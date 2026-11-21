import datetime
import json
import os
import shutil
import subprocess
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
DIGEST = os.path.join(HERE, '..', 'scripts', 'digest_transcript.py')
APPEND = os.path.join(HERE, '..', 'scripts', 'append_deferred.py')
HISTORY = os.path.join(HERE, '..', 'scripts', 'digest_history.py')

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


T0 = datetime.datetime(2026, 11, 15, 10, 0, 0, tzinfo=datetime.timezone.utc)


def at(rec, sec, mid=None, usage=None):
    r = json.loads(json.dumps(rec))
    r['timestamp'] = (T0 + datetime.timedelta(seconds=sec)).isoformat().replace('+00:00', 'Z')
    if mid is not None:
        r['message']['id'] = mid
    if usage is not None:
        r['message']['usage'] = usage
    return r


def slow_lines(out):
    return [l for l in out.splitlines() if l.startswith('SLOW: ')]


def segment_lines(out):
    return [l for l in out.splitlines() if l.startswith('# 구간 ')]


def run_timed(records, subagents=(), extra=()):
    t = Tree()
    try:
        t.session('proj-a', SID, records)
        for name, recs, meta in subagents:
            t.subagent('proj-a', SID, name, recs)
            if meta is not None:
                path = os.path.join(t.root, 'proj-a', SID, 'subagents', name.replace('.jsonl', '.meta.json'))
                with open(path, 'w', encoding='utf-8') as f:
                    json.dump(meta, f)
        rc, out, err = digest(t, list(extra))
        assert rc == 0, (rc, err)
        return out
    finally:
        t.close()


def tool_pair(tid, name, start, end, command='x'):
    return [at(rec_assistant([tool_use(tid, name, command)]), start),
            at(rec_user_blocks([tool_result(tid, '출력')]), end)]


@case
def slow_line_marked():
    out = run_timed(tool_pair('t1', 'Bash', 0, 75, 'sleep 75'))
    assert slow_lines(out) == ['SLOW: Bash 75초 sleep 75'], out


@case
def below_slow_excluded():
    out = run_timed(tool_pair('t1', 'Bash', 0, 59))
    assert slow_lines(out) == [], out


@case
def ask_user_not_slow():
    out = run_timed(tool_pair('q1', 'AskUserQuestion', 0, 600))
    assert slow_lines(out) == [], out


@case
def agent_not_slow():
    out = run_timed(tool_pair('a1', 'Agent', 0, 300))
    assert slow_lines(out) == [], out


@case
def agent_wait_excluded_from_work():
    recs = [at(rec_user('시작'), 0)] + tool_pair('a1', 'Agent', 5, 305) + \
        [at(rec_assistant([{'type': 'text', 'text': '받았다'}]), 315)]
    out = run_timed(recs)
    assert segment_lines(out)[0].startswith('# 구간 (스킬 밖): 작업 15초 · '), segment_lines(out)


@case
def notification_gap_excluded():
    recs = [at(rec_assistant([{'type': 'text', 'text': '기다린다'}]), 0),
            at(rec_user('Another Claude session sent a message: 끝'), 200),
            at(rec_assistant([{'type': 'text', 'text': '읽었다'}]), 205)]
    out = run_timed(recs)
    assert segment_lines(out)[0].startswith('# 구간 (스킬 밖): 작업 5초 · '), segment_lines(out)


@case
def user_text_gap_excluded():
    recs = [at(rec_assistant([{'type': 'text', 'text': '물었다'}]), 0),
            at(rec_user('답'), 100),
            at(rec_assistant([{'type': 'text', 'text': '이어간다'}]), 103)]
    out = run_timed(recs)
    assert segment_lines(out)[0].startswith('# 구간 (스킬 밖): 작업 3초 · '), segment_lines(out)


