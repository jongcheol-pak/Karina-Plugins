# Intent: 계획 리뷰 3라운드를 2라운드 BLOCKER 때만 부른다
Author: 사용자(jongcheol-pak). Status: approved.

## Problem
원문 요청: 「리뷰가 3회차까지 진행 하는데 적당하다고 판단되나? 아니면 2회로 줄여도 문제가 없을 거 같나?」 → 답변의 대안(상한 3은 두고 3라운드 호출 조건만 좁힌다)에 「그 대안으로 계획 잡아줘」. 계획 리뷰는 2라운드에 BLOCKER·MAJOR 가 남으면 3라운드를 부르는데, 리뷰어 호출 한 번이 수백만 토큰·수 분이 든다(`plan/references/relay-mode.md:49`). 중계 모드는 이미 BLOCKER 때만 다시 부른다.

## Proposed outcome
일반 모드 계획 리뷰는 상한 3라운드를 유지하고, 3라운드는 2라운드에 BLOCKER 가 있었을 때만 부른다(사용자 답 「계획 리뷰만」). 2라운드 지적이 MAJOR 뿐이면 고치고 다시 부르지 않으며, 그 수정을 승인 제시 `남은 리뷰 지적:` 줄에 `(고침·재검토 안 함)` 으로 싣는다(사용자 답 「승인 화면에 싣기」). README 의 계획 리뷰 서술 두 곳을 새 규칙에 맞춘다.

## Affected users and systems
`pjc:plan` 을 일반 모드로 돌리는 세션 · `plugins/pjc/skills/plan/SKILL.md` Step 6 · `plugins/pjc/skills/plan/references/interview.md` 「승인 제시」 · `README.md`.

## Constraints
완료 리뷰(`implement/references/final-review.md`)와 중계 모드 규칙(`plan/references/relay-mode.md`)은 고치지 않는다. `plan/SKILL.md` 는 12,000자 예산 안에 둔다. CRLF 를 유지한다.

## Open questions
없음
