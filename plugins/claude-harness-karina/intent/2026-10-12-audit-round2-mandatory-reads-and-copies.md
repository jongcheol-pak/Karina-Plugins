# Intent: 하니스 감사 2회차 — 의무 Read 축소·규칙 사본 정리
Author: 사용자(jongcheol-pak). Status: approved.

## Problem
원문 요청: 「위키, 하니스,체인 등 스킬에서 불필요한 부분이나 작업 속도에 영향을 주는 부분, 사용하지 않는 문서을 만들고 있는지 검토」 → 「모두 수정 계획 작성. 아무도 다시 읽지 않는 산출물 항목도 같이 계획」 (3회차 분할의 2회차). 위키 쓰기 세션은 예산 신호가 없어도 쓰기 규칙 ⑦~⑨ 와 큐 소비 규칙을 매번 읽고, implement·plan 의 완료 기록은 WIKI.md 머리와 큐 규약을 통째로 읽으며, 체인 워커는 조건부 규칙이 섞인 relay-mode(11,572자)를 매번 읽는다. 같은 규칙(체인 답 서식·DB 위치·heredoc·3회 상한·worker_done 순서·실측 칸·Next Steps, 위키 예산 값, schema 절차 요약)이 여러 파일에 사본으로 있고, 상시 문서에 날짜 일화 13개와 드문 사건(사후 완료·자리 대기) 서술이 있다.

## Proposed outcome
위키 쓰기 세션은 예산 신호가 났을 때만 ⑦~⑨ 를, 대상 프로젝트 큐 항목이 있을 때만 큐 소비 규칙을 읽는다. implement·plan 은 WIKI.md 와 큐 규약에서 필요한 절만 읽는다. relay-mode 의 조건부 규칙은 relay-edge-cases 로 옮긴다. 체인 규칙 사본 7종·위키 예산 값(⑥ 표와 lint.py 만 남김)·schema 절차 요약은 정본 하나와 포인터가 되고, 검사기 출력 문구와 절차 문서의 다섯째 예산 사본도 함께 정리한다(후보 라운드 포함). 날짜 일화 괄호는 지우고 「왜」 문장은 남기며, 사후 완료 서술은 참조 파일로 내린다(자리 대기의 재기동 규칙은 유일한 자리라 남는다). 실측 칸 목록·봉투 대조 문면 사본을 정리하고, `worker-start.md` 는 `cli-errors.md` 로, `delegation.md` 는 `user-relay.md` 로 합친다. 동작은 바뀌지 않고 읽는 시점·위치만 바뀌며 전 검사기·골든이 통과한다.

## Affected users and systems
pjc:plan·implement·chain-plan·llm-wiki 를 쓰는 세션(사용자·체인 코디네이터·워커). `llm-wiki/SKILL.md`·references·`evals/check_consistency.py`·`scripts/lint.py` 주석, `skills/WIKI.md`, `implement/SKILL.md`, `plan/SKILL.md`·`references/relay-mode.md`·`relay-edge-cases.md`·`interview.md`·`plan-template.md`, `chain-plan/SKILL.md`·references, `evals/check-stale-refs.py`·`cases.json`, `docs/harness-conventions.md`·`stale-docs-rationale.md`.

## Constraints
차단 hook 넷과 그 판정은 바꾸지 않는다. `check-harness-consistency.py` 축 정리·guard-bash 지연 로드·정본 문서 이력 걷기는 3회차 몫이다. 큐 규약 규칙의 의미(하네스 예외 포함)는 바꾸지 않는다. CRLF·BOM 규약 · SKILL 문서 예산.

## Open questions
없음
