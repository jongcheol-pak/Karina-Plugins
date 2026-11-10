"""chain-plan 검증 래퍼(scripts/run-verify.py) 골든.

시계·잠금·자식 프로세스·git 을 가짜로 주입해 갈래(pass·fail·stalled·deadline·overtime·superseded·unrunnable·reused)마다
RESULT 줄과 종료 호출, --stamp 의 기록·재사용 조건을 잰다. 끝의 실프로세스 케이스만 실제로 띄운다 — 짧은 명령 ·
출력 없는 정지 · `$` 가 든 pwsh 파일 · 메인이 끝난 뒤 남은 손자 정리(Windows) · cp949 stdout 에서의 RESULT 줄 ·
임시 git 레포에서 기록 뒤 재사용.
"""
import importlib.util
import os
import shutil
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
SCRIPT = os.path.join(HERE, '..', 'scripts', 'run-verify.py')
CHAIN_DIR = os.path.join(tempfile.gettempdir(), 'karina-plugin', 'chain')

spec = importlib.util.spec_from_file_location('run_verify', SCRIPT)
rv = importlib.util.module_from_spec(spec)
spec.loader.exec_module(rv)


class Clock:
    """sleep 이 시계를 밀고 지금 자식의 단계를 하나 넘긴다."""

    def __init__(self):
        self.t = 0.0
        self.proc = None

    def now(self):
        return self.t

    def sleep(self, proc, d):
        self.t += d
        if self.proc:
            self.proc.tick()


class FakeProc:
    """steps[i] = (exit 코드 또는 None, 출력 바이트 수, 누적 CPU 초 또는 None). 마지막 단계는 계속 이어진다."""

    def __init__(self, steps, tail_lines=('끝 줄',)):
        self.steps = list(steps)
        self.i = 0
        self.terminated = 0
        self.discarded = 0
        self.tail_lines = list(tail_lines)
        self.log_path = 'fake.log'

    def _cur(self):
        return self.steps[min(self.i, len(self.steps) - 1)]

    def tick(self):
        self.i += 1

    def poll(self):
        return self._cur()[0]

    def output_size(self):
        return self._cur()[1]

    def cpu(self):
        return self._cur()[2]

    def terminate(self):
        self.terminated += 1

    def tail(self, n):
        return self.tail_lines[-n:]

    def discard(self):
        self.discarded += 1


class Launcher:
    """시도마다 procs 에서 하나씩 꺼낸다. 예외 객체면 띄우기 실패다."""

    def __init__(self, clock, procs):
        self.clock = clock
        self.procs = list(procs)
        self.calls = []

    def __call__(self, cmd, cwd):
        self.calls.append((list(cmd), cwd))
        p = self.procs.pop(0)
        if isinstance(p, BaseException):
            raise p
        self.clock.proc = p
        return p


class FakeLock:
    def __init__(self, owned_until=None):
        self.n = 0
        self.owned_until = owned_until
        self.released = 0

    def owned(self):
        self.n += 1
        return self.owned_until is None or self.n <= self.owned_until

    def release(self):
        self.released += 1


def idle(n, size=0, cpu=0.0):
    return [(None, size, cpu)] * n


def run(procs, argv=(), lock=None):
    clock = Clock()
    launch = Launcher(clock, procs)
    steps = []
    opts = rv.parse_args(list(argv) + ['--cwd', '.', '--label', 'v1', '--', 'bash', 'v1.sh'])
    lines = rv.run(opts, launch, clock.now, clock.sleep, lock or FakeLock(), steps.append)
    return lines, steps, launch


def result(lines):
    r = [l for l in lines if l.startswith('RESULT: ')]
    assert len(r) == 1, lines
    return r[0]


CASES = []


def case(fn):
    CASES.append(fn)
    return fn


@case
def pass_on_exit_zero():
    p = FakeProc(idle(3) + [(0, 10, 1.0)])
    lines, _, launch = run([p])
    assert result(lines).startswith('RESULT: pass — '), lines
    assert launch.calls == [(['bash', 'v1.sh'], '.')], launch.calls


@case
def fail_carries_exit_code():
    p = FakeProc([(3, 10, 1.0)])
    lines, _, _ = run([p])
    r = result(lines)
    assert r.startswith('RESULT: fail — ') and 'exit 3' in r, r


