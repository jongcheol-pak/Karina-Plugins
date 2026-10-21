# Intent: prompt-audit(Opus 5.5) 2회차 발견 사항 수정
Author: 사용자(jongcheol-pak). Status: approved.

## Problem
`/claude-api prompt-audit` 2회차가 2026-10-09 감사 뒤에 다시 들어온 날짜·버전 꼬리표, 레포에 없는 대상을 가리키는 참조(「규칙 12」·「그 절이 기각」·대장 항목명·「세 곳 동시 갱신」), 어느 cwd 에서도 풀리지 않는 hook 안내 경로, rubric judge 의 「JSON 한 덩어리만」 지시와 재파싱 재시도를 찾았다. 원문 요청: *"전체 수정해"*, 후보 라운드 답 *"권장"*. 감사 근거가 살아 있는 지금 반영한다.

## Proposed outcome
보고서의 수정안 30편집이 반영되고, rubric judge 는 `--json-schema` 구조화 출력으로 채점하며, 후보 라운드에서 포함한 셋(rubric 비교 세대 안내 · chain-plan 병렬 병합 위임 단서 · 버전 드리프트 재설치 안내)이 함께 고쳐진다. 지운 옛 표현은 레포에 남지 않고 검사기·골든은 착수 때와 같은 green 이다.

## Affected users and systems
본인과 마켓플레이스 배포 사용자. `pjc:llm-wiki`·`pjc:plan`·`pjc:implement`·`pjc:chain-plan` 문서, `plan-reviewer`, `session-context`·`session-wiki-signals`·`guard-harness`·`guard-bash`(경고 문구)·`warn-version-drift` hook 메시지, `skills/evals/rubric_eval.py`·`rubric.md`·`README.md`, `docs/harness-conventions.md`·`docs/golden-runner.md`·`skills/AGENTS-BOUNDARY.md`.

## Constraints
워킹트리 CRLF·`.ps1` UTF-8 BOM 유지 · 차단 hook 은 안내 문자열만 바꾸고 차단 판정은 그대로 둔다 · 2026-10-14 결정(옛 설치본 워커의 무응답 실패 재개 경로)은 유지한다 · description 은 고치지 않는다 · push·릴리즈는 별도 승인.

## Open questions
없음.
