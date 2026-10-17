# Intent: pstack 검토 3절 회차 2 — plan.md 결정적 검사 스크립트
Author: 사용자. Status: approved.

## Problem
원문 요청: 「pstack 검토 3절 회차 2 계획 세워줘 — plan 구조 검사 스크립트: plan-reviewer 가 LLM 으로 하는 기계 판정(절 존재·체크박스 형식·Files·Acceptance·검증 줄)을 결정적 스크립트로 옮긴다.」 plan-reviewer 는 Read·Grep·Glob 만 가진 LLM 에이전트라, 빈 명령 열·남은 Open Questions 같은 문자열 판정도 매 라운드 모델이 읽어서 가르고, 템플릿 필수 절·task 줄 형식은 명시적으로 재지 않는다.

Q/A (인터뷰):
- Q: 스크립트를 어디서 돌리고 리뷰어 항목은 어떻게 하나 — A: 계획 세션이 Step 6 에서 리뷰어 호출 전에 돌리고, 옮긴 리뷰어 항목은 지운다.
- Q: 잴 항목 — A: A 묶음(리뷰어에서 옮길 것 — Log 명령 열 빈 행 · 위키 참조 행 · deferred-closed 조회 흔적 · Open Questions `[ ]` · Acceptance 착수값 · Files 케이스 표시) + B 묶음(plan-template 서식 — 필수 절 · Goal 머리 줄 · task 하위 항목 형식 · task 별 Files·Acceptance·검증 줄).
- Q(후보 라운드): 검증 매핑에 스킬 로컬 스크립트 행 — A: 포함. 골든 러너 주석 「시나리오 15개」 — A: 포함. Deferred 마커 서식 검사 — A: 새 스크립트에서 제외(세 번째 구현을 만들지 않는다).

## Proposed outcome
- `plugins/pjc/skills/plan/scripts/check-plan.ps1 <plan.md>` 가 PS 5.1·7 에서 돌아 위반마다 줄 번호와 사유를 내고 exit 1, 위반이 없으면 exit 0, 파일을 못 읽으면 exit 2 를 낸다.
- 출력은 ASCII 코드다(Git Bash 를 거치면 한글이 깨진다).
- `pjc:plan` Step 6 이 리뷰어 호출 전에 그것을 돌려 exit 1 이면 고친 뒤 다시 돌린다(오탐이면 Log 에 적고 넘어간다). plan-reviewer 문서에서 줄 단위로 끝나는 A 묶음 넷(명령 칸 빈 행 · 위키 참조 행 · 종결 대장 조회 흔적 · Open Questions)이 빠지고, 스크립트가 줄 단위 유무만 재는 케이스 표시·착수값은 항목 단위 판정으로 리뷰어에 남는다. 스크립트가 못 돌면 그 사실이 리뷰어 입력으로 가 리뷰어가 넷을 직접 본다.
- hook 골든에 스크립트 시나리오가 갈래마다 케이스를 갖고, 기준선·검증 매핑·러너 주석이 함께 맞다. README 가 검사 단계를 서술한다.

## Affected users and systems
pjc:plan 을 쓰는 모든 레포의 계획 세션(체인 워커 포함)과 plan-reviewer. 시스템: 새 `plan/scripts/check-plan.ps1` · `plan/SKILL.md` · `agents/plan-reviewer.md` · hook 골든(`hooks/evals/` 시나리오·러너·필터) · `docs/harness-conventions.md` · `docs/golden-runner.md` · `README.md`.

## Constraints
PowerShell 5.1 호환(README 사전 요구사항에 python 이 없다) · `.ps1` UTF-8 BOM · plan-reviewer 6,000자 · plan/SKILL.md 12,000자 · CRLF. 「신규 파일 task 의 구조 줄」·「어느 task 가 케이스가 필요한가」 판단은 리뷰어에 남긴다. Deferred 마커 서식은 검사하지 않는다.

## Open questions
없음
