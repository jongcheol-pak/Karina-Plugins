# Intent: 계획 체인 — 의존 없는 계획을 별도 worktree 에서 병렬로 돌린다
Author: 사용자. Status: approved.

## Problem
원문: 「체인으로 작업시 plan 1~10 까지 있는 경우 너무 오래 걸리는데 작업 트리로 나눠서 작업을 진행할 수 없나?」 → 「진행해줘」(혼합 방식). `pjc:chain-plan` 은 모든 계획을 한 폴더에서 차례로 돌려(`--worktree <대상 레포 경로>` · `--deps` 직렬), 서로 의존하지 않는 계획도 앞 계획이 끝나야 시작한다.

## Proposed outcome
의존이 없고 실측한 바뀌는 영역이 겹치지 않는 계획은 Karina `new-child` worktree 에서 동시에 돌고(기본 상한 2, 체인마다 변경 가능), 나머지는 지금처럼 직렬이다. 코디네이터가 끝난 순서대로 하나씩 로컬 병합하고 병합마다 검증하며, 충돌·검증 실패는 병합을 되돌리고 그 워커가 main 을 자기 브랜치에 병합해 해결한다. 병렬 그룹 워커는 버전 task 를 만들지 않고, 그룹의 마지막 워커가 체인 브랜치를 병합한 뒤 버전을 한 번 올린다. 인계 파일·회차 이력의 덧붙이기 충돌은 병합 때 union 으로 합치고, 대상 레포가 추적하는 루트 `plan.md`·`notes.md` 는 병합되는 쪽 판을 받으며, Deferred 대장 충돌은 워커가 푼다. 대기 스크립트는 여러 워커를 함께 기다린다. 「plan N부터」 재개는 병합되지 않은 병렬 브랜치를 먼저 처리한다. 글로벌 지침은 체인 승인으로 위임받은 체인 worktree 로컬 병합을 별도 승인에서 뺀다.

## Affected users and systems
계획 체인을 쓰는 사용자 · `plugins/pjc/skills/chain-plan/`(SKILL·references·대기 스크립트·골든) · `README.md` · `docs/harness-conventions.md` · 글로벌 `~/.claude/CLAUDE.md`.

## Constraints
`pjc:implement` 는 고치지 않는다. push·원격 병합·PR·history rewrite 는 그대로 별도 승인이다. 병렬 그룹이 없는 체인은 지금과 동작이 같다. 사용자 답: 병합 승인 「체인 승인으로 병합 위임」 · 충돌 「워커에게 되돌려 해결」 · 동시 상한 「2개」 · 공유 파일 「버전만 코디네이터, 대장은 rebase로」 → 실측 정정 뒤 「인계 파일만 union」·「마지막 워커에 재배정」(버전) · 회차 파일을 추적하는 레포 「자동 처리」.

## Open questions
없음
