"""karina:reflect — 사용자가 고른 개선 후보를 Deferred 대장에 넣는다.

Edit 도구·텍스트 모드 쓰기는 파일 전체를 LF 로 바꿔 정합 검사의 줄바꿈 축이 실패하므로, 바이트로 읽어
그 파일의 줄바꿈·BOM 을 그대로 쓴다.

- 범위: `--group` 이 있으면(하니스 대장 `docs/plans/deferred.md`) `### <그룹>` 헤딩부터 다음 `### ` · `---` 줄 · EOF
  중 먼저 오는 것까지(잔량 줄은 그룹들보다 앞에 있다). 없으면(다른 레포 대장) `## 대기` 줄부터 다음 `## ` 줄 · EOF
  까지, `## 대기` 가 없으면 파일 전체.
- 넣는 자리: 범위 안 마지막 `- [` 항목과 그 아래 들여쓴 연속 줄 바로 뒤 · 항목이 없으면 헤딩 뒤 빈 줄 하나 다음
  (파일 전체면 끝에 빈 줄 하나를 두고). 범위 끝 빈 줄은 그대로 둔다.
- 잔량 줄 `**▶ 현행 잔량(기계 대조 대상)**: 대기 N` 의 N 을 넣은 수만큼 올린다 — `--group` 모드는 필수, 아니면 있을 때만.

종료 코드: 0 정상 · 2 그룹 없음·(`--group` 모드) 잔량 줄 없음·형식 위반 항목(날짜 머리·`(실해: ` 필드·600자 상한)
— 이때 파일을 쓰지 않는다.
항목 형식·상한의 정본은 `../../plan/references/deferred-rules.md` 와 대장 머리말이다.
"""
import argparse
import re
import sys

ENTRY_HEAD = re.compile(r'^- \[\d{4}-\d{2}-\d{2}\] ')
EVIDENCE = re.compile(r'\(실해: \d{4}-\d{2}-\d{2} ')
ENTRY_MAX = 600
COUNTER = re.compile(r'^(\*\*▶ 현행 잔량\(기계 대조 대상\)\*\*: 대기 )(\d+)( .*)?$')


def fail(msg):
    print('append_deferred: ' + msg, file=sys.stderr)
    return 2


def main(argv=None):
    sys.stdout.reconfigure(encoding='utf-8')
    sys.stderr.reconfigure(encoding='utf-8')
    ap = argparse.ArgumentParser(description='reflect 대장 등재')
    ap.add_argument('--ledger', required=True)
    ap.add_argument('--group', default=None)
    ap.add_argument('--entries', required=True)
    a = ap.parse_args(argv)

    with open(a.entries, encoding='utf-8') as f:
        entries = [l.rstrip('\r\n') for l in f if l.strip()]
    for e in entries:
        if not ENTRY_HEAD.match(e) or not EVIDENCE.search(e) or len(e) > ENTRY_MAX:
            return fail('형식 위반 — %s' % e[:60])
    if not entries:
        return fail('형식 위반 — 넣을 항목이 없다')

    with open(a.ledger, 'rb') as f:
        raw = f.read()
    bom = raw.startswith(b'\xef\xbb\xbf')
    text = raw[3:].decode('utf-8') if bom else raw.decode('utf-8')
    eol = '\r\n' if '\r\n' in text else '\n'
    lines = text.split(eol)

    if a.group is not None:
        heading = '### ' + a.group
        if heading not in lines:
            return fail('그룹 없음 — %s' % heading)
        start = lines.index(heading)
        end = next((i for i in range(start + 1, len(lines))
                    if lines[i].startswith('### ') or lines[i] == '---'), len(lines))
    elif '## 대기' in lines:
        heading = '## 대기'
        start = lines.index(heading)
        end = next((i for i in range(start + 1, len(lines)) if lines[i].startswith('## ')), len(lines))
    else:
        heading, start, end = '(파일 전체)', None, len(lines)

    first = 0 if start is None else start + 1
    items = [i for i in range(first, end) if lines[i].startswith('- [')]
    if items:
        at = items[-1] + 1
        while at < end and lines[at][:1] in (' ', '\t'):
            at += 1
        insert = entries
    elif start is None:
        at = len(lines) - 1 if lines[-1] == '' else len(lines)
        insert = [''] + entries
    else:
        at = start + 2 if start + 1 < end and lines[start + 1] == '' else start + 1
        insert = entries + ([''] if at < len(lines) and lines[at] != '' else [])

    counter = [i for i, l in enumerate(lines) if COUNTER.match(l)]
    if a.group is not None and len(counter) != 1:
        return fail('잔량 줄 없음 — 「**▶ 현행 잔량(기계 대조 대상)**: 대기 N」 줄이 %d개' % len(counter))
    tally = ''
    if len(counter) == 1:
        m = COUNTER.match(lines[counter[0]])
        lines[counter[0]] = m.group(1) + str(int(m.group(2)) + len(entries)) + (m.group(3) or '')
        tally = ' · 대기 %s → %d' % (m.group(2), int(m.group(2)) + len(entries))

    lines[at:at] = insert
    out = eol.join(lines).encode('utf-8')
    with open(a.ledger, 'wb') as f:
        f.write((b'\xef\xbb\xbf' if bom else b'') + out)
    print('등재 %d건 — %s%s' % (len(entries), heading, tally))
    return 0


if __name__ == '__main__':
    sys.exit(main())
