# Intent: 작업 시작 시각을 hook 이 기록하고 소요 계산을 스크립트로 옮긴다
Author: 사용자(v1.375.0 완료 리뷰 9건에 대한 「hook 기반으로 다시 설계하는게 좋은거 아닌가?」 → 「응, 그렇게 계획 세워줘」). Status: approved.

## Problem
v1.375.0 의 시작·완료 시각 기록은 모델이 Step 1 셸 호출에 `date` 를 얹어 시각을 기억하고 Step 5 까지 들고 가는 구조라, 압축·회차 경계 넘김에서 시각을 잃고(리뷰 5·7번), 서식이 정해지지 않은 자리가 있으며(2번), `date -d` 실패가 서식에 맞는 엉뚱한 값을 내고 stderr 판정이 정상 경우에도 걸리며 macOS 폴백이 돌지 않는다(1·3번). 커밋 판정 순서(4번)·옛 초안 시각 보존 기준(6번)·규칙 근거 누락(8번)·chain-plan/SKILL.md 예산 임박(9번)도 함께 지적됐다.

## Proposed outcome
`pjc:plan`·`pjc:chain-plan` 발동 시각이 hook 에서 세션별 상태 파일에 기록되고 컨텍스트에 주입되며, 압축 직후에도 다시 주입된다. 현재 시각과 소요는 플랫폼과 무관하게 스크립트 출력으로만 나오고, 실패하면 판별 가능한 오류 줄이 나온다. 커밋 판정은 `> 완료:` Edit 뒤에 일어나고, 초안의 `> 시작:` 은 사용자가 그 초안을 명시적으로 「계속」할 때만 보존된다. 새 규칙 줄이 근거를 갖고, chain-plan/SKILL.md 에는 시각 명령·서식을 두지 않아(references 가 받는다) 예산 상한 안에 머문다.

## Affected users and systems
`pjc:plan`·`pjc:implement`·`pjc:chain-plan` 을 쓰는 세션과 완료 보고를 읽는 사용자. hook(`hooks.json`·새 hook·`session-context.ps1`)·시각 스크립트·자기보호 이름 집합·`validate.ps1`·hook 골든·세 스킬의 시각 관련 문서.

## Constraints
차단 hook 4종의 차단 동작은 바꾸지 않는다. 새 hook 은 exit 0 비차단·fail-open 이다. `.ps1` 은 UTF-8 BOM, 워킹트리는 CRLF 다. hook 동작은 골든으로 실증한다. `plugins/pjc/scripts/` 에 두는 새 hook 스크립트는 자기보호 이름 집합에 등재한다.

## Open questions
없음
