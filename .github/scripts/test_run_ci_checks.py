"""run_ci_checks.py 의 단계 추출과 실행 판정을 잰다.

실행: python .github/scripts/test_run_ci_checks.py
출력: 케이스마다 PASS <갈래> 또는 FAIL <갈래> <기대·실제>, 끝에 N cases. 실패가 있으면 exit 1.
"""
import os
import re
import sys

sys.stdout.reconfigure(encoding='utf-8')
HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import run_ci_checks as r

results = []


def check(branch, expected, actual, label):
    ok = expected == actual
    results.append(ok)
    if ok:
        print(f'PASS {branch} {label}')
    else:
        print(f'FAIL {branch} {label} 기대={expected} 실제={actual}')


def attempt(fn):
    try:
        return fn()
    except Exception as e:
        return f'예외 {type(e).__name__}'


WORKFLOW = """\
{H} run: python comment.py
jobs:
  checks:
    defaults:
      run:
        working-directory: sub/dir
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: 2
      - name: first
        run: python a.py
      - name: pwsh inline
        shell: pwsh
        run: Write-Host 'python b.py'
      - name: folded
        run: >
          python c.py
      - name: literal
        run: |
          python d.py
      {H} - name: commented
      {H}   run: python e.py
      - name: second
        run: python f.py --flag
      - uses: actions/setup-node@v4
        working-directory: wrong
      - name: rooted
        working-directory: .
        run: python g.py
      - name: conditional
        if: steps.paths.outputs.x == 'true'
        run: python h.py
""".replace('{H}', chr(35))

ONLY_PWSH = 'jobs:\n  checks:\n    steps:\n      - name: only pwsh\n        shell: pwsh\n        run: echo hi\n'


def python_steps(text):
    return [(s.command, s.workdir) for s in r.parse_steps(text) if s.kind == 'python']


def run_all(text, failing=()):
    lines = []
    calls = []

    def runner(command, cwd):
        calls.append(command)
        return (1 if command in failing else 0), 'last line'

    try:
        code = r.run_all(r.parse_steps(text), 'ROOT', runner=runner, out=lines.append)
    except Exception as e:
        code = f'예외 {type(e).__name__}'
    return code, calls, lines


check('extract', [('python a.py', 'sub/dir'), ('python f.py --flag', 'sub/dir'), ('python g.py', '.')],
      attempt(lambda: python_steps(WORKFLOW)), '한 줄 python 단계를 순서대로 · 단계별 working-directory')
check('workdir-default', 'sub/dir', attempt(lambda: python_steps(WORKFLOW)[0][1]), 'defaults 값을 쓴다')
check('workdir-step', '.', attempt(lambda: python_steps(WORKFLOW)[2][1]), '단계의 값은 그 단계에만')
check('uses-boundary', 'sub/dir', attempt(lambda: python_steps(WORKFLOW)[1][1]),
      '- uses: 단계 뒤 working-directory 를 앞 단계에 붙이지 않는다')
check('not-python', False,
      attempt(lambda: any(c in ('python b.py', 'python c.py', 'python d.py', 'python e.py', 'python comment.py')
                          for c, _ in python_steps(WORKFLOW))), 'pwsh·여러 줄·주석 줄은 뽑지 않는다')

code, calls, lines = run_all(WORKFLOW)
check('all-pass', 0, code, '전부 통과면 exit 0')
check('all-pass-calls', ['python a.py', 'python f.py --flag', 'python g.py'], calls, 'if 단계는 돌리지 않는다')
check('skip-line', True, any(l.startswith('[skip] python h.py') for l in lines), 'if 단계는 [skip] 줄')
check('unrun-line', True, any(l.startswith('[로컬 미실행] pwsh inline') for l in lines), '뽑지 않은 단계 이름')
check('result-line', '결과: 3/3 OK', lines[-1] if lines else None, '마지막 줄')

code, calls, lines = run_all(WORKFLOW, failing=('python a.py',))
check('one-fail', 1, code, '하나 실패면 exit 1')
check('one-fail-continues', 3, len(calls), '실패해도 나머지를 끝까지 돈다')
check('one-fail-result', '결과: 2/3 OK', lines[-1] if lines else None, '마지막 줄')

check('no-steps', 2, run_all(ONLY_PWSH)[0], 'python 단계가 없으면 exit 2')

with open(os.path.join(HERE, '..', 'workflows', 'checks.yml'), encoding='utf-8') as f:
    real = f.read()
grep_count = len(re.findall(r'(?m)^ *run: python ', real))
check('real-count', grep_count,
      attempt(lambda: len([s for s in r.parse_steps(real) if s.kind in ('python', 'skip')])), '실제 checks.yml 의 단계 수')
check('real-nonzero', True, grep_count > 0, '실제 checks.yml 에 python 단계가 있다')

print(f'{len(results)} cases')
sys.exit(0 if all(results) else 1)