@case
def output_growth_resets_stall():
    # 30분 동안 15초마다 출력이 1바이트씩 늘고 CPU 는 0 — 멈춤이 아니다.
    steps = [(None, i, 0.0) for i in range(120)] + [(0, 200, 0.0)]
    lines, _, launch = run([FakeProc(steps)])
    assert result(lines).startswith('RESULT: pass — '), lines
    assert len(launch.calls) == 1


@case
def cpu_growth_resets_stall():
    # 출력 없이 15초마다 CPU 가 10초씩 쌓인다(3단계마다 30초 문턱) — 멈춤이 아니다.
    steps = [(None, 0, 10.0 * i) for i in range(120)] + [(0, 0, 1200.0)]
    lines, _, launch = run([FakeProc(steps)])
    assert result(lines).startswith('RESULT: pass — '), lines
    assert len(launch.calls) == 1


@case
def cpu_below_threshold_counts_as_stall():
    # 정지 상태 pwsh 처럼 15초마다 0.06초 — 10분이면 문턱 30초에 못 미친다.
    steps = [(None, 0, 0.06 * i) for i in range(200)]
    lines, _, _ = run([FakeProc(steps), FakeProc(steps)])
    assert result(lines).startswith('RESULT: stalled — '), lines


@case
def stall_terminates_and_retries_to_pass():
    first = FakeProc(idle(100))
    second = FakeProc(idle(2) + [(0, 5, 0.0)])
    lines, steps, launch = run([first, second])
    assert first.terminated >= 1, '멈춘 시도의 Job 을 끝내야 한다'
    assert len(launch.calls) == 2, launch.calls
    assert result(lines).startswith('RESULT: pass — '), lines


@case
def stall_twice_is_stalled():
    a, b = FakeProc(idle(100)), FakeProc(idle(100))
    lines, _, launch = run([a, b])
    r = result(lines)
    assert r.startswith('RESULT: stalled — '), r
    assert a.terminated >= 1 and b.terminated >= 1
    assert len(launch.calls) == 2, '재실행은 1회뿐이다'


@case
def stall_detected_within_window():
    clock = Clock()
    p = FakeProc(idle(1000))
    launch = Launcher(clock, [p])
    opts = rv.parse_args(['--retries', '0', '--cwd', '.', '--', 'bash', 'x.sh'])
    lines = rv.run(opts, launch, clock.now, clock.sleep, FakeLock(), lambda s: None)
    assert result(lines).startswith('RESULT: stalled — '), lines
    assert 600 <= clock.t <= 615, clock.t


@case
def deadline_terminates_without_stall_check():
    # 출력이 계속 늘어도 사전 단계 시한 120초에 닿으면 끝낸다 — 재실행 없음.
    steps = [(None, i, 0.0) for i in range(100)]
    p = FakeProc(steps)
    lines, _, launch = run([p], ['--deadline-sec', '120'])
    assert result(lines).startswith('RESULT: deadline — '), lines
    assert p.terminated >= 1 and len(launch.calls) == 1


@case
def deadline_ignores_stall():
    # 진행이 없어도 시한 전에는 멈춤으로 보지 않는다(시한이 멈춤 창보다 길 때).
    p = FakeProc(idle(60) + [(0, 0, 0.0)])
    lines, _, _ = run([p], ['--deadline-sec', '1200'])
    assert result(lines).startswith('RESULT: pass — '), lines


@case
def unrunnable_on_launch_error():
    lines, _, launch = run([FileNotFoundError(2, '없음')])
    assert result(lines).startswith('RESULT: unrunnable — '), lines
    assert len(launch.calls) == 1


@case
def unrunnable_on_exit_127():
    lines, _, _ = run([FakeProc([(127, 0, 0.0)])])
    assert result(lines).startswith('RESULT: unrunnable — '), lines


@case
def terminate_after_pass_and_fail():
    a = FakeProc([(0, 1, 0.0)])
    run([a])
    b = FakeProc([(1, 1, 0.0)])
    run([b])
    assert a.terminated >= 1 and b.terminated >= 1, '끝난 뒤 남은 자손을 정리해야 한다'


