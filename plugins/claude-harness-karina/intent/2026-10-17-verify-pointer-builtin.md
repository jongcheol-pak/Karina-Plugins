# Intent: pstack 검토 3절 회차 3 — 앱 조작 검증을 Claude Code 내장 스킬에 연결
Author: 사용자. Status: approved.

## Problem
원문 요청: 「pstack 검토 3절 회차 3 계획 세워줘 — 앱 조작 검증 스킬(생성기): 레포를 조사해 .claude/skills/verify-<app>/(Launch·Doctor·Drive·Evidence·Cleanup + 기능 지도)를 만들고 한 번 실제로 돌려 넘기는 스킬.」

Q/A (인터뷰):
- Q: 발동 방식 — A: 사용자가 부를 때만(이후 방향 전환으로 새 스킬 자체가 빠짐).
- Q: 실행 증명에 실패하면 — A: 초안으로 남기고 AGENTS.md 포인터는 쓰지 않는다 → 포인터는 실제로 성공한 레시피만 가리킨다.
- 실측: Claude Code 에 내장 `/run`·`/verify`·`/run-skill-generator` 가 있다(https://code.claude.com/docs/en/skills.md 「Run and verify your app」). `/run-skill-generator` 는 성공한 실행 절차를 `.claude/skills/run-<name>/` 프로젝트 스킬로 기록하고, `/verify` 는 `.claude/skills/verify/SKILL.md` 에 기록한다. 기능 지도·증거 기준·Windows GUI 는 문서에 없다.
- Q: 내장이 있는데 이 회차를 어떻게 — A: 내장 스킬에 연결만 한다(새 스킬 없음).

## Proposed outcome
- AGENTS.md 골격의 `Verify (앱 조작)` 줄 예시가 내장 산출물 경로(`.claude/skills/run-<name>/` · `.claude/skills/verify/`)와 「없으면 `/run-skill-generator` 로 만든다」 를 담고, record-project-fact 매핑이 같다.
- implement 의 HUMAN-VERIFY 불릿이 포인터의 레시피를 Read 해 따라 조작하고, 레시피가 실패하면 HUMAN-VERIFY 로 넘긴다. 증거 기준(실제 사용자 경로 · 조작과 결과 상태 · 부수 효과)은 report-format 에 한 불릿으로 있다.
- 레시피가 없으면 최종 보고의 HUMAN-VERIFY 줄이 사용자에게 `/run-skill-generator` 를 권한다 — 생성기를 돌리는 것은 사용자다.
- README 완료 단계 문단과 트러블슈팅이 `/run-skill-generator` 를 안내한다.

## Affected users and systems
implement 세션(화면 확인 단계) · 대상 레포 AGENTS.md 를 만드는 plan·record-project-fact · README 를 읽는 사용자. 시스템: `AGENTS-BOUNDARY.md` · `record-project-fact/SKILL.md` · `implement/SKILL.md` · `implement/references/report-format.md` · `README.md` · session-context 골든(implement 「자율 루프」 발췌).

## Constraints
새 스킬·트리거 eval 없음 · implement/SKILL.md 12,000자(현재 11,506) · CRLF. 포인터는 실제로 성공한 레시피만 가리킨다.

## Open questions
없음
