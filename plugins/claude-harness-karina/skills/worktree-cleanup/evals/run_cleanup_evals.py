"""worktree-cleanup 스크립트(scripts/worktree_cleanup.py) 골든.

모델·Karina 앱·gh 를 부르지 않는다 — 임시 폴더에 실제 git 레포와 레포 바깥 worktree 들을 만들고,
가짜 projects 폴더(세션 전사 mtime)·PR 상태 JSON·가짜 Karina CLI(python 스크립트)를 주입해
스크립트를 실제 프로세스로 띄운다. 전역 git 설정은 빈 파일로 격리한다 — 전역 gitignore 가 픽스처 파일을
삼키면 작성자 PC 에서만 결과가 갈린다.
"""
import json
import os
import re
import shutil
import stat
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, '..', 'scripts', 'worktree_cleanup.py')
DAY = 86400

CASES = []


def case(fn):
    CASES.append(fn)
    return fn


def _onerror(func, path, _exc):
    os.chmod(path, stat.S_IWRITE)
    func(path)


def rmtree(path):
    if os.path.exists(path):
        shutil.rmtree(path, onerror=_onerror)


def slug(path):
    return re.sub(r'[^A-Za-z0-9]', '-', os.path.abspath(path))


class Fixture:
    """임시 루트 아래 repo/(main) · wts/<이름>(worktree) · projects/ · backup/ 를 둔다."""

    def __init__(self):
        self.root = os.path.realpath(tempfile.mkdtemp(prefix='wtc-'))
        self.repo = os.path.join(self.root, 'repo')
        self.projects = os.path.join(self.root, 'projects')
        self.backup = os.path.join(self.root, 'backup')
        os.makedirs(self.projects)
        gcfg = os.path.join(self.root, 'gitconfig')
        open(gcfg, 'w').close()
        self.env = dict(os.environ)
        self.env.update({
            'GIT_CONFIG_GLOBAL': gcfg, 'GIT_CONFIG_NOSYSTEM': '1',
            'GIT_AUTHOR_NAME': 't', 'GIT_AUTHOR_EMAIL': 't@t', 'GIT_COMMITTER_NAME': 't', 'GIT_COMMITTER_EMAIL': 't@t',
        })
        self.env.pop('KARINA_CLI_COMMAND', None)
        self.prs = []
        self.now = int(time.time())
        os.makedirs(self.repo)
        self.git('init', '-q', '-b', 'main')
        self.write('repo', 'README.md', 'hello\n')
        self.write('repo', '.gitignore', 'plan.md\nnode_modules/\nbigdir/\n')
        self.git('add', '.')
        self.git('commit', '-qm', 'init')

    def git(self, *args, cwd=None):
        p = subprocess.run(['git'] + list(args), cwd=cwd or self.repo, env=self.env, capture_output=True, timeout=60)
        if p.returncode != 0:
            raise AssertionError('git %s 실패: %s' % (' '.join(args), p.stderr.decode('utf-8', 'replace')))
        return p.stdout.decode('utf-8', 'replace').strip()

    def path(self, name):
        return os.path.join(self.root, 'wts', name)

    def write(self, where, rel, text):
        base = self.repo if where == 'repo' else self.path(where)
        full = os.path.join(base, rel)
        os.makedirs(os.path.dirname(full), exist_ok=True)
        with open(full, 'w', encoding='utf-8') as f:
            f.write(text)
        return full

    def add(self, name, branch=None, commit=False, merge=False, detach=False):
        """worktree 하나를 만든다. commit 이면 그 브랜치에 커밋 1개, merge 면 main 에 fast-forward 로 넣는다."""
        p = self.path(name)
        if detach:
            self.git('worktree', 'add', '-q', '--detach', p, 'main')
            return p
        self.git('worktree', 'add', '-q', '-b', branch or name, p, 'main')
        if commit:
            self.write(name, 'work-%s.txt' % abs(hash(name)), 'work\n')
            self.git('add', '.', cwd=p)
            self.git('commit', '-qm', 'work', cwd=p)
        if merge:
            self.git('merge', '-q', '--ff-only', branch or name)
        return p

    def session(self, wt_path, days_ago, suffix=''):
        d = os.path.join(self.projects, slug(wt_path) + suffix)
        os.makedirs(d, exist_ok=True)
        f = os.path.join(d, 'sess.jsonl')
        open(f, 'w').close()
        t = self.now - int(days_ago * DAY)
        os.utime(f, (t, t))

    def run(self, *args, cwd=None):
        prj = os.path.join(self.root, 'prs.json')
        with open(prj, 'w', encoding='utf-8') as f:
            json.dump(self.prs, f)
        common = ['--repo', self.repo, '--base', 'main', '--now', str(self.now),
                  '--projects-dir', self.projects, '--pr-json', prj]
        cmd = [sys.executable, SCRIPT, args[0]] + common + list(args[1:])
        p = subprocess.run(cmd, cwd=cwd or self.root, env=self.env, capture_output=True, timeout=120)
        return p.returncode, p.stdout.decode('utf-8', 'replace'), p.stderr.decode('utf-8', 'replace')

    def audit(self, cwd=None):
        rc, out, err = self.run('audit', '--json', cwd=cwd)
        assert rc == 0, (rc, err)
        return {os.path.basename(r['worktree'].rstrip('/\\')): r for r in json.loads(out)['worktrees']}

    def remove(self, *args):
        return self.run('remove', '--backup-root', self.backup, *args)

    def listed(self):
        out = self.git('worktree', 'list', '--porcelain')
        return [os.path.normcase(os.path.abspath(l[9:])) for l in out.splitlines() if l.startswith('worktree ')]

    def is_listed(self, p):
        return os.path.normcase(os.path.abspath(p)) in self.listed()

    def backup_files(self):
        found = []
        for dp, _, fs in os.walk(self.backup):
            found += [os.path.relpath(os.path.join(dp, f), self.backup).replace('\\', '/') for f in fs]
        return found

    def manifest(self):
        ms = [f for f in self.backup_files() if f.endswith('manifest.txt')]
        assert len(ms) == 1, ms
        with open(os.path.join(self.backup, ms[0]), encoding='utf-8') as f:
            return f.read()

    def close(self):
        for p in self.listed()[1:]:
            subprocess.run(['git', 'worktree', 'unlock', p], cwd=self.repo, env=self.env, capture_output=True)
        rmtree(self.root)


