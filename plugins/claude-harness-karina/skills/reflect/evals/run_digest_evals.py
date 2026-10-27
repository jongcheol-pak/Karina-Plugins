"""reflect 스크립트(scripts/digest_transcript.py · scripts/append_deferred.py) 골든.

모델·Claude Code 를 부르지 않는다 — 임시 폴더에 가짜 projects 폴더(전사 JSONL)와 가짜 대장을 바이트로 만들고,
두 스크립트를 실제 프로세스로 띄워 종료 코드·출력·파일 바이트를 잰다. 픽스처를 레포에 두지 않는 이유는
대장 픽스처의 CRLF·BOM 을 git 체크아웃 정규화에 맡기지 않으려는 것이다.
"""
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
DIGEST = os.path.join(HERE, '..', 'scripts', 'digest_transcript.py')
APPEND = os.path.join(HERE, '..', 'scripts', 'append_deferred.py')

SID = '11111111-2222-3333-4444-555555555555'
OTHER = '99999999-8888-7777-6666-555555555555'

CASES = []


def case(fn):
    CASES.append(fn)
    return fn


def run(script, args, env_sid=None):
    env = dict(os.environ)
    env.pop('CLAUDE_CODE_SESSION_ID', None)
    if env_sid is not None:
        env['CLAUDE_CODE_SESSION_ID'] = env_sid
    p = subprocess.run([sys.executable, script] + args, capture_output=True, env=env, timeout=60)
    return p.returncode, p.stdout.decode('utf-8', errors='replace'), p.stderr.decode('utf-8', errors='replace')


def rec_user(text):
    return {'type': 'user', 'message': {'role': 'user', 'content': text}}


def rec_user_blocks(blocks):
    return {'type': 'user', 'message': {'role': 'user', 'content': blocks}}


def rec_assistant(blocks):
    return {'type': 'assistant', 'message': {'role': 'assistant', 'content': blocks}}


def rec_hook(content):
    return {'type': 'attachment', 'attachment': {'type': 'hook_additional_context', 'hookName': 'PreToolUse:Bash',
                                                 'content': [content]}}


BASIC = [
    rec_user('사용자가 버그를 보고했다'),
    rec_assistant([{'type': 'thinking', 'thinking': '비밀스러운 생각'},
                   {'type': 'text', 'text': '원인을 찾겠습니다'},
                   {'type': 'tool_use', 'name': 'Bash', 'input': {'command': 'git status'}}]),
    rec_user_blocks([{'type': 'tool_result', 'content': '성공한 출력', 'is_error': False}]),
    rec_user_blocks([{'type': 'tool_result', 'content': 'exit 2 차단됨', 'is_error': True}]),
    rec_hook('경고: 외부 작업'),
    {'type': 'mode', 'mode': 'x'},
    {'type': 'api-request', 'params': {}},
]


class Tree:
    """가짜 `~/.claude/projects` — 폴더마다 세션 전사를 둔다."""

    def __init__(self):
        self.root = tempfile.mkdtemp(prefix='karina-reflect-')

    def session(self, folder, sid, records, raw_lines=()):
        d = os.path.join(self.root, folder)
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, sid + '.jsonl'), 'w', encoding='utf-8', newline='\n') as f:
            for r in records:
                f.write(json.dumps(r, ensure_ascii=False) + '\n')
            for line in raw_lines:
                f.write(line + '\n')
        return d

    def subagent(self, folder, sid, name, records):
        d = os.path.join(self.root, folder, sid, 'subagents')
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, name), 'w', encoding='utf-8', newline='\n') as f:
            for r in records:
                f.write(json.dumps(r, ensure_ascii=False) + '\n')

    def close(self):
        shutil.rmtree(self.root, ignore_errors=True)


def digest(tree, extra=(), env_sid=None, sid=SID):
    args = ['--projects-dir', tree.root] + list(extra)
    if sid is not None:
        args += ['--session', sid]
    return run(DIGEST, args, env_sid=env_sid)


