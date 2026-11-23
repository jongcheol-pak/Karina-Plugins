"""karina:reflect — 현재 세션의 Claude Code 전사를 리뷰어가 읽을 요약으로 줄인다.

찾는 파일: `<projects>/*/<세션ID>.jsonl` 정확히 1개와 `<projects>/<그 폴더>/<세션ID>/subagents/*.jsonl`.
세션 ID 는 `--session`, 없으면 환경변수 `CLAUDE_CODE_SESSION_ID` 다 — 같은 폴더에 다른 탭의 세션 파일이 있어
최신 파일로 고르면 남의 세션을 읽는다.

출력 줄 머리 — U: 사용자 text · A: 모델 text · T: 도구 호출(이름 + 명령·경로 한 구 — 이미지(IMAGE_EXT) Read 는 모드와 무관하게
경로를 자르지 않는다) · ERR: 오류 도구 결과(hook 차단 포함)
· H: hook 첨부(경고 additionalContext · 취소) · BIG: 큰 성공 결과(`BIG: <도구명> <N>자 <앞 120자>` — 본문 길이나
`<persisted-output>` 미리보기의 `Output too large (<크기>)` 가 BIG_CAP 이상, 도구명은 tool_use_id 로 찾고 못 찾으면 `?`)
· SLOW: 오래 걸린 도구 호출(`SLOW: <도구명> <N>초 <hint 앞 120자>` — 결과 레코드 자리 · 시작과 tool_result 의
`timestamp` 차가 SLOW_SEC 이상 · 시작은 그 tool_use_id 의 첫 PreToolUse 첨부(`attachment.hookEvent: PreToolUse` ·
`attachment.toolUseID`) 시각이고 없으면 tool_use 레코드 시각이다 — tool_use 레코드는 블록 입력을 생성하기 시작할 때 찍혀
생성 시간이 소요에 섞인다 · SLOW_EXCLUDE 도구는 뺀다 · Bash 의 권한 승인 대기는 전사로 가를 수 없어 소요에 든다 ·
백그라운드 Bash(결과가 `Command running in background with ID` 인 것)는 끝을 그 tool_use_id 를 담은 `<task-notification>`
사용자 레코드 시각으로 재고 `SLOW: Bash <N>초 (백그라운드) <hint>` 로 그 레코드 자리에 싣는다 — Bash 소요 줄도 같은 끝으로 센다).
그 밖(thinking·BIG_CAP 미만의 성공 결과·메타 레코드)은 싣지 않는다.
머리에 읽은 파일·구간 줄·갈래별 줄 수·총 줄 수를 싣는다 — 리뷰어가 총 줄 수까지 나눠 읽는다.
구간 줄 — `# 구간 <이름>: 작업 <N>초 · 토큰 입력 <a> · 캐시읽기 <b> · 캐시쓰기 <c> · 출력 <d>`. 본 전사는 `Skill`
tool_use 와 `<command-name>` 이 든 사용자 레코드(slash command — 앞 `/` 를 뗀다 · 바로 뒤에 같은 명령의
`type: system`·`subtype: local_command` 레코드가 오는 내장 명령(`/clear` 등)은 앞 구간·뿌리로 되돌린다)가 구간을 바꾸고 첫 경계 앞은
`(스킬 밖)` 이다 · 구간 뿌리는 slash command · 이름에 `:` 가 든 플러그인 스킬 · 뿌리가 `(스킬 밖)` 일 때의 스킬이고, 그 밖의
Skill 호출(레포·사용자 스킬)은 `<뿌리> › <자식>` 구간이 되어 다음 경계까지 잇는다(자식이 끝나는 표지는 전사에 없다 — 뿌리의
소계는 `<뿌리>` 와 `<뿌리> › *` 의 합이다) · 서브에이전트 전사는 파일마다 `서브에이전트 <meta.json 의 agentType | 파일 이름>` 한 구간이다.
작업 시간은 같은 전사 안 연속 레코드 `timestamp` 간격의 합이고(간격은 앞 레코드의 구간에 든다 · 앞 시각은 지금까지 본
가장 늦은 시각이다 — 첨부 레코드는 앞 레코드보다 이른 시각으로 기록돼 그대로 쓰면 겹친 간격을 두 번 센다), 사용자 text
레코드(slash command·대기 중 들어온 알림 포함)나 SLOW_EXCLUDE 도구의 결과로 끝나는 간격은 뺀다 — 사용자 대기와
서브에이전트 대기(그 시간은 서브에이전트 구간이 센다)다. 토큰은 `message.id` 마다 한 번만 센다 — 한 응답이 블록마다
레코드로 갈려 같은 `usage` 가 반복된다. 반올림한 작업 시간이 0초이고 토큰도 없는 구간은 싣지 않는다.
Bash 소요 줄 — 구간 줄 앞에 `# Bash 소요: 시험 <N>초 <k>회 · 검사·형식 … · 기동·빌드 … · 기타 …` 한 줄(갈래 넷을 늘 싣는다).
본 전사·서브에이전트 전사의 Bash 호출마다 SLOW 와 같은 시작 시각에서 tool_result 시각까지를 그 명령의 갈래에 더한다. 갈래는
`git` 으로 시작하면(앞의 `cd <경로>;`·`cd <경로> &&` 는 건너뛴다) 기타, 아니면 BASH_KINDS 의 순서대로 처음 맞는 것이고 없으면 기타다 — 이은 명령은 첫 일치 갈래에 통째로 든다.
`--audit`(implement 완료 리뷰의 전사 대조용) — 본 전사의 A: 줄 · Bash·Skill 의 T: 줄 ·
이미지(IMAGE_EXT) Read 의 T: 줄 · `<command-name>` 이 든 U: 줄 · `SLOW: Bash` 줄만 남긴다(Skill·slash command 줄은 대조 범위를
가르는 표지 · 이미지 Read 줄은 완료 리뷰가 화면 판정의 스크린샷을 열어 봤는지 대조하는 재료 · `SLOW: Bash` 줄은 회차 끝 도구 점검과
완료 리뷰가 느린 검증 명령을 대조하는 재료다). 서브에이전트 전사는 이미지 Read 의 T: 줄만 `## subagent <파일명> (<agentType>)`
머리 아래 싣고, 그 줄이 없는 서브에이전트는 머리도 싣지 않는다(화면 판정을 맡은 검증 에이전트의 스크린샷 Read 대조 재료).
머리에 `# 모드: audit` 을 싣는다.
  한글 음절(가-힣)이 하나도 없는 A: 줄은 `A: [한글 없음] …` 으로 표지하고 그 수를 머리 `# 한글 없는 A: <N>` 에 싣는다
  — implement·pr 의 「상태 메모도 한글로」 위반을 완료 리뷰가 세는 재료는 대조 범위 안의 표지 줄이고, 머리 수는 세션 전체 값이다.
  본 전사의 백그라운드 `Bash` 중 명령이 `sleep <N>`(뒤에 `; echo …` 하나까지)뿐인 시한 타이머가 완료(`<status>completed</status>`) 알림으로 끝났는데,
  그 타이머 시작 뒤·완료 알림 앞에 `SendMessage`·`Agent`·`Task` 의 완료 알림(검증 응답)이 왔으면 타이머 완료 알림 자리에
  `TIMER: <명령> 응답 <HH:MM:SS> 뒤 <N>초에 끝남` 을 싣고 그 수를 머리 `# 응답 뒤 끝난 시한 타이머: <N>` 에 싣는다
  — 응답이 오면 타이머를 `TaskStop` 으로 끄라는 implement screen-scenarios 「화면 시나리오 실행」 위반을 완료 리뷰가 세는 재료다.
  `TaskStop` 으로 끈 타이머는 완료 알림이 없어 싣지 않는다.
  audit 은 Bash 아닌 SLOW: 줄·Bash 소요 줄·구간 줄을 내지 않는다.

종료 코드: 0 정상 · 2 세션 판정 실패(ID 없음·파일 0개·2개 이상) · 3 인식한 레코드 0(전사 형식이 바뀌었을 수 있다).
전사 형식은 Claude Code 내부 형식이라 문서화돼 있지 않다 — 2.1.306 실측 기준이다.
"""
import argparse
import datetime
import glob
import json
import os
import re
import sys