# ---- audit: 한 픽스처에 갈래별 worktree 를 모두 두고 한 번 돈 결과를 케이스마다 단언한다 ----

_AUDIT = {}


def audit_fixture():
    if _AUDIT:
        return _AUDIT
    fx = Fixture()
    try:
        wm = fx.add('wt-merged', commit=True, merge=True)
        fx.write('wt-merged', 'plan.md', '# plan\n')
        fx.write('wt-merged', 'scratch.txt', 'x\n')
        fx.add('wt-unmerged', commit=True)
        fx.add('wt-wip')
        fx.write('wt-wip', 'README.md', 'changed\n')
        fx.add('wt-pr-open', commit=True)
        fx.add('wt-squash', commit=True)
        fx.add('wt-closed', commit=True)
        fx.prs = [{'head': 'wt-pr-open', 'state': 'OPEN'}, {'head': 'wt-squash', 'state': 'MERGED'},
                  {'head': 'wt-closed', 'state': 'CLOSED'},
                  {'head': 'chain-ab12cd34-p3', 'state': 'MERGED'}]
        fx.session(fx.add('wt-recent'), 3)
        wo = fx.add('wt-old')
        fx.session(wo, 5)
        fx.session(fx.add('wt-sub'), 1, suffix='-plugins-sub')
        fx.add('wt-locked')
        fx.git('worktree', 'lock', fx.path('wt-locked'))
        fx.add('wt-detached', detach=True)
        fx.add('wt-한글')
        fx.add('wt-chain', branch='karina/chain-ab12cd34-p2', commit=True)
        fx.add('wt-chain-merged', branch='chain-ab12cd34-p3', commit=True)
        # ⑰ 추적 파일의 mtime 만 바꿔 두면 일반 git status 는 index 를 refresh 해 다시 쓴다
        readme = os.path.join(wo, 'README.md')
        t = time.time() + 10
        os.utime(readme, (t, t))
        gitdirs = os.path.join(fx.repo, '.git', 'worktrees')
        idx = {n: os.stat(os.path.join(gitdirs, n, 'index')).st_mtime_ns for n in os.listdir(gitdirs)
               if os.path.exists(os.path.join(gitdirs, n, 'index'))}
        rows = fx.audit()
        idx_after = {n: os.stat(os.path.join(gitdirs, n, 'index')).st_mtime_ns for n in idx}
        cur = fx.audit(cwd=wm)
        rc, _, err = fx.run('audit', '--json', '--base', 'nope')
        _AUDIT.update(rows=rows, idx=idx, idx_after=idx_after, current=cur, bad_base=(rc, err), main=fx.repo)
    finally:
        fx.close()
    return _AUDIT


