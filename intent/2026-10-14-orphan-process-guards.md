# Intent: 스킬이 띄운 하위 프로세스가 고아로 남거나 파이프에 막히지 않게 한다
Author: 사용자(jongcheol-pak). Status: approved.

## Problem
사용자가 「스킬 사용시 고아 프로세스는 잘 정리하는지, 메모리 사용량 최적화는 잘 되어 있는지 검토」를 요청했고, 검토에서 세 빈틈이 나왔다 — ① `chain-plan` 대기 스크립트 `wait-worker.py` 가 자기를 띄운 셸·세션이 사라졌는지 보지 않고 `karina-cli`·`git` 호출에 시한이 없어, 코디네이터 세션이 죽고 Claude Code 가 자식 트리를 함께 죽이지 않으면 남는다(자리 대기 `--place` 는 시한이 없다) ② `trigger_eval.py` 가 stderr 파이프를 읽지 않은 채 stdout 만 읽어, stderr 가 파이프 버퍼를 채우면 케이스가 watchdog 까지 막혀 timeout 으로 버려진다 ③ `session-wiki-signals.ps1` 이 stderr 를 리다이렉트만 하고 읽지 않아 같은 교착이 난다(실측 재현). 사용자 원문: 「1~3번 계획 세워줘」.

## Proposed outcome
- `wait-worker.py` 가 자기를 띄운 셸·세션이 사라지면 다음 대기 주기 안에 스스로 끝나고, CLI·git 호출은 시한을 넘기면 끊긴다. 살아 있는 코디네이터가 그 종료를 읽으면 대기를 다시 띄우라는 지시를 받는다.
- `trigger_eval.py` 의 케이스 실행이 stderr 분량과 무관하게 첫 Skill 호출에서 끝난다.
- `session-wiki-signals.ps1` 의 뒤처짐 계산이 git 의 stderr 분량과 무관하게 시간 상한 안에 끝난다.
- 세 변경 각각에 고치기 전 코드에서 실패하는 회귀 케이스가 있다.

## Affected users and systems
`pjc:chain-plan` 체인을 돌리는 사용자 · 스킬 트리거 eval 을 돌리는 하니스 개발자 · 모든 세션 시작(위키 뒤처짐 계산). `plugins/pjc/skills/chain-plan/scripts/wait-worker.py` · `plugins/pjc/skills/evals/trigger_eval.py` · `plugins/pjc/scripts/session-wiki-signals.ps1` 과 각 골든.

## Constraints
감시·시한 장치가 실패하면 현행처럼 계속 기다린다(fail-open) · hook 스크립트는 PS 5.1 호환 유지 · `.ps1` 은 UTF-8 BOM · 워킹트리 CRLF · 트리거 eval 실제 실행은 스모크 1케이스만(사용자 답).

## Open questions
없음