@case
def tail_attached_after_result():
    p = FakeProc([(1, 1, 0.0)], tail_lines=['줄%d' % i for i in range(60)])
    lines, _, _ = run([p])
    assert lines[0].startswith('RESULT: '), lines[:2]
    assert '줄59' in lines and '줄20' in lines and '줄19' not in lines, lines


@case
def bad_args_exit_2_with_message():
    p = subprocess.run([sys.executable, SCRIPT, '--cwd', '.'], capture_output=True,
                       encoding='utf-8', errors='replace', timeout=60)
    assert p.returncode == 2, p.returncode
    assert '실행할 명령' in p.stderr, p.stderr[-300:]


@case
def step_lines_on_start_and_retry():
    lines, steps, _ = run([FakeProc(idle(100)), FakeProc([(0, 1, 0.0)])])
    assert len(steps) == 2, steps
    assert steps[0].startswith('STEP v1 start') and '1/2' in steps[0], steps
    assert '2/2' in steps[1] and '멈춤' in steps[1], steps


@case
def overtime_even_with_progress():
    steps = [(None, i, 0.0) for i in range(2000)]
    p = FakeProc(steps)
    lines, _, launch = run([p], ['--max-sec', '3000'])
    assert result(lines).startswith('RESULT: overtime — '), lines
    assert p.terminated >= 1 and len(launch.calls) == 1, '최대 시간 초과는 재실행하지 않는다'


@case
def max_and_deadline_together_rejected():
    p = subprocess.run([sys.executable, SCRIPT, '--max-sec', '10', '--deadline-sec', '5', '--cwd', '.',
                        '--', 'bash', 'x.sh'], capture_output=True, encoding='utf-8', errors='replace', timeout=60)
    assert p.returncode == 2, p.returncode
    assert '함께 줄 수 없다' in p.stderr, p.stderr[-300:]


@case
def lock_lost_is_superseded():
    p = FakeProc(idle(100))
    lock = FakeLock(owned_until=3)
    lines, _, launch = run([p], lock=lock)
    assert result(lines).startswith('RESULT: superseded — '), lines
    assert p.terminated >= 1 and len(launch.calls) == 1


@case
def file_lock_releases_only_own():
    d = tempfile.mkdtemp()
    try:
        cwd = os.path.join(d, 'repo')
        os.mkdir(cwd)
        a = rv.FileLock(cwd)
        b = rv.FileLock(cwd)          # 같은 레포의 새 래퍼가 이어받는다
        assert not a.owned() and b.owned()
        a.release()                   # 앞 래퍼가 끝나도 새 래퍼의 잠금은 남는다
        assert b.owned() and os.path.exists(b.path)
        b.release()
        assert not os.path.exists(b.path)
        c = rv.FileLock(os.path.join(d, 'other'))
        assert c.path != b.path, '레포가 다르면 잠금이 갈린다'
        assert os.path.dirname(c.path) == CHAIN_DIR, c.path
        c.release()
    finally:
        shutil.rmtree(d, ignore_errors=True)


@case
def sweep_removes_week_old_verify_files():
    # 7일 지난 karina-chain-verify-* 만 지운다 — 7일 이내 파일과 다른 접두 파일은 남긴다.
    d = tempfile.mkdtemp(prefix='karina-verify-eval-')
    now = 1_000_000_000.0
    files = {'karina-chain-verify-a.lock': 8, 'karina-chain-verify-b.log': 8, 'karina-chain-verify-c.lock': 1,
             'karina-chain-run_x-decisions.md': 8}
    try:
        for name, days in files.items():
            p = os.path.join(d, name)
            with open(p, 'w', encoding='utf-8') as f:
                f.write('x')
            os.utime(p, (now - days * 86400, now - days * 86400))
        rv.sweep_stale(d, now)
        assert sorted(os.listdir(d)) == ['karina-chain-run_x-decisions.md', 'karina-chain-verify-c.lock'], os.listdir(d)
    finally:
        shutil.rmtree(d)


