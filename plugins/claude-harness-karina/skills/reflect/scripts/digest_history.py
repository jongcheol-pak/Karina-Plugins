"""reflect 이력 모드의 요약 — 작업 레포의 수정·되돌림 커밋을 reflect-reviewer 가 읽을 텍스트로 쓴다.

사용: python digest_history.py --repo <레포> --out <파일> [--days N(기본 90)] [--now YYYY-MM-DDTHH:MM:SS]

담는 커밋은 제목이 `수정:`·`Revert`·`되돌리기` 로 시작하는 것뿐이다. 커밋마다 `== commit <짧은 SHA(git %h)> <날짜>` 머리 뒤에
`SUBJECT <제목>`, 빈 줄을 뺀 본문 앞 3줄(`BODY `), 바뀐 파일(`FILE `)을 쓴다. 파일 첫 줄은 `# 총 줄 수: N` 이다(리뷰어가
150줄씩 나눠 읽는 기준). `--now` 는 기간 계산의 기준 시각이다(없으면 현재 시각) — 골든이 시각을 고정하려고 넣는다.

종료 코드: 0 = 썼다(대상 커밋 0건 포함) · 2 = 입력 오류(레포 아님·git 실패·인자 오류).
"""
import argparse
import datetime
import re
import subprocess
import sys

SUBJECT_RX = re.compile(r'^(수정:|Revert|되돌리기)')
SEP = '\x1e'
END = '\x1f'


def git(repo, args):
    p = subprocess.run(['git', '-C', repo] + args, capture_output=True)
    return p.returncode, p.stdout.decode('utf-8', errors='replace')


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    ap = argparse.ArgumentParser()
    ap.add_argument('--repo', required=True)
    ap.add_argument('--out', required=True)
    ap.add_argument('--days', type=int, default=90)
    ap.add_argument('--now')
    a = ap.parse_args()
    now = datetime.datetime.fromisoformat(a.now) if a.now else datetime.datetime.now()
    since = (now - datetime.timedelta(days=a.days)).strftime('%Y-%m-%dT%H:%M:%S')
    rc, _ = git(a.repo, ['rev-parse', '--is-inside-work-tree'])
    if rc != 0:
        print('레포가 아닙니다: %s' % a.repo)
        return 2
    rc, out = git(a.repo, ['log', '--since=' + since, '--until=' + now.strftime('%Y-%m-%dT%H:%M:%S'),
                           '--format=' + SEP + '%h%x09%cs%x09%B' + END, '--name-only'])
    if rc != 0:
        print('git log 실패: %s' % a.repo)
        return 2
    lines = []
    for chunk in out.split(SEP)[1:]:
        head, _, rest = chunk.partition('\t')
        date, _, rest = rest.partition('\t')
        message, _, names = rest.partition(END)
        parts = message.strip('\n').split('\n')
        subject = parts[0] if parts else ''
        if not SUBJECT_RX.match(subject):
            continue
        text = [l for l in parts[1:] if l.strip()]
        files = [l for l in names.split('\n') if l.strip()]
        lines.append('== commit %s %s' % (head, date))
        lines.append('SUBJECT ' + subject)
        lines.extend('BODY ' + l for l in text[:3])
        lines.extend('FILE ' + f for f in files)
    with open(a.out, 'w', encoding='utf-8', newline='\n') as f:
        f.write('# 총 줄 수: %d\n' % (len(lines) + 1))
        f.write('\n'.join(lines) + ('\n' if lines else ''))
    print('커밋 %d건 → %s' % (sum(1 for l in lines if l.startswith('== commit ')), a.out))
    return 0


if __name__ == '__main__':
    sys.exit(main())