def row(name):
    rows = audit_fixture()['rows']
    assert name in rows, sorted(rows)
    return rows[name]


@case
def audit_merged_is_safe():
    # ① base 조상 → safe
    assert row('wt-merged')['bucket'] == 'safe', row('wt-merged')


@case
def audit_unmerged_is_review():
    # ② 미병합 → review
    assert row('wt-unmerged')['bucket'] == 'review', row('wt-unmerged')


@case
def audit_tracked_change_is_hold_wip():
    # ③ 추적 수정 → hold-wip
    r = row('wt-wip')
    assert r['bucket'] == 'hold-wip' and r['dirty'] == 'wip:1', r


@case
def audit_untracked_only_is_scratch():
    # ④ 미추적만 → scratch:N, 버킷은 병합 기준
    r = row('wt-merged')
    assert r['dirty'] == 'scratch:1' and r['bucket'] == 'safe', r


@case
def audit_open_pr_is_hold():
    # ⑤ PR OPEN → hold-open-pr
    assert row('wt-pr-open')['bucket'] == 'hold-open-pr', row('wt-pr-open')


@case
def audit_squash_merged_pr_is_safe():
    # ⑥ PR MERGED(조상 아님) → safe
    r = row('wt-squash')
    assert r['merged'] == 'pr' and r['bucket'] == 'safe', r


@case
def audit_closed_pr_is_review():
    # ⑦ PR CLOSED 미병합 → review
    assert row('wt-closed')['bucket'] == 'review', row('wt-closed')


@case
def audit_recent_session_is_hold():
    # ⑧ 전사 3일 전 → hold-recent
    assert row('wt-recent')['bucket'] == 'hold-recent', row('wt-recent')


@case
def audit_old_session_falls_through():
    # ⑨ 전사 5일 전 → 병합 기준 버킷
    r = row('wt-old')
    assert r['bucket'] == 'safe' and r['last_session'] != '-', r


@case
def audit_subfolder_session_counts():
    # ⑩ 하위 폴더 슬러그의 전사도 잡힌다
    assert row('wt-sub')['bucket'] == 'hold-recent', row('wt-sub')


@case
def audit_locked_is_hold():
    # ⑪ locked → hold-locked
    assert row('wt-locked')['bucket'] == 'hold-locked', row('wt-locked')


@case
def audit_main_worktree_excluded():
    # ⑫ 주 worktree 는 표에 없다
    assert 'repo' not in audit_fixture()['rows'], sorted(audit_fixture()['rows'])


@case
def audit_cwd_worktree_is_current():
    # ⑬ 지금 cwd 가 속한 worktree → current
    assert audit_fixture()['current']['wt-merged']['bucket'] == 'current', audit_fixture()['current']['wt-merged']


@case
def audit_detached_is_review():
    # ⑭ detached → review (main 과 같은 커밋이어도)
    r = row('wt-detached')
    assert r['branch'] == '-' and r['bucket'] == 'review', r