TEXT_CAP = 600
SHORT_CAP = 300
BIG_CAP = 20000
BIG_HEAD = 120
SLOW_SEC = 60
SLOW_EXCLUDE = ('AskUserQuestion', 'Agent', 'Task')
COMMAND_NAME = re.compile(r'<command-name>/?([^<]+)</command-name>')
OUTSIDE = '(스킬 밖)'
TOKEN_KEYS = ('input_tokens', 'cache_read_input_tokens', 'cache_creation_input_tokens', 'output_tokens')
HOOK_TYPES = ('hook_additional_context', 'hook_cancelled')
PERSISTED = re.compile(r'<persisted-output>\s*Output too large \(([\d.]+)(KB|MB)\)')
AUDIT_KINDS = ('U', 'A', 'T')
AUDIT_TOOLS = ('T: Bash ', 'T: Skill ')
AUDIT_SLOW = 'SLOW: Bash '
AUDIT_SUB_HEAD = '## subagent '
IMAGE_EXT = ('.png', '.jpg', '.jpeg', '.gif', '.webp', '.bmp')
NEST_MARK = ' › '
BASH_KINDS = (
    ('시험', re.compile(r'\b(test|tests|pytest)\b|test[-_]task|\bevals?\b|[-_]evals?\b')),
    ('검사·형식', re.compile(r'\b(checks?|fmt|clippy|lint|format)\b|drift|audit')),
    ('기동·빌드', re.compile(r'\b(build|run|launch|start)\b')),
)
BASH_OTHER = '기타'
BACKGROUND_RESULT = 'Command running in background with ID'
BACKGROUND_MARK = '(백그라운드)'
NOTIFICATION = '<task-notification>'
NOTIFIED_TOOL = re.compile(r'<tool-use-id>([^<]+)</tool-use-id>')
NOTIFIED_STATUS = re.compile(r'<status>([^<]+)</status>')
REPLY_TOOLS = ('SendMessage', 'Agent', 'Task')
TIMER_COMMAND = re.compile(r'^\s*sleep\s+\d+\s*(?:;\s*echo\b[^;&|]*)?$')
TIMER_MARK = 'TIMER: '
TIMER_HEAD = '# 응답 뒤 끝난 시한 타이머: '
GIT_COMMAND = re.compile(r'''^\s*(?:cd\s+(?:"[^"]*"|'[^']*'|\S+)\s*(?:;|&&)\s*)*git\b''')
HANGUL = re.compile('[가-힣]')
HANGUL_FREE_MARK = 'A: [한글 없음] '


