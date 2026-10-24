"""karina:worktree-cleanup — 레포의 git worktree 를 감사(audit)하고, 고른 것만 백업 뒤 지운다(remove).

대상은 `git worktree list --porcelain` 이 내는 경로뿐이고 첫 항목(주 worktree)은 표에 싣지 않는다.

audit — 읽기 전용. git 호출은 모두 `--no-optional-locks` 라 index 를 refresh 해 쓰지 않는다.
  열: SIZE · AGE(HEAD 커밋 경과 일) · MERGED(yes = base 조상 | pr = PR MERGED | no) · DIRTY(clean | wip:N 추적 수정
  | scratch:N 미추적만) · IGNORED(ignore 항목 수) · PR(OPEN | MERGED | CLOSED | -) · LAST_SESSION(최근 Claude 세션 날짜
  | - 없음 | ? 판정 불가) · BUCKET · BRANCH(- 는 detached) · WORKTREE. `--json` 이면 {"base", "worktrees": [행]}.
  버킷(위가 먼저): current(지금 cwd 가 그 안) · hold-locked · hold-wip · hold-open-pr · hold-chain(브랜치가
  `chain-<영숫자 8자>-p<숫자>` 로 끝나고 미병합 — chain-plan 재개가 그 안의 plan.md 를 읽는다) · hold-recent(세션
  ≤ --recent-days) · review(detached) · safe(MERGED yes·pr, 세션 판정 가능) · review(그 밖).
  세션: `<projects-dir>` 아래 폴더 이름이 worktree 절대 경로의 슬러그(영숫자 밖 문자 → `-`)와 같거나 `<슬러그>-` 로
  시작하면 그 폴더 최상위 `*.jsonl` 의 최신 mtime 을 쓴다(하위 폴더에서 연 세션 포함). 경로에 비 ASCII 가 있으면
  슬러그 규칙을 모르므로 `?` 이고 safe 로 올리지 않는다.
  base: --base, 없으면 origin/HEAD → origin/main → origin/master. 로컬 ref 그대로 쓰고 fetch 하지 않는다.

remove [--dry-run] <경로>... — 경로마다 audit 과 같은 판정을 다시 해 hold·current 버킷과 주 worktree 는 거부한다.
  지우기 전에 미추적(`??`)·ignore(`!!`) 항목을 `<backup-root>/<레포 이름>/<worktree 이름>-<시각>/` 에 복사하고
  manifest.txt(원래 경로·브랜치·HEAD·백업한 것·건너뛴 것)를 쓴다. ignore 폴더 항목은 합계가 --ignored-dir-cap-mb
  를 넘으면 건너뛴다. 미추적 폴더는 상한 없이 복사한다.
  삭제: Karina CLI 가 그 경로를 아는 worktree(`worktree show --worktree path:<경로>` 가 ok)는
  `worktree rm --worktree path:<경로> --force --json`, `selector_not_found` 면 `git worktree remove --force`,
  그 밖의 오류(앱이 꺼짐 등)면 그 경로를 실패로 두고 지우지 않는다. 남은 폴더는 읽기 전용을 풀고 지운다.
  끝에 `git worktree prune`. 브랜치 ref 는 지우지 않는다. 한 경로가 실패해도 나머지를 진행한다.
  출력 첫 줄: `RESULT: removed N · refused N · failed N — backup <backup-root>`
  (--dry-run 이면 `RESULT: dry-run · would remove N · refused N · failed N`). 이어서 경로마다
  REMOVED | REFUSED | FAILED | PLAN 줄, 백업 항목마다 BACKUP | SKIP 줄.

변동값 주입: --now <epoch 초> · --projects-dir · --pr-json <[{"head","state"}] 파일 — 없으면 `gh pr list` 를 부르고
실패하면 PR 열은 -> · --backup-root(기본 시스템 임시 폴더/karina-plugin/worktree-backup — TEMP-FILES.md) · --karina-cli <경로>(.py 면
python 으로 실행 · 없으면 KARINA_CLI_COMMAND → PATH 의 karina-cli) · --no-karina.

종료 코드: 0 정상 · 1 거부·실패가 하나 이상(remove) · 2 레포·base 오류.
"""
import argparse
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time

