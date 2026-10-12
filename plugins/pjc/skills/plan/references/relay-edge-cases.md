# 중계 모드 — 드문 조건

> `relay-mode.md`「중계 모드」 의 트리거가 걸렸을 때만 해당 절을 읽는다 — 워커가 매번 읽는 중계 규칙에서 드문 조건에만 쓰는 규칙을 떼어 둔 자리다. `<CLI>` 와 `ask` 명령은 `relay-mode.md`「중계 모드」 의 것이다.

## 아키텍처 선언 부재

- **`AGENTS.md` 에 아키텍처 선언이 없으면 재진술 제약조건에 실린 선언을 쓰고, 거기도 없으면 `relay-mode.md`「중계 모드」 의 `ask` 로 묻는다** — `../SKILL.md` Step 1 은 그것을 Step 2 의 질문으로 확정하는데 중계 모드는 Step 2 를 건너뛰고, 코디네이터가 인터뷰에서 확정해 제약조건에 싣는다(`../../chain-plan/SKILL.md`「인터뷰」). `../../AGENTS-BOUNDARY.md`「AGENTS.md 최소 생성」이 말하는 「Step 2의 답」 자리도 이것이 대신한다.

## ask 만료

- **만료 응답(`answered:false`·`status:"pending"`)이면 `ask --resume <questionId>` 로 같은 질문을 이어 간다 — 다시 묻지 않는다** — 새로 `ask` 하면 같은 질문이 코디네이터에 둘 쌓인다. 시한을 Bash 도구 상한보다 짧게 잡는 것은 도구가 먼저 끊으면 `questionId` 가 출력되지 않기 때문이다.
- **이어 가기 전에 `<CLI> orchestration check --json 2>/dev/null` 로 코디네이터의 대기 신호(`status` 유형, 제목 `사용자 확인 대기 중`)를 본다 — 신호가 있으면 사용자 판단을 기다리는 중이라 상한 없이 이어 가고, 신호 없는 만료가 3회 연속이면 `worker_done --outcome failed`(사유: 코디네이터 무응답)로 멈춘다** — `ask` 는 막는 호출이라 무응답과 사용자 대기를 그 사이의 신호로만 가를 수 있다. 3회는 같은 수단을 세 번 반복해도 닿지 않을 때 멈추는 수다.

## 회차와 이어받기

- **중계 모드는 회차를 나누지 않는 것이 기본이다 — 그래도 나누면 남은 회차를 `worker_done` 의 `남은 일` 에 `[다음 회차]` 로 싣는다** — 워커 화면의 인계 프롬프트는 아무도 보지 않아, 거기만 두면 남은 회차가 사라진다. 코디네이터는 그 표식을 보고 같은 계획의 이어받기 워커를 띄운다(`../../chain-plan/references/continuation.md`「이어받기」).
- **이 계획의 남은 회차만 적는다 — spec `다른 회차:` 의 계획은 `[다음 회차]` 로 적지 않는다** — 그 계획은 체인이 따로 돌린다.
- **spec 머리(또는 args)에 `이어받기: <k>` 가 있으면 이어받기 워커다 — 작업 task 는 `실측 요지:` 항목뿐이고(인계 절은 같은 마무리 마지막 커밋으로 쓴다 — `relay-mode.md` 인계 절의 생략 조건 제외), 인계 절 이름은 `## plan <N> 이어받기 <k>` 다** — 원 계획의 나머지는 앞 워커가 이미 커밋했다.

## 실행 시점 승인

- **`pjc:implement` 「멈추는 넷」의 「파괴적·외부 비가역 작업」(실행 시점 승인 항목)은 `failed` 대신 `ask` 로 승인을 요청한다 — 본문은 무엇을·왜·영향 범위·되돌리는 방법이다** — 코디네이터가 그것을 사용자에게 잇는다(`../../chain-plan/SKILL.md`「답하는 기준」). `Y` 면 실행한다. `N` 이면 실행하지 않고 그 항목에 의존하지 않는 task 를 끝낸 뒤, 의존 task 가 남으면 `--outcome failed`(사유: 거절된 항목·남은 task), 남지 않으면(push 등) `succeeded` 의 `승인 필요 항목` 에 싣는다 — 미완인 계획 위에 다음 계획이 뜨지 않게 한다.

## 사후 완료

- **`worker_done` 이 `inactive_dispatch` 로 거절되면(`failed` 보고 뒤 사용자가 이 탭에서 이어 가게 해 끝까지 간 경우) 같은 `--body` 로 `<CLI> orchestration send --type status --subject "사후 완료 — plan <N>" --from <핸들> --body …` 를 보낸다(`--to` 없음 — 코디네이터로 간다)** — `failed` 로 정산된 배정은 `worker_done` 을 받지 않아, 코디네이터가 이 유형을 완료로 받는다(`../../chain-plan/references/manual-resume.md`「사후 완료」).

## 위임 경로를 바꿀 때

- **이 취급이 기대는 경로를 바꿀 때는 위임부터 다시 설계한다** — 지금 답은 Karina `ask` 의 Bash 출력으로 온다(`../../chain-plan/references/spec-format.md`「spec 서식」 진행 2). 반면 Claude Code 기본 세션 간 메시지(`SendMessage`·agent teams)는 공식 문서상 다른 세션이 보낸 메시지를 사용자 동의로 세지 않는다(https://code.claude.com/docs/en/cross-session-messaging). 그래서 질문 경로를 그것으로 옮기면 위임·판정 답이 승인으로 통하지 않을 것으로 본다(추정 — 옮긴 뒤를 재보지 않았다).
