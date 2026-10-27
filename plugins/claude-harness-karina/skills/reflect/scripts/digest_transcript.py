"""karina:reflect — 현재 세션의 Claude Code 전사를 리뷰어가 읽을 요약으로 줄인다.

찾는 파일: `<projects>/*/<세션ID>.jsonl` 정확히 1개와 `<projects>/<그 폴더>/<세션ID>/subagents/*.jsonl`.
세션 ID 는 `--session`, 없으면 환경변수 `CLAUDE_CODE_SESSION_ID` 다 — 같은 폴더에 다른 탭의 세션 파일이 있어
최신 파일로 고르면 남의 세션을 읽는다.

출력 줄 머리 — U: 사용자 text · A: 모델 text · T: 도구 호출(이름 + 명령·경로 한 구) · ERR: 오류 도구 결과(hook 차단 포함)
· H: hook 첨부(경고 additionalContext · 취소) · BIG: 큰 성공 결과(`BIG: <도구명> <N>자 <앞 120자>` — 본문 길이나
`<persisted-output>` 미리보기의 `Output too large (<크기>)` 가 BIG_CAP 이상, 도구명은 tool_use_id 로 찾고 못 찾으면 `?`).
그 밖(thinking·BIG_CAP 미만의 성공 결과·메타 레코드)은 싣지 않는다.
머리에 읽은 파일·갈래별 줄 수·총 줄 수를 싣는다 — 리뷰어가 총 줄 수까지 나눠 읽는다.

종료 코드: 0 정상 · 2 세션 판정 실패(ID 없음·파일 0개·2개 이상) · 3 인식한 레코드 0(전사 형식이 바뀌었을 수 있다).
전사 형식은 Claude Code 내부 형식이라 문서화돼 있지 않다 — 2.1.306 실측 기준이다.
"""
import argparse
import glob
import json
import os
import re
import sys

TEXT_CAP = 600
SHORT_CAP = 300
BIG_CAP = 20000
BIG_HEAD = 120
HOOK_TYPES = ('hook_additional_context', 'hook_cancelled')
PERSISTED = re.compile(r'<persisted-output>\s*Output too large \(([\d.]+)(KB|MB)\)')


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


def remember_tool_names(d, tool_name_by_id):
    if d.get('type') != 'assistant' or not isinstance(d.get('message'), dict):
        return
    for b in d['message'].get('content') or []:
        if isinstance(b, dict) and b.get('type') == 'tool_use':
            tool_name_by_id[b.get('id')] = b.get('name')


def record_lines(d, tool_name_by_id):
    t = d.get('type')
    m = d.get('message') if isinstance(d.get('message'), dict) else {}
    c = m.get('content')
    if t == 'user':
        if isinstance(c, str):
            return ['U: ' + cut(c, TEXT_CAP)]
        out = []
        for b in c or []:
            if b.get('type') == 'text':
                out.append('U: ' + cut(b.get('text', ''), TEXT_CAP))
            elif b.get('type') == 'tool_result' and b.get('is_error'):
                out.append('ERR: ' + cut(_result_text(b.get('content')), SHORT_CAP))
            elif b.get('type') == 'tool_result':
                text = _result_text(b.get('content'))
                size = result_size(text)
                if size >= BIG_CAP:
                    name = tool_name_by_id.get(b.get('tool_use_id'), '?')
                    out.append('BIG: %s %d자 %s' % (name, size, cut(text, BIG_HEAD)))
        return out
    if t == 'assistant':
        out = []
        for b in c or []:
            if b.get('type') == 'text':
                out.append('A: ' + cut(b.get('text', ''), TEXT_CAP))
            elif b.get('type') == 'tool_use':
                hint = cut(_tool_hint(b.get('input') or {}), SHORT_CAP)
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


def digest_file(path, counts):
    lines, recognized, tool_name_by_id = [], 0, {}
    with open(path, encoding='utf-8', errors='replace') as f:
        for raw in f:
            try:
                d = json.loads(raw)
            except ValueError:
                continue
            if not isinstance(d, dict):
                continue
            remember_tool_names(d, tool_name_by_id)
            got = record_lines(d, tool_name_by_id)
            if got is None:
                continue
            recognized += 1
            for line in got:
                counts[line.split(':', 1)[0]] = counts.get(line.split(':', 1)[0], 0) + 1
                lines.append(line)
    return lines, recognized


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
    counts, body, recognized = {}, [], 0
    lines, n = digest_file(mains[0], counts)
    body += lines
    recognized += n
    for sub in subs:
        lines, n = digest_file(sub, counts)
        body += ['## subagent ' + os.path.basename(sub)] + lines
        recognized += n
    if recognized == 0:
        print('인식한 레코드 0 — 전사 형식이 바뀌었을 수 있다: %s' % mains[0], file=sys.stderr)
        return 3
    head = ['# reflect 요약 — 세션 %s' % sid, '# 본 전사: %s' % mains[0], '# 서브에이전트 전사: %d개' % len(subs),
            '# 줄 수: ' + ' · '.join('%s %d' % (k, counts.get(k, 0)) for k in ('U', 'A', 'T', 'ERR', 'H', 'BIG'))]
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
