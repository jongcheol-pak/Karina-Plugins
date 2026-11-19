"""karina:chain-plan 코디네이터 검증의 명령 래퍼 — Bash `run_in_background` 로 띄우고 끝날 때 결과 한 줄을 낸다.

사용: python run-verify.py --cwd <대상 레포> [--label <이름>] [옵션] -- <명령 argv…>

출력 — 진행 중 시도마다 `STEP <label> start (시도 k/N …)` 줄, 끝에 `RESULT: <갈래> — <다음 행동>` 한 줄,
이어 (기대 조건을 줬으면) `SUMMARY: <k> <값>` 줄과 마지막 시도 출력의 끝 40줄. 판정은 `RESULT:` 줄로 한다(래퍼 exit 는 인자 오류 2, 그 밖 0).
--expect-regex RE (여러 번 · 캡처 그룹 정확히 하나) 를 주면 지우기 전 전체 출력에서 RE 마다 마지막 일치 줄의 캡처를
`SUMMARY:` 줄로 낸다. --expect-value V 는 주지 않거나 RE 와 같은 수로 주고, 순서대로 짝지어 캡처와 문자열로 비교한다.
- pass       명령이 exit 0 으로 끝났다(기대 조건을 줬으면 일치 줄이 모두 있고 값이 모두 맞는다).
- fail       명령이 0 아닌 exit 로 끝났거나(코드를 싣는다 · 126/127 은 unrunnable) exit 0 인데 기대값이 어긋났다.
- nosummary  exit 0 인데 어느 --expect-regex 의 일치 줄도 출력에 없다 — 미검증이다.
- stalled    마지막 진행 시점부터 --stall-sec 동안 출력이 늘지 않고 CPU 증가가 --cpu-sec 미만인 일이
             --retries 회 재실행 뒤에도 되풀이됐다.
- deadline   (--deadline-sec — 사전 단계) 벽시계 시한에 닿았다. 멈춤 판정·재실행을 하지 않는다.
- overtime   (본체) 진행이 이어져도 --max-sec 에 닿았다. 재실행하지 않는다.
- superseded 같은 --cwd 의 새 래퍼가 잠금을 가져갔다. 이 결과는 판정에 쓰지 않는다.
- unrunnable 명령을 띄우지 못했거나(실행 파일 없음) exit 126/127 이다.
- reused     (--stamp) 같은 작업 폴더·같은 명령 내용·같은 기대 조건의 통과 기록이 지금 HEAD 에 맞아 띄우지 않았다.
             기록된 SUMMARY 줄과 꼬리를 낸다.

--stamp 를 주면 실행 전에 기록을 보고, 통과(pass)했고 실행 전·후 HEAD 가 같고 미커밋 추적 변경이 없으면
(작업 폴더 바로 아래 plan.md·notes.md 는 세지 않는다) chain 폴더의 `karina-chain-verify-stamp-*.json` 에 기록한다.
기록·재사용을 하지 못한 사유는 `STAMP:` 줄로 낸다. 재사용은 미커밋 추적 변경이 없고(같은 제외) 기록 HEAD 가 지금 HEAD 와 같을 때이고,
--reuse-docs 를 함께 주면 그 사이 바뀐 파일이 전부 .md·.txt 이고 AGENTS.md·CLAUDE.md 가 없으며 그 이름이
.md·.txt 밖 추적 파일에 따옴표 앞 문자열로 나오지 않을 때도 재사용한다.
--reuse-glob <g> (여러 번)를 주면 --cwd 폴더 기준으로 그 glob(git `:(glob)` 규칙)에 걸리는 파일도
재사용 범위로 친다 — 이름 대조는 하지 않고, --reuse-docs 없이 주면 그 밖 변경은 문서여도 재사용하지 않는다.

어느 갈래로 끝나든 명령이 남긴 자손 프로세스를 끝낸다(Windows 는 Job Object, 그 밖은 프로세스 그룹).
판정 근거는 `../references/run-verify-rationale.md` 가 정본이다.
"""
import argparse
import hashlib
import json
import os
import re
import shutil
import signal
import subprocess
import sys
import tempfile
import time

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', '..', 'scripts'))
import timed_run