@case
def tokens_counted_once_per_message():
    u1 = {'input_tokens': 10, 'cache_read_input_tokens': 100, 'cache_creation_input_tokens': 20, 'output_tokens': 5}
    u2 = {'input_tokens': 1, 'cache_read_input_tokens': 2, 'cache_creation_input_tokens': 3, 'output_tokens': 4}
    recs = [at(rec_assistant([{'type': 'text', 'text': '앞'}]), 0, 'm1', u1),
            at(rec_assistant([tool_use('t1', 'Bash')]), 1, 'm1', u1),
            at(rec_assistant([{'type': 'text', 'text': '뒤'}]), 2, 'm2', u2)]
    out = run_timed(recs)
    assert segment_lines(out) == ['# 구간 (스킬 밖): 작업 2초 · 토큰 입력 11 · 캐시읽기 102 · 캐시쓰기 23 · 출력 9'], out


@case
def skill_segment_header():
    recs = [at(rec_assistant([{'type': 'text', 'text': '시작'}]), 0),
            at(rec_assistant([{'type': 'tool_use', 'id': 's1', 'name': 'Skill', 'input': {'skill': 'karina:plan'}}]), 10),
            at(rec_user_blocks([tool_result('s1', '발동')]), 11),
            at(rec_assistant([{'type': 'text', 'text': '계획'}]), 31)]
    segs = segment_lines(run_timed(recs))
    assert [s.split(' · ')[0] for s in segs] == ['# 구간 (스킬 밖): 작업 10초', '# 구간 karina:plan: 작업 21초'], segs


@case
def slash_command_segment_header():
    recs = [at(rec_user('<command-message>karina:plan-draft</command-message>\n'
                        '<command-name>/karina:plan-draft</command-name>'), 0),
            at(rec_assistant([{'type': 'text', 'text': '초안'}]), 4),
            at(rec_assistant([{'type': 'text', 'text': '끝'}]), 10)]
    segs = segment_lines(run_timed(recs))
    assert [s.split(' · ')[0] for s in segs] == ['# 구간 karina:plan-draft: 작업 10초'], segs


@case
def local_command_not_segment():
    recs = [at(rec_user('<command-name>/clear</command-name>\n<command-message>clear</command-message>'), 0),
            at({'type': 'system', 'subtype': 'local_command', 'content': '<local-command-stdout></local-command-stdout>',
                'commandRun': {'command': 'clear', 'args': ''}}, 2),
            at(rec_user('질문'), 50),
            at(rec_assistant([{'type': 'text', 'text': '답'}]), 57)]
    segs = segment_lines(run_timed(recs))
    assert [s.split(' · ')[0] for s in segs] == ['# 구간 (스킬 밖): 작업 9초'], segs


@case
def zero_segment_dropped():
    recs = [at(rec_assistant([{'type': 'text', 'text': '곧'}]), 0),
            at(rec_assistant([{'type': 'tool_use', 'id': 's1', 'name': 'Skill', 'input': {'skill': 'karina:plan'}}]), 0.3),
            at(rec_user_blocks([tool_result('s1', '발동')]), 1),
            at(rec_assistant([{'type': 'text', 'text': '계획'}]), 11)]
    segs = segment_lines(run_timed(recs))
    assert [s.split(' · ')[0] for s in segs] == ['# 구간 karina:plan: 작업 11초'], segs


@case
def subagent_segment_uses_agent_type():
    sub = [at(rec_assistant([{'type': 'text', 'text': '검토'}]), 0),
           at(rec_assistant([{'type': 'text', 'text': '끝'}]), 30)]
    out = run_timed([at(rec_user('시작'), 0)], [('agent-abc.jsonl', sub, {'agentType': 'karina:plan-reviewer'})])
    assert '# 구간 서브에이전트 karina:plan-reviewer: 작업 30초' in [s.split(' · ')[0] for s in segment_lines(out)], out
    assert '## subagent agent-abc.jsonl' in out.splitlines(), out