def is_image_read(line):
    return line.startswith('T: Read ') and line.lower().endswith(IMAGE_EXT)


def audit_keep(line):
    if line.startswith('U: '):
        return '<command-name>' in line
    return (line.startswith(('A: ', AUDIT_SUB_HEAD, TIMER_MARK)) or line.startswith(AUDIT_TOOLS) or line.startswith(AUDIT_SLOW)
            or is_image_read(line))


def cut(value, cap):
    s = ' '.join(str(value).split())
    return s if len(s) <= cap else s[:cap] + '…'


def _result_text(content):
    if isinstance(content, str):
        return content
    return ' '.join(b.get('text', '') for b in content or [] if isinstance(b, dict))


def _tool_hint(inp):
    for key in ('command', 'file_path', 'skill', 'pattern', 'description', 'prompt'):
        if inp.get(key):
            return inp[key]
    return ''


def result_size(text):
    m = PERSISTED.search(text)
    if m:
        return int(float(m.group(1)) * (1000 if m.group(2) == 'KB' else 1000000))
    return len(text)


def parse_ts(d):
    try:
        return datetime.datetime.fromisoformat(str(d['timestamp']).replace('Z', '+00:00'))
    except (KeyError, ValueError):
        return None


def remember_tools(d, tools):
    a = d.get('attachment') if d.get('type') == 'attachment' else None
    if isinstance(a, dict) and a.get('hookEvent') == 'PreToolUse':
        known = tools.get(a.get('toolUseID'))
        if known and not known[3] and parse_ts(d) is not None:
            tools[a.get('toolUseID')] = (known[0], parse_ts(d), known[2], True)
        return
    if d.get('type') != 'assistant' or not isinstance(d.get('message'), dict):
        return
    for b in d['message'].get('content') or []:
        if isinstance(b, dict) and b.get('type') == 'tool_use':
            tools[b.get('id')] = (b.get('name'), parse_ts(d), _tool_hint(b.get('input') or {}), False)


def slow_line(b, tools, ts):
    name, start, hint, _ = tools.get(b.get('tool_use_id'), ('?', None, '', False))
    if ts is None or start is None or name in SLOW_EXCLUDE:
        return None
    sec = (ts - start).total_seconds()
    if sec < SLOW_SEC:
        return None
    return ('SLOW: %s %d초 %s' % (name, round(sec), cut(hint, BIG_HEAD))).rstrip()


