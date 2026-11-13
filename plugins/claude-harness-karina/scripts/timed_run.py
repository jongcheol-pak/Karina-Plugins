"""시간 상한을 건 자식 실행 — `subprocess.run` 과 같은 인자·반환·예외를 쓰되, 시간 초과면 손자까지 트리째 끝낸다.

`run(cmd, timeout, **kwargs)` 는 `subprocess.CompletedProcess` 를 돌려주고, 시간 초과면 트리를 끝낸 뒤
`subprocess.TimeoutExpired` 를 올린다. 정상 완료 때 자손은 건드리지 않는다.
Windows 는 Job Object(넣지 못하면 부모 PID·생성 시각으로 찾은 자손 트리), 그 밖은 새 세션의 프로세스 그룹으로 끝낸다.
"""
import os
import signal
import subprocess

OUTPUT_GRACE_SEC = 2
CREATE_SUSPENDED = 0x4
KILL_ON_JOB_CLOSE = 0x2000


class WinJob:
    """자식을 담는 Job Object — 누적 CPU 를 재고, 끝낼 때 고아 자손까지 한 번에 끝낸다."""

    def __init__(self, kill_on_close=True):
        import ctypes
        from ctypes import wintypes
        self.ctypes = ctypes
        self.k32 = ctypes.WinDLL('kernel32', use_last_error=True)
        self.k32.CreateJobObjectW.restype = wintypes.HANDLE
        self.handle = self.k32.CreateJobObjectW(None, None)
        if not self.handle:
            raise OSError(ctypes.get_last_error(), 'CreateJobObjectW 실패')
        if not kill_on_close:
            return

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
        info.BasicLimitInformation.LimitFlags = KILL_ON_JOB_CLOSE
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
        return (a.TotalUserTime + a.TotalKernelTime) / 1e7

    def terminate(self):
        self.k32.TerminateJobObject(self.handle, 1)

    def close(self):
        self.k32.CloseHandle(self.handle)


def resume_suspended(process_handle):
    import ctypes
    ntdll = ctypes.WinDLL('ntdll')
    status = ntdll.NtResumeProcess(ctypes.c_void_p(int(process_handle)))
    if status != 0:
        raise OSError(status, 'NtResumeProcess 실패')


def create_job():
    return WinJob(kill_on_close=False)


def run(cmd, timeout, **kwargs):
    if kwargs.pop('capture_output', False):
        kwargs['stdout'] = subprocess.PIPE
        kwargs['stderr'] = subprocess.PIPE
    if os.name == 'nt':
        return _run_windows(cmd, timeout, kwargs)
    return _run_posix(cmd, timeout, kwargs)


def _run_windows(cmd, timeout, kwargs):
    kwargs['creationflags'] = kwargs.get('creationflags', 0) | CREATE_SUSPENDED
    proc = subprocess.Popen(cmd, **kwargs)
    job = None
    try:
        try:
            job = create_job()
            job.assign(proc._handle)
        except OSError:
            if job:
                job.close()
            job = None
        resume_suspended(proc._handle)
    except BaseException:
        proc.kill()
        proc.wait()
        if job:
            job.close()
        raise
    try:
        out, err = proc.communicate(timeout=timeout)
    except BaseException as e:
        if job:
            job.terminate()
        else:
            _kill_tree_without_job(proc)
        out, err = _collect_rest(proc)
        if isinstance(e, subprocess.TimeoutExpired):
            raise subprocess.TimeoutExpired(proc.args, timeout, out, err) from None
        raise
    finally:
        if job:
            job.close()
    return subprocess.CompletedProcess(proc.args, proc.returncode, out, err)


def _run_posix(cmd, timeout, kwargs):
    kwargs['start_new_session'] = True
    proc = subprocess.Popen(cmd, **kwargs)
    try:
        out, err = proc.communicate(timeout=timeout)
    except BaseException as e:
        try:
            os.killpg(proc.pid, signal.SIGKILL)
        except OSError:
            pass
        out, err = _collect_rest(proc)
        if isinstance(e, subprocess.TimeoutExpired):
            raise subprocess.TimeoutExpired(proc.args, timeout, out, err) from None
        raise
    return subprocess.CompletedProcess(proc.args, proc.returncode, out, err)


def _collect_rest(proc):
    try:
        return proc.communicate(timeout=OUTPUT_GRACE_SEC)
    except subprocess.TimeoutExpired:
        return None, None


def _kill_tree_without_job(proc):
    import ctypes
    from ctypes import wintypes
    k32 = ctypes.WinDLL('kernel32', use_last_error=True)
    k32.OpenProcess.restype = wintypes.HANDLE
    k32.CreateToolhelp32Snapshot.restype = wintypes.HANDLE
    pending = [(proc.pid, _creation_time(k32, int(proc._handle)))]
    k32.TerminateProcess(wintypes.HANDLE(int(proc._handle)), 1)
    children = _parent_map(k32)
    while pending:
        parent, parent_born = pending.pop()
        if parent_born is None:
            continue
        for pid in children.get(parent, ()):
            h = k32.OpenProcess(0x1001, False, pid)
            if not h:
                continue
            try:
                born = _creation_time(k32, h)
                if born is not None and born >= parent_born:
                    k32.TerminateProcess(wintypes.HANDLE(h), 1)
                    pending.append((pid, born))
            finally:
                k32.CloseHandle(wintypes.HANDLE(h))


def _parent_map(k32):
    import ctypes
    from ctypes import wintypes

    class Entry(ctypes.Structure):
        _fields_ = [('dwSize', wintypes.DWORD), ('cntUsage', wintypes.DWORD), ('th32ProcessID', wintypes.DWORD),
                    ('th32DefaultHeapID', ctypes.c_size_t), ('th32ModuleID', wintypes.DWORD),
                    ('cntThreads', wintypes.DWORD), ('th32ParentProcessID', wintypes.DWORD),
                    ('pcPriClassBase', ctypes.c_long), ('dwFlags', wintypes.DWORD),
                    ('szExeFile', ctypes.c_wchar * 260)]

    snap = k32.CreateToolhelp32Snapshot(0x2, 0)
    if not snap or snap == wintypes.HANDLE(-1).value:
        return {}
    children = {}
    try:
        e = Entry()
        e.dwSize = ctypes.sizeof(Entry)
        more = k32.Process32FirstW(wintypes.HANDLE(snap), ctypes.byref(e))
        while more:
            if e.th32ProcessID != e.th32ParentProcessID:
                children.setdefault(e.th32ParentProcessID, []).append(e.th32ProcessID)
            more = k32.Process32NextW(wintypes.HANDLE(snap), ctypes.byref(e))
    finally:
        k32.CloseHandle(wintypes.HANDLE(snap))
    return children


def _creation_time(k32, handle):
    import ctypes
    from ctypes import wintypes
    created, exited, kernel, user = (wintypes.FILETIME() for _ in range(4))
    if not k32.GetProcessTimes(wintypes.HANDLE(handle), ctypes.byref(created), ctypes.byref(exited),
                               ctypes.byref(kernel), ctypes.byref(user)):
        return None
    return (created.dwHighDateTime << 32) | created.dwLowDateTime
