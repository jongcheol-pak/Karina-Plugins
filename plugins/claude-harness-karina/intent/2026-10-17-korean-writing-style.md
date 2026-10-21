# Intent: 사람이 읽는 출력에 거는 한글 문체 규칙
Author: 사용자. Status: approved.

## Problem
원문 요청: 「한글 문체 규칙 도입 계획 세워줘」 — pstack 검토 4절이 unslop·technical-writing 의 문체 규칙을 「영어 문체 규칙이라 맞지 않는다」로 분류했으나, 그 규칙 대부분은 언어와 무관하다. pjc 가 사용자에게 내는 글(완료 보고·승인 제시·커밋 메시지·README·디버깅 보고·체인 보고)에는 길이·항목 규칙만 있고 문장 규칙(군더더기·번역투·느낌 대신 동작·능동 등)이 없다. 같은 인터뷰에서 계획 인터뷰 규약의 두 규칙(반박 쪽 GUESS · GUESS 와 권장 선택지 일치)이 함께 지켜지지 않는 질문이 실제로 나갔다.

## Proposed outcome
사람이 읽는 출력에 거는 한글 문체 규칙 문서가 하나 있다 — 언어 무관 규칙을 한글로 옮기고 규칙마다 한글 나쁜 예→고친 예를 달며, 번역투는 규칙 하나로 둔다(예시는 금지어가 아니다). 완료 보고·승인 제시·커밋 메시지·README 갱신·디버깅 보고·체인 보고를 쓰는 자리에서 그 문서를 가리킨다. 계획 인터뷰의 반박 규칙은 「가장 덜 확신하는 가정을 한 번은 질문으로 올린다」로 바뀌어 GUESS 가 늘 실제 판단(권장안)과 같다.

## Affected users and systems
pjc 를 쓰는 세션과 그 출력을 읽는 사용자. 시스템: 새 `skills/WRITING.md`, implement `SKILL.md`·`references/report-format.md`, plan `references/interview.md`, debugging `SKILL.md`, chain-plan `references/report.md`, `BUDGET.md`, `validate.ps1`(가이드 문서 목록), README.

## Constraints
문서 규칙만 둔다(검사 스크립트·hook 없음). 구두점·굵게·라벨 규칙은 pjc 서식(`DESIGN.md` §1 · 보고 서식)과 충돌하므로 들이지 않는다. 일반 대화 응답·SKILL 문서·기존 문서 일괄 수정은 대상이 아니다. 파일 크기 게이트와 CRLF 를 지킨다.

## Open questions
없음
