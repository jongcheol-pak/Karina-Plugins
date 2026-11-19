"""checks.yml 의 한 줄 `run: python …` 단계를 읽어 로컬에서 그대로 돌린다.

실행: python .github/scripts/run_ci_checks.py
출력: 단계마다 `[<exit>] <명령> :: <마지막 출력 줄>`, `if:` 가 붙은 python 단계는 `[skip] <명령> :: if 조건 단계`,
      python 한 줄이 아닌 run 단계는 `[로컬 미실행] <단계 이름>`, 끝에 `결과: N/M OK`.
종료 코드: 0 전부 통과 · 1 실패 있음 · 2 python 단계를 하나도 찾지 못함(통과가 아니다).
"""
import os
import re
import shlex
import subprocess
import sys
from collections import namedtuple

Step = namedtuple('Step', 'name kind command workdir')

STEP_TIMEOUT_SEC = 1800
KEY_RX = re.compile(r'^(?P<indent> *)(?P<dash>- )?(?P<key>[A-Za-z-]+):(?: (?P<value>.*))?$')


def parse_steps(text):
    default_workdir = '.'
    step_indent = None
    in_steps = False
    raw = []
    for line in text.splitlines():
        if not line.strip() or line.lstrip().startswith('#'):
            continue
        m = KEY_RX.match(line.rstrip())
        if not in_steps:
            if m and m.group('key') == 'working-directory':
                default_workdir = m.group('value').strip()
            elif m and m.group('key') == 'steps' and not m.group('dash'):
                in_steps = True
            continue
        if not m:
            continue
        indent = len(m.group('indent'))
        if m.group('dash') and (step_indent is None or indent == step_indent):
            step_indent = indent
            raw.append({'indent': indent + 2})
        if not raw or indent + (2 if m.group('dash') else 0) != raw[-1]['indent']:
            continue
        raw[-1].setdefault(m.group('key'), (m.group('value') or '').strip())

    steps = []
    for fields in raw:
        run = fields.get('run')
        if run is None:
            continue
        name = fields.get('name', run)
        workdir = fields.get('working-directory', default_workdir)
        if not run.startswith('python ') or 'shell' in fields:
            steps.append(Step(name, 'other', run, workdir))
        elif 'if' in fields:
            steps.append(Step(name, 'skip', run, workdir))
        else:
            steps.append(Step(name, 'python', run, workdir))
    return steps


def run_command(command, cwd):
    argv = shlex.split(command)
    argv[0] = sys.executable
    try:
        done = subprocess.run(argv, cwd=cwd, capture_output=True, text=True, encoding='utf-8',
                              errors='replace', timeout=STEP_TIMEOUT_SEC)
    except subprocess.TimeoutExpired:
        return 124, f'시간 초과 {STEP_TIMEOUT_SEC}초'
    except OSError as e:
        return 127, str(e)
    lines = [l for l in (done.stdout + done.stderr).splitlines() if l.strip()]
    return done.returncode, (lines[-1].strip() if lines else '')


def run_all(steps, root, runner=run_command, out=print):
    total = passed = 0
    for step in steps:
        if step.kind == 'other':
            out(f'[로컬 미실행] {step.name}')
        elif step.kind == 'skip':
            out(f'[skip] {step.command} :: if 조건 단계')
        else:
            total += 1
            code, last = runner(step.command, os.path.join(root, step.workdir))
            passed += code == 0
            out(f'[{code}] {step.command} :: {last[:160]}')
    if total == 0:
        out('결과: python 단계 없음')
        return 2
    out(f'결과: {passed}/{total} OK')
    return 0 if passed == total else 1


def main():
    sys.stdout.reconfigure(encoding='utf-8')
    root = os.path.abspath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
    with open(os.path.join(root, '.github', 'workflows', 'checks.yml'), encoding='utf-8') as f:
        steps = parse_steps(f.read())
    return run_all(steps, root)


if __name__ == '__main__':
    sys.exit(main())
