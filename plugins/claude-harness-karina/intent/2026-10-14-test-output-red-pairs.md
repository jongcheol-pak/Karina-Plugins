# Intent: 테스트 확인의 출력 비용·RED 규칙·골든 소요 서술 정비
Author: 사용자(jongcheol-pak). Status: approved.

## Problem
원문 요청: 「테스트 계획을 작성하고 테스트는 어떻게 확인을 하나? 그리고 테스트 계획이 코드 작업에 영향을 미치는지 확인」 → 「수정할 부분은없나? 그리고 테스트 확인시에도 토큰 소모가 많나?」 → 「셋 다 계획 세워줘」. hook 골든 전체 실행이 87.6KB·1065줄을 출력하고(2026-10-14 실측) 문서의 소요·10분 캡 서술이 실측(684초)과 어긋나며, `implement` 의 RED 규칙이 구현 전에도 통과하는 게 정상인 신규 음성 짝 케이스를 미검증으로 만든다.

## Proposed outcome
hook 러너는 기본으로 FAIL·PENDING·경고·결과·TIMING 줄만 내고 `-Full` 이면 지금과 같은 전체 출력을 낸다 — lint 골든 러너(17,976B)도 같은 방식으로 `--full` 을 갖는다(승인 화면에서 「lint 골든 축약도 이번에 포함해」). `golden-runner.md` 의 소요·실행 방법·state 집계 서술이 실측과 맞는다. 신규 음성 케이스는 같은 task 에 RED 를 본 양성 짝이 있을 때 GREEN 만 보고, plan 템플릿이 케이스마다 RED/GREEN 기대를 표시하며 `plan-reviewer` 가 그 표시 누락을 지적한다.

## Affected users and systems
`pjc:plan`·`pjc:implement` 를 돌리는 세션과 두 리뷰어 · `plugins/pjc/hooks/evals/run-hook-evals.ps1`·`eval-common.ps1` · `plugins/pjc/skills/llm-wiki/evals/run_lint_evals.py` · `docs/golden-runner.md`·`docs/harness-conventions.md` · `implement/SKILL.md`·`plan/references/plan-template.md`·`agents/plan-reviewer.md`.

## Constraints
러너의 판정·exit 코드는 바뀌지 않는다(출력만 줄어든다). 차단 hook 4종은 건드리지 않는다. CRLF·`.ps1` BOM 을 유지한다. 순차·병렬 등가 대조는 `-Full` 로 계속 가능해야 한다.

## Open questions
없음
