#!/usr/bin/env python3
"""`scripts/timed_run.py` 골든 — 실제 자식·손자 프로세스를 띄워 시간 초과 때 트리 종료와 정상 경로를 잰다.

전 case PASS면 exit 0, 하나라도 FAIL이면 1.
"""
import importlib
import os
import shutil
import subprocess
import sys
import tempfile
import time
import traceback

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, '..', 'scripts'))

LIMIT = 2
SLACK = 3
CASES = []


def case(fn):
    CASES.append(fn)
    return fn


def helper():
    return importlib.import_module('timed_run')


def alive(pid):
    if os.name != 'nt':
        try:
            os.kill(pid, 0)
        except OSError:
            return False
        return True
    import ctypes
    k32 = ctypes.WinDLL('kernel32', use_last_error=True)
    k32.OpenProcess.restype = ctypes.c_void_p
    h = k32.OpenProcess(0x1000, False, pid)
    if not h:
        return False
    try:
        code = ctypes.c_ulong()
        k32.GetExitCodeProcess(ctypes.c_void_p(h), ctypes.byref(code))
        return code.value == 259
    finally:
        k32.CloseHandle(ctypes.c_void_p(h))


def kill(pid):
    if os.name == 'nt':
        subprocess.call(['taskkill', '/F', '/PID', str(pid)], stdin=subprocess.DEVNULL,
                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    else:
        try:
            os.kill(pid, 9)
        except OSError:
            pass


def gone_within(pid, sec):
    deadline = time.time() + sec
    while alive(pid) and time.time() < deadline:
        time.sleep(0.1)
    return not alive(pid)


def child_cmd(pid_file, grandchild_holds_pipe, child_lingers):
    gc_out = 'None' if grandchild_holds_pipe else 'subprocess.DEVNULL'
    code = ('import subprocess, sys, time; '
            'g = subprocess.Popen([sys.executable, "-c", "import time; time.sleep(60)"], stdout=%s, stderr=%s); '
            'open(%r, "w").write(str(g.pid)); print("started", flush=True); '
            '%s' % (gc_out, gc_out, pid_file, 'time.sleep(60)' if child_lingers else 'pass'))
    return [sys.executable, '-c', code]


def read_pid(pid_file):
    deadline = time.time() + 10
    while time.time() < deadline:
        try:
            with open(pid_file, encoding='utf-8') as f:
                text = f.read().strip()
            if text:
                return int(text)
        except OSError:
            pass
        time.sleep(0.1)
    raise AssertionError('손자 PID 파일이 생기지 않았다: %s' % pid_file)


def timeout_case(child_lingers, budget, **kwargs):
    tr = helper()
    d = tempfile.mkdtemp(prefix='karina-timed-run-')
    pid_file = os.path.join(d, 'gc.pid')
    t = time.time()
    try:
        try:
            tr.run(child_cmd(pid_file, kwargs.pop('holds', True), child_lingers), timeout=LIMIT, **kwargs)
        except subprocess.TimeoutExpired:
            pass
        else:
            raise AssertionError('TimeoutExpired 가 올라오지 않았다')
        elapsed = time.time() - t
        gpid = read_pid(pid_file)
        survived = not gone_within(gpid, 3)
        if survived:
            kill(gpid)
    finally:
        shutil.rmtree(d, ignore_errors=True)
    assert elapsed < budget, '상한 %s초 안에 돌아오지 않았다: %.1f초' % (budget, elapsed)
    assert not survived, '시간 초과 뒤 손자(pid %d)가 살아 있다' % gpid


def without_job(fn):
    tr = helper()
    saved = tr.create_job

    def refuse():
        raise OSError('주입: Job 넣기 실패')
    tr.create_job = refuse
    try:
        fn()
    finally:
        tr.create_job = saved


@case
def grandchild_holding_pipe_is_killed_on_timeout():
    timeout_case(True, LIMIT + SLACK, capture_output=True)


@case
def grandchild_of_exited_child_is_killed_on_timeout():
    timeout_case(False, LIMIT + SLACK, capture_output=True)


@case
def grandchild_is_killed_on_timeout_without_pipes():
    timeout_case(True, LIMIT + SLACK, holds=False, stdin=subprocess.DEVNULL,
                 stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


@case
def normal_exit_returns_code_and_output():
    tr = helper()
    p = tr.run([sys.executable, '-c', 'import sys; sys.stdout.write("out"); sys.stderr.write("err"); sys.exit(3)'],
               timeout=30, capture_output=True)
    assert (p.returncode, p.stdout, p.stderr) == (3, b'out', b'err'), (p.returncode, p.stdout, p.stderr)


@case
def text_mode_passes_encoding_through():
    tr = helper()
    p = tr.run([sys.executable, '-c', 'import sys; sys.stdout.buffer.write("한글 출력".encode("utf-8"))'],
               timeout=30, capture_output=True, encoding='utf-8', errors='replace')
    assert p.stdout == '한글 출력', repr(p.stdout)


@case
def job_refusal_falls_back_to_tree_kill():
    without_job(lambda: timeout_case(True, LIMIT + SLACK, capture_output=True))


@case
def missing_executable_raises_oserror():
    tr = helper()
    try:
        tr.run(['karina-no-such-exe-7f3a'], timeout=5, capture_output=True)
    except OSError:
        return
    raise AssertionError('OSError 가 올라오지 않았다')


@case
def normal_exit_leaves_detached_grandchild_running():
    tr = helper()
    d = tempfile.mkdtemp(prefix='karina-timed-run-')
    pid_file = os.path.join(d, 'gc.pid')
    try:
        p = tr.run(child_cmd(pid_file, False, False), timeout=30, capture_output=True)
        gpid = read_pid(pid_file)
        time.sleep(0.5)
        survived = alive(gpid)
        kill(gpid)
    finally:
        shutil.rmtree(d, ignore_errors=True)
    assert p.returncode == 0, p.returncode
    assert survived, '정상 완료 뒤 떼어 띄운 손자(pid %d)가 함께 끝났다' % gpid


@case
def job_refusal_with_exited_child_still_kills_grandchild():
    without_job(lambda: timeout_case(False, LIMIT + SLACK + 2, capture_output=True))


def main():
    passed = 0
    for fn in CASES:
        try:
            fn()
        except Exception:
            print('FAIL %s' % fn.__name__)
            print('  ' + traceback.format_exc().strip().splitlines()[-1])
        else:
            passed += 1
            print('PASS %s' % fn.__name__)
    print('%d/%d PASS' % (passed, len(CASES)))
    return 0 if passed == len(CASES) else 1


if __name__ == '__main__':
    sys.exit(main())