@case
def subagent_segment_without_meta_uses_file_name():
    sub = [at(rec_assistant([{'type': 'text', 'text': '검토'}]), 0),
           at(rec_assistant([{'type': 'text', 'text': '끝'}]), 8)]
    out = run_timed([at(rec_user('시작'), 0)], [('agent-abc.jsonl', sub, None)])
    assert '# 구간 서브에이전트 agent-abc.jsonl: 작업 8초' in [s.split(' · ')[0] for s in segment_lines(out)], out


def pre_hook(tid, sec):
    return at({'type': 'attachment', 'attachment': {
        'type': 'hook_success', 'hookName': 'PreToolUse:Bash', 'hookEvent': 'PreToolUse',
        'toolUseID': tid, 'content': '', 'exitCode': 0}}, sec)


@case
def slow_starts_at_pre_tool_use():
    out = run_timed([at(rec_assistant([tool_use('t1', 'Bash', 'gen')]), 0), pre_hook('t1', 70),
                     at(rec_user_blocks([tool_result('t1', '출력')]), 75)])
    assert slow_lines(out) == [], out


@case
def slow_measured_from_pre_tool_use():
    out = run_timed([at(rec_assistant([tool_use('t1', 'Bash', 'sleep 75')]), 0), pre_hook('t1', 5),
                     at(rec_user_blocks([tool_result('t1', '출력')]), 80)])
    assert slow_lines(out) == ['SLOW: Bash 75초 sleep 75'], out


@case
def early_attachment_not_double_counted():
    recs = [at(rec_assistant([{'type': 'text', 'text': '시작'}]), 0),
            at(rec_assistant([tool_use('t1', 'Bash')]), 10), pre_hook('t1', 4),
            at(rec_user_blocks([tool_result('t1', '출력')]), 12)]
    out = run_timed(recs)
    assert segment_lines(out)[0].startswith('# 구간 (스킬 밖): 작업 12초 · '), segment_lines(out)


def skill_use(tid, name, sec):
    return at(rec_assistant([{'type': 'tool_use', 'id': tid, 'name': 'Skill', 'input': {'skill': name}}]), sec)


def segment_names(out):
    return [s[len('# 구간 '):].split(': 작업 ')[0] for s in segment_lines(out)]


def bash_lines(out):
    return [l for l in out.splitlines() if l.startswith('# Bash 소요:')]


@case
def nested_skill_under_plugin_root():
    recs = [skill_use('s1', 'karina:implement', 0), at(rec_user_blocks([tool_result('s1', '발동')]), 1),
            skill_use('s2', 'verify-karina', 10), at(rec_user_blocks([tool_result('s2', '발동')]), 11),
            at(rec_assistant([{'type': 'text', 'text': '다음 task'}]), 31)]
    segs = segment_lines(run_timed(recs))
    assert [s.split(' · ')[0] for s in segs] == ['# 구간 karina:implement: 작업 10초',
                                                 '# 구간 karina:implement › verify-karina: 작업 21초'], segs


@case
def first_repo_skill_outside_is_root():
    recs = [skill_use('s1', 'verify-karina', 0), at(rec_assistant([{'type': 'text', 'text': '조작'}]), 10)]
    assert segment_names(run_timed(recs)) == ['verify-karina'], recs


@case
def plugin_skill_starts_new_root():
    recs = [skill_use('s1', 'karina:implement', 0), skill_use('s2', 'verify-karina', 5),
            skill_use('s3', 'karina:reflect', 10), at(rec_assistant([{'type': 'text', 'text': '회고'}]), 20)]
    out = run_timed(recs)
    assert segment_names(out) == ['karina:implement', 'karina:implement › verify-karina', 'karina:reflect'], out


