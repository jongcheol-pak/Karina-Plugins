# Intent: 계획 세션의 컨텍스트를 구현·조사에서 떼어 낸다
Author: 사용자(jongcheol-pak). Status: approved.

## Problem
공식 Best practices(code.claude.com/docs/en/best-practices)와 대조하니 컨텍스트 관리 두 곳이 어긋났다 — *"Once the spec is complete, start a fresh session to execute it"* 와 *"use subagents to investigate"*. `pjc:plan` 은 승인 직후 같은 turn 에서 `pjc:implement` 를 불러 인터뷰·실측·리뷰로 찬 컨텍스트를 구현까지 끌고 가고, Step 3 실측은 전부 메인 세션에서 돈다. 원문 요청: *"그럼 공식 대로 하니스 스킬은 잘 구현 되어 있는지 확인"* → 대조 결과 중 2·3번(컨텍스트 관리)을 `pjc:plan` 으로 계획하자는 제안에 *"승인"*.

## Proposed outcome
승인 화면에 「승인·새 세션에서 구현」 선택지가 있고, 그것을 고르면 계획 세션은 승인 표지까지 마친 뒤 구현하지 않고 새 세션에 붙여 넣을 한 줄을 내고 끝난다. Step 3 실측은 탐색이 넓을 때(변경 대상을 가리키는 리터럴마다 추적 파일만 센 파일 수의 합이 30 초과) Explore 서브에이전트 1개에 탐색과 「없다」 확인을 맡기고, 결과는 `(위임)` 표기를 단 Investigation Log 행으로 받는다 — 「없다」 행은 메인이 명령을 다시 돌려 확정하고, acceptance 현재값·삭제 복구 판정·버그 원인 규명은 메인에 남는다.

## Affected users and systems
pjc 하니스로 계획을 세우는 세션(사용자 본인). `pjc:plan` 의 SKILL.md·`interview.md`·`plan-template.md`·`relay-mode.md`·새 참조 문서, README, `session-context` hook 의 Step 3 발췌 골든.

## Constraints
Opus 가이드의 위임 원칙(`skills/DESIGN.md` 3-2)을 지킨다 · `pjc:chain-plan` 중계 모드는 새 세션 선택지를 받지 않는다(워커는 같은 세션에서 구현을 잇는다) · SKILL.md 12,000자·references 15,000자 예산 · 워킹트리 CRLF.

## Open questions
없음