DAY = 86400
HOLD = ('current', 'hold-locked', 'hold-wip', 'hold-open-pr', 'hold-chain')
CHAIN_RX = re.compile(r'chain-[0-9A-Za-z]{8}-p\d+$')
PR_RANK = {'OPEN': 3, 'MERGED': 2, 'CLOSED': 1}


class Fatal(Exception):
    pass


# ---- 바깥(git·gh·Karina·파일시스템) ----

def git(cwd, *args):
    p = subprocess.run(['git', '--no-optional-locks', '-C', cwd] + list(args),
                       capture_output=True, timeout=120)
    return p.returncode, p.stdout.decode('utf-8', 'replace')


def list_worktrees(repo):
    rc, out = git(repo, 'worktree', 'list', '--porcelain')
    if rc != 0:
        raise Fatal('git 레포가 아니거나 worktree 목록을 읽지 못함: %s' % repo)
    blocks, cur = [], None
    for line in out.splitlines():
        if line.startswith('worktree '):
            cur = {'path': line[9:], 'head': '', 'branch': None, 'locked': False}
            blocks.append(cur)
        elif cur is None:
            continue
        elif line.startswith('HEAD '):
            cur['head'] = line[5:]
        elif line.startswith('branch '):
            cur['branch'] = line[7:].replace('refs/heads/', '', 1)
        elif line == 'locked' or line.startswith('locked '):
            cur['locked'] = True
    return blocks


def resolve_base(repo, base):
    cands = [base] if base else []
    if not base:
        rc, out = git(repo, 'symbolic-ref', '--short', 'refs/remotes/origin/HEAD')
        cands = ([out.strip()] if rc == 0 and out.strip() else []) + ['origin/main', 'origin/master']
    for c in cands:
        if git(repo, 'rev-parse', '--verify', '--quiet', c + '^{commit}')[0] == 0:
            return c
    raise Fatal('base ref 를 찾지 못함: %s — --base 로 지정' % (base or ', '.join(cands)))


def status_entries(wt):
    """(XY, 상대 경로) 목록. 미추적·ignore 폴더는 `dir/` 한 항목으로 접혀 온다."""
    rc, out = git(wt, 'status', '--porcelain', '-z', '--ignored')
    if rc != 0:
        return None
    toks, entries, i = out.split('\0'), [], 0
    while i < len(toks):
        t = toks[i]
        i += 1
        if len(t) < 4:
            continue
        entries.append((t[:2], t[3:]))
        if t[0] in 'RC':
            i += 1  # 이름 바꾸기의 원래 경로 토큰
    return entries


def load_prs(repo, pr_json):
    if pr_json:
        with open(pr_json, encoding='utf-8') as f:
            raw = json.load(f)
    else:
        try:
            p = subprocess.run(['gh', 'pr', 'list', '--state', 'all', '--limit', '1000', '--json', 'headRefName,state'],
                               cwd=repo, capture_output=True, timeout=60)
            raw = [{'head': r['headRefName'], 'state': r['state']} for r in json.loads(p.stdout)] if p.returncode == 0 else []
        except (OSError, ValueError, subprocess.TimeoutExpired):
            raw = []
    prs = {}
    for r in raw:
        s = str(r.get('state', '')).upper()
        if PR_RANK.get(s, 0) > PR_RANK.get(prs.get(r.get('head')), 0):
            prs[r['head']] = s
    return prs


def session_index(projects_dir):
    """폴더 이름(소문자) → 최상위 *.jsonl 최신 mtime."""
    idx = {}
    if not projects_dir or not os.path.isdir(projects_dir):
        return idx
    for name in os.listdir(projects_dir):
        d = os.path.join(projects_dir, name)
        if not os.path.isdir(d):
            continue
        ts = [os.path.getmtime(os.path.join(d, f)) for f in os.listdir(d) if f.endswith('.jsonl')]
        if ts:
            idx[name.lower()] = max(ts)
    return idx


