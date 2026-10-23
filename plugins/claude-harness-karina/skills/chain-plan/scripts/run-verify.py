"""karina:chain-plan 코디네이터 검증의 명령 래퍼 — Bash `run_in_background` 로 띄우고 끝날 때 결과 한 줄을 낸다.

사용: python run-verify.py --cwd <대상 레포> [--label <이름>] [옵션] -- <명령 argv…>

출력 — 진행 중 시도마다 `STEP <label> start (시도 k/N …)` 줄, 끝에 `RESULT: <갈래> — <다음 행동>` 한 줄,
이어 마지막 시도 출력의 끝 40줄. 판정은 `RESULT:` 줄로 한다(래퍼 exit 는 인자 오류 2, 그 밖 0).
- pass       명령이 exit 0 으로 끝났다.
- fail       명령이 0 아닌 exit 로 끝났다(코드를 싣는다 · 126/127 은 unrunnable).
- stalled    마지막 진행 시점부터 --stall-sec 동안 출력이 늘지 않고 CPU 증가가 --cpu-sec 미만인 일이
             --retries 회 재실행 뒤에도 되풀이됐다.
- deadline   (--deadline-sec — 사전 단계) 벽시계 시한에 닿았다. 멈춤 판정·재실행을 하지 않는다.
- overtime   (본체) 진행이 이어져도 --max-sec 에 닿았다. 재실행하지 않는다.
- superseded 같은 --cwd 의 새 래퍼가 잠금을 가져갔다. 이 결과는 판정에 쓰지 않는다.
- unrunnable 명령을 띄우지 못했거나(실행 파일 없음) exit 126/127 이다.

어느 갈래로 끝나든 명령이 남긴 자손 프로세스를 끝낸다(Windows 는 Job Object, 그 밖은 프로세스 그룹).
판정 근거는 `../references/run-verify-rationale.md` 가 정본이다.
"""
import argparse
import hashlib
import os
import shutil
import signal
import subprocess
import sys
import tempfile
import time

TAIL_LINES = 40
LOCK_PREFIX = 'karina-chain-verify-'
DEFAULT_STALL_SEC = 600
DEFAULT_CPU_SEC = 30
DEFAULT_POLL_SEC = 15
DEFAULT_MAX_SEC = 3 * 3600
UNRUNNABLE_EXITS = (126, 127)


class Parser(argparse.ArgumentParser):
    def error(self, message):
        self.print_usage(sys.stderr)
        sys.stderr.write('run-verify: 인자 오류 — %s\n' % message)
        sys.exit(2)


def parse_args(argv):
    p = Parser(prog='run-verify.py')
    p.add_argument('--cwd', required=True)
    p.add_argument('--label', default='verify')
    p.add_argument('--stall-sec', type=float, default=DEFAULT_STALL_SEC)
    p.add_argument('--cpu-sec', type=float, default=DEFAULT_CPU_SEC)
    p.add_argument('--poll-sec', type=float, default=DEFAULT_POLL_SEC)
    p.add_argument('--retries', type=int, default=1)
    p.add_argument('--max-sec', type=float, default=None)
    p.add_argument('--deadline-sec', type=float, default=None)
    p.add_argument('cmd', nargs=argparse.REMAINDER)
    opts = p.parse_args(argv)
    if opts.cmd[:1] == ['--']:
        opts.cmd = opts.cmd[1:]
    if not opts.cmd:
        p.error('실행할 명령이 없다 — `--` 뒤에 명령 argv 를 준다')
    if opts.max_sec is not None and opts.deadline_sec is not None:
        p.error('--max-sec 와 --deadline-sec 은 함께 줄 수 없다 — 사전 단계는 --deadline-sec 하나다')
    if opts.max_sec is None and opts.deadline_sec is None:
        opts.max_sec = DEFAULT_MAX_SEC
    return opts


def watch(proc, opts, clock, sleep, lock):
    """한 시도를 끝까지 지켜본다 — ('exit', 코드) · ('stalled',) · ('deadline',) · ('overtime',) · ('superseded',)."""
    start = clock()
    last_progress = start
    last_size = proc.output_size()
    last_cpu = proc.cpu()
    while True:
        code = proc.poll()
        if code is not None:
            return ('exit', code)
        if not lock.owned():
            return ('superseded',)
        now = clock()
        if opts.deadline_sec is not None:
            if now - start >= opts.deadline_sec:
                return ('deadline',)
        else:
            if now - start >= opts.max_sec:
                return ('overtime',)
            size = proc.output_size()
            cpu = proc.cpu()
            if size > last_size:
                last_size, last_progress, last_cpu = size, now, cpu
            elif cpu is not None and last_cpu is not None and cpu - last_cpu >= opts.cpu_sec:
                last_progress, last_cpu = now, cpu
            if now - last_progress >= opts.stall_sec:
                return ('stalled',)
        sleep(proc, opts.poll_sec)


def _result(kind, action, tail=()):
    return ['RESULT: %s — %s' % (kind, action)] + list(tail)