def bash_kind(command):
    if GIT_COMMAND.match(command):
        return BASH_OTHER
    for kind, rx in BASH_KINDS:
        if rx.search(command):
            return kind
    return BASH_OTHER


def background_bash_ids(text, tools):
    if NOTIFICATION not in text:
        return []
    return [tid for tid in NOTIFIED_TOOL.findall(text) if tools.get(tid, ('?',))[0] == 'Bash']


def background_slow_lines(text, tools, ts):
    out = []
    for tid in background_bash_ids(text, tools):
        _, start, hint, _ = tools[tid]
        if ts is not None and start is not None and (ts - start).total_seconds() >= SLOW_SEC:
            out.append(('SLOW: Bash %d초 %s %s' % (round((ts - start).total_seconds()), BACKGROUND_MARK,
                                                   cut(hint, BIG_HEAD))).rstrip())
    return out


def timer_lines(d, tools, replies):
    if d.get('type') != 'user' or not isinstance(d.get('message'), dict):
        return []
    ts = parse_ts(d)
    c = d['message'].get('content')
    out = []
    for text in ([c] if isinstance(c, str) else [b.get('text', '') for b in c or [] if isinstance(b, dict)]):
        if NOTIFICATION not in str(text) or ts is None:
            continue
        status = NOTIFIED_STATUS.search(text)
        if not status or status.group(1) != 'completed':
            continue
        for tid in NOTIFIED_TOOL.findall(text):
            name, start, hint, _ = tools.get(tid, ('?', None, '', False))
            if name in REPLY_TOOLS:
                replies.append(ts)
            elif name == 'Bash' and start is not None and TIMER_COMMAND.match(str(hint)):
                after = [r for r in replies if start <= r <= ts]
                if after:
                    out.append('%s%s 응답 %s 뒤 %d초에 끝남' % (TIMER_MARK, cut(hint, BIG_HEAD), after[0].strftime('%H:%M:%S'),
                                                         round((ts - after[0]).total_seconds())))
    return out


def _add_bash(bash, hint, start, ts):
    if ts is None or start is None:
        return
    total = bash.setdefault(bash_kind(str(hint)), [0.0, 0])
    total[0] += max(0.0, (ts - start).total_seconds())
    total[1] += 1


def add_bash_time(d, tools, bash):
    if d.get('type') != 'user' or not isinstance(d.get('message'), dict):
        return
    ts = parse_ts(d)
    c = d['message'].get('content')
    for b in ([{'type': 'text', 'text': c}] if isinstance(c, str) else c or []):
        if not isinstance(b, dict):
            continue
        if b.get('type') == 'text':
            for tid in background_bash_ids(b.get('text', ''), tools):
                _add_bash(bash, tools[tid][2], tools[tid][1], ts)
            continue
        if b.get('type') != 'tool_result' or BACKGROUND_RESULT in _result_text(b.get('content')):
            continue
        name, start, hint, _ = tools.get(b.get('tool_use_id'), ('?', None, '', False))
        if name == 'Bash':
            _add_bash(bash, hint, start, ts)


def bash_line(bash):
    kinds = [k for k, _ in BASH_KINDS] + [BASH_OTHER]
    return '# Bash 소요: ' + ' · '.join(
        '%s %d초 %d회' % (k, round(bash.get(k, [0.0, 0])[0]), bash.get(k, [0.0, 0])[1]) for k in kinds)


def record_lines(d, tools):
    t = d.get('type')
    m = d.get('message') if isinstance(d.get('message'), dict) else {}
    c = m.get('content')
    if t == 'user':
        ts = parse_ts(d)
        if isinstance(c, str):
            return ['U: ' + cut(c, TEXT_CAP)] + background_slow_lines(c, tools, ts)
        out = []
        for b in c or []:
            if b.get('type') == 'text':
                out.append('U: ' + cut(b.get('text', ''), TEXT_CAP))
                out += background_slow_lines(b.get('text', ''), tools, ts)
            elif b.get('type') == 'tool_result' and b.get('is_error'):
                out.append('ERR: ' + cut(_result_text(b.get('content')), SHORT_CAP))
            elif b.get('type') == 'tool_result':
                text = _result_text(b.get('content'))
                size = result_size(text)
                if size >= BIG_CAP:
                    name = tools.get(b.get('tool_use_id'), ('?',))[0]
                    out.append('BIG: %s %d자 %s' % (name, size, cut(text, BIG_HEAD)))
            if b.get('type') == 'tool_result':
                slow = slow_line(b, tools, ts)
                if slow:
                    out.append(slow)
        return out
    if t == 'assistant':
        out = []
        for b in c or []:
            if b.get('type') == 'text':
                out.append('A: ' + cut(b.get('text', ''), TEXT_CAP))
            elif b.get('type') == 'tool_use':
                inp = b.get('input') or {}
                path = str(inp.get('file_path') or '')
                whole = b.get('name') == 'Read' and path.lower().endswith(IMAGE_EXT)
                hint = path if whole else cut(_tool_hint(inp), SHORT_CAP)
                out.append(('T: %s %s' % (b.get('name'), hint)).rstrip())
        return out
    if t == 'attachment':
        a = d.get('attachment') or {}
        if a.get('type') in HOOK_TYPES:
            body = a.get('content')
            body = ' '.join(map(str, body)) if isinstance(body, list) else (body or '')
            return [('H: %s %s %s' % (a.get('type'), a.get('hookName', ''), cut(body, SHORT_CAP))).rstrip()]
        return []
    return None