@case
def local_command_restores_root():
    recs = [skill_use('s1', 'karina:implement', 0), skill_use('s2', 'verify-karina', 5),
            at(rec_user_blocks([tool_result('s2', '발동')]), 6),
            at(rec_user('<command-name>/clear</command-name>\n<command-message>clear</command-message>'), 10),
            at({'type': 'system', 'subtype': 'local_command', 'content': '<local-command-stdout></local-command-stdout>',
                'commandRun': {'command': 'clear', 'args': ''}}, 12),
            skill_use('s3', 'karina-computer-use', 20), at(rec_assistant([{'type': 'text', 'text': '끝'}]), 30)]
    out = run_timed(recs)
    assert segment_names(out) == ['karina:implement', 'karina:implement › verify-karina',
                                  'karina:implement › karina-computer-use'], out


@case
def bash_time_summed_by_kind():
    recs = tool_pair('b1', 'Bash', 0, 100, 'cargo test --no-fail-fast > t.txt 2>&1') + \
        tool_pair('b2', 'Bash', 200, 230, 'cargo clippy --all-targets -- -D warnings') + \
        tool_pair('b3', 'Bash', 300, 360, 'pwsh -File helpers/launch.ps1 -Repo .') + \
        tool_pair('b4', 'Bash', 400, 405, 'git commit -m "test 추가"') + \
        tool_pair('b5', 'Bash', 500, 502, 'ls')
    sub = tool_pair('c1', 'Bash', 0, 20, 'python docs/test-task.py out.txt')
    out = run_timed(recs, [('agent-abc.jsonl', sub, None)])
    assert bash_lines(out) == ['# Bash 소요: 시험 120초 2회 · 검사·형식 30초 1회 · 기동·빌드 60초 1회 · 기타 7초 2회'], out


@case
def git_after_cd_is_other():
    recs = tool_pair('b1', 'Bash', 0, 10, 'cd "D:/repo x"; git commit -m "test 추가"') + \
        tool_pair('b2', 'Bash', 20, 25, "cd /repo && git log --grep check")
    assert bash_lines(run_timed(recs)) == ['# Bash 소요: 시험 0초 0회 · 검사·형식 0초 0회 · 기동·빌드 0초 0회 · 기타 15초 2회'], recs


def background_bash(tid, start, launched, done, command):
    note = ('<task-notification>\n<task-id>x1</task-id>\n<tool-use-id>%s</tool-use-id>\n'
            '<output-file>o.txt</output-file>\n<status>completed</status>\n</task-notification>' % tid)
    return [at(rec_assistant([tool_use(tid, 'Bash', command)]), start),
            at(rec_user_blocks([tool_result(tid, 'Command running in background with ID: x1. Output is being written to: o.txt')]), launched),
            at(rec_user(note), done)]


@case
def background_bash_measured_to_notification():
    out = run_timed(background_bash('t1', 0, 1, 230, 'pwsh -File run-hook-evals.ps1'))
    assert slow_lines(out) == ['SLOW: Bash 230초 (백그라운드) pwsh -File run-hook-evals.ps1'], out
    assert bash_lines(out) == ['# Bash 소요: 시험 230초 1회 · 검사·형식 0초 0회 · 기동·빌드 0초 0회 · 기타 0초 0회'], out


@case
def background_bash_slow_kept_in_audit():
    out = run_timed(background_bash('t1', 0, 1, 90, 'sleep 90'), extra=['--audit'])
    assert slow_lines(out) == ['SLOW: Bash 90초 (백그라운드) sleep 90'], out


@case
def background_bash_short_not_slow():
    out = run_timed(background_bash('t1', 0, 1, 30, 'sleep 30'))
    assert slow_lines(out) == [], out
    assert bash_lines(out) == ['# Bash 소요: 시험 0초 0회 · 검사·형식 0초 0회 · 기동·빌드 0초 0회 · 기타 30초 1회'], out


@case
def audit_has_no_bash_line():
    out = run_timed(tool_pair('b1', 'Bash', 0, 100, 'cargo test'), extra=['--audit'])
    assert bash_lines(out) == [], out