def run(opts, launch, clock, sleep, lock, emit):
    """시도를 돌려 RESULT 줄과 꼬리 줄을 돌려준다. sleep(proc, 초) 는 그 사이 자식이 끝나면 일찍 돌아와도 된다.
    emit 은 진행 중 STEP 줄을 받는다."""
    attempts = 1 if opts.deadline_sec is not None else 1 + max(opts.retries, 0)
    why = ''
    for k in range(1, attempts + 1):
        emit('STEP %s start (시도 %d/%d%s)' % (opts.label, k, attempts, why))
        try:
            proc = launch(opts.cmd, opts.cwd)
        except OSError as e:
            return _result('unrunnable', '명령을 띄우지 못했다(%s) — 미검증으로 적는다' % e)
        try:
            try:
                outcome = watch(proc, opts, clock, sleep, lock)
            finally:
                proc.terminate()
            tail = proc.tail(TAIL_LINES)
        finally:
            proc.discard()
        if outcome[0] == 'exit':
            code = outcome[1]
            if code == 0:
                return _result('pass', '통과 — 다음 명령으로 간다', tail)
            if code in UNRUNNABLE_EXITS:
                return _result('unrunnable', '실행 불가(exit %d) — 미검증으로 적는다' % code, tail)
            return _result('fail', '실패(exit %d) — 실패로 판정한다' % code, tail)
        if outcome[0] == 'deadline':
            return _result('deadline', '사전 단계 시한(%g초) — 그 계획의 검증을 미검증으로 적는다'
                           % opts.deadline_sec, tail)
        if outcome[0] == 'overtime':
            return _result('overtime', '최대 시간 초과(%g초) — 미검증으로 적고 다시 띄우지 않는다'
                           % opts.max_sec, tail)
        if outcome[0] == 'superseded':
            return _result('superseded', '같은 레포의 새 검증이 이어받았다 — 이 결과는 판정에 쓰지 않는다', tail)
        why = ' — 앞 시도 멈춤(%g초 동안 진행 없음)' % opts.stall_sec
    return _result('stalled', '멈춤 재현(재실행 %d회 뒤) — 미검증으로 적고 다음으로 간다'
                   % (attempts - 1), tail)


class FileLock:
    """--cwd 마다 시스템 임시 폴더에 둔 파일 하나. 같은 레포의 새 래퍼가 자기 표식을 덮어쓰면 앞 래퍼는 물러난다."""

    def __init__(self, cwd):
        key = hashlib.sha1(os.path.normcase(os.path.abspath(cwd)).encode('utf-8')).hexdigest()[:16]
        self.path = os.path.join(tempfile.gettempdir(), '%s%s.lock' % (LOCK_PREFIX, key))
        self.token = '%d-%d' % (os.getpid(), time.time_ns())
        with open(self.path, 'w', encoding='utf-8') as f:
            f.write(self.token)

    def owned(self):
        try:
            with open(self.path, encoding='utf-8') as f:
                return f.read() == self.token
        except OSError:
            return False

    def release(self):
        # 아직 자기 것일 때만 지운다 — 이어받은 새 래퍼의 잠금을 지우면 그 래퍼가 물러난다.
        if self.owned():
            try:
                os.remove(self.path)
            except OSError:
                pass


class _WinJob:
    """자식을 담는 Job Object — 누적 CPU 를 재고, 끝낼 때 고아 자손까지 한 번에 끝낸다."""

    def __init__(self):
        import ctypes
        from ctypes import wintypes
        self.ctypes = ctypes
        self.k32 = ctypes.WinDLL('kernel32', use_last_error=True)
        self.k32.CreateJobObjectW.restype = wintypes.HANDLE
        self.handle = self.k32.CreateJobObjectW(None, None)
        if not self.handle:
            raise OSError(ctypes.get_last_error(), 'CreateJobObjectW 실패')

        class BasicLimit(ctypes.Structure):
            _fields_ = [('PerProcessUserTimeLimit', ctypes.c_int64), ('PerJobUserTimeLimit', ctypes.c_int64),
                        ('LimitFlags', wintypes.DWORD), ('MinimumWorkingSetSize', ctypes.c_size_t),
                        ('MaximumWorkingSetSize', ctypes.c_size_t), ('ActiveProcessLimit', wintypes.DWORD),
                        ('Affinity', ctypes.c_size_t), ('PriorityClass', wintypes.DWORD),
                        ('SchedulingClass', wintypes.DWORD)]

        class IoCounters(ctypes.Structure):
            _fields_ = [(n, ctypes.c_uint64) for n in ('ReadOperationCount', 'WriteOperationCount',
                                                       'OtherOperationCount', 'ReadTransferCount',
                                                       'WriteTransferCount', 'OtherTransferCount')]

        class ExtendedLimit(ctypes.Structure):
            _fields_ = [('BasicLimitInformation', BasicLimit), ('IoInfo', IoCounters),
                        ('ProcessMemoryLimit', ctypes.c_size_t), ('JobMemoryLimit', ctypes.c_size_t),
                        ('PeakProcessMemoryUsed', ctypes.c_size_t), ('PeakJobMemoryUsed', ctypes.c_size_t)]

        info = ExtendedLimit()
        info.BasicLimitInformation.LimitFlags = 0x2000  # JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE
        if not self.k32.SetInformationJobObject(self.handle, 9, ctypes.byref(info), ctypes.sizeof(info)):
            raise OSError(ctypes.get_last_error(), 'SetInformationJobObject 실패')

    def assign(self, process_handle):
        if not self.k32.AssignProcessToJobObject(self.handle, int(process_handle)):
            raise OSError(self.ctypes.get_last_error(), 'AssignProcessToJobObject 실패')

    def cpu(self):
        ctypes = self.ctypes

        class Accounting(ctypes.Structure):
            _fields_ = [('TotalUserTime', ctypes.c_int64), ('TotalKernelTime', ctypes.c_int64),
                        ('ThisPeriodTotalUserTime', ctypes.c_int64), ('ThisPeriodTotalKernelTime', ctypes.c_int64),
                        ('TotalPageFaultCount', ctypes.c_uint32), ('TotalProcesses', ctypes.c_uint32),
                        ('ActiveProcesses', ctypes.c_uint32), ('TotalTerminatedProcesses', ctypes.c_uint32)]

        a = Accounting()
        if not self.k32.QueryInformationJobObject(self.handle, 1, ctypes.byref(a), ctypes.sizeof(a), None):
            return None
        return (a.TotalUserTime + a.TotalKernelTime) / 1e7  # 100ns 단위

    def terminate(self):
        self.k32.TerminateJobObject(self.handle, 1)

    def close(self):
        self.k32.CloseHandle(self.handle)


