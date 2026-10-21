# Intent: pstack 검토 1절 — 테스트 변조 금지 · 리팩토링 동작 고정 · 루프 중 사용자 중단
Author: 사용자. Status: approved.

## Problem
원문 요청: 「1절 3건부터 계획 세워줘」 — Cursor pstack 플러그인 검토에서 pjc 에 빈자리로 확인된 세 가지다. 실패한 기존 테스트·골든의 기대값을 바꿔 통과시키는 것을 막는 규칙이 implement·debugging·완료 리뷰에 없고(chain 워커 spec 에만 있다), 구조만 바꾸는 리팩토링 task 는 케이스 요구 밖이며, 자율 루프 도중 사용자가 멈추라고 할 때의 절차가 없고 `loop-continue` 주입 문구는 그 정지를 유지할 정지로 적지 않는다.

## Proposed outcome
루프 안에서 기존 케이스를 구현에 맞춰 고치지 않는다(plan Goal 이 바꾸기로 한 동작을 재는 케이스면 고치고 판정 줄을 남기며, 그 밖이면 승인 밖 동작 변경으로 멈춘다) — 이 규칙이 implement 실패 처리·debugging 안티패턴·완료 리뷰 대조에 있다. 구조만 바꾸는 task 도 구조 변경 전에 동작을 고정하는 케이스(또는 기존 케이스 경로)를 Files 에 적고 계획 리뷰가 그것을 본다. 사용자가 루프 중 멈추라고 하면 즉시 멈추고 미커밋 변경을 보존한 채 `[/]`·Progress Log 중단 줄·재개 한 줄을 남기며, `loop-continue` 주입 문구가 사용자 중단을 유지할 정지로 적고 골든이 그것을 잰다.

## Affected users and systems
pjc 를 쓰는 세션(`pjc:implement` 자율 루프 · `pjc:plan` 작성 · `plan-reviewer`·`completion-reviewer`). 시스템: implement `references/loop-exceptions.md`·`SKILL.md`·`loop-stop-patterns.md`, debugging `SKILL.md`, plan `plan-template.md`, 에이전트 2종, `scripts/loop-continue.ps1` 과 그 골든·근거 문서, README.

## Constraints
implement `SKILL.md` 12,000자·에이전트 정의 6,000자 게이트 안에서 본문에는 포인터만 둔다. 워킹트리 CRLF 와 `.ps1` BOM 을 보존한다. `loop-continue` 는 문면 판정을 더하지 않고 주입 문구만 바꾼다.

## Open questions
없음