@case
def five_prefixes_present():
    # ① 다섯 줄 머리가 각각 나온다
    t = Tree()
    try:
        t.session('proj-a', SID, BASIC)
        rc, out, err = digest(t)
        assert rc == 0, (rc, err)
        for p in ('U: 사용자가 버그를', 'A: 원인을 찾겠습니다', 'T: Bash git status', 'ERR: exit 2 차단됨', 'H: '):
            assert any(l.startswith(p) for l in out.splitlines()), (p, out)
        assert '경고: 외부 작업' in out, out
    finally:
        t.close()


@case
def noise_excluded():
    # ② thinking·성공 tool_result·메타 레코드는 나오지 않는다
    t = Tree()
    try:
        t.session('proj-a', SID, BASIC)
        rc, out, _ = digest(t)
        assert rc == 0
        for bad in ('비밀스러운 생각', '성공한 출력', 'api-request', '"mode"'):
            assert bad not in out, (bad, out)
    finally:
        t.close()


@case
def subagent_appended():
    # ③ 서브에이전트 전사가 `## subagent <파일명>` 머리로 붙는다
    t = Tree()
    try:
        t.session('proj-a', SID, BASIC)
        t.subagent('proj-a', SID, 'agent-abc.jsonl', [rec_assistant([{'type': 'text', 'text': '서브에이전트 답'}])])
        rc, out, _ = digest(t)
        assert rc == 0
        lines = out.splitlines()
        i = lines.index('## subagent agent-abc.jsonl')
        assert 'A: 서브에이전트 답' in lines[i + 1:], out
    finally:
        t.close()


@case
def other_sessions_not_read():
    # ④ 다른 폴더·다른 세션 파일은 읽지 않는다
    t = Tree()
    try:
        t.session('proj-a', SID, BASIC)
        t.session('proj-a', OTHER, [rec_user('같은 폴더 남의 세션')])
        t.session('proj-b', OTHER, [rec_user('다른 프로젝트')])
        t.subagent('proj-a', OTHER, 'agent-x.jsonl', [rec_user('남의 서브에이전트')])
        rc, out, _ = digest(t)
        assert rc == 0
        for bad in ('같은 폴더 남의 세션', '다른 프로젝트', '남의 서브에이전트'):
            assert bad not in out, (bad, out)
    finally:
        t.close()


@case
def session_from_env():
    # ⑤ ID 를 환경변수에서 읽는다
    t = Tree()
    try:
        t.session('proj-a', SID, BASIC)
        rc, out, err = digest(t, sid=None, env_sid=SID)
        assert rc == 0, (rc, err)
        assert 'U: 사용자가 버그를' in out
    finally:
        t.close()


@case
def session_resolution_failures():
    # ⑥ ID 없음 · 파일 0개 · 2개 이상 → exit 2
    t = Tree()
    try:
        rc, _, err = digest(t, sid=None)
        assert rc == 2 and '세션 ID 없음' in err, ('ID 없음', rc, err)
        rc, _, err = digest(t)
        assert rc == 2 and '세션 전사 0개' in err, ('파일 0개', rc, err)
        t.session('proj-a', SID, BASIC)
        t.session('proj-b', SID, BASIC)
        rc, _, err = digest(t)
        assert rc == 2, ('2개 이상', rc)
        assert 'proj-a' in err and 'proj-b' in err, err
    finally:
        t.close()


@case
def unrecognized_format_exit3():
    # ⑦ 인식 레코드 0 → exit 3
    t = Tree()
    try:
        t.session('proj-a', SID, [{'type': 'mode'}, {'kind': 'unknown'}])
        rc, _, _ = digest(t)
        assert rc == 3, rc
    finally:
        t.close()


@case
def broken_json_skipped():
    # ⑧ 깨진 JSON 줄은 건너뛰고 나머지를 낸다
    t = Tree()
    try:
        t.session('proj-a', SID, [rec_user('앞줄')], raw_lines=['{깨진 줄', json.dumps(rec_user('뒷줄'))])
        rc, out, _ = digest(t)
        assert rc == 0
        assert 'U: 앞줄' in out and 'U: 뒷줄' in out, out
    finally:
        t.close()


