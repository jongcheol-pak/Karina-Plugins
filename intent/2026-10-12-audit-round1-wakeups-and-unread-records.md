# Intent: 하니스 감사 1회차 — 불필요한 깨움·검증 반복·다시 읽히지 않는 기록 걷기
Author: 사용자(jongcheol-pak). Status: approved.

## Problem
원문 요청: 「위키, 하니스,체인 등 스킬에서 불필요한 부분이나 작업 속도에 영향을 주는 부분, 사용하지 않는 문서을 만들고 있는지 검토」 → 「모두 수정 계획 작성. 아무도 다시 읽지 않는 산출물 항목도 같이 계획」. 감사(2026-10-12)가 잰 낭비 중 1회차 몫: 체인 대기가 task 완료 커밋마다 코디네이터를 깨우고, hook 골든 전체(5~9분)가 중간 task 마다 필수이며, implement 가 체크박스를 스크립트로 일괄 치환하다 하루 5건씩 차단되고, 아무도 다시 읽지 않는 기록(위키 사용 기록·계획 함정 절·git vault 의 `[SCHEMA]` 줄·lint 리포트 페이지·마지막 계획 인계 절·`리뷰 지적 처리:` 줄·로컬 notes)과 release 의 완료 보고 대기·쌓이는 `.seen` 파일이 있다. 3회차로 나눈 것의 첫 회차다(사용자 답 「권장」).

## Proposed outcome
체인 대기는 진행 줄만으로 끝나지 않고 그 줄을 다음 질문·멈춤·완료 결과에 싣는다(10-05 「task 완료마다 한 줄」 결정의 번복 — 사용자 답 「포함」). 7일 지난 대기 상태 파일은 대기가 시작할 때 지운다. hook 골든은 중간 task 에서 `-Filter` 부분 실행이 기본이고 무인자 전체는 마지막에 1회다. implement 는 체크박스를 Edit 한 번으로 묶어 고친다. 위 기록들은 플러그인이 더 이상 쓰라고 지시하지 않고, 기존 파일(`wiki-usage.md`·vault lint 리포트 4개·notes)은 지운다. hook 이벤트 로그는 유지한다(존속 목적은 README·근거 문서에 이미 적혀 있다). 2·3회차(의무 Read 축소·중복 정리 / 검사기·문서 구조·guard-bash 지연 로드)는 `[다음 회차]` 로 남는다.

## Affected users and systems
pjc:plan·implement·chain-plan·llm-wiki 사용자. `chain-plan/scripts/wait-worker.py`·골든·`references/release.md`·`manual-resume.md`·SKILL, `plan/references/relay-mode.md`·`plan-template.md`, `implement/SKILL.md`, `agents/plan-reviewer.md`, `skills/WIKI.md`, `llm-wiki/scripts/lint.py`·골든·references, hook 골든 러너 경고, `docs/harness-conventions.md`·`docs/golden-runner.md`·README, `check-stale-refs.py`, 위키 vault `30_knowledge/questions/`.

## Constraints
차단 hook 넷의 차단 판정은 바꾸지 않는다(hook 프로세스 통합은 범위 밖 — 사용자 답 「권장」). 기존 log.md `[SCHEMA]` 줄은 그대로 둔다. notes 제외 목록은 유지한다(사용자 답 「권장」). notes 삭제는 복구 경로가 없어 승인 항목이다. CRLF·BOM 규약 · SKILL 문서 예산.

## Open questions
없음
