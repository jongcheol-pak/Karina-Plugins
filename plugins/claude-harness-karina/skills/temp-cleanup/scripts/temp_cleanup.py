"""karina-plugin 임시 폴더의 목록과 삭제 — `karina:temp-cleanup` 이 부른다. 폴더 배치는 `../../TEMP-FILES.md`.

사용:
  python temp_cleanup.py list   [--root <경로>] [--now <epoch 초>]
  python temp_cleanup.py remove [--root <경로>] [--now <epoch 초>] [--dry-run] <경로…>

list — 첫 줄 `RESULT: list · N items · <합계 크기>`, 이어서 항목마다
  `ITEM <루트 기준 경로> · <크기> · <수정 시각 YYYY-MM-DD HH:MM>[ · 사용 중일 수 있음]`.
  항목은 하위 폴더의 자식이고, `verify`·`worktree-backup` 은 한 단계 더 내려간 자식(실행·worktree 단위)이다.
  루트가 없으면 `RESULT: list · 0 items · 0 B` 와 exit 0.
remove — 첫 줄 `RESULT: removed N · refused N · failed N`(--dry-run 이면 `RESULT: dry-run · would remove N · refused N`),
  이어서 경로마다 `REMOVED`·`WOULD-REMOVE`·`REFUSED <경로> — <사유>`·`FAILED <경로> — <사유>`.
  거부: 루트 자체 · 루트 밖(`..` 로 빠지는 경로 포함) · 없는 경로 · `chain` 의 7일 이내 `karina-chain-*.lock`(실행 중일 수 있음).
  read-only 파일은 권한을 풀고 지운다.
종료 코드: 0 전부 처리 · 1 거부·실패가 하나라도 있음 · 2 인자 오류.
"""
import argparse
import os
import stat
import shutil
import sys
import tempfile
import time

DEPTH2 = ('verify', 'worktree-backup')
LOCK_IN_USE_SEC = 7 * 24 * 3600


def default_root():
    return os.path.join(tempfile.gettempdir(), 'karina-plugin')


def size_of(path):
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


def human(n):
    for unit in ('B', 'KB', 'MB', 'GB'):
        if n < 1024 or unit == 'GB':
            return ('%d %s' % (n, unit)) if unit == 'B' else ('%.1f %s' % (n, unit))
        n /= 1024.0


def maybe_in_use(root, path, now):
    rel = os.path.relpath(path, root).replace('\\', '/')
    name = os.path.basename(path)
    if not (rel.startswith('chain/') and name.startswith('karina-chain-') and name.endswith('.lock')):
        return False
    try:
        return now - os.path.getmtime(path) < LOCK_IN_USE_SEC
    except OSError:
        return False


def items(root):
    out = []
    for sub in sorted(os.listdir(root)):
        p = os.path.join(root, sub)
        if not os.path.isdir(p):
            out.append(p)
            continue
        for child in sorted(os.listdir(p)):
            c = os.path.join(p, child)
            if sub in DEPTH2 and os.path.isdir(c):
                out += [os.path.join(c, g) for g in sorted(os.listdir(c))]
            else:
                out.append(c)
    return out


def cmd_list(args):
    if not os.path.isdir(args.root):
        print('RESULT: list · 0 items · 0 B')
        return 0
    rows, total = [], 0
    for p in items(args.root):
        n = size_of(p)
        total += n
        stamp = time.strftime('%Y-%m-%d %H:%M', time.localtime(os.path.getmtime(p)))
        mark = ' · 사용 중일 수 있음' if maybe_in_use(args.root, p, args.now) else ''
        rows.append('ITEM %s · %s · %s%s' % (os.path.relpath(p, args.root).replace('\\', '/'), human(n), stamp, mark))
    print('RESULT: list · %d items · %s' % (len(rows), human(total)))
    for r in rows:
        print(r)
    return 0


def refusal(root, path, now):
    """지울 수 없으면 사유, 지울 수 있으면 None."""
    real_root = os.path.normcase(os.path.realpath(root))
    real = os.path.normcase(os.path.realpath(path))
    if real == real_root:
        return '루트 자체는 지우지 않는다'
    try:
        inside = os.path.commonpath([real_root, real]) == real_root
    except ValueError:
        inside = False
    if not inside:
        return 'karina-plugin 루트 밖'
    if not os.path.lexists(path):
        return '없는 경로'
    if maybe_in_use(root, os.path.realpath(path), now):
        return '7일 이내 체인 잠금 — 실행 중일 수 있음'
    return None


def _force_writable(func, path, _exc):
    os.chmod(path, stat.S_IWRITE)
    func(path)


def delete(path):
    if os.path.isdir(path) and not os.path.islink(path):
        shutil.rmtree(path, onerror=_force_writable)
    else:
        try:
            os.remove(path)
        except PermissionError:
            os.chmod(path, stat.S_IWRITE)
            os.remove(path)


def cmd_remove(args):
    done, refused, failed, lines = 0, 0, 0, []
    for raw in args.paths:
        path = os.path.abspath(raw)
        why = refusal(args.root, path, args.now)
        if why:
            refused += 1
            lines.append('REFUSED %s — %s' % (path, why))
            continue
        if args.dry_run:
            done += 1
            lines.append('WOULD-REMOVE %s · %s' % (path, human(size_of(path))))
            continue
        try:
            delete(path)
        except OSError as e:
            failed += 1
            lines.append('FAILED %s — %s' % (path, e))
            continue
        if os.path.lexists(path):
            failed += 1
            lines.append('FAILED %s — 지운 뒤에도 남아 있다' % path)
            continue
        done += 1
        lines.append('REMOVED %s' % path)
    if args.dry_run:
        print('RESULT: dry-run · would remove %d · refused %d' % (done, refused))
    else:
        print('RESULT: removed %d · refused %d · failed %d' % (done, refused, failed))
    for line in lines:
        print(line)
    return 1 if refused or failed else 0


def main(argv=None):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    ap = argparse.ArgumentParser(description='karina-plugin 임시 폴더 목록·삭제')
    sub = ap.add_subparsers(dest='cmd', required=True)
    for name in ('list', 'remove'):
        p = sub.add_parser(name)
        p.add_argument('--root', default=default_root())
        p.add_argument('--now', type=float, default=None)
    sub.choices['remove'].add_argument('--dry-run', action='store_true')
    sub.choices['remove'].add_argument('paths', nargs='+')
    args = ap.parse_args(argv)
    if args.now is None:
        args.now = time.time()
    return cmd_list(args) if args.cmd == 'list' else cmd_remove(args)


if __name__ == '__main__':
    sys.exit(main())