class FakeGit:
    """git(cwd, args) → (exit, stdout). diff 는 '<기록 HEAD>..<HEAD>' 범위마다 바뀐 경로, refs 는 문자열 리터럴로 참조되는 파일 이름."""

    def __init__(self, head='a' * 40, dirty=(), top='/repo', prefix='', diff=None, refs=(), fail=False):
        self.head, self.dirty, self.top, self.prefix = head, list(dirty), top, prefix
        self.diff, self.refs, self.fail = diff or {}, set(refs), fail
        self.calls = []

    def __call__(self, cwd, args):
        self.calls.append(list(args))
        if self.fail:
            return 128, ''
        if args[:2] == ['rev-parse', 'HEAD']:
            return 0, self.head
        if args[:2] == ['rev-parse', '--show-toplevel']:
            return 0, self.top
        if args[:2] == ['rev-parse', '--show-prefix']:
            return 0, self.prefix
        if args[0] == 'status':
            return 0, '\n'.join(' M ' + p for p in self.dirty)
        if args[0] == 'diff':
            rng = [a for a in args if '..' in a][0]
            return 0, '\n'.join(self.diff.get(rng, []))
        if args[0] == 'grep':
            pats = [args[i + 1] for i, a in enumerate(args) if a == '-e']
            return (0, 'src/x.rs') if any(p[:-1] in self.refs for p in pats) else (1, '')
        raise AssertionError('예상하지 못한 git 호출: %s' % args)


PASS_LINES = ['RESULT: pass — 통과 — 다음 명령으로 간다', '꼬리 1', '꼬리 2']


def stamped(git, argv=(), run_lines=PASS_LINES, folder=None, cmd=('bash', 'v1.sh'), cwd='.'):
    folder = folder or tempfile.mkdtemp(prefix='karina-stamp-eval-')
    opts = rv.parse_args(['--stamp'] + list(argv) + ['--cwd', cwd, '--'] + list(cmd))
    calls, out = [], []

    def run_fn():
        calls.append(1)
        return run_lines() if callable(run_lines) else list(run_lines)

    lines = rv.run_stamped(opts, git, run_fn, out.append, folder)
    return lines, out, calls, folder


def stamp_files(folder):
    return [f for f in os.listdir(folder) if f.startswith('karina-chain-verify-stamp-')]


def seeded(git, argv=(), cmd=('bash', 'v1.sh')):
    """같은 폴더에 기록 하나를 남겨 두고 그 폴더를 돌려준다(기록 HEAD = git.head)."""
    _, _, calls, folder = stamped(git, argv, cmd=cmd)
    assert calls == [1] and stamp_files(folder), '기록이 남지 않았다'
    return folder


H1, H2 = 'a' * 40, 'b' * 40