@case
def long_values_truncated():
    # ⑨ 긴 값이 갈래별 상한(600·300자)에서 잘린다
    t = Tree()
    try:
        t.session('proj-a', SID, [rec_user('가' * 1000),
                                   rec_assistant([{'type': 'tool_use', 'name': 'Bash',
                                                   'input': {'command': 'x' * 1000}}])])
        rc, out, _ = digest(t)
        assert rc == 0
        u = [l for l in out.splitlines() if l.startswith('U: ')][0]
        tl = [l for l in out.splitlines() if l.startswith('T: ')][0]
        assert u == 'U: ' + '가' * 600 + '…', len(u)
        assert len(tl) <= len('T: Bash ') + 300 + 1 and tl.endswith('…'), len(tl)
    finally:
        t.close()


@case
def out_file_with_total_lines():
    # ⑩ `--out` 이 파일에 쓰고 머리에 총 줄 수가 있다
    t = Tree()
    try:
        t.session('proj-a', SID, BASIC)
        out_path = os.path.join(t.root, 'digest.txt')
        rc, out, _ = digest(t, extra=['--out', out_path])
        assert rc == 0
        with open(out_path, encoding='utf-8') as f:
            text = f.read()
        lines = text.splitlines()
        total = [l for l in lines if l.startswith('# 총 줄 수: ')]
        assert total and int(total[0].split(': ')[1]) == len(lines), (total, len(lines))
        assert 'U: 사용자가 버그를' in text
        assert out_path in out, '저장 경로를 알린다'
    finally:
        t.close()


def tool_use(tid, name, command='x'):
    return {'type': 'tool_use', 'id': tid, 'name': name, 'input': {'command': command}}


def tool_result(tid, content, is_error=False):
    return {'type': 'tool_result', 'tool_use_id': tid, 'content': content, 'is_error': is_error}


def big_lines(out):
    return [l for l in out.splitlines() if l.startswith('BIG: ')]


@case
def big_result_marked():
    # ⑲ 본문 20,000자 성공 결과 → 도구 이름을 단 BIG 줄 · 본문은 120자까지만 · 머리 줄 수에 BIG 1
    t = Tree()
    try:
        t.session('proj-a', SID, [rec_assistant([tool_use('t1', 'Bash')]),
                                   rec_user_blocks([tool_result('t1', '가' * 20000)])])
        rc, out, err = digest(t)
        assert rc == 0, (rc, err)
        big = big_lines(out)
        assert len(big) == 1 and big[0].startswith('BIG: Bash 20000자 '), big
        assert '가' * 121 not in big[0], len(big[0])
        assert 'BIG 1' in [l for l in out.splitlines() if l.startswith('# 줄 수: ')][0], out[:400]
    finally:
        t.close()


@case
def persisted_output_marked():
    # ⑳ 파일로 빠진 출력의 미리보기(Output too large) → BIG 줄
    t = Tree()
    try:
        preview = '<persisted-output>\nOutput too large (21.3KB). Full output saved to: C:\\x\\tool-results\\a.txt\n미리보기'
        t.session('proj-a', SID, [rec_assistant([tool_use('t1', 'Grep')]),
                                   rec_user_blocks([tool_result('t1', preview)])])
        rc, out, err = digest(t)
        assert rc == 0, (rc, err)
        big = big_lines(out)
        assert len(big) == 1 and big[0].startswith('BIG: Grep 21300자 '), big
    finally:
        t.close()


@case
def big_parallel_tool_name():
    # ㉑ 병렬 호출 — 결과의 tool_use_id 로 도구를 찾아, 바로 앞 T 줄(다른 도구)을 붙이지 않는다
    t = Tree()
    try:
        t.session('proj-a', SID, [rec_assistant([tool_use('r1', 'Read'), tool_use('b1', 'Bash')]),
                                   rec_user_blocks([tool_result('r1', '나' * 20000)]),
                                   rec_user_blocks([tool_result('b1', '짧음')])])
        rc, out, err = digest(t)
        assert rc == 0, (rc, err)
        big = big_lines(out)
        assert len(big) == 1 and big[0].startswith('BIG: Read '), big
    finally:
        t.close()


@case
def below_big_cap_excluded():
    # ㉒ 문턱 미만(본문 19,999자 · 미리보기 19.5KB) → BIG 없음
    t = Tree()
    try:
        preview = '<persisted-output>\nOutput too large (19.5KB). Full output saved to: C:\\x\\b.txt'
        t.session('proj-a', SID, [rec_assistant([tool_use('t1', 'Bash'), tool_use('t2', 'Bash')]),
                                   rec_user_blocks([tool_result('t1', '가' * 19999)]),
                                   rec_user_blocks([tool_result('t2', preview)])])
        rc, out, err = digest(t)
        assert rc == 0, (rc, err)
        assert big_lines(out) == [], big_lines(out)
    finally:
        t.close()