def _resume(process_handle):
    import ctypes
    ntdll = ctypes.WinDLL('ntdll')
    status = ntdll.NtResumeProcess(ctypes.c_void_p(int(process_handle)))
    if status != 0:
        raise OSError(status, 'NtResumeProcess 실패')


class RealProc:
    """명령 하나를 로그 파일로 출력을 받으며 띄운다."""

    def __init__(self, cmd, cwd):
        exe = shutil.which(cmd[0])
        if exe is None:
            raise FileNotFoundError(2, '실행 파일을 PATH 에서 찾지 못했다', cmd[0])
        fd, self.log_path = tempfile.mkstemp(prefix=LOCK_PREFIX, suffix='.log')
        self.log = os.fdopen(fd, 'wb')
        self.job = None
        argv = [exe] + list(cmd[1:])
        try:
            if os.name == 'nt':
                self.job = _WinJob()
                self.proc = subprocess.Popen(argv, cwd=cwd, stdin=subprocess.DEVNULL, stdout=self.log,
                                             stderr=subprocess.STDOUT, creationflags=0x4)  # CREATE_SUSPENDED
                try:
                    self.job.assign(self.proc._handle)
                finally:
                    _resume(self.proc._handle)
            else:
                self.proc = subprocess.Popen(argv, cwd=cwd, stdin=subprocess.DEVNULL, stdout=self.log,
                                             stderr=subprocess.STDOUT, start_new_session=True)
        except OSError:
            self.log.close()
            self.discard()
            if self.job:
                self.job.close()
            raise

    def poll(self):
        return self.proc.poll()

    def pause(self, sec):
        try:
            self.proc.wait(timeout=sec)
        except subprocess.TimeoutExpired:
            pass

    def output_size(self):
        try:
            return os.path.getsize(self.log_path)
        except OSError:
            return 0

    def cpu(self):
        return self.job.cpu() if self.job else None

    def terminate(self):
        if self.job:
            self.job.terminate()
        else:
            try:
                os.killpg(self.proc.pid, signal.SIGKILL)
            except OSError:
                pass
        try:
            self.proc.wait(timeout=30)
        except subprocess.TimeoutExpired:
            pass
        if self.job:
            self.job.close()
            self.job = None
        self.log.close()

    def tail(self, n):
        try:
            with open(self.log_path, encoding='utf-8', errors='replace') as f:
                return [l.rstrip('\r\n') for l in f.readlines()[-n:]]
        except OSError:
            return []

    def discard(self, wait_sec=5):
        # Job 을 비운 직후에는 끝난 자손이 로그 핸들을 아직 놓지 않아 Windows 가 삭제를 거부한다 — 그동안 다시 시도한다.
        deadline = time.monotonic() + wait_sec
        while True:
            try:
                os.remove(self.log_path)
                return
            except FileNotFoundError:
                return
            except OSError:
                if time.monotonic() >= deadline:
                    return
                time.sleep(0.1)


def main(argv):
    sys.stdout.reconfigure(encoding='utf-8', errors='replace')
    opts = parse_args(argv)

    def emit(line):
        print(line, flush=True)

    lock = FileLock(opts.cwd)
    try:
        lines = run(opts, RealProc, time.monotonic, lambda proc, sec: proc.pause(sec), lock, emit)
    finally:
        lock.release()
    for line in lines:
        print(line)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