@case
def audit_keeps_slow_bash_only():
    recs = [at(rec_user('<command-name>/karina:implement</command-name>'), 0)] + \
        tool_pair('t1', 'Bash', 1, 100, 'sleep 99')
    out = run_timed(recs, extra=['--audit'])
    assert slow_lines(out) == ['SLOW: Bash 99초 sleep 99'] and segment_lines(out) == [], out
    assert 'T: Bash sleep 99' in out.splitlines(), out


@case
def audit_drops_slow_non_bash():
    recs = [at(rec_assistant([{'type': 'tool_use', 'id': 'r1', 'name': 'Read', 'input': {'file_path': 'a.md'}}]), 0),
            at(rec_user_blocks([tool_result('r1', '출력')]), 90)]
    out = run_timed(recs, extra=['--audit'])
    assert slow_lines(out) == [], out


AUDIT = [
    rec_user('평범한 사용자 말'),
    rec_user('<command-name>/karina:implement</command-name>'),
    rec_assistant([{'type': 'text', 'text': '접근 A 를 버리고 B 로 간다'},
                   tool_use('b1', 'Bash', 'git restore a.py'),
                   {'type': 'tool_use', 'id': 's1', 'name': 'Skill', 'input': {'skill': 'karina:implement'}},
                   {'type': 'tool_use', 'id': 'r1', 'name': 'Read', 'input': {'file_path': 'C:\\x\\읽은파일.md'}}]),
    rec_user_blocks([tool_result('b1', '오류 출력', is_error=True)]),
    rec_user_blocks([tool_result('r1', '큰' * 20000)]),
    rec_hook('훅 경고'),
]


def audit_digest(t):
    t.session('proj-a', SID, AUDIT)
    t.subagent('proj-a', SID, 'agent-abc.jsonl', [rec_assistant([{'type': 'text', 'text': '서브에이전트 답'}])])
    return digest(t, ['--audit'])


@case
def audit_skips_subagents():
    t = Tree()
    try:
        rc, out, err = audit_digest(t)
        assert rc == 0, (rc, err)
        assert '## subagent' not in out and '서브에이전트 답' not in out, out
    finally:
        t.close()


@case
def audit_drops_other_lines():
    t = Tree()
    try:
        rc, out, err = audit_digest(t)
        assert rc == 0, (rc, err)
        body = [l for l in out.splitlines() if not l.startswith('# ')]
        for bad in ('U: 평범한', 'ERR: ', 'H: ', 'BIG: ', 'T: Read'):
            assert not any(l.startswith(bad) for l in body), (bad, body)
    finally:
        t.close()


@case
def audit_keeps_decision_lines():
    t = Tree()
    try:
        rc, out, err = audit_digest(t)
        assert rc == 0, (rc, err)
        body = [l for l in out.splitlines() if not l.startswith('# ')]
        assert body == ['U: <command-name>/karina:implement</command-name>', 'A: 접근 A 를 버리고 B 로 간다',
                        'T: Bash git restore a.py', 'T: Skill karina:implement'], body
    finally:
        t.close()


@case
def audit_header_marks_mode():
    t = Tree()
    try:
        rc, out, err = audit_digest(t)
        assert rc == 0, (rc, err)
        head = [l for l in out.splitlines() if l.startswith('# ')]
        assert '# 모드: audit' in head, head
        assert '# 줄 수: U 1 · A 1 · T 2' in head, head
    finally:
        t.close()


@case
def audit_marks_hangul_free_lines():
    t = Tree()
    try:
        t.session('proj-a', SID, [rec_assistant([{'type': 'text', 'text': 'Now running the full verification.'}]),
                                  rec_assistant([{'type': 'text', 'text': '검증을 돌린다'}])])
        rc, out, err = digest(t, ['--audit'])
        assert rc == 0, (rc, err)
        lines = out.splitlines()
        assert '# 한글 없는 A: 1' in lines, lines
        assert 'A: [한글 없음] Now running the full verification.' in lines, lines
    finally:
        t.close()


