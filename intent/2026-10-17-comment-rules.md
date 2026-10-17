# Intent: pjc 가 쓰는 코드의 주석 규칙 (pstack comment-sicko 기준)
Author: 사용자. Status: approved.

## Problem
원문 요청: 「주석 규칙 도입 계획 세워줘」 — pjc 로 작업하면 주석이 코드 수정을 따라가지 못해 틀린 채 남고, 작업 완료 뒤 주석을 다시 고치는 작업이 자주 생기며, 코드 검토 때 주석만 보고 잘못 판단하는 일이 생긴다. pjc 의 코드 작성 규약(`code-style.md`)에는 주석의 언어와 린트 억제만 있고 주석 내용 규칙이 없으며, 이 레포 `AGENTS.md` 는 「주석: 한글, 왜를 설명한다」로 설계 이유 주석을 권한다.

## Proposed outcome
pjc 가 쓰는 코드(사용자 프로젝트와 이 하니스 레포 모두)는 pstack comment-sicko 의 예외 다섯(라이선스 · 바꿀 수 없는 외부 제약이 강제하는 동작 · 결함 있는 규칙의 린트 억제 · 공개 API 계약 doc · 제약을 설명하는 이슈·RFC·문서 링크)만 주석으로 남긴다. 바꾼 줄과 같은 diff hunk 안(문맥 줄 포함)의 기존 주석은 예외 밖이거나 해당 여부가 확실하지 않으면 지우고, 그 이유가 커밋 이력에 없으면 이번 커밋 본문(커밋하지 않는 경로면 수정 보고)에 옮긴다. 검사기가 파싱하거나 규약이 정본·예외로 지정한 주석과 프로젝트 규약·린터가 요구하는 주석은 남긴다. 계획 실측·디버깅 조사·완료 리뷰는 주석이 아니라 코드와 실행으로 판정한다. 이 레포의 주석 규약과 근거 이관 처방은 설계 이유를 rationale 문서로만 보내고, 검사기가 파싱하거나 규약이 지목한 주석(rationale 포인터 등)은 남긴다. README 가 바뀐 동작을 서술한다.

## Affected users and systems
pjc 로 코드를 고치는 세션(implement·debugging)과 계획 세션·완료 리뷰어. 시스템: implement `references/code-style.md`·`SKILL.md`(See also 목록), plan `references/plan-template.md`, debugging `SKILL.md`, `agents/completion-reviewer.md`, `skills/BUDGET.md`, 이 레포 `AGENTS.md`, README.

## Constraints
문서 규칙만 둔다(검사 스크립트·hook 없음). 기존 주석 일괄 삭제는 하지 않는다(diff 안만 — 단위는 바꾼 줄의 diff hunk, 문맥 줄 포함). pstack 의 `MUST KILL` 리팩토링 지목은 들이지 않는다. 파일 크기 게이트·CRLF·`.ps1` BOM 을 지킨다.

## Open questions
없음