@case
def audit_missing_base_exits_2():
    # ⑮ base 없음 → exit 2 와 오류 줄
    rc, err = audit_fixture()['bad_base']
    assert rc == 2 and 'nope' in err, (rc, err)


@case
def audit_counts_ignored_files():
    # ⑯ ignore 파일(plan.md)을 IGNORED 열에 센다
    assert row('wt-merged')['ignored'] == 1, row('wt-merged')


@case
def audit_does_not_write_index():
    # ⑰ audit 전후 각 worktree index mtime 불변
    a = audit_fixture()
    assert a['idx'] and a['idx'] == a['idx_after'], [n for n in a['idx'] if a['idx'][n] != a['idx_after'][n]]


@case
def audit_non_ascii_path_never_safe():
    # ㉕ 비 ASCII 경로 → LAST_SESSION ? 이고 병합돼도 safe 가 아니다
    r = row('wt-한글')
    assert r['last_session'] == '?' and r['bucket'] == 'review', r


@case
def audit_unmerged_chain_is_hold():
    # ㉖ chain-<8자>-p<N> 미병합 → hold-chain
    assert row('wt-chain')['bucket'] == 'hold-chain', row('wt-chain')


@case
def audit_chain_with_merged_pr_is_safe():
    # ㉗ 같은 패턴이라도 PR MERGED → safe
    assert row('wt-chain-merged')['bucket'] == 'safe', row('wt-chain-merged')


# ---- remove: 케이스마다 작은 픽스처 ----

def with_fixture(fn):
    fx = Fixture()
    try:
        fn(fx)
    finally:
        fx.close()


@case
def remove_backs_up_and_removes():
    # ⑱ ignore plan.md·미추적 파일·manifest 가 백업에 있고 worktree 목록에서 빠진다
    def body(fx):
        p = fx.add('done', commit=True, merge=True)
        fx.write('done', 'plan.md', '# plan\n')
        fx.write('done', 'scratch.txt', 'x\n')
        rc, out, err = fx.remove('--no-karina', p)
        assert rc == 0 and out.startswith('RESULT: removed 1'), (rc, out, err)
        files = fx.backup_files()
        assert any(f.endswith('/plan.md') for f in files) and any(f.endswith('/scratch.txt') for f in files), files
        assert 'plan.md' in fx.manifest()
        assert not fx.is_listed(p) and not os.path.exists(p)
    with_fixture(body)


@case
def remove_keeps_branch():
    # ⑲ 브랜치 ref 는 남는다
    def body(fx):
        p = fx.add('keep-branch', commit=True, merge=True)
        rc, out, err = fx.remove('--no-karina', p)
        assert rc == 0, (out, err)
        assert fx.git('branch', '--list', 'keep-branch') != ''
    with_fixture(body)


@case
def remove_refuses_wip():
    # ⑳ wip 거부 — 폴더·파일 그대로
    def body(fx):
        p = fx.add('wip')
        fx.write('wip', 'README.md', 'changed\n')
        rc, out, _ = fx.remove('--no-karina', p)
        assert rc == 1 and 'REFUSED' in out and 'hold-wip' in out, out
        assert fx.is_listed(p) and open(os.path.join(p, 'README.md'), encoding='utf-8').read() == 'changed\n'
    with_fixture(body)


@case
def remove_refuses_main():
    # ㉑ 주 worktree 거부
    def body(fx):
        rc, out, _ = fx.remove('--no-karina', fx.repo)
        assert rc == 1 and 'REFUSED' in out, out
        assert os.path.exists(os.path.join(fx.repo, 'README.md'))
    with_fixture(body)


@case
def remove_skips_big_ignored_dir():
    # ㉒ 상한을 넘는 ignore 폴더는 건너뛰고 manifest·출력에 싣는다
    def body(fx):
        p = fx.add('big', commit=True, merge=True)
        fx.write('big', 'bigdir/blob.bin', 'x' * 4096)
        rc, out, err = fx.remove('--no-karina', '--ignored-dir-cap-mb', '0.001', p)
        assert rc == 0, (out, err)
        assert 'SKIP' in out and 'bigdir' in out, out
        assert 'bigdir' in fx.manifest() and not any('blob.bin' in f for f in fx.backup_files())
        assert not fx.is_listed(p)
    with_fixture(body)