def read_use(tid, path):
    return {'type': 'tool_use', 'id': tid, 'name': 'Read', 'input': {'file_path': path}}


@case
def audit_keeps_image_reads_only():
    t = Tree()
    try:
        t.session('proj-a', SID, [rec_assistant([read_use('r1', 'C:\\ev\\demo.png'), read_use('r2', 'C:\\x\\notes.md'),
                                                 read_use('r3', 'C:\\ev\\shot.JPG')])])
        rc, out, err = digest(t, ['--audit'])
        assert rc == 0, (rc, err)
        body = [l for l in out.splitlines() if not l.startswith('# ')]
        assert body == ['T: Read C:\\ev\\demo.png', 'T: Read C:\\ev\\shot.JPG'], body
    finally:
        t.close()


@case
def audit_keeps_long_image_path_whole():
    t = Tree()
    try:
        path = 'C:\\' + 'a' * 320 + '\\final-demo.png'
        t.session('proj-a', SID, [rec_assistant([read_use('r1', path)])])
        rc, out, err = digest(t, ['--audit'])
        assert rc == 0, (rc, err)
        assert 'T: Read ' + path in out.splitlines(), out
    finally:
        t.close()


@case
def audit_keeps_subagent_image_reads_under_header():
    sub = [rec_assistant([read_use('s1', 'C:\\ev\\sv.png'), read_use('s2', 'C:\\x\\SKILL.md'),
                          tool_use('s3', 'Bash', 'pwsh shot.ps1'), {'type': 'text', 'text': '판정 참'}])]
    out = run_timed([rec_assistant([read_use('r1', 'C:\\ev\\main.png')])],
                    [('agent-v.jsonl', sub, {'agentType': 'karina:screen-verifier'})], ['--audit'])
    body = [l for l in out.splitlines() if not l.startswith('# ')]
    assert body == ['T: Read C:\\ev\\main.png', '## subagent agent-v.jsonl (karina:screen-verifier)',
                    'T: Read C:\\ev\\sv.png'], body


@case
def audit_omits_subagent_header_without_image_reads():
    sub = [rec_assistant([tool_use('s1', 'Bash', 'pwsh doctor.ps1'), {'type': 'text', 'text': '판정 참'}])]
    out = run_timed([rec_assistant([read_use('r1', 'C:\\ev\\main.png')])],
                    [('agent-v.jsonl', sub, {'agentType': 'karina:screen-verifier'})], ['--audit'])
    assert '## subagent' not in out and 'doctor.ps1' not in out, out


@case
def audit_leaves_korean_lines():
    t = Tree()
    try:
        rc, out, err = audit_digest(t)
        assert rc == 0, (rc, err)
        assert '[한글 없음]' not in out, out
    finally:
        t.close()


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
        group_args = [] if group is None else ['--group', group]
        return run(APPEND, ['--ledger', self.path] + group_args + ['--entries', ep])

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


REPO_LEDGER = (
    '# Deferred 대장\r\n'
    '\r\n'
    '## 대기\r\n'
    '- [2026-07-15] 첫 항목 (실해: 2026-07-15 관측)\r\n'
    '- [2026-07-16] 둘째 항목 (실해: 2026-07-16 관측)\r\n'
    '\r\n'
    '## 종결\r\n'
    '- [2026-07-01] 끝난 항목 (실해: 2026-07-01 관측)\r\n'
)


@case
def append_no_group_into_daegi():
    lg = Ledger(REPO_LEDGER)
    try:
        rc, _, err = lg.append(None, [ENTRY])
        assert rc == 0, (rc, err)
        lines = lg.text().split('\r\n')
        assert lines[lines.index(ENTRY) - 1].startswith('- [2026-07-16] 둘째 항목'), lines
        assert lg.text().endswith('## 종결\r\n- [2026-07-01] 끝난 항목 (실해: 2026-07-01 관측)\r\n'), lg.text()
        assert lg.bytes().count(b'\n') == lg.bytes().count(b'\r\n'), '모든 줄이 CRLF'
    finally:
        lg.close()