def tree_size(path):
    if os.path.isfile(path):
        return os.path.getsize(path)
    total = 0
    for dp, _, fs in os.walk(path):
        for f in fs:
            try:
                total += os.path.getsize(os.path.join(dp, f))
            except OSError:
                pass
    return total


def _onerror(func, path, _exc):
    os.chmod(path, stat.S_IWRITE)
    func(path)


def rmtree(path):
    shutil.rmtree(path, onerror=_onerror)


def karina_call(cli, args):
    cmd = ([sys.executable, cli] if cli.lower().endswith('.py') else [cli]) + args
    try:
        p = subprocess.run(cmd, capture_output=True, timeout=120)
        doc = json.loads(p.stdout.decode('utf-8', 'replace'))
    except (OSError, ValueError, subprocess.TimeoutExpired) as e:
        return False, 'karina 응답 해석 불가 (%s)' % type(e).__name__
    if doc.get('ok'):
        return True, ''
    return False, str((doc.get('error') or {}).get('code', 'unknown'))


def resolve_karina(args):
    if args.no_karina:
        return None
    return args.karina_cli or os.environ.get('KARINA_CLI_COMMAND') or shutil.which('karina-cli')


# ---- 판정(값만 받는다) ----

def norm(p):
    return os.path.normcase(os.path.abspath(p))


def slug(path):
    return re.sub(r'[^A-Za-z0-9]', '-', os.path.abspath(path)).lower()


def last_session(path, idx):
    """(표시 문자열, mtime 또는 None). 비 ASCII 경로는 ('?', None)."""
    if not path.isascii():
        return '?', None
    s = slug(path)
    ts = [t for n, t in idx.items() if n == s or n.startswith(s + '-')]
    if not ts:
        return '-', None
    t = max(ts)
    return time.strftime('%Y-%m-%d', time.localtime(t)), t


def bucket(current, locked, wip, pr, branch, merged, recent, session_unknown):
    if current:
        return 'current'
    if locked:
        return 'hold-locked'
    if wip:
        return 'hold-wip'
    if pr == 'OPEN':
        return 'hold-open-pr'
    if branch and CHAIN_RX.search(branch) and merged == 'no':
        return 'hold-chain'
    if recent:
        return 'hold-recent'
    if branch is None:
        return 'review'
    if merged != 'no' and not session_unknown:
        return 'safe'
    return 'review'


def human(n):
    for unit in ('B', 'K', 'M', 'G'):
        if n < 1024 or unit == 'G':
            return '%d%s' % (n, unit) if unit == 'B' else '%.1f%s' % (n, unit)
        n /= 1024.0


# ---- 조립 ----