@case
def big_error_stays_err():
    # ㉓ 20,000자 오류 결과는 ERR 로만 나온다
    t = Tree()
    try:
        t.session('proj-a', SID, [rec_assistant([tool_use('t1', 'Bash')]),
                                   rec_user_blocks([tool_result('t1', '오' * 20000, is_error=True)])])
        rc, out, err = digest(t)
        assert rc == 0, (rc, err)
        assert big_lines(out) == [], big_lines(out)
        assert any(l.startswith('ERR: 오') for l in out.splitlines()), out[:400]
    finally:
        t.close()


# ── append_deferred ─────────────────────────────────────────────────────────

LEDGER = (
    '﻿# Deferred 대장\r\n'
    '\r\n'
    '> 머리말\r\n'
    '\r\n'
    '## 대기\r\n'
    '\r\n'
    '- [2026-10-01] **맨 위 항목** — 본문 (출처: x) (실해: 2026-10-01 관측)\r\n'
    '\r\n'
    '**▶ 현행 잔량(기계 대조 대상)**: 대기 3 / 종결 119\r\n'
    '\r\n'
    '### 대장 운영\r\n'
    '\r\n'
    '### hook · 안전망\r\n'
    '\r\n'
    '- [2026-10-02] **hook 항목** — 본문 (출처: x) (실해: 2026-10-02 관측)\r\n'
    '\r\n'
    '\r\n'
    '\r\n'
    '### eval · 측정\r\n'
    '\r\n'
    '- [2026-10-03] **eval 항목** — 본문 (출처: x) (실해: 2026-10-03 관측)\r\n'
    '\r\n'
    '---\r\n'
    '\r\n'
    '> 꼬리 인용\r\n'
)

ENTRY = '- [2026-10-21] **새 항목** — 본문 (출처: reflect 11111111) (실해: 2026-10-21 관측)'


class Ledger:
    def __init__(self, text=LEDGER):
        self.dir = tempfile.mkdtemp(prefix='karina-ledger-')
        self.path = os.path.join(self.dir, 'deferred.md')
        with open(self.path, 'wb') as f:
            f.write(text.encode('utf-8'))
        self.before = self.bytes()

    def bytes(self):
        with open(self.path, 'rb') as f:
            return f.read()

    def text(self):
        return self.bytes().decode('utf-8')

    def append(self, group, entries):
        ep = os.path.join(self.dir, 'entries.txt')
        with open(ep, 'w', encoding='utf-8', newline='\n') as f:
            f.write('\n'.join(entries) + '\n')
        return run(APPEND, ['--ledger', self.path, '--group', group, '--entries', ep])

    def close(self):
        shutil.rmtree(self.dir, ignore_errors=True)


@case
def append_keeps_crlf_and_bom():
    # ⑪ 대장 쓰기가 CRLF·BOM 을 보존한다
    lg = Ledger()
    try:
        rc, _, err = lg.append('hook · 안전망', [ENTRY])
        assert rc == 0, (rc, err)
        b = lg.bytes()
        assert b.startswith(b'\xef\xbb\xbf'), 'BOM'
        assert b.count(b'\n') == b.count(b'\r\n'), '모든 줄이 CRLF'
    finally:
        lg.close()


@case
def append_into_named_group_only():
    # ⑫ 지정 그룹 끝에 들어가고 다른 그룹은 그대로다
    lg = Ledger()
    try:
        rc, _, _ = lg.append('hook · 안전망', [ENTRY])
        assert rc == 0
        lines = lg.text().split('\r\n')
        i = lines.index('- [2026-10-02] **hook 항목** — 본문 (출처: x) (실해: 2026-10-02 관측)')
        assert lines[i + 1] == ENTRY, lines[i:i + 3]
        assert lg.text().count(ENTRY) == 1
        assert lg.text().replace(ENTRY + '\r\n', '', 1).replace('대기 4', '대기 3') == lg.before.decode('utf-8')
    finally:
        lg.close()


