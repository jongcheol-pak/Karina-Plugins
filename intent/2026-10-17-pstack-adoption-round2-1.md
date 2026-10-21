# Intent: pstack 검토 2절 회차 1 — 외부 선례 근거 규약 · 디버깅 규율 7건 · code-style 보강
Author: 사용자. Status: approved.

## Problem
원문 요청: 「2. 도입 권장 계획」 — pstack 검토 2절(가치 중) 17건 중 회차 1(디버깅 7건 + code-style 보강)이다. 새 문면 규칙은 「그것이 없어서 실제로 일어난 일」을 근거로 대야 하는데(`DESIGN.md:52`·`[면제 ⑤]`), 다른 하니스에서 확인한 규칙을 들일 근거 형태가 없어 이 항목들이 통로가 없었다. 디버깅에는 성능 측정 절차·사용자 지목 원인의 취급·2회 실패 시 전제 점검·같은 결함 전수·가드 정당성 판정·git 이력 추적 명령·자동 신호 없는 재현 조건이 없고, `code-style.md` 는 포인터가 말하는 「가독성·길이·주석」 을 담지 않는다.

## Proposed outcome
`[면제 ⑤]` 에 네 번째 근거 형태 「외부 선례」(외부 문면 인용 · 대응 규칙 부재 실측 · 이 레포에서 그 실패가 지나갈 경로 — 셋 모두)가 있고 계획 리뷰어가 그것을 대조한다. 디버깅 문서에 위 7건과 추가 2건(상시 신호 제안 · 재시작 후 실패의 영속 상태 의심)이 있고, `code-style.md` 에 멱등성·옛 경로 정리·린트 억제 주석·도메인 모델 신호가 있으며 그것을 가리키는 포인터가 내용과 맞는다.

## Affected users and systems
pjc 를 쓰는 세션(`pjc:pjc-systematic-debugging` · `pjc:implement` · `pjc:plan`)과 `plan-reviewer`. 시스템: `plan/references/plan-template.md`·`DESIGN.md`·`agents/plan-reviewer.md`·`docs/harness-conventions.md`, debugging `SKILL.md`·`references/*`, `implement/references/code-style.md`·`report-format.md`·`SKILL.md`.

## Constraints
SKILL.md 12,000자 · references 15,000자 · 에이전트 정의 6,000자 게이트 안. 워킹트리 CRLF 보존. 외부 인용은 pstack 저장소 고정 커밋 URL 로 적는다.

## Open questions
없음