@case
def remove_dry_run_changes_nothing():
    # ㉓ --dry-run 은 지우지 않고 백업 계획만 낸다
    def body(fx):
        p = fx.add('dry', commit=True, merge=True)
        fx.write('dry', 'plan.md', '# plan\n')
        rc, out, err = fx.remove('--no-karina', '--dry-run', p)
        assert rc == 0 and 'BACKUP' in out and 'plan.md' in out, (out, err)
        assert fx.is_listed(p) and os.path.exists(os.path.join(p, 'plan.md'))
        assert not os.path.exists(fx.backup)
    with_fixture(body)


@case
def remove_default_backup_root_is_karina_plugin():
    # --backup-root 를 주지 않으면 임시 폴더의 karina-plugin/worktree-backup 에 백업한다(TEMP-FILES.md)
    def body(fx):
        p = fx.add('defroot', commit=True, merge=True)
        fx.write('defroot', 'plan.md', '# plan\n')
        fake_tmp = os.path.join(fx.root, 'tmp')
        os.makedirs(fake_tmp)
        fx.env.update({'TMPDIR': fake_tmp, 'TEMP': fake_tmp, 'TMP': fake_tmp})
        rc, out, err = fx.run('remove', '--no-karina', p)
        want = os.path.join(fake_tmp, 'karina-plugin', 'worktree-backup')
        assert rc == 0 and want.replace('\\', '/') in out.replace('\\', '/'), (want, out, err)
        assert os.path.isdir(want) and os.listdir(want), want
    with_fixture(body)


@case
def remove_continues_after_failure():
    # ㉔ 한 경로가 실패해도 나머지는 지우고 exit 1
    def body(fx):
        p = fx.add('ok', commit=True, merge=True)
        rc, out, _ = fx.remove('--no-karina', os.path.join(fx.root, 'no-such'), p)
        assert rc == 1 and 'FAILED' in out, out
        assert not fx.is_listed(p)
    with_fixture(body)


@case
def remove_refuses_unmerged_chain():
    # ㉘ hold-chain 거부
    def body(fx):
        p = fx.add('chain', branch='chain-ab12cd34-p1', commit=True)
        rc, out, _ = fx.remove('--no-karina', p)
        assert rc == 1 and 'hold-chain' in out, out
        assert fx.is_listed(p)
    with_fixture(body)


@case
def remove_refuses_open_pr():
    # ㉙ hold-open-pr 거부
    def body(fx):
        p = fx.add('pr', commit=True)
        fx.prs = [{'head': 'pr', 'state': 'OPEN'}]
        rc, out, _ = fx.remove('--no-karina', p)
        assert rc == 1 and 'hold-open-pr' in out, out
        assert fx.is_listed(p)
    with_fixture(body)


@case
def remove_allows_review():
    # ㉚ review 는 사용자가 지정하면 지운다
    def body(fx):
        p = fx.add('rv', commit=True)
        rc, out, err = fx.remove('--no-karina', p)
        assert rc == 0, (out, err)
        assert not fx.is_listed(p) and fx.git('branch', '--list', 'rv') != ''
    with_fixture(body)


@case
def remove_backs_up_untracked_dir():
    # ㉛ 미추적 폴더는 통째로 백업하고 manifest 에 싣는다
    def body(fx):
        p = fx.add('ud', commit=True, merge=True)
        fx.write('ud', 'newdir/a.txt', 'a\n')
        fx.write('ud', 'newdir/b.txt', 'b\n')
        rc, out, err = fx.remove('--no-karina', p)
        assert rc == 0, (out, err)
        files = fx.backup_files()
        assert any(f.endswith('newdir/a.txt') for f in files) and any(f.endswith('newdir/b.txt') for f in files), files
        assert 'newdir' in fx.manifest()
    with_fixture(body)