@case
def stamp_written_on_pass():
    git = FakeGit()
    lines, _, calls, folder = stamped(git)
    try:
        assert result(lines).startswith('RESULT: pass — ') and calls == [1], lines
        files = stamp_files(folder)
        assert len(files) == 1, files
        with open(os.path.join(folder, files[0]), encoding='utf-8') as f:
            text = f.read()
        assert H1 in text and '꼬리 2' in text, text
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def stamp_skipped_on_fail():
    lines, out, _, folder = stamped(FakeGit(), run_lines=['RESULT: fail — 실패(exit 1) — 실패로 판정한다'])
    try:
        assert any(l.startswith('STAMP: 기록 안 함 — ') for l in out), out
        assert not stamp_files(folder)
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def stamp_skipped_when_tree_dirty():
    lines, out, _, folder = stamped(FakeGit(dirty=['src/a.rs']))
    try:
        assert any(l.startswith('STAMP: 기록 안 함 — ') for l in out), out
        assert not stamp_files(folder)
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def stamp_written_when_only_plan_dirty():
    git = FakeGit(prefix='sub/', dirty=['sub/plan.md', 'sub/notes.md'])
    _, out, _, folder = stamped(git)
    try:
        assert len(stamp_files(folder)) == 1, out
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def stamp_skipped_when_head_moves_during_run():
    git = FakeGit()

    def moving():
        git.head = H2
        return list(PASS_LINES)

    _, out, _, folder = stamped(git, run_lines=moving)
    try:
        assert any(l.startswith('STAMP: 기록 안 함 — ') for l in out), out
        assert not stamp_files(folder)
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def reuse_same_head_skips_run():
    git = FakeGit()
    folder = seeded(git)
    try:
        lines, _, calls, _ = stamped(git, folder=folder)
        r = result(lines)
        assert r.startswith('RESULT: reused — ') and H1[:7] in r, lines
        assert calls == [], '재사용인데 명령을 띄웠다'
        assert '꼬리 2' in lines, '기록된 꼬리를 다시 내야 기대값을 대조한다'
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def reuse_same_head_dirty_runs():
    git = FakeGit()
    folder = seeded(git)
    try:
        git.dirty = ['src/a.rs']
        lines, _, calls, _ = stamped(git, folder=folder)
        assert calls == [1] and result(lines).startswith('RESULT: pass — '), lines
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def reuse_other_head_runs():
    git = FakeGit()
    folder = seeded(git)
    try:
        git.head = H2
        git.diff = {H1 + '..' + H2: ['src/a.rs']}
        lines, _, calls, _ = stamped(git, ['--reuse-docs'], folder=folder)
        assert calls == [1], lines
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def reuse_docs_only_with_flag():
    git = FakeGit()
    folder = seeded(git)
    try:
        git.head = H2
        git.diff = {H1 + '..' + H2: ['docs/plans/deferred.md', 'docs/conventions.md', 'plan.md']}
        lines, _, calls, _ = stamped(git, ['--reuse-docs'], folder=folder)
        assert calls == [] and result(lines).startswith('RESULT: reused — '), lines
        assert any('--no-renames' in c for c in git.calls if c[0] == 'diff'), git.calls
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def reuse_docs_only_without_flag_runs():
    git = FakeGit()
    folder = seeded(git)
    try:
        git.head = H2
        git.diff = {H1 + '..' + H2: ['docs/conventions.md']}
        _, _, calls, _ = stamped(git, folder=folder)
        assert calls == [1]
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def reuse_docs_agents_md_runs():
    git = FakeGit()
    folder = seeded(git)
    try:
        git.head = H2
        git.diff = {H1 + '..' + H2: ['AGENTS.md']}
        _, _, calls, _ = stamped(git, ['--reuse-docs'], folder=folder)
        assert calls == [1]
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def reuse_docs_literal_reference_runs():
    git = FakeGit(refs=['case.txt'])
    folder = seeded(git)
    try:
        git.head = H2
        git.diff = {H1 + '..' + H2: ['src/fixtures/case.txt']}
        _, _, calls, _ = stamped(git, ['--reuse-docs'], folder=folder)
        assert calls == [1]
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def reuse_docs_rename_counts_both_paths():
    git = FakeGit()
    folder = seeded(git)
    try:
        git.head = H2
        git.diff = {H1 + '..' + H2: ['src/a.rs', 'docs/a.md']}
        _, _, calls, _ = stamped(git, ['--reuse-docs'], folder=folder)
        assert calls == [1]
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def reuse_git_failure_runs():
    lines, out, calls, folder = stamped(FakeGit(fail=True))
    try:
        assert calls == [1] and result(lines).startswith('RESULT: pass — '), lines
        assert not stamp_files(folder)
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def command_key_follows_file_content():
    d = tempfile.mkdtemp()
    try:
        a, b, c = (os.path.join(d, n) for n in ('w.sh', 'c.sh', 'x.sh'))
        for p, body in ((a, 'cargo test\r\n'), (b, '  cargo test\n'), (c, 'cargo clippy\n')):
            with open(p, 'w', encoding='utf-8', newline='') as f:
                f.write(body)
        assert rv.command_key(['bash', a], d) == rv.command_key(['bash', b], d), '경로·줄바꿈만 다르면 같은 키'
        assert rv.command_key(['bash', a], d) != rv.command_key(['bash', c], d), '내용이 다르면 다른 키'
    finally:
        shutil.rmtree(d, ignore_errors=True)


@case
def stamp_file_keyed_by_git_toplevel():
    folder = tempfile.mkdtemp(prefix='karina-stamp-eval-')
    try:
        git = FakeGit(top='D:/r', prefix='')
        p1 = rv.stamp_file('/d/r', git, folder)
        p2 = rv.stamp_file('D:\\r', git, folder)
        assert p1 == p2, '작업 폴더 표기가 달라도 같은 레포·폴더면 같은 기록'
        assert os.path.dirname(p1) == folder and os.path.basename(p1).startswith('karina-chain-verify-stamp-'), p1
        assert rv.stamp_file('/d/r', FakeGit(top='D:/r', prefix='sub/'), folder) != p1, '작업 폴더가 다르면 갈린다'
    finally:
        shutil.rmtree(folder, ignore_errors=True)