@case
def append_bumps_counter():
    # ⑬ 잔량 줄 대기 수가 넣은 수만큼 오른다
    lg = Ledger()
    try:
        second = ENTRY.replace('새 항목', '둘째 항목')
        rc, _, _ = lg.append('hook · 안전망', [ENTRY, second])
        assert rc == 0
        assert '**▶ 현행 잔량(기계 대조 대상)**: 대기 5 / 종결 119' in lg.text()
    finally:
        lg.close()


@case
def append_missing_anchor_exit2():
    # ⑭ 그룹 없음·잔량 줄 없음 → exit 2 · 파일 불변
    lg = Ledger()
    try:
        rc, _, err = lg.append('없는 그룹', [ENTRY])
        assert rc == 2 and lg.bytes() == lg.before, rc
        assert '그룹 없음' in err, err
    finally:
        lg.close()
    lg = Ledger(LEDGER.replace('**▶ 현행 잔량(기계 대조 대상)**: 대기 3 / 종결 119\r\n', ''))
    try:
        rc, _, err = lg.append('hook · 안전망', [ENTRY])
        assert rc == 2 and lg.bytes() == lg.before, rc
        assert '잔량 줄 없음' in err, err
    finally:
        lg.close()


@case
def append_rejects_bad_entries():
    # ⑮ 형식 위반 항목(날짜 머리·실해 필드·600자) → exit 2 · 파일 불변
    bad = ['- **날짜 없음** — 본문 (실해: 2026-10-21 관측)',
           '- [2026-10-21] **실해 없음** — 본문 (출처: x)',
           '- [2026-10-21] **긴 항목** — ' + '가' * 600 + ' (실해: 2026-10-21 관측)']
    for e in bad:
        lg = Ledger()
        try:
            rc, _, err = lg.append('hook · 안전망', [ENTRY, e])
            assert rc == 2 and lg.bytes() == lg.before, (e[:30], rc)
            assert '형식 위반' in err, err
        finally:
            lg.close()


@case
def append_last_group_before_rule():
    # ⑯ 마지막 그룹에 넣어도 `---` 꼬리 앞에 들어간다
    lg = Ledger()
    try:
        rc, _, _ = lg.append('eval · 측정', [ENTRY])
        assert rc == 0
        lines = lg.text().split('\r\n')
        i = lines.index('- [2026-10-03] **eval 항목** — 본문 (출처: x) (실해: 2026-10-03 관측)')
        assert lines[i + 1] == ENTRY and lines.index('---') > i + 1, lines[i:]
        assert lines[-2:] == ['> 꼬리 인용', ''], lines[-3:]
    finally:
        lg.close()


@case
def append_empty_group():
    # ⑰ 항목 없는 그룹이면 헤딩 뒤 빈 줄 하나 다음에 들어간다
    lg = Ledger()
    try:
        rc, _, _ = lg.append('대장 운영', [ENTRY])
        assert rc == 0
        lines = lg.text().split('\r\n')
        i = lines.index('### 대장 운영')
        assert lines[i + 1] == '' and lines[i + 2] == ENTRY and lines[i + 3] == '', lines[i:i + 5]
        assert lines[i + 4] == '### hook · 안전망', lines[i:i + 5]
    finally:
        lg.close()


@case
def append_keeps_trailing_blank_lines():
    # ⑱ 그룹 끝 빈 줄이 여러 개여도 마지막 항목 바로 뒤에 들어가고 빈 줄 수가 그대로다
    lg = Ledger()
    try:
        rc, _, _ = lg.append('hook · 안전망', [ENTRY])
        assert rc == 0
        lines = lg.text().split('\r\n')
        i = lines.index(ENTRY)
        assert lines[i + 1:i + 5] == ['', '', '', '### eval · 측정'], lines[i:i + 5]
    finally:
        lg.close()


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    failed = 0
    for fn in CASES:
        try:
            fn()
            print('PASS', fn.__name__)
        except Exception as e:  # 케이스 하나의 실패가 나머지 판정을 막지 않게 한다
            failed += 1
            print('FAIL', fn.__name__, '-', type(e).__name__, str(e)[:300])
    print('%d/%d PASS' % (len(CASES) - failed, len(CASES)))
    return 1 if failed else 0


if __name__ == '__main__':
    sys.exit(main())
