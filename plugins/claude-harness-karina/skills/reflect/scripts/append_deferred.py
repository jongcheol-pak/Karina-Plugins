"""karina:reflect — 사용자가 고른 개선 후보를 Deferred 대장(`docs/plans/deferred.md`)의 한 그룹에 넣는다.

Edit 도구·텍스트 모드 쓰기는 파일 전체를 LF 로 바꿔 정합 검사의 줄바꿈 축이 실패하므로, 바이트로 읽어
그 파일의 줄바꿈·BOM 을 그대로 쓴다.

- 그룹 범위: `### <그룹>` 헤딩부터 다음 `### ` · `---` 줄 · EOF 중 먼저 오는 것까지(잔량 줄은 그룹들보다 앞에 있다).
- 넣는 자리: 범위 안 마지막 `- [` 항목 줄 바로 뒤 · 항목이 없으면 헤딩 뒤 빈 줄 하나 다음. 그룹 끝 빈 줄은 그대로 둔다.
- 잔량 줄 `**▶ 현행 잔량(기계 대조 대상)**: 대기 N` 의 N 을 넣은 수만큼 올린다.

종료 코드: 0 정상 · 2 그룹 없음·잔량 줄 없음·형식 위반 항목(날짜 머리·`(실해: ` 필드·600자 상한) — 이때 파일을 쓰지 않는다.
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
    ap.add_argument('--group', required=True)
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

    heading = '### ' + a.group
    try:
        start = lines.index(heading)
    except ValueError:
        return fail('그룹 없음 — %s' % heading)
    end = len(lines)
    for i in range(start + 1, len(lines)):
        if lines[i].startswith('### ') or lines[i] == '---':
            end = i
            break
    items = [i for i in range(start + 1, end) if lines[i].startswith('- [')]
    if items:
        at = items[-1] + 1
        insert = entries
    else:
        at = start + 2 if start + 1 < end and lines[start + 1] == '' else start + 1
        # 빈 그룹 — 헤딩·빈 줄·항목·빈 줄 모양을 유지한다
        insert = entries + ([''] if at < len(lines) and lines[at] != '' else [])

    counter = [i for i, l in enumerate(lines) if COUNTER.match(l)]
    if len(counter) != 1:
        return fail('잔량 줄 없음 — 「**▶ 현행 잔량(기계 대조 대상)**: 대기 N」 줄이 %d개' % len(counter))
    m = COUNTER.match(lines[counter[0]])
    lines[counter[0]] = m.group(1) + str(int(m.group(2)) + len(entries)) + (m.group(3) or '')

    lines[at:at] = insert
    out = eol.join(lines).encode('utf-8')
    with open(a.ledger, 'wb') as f:
        f.write((b'\xef\xbb\xbf' if bom else b'') + out)
    print('등재 %d건 — %s · 대기 %s → %d' % (len(entries), heading, m.group(2), int(m.group(2)) + len(entries)))
    return 0


if __name__ == '__main__':
    sys.exit(main())
