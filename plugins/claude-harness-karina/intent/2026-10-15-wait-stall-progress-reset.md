# Intent: 체인 대기의 멈춤 판정이 워커 진행을 반영한다
Author: 사용자(jongcheol-pak). Status: approved.

## Problem
체인 대기 스크립트가 「워커 화면이 27분 동안 그대로」라며 stall 을 냈지만 워커는 그 사이 task 커밋 3개(T6·T7·T8)를 쌓고 있었다. 판정은 `worker-read` 화면 해시만 보고, 같은 출력에 실린 진행 줄은 연속 수를 되돌리지 않는다(원문: 「진행 신호가 있으면 정지로 보지 않게 하면 오판은 사라집니다」). 사용자 요청: 「dispatch별 새 진행으로 streak 리셋하는 안으로 고쳐줘」.

## Proposed outcome
화면 비교 사이에 그 워커 레포의 HEAD 가 움직였으면(task 커밋이든 아니든) 그 dispatch 의 멈춤 연속 수가 0 으로 돌아간다. 진행이 한 번 있었다고 이후의 진짜 멈춤을 놓치지 않으며, 병렬 대기에서 한 워커의 커밋이 다른 워커의 판정에 영향을 주지 않는다.

## Affected users and systems
`pjc:chain-plan` 코디네이터(대기 결과를 받아 멈춤 여부를 정한다) · `chain-plan/scripts/wait-worker.py` · 그 골든 `chain-plan/evals/run_wait_evals.py`.

## Constraints
`--repo` 를 주지 않은 대기(진행 감지 꺼짐)의 판정은 지금과 같다. 기존 골든 73케이스는 그대로 통과한다.

## Open questions
없음
