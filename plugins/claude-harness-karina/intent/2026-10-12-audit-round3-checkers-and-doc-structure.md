# Intent: 하니스 감사 3회차 — 검사기·문서 구조
Author: 사용자(jongcheol-pak). Status: approved.

## Problem
원문 요청: 「위키, 하니스,체인 등 스킬에서 불필요한 부분이나 작업 속도에 영향을 주는 부분, 사용하지 않는 문서을 만들고 있는지 검토」 → 「모두 수정 계획 작성. 아무도 다시 읽지 않는 산출물 항목도 같이 계획」 (3회차 분할의 3회차). `guard-bash` 는 Bash 호출마다 커밋 판정 라이브러리 둘(33,719B)을 dot-source 한다(약 120ms/호출, 1회 약 570ms 중 — 2026-10-12 실측). 정합 검사기는 예산 95,000자에 11자 남았다. 포인터 축이 승인 시점 스냅샷인 `intent/` 를 검사해 intent 를 정합 때문에 고친 커밋이 생긴다. rationale 주석 짝 검사가 헤딩 전문 일치를 요구해 161개 주석이 헤딩을 통째로 복제한다(최장 220자). `docs/harness-conventions.md` 의 기준선 줄과 `docs/golden-runner.md:19` 에 케이스 수·소요 시간 증감 서사가 쌓였다. llm-wiki 의 비 git vault 백업 규칙은 git vault 사용자에게도 SKILL 본문(622자)으로 매번 실린다. 체인 대기의 message RESULT 는 배치 JSON 원문을 최대 16,000자까지 싣는다.

## Proposed outcome
`guard-bash` 는 명령에 `commit` 이 들 때만 커밋 판정 라이브러리를 dot-source 하고, 존재 확인은 매번 해 로드 실패 경고를 유지한다. 공용 헬퍼 둘은 `guard-bash.ps1` 로 옮기고, 라이브러리가 없어도 나머지 검사(차단 게이트 포함)는 계속 돈다. 정상 경로의 차단 판정은 바뀌지 않으며 골든이 실증한다. 축 ⑰ 의 숫자 대조는 유지하고 기준선 줄의 증감 서사는 걷으며, 서사가 다시 붙지 않게 축 ⑰ 이 기준선 줄의 「직전 N」 을 잡는다. 검사기 주석의 이력을 압축해 예산 여유를 만든다. 포인터 축의 출처에서 `intent/` 를 뺀다. rationale 주석 짝 검사는 `§N` 번호 실재만 보고, 161개 주석은 `— 근거는 \`<파일>\` §N` 꼴로 바꾼다. `golden-runner.md` 의 실측 나열은 최신 값 하나로 줄인다. 비 git vault 백업 규칙 본문은 전용 참조로 옮기고, schema-budget 에는 헤딩과 포인터를, SKILL 에는 조건 한 줄만 둔다(「정본」 서술 동반 갱신). 라이브러리가 없을 때 차단 게이트가 꺼지던 것은 ② 미탐 보완으로 함께 고친다. message RESULT 는 키를 모두 보존하되 subject·body 밖의 긴 문자열 값은 자르고 빈 값은 빼서 공백 없는 JSON 으로 낸다. 위키 conventions 제외 규칙 6곳의 술어 통합은 보류, 대장의 require-task-checkbox `-F` 미탐 항목은 대장 유지다.

## Affected users and systems
모든 Bash 호출(`guard-bash`), 하니스 레포를 고치는 세션(정합 검사기·잘린 주석 검사기·골든), pjc:llm-wiki 사용 세션, pjc:chain-plan 코디네이터. `plugins/pjc/scripts/*.ps1`·`rules/*-rationale.md`, `plugins/pjc/evals/check-harness-consistency.py`·`check-comment-truncation.py`·`cases.json`·fixtures·rationale, `plugins/pjc/hooks/evals/scenarios/*`, `plugins/pjc/skills/llm-wiki/SKILL.md`·references, `plugins/pjc/skills/chain-plan/scripts/wait-worker.py`·evals, `docs/harness-conventions.md`·`docs/golden-runner.md`.

## Constraints
정상 경로에서 차단 hook 넷의 판정은 바꾸지 않는다(라이브러리 부재 시 나머지 검사가 계속 도는 것은 실패 경로의 변경이라 Decisions 에 적고 골든으로 실증한다). 축 ⑰ 의 숫자 대조·`--fix` 는 유지한다. 근거 서술(「회차 NN 실측: …」)은 이력이 아니라 근거라 남긴다. CRLF·`.ps1` BOM 규약 · 파일 예산. 릴리즈는 3회차 뒤 2회차 미배포분과 함께 한다(사용자 답).

## Open questions
- Karina `check` 배치의 실제 키 구조(특히 worker_done 결과가 담기는 키)는 미확인이다 — 키를 모두 보존하는 설계로 이 미확인을 비켜 간다.
