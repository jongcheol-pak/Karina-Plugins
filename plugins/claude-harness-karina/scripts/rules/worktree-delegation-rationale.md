# warn-worktree-delegation 근거

> `scripts/warn-worktree-delegation.ps1` 의 주석이 가리키는 근거다. 조항↔hook 대응은 `skills/DESIGN.md` 「5. hook이 강제하는 것」 E23 행이다.

## §1 왜 경고하는가

`karina:implement` 는 task 를 서브에이전트에 맡기지 않고 직접 실행하고, 예외는 `plan.md` 의 `> 병렬 그룹:` 줄이 묶은 task 뿐이다(`skills/implement/SKILL.md`「작업 범위」). 그 예외는 `skills/implement/references/parallel-run.md`「띄우기」 의 프롬프트 서식(0단계 fast-forward · plan 갈래 · 커밋 규약 · git 한 호출에 하나)과 「대기」 의 병행 금지를 함께 전제한다.

**재발이다(2026-11-23)** — Karina 앱 체인 run_c18e92c2 plan 3 중계 워커(세션 6363bf44)가 그룹 줄 없는 plan 에서 `Agent` 를 `isolation: "worktree"` 로 약 18회 불러 task 를 즉석 프롬프트로 맡겼다. 서식이 빠져 완료 커밋 체크박스 차단 3회 · worktree 샌드박스 git 거부 약 25회 · 보충 빈 커밋 약 10개가 났다. 문면만으로는 막지 못해 `skills/DESIGN.md` 5절의 재발 예외로 hook 을 둔다.

- **경고다 — 차단이 아니다(요구 원문)** — 막지 않고 `exit 0` 에 stderr 와 `additionalContext` 로 같은 안내를 싣는다. 위임 자체는 되돌릴 수 있고(worktree·브랜치는 남는다), 그룹 판정을 hook 이 틀리면 정당한 병렬 실행이 막힌다.

## §2 언제 경고하는가

다섯이 모두 참일 때만이다. 하나라도 판정할 수 없으면 침묵한다(§3).

- **`tool_input.isolation` 이 `worktree` 다** — 격리 없는 `Agent` 호출(탐색·리뷰어)은 task 위임이 아니다.
- **입력에 `agent_id` 가 없다** — 서브에이전트 안의 호출은 메인의 루프가 아니다(`reply-language-rationale.md` §2 와 같은 거름).
- **이 세션의 implement 발동 마커(`~/.claude/.state/loop-continue/<sid>.active`)가 있다** — 마커는 `loop-continue` 가 implement 발동 때 세우고 plan 발동 때 지운다(`loop-continue-rationale.md` §6). implement 루프 밖의 worktree 위임은 이 규칙의 대상이 아니다.
- **cwd 에서 위로 찾은 `plan.md` 가 있다** — 탐색은 `plan-round.ps1` 의 `Find-SinglePlanUpwards` 다(`guard-bash` 와 같은 탐색 — 레포 경계에서 멈춘다).
- **그 plan 에 `> 병렬 그룹:` 줄이 없거나, `tool_input.description` 의 `T<N>` 이 어느 그룹 줄에도 없다** — 그룹 줄이 있어도 밖 task 를 맡기면 같은 위반이다. description 에 `T<N>` 이 없으면 그룹 task 의 띄우기 서식(`description: "T<N> 병렬 실행"`)이 아니므로 경고한다.

## §3 판정 불가는 침묵

stdin 이 JSON 이 아니거나, `session_id`·`cwd` 가 없거나, plan 을 읽지 못하면 아무것도 내지 않고 `exit 0` 이다. 경고가 빠져 잃는 것은 안내 한 줄이고, hook 실패가 `Agent` 호출을 막아서는 안 된다 — 그래서 `hooks.json` 블록에 `onFailure` 를 걸지 않는다.

## §4 배선

`hooks.json` PreToolUse `"matcher": "Agent"` 블록에 디스패처 없이 단독으로 건다 — 이 매처에 걸리는 스크립트가 하나뿐이다(`hook-dispatch-rationale.md` §1). `Agent` 호출은 회차당 수십 회 이하라 호출마다 pwsh 기동(단독 실측 약 0.46초 — `reply-language-rationale.md` §2)이 더해져도 루프 비용에 비해 작다.
