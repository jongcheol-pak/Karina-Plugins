# Intent: pstack 검토 3절 회차 1 — 승인 필요 항목 권장안 · chain 보고 검증·판정 · 앱 조작 검증 포인터 · README 레시피
Author: 사용자. Status: approved.

## Problem
원문 요청: 「pstack 검토 3절 계획 세워줘」. 3절 선택 항목 다섯(plan 구조 검사 스크립트 · 앱 조작 검증 스킬 · 도움말 · 승인 필요 항목 보강 · chain 워커 보고 보강)을 모두 하되 세 회차로 나눈다(사용자 답). 이번 회차는 문서만 고치는 묶음이다. 완료 보고의 승인 필요 항목은 나열만 해 사용자가 답하지 않으면 무엇이 남는지 모르고, chain 워커 보고는 실제로 돌린 검증과 워커가 스스로 정한 판정을 코디네이터 보고로 넘기지 않으며, 화면 확인은 전부 HUMAN-VERIFY 로 사용자에게 넘어가고, README 에는 복사해 쓸 요청 예와 증상별 처방이 적다.

## Proposed outcome
- implement 완료 보고의 승인 필요 항목이 건수로 시작하고 항목마다 권장안과 「답이 없으면 무엇이 남는가」를 단다. chain 워커 `--body`·코디네이터 체인 보고의 같은 칸도 같은 형태다.
- chain 워커 `--body` 와 코디네이터 체인 보고에 `검증:`(실제로 돌린 명령과 결과)과 `판정:`(워커가 스스로 정한 것 — 근거는 커밋 SHA·파일:줄 포인터) 칸이 있고, 코디네이터 판정의 근거도 포인터다.
- 대상 레포 `AGENTS.md` 골격에 선택 줄 `Verify (앱 조작)` 이 있고, implement 는 HUMAN-VERIFY 로 넘기기 전에 그 줄이 가리키는 검증 스킬로 조작할 수 있는 것을 먼저 조작한다. record-project-fact 매핑이 그 줄을 받는다.
- README 「자주 쓰는 명령」·「트러블슈팅」에 요청 예와 증상→처방이 더해지고, 위 두 동작 변경이 README 완료 단계 서술에 반영된다.
- plan 구조 검사 스크립트와 앱 조작 검증 스킬은 다음 두 회차로 남는다.

## Affected users and systems
pjc 를 쓰는 사용자(완료·체인 보고를 읽고 결정하는 쪽), implement·chain-plan 세션. 시스템: `implement/references/report-format.md` · `implement/SKILL.md` · `chain-plan/references/{spec-format,report}.md` · `AGENTS-BOUNDARY.md` · `record-project-fact/SKILL.md` · `README.md`, session-context 골든(implement 「자율 루프」 발췌).

## Constraints
SKILL.md 12,000자(implement 현재 11,423자) · references 15,000자 · 최상위 skills md 13,000자 안. CRLF 보존. README 는 현재 기능만·새 절 없음. 근거는 `[면제 ⑤ · 외부 선례]` 세 요소로 커밋 본문에 싣는다.

## Open questions
없음