TAIL_LINES = 40
LOCK_PREFIX = 'karina-chain-verify-'
DEFAULT_STALL_SEC = 600
DEFAULT_CPU_SEC = 30
DEFAULT_POLL_SEC = 15
DEFAULT_MAX_SEC = 3 * 3600
UNRUNNABLE_EXITS = (126, 127)
SWEEP_AGE_SEC = 7 * 24 * 3600
STAMP_PREFIX = LOCK_PREFIX + 'stamp-'
NOTE_FILES = ('plan.md', 'notes.md')
DOC_EXTS = ('.md', '.txt')
BLOCKING_DOCS = ('AGENTS.md', 'CLAUDE.md')
GIT_TIMEOUT_SEC = 60


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
    p.add_argument('--stamp', action='store_true')
    p.add_argument('--reuse-docs', action='store_true')
    p.add_argument('--reuse-glob', action='append', default=[])
    p.add_argument('--expect-regex', action='append', default=[])
    p.add_argument('--expect-value', action='append', default=[])
    p.add_argument('cmd', nargs=argparse.REMAINDER)
    opts = p.parse_args(argv)
    if opts.cmd[:1] == ['--']:
        opts.cmd = opts.cmd[1:]
    if not opts.cmd:
        p.error('실행할 명령이 없다 — `--` 뒤에 명령 argv 를 준다')
    if opts.max_sec is not None and opts.deadline_sec is not None:
        p.error('--max-sec 와 --deadline-sec 은 함께 줄 수 없다 — 사전 단계는 --deadline-sec 하나다')
    if opts.reuse_docs and not opts.stamp:
        p.error('--reuse-docs 는 --stamp 와 함께만 준다')
    if opts.reuse_glob and not opts.stamp:
        p.error('--reuse-glob 는 --stamp 와 함께만 준다')
    if opts.expect_value and len(opts.expect_value) != len(opts.expect_regex):
        p.error('--expect-value 는 주지 않거나 --expect-regex 와 같은 수로 준다(순서대로 짝)')
    opts.expect = []
    for pattern in opts.expect_regex:
        try:
            rx = re.compile(pattern)
        except re.error as e:
            p.error('--expect-regex 를 읽지 못했다(%s) — %s' % (e, pattern))
        if rx.groups != 1:
            p.error('--expect-regex 는 캡처 그룹이 정확히 하나여야 한다 — %s' % pattern)
        opts.expect.append(rx)
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


def summarize(opts, log_lines):
    """regex 마다 마지막 일치 줄의 캡처 — 일치 줄이 없으면 None."""
    found = [None] * len(opts.expect)
    for line in log_lines:
        for i, rx in enumerate(opts.expect):
            m = rx.search(line)
            if m:
                found[i] = m.group(1)
    return found


def judge_expect(opts, found):
    """exit 0 인 시도의 기대 조건 판정 — (갈래, 다음 행동)."""
    missing = [opts.expect_regex[i] for i, v in enumerate(found) if v is None]
    if missing:
        return 'nosummary', '합계 줄을 찾지 못했다(%s) — 미검증으로 적는다' % missing[0]
    for i, want in enumerate(opts.expect_value):
        if found[i] != want:
            return 'fail', '기대값 불일치(%s 기대 %s · 실제 %s) — 실패로 판정한다' % (opts.expect_regex[i], want, found[i])
    return 'pass', '통과 — 다음 명령으로 간다'


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
            log_lines = proc.lines()
        finally:
            proc.discard()
        tail = log_lines[-TAIL_LINES:]
        if outcome[0] == 'exit':
            code = outcome[1]
            if opts.expect:
                found = summarize(opts, log_lines)
                tail = ['SUMMARY: %d %s' % (i + 1, v) for i, v in enumerate(found) if v is not None] + tail
            if code == 0:
                if opts.expect:
                    return _result(*judge_expect(opts, found), tail)
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


def git_call(cwd, args):
    try:
        p = timed_run.run(['git', '-C', cwd, '-c', 'core.quotepath=off'] + list(args), stdin=subprocess.DEVNULL,
                          capture_output=True, timeout=GIT_TIMEOUT_SEC)
    except (OSError, subprocess.SubprocessError):
        return 128, ''
    return p.returncode, p.stdout.decode('utf-8', errors='replace').rstrip('\r\n')


def _git_out(git, cwd, args):
    code, out = git(cwd, args)
    return out if code == 0 else None


def command_key(cmd, cwd, expect=()):
    parts = ['x:' + e for e in expect] + [os.path.splitext(os.path.basename(cmd[0]))[0].lower()]
    for arg in cmd[1:]:
        path = arg if os.path.isabs(arg) else os.path.join(cwd, arg)
        if os.path.isfile(path):
            with open(path, 'rb') as f:
                body = f.read().replace(b'\r\n', b'\n').strip()
            parts.append('f:' + hashlib.sha256(body).hexdigest())
        else:
            parts.append('a:' + arg)
    return hashlib.sha256('\0'.join(parts).encode('utf-8')).hexdigest()