@case
def remove_skips_artifact_dir():
    # ㉟ 빌드·캐시 이름의 ignore 폴더는 상한 이하여도 백업하지 않고 SKIP·manifest 에 싣는다
    def body(fx):
        p = fx.add('art', commit=True, merge=True)
        fx.write('art', 'node_modules/x.js', 'x\n')
        rc, out, err = fx.remove('--no-karina', p)
        assert rc == 0 and out.startswith('RESULT: removed 1'), (out, err)
        assert any(l.startswith('SKIP') and 'node_modules' in l for l in out.splitlines()), out
        assert 'node_modules' in fx.manifest() and not any(f.endswith('x.js') for f in fx.backup_files())
        assert not fx.is_listed(p)
    with_fixture(body)


@case
def remove_untracked_dir_excludes_nested_artifact():
    # ㊱ 미추적 폴더 안의 빌드·캐시 폴더는 빼고 나머지를 백업한 뒤 지운다
    def body(fx):
        p = fx.add('una', commit=True, merge=True)
        fx.write('una', 'newdir/a.txt', 'a\n')
        fx.write('una', 'newdir/node_modules/x.js', 'x\n')
        rc, out, err = fx.remove('--no-karina', p)
        assert rc == 0 and out.startswith('RESULT: removed 1'), (out, err)
        files = fx.backup_files()
        assert any(f.endswith('newdir/a.txt') for f in files) and not any(f.endswith('x.js') for f in files), files
    with_fixture(body)


@case
def remove_untracked_dir_keeps_nested_ignored_file():
    # ㊲ 미추적 폴더 안의 ignore 파일(plan.md)도 백업한다
    def body(fx):
        p = fx.add('unf', commit=True, merge=True)
        fx.write('unf', 'newdir/a.txt', 'a\n')
        fx.write('unf', 'newdir/plan.md', '# plan\n')
        rc, out, err = fx.remove('--no-karina', p)
        assert rc == 0 and out.startswith('RESULT: removed 1'), (out, err)
        files = fx.backup_files()
        assert any(f.endswith('newdir/a.txt') for f in files) and any(f.endswith('newdir/plan.md') for f in files), files
    with_fixture(body)


@case
def remove_untracked_dir_with_nested_ignored_dir():
    # ㊳ 미추적 폴더 안의 (목록 밖) ignore 폴더는 상한 이하면 함께 백업된다
    def body(fx):
        p = fx.add('und', commit=True, merge=True)
        fx.write('und', 'newdir/a.txt', 'a\n')
        fx.write('und', 'newdir/bigdir/b.txt', 'b\n')
        rc, out, err = fx.remove('--no-karina', p)
        assert rc == 0 and out.startswith('RESULT: removed 1'), (out, err)
        files = fx.backup_files()
        assert any(f.endswith('newdir/a.txt') for f in files) and any(f.endswith('newdir/bigdir/b.txt') for f in files), files
    with_fixture(body)


@case
def remove_untracked_dir_caps_nested_ignored_dir():
    # ㊴ 미추적 폴더 안의 ignore 폴더에도 상한이 걸린다 — 부모 폴더 복사에 섞여 상한을 비켜 가지 않는다
    def body(fx):
        p = fx.add('unc', commit=True, merge=True)
        fx.write('unc', 'newdir/a.txt', 'a\n')
        fx.write('unc', 'newdir/bigdir/b.txt', 'b' * 4096)
        rc, out, err = fx.remove('--no-karina', '--ignored-dir-cap-mb', '0.001', p)
        assert rc == 0 and out.startswith('RESULT: removed 1'), (out, err)
        assert any(l.startswith('SKIP') and 'bigdir' in l for l in out.splitlines()), out
        files = fx.backup_files()
        assert any(f.endswith('newdir/a.txt') for f in files) and not any(f.endswith('b.txt') for f in files), files
    with_fixture(body)


# ---- Karina CLI: 가짜 CLI 가 받은 인자를 로그에 남기고, 설정대로 응답한다 ----

