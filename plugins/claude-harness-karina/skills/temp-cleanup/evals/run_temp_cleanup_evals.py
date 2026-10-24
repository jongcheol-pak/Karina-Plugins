"""temp-cleanup 스크립트(scripts/temp_cleanup.py) 골든.

실제 사용자 임시 폴더를 건드리지 않는다 — 케이스마다 임시 디렉터리를 만들어 --root 로 넘긴다.
목록·시험 실행·삭제·거부(루트 자체·루트 밖·`..` 탈출·7일 이내 체인 잠금)·read-only 삭제를 잰다.
"""
import os
import shutil
import stat
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, '..', 'scripts', 'temp_cleanup.py')
DAY = 86400
NOW = 1_000_000_000

CASES = []


def case(fn):
    CASES.append(fn)
    return fn


def _onerror(func, path, _exc):
    os.chmod(path, stat.S_IWRITE)
    func(path)


class Fixture:
    """임시 디렉터리 아래 karina-plugin 루트와 그 밖의 파일 하나를 둔다."""

    def __init__(self):
        self.base = os.path.realpath(tempfile.mkdtemp(prefix='tcl-'))
        self.root = os.path.join(self.base, 'karina-plugin')
        os.makedirs(self.root)

    def put(self, rel, days_ago=0, folder=False):
        p = os.path.join(self.root, rel) if not rel.startswith('..') else os.path.join(self.base, rel[3:])
        os.makedirs(os.path.dirname(p), exist_ok=True)
        if folder:
            os.makedirs(p, exist_ok=True)
            with open(os.path.join(p, 'a.txt'), 'w', encoding='utf-8') as f:
                f.write('abc')
        else:
            with open(p, 'w', encoding='utf-8') as f:
                f.write('abcd')
        t = NOW - days_ago * DAY
        os.utime(p, (t, t))
        return p

    def run(self, *args):
        cmd = [sys.executable, SCRIPT, args[0], '--root', self.root, '--now', str(NOW)] + list(args[1:])
        p = subprocess.run(cmd, capture_output=True, timeout=60)
        return p.returncode, p.stdout.decode('utf-8', 'replace'), p.stderr.decode('utf-8', 'replace')

    def close(self):
        shutil.rmtree(self.base, onerror=_onerror)


def with_fixture(body):
    fx = Fixture()
    try:
        body(fx)
    finally:
        fx.close()


@case
def list_shows_items_per_folder():
    def body(fx):
        fx.put('backup/plan-x-repo-20261001-1200.md', 20)
        fx.put('verify/notes/run1', 3, folder=True)
        fx.put('scratch/s.ps1', 1)
        rc, out, err = fx.run('list')
        assert rc == 0, (rc, err)
        assert out.startswith('RESULT: list · 3 items'), out
        assert 'ITEM backup/plan-x-repo-20261001-1200.md' in out, out
        assert 'ITEM verify/notes/run1' in out, out
        assert 'ITEM scratch/s.ps1' in out, out
    with_fixture(body)


@case
def list_missing_root_is_empty():
    def body(fx):
        shutil.rmtree(fx.root)
        rc, out, err = fx.run('list')
        assert rc == 0 and out.startswith('RESULT: list · 0 items'), (rc, out, err)
    with_fixture(body)


@case
def dry_run_keeps_files():
    def body(fx):
        p = fx.put('scratch/old.ps1', 30)
        rc, out, _ = fx.run('remove', '--dry-run', p)
        assert rc == 0 and out.startswith('RESULT: dry-run · would remove 1 · refused 0'), out
        assert os.path.exists(p)
    with_fixture(body)


@case
def remove_inside_root():
    def body(fx):
        f = fx.put('backup/plan-old.md', 40)
        d = fx.put('worktree-backup/repo/wt-1', 40, folder=True)
        rc, out, _ = fx.run('remove', f, d)
        assert rc == 0 and out.startswith('RESULT: removed 2 · refused 0 · failed 0'), out
        assert not os.path.exists(f) and not os.path.exists(d)
    with_fixture(body)


@case
def remove_whole_subfolder():
    def body(fx):
        fx.put('plan-variants/20261001-1000/v1.html', 5)
        sub = os.path.join(fx.root, 'plan-variants')
        rc, out, _ = fx.run('remove', sub)
        assert rc == 0 and not os.path.exists(sub), out
    with_fixture(body)


@case
def refuse_root_itself():
    def body(fx):
        rc, out, _ = fx.run('remove', fx.root)
        assert rc == 1 and 'REFUSED' in out and os.path.isdir(fx.root), out
    with_fixture(body)


@case
def refuse_outside_root():
    def body(fx):
        p = fx.put('../stray.txt', 60)
        rc, out, _ = fx.run('remove', p)
        assert rc == 1 and 'REFUSED' in out and os.path.exists(p), out
    with_fixture(body)


@case
def refuse_dotdot_escape():
    def body(fx):
        p = fx.put('../stray.txt', 60)
        sneaky = os.path.join(fx.root, 'scratch', '..', '..', 'stray.txt')
        rc, out, _ = fx.run('remove', sneaky)
        assert rc == 1 and 'REFUSED' in out and os.path.exists(p), out
    with_fixture(body)


@case
def removes_readonly_files():
    def body(fx):
        d = fx.put('backup/ro-folder', 40, folder=True)
        os.chmod(os.path.join(d, 'a.txt'), stat.S_IREAD)
        rc, out, _ = fx.run('remove', d)
        assert rc == 0 and not os.path.exists(d), out
    with_fixture(body)


@case
def refuse_young_chain_lock():
    # 잠금은 열어 둔 파일이 아니라 사용 중 판정이 나이뿐이다 — 7일 이내 잠금은 거부, 지난 잠금은 지운다.
    def body(fx):
        young = fx.put('chain/karina-chain-wait-x.lock', 1)
        old = fx.put('chain/karina-chain-verify-y.lock', 8)
        rc, out, _ = fx.run('remove', young, old)
        assert rc == 1 and 'REFUSED' in out, out
        assert os.path.exists(young) and not os.path.exists(old), out
        rc, out, _ = fx.run('list')
        assert 'chain/karina-chain-wait-x.lock' in out and '사용 중일 수 있음' in out, out
    with_fixture(body)


def main():
    ok = 0
    for fn in CASES:
        try:
            fn()
            ok += 1
            print('PASS %s' % fn.__name__)
        except Exception as e:  # noqa: BLE001 — 케이스 실패를 모두 모아 보고한다
            print('FAIL %s - %s %s' % (fn.__name__, type(e).__name__, str(e)[:400]))
    print('%d/%d PASS' % (ok, len(CASES)))
    return 0 if ok == len(CASES) else 1


if __name__ == '__main__':
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    sys.exit(main())