@case
def append_no_group_whole_file():
    text = '# 대장\n\n- [2026-07-15] 하나 (실해: 2026-07-15 관측)\n- [2026-07-16] 둘 (실해: 2026-07-16 관측)\n\n> 꼬리\n'
    lg = Ledger(text)
    try:
        rc, _, err = lg.append(None, [ENTRY])
        assert rc == 0, (rc, err)
        lines = lg.text().split('\n')
        assert lines[lines.index(ENTRY) - 1].startswith('- [2026-07-16] 둘'), lines
        assert b'\r' not in lg.bytes(), 'LF 유지'
        assert lg.text().endswith('\n\n> 꼬리\n'), lg.text()
    finally:
        lg.close()


@case
def append_no_group_without_counter():
    lg = Ledger(REPO_LEDGER)
    try:
        rc, _, err = lg.append(None, [ENTRY])
        assert rc == 0, (rc, err)
    finally:
        lg.close()
    lg = Ledger(REPO_LEDGER.replace('## 대기\r\n', '## 대기\r\n**▶ 현행 잔량(기계 대조 대상)**: 대기 2\r\n'))
    try:
        rc, _, err = lg.append(None, [ENTRY])
        assert rc == 0, (rc, err)
        assert '**▶ 현행 잔량(기계 대조 대상)**: 대기 3' in lg.text(), lg.text()
    finally:
        lg.close()


@case
def append_no_group_empty_daegi():
    lg = Ledger('# 대장\r\n\r\n## 대기\r\n\r\n## 종결\r\n')
    try:
        rc, _, err = lg.append(None, [ENTRY])
        assert rc == 0, (rc, err)
        lines = lg.text().split('\r\n')
        i = lines.index('## 대기')
        assert lines[i + 1:i + 5] == ['', ENTRY, '', '## 종결'], lines
    finally:
        lg.close()


@case
def append_no_group_after_continuation():
    lg = Ledger('## 대기\r\n- [2026-07-16] 둘 (실해: 2026-07-16 관측)\r\n  - 하위 1\r\n  - 하위 2\r\n\r\n## 종결\r\n')
    try:
        rc, _, err = lg.append(None, [ENTRY])
        assert rc == 0, (rc, err)
        lines = lg.text().split('\r\n')
        assert lines[1:5] == ['- [2026-07-16] 둘 (실해: 2026-07-16 관측)', '  - 하위 1', '  - 하위 2', ENTRY], lines
    finally:
        lg.close()


HIST_NOW = datetime.datetime(2026, 6, 1, 12, 0, 0)