@case
def reuse_docs_needs_stamp():
    p = subprocess.run([sys.executable, SCRIPT, '--reuse-docs', '--cwd', '.', '--', 'bash', 'x.sh'],
                       capture_output=True, encoding='utf-8', errors='replace', timeout=60)
    assert p.returncode == 2 and '--stamp' in p.stderr, (p.returncode, p.stderr[-300:])


def _wrap(args, cwd, env=None, timeout=90):
    return subprocess.run([sys.executable, SCRIPT, '--cwd', cwd] + args, capture_output=True,
                          env=env, timeout=timeout)


@case
def real_short_command_passes():
    d = tempfile.mkdtemp()
    try:
        p = _wrap(['--label', 'py', '--', sys.executable, '-c', 'print("안녕 ok")'], d)
        text = p.stdout.decode('utf-8', errors='replace')
        assert p.returncode == 0, p.stderr[-300:]
        assert 'RESULT: pass — ' in text and '안녕 ok' in text, text[-500:]
    finally:
        shutil.rmtree(d, ignore_errors=True)


def _verify_logs():
    if not os.path.isdir(CHAIN_DIR):
        return set()
    return {f for f in os.listdir(CHAIN_DIR) if f.startswith('karina-chain-verify-') and f.endswith('.log')}


@case
def watch_error_still_discards_log():
    class Broken(FakeProc):
        def poll(self):
            raise KeyboardInterrupt

    p = Broken(idle(1))
    try:
        run([p])
        raise AssertionError('watch 예외가 삼켜졌다')
    except KeyboardInterrupt:
        pass
    assert p.terminated == 1 and p.discarded == 1, (p.terminated, p.discarded)


@case
def real_launch_failure_removes_log():
    d = tempfile.mkdtemp()
    orig = rv.subprocess.Popen

    def fail(*a, **k):
        raise OSError(5, '가짜 Popen 실패')

    try:
        before = _verify_logs()
        rv.subprocess.Popen = fail
        try:
            rv.RealProc([sys.executable, '-c', 'pass'], d)
            raise AssertionError('Popen 실패가 전파되지 않았다')
        except OSError:
            pass
        finally:
            rv.subprocess.Popen = orig
        left = _verify_logs() - before
        assert not left, '띄우기 실패 뒤 시도 로그가 임시 폴더에 남았다: %s' % sorted(left)
    finally:
        shutil.rmtree(d, ignore_errors=True)


@case
def real_non_utf8_tail_and_log_removed():
    d = tempfile.mkdtemp()
    try:
        before = _verify_logs()
        code = 'import sys; sys.stdout.buffer.write(b"\\xff\\xfe tail-ok\\n")'
        p = _wrap(['--', sys.executable, '-c', code], d)
        text = p.stdout.decode('utf-8', errors='strict')
        assert p.returncode == 0, p.stderr[-300:]
        assert 'RESULT: pass — ' in text and 'tail-ok' in text, text[-500:]
        left = _verify_logs() - before
        assert not left, '시도 로그가 임시 폴더에 남았다: %s' % sorted(left)
    finally:
        shutil.rmtree(d, ignore_errors=True)


@case
def real_silent_sleep_stalls():
    d = tempfile.mkdtemp()
    try:
        p = _wrap(['--poll-sec', '0.2', '--stall-sec', '1.5', '--',
                   sys.executable, '-c', 'import time; time.sleep(60)'], d)
        text = p.stdout.decode('utf-8', errors='replace')
        assert 'RESULT: stalled — ' in text, text[-500:]
    finally:
        shutil.rmtree(d, ignore_errors=True)


@case
def real_pwsh_file_keeps_dollar():
    if not shutil.which('pwsh'):
        raise AssertionError('pwsh 가 없어 잴 수 없다')
    d = tempfile.mkdtemp()
    try:
        f = os.path.join(d, 'v.ps1')
        with open(f, 'w', encoding='utf-8') as fh:
            fh.write('$x = 41 + 1; Write-Output "value=$x"\n')
        p = _wrap(['--', 'pwsh', '-NoProfile', '-File', f], d)
        text = p.stdout.decode('utf-8', errors='replace')
        assert 'RESULT: pass — ' in text and 'value=42' in text, text[-500:]
    finally:
        shutil.rmtree(d, ignore_errors=True)


