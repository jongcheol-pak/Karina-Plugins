# Intent: 되돌릴 수 있는 작업은 묻지 않고 진행 · 삭제 먼저 · 옛 API 정리 · codemod 줄바꿈 (pstack 원칙 4건)
Author: 사용자. Status: approved.

## Problem
원문 요청: pstack 검토 4절의 「맞지 않는 것」 가운데 never-block-on-the-human · subtract-before-you-add · migrate-callers-then-delete-legacy-apis 를 「이것처럼 수정」하고 codemod 줄바꿈 처리를 도입하라. pjc 와 글로벌 지침은 git 으로 되돌릴 수 있는 작업(구조 변경·범위 번짐·커밋된 파일 삭제·의존성 추가 등)도 승인 전 금지로 두고, 요청 범위 밖 수정을 절대 금지로 둔다. 기존 테스트·골든의 기대값 변경·삭제를 막는 규칙이 리팩토링 전 구현 세부만 지키던 테스트까지 지킨다. 스크립트 일괄 편집은 줄바꿈·BOM 을 바꿔 놓는 함정만 경고돼 있고 안전하게 하는 규칙이 없다.

## Proposed outcome
git 으로 되돌릴 수 있는 작업(구조 변경·내부 API 변경·기존 동작 변경·커밋된 파일의 삭제·이동·이름 변경·범위 번짐·의존성 추가 — 기존 패키지 소스에서의 restore 포함, 새 패키지 소스·레지스트리 추가는 제외)은 승인 없이 먼저 하고 결과를 완료 보고에 보인다. 계획 단계에서 드러난 요청 밖 함께 고칠 곳과 요청 밖 기능 추가는 제품 방향이라 계속 묻는다. 승인이 남는 것은 DB 변경·외부 호출·환경변수·시크릿·push·병합·태그·릴리즈·PR·force push·복구 경로 없는 삭제·덮어쓰기·외부 공개 API 삭제·호환을 깨는 변경이다. 이번 회차가 만든 결함은 같은 회차에 닫고, 그 밖에 발견한 문제는 묻지 않고 기록해 다음 회차로 넘긴다. 더하기 전에 바꾸려는 기능이 지나는 영역의 죽은 코드·중복 검증·안 쓰이는 참조를 먼저 지운다(기본값 삭제). 새 내부 API 는 호환 계층 없이 호출부를 같은 회차에 옮기고 옛 API 를 지우며, 리팩토링 전 구현 세부만 지키던 테스트는 지운다(관측 동작 테스트는 보호). 반복 편집은 스크립트로 하되 원래 줄바꿈·BOM 을 보존하고 편집 뒤 확인한다. 이 규칙이 pjc 스킬 문서와 글로벌 `~/.claude/CLAUDE.md` 에 함께 들어간다.

## Affected users and systems
pjc 로 작업하는 모든 세션과 이 PC 의 글로벌 지침. 시스템: implement·plan·debugging·chain-plan 스킬 문서, 리뷰어 2종, README, 이 레포 `AGENTS.md`·`docs/harness-conventions.md`, 글로벌 `~/.claude/CLAUDE.md`.

## Constraints
차단 hook(`exit 2` 를 내는 넷)과 plan 게이트는 바꾸지 않는다. 글로벌 `CLAUDE.md` 는 레포 밖 개인 파일이라 고치기 전에 시스템 임시 폴더에 백업하고 plan 의 승인 필요 항목으로 둔다. 절대 금지의 나머지 셋(검증 허위 보고·질문 작업에서 파일 수정·시크릿 기록)은 그대로다. 파일 크기 게이트·CRLF·`.ps1` BOM 을 지킨다.

## Open questions
없음
