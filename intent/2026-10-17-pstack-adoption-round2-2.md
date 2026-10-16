# Intent: pstack 검토 2절 회차 2 — plan 규율 4건 · 테스트·검증 원칙 3건 · 위키·대장 2건
Author: 사용자. Status: approved.

## Problem
원문 요청: 「pstack 검토 2절 회차 2 계획 세워줘 — 「2. 도입 권장 계획」의 나머지」. plan 쪽은 실행해 보면 갈리는 갈림길을 사용자에게 묻고, 영향 범위 목록이 심볼 검색이 닿는 자리(호출자·구현체·직렬화·테스트)만 보며, 구조 줄에 기각한 대안이 없고, 가드·매직 상수를 지울 때 그것이 왜 들어왔는지 보지 않는다. 테스트 원칙에는 내부 고정 축·진입 경로 전수·관측 수단 의심이 없고, 재발 함정은 문서로만 기록되며, Deferred 등재 전 중복 판정이 없다.

## Proposed outcome
위 9건이 각 문서(interview 2-3 · 영향 범위 목록 사본 4곳 · plan-template · implement 실패 처리 · deferred-rules)에 있고, 항목마다 `[면제 ⑤ · 외부 선례]` 세 요소가 실측으로 받쳐져 있다. 재발 함정의 강제 수단은 위키 기록과 별도로 plan.md Deferred 에 적혀 등재 판정에 오른다.

## Affected users and systems
pjc 를 쓰는 plan·implement 세션과 `plan-reviewer`. 시스템: `plan/SKILL.md`·`plan/references/{interview,measure-delegation,plan-template,deferred-rules}.md`·`agents/plan-reviewer.md`·`implement/references/{loop-exceptions,code-style}.md`, `session-context` 골든(plan Step 3 발췌).

## Constraints
SKILL.md 12,000자 · references 15,000자 · 에이전트 정의 6,000자 게이트 안. 워킹트리 CRLF 보존. 근거는 각 커밋 본문에 싣는다.

## Open questions
없음