def stamp_file(cwd, git, folder):
    top = _git_out(git, cwd, ['rev-parse', '--show-toplevel'])
    prefix = _git_out(git, cwd, ['rev-parse', '--show-prefix'])
    if top is None or prefix is None:
        return None
    key = hashlib.sha1(('%s\0%s' % (os.path.normcase(top.replace('\\', '/')), prefix)).encode('utf-8'))
    return os.path.join(folder, '%s%s.json' % (STAMP_PREFIX, key.hexdigest()[:16]))


def _tree(git, cwd):
    head = _git_out(git, cwd, ['rev-parse', 'HEAD'])
    prefix = _git_out(git, cwd, ['rev-parse', '--show-prefix'])
    status = _git_out(git, cwd, ['status', '--porcelain', '--untracked-files=no', '--no-renames'])
    if head is None or prefix is None or status is None:
        return None
    exempt = {prefix + n for n in NOTE_FILES}
    dirty = [l[3:] for l in status.splitlines() if l[3:] and l[3:] not in exempt]
    return head, dirty, prefix


def _load(path):
    try:
        with open(path, encoding='utf-8') as f:
            data = json.load(f)
        return data if isinstance(data, dict) else {}
    except (OSError, ValueError):
        return {}


def _glob_regex(pattern):
    out, i = [], 0
    while i < len(pattern):
        if pattern[i] == '*':
            j = i
            while j < len(pattern) and pattern[j] == '*':
                j += 1
            after = pattern[j:j + 1]
            if j - i < 2 or after not in ('', '/'):
                out.append('[^/]*')
            elif after == '':
                out.append('.*')
            else:
                out.append('(?:.*/)?' if i == 0 or pattern[i - 1] == '/' else '.*/')
                j += 1
            i = j
        elif pattern[i] == '?':
            out.append('[^/]')
            i += 1
        elif pattern[i] == '[' and ']' in pattern[i + 2:]:
            end = pattern.index(']', i + 2)
            body = pattern[i + 1:end]
            out.append('[' + ('^' + body[1:] if body[:1] == '!' else body) + ']')
            i = end + 1
        else:
            out.append(re.escape(pattern[i]))
            i += 1
    return re.compile(''.join(out) + r'\Z')


def glob_match(path, pattern):
    """git `:(glob)` pathspec 과 같은 규칙으로 맞춘다 — 뒤가 `/` 나 패턴 끝인 `**` 는 폴더를 건너고(앞이 경계인 `**/` 는
    폴더 0개도 맞는다), 그 밖 `*`·`?` 는 `/` 를 넘지 않는다."""
    return _glob_regex(pattern).match(path) is not None


def _changes_reusable(git, cwd, since, head, prefix, docs, globs):
    changed = _git_out(git, cwd, ['diff', '--name-only', '--no-renames', '%s..%s' % (since, head)])
    if changed is None:
        return '바뀐 파일을 읽지 못했다'
    top = _git_out(git, cwd, ['rev-parse', '--show-toplevel'])
    for path in changed.splitlines():
        if path in {prefix + n for n in NOTE_FILES}:
            continue
        rel = path[len(prefix):] if path.startswith(prefix) else None
        if rel is not None and any(glob_match(rel, g) for g in globs):
            continue
        name = path.rsplit('/', 1)[-1]
        if not docs or not name.lower().endswith(DOC_EXTS) or name in BLOCKING_DOCS:
            return '재사용 범위 밖 변경 — %s' % path
        code, _ = git(top or cwd, ['grep', '-l', '-F', '-e', name + '"', '-e', name + "'", '--',
                                   '.', ':!*.md', ':!*.txt'])
        if code != 1:
            return '코드가 문자열로 참조하는 문서 — %s' % path
    return None


def _reusable(opts, git, entry, tree):
    if not entry:
        return '기록 없음'
    head, dirty, prefix = tree
    if dirty:
        return '미커밋 변경 — %s' % dirty[0]
    if entry.get('head') == head:
        return None
    if not opts.reuse_docs and not opts.reuse_glob:
        return 'HEAD 가 다르다(기록 %s)' % entry.get('head', '')[:7]
    return _changes_reusable(git, opts.cwd, entry.get('head', ''), head, prefix, opts.reuse_docs, opts.reuse_glob)