def inspect(repo, wt, base, prs, idx, now, recent_days, cwd):
    path = wt['path']
    entries = status_entries(path) if os.path.isdir(path) else None
    entries = entries or []
    wip = sum(1 for xy, _ in entries if xy not in ('??', '!!'))
    untracked = sum(1 for xy, _ in entries if xy == '??')
    ignored = sum(1 for xy, _ in entries if xy == '!!')
    ancestor = bool(wt['head']) and git(repo, 'merge-base', '--is-ancestor', wt['head'], base)[0] == 0
    pr = prs.get(wt['branch'], '-') if wt['branch'] else '-'
    merged = 'yes' if ancestor else ('pr' if pr == 'MERGED' else 'no')
    shown, t = last_session(path, idx)
    recent = t is not None and now - t <= recent_days * DAY
    rc, ct = git(repo, 'log', '-1', '--format=%ct', wt['head']) if wt['head'] else (1, '')
    age = '%dd' % ((now - int(ct.strip())) // DAY) if rc == 0 and ct.strip().isdigit() else '?'
    np, nc = norm(path), norm(cwd)
    current = nc == np or nc.startswith(np.rstrip(os.sep) + os.sep)
    dirty = 'wip:%d' % wip if wip else ('scratch:%d' % untracked if untracked else 'clean')
    return {
        'worktree': path, 'branch': wt['branch'] or '-', 'size': human(tree_size(path)) if os.path.isdir(path) else '-',
        'age': age, 'merged': merged, 'dirty': dirty, 'ignored': ignored, 'pr': pr, 'last_session': shown,
        'bucket': bucket(current, wt['locked'], wip, pr, wt['branch'], merged, recent, shown == '?'),
        '_entries': entries,
    }


def context(args):
    repo = os.path.abspath(args.repo)
    wts = list_worktrees(repo)
    base = resolve_base(repo, args.base)
    prs = load_prs(repo, args.pr_json)
    idx = session_index(args.projects_dir)
    now = args.now if args.now is not None else int(time.time())
    return repo, wts, base, prs, idx, now


def cmd_audit(args):
    repo, wts, base, prs, idx, now = context(args)
    rows = [inspect(repo, wt, base, prs, idx, now, args.recent_days, os.getcwd()) for wt in wts[1:]]
    for r in rows:
        del r['_entries']
    if args.json:
        print(json.dumps({'base': base, 'worktrees': rows}, ensure_ascii=False, indent=1))
        return 0
    cols = ['size', 'age', 'merged', 'dirty', 'ignored', 'pr', 'last_session', 'bucket', 'branch', 'worktree']
    print('# base: %s' % base)
    print('\t'.join(c.upper() for c in cols))
    for r in rows:
        print('\t'.join(str(r[c]) for c in cols))
    return 0


def backup_plan(path, entries, cap_bytes):
    """(백업할 상대 경로 목록, [(건너뛸 상대 경로, 크기)])."""
    take, skip = [], []
    for xy, rel in entries:
        if xy == '??':
            take.append(rel)
        elif xy == '!!':
            if rel.endswith('/'):
                size = tree_size(os.path.join(path, rel))
                if size > cap_bytes:
                    skip.append((rel, size))
                    continue
            take.append(rel)
    return take, skip


def do_backup(root, repo, wt, take, skip, now):
    stamp = time.strftime('%Y%m%d-%H%M%S', time.localtime(now))
    first = os.path.join(root, os.path.basename(repo.rstrip('/\\')), '%s-%s' % (os.path.basename(wt['path'].rstrip('/\\')), stamp))
    dest, n = first, 2
    while os.path.exists(dest):
        dest = '%s-%d' % (first, n)
        n += 1
    os.makedirs(dest)
    for rel in take:
        src = os.path.join(wt['path'], rel.rstrip('/'))
        dst = os.path.join(dest, rel.rstrip('/'))
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if os.path.isdir(src):
            shutil.copytree(src, dst, symlinks=True)
        else:
            shutil.copy2(src, dst)
    lines = ['worktree: %s' % wt['path'], 'branch: %s' % (wt['branch'] or '-'), 'head: %s' % wt['head']]
    lines += ['backup: %s' % r for r in take] + ['skipped: %s (%d B)' % (r, s) for r, s in skip]
    with open(os.path.join(dest, 'manifest.txt'), 'w', encoding='utf-8') as f:
        f.write('\n'.join(lines) + '\n')
    return dest


def delete_worktree(repo, path, cli):
    """실패 사유 문자열, 성공이면 None."""
    managed = False
    if cli:
        ok, code = karina_call(cli, ['worktree', 'show', '--worktree', 'path:' + path, '--json'])
        if ok:
            managed = True
        elif code != 'selector_not_found':
            return 'Karina CLI %s — 지우지 않음' % code
    if managed:
        ok, code = karina_call(cli, ['worktree', 'rm', '--worktree', 'path:' + path, '--force', '--json'])
        if not ok:
            return 'Karina worktree rm %s' % code
    else:
        git(repo, 'worktree', 'remove', '--force', path)
    if os.path.exists(path):
        try:
            rmtree(path)
        except OSError as e:
            return '폴더 삭제 실패 (%s)' % e
    return None


def cmd_remove(args):
    repo, wts, base, prs, idx, now = context(args)
    by_path = {norm(w['path']): w for w in wts}
    main_wt = norm(wts[0]['path'])
    cli = None if args.dry_run else resolve_karina(args)
    cap = int(args.ignored_dir_cap_mb * 1024 * 1024)
    out, removed, refused, failed, planned = [], 0, 0, 0, 0
    for raw in args.paths:
        key = norm(raw)
        if key == main_wt:
            refused += 1
            out.append('REFUSED %s — 주 worktree' % raw)
            continue
        wt = by_path.get(key)
        if wt is None:
            failed += 1
            out.append('FAILED %s — git worktree 목록에 없음' % raw)
            continue
        r = inspect(repo, wt, base, prs, idx, now, args.recent_days, os.getcwd())
        if r['bucket'] in HOLD:
            refused += 1
            out.append('REFUSED %s — %s' % (wt['path'], r['bucket']))
            continue
        take, skip = backup_plan(wt['path'], r['_entries'], cap)
        items = ['BACKUP %s :: %s' % (wt['path'], t) for t in take] + \
                ['SKIP %s :: %s (%d B — 상한 초과, 백업 안 함)' % (wt['path'], s, n) for s, n in skip]
        if args.dry_run:
            planned += 1
            out.append('PLAN %s — %s · 백업 %d · 건너뜀 %d' % (wt['path'], r['bucket'], len(take), len(skip)))
            out += items
            continue
        try:
            dest = do_backup(args.backup_root, repo, wt, take, skip, now)
        except OSError as e:
            failed += 1
            out.append('FAILED %s — 백업 실패, 지우지 않음 (%s)' % (wt['path'], e))
            continue
        reason = delete_worktree(repo, wt['path'], cli)
        if reason:
            failed += 1
            out.append('FAILED %s — %s · 백업 %s' % (wt['path'], reason, dest))
        else:
            removed += 1
            out.append('REMOVED %s — 백업 %s' % (wt['path'], dest))
        out += items
    if args.dry_run:
        print('RESULT: dry-run · would remove %d · refused %d · failed %d' % (planned, refused, failed))
    else:
        git(repo, 'worktree', 'prune')
        print('RESULT: removed %d · refused %d · failed %d — backup %s' % (removed, refused, failed, args.backup_root))
    for line in out:
        print(line)
    return 1 if refused or failed else 0


def main(argv=None):
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    ap = argparse.ArgumentParser(description='git worktree 감사·정리')
    sub = ap.add_subparsers(dest='cmd', required=True)
    for name in ('audit', 'remove'):
        p = sub.add_parser(name)
        p.add_argument('--repo', default='.')
        p.add_argument('--base')
        p.add_argument('--recent-days', type=float, default=4)
        p.add_argument('--now', type=int)
        p.add_argument('--projects-dir', default=os.path.join(os.path.expanduser('~'), '.claude', 'projects'))
        p.add_argument('--pr-json')
    sub.choices['audit'].add_argument('--json', action='store_true')
    rm = sub.choices['remove']
    rm.add_argument('--dry-run', action='store_true')
    rm.add_argument('--backup-root', default=os.path.join(tempfile.gettempdir(), 'karina-plugin', 'worktree-backup'))
    rm.add_argument('--ignored-dir-cap-mb', type=float, default=50)
    rm.add_argument('--karina-cli')
    rm.add_argument('--no-karina', action='store_true')
    rm.add_argument('paths', nargs='+')
    args = ap.parse_args(argv)
    try:
        return cmd_audit(args) if args.cmd == 'audit' else cmd_remove(args)
    except Fatal as e:
        print('오류: %s' % e, file=sys.stderr)
        return 2


if __name__ == '__main__':
    sys.exit(main())