def _alive(pid):
    if os.name != 'nt':
        try:
            os.kill(pid, 0)
            return True
        except OSError:
            return False
    import ctypes
    k32 = ctypes.WinDLL('kernel32', use_last_error=True)
    k32.OpenProcess.restype = ctypes.c_void_p
    h = k32.OpenProcess(0x00100000, False, pid)  # SYNCHRONIZE
    if not h:
        return False
    try:
        return k32.WaitForSingleObject(ctypes.c_void_p(h), 0) == 0x102  # WAIT_TIMEOUT — 아직 살아 있다
    finally:
        k32.CloseHandle(ctypes.c_void_p(h))


@case
def real_leftover_grandchild_cleaned():
    d = tempfile.mkdtemp()
    pid_file = os.path.join(d, 'gc.pid')
    try:
        before = _verify_logs()
        code = ('import subprocess, sys; '
                'g = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(120)"]); '
                'open(%r, "w").write(str(g.pid))' % pid_file)
        p = _wrap(['--', sys.executable, '-c', code], d)
        text = p.stdout.decode('utf-8', errors='replace')
        assert 'RESULT: pass — ' in text, text[-500:]
        with open(pid_file, encoding='utf-8') as f:
            gpid = int(f.read())
        deadline = time.time() + 10
        while _alive(gpid) and time.time() < deadline:
            time.sleep(0.2)
        alive = _alive(gpid)
        if alive:
            os.kill(gpid, 9)
        assert not alive, '메인이 끝난 뒤 남은 손자가 래퍼 종료 뒤에도 살아 있다'
        left = _verify_logs() - before
        assert not left, '손자가 쥔 시도 로그가 임시 폴더에 남았다: %s' % sorted(left)
    finally:
        shutil.rmtree(d, ignore_errors=True)


@case
def real_result_survives_cp949_stdout():
    d = tempfile.mkdtemp()
    try:
        env = dict(os.environ, PYTHONIOENCODING='cp949')
        p = _wrap(['--', sys.executable, '-c', 'raise SystemExit(4)'], d, env=env)
        text = p.stdout.decode('utf-8', errors='strict')
        assert p.returncode == 0, (p.returncode, p.stderr[-400:])
        assert 'RESULT: fail — ' in text, text[-300:]
    finally:
        shutil.rmtree(d, ignore_errors=True)


@case
def real_git_stamp_then_reuse():
    d = tempfile.mkdtemp()
    try:
        g = ['git', '-C', d, '-c', 'user.name=eval', '-c', 'user.email=eval@example.invalid']
        subprocess.run(['git', 'init', '-q', d], check=True)
        with open(os.path.join(d, 'a.txt'), 'w', encoding='utf-8') as f:
            f.write('x\n')
        subprocess.run(g + ['add', 'a.txt'], check=True)
        subprocess.run(g + ['commit', '-q', '-m', 'init'], check=True)
        cmd = ['--stamp', '--', sys.executable, '-c', 'print("stamp-ok")']
        first = _wrap(cmd, d).stdout.decode('utf-8', errors='replace')
        second = _wrap(cmd, d).stdout.decode('utf-8', errors='replace')
        assert 'RESULT: pass — ' in first, first[-400:]
        assert 'RESULT: reused — ' in second and 'stamp-ok' in second, second[-400:]
    finally:
        try:
            os.remove(rv.stamp_file(d, rv.git_call, CHAIN_DIR))
        except (OSError, AttributeError):
            pass
        shutil.rmtree(d, ignore_errors=True)


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    failed = 0
    for fn in CASES:
        try:
            fn()
            print('PASS', fn.__name__)
        except (Exception, SystemExit) as e:  # 케이스 안의 SystemExit 이 러너를 끝내지 않게 한다
            failed += 1
            print('FAIL', fn.__name__, '-', type(e).__name__, str(e)[:300])
    print('%d/%d PASS' % (len(CASES) - failed, len(CASES)))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