def run_stamped(opts, git, run_fn, emit, folder, now=time.time):
    path = stamp_file(opts.cwd, git, folder)
    before = _tree(git, opts.cwd)
    if path is None or before is None:
        emit('STAMP: 기록 안 함 — git 상태를 읽지 못했다')
        return run_fn()
    key = command_key(opts.cmd, opts.cwd, ['r:' + r for r in opts.expect_regex] + ['v:' + v for v in opts.expect_value])
    stamps = _load(path)
    entry = stamps.get(key)
    why = _reusable(opts, git, entry, before)
    if why is None:
        return _result('reused', '%s 에서 통과한 기록을 재사용한다 — 다음 명령으로 간다' % entry['head'][:7],
                       entry.get('tail', []))
    emit('STAMP: 재사용 안 함 — %s' % why)
    lines = run_fn()
    after = _tree(git, opts.cwd)
    if not lines or not lines[0].startswith('RESULT: pass '):
        why = '통과가 아니다'
    elif before[1]:
        why = '실행 전 미커밋 변경 — %s' % before[1][0]
    elif after is None or after[0] != before[0] or after[1]:
        why = '실행 중 HEAD 나 트리가 바뀌었다'
    else:
        why = None
    if why:
        emit('STAMP: 기록 안 함 — %s' % why)
        return lines
    stamps = _load(path)
    stamps[key] = {'head': before[0], 'tail': lines[1:], 'at': int(now())}
    tmp = path + '.tmp'
    try:
        with open(tmp, 'w', encoding='utf-8') as f:
            json.dump(stamps, f, ensure_ascii=False)
        os.replace(tmp, path)
    except OSError as e:
        emit('STAMP: 기록 안 함 — 쓰기 실패(%s)' % e)
    return lines


def chain_dir():
    """임시 폴더의 `karina-plugin/chain` — 없으면 만든다. 폴더 배치는 `../../TEMP-FILES.md`."""
    d = os.path.join(tempfile.gettempdir(), 'karina-plugin', 'chain')
    os.makedirs(d, exist_ok=True)
    return d


def sweep_stale(folder, now):
    """`folder` 의 `karina-chain-verify-*`(잠금·시도 로그) 중 수정 시각이 SWEEP_AGE_SEC 지난 것을 지운다.
    비정상 종료한 래퍼가 남긴 것이다. 정리는 부가 기능이라 실패는 삼킨다."""
    try:
        names = os.listdir(folder)
    except OSError:
        return
    for name in names:
        if not name.startswith(LOCK_PREFIX):
            continue
        path = os.path.join(folder, name)
        try:
            if now - os.path.getmtime(path) > SWEEP_AGE_SEC:
                os.remove(path)
        except OSError:
            pass


class FileLock:
    """--cwd 마다 chain 폴더에 둔 파일 하나. 같은 레포의 새 래퍼가 자기 표식을 덮어쓰면 앞 래퍼는 물러난다."""

    def __init__(self, cwd):
        key = hashlib.sha1(os.path.normcase(os.path.abspath(cwd)).encode('utf-8')).hexdigest()[:16]
        self.path = os.path.join(chain_dir(), '%s%s.lock' % (LOCK_PREFIX, key))
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


class RealProc:
    """명령 하나를 로그 파일로 출력을 받으며 띄운다."""

    def __init__(self, cmd, cwd):
        exe = shutil.which(cmd[0])
        if exe is None:
            raise FileNotFoundError(2, '실행 파일을 PATH 에서 찾지 못했다', cmd[0])
        fd, self.log_path = tempfile.mkstemp(prefix=LOCK_PREFIX, suffix='.log', dir=chain_dir())
        self.log = os.fdopen(fd, 'wb')
        self.job = None
        argv = [exe] + list(cmd[1:])
        try:
            if os.name == 'nt':
                self.job = timed_run.WinJob()
                self.proc = subprocess.Popen(argv, cwd=cwd, stdin=subprocess.DEVNULL, stdout=self.log,
                                             stderr=subprocess.STDOUT, creationflags=0x4)  # CREATE_SUSPENDED
                try:
                    self.job.assign(self.proc._handle)
                finally:
                    timed_run.resume_suspended(self.proc._handle)
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

    def lines(self):
        try:
            with open(self.log_path, encoding='utf-8', errors='replace') as f:
                return [l.rstrip('\r\n') for l in f]
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

    sweep_stale(chain_dir(), time.time())

    def run_locked():
        lock = FileLock(opts.cwd)
        try:
            return run(opts, RealProc, time.monotonic, lambda proc, sec: proc.pause(sec), lock, emit)
        finally:
            lock.release()

    lines = run_stamped(opts, git_call, run_locked, emit, chain_dir()) if opts.stamp else run_locked()
    for line in lines:
        print(line)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
