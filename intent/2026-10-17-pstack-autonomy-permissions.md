# Intent: 권한 규칙 개정 — push·PR·merge·자기 `pjc/` 브랜치 force-with-lease 무승인
Author: 사용자(코디네이터 인터뷰 경유). Status: approved.

## Problem
spec 「원문:」 블록 그대로:

plan 1: 권한 규칙 개정 — push·PR 생성·PR 코멘트·PR merge 와 자기 `pjc/` 브랜치의 force-with-lease push 를 승인 없이 하도록 글로벌 지침·레포 사본·경고 hook·차단 hook(골든)·AGENTS.md DO NOT 를 고친다. 릴리즈·태그·배포·main/공유 브랜치 force push 는 계속 승인·차단
(사용자 처음 지시: 「pstack이 자율로 하는 것 하도 동일하게 수정해」 — opening-a-pr·babysit·shipping·autopilot-full)
[공통] Q: 「동일하게」의 범위 / 선택지: 승인 규칙만 푼다 (권장) · 규칙 + 새 기능 · 새 기능만 만든다 / A: 규칙 + 새 기능
[plan 1] Q: autopilot-full 의 자기 브랜치 rebase → force-with-lease push 도 자율로? / 선택지: 뺀다 (권장) · 넣는다 — 자기 브랜치만 / A: 넣는다 — 자기 브랜치만
[공통] Q: 릴리즈·태그 발행도 자율로? / 선택지: 계속 승인 (권장) · 릴리즈도 자율 / A: 계속 승인 (권장)
[공통] Q: 의도 재진술(PR 흐름 항상·babysit/ship 요청 시·검증 에이전트·chain-plan PR 모드·push/PR/merge/자기 브랜치 force-with-lease 자율·릴리즈 승인 유지·스택 PR 범위 밖) 확인 / 선택지: 없음 / A: 진행
[plan 1] Q: 후보 라운드 — 1 force push 차단 근거 문서(destructive-rationale.md:16·:20)의 번호 지칭 바로잡기 · 2 외부 작업 경고가 `--help` 호출에도 뜨는 오탐 수정(검색 문자열 쪽은 제외) / 선택지: 권장대로 (권장) · 3만 worktree / A: 권장대로 (권장) — 1 포함 · 2 포함(--help 만)
[공통] Q: 세 회차 진행 방식 / 선택지: 계획 체인으로 (권장) · 이 세션에서 1회차부터 / A: 계획 체인으로 (권장)
[공통] Q: 계획 체인 승인 / 선택지: Y 승인 · E 수정 요청 · N 중단 / A: 진행

지금 하는 이유: 되돌릴 수 있는 작업은 묻지 않는다는 앞 회차 기준을 원격 작업까지 넓혀, PR 흐름(plan 2·3)에서 루프가 서지 않게 하는 전제다.

## Proposed outcome
승인된 plan·발동된 스킬 실행 안에서 push·PR 생성·PR 코멘트·PR merge·로컬 병합이 승인 목록·「멈추는 넷」에서 빠지고(일반 작업에서는 지금처럼 승인 · 외부 작업 경고는 남되 그 구분을 문구로 말한다), 에이전트가 만든 `pjc/` 브랜치를 이름으로 명시한 `--force-with-lease` push 는 차단되지 않는다. 릴리즈·태그·배포와 main·공유 브랜치 force push·브랜치를 명시하지 않은 force-with-lease·`--force`·`-f` 는 계속 승인·차단되며 골든이 그 경계를 실증한다. 글로벌 지침·레포 사본·외부 작업 경고 문구가 새 기준과 맞는다. 요청 밖 포함: force push 차단 근거 문서의 번호 지칭 바로잡기 · 외부 작업 경고의 `--help` 오탐 수정.

## Affected users and systems
이 PC 의 pjc 사용자(글로벌 `~/.claude/CLAUDE.md` 포함)와 마켓플레이스 설치 사용자. 글로벌 지침 · implement/plan/chain-plan/llm-wiki 스킬 문서 · `DESIGN.md` · `README.md` · `AGENTS.md` · `docs/harness-conventions.md` · `guard-bash`(외부 작업 경고)·`block-destructive`(차단) hook 과 규칙 파일·근거 문서·골든.

## Constraints
차단 hook 변경은 골든 실증(델타 양성·음성)을 붙이고 `AGENTS.md` DO NOT 와 harness-conventions 「안전 임계 hook 의 차단 동작 변경」 허용 종류를 함께 개정한다. 글로벌 지침은 레포 밖이라 시스템 임시 폴더에 사전 백업한다(체인 승인에 승인 필요 항목으로 명시 승인됨).

## Open questions
없음