class Segments:
    """구간별 작업 시간·토큰 — 규칙은 모듈 docstring 「구간 줄」."""

    def __init__(self, first, split):
        self.current, self.root, self.split = first, first, split
        self.totals, self.prev, self.seen, self.before_command = {}, None, set(), None

    def _add(self, name, i, value):
        self.totals.setdefault(name, [0.0, 0, 0, 0, 0])[i] += value

    def _boundary(self, d, m):
        if not self.split:
            return None
        c = m.get('content')
        if d.get('type') == 'user':
            text = c if isinstance(c, str) else ' '.join(
                b.get('text', '') for b in c or [] if isinstance(b, dict) and b.get('type') == 'text')
            hit = COMMAND_NAME.search(text)
            return (hit.group(1).strip(), True) if hit else None
        if d.get('type') == 'assistant':
            for b in c or []:
                if isinstance(b, dict) and b.get('type') == 'tool_use' and b.get('name') == 'Skill':
                    return str((b.get('input') or {}).get('skill') or 'Skill'), False
        return None

    def _waits(self, d, m, tools):
        if d.get('type') != 'user':
            return False
        c = m.get('content')
        if isinstance(c, str):
            return True
        for b in c or []:
            if not isinstance(b, dict):
                continue
            if b.get('type') == 'text':
                return True
            if b.get('type') == 'tool_result' and tools.get(b.get('tool_use_id'), ('?',))[0] in SLOW_EXCLUDE:
                return True
        return False

    def observe(self, d, tools):
        m = d.get('message') if isinstance(d.get('message'), dict) else {}
        ts = parse_ts(d)
        local = d.get('type') == 'system' and d.get('subtype') == 'local_command'
        if local and self.before_command is not None and (d.get('commandRun') or {}).get('command') == self.current:
            (self.current, self.root), self.before_command = self.before_command, None
            if self.prev is not None:
                self.prev = (self.prev[0], self.current)
        if ts is not None and self.prev is not None and not self._waits(d, m, tools):
            self._add(self.prev[1], 0, max(0.0, (ts - self.prev[0]).total_seconds()))
        usage = m.get('usage')
        if d.get('type') == 'assistant' and isinstance(usage, dict) and m.get('id') not in self.seen:
            self.seen.add(m.get('id'))
            for i, key in enumerate(TOKEN_KEYS, 1):
                self._add(self.current, i, int(usage.get(key) or 0))
        hit = self._boundary(d, m)
        if hit:
            name, command = hit
            self.before_command = (self.current, self.root) if command else None
            if command or ':' in name or self.root == OUTSIDE:
                self.root = self.current = name
            else:
                self.current = self.root + NEST_MARK + name
        if ts is not None:
            self.prev = (ts if self.prev is None else max(ts, self.prev[0]), self.current)

    def lines(self):
        return ['# 구간 %s: 작업 %d초 · 토큰 입력 %d · 캐시읽기 %d · 캐시쓰기 %d · 출력 %d'
                % ((name, round(v[0])) + tuple(v[1:])) for name, v in self.totals.items()
                if round(v[0]) or any(v[1:])]


def digest_file(path, counts, segments, bash):
    lines, recognized, tools, replies = [], 0, {}, []
    with open(path, encoding='utf-8', errors='replace') as f:
        for raw in f:
            try:
                d = json.loads(raw)
            except ValueError:
                continue
            if not isinstance(d, dict):
                continue
            remember_tools(d, tools)
            segments.observe(d, tools)
            add_bash_time(d, tools, bash)
            got = record_lines(d, tools)
            if got is None:
                continue
            got = got + timer_lines(d, tools, replies)
            recognized += 1
            for line in got:
                counts[line.split(':', 1)[0]] = counts.get(line.split(':', 1)[0], 0) + 1
                lines.append(line)
    return lines, recognized


