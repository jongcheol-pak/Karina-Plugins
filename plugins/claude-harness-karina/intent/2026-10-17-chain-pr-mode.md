# Intent: 계획 체인 PR 모드 — 워커마다 PR · green·pr-verifier PASS 뒤 merge
Author: 사용자 (코디네이터 인터뷰 경유 — 계획 체인 run_b2c299c16e801eccf8df607a1a1d2e3b plan 3/3). Status: approved.

## Problem
spec 「원문:」 블록 그대로 —

plan 3: pjc:chain-plan 에 PR 모드 추가 — 체인 승인 때 고르면 워커마다 PR 을 열고 green·pr-verifier PASS 뒤 merge, 고르지 않으면 지금의 로컬 병합
(사용자 처음 지시: 「pstack이 자율로 하는 것 하도 동일하게 수정해」 — opening-a-pr·babysit·shipping·autopilot-full)
[공통] Q: 「동일하게」의 범위 / 선택지: 승인 규칙만 푼다 (권장) · 규칙 + 새 기능 · 새 기능만 만든다 / A: 규칙 + 새 기능
[공통] Q: 릴리즈·태그 발행도 자율로? / 선택지: 계속 승인 (권장) · 릴리즈도 자율 / A: 계속 승인 (권장)
[plan 3] Q: autopilot-full 을 pjc 에서 어디에? / 선택지: chain-plan에 PR 모드 추가 (권장) · 새 스킬 · 이번엔 뺀다 / A: chain-plan에 PR 모드 추가 (권장)
[공통] Q: 의도 재진술 확인 / 선택지: 없음 / A: 진행
[공통] Q: 세 회차 진행 방식 / 선택지: 계획 체인으로 (권장) · 이 세션에서 1회차부터 / A: 계획 체인으로 (권장)
[plan 3] Q: 후보 라운드 — 3 대기 스크립트 진행 줄에 PR 단계 표시(포함 권장) · 4 재개 때 멈춘 체인이 열어 둔 PR 을 찾아 승인 화면에 표시(포함 권장) / 선택지: 권장대로 (권장) · 전부 포함 · 전부 제외 / A: 권장대로 (권장) — 3 포함 · 4 포함
[공통] Q: 계획 체인 승인 / 선택지: Y 승인 · E 수정 요청 · N 중단 / A: 진행

지금 하는 이유: autopilot-full(빌드→PR→green→merge 무인)을 pjc 에서는 chain-plan 을 넓혀 제공하기로 했다.

## Proposed outcome
`pjc:chain-plan` 체인 승인 화면에 PR 모드 선택이 생긴다. 켜면 워커마다(직렬·병렬) PR 을 열고 `pjc:pr` 의 babysit 로 green 을 만든 뒤 `pr-verifier` PASS 를 받아 squash merge 하고, 직렬은 merge 뒤 체인 브랜치를 맞춘 다음 다음 계획으로 간다. 끄면 지금의 로컬 병합 그대로다. 재개·압축 복원·보고는 squash merge 된 계획을 끝난 것으로 판정한다. 요청 밖 포함: 대기 스크립트 진행 줄에 PR 단계(PR 열림·CI green·merge) 표시 · 재개 때 멈춘 체인이 열어 둔 PR 을 찾아 승인 화면에 표시.

## Affected users and systems
계획 체인을 돌리는 사용자(GitHub 원격·`gh` 인증이 있는 레포). `skills/chain-plan`(SKILL·references·scripts·evals) · `skills/plan/references/relay-mode.md` · `skills/implement/references/pr-flow.md` · `skills/pr/references/ship.md` · `README.md` · `docs/harness-conventions.md`.

## Constraints
rebase 금지 유지(앞선 base 는 merge 로 합친다) · chain-plan `SKILL.md` 12,000자 상한 — 본문은 새 references 로 · 앞 PR merge 뒤에 다음 직렬 계획 · 릴리즈·태그는 계속 승인 · PR 모드를 끈 체인은 동작이 같다.

## Open questions
없음