def git_repo(commits):
    d = tempfile.mkdtemp(prefix='reflect-hist-')
    base = dict(os.environ, GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@t', GIT_COMMITTER_NAME='t', GIT_COMMITTER_EMAIL='t@t')
    subprocess.run(['git', 'init', '-q', d], check=True, env=base)
    for i, (subject, body, days_ago) in enumerate(commits):
        with open(os.path.join(d, 'f%d.txt' % i), 'w', encoding='utf-8') as f:
            f.write(subject)
        subprocess.run(['git', '-C', d, 'add', '.'], check=True, env=base)
        when = (HIST_NOW - datetime.timedelta(days=days_ago)).strftime('%Y-%m-%dT%H:%M:%S')
        env = dict(base, GIT_AUTHOR_DATE=when, GIT_COMMITTER_DATE=when)
        subprocess.run(['git', '-C', d, 'commit', '-q', '-m', subject + ('\n\n' + body if body else '')], check=True, env=env)
    return d


def history(repo, extra=()):
    out = os.path.join(tempfile.mkdtemp(prefix='reflect-hist-out-'), 'h.txt')
    rc, so, se = run(HISTORY, ['--repo', repo, '--out', out, '--now', HIST_NOW.strftime('%Y-%m-%dT%H:%M:%S')] + list(extra))
    text = open(out, encoding='utf-8').read() if os.path.exists(out) else ''
    return rc, so + se, text


@case
def history_keeps_fix_and_revert_only():
    d = git_repo([('수정: 차단 문구 오탐', '첫 줄 본문\n둘째 줄', 3), ('기능: 새 스킬', '', 2),
                  ('수정: 같은 오탐 재발', '', 1), ('Revert "기능: 새 스킬"', '', 1)])
    try:
        rc, out, text = history(d)
        assert rc == 0, (rc, out)
        assert text.startswith('# 총 줄 수:'), text[:80]
        for s in ('수정: 차단 문구 오탐', '수정: 같은 오탐 재발', 'Revert "기능: 새 스킬"', '첫 줄 본문'):
            assert s in text, (s, text)
        assert '\n기능: 새 스킬' not in text and 'SUBJECT 기능: 새 스킬' not in text, text
        assert text.count('== commit ') == 3, text
    finally:
        shutil.rmtree(d, ignore_errors=True)


@case
def history_revert_needs_word_boundary():
    d = git_repo([('Reverting the cache layout', '', 2), ('Revert "기능: 캐시"', '', 1)])
    try:
        rc, out, text = history(d)
        assert rc == 0, (rc, out)
        assert 'Reverting the cache layout' not in text, text
        assert 'Revert "기능: 캐시"' in text, text
    finally:
        shutil.rmtree(d, ignore_errors=True)


@case
def history_drops_commits_outside_window():
    d = git_repo([('수정: 오래된 수정', '', 200), ('수정: 최근 수정', '', 5)])
    try:
        rc, out, text = history(d, ['--days', '90'])
        assert rc == 0, (rc, out)
        assert '수정: 최근 수정' in text and '수정: 오래된 수정' not in text, text
    finally:
        shutil.rmtree(d, ignore_errors=True)


@case
def history_lists_non_ascii_file_names():
    d = git_repo([('수정: 하나', '', 3)])
    try:
        with open(os.path.join(d, '화면.md'), 'w', encoding='utf-8') as f:
            f.write('x')
        when = (HIST_NOW - datetime.timedelta(days=1)).strftime('%Y-%m-%dT%H:%M:%S')
        env = dict(os.environ, GIT_AUTHOR_NAME='t', GIT_AUTHOR_EMAIL='t@t', GIT_COMMITTER_NAME='t',
                   GIT_COMMITTER_EMAIL='t@t', GIT_AUTHOR_DATE=when, GIT_COMMITTER_DATE=when)
        subprocess.run(['git', '-C', d, 'add', '.'], check=True, env=env)
        subprocess.run(['git', '-C', d, 'commit', '-q', '-m', '수정: 한글 파일'], check=True, env=env)
        rc, out, text = history(d)
        assert rc == 0, (rc, out)
        assert 'FILE 화면.md' in text, text
    finally:
        shutil.rmtree(d, ignore_errors=True)


@case
def history_not_a_repo_exit2():
    d = tempfile.mkdtemp(prefix='reflect-hist-norepo-')
    try:
        rc, out, _ = history(d)
        assert rc == 2, (rc, out)
    finally:
        shutil.rmtree(d, ignore_errors=True)


@case
def history_git_timeout_is_git_failure():
    import importlib.util
    sys.path.insert(0, os.path.join(HERE, '..', '..', '..', 'scripts'))
    import timed_run
    spec = importlib.util.spec_from_file_location('digest_history_under_test', HISTORY)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    calls = []

    def hang(cmd, **kw):
        calls.append(kw.get('timeout'))
        raise subprocess.TimeoutExpired(cmd, kw.get('timeout'))
    saved = timed_run.run
    timed_run.run = hang
    try:
        got = mod.git(tempfile.gettempdir(), ['log'])
    finally:
        timed_run.run = saved
    assert got == (128, ''), got
    assert calls == [120], calls


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