def subagent_label(path):
    try:
        with open(path[:-len('.jsonl')] + '.meta.json', encoding='utf-8') as f:
            meta = json.load(f)
    except (OSError, ValueError):
        return os.path.basename(path)
    return str(meta.get('agentType') or os.path.basename(path)) if isinstance(meta, dict) else os.path.basename(path)


def find_files(projects, sid):
    mains = sorted(glob.glob(os.path.join(glob.escape(projects), '*', glob.escape(sid) + '.jsonl')))
    if len(mains) != 1:
        return mains, []
    folder = os.path.dirname(mains[0])
    subs = sorted(glob.glob(os.path.join(glob.escape(folder), glob.escape(sid), 'subagents', '*.jsonl')))
    return mains, subs


def main(argv=None):
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    ap = argparse.ArgumentParser(description='reflect 전사 요약')
    ap.add_argument('--session', default=None)
    ap.add_argument('--projects-dir', default=os.path.join(os.path.expanduser('~'), '.claude', 'projects'))
    ap.add_argument('--out', default=None)
    ap.add_argument('--audit', action='store_true')
    a = ap.parse_args(argv)
    sid = a.session or os.environ.get('CLAUDE_CODE_SESSION_ID')
    if not sid:
        print('세션 ID 없음 — --session 을 주거나 CLAUDE_CODE_SESSION_ID 가 있는 세션에서 실행한다', file=sys.stderr)
        return 2
    mains, subs = find_files(a.projects_dir, sid)
    if len(mains) != 1:
        print('세션 전사 %d개 — 정확히 1개여야 한다: %s' % (len(mains), ', '.join(mains) or a.projects_dir),
              file=sys.stderr)
        return 2
    counts, body, recognized, bash = {}, [], 0, {}
    main_segments = Segments(OUTSIDE, True)
    lines, n = digest_file(mains[0], counts, main_segments, bash)
    body += lines
    recognized += n
    segment_lines = main_segments.lines()
    for sub in subs:
        sub_segments = Segments('서브에이전트 ' + subagent_label(sub), False)
        lines, n = digest_file(sub, counts, sub_segments, bash)
        if a.audit:
            lines = [line for line in lines if is_image_read(line)]
            if lines:
                body += ['%s%s (%s)' % (AUDIT_SUB_HEAD, os.path.basename(sub), subagent_label(sub))] + lines
            continue
        body += [AUDIT_SUB_HEAD + os.path.basename(sub)] + lines
        recognized += n
        segment_lines += sub_segments.lines()
    if recognized == 0:
        print('인식한 레코드 0 — 전사 형식이 바뀌었을 수 있다: %s' % mains[0], file=sys.stderr)
        return 3
    kinds = ('U', 'A', 'T', 'ERR', 'H', 'BIG', 'SLOW')
    head = ['# reflect 요약 — 세션 %s' % sid, '# 본 전사: %s' % mains[0], '# 서브에이전트 전사: %d개' % len(subs)]
    if not a.audit:
        head += [bash_line(bash)] + segment_lines
    if a.audit:
        body = [line for line in body if audit_keep(line)]
        body = [HANGUL_FREE_MARK + line[3:] if line.startswith('A: ') and not HANGUL.search(line) else line
                for line in body]
        counts = {k: sum(1 for line in body if line.startswith(k + ': ')) for k in AUDIT_KINDS}
        kinds = AUDIT_KINDS
        head.append('# 모드: audit')
        head.append('# 한글 없는 A: %d' % sum(1 for line in body if line.startswith(HANGUL_FREE_MARK)))
        head.append(TIMER_HEAD + '%d' % sum(1 for line in body if line.startswith(TIMER_MARK)))
    head.append('# 줄 수: ' + ' · '.join('%s %d' % (k, counts.get(k, 0)) for k in kinds))
    total = len(head) + 1 + len(body)
    text = '\n'.join(head + ['# 총 줄 수: %d' % total] + body) + '\n'
    if a.out:
        with open(a.out, 'w', encoding='utf-8', newline='\n') as f:
            f.write(text)
        print('요약 저장: %s (총 %d줄)' % (a.out, total))
    else:
        sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main())