FAKE_KARINA = r'''
import json, os, subprocess, sys
here = os.path.dirname(os.path.abspath(__file__))
cfg = json.load(open(os.path.join(here, 'karina.json'), encoding='utf-8'))
with open(os.path.join(here, 'karina.log'), 'a', encoding='utf-8') as f:
    f.write(' '.join(sys.argv[1:]) + '\n')
if cfg.get('unavailable'):
    print(json.dumps({'id': '1', 'ok': False, 'error': {'code': 'runtime_unavailable', 'message': 'down'}}))
    sys.exit(1)
sel = sys.argv[sys.argv.index('--worktree') + 1][len('path:'):]
known = [os.path.normcase(os.path.abspath(p)) for p in cfg['managed']]
if os.path.normcase(os.path.abspath(sel)) not in known:
    print(json.dumps({'id': '1', 'ok': False, 'error': {'code': 'selector_not_found', 'message': 'x'}}))
    sys.exit(1)
if sys.argv[2] == 'rm':
    subprocess.run(['git', '-C', cfg['repo'], 'worktree', 'remove', '--force', sel], check=True)
print(json.dumps({'id': '1', 'ok': True, 'result': {}}))
'''


def fake_karina(fx, managed=(), unavailable=False):
    d = os.path.join(fx.root, 'fake')
    os.makedirs(d, exist_ok=True)
    with open(os.path.join(d, 'karina.json'), 'w', encoding='utf-8') as f:
        json.dump({'managed': list(managed), 'unavailable': unavailable, 'repo': fx.repo}, f)
    script = os.path.join(d, 'karina.py')
    with open(script, 'w', encoding='utf-8') as f:
        f.write(FAKE_KARINA)
    return script, os.path.join(d, 'karina.log')


def log_text(log):
    return open(log, encoding='utf-8').read() if os.path.exists(log) else ''


@case
def remove_uses_karina_for_managed():
    # ㉜ Karina 가 아는 worktree 는 백업 뒤 karina worktree rm 으로 지운다
    def body(fx):
        p = fx.add('km', commit=True, merge=True)
        fx.write('km', 'plan.md', '# plan\n')
        cli, log = fake_karina(fx, managed=[p])
        rc, out, err = fx.remove('--karina-cli', cli, p)
        assert rc == 0, (out, err)
        assert 'worktree rm --worktree path:' in log_text(log) and '--force --json' in log_text(log), log_text(log)
        assert any(f.endswith('/plan.md') for f in fx.backup_files()) and not fx.is_listed(p)
    with_fixture(body)


@case
def remove_falls_back_to_git_when_unknown():
    # ㉝ selector_not_found 면 git 으로 지운다
    def body(fx):
        p = fx.add('ku', commit=True, merge=True)
        cli, log = fake_karina(fx, managed=[])
        rc, out, err = fx.remove('--karina-cli', cli, p)
        assert rc == 0, (out, err)
        assert 'worktree show' in log_text(log) and 'worktree rm' not in log_text(log), log_text(log)
        assert not fx.is_listed(p)
    with_fixture(body)


@case
def remove_fails_when_karina_down():
    # ㉞ runtime_unavailable 이면 그 경로를 실패로 두고 지우지 않는다
    def body(fx):
        p = fx.add('kd', commit=True, merge=True)
        cli, _ = fake_karina(fx, unavailable=True)
        rc, out, _ = fx.remove('--karina-cli', cli, p)
        assert rc == 1 and 'FAILED' in out and 'runtime_unavailable' in out, out
        assert fx.is_listed(p) and os.path.exists(p)
    with_fixture(body)


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    failed = 0
    for fn in CASES:
        try:
            fn()
            print('PASS', fn.__name__)
        except (Exception, SystemExit) as e:  # 케이스 하나의 실패가 나머지 판정을 막지 않게 한다
            failed += 1
            print('FAIL', fn.__name__, '-', type(e).__name__, str(e)[:300])
    print('%d/%d PASS · FAIL %d' % (len(CASES) - failed, len(CASES), failed))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
