# 드문 갈래 (`karina:plan`)

> `../SKILL.md` 가 조건이 맞을 때만 이 파일을 연다 — `AGENTS.md` 에 아키텍처 선언이 없을 때(Step 1)다. 승인 답 `G`·`S`·`C` 의 갈래는 `interview.md`「승인 제시」 가 정본이다.

## 아키텍처 선언 부재

- **`AGENTS.md`에 아키텍처 선언이 없으면 이번 계획이 확정한다** — 기본값과 「두지 않으면 근거를 남긴다」는 `../../AGENTS-BOUNDARY.md`「생성물 골격 (정본)」의 아키텍처 불릿이 정본이다. **`../SKILL.md` Step 2의 질문 하나로 확정한다**(`GUESS:`) — 말없이 적용하면 의도적 비채택인지 누락인지 갈리지 않는다. 중계 모드는 Step 2 가 없어 경로가 `relay-edge-cases.md`「아키텍처 선언 부재」에 있다.
- **확정한 선언(중계 모드의 답 포함)은 계획 중에 쓰지 않고 plan 의 첫 task 로 「`karina:record-project-fact` 로 `AGENTS.md` `## Conventions` 의 `- **아키텍처**:` 줄 기록」을 둔다** — 계획 단계 산출물은 `plan.md` 와 없을 때 만드는 `AGENTS.md` 뿐이고(`../SKILL.md` 머리), 기록하지 않으면 다음 계획이 같은 질문을 다시 낸다. plan 승인이 그 기록의 승인을 겸한다(`../../record-project-fact/SKILL.md` Step 3). 초안 모드는 실행되지 않아 진행 모드의 plan 이 그 task 를 갖는다.
