# 계획 체인 인계 — run_9b52a45ef7f97baf22d834a04e87c4f3

## plan 1

- **BASE**: 5dbe516d · **커밋**: a97ec9dc…c66da287 (T1~T7 · 주석 정리 e96aa9b3 · G2 보정 c66da287)
- **바꾼 파일·새 심볼·API**
  - 신규 `skills/REPO-DECISIONS.md` — 절 `## 위치`·`## 읽기`·`## 쓰기`(항목 형식 포함)·`## 아카이브`. 결정 이력 규약의 정본.
  - 신규 `docs/decisions.md`(28항목 — 2026-11-11 번복 포함)·`docs/decisions-archive.md`(286항목) — vault claude-harness-karina 이력 이전본.
  - `skills/implement/SKILL.md` 회차 끝 줄 · `implement/references/final-review.md` 절 이름 `## 함정 기록·결정 기록`(옛 「함정 기록·결정 큐잉」) — 완료 시 `docs/decisions.md` 에 직접 기록, vault 를 읽거나 쓰지 않음.
  - `plan/SKILL.md` Step 1 · `chain-plan/SKILL.md` 후보 라운드 · `WIKI.md` §1·§3·§4 · `AGENTS-BOUNDARY.md`(결정 이력 행 신설) · `REPO-CONVENTIONS.md` · `AGENTS.md` · `README.md` · `interview.md`·`grill.md`·`reflect/SKILL.md`·`local-gate.md`·`session-context-rationale-wiki.md` — 결정 이력 읽기·인용이 레포 두 파일.
  - `scripts/session-context.ps1` 압축 주입이 `REPO-DECISIONS.md` 「쓰기」~「아카이브」(1,415B) — 골든 SC42 계열 앵커 `트리거는 둘이다`·`원문 발췌 — REPO-DECISIONS.md 「쓰기」`·`그 회차의 마지막 커밋에 함께 넣는다`.
  - `skills/evals/check_wiki_circuit.py` 14단계(8~13 이 결정 회로 · 13 은 implement·final-review 에 `pending.md`·`queue-rules` 부재).
  - 검사기: `check-harness-consistency.py` `_DECISION_LOGS`(기록 문서 술어) · CRITICAL_LITERALS implement 항목 리터럴 `보류·기각·번복 결정 기록은` · `check-stale-refs.py` EXCEPTIONS 에 결정 이력 2파일 · 골든 `harness-decision-log-excluded`(161케이스) · 픽스처 `evals/fixtures/minimal-repo/docs/decisions*.md`.
- **내린 결정과 근거**
  - 결정 이력 2파일은 날짜가 붙은 기록이라 정합·stale 검사에서 뺀다 — 이전본이 포인터 끊김·폐기 식별자 18건, 옛 자산 이름 76건으로 검사를 막았다.
  - vault 이력 이전: 11개 대상 폴더(Claude Code Mod·CountingDashboard·ProjectDashboard·DeskTube·Karina-Mobile·Karina·MOA·turing-smart-screen·Tiny Swords·LGRenewStepUpdate·LGURStepUpdate)에 새 파일만 만들고 커밋하지 않음 · 파일마다 항목 수 대조 일치 · vault 16파일 삭제 로컬 커밋 5b43ec6(push 안 함).
- **뒤 계획(plan 2)이 지킬 제약**
  - vault 의 `decisions` 링크(허브·템플릿 등 약 16파일)는 지금 끊긴 채다 — plan 2 가 정리한다.
  - llm-wiki 쪽 잔존: `skills/llm-wiki/references/queue-rules.md` 의 K 5-2(구현 종료 시점 트리거 문면)·`wiki-schema.md:222`(「결정 큐잉」) 와 `docs/harness-conventions.md` 「llm-wiki ↔ 글로벌 지침 결합」 표의 큐 폴백 행 — plan 2 몫. 완료 흐름은 이미 vault 를 쓰지 않으므로 그 문면은 호출되지 않는다.
  - 회로 검사 13단계는 implement/SKILL·final-review 에 `pending.md`·`queue-rules` 문자열이 다시 들어오면 FAIL 한다.
  - 버전은 아직 올리지 않았다(체인 마지막 계획 몫).
- **미해결**
  - MOA 는 `.gitignore` 의 `/docs/*` 때문에 새 `docs/decisions*.md` 가 git 에 보이지 않는다(파일은 실재) — 그 레포 세션이 ignore 예외를 둘지 정한다.
  - 다른 레포의 새 파일은 미커밋 — 각 프로젝트 세션이 자기 커밋에 포함한다.
