# inject-reply-language 근거

> `scripts/inject-reply-language.ps1` 의 주석이 가리키는 근거다 — 주입(§1~§3)과 Stop 재작성(§4). 조항↔hook 대응은 `skills/DESIGN.md` 「5. hook이 강제하는 것」 E16 행이다.

## §1 왜 hook 이 응답 언어를 주입하는가

긴 세션에서 스킬이 발동된 뒤 응답이 영문으로 기우는 현상이 있었다. 하니스 스킬·에이전트·hook 어디에도 사용자 출력 언어 지시가 없고(2026-10-24 실측 — 지시 형태 검색 0줄), 응답 언어 규칙은 사용자 설정 두 곳에만 있다 — `settings.json` 의 `language`(메인 세션 시스템 프롬프트의 Language 절 — 서브에이전트에는 실리지 않는다)와 사용자 글로벌 지침 머리다(2026-10-28 실측). 둘 다 세션 머리에 한 번 실려, 영문 스킬 본문·도구 출력·서브에이전트 보고가 쌓이면 생성 위치에서 먼 그 규칙이 밀린다.

- **강제가 아니라 주입이다** — `DESIGN.md` 5절 머리 원칙(hook 은 되돌릴 수 없는 것만 강제한다)에 걸리지 않는다. 차단·경고 없이 한 줄만 싣는다(E9·E11 과 같은 형태).
- **스킬·에이전트 본문에 문구를 넣지 않는다** — 파일마다 같은 줄을 복제해야 하고 새 스킬이 생길 때마다 빠진다.
- **한글 고정 · 끄는 스위치 없음** — 하니스가 한글 우선이고, 한 줄 주입이라 끌 이유가 적다(사용자 결정).

## §2 Skill 발동 주입과 PreToolUse 셸·쓰기 20회 주기 주입

- **`UserPromptSubmit` 매 턴 주입은 폐지했다(2026-11-04)** — 사용자 턴은 그 직전에 사용자 설정 `language` 와 글로벌 지침이 이미 같은 규칙을 싣는 자리라 겹쳤고, 그 자리에 다른 hook 이 없어 pwsh 기동 시간(실측 0.5~0.7초)이 턴마다 더해졌다. 쏠림이 생기는 것은 영문 스킬 본문이 들어오는 자리다.
- **`PreToolUse` · `tool_name` = `Skill`** — 스킬 본문이 들어오는 자리다. `karina:implement` 루프처럼 사용자 입력 없이 도구 호출이 이어지는 동안에도 스킬 발동 때마다 본문 옆에 실린다.
- **Skill 도구를 거쳐 발동하는 스킬에는 karina 밖 스킬에도 주입한다** — 영문으로 쓰인 다른 플러그인 스킬도 쏠림의 원인이다. 사용자가 `/스킬` 을 직접 치면 PreToolUse 를 거치지 않아(`loop-continue-rationale.md` 「`UserPromptExpansion`」 의 공식 문서 인용) 주입이 없다 — 그 턴은 사용자 설정 `language` 와 글로벌 지침이 같은 규칙을 싣는 사용자 턴이라 `UserPromptExpansion` 주입을 두지 않는다.
- **셸·쓰기 도구의 PreToolUse 를 세어 20회째마다 같은 줄을 다시 싣는다(2026-11-07 도입 · 2026-11-12 PostToolUse 에서 이전)** — 스킬 발동 주입만으로는 `karina:implement` 루프 안에서 도구 호출이 수백 번 쌓인 뒤 진행 안내가 영어로 샜다(전사 실측 — 마지막 주입 뒤 약 850·2100줄에서 영문 상태 메모 2줄). 주기는 사용자가 골랐다(20 · 10 · 40 중).
  - **받는 도구는 `Bash|PowerShell|Write|Edit|MultiEdit|NotebookEdit`** — 셸·쓰기 PreToolUse 차단 묶음의 권고 구간(`advisory:` 뒤)에 들어간다(`hook-dispatch-rationale.md` §7 — 같은 프로세스라 pwsh 기동이 늘지 않고, 차단되면 돌지 않으며 실패해도 도구 호출을 막지 않는다). hook 이 없는 Read·Grep·Glob 까지 세면 호출마다 pwsh 기동(단독 실측 0.46초)이 더해진다.
  - **PostToolUse 에서 옮긴 이유(2026-11-12)** — 셸 PostToolUse 블록을 지워 셸 호출당 pwsh 를 2 → 1 로 줄였고, 쓰기 PostToolUse(`post-write-checks`)는 async 가 되어 거기서 세면 카운트가 백그라운드에서 돌아 주입이 한 턴 밀린다. 이제 PostToolUse 는 받지 않는다.
  - **카운터는 `~/.claude/.state/reply-language/<sid>.txt` 정수 하나** — Skill 주입이 0으로 되돌리고, 20에 닿으면 주입하고 0으로 쓴다. 읽지 못하거나 정수가 아니면 0으로 보고, 쓰기 실패는 침묵한다(병렬 도구 호출의 동시 쓰기로 한 번 덜 세는 것은 허용). 30일 지난 파일은 `session-context` 가 걷는다.
  - **`agent_id` 가 실린 입력(서브에이전트 안)은 세지 않는다** — 서브에이전트의 도구 호출도 같은 hook 을 거치고 입력에 `agent_id` 가 실린다(공식 hooks 문서). 세면 주입이 서브에이전트 컨텍스트로 새고 메인 간격이 늘 수 있다. 서브에이전트 안 Skill 은 주입만 하고 메인 카운터를 쓰지 않는다. `agent_type` 은 `--agent` 메인 세션에도 실려 거름 필드로 쓰지 않는다.
  - **`session_id` 가 없으면** Skill 은 주입만 하고 셸·쓰기 호출은 무출력이다.
- **`record-work-start` 와 파일을 나눈다** — 같은 이벤트를 받지만 변경 이유가 다르다. 같은 묶음의 스크립트는 `hook-dispatch.ps1` 이 차례로 부르고, 각자 낸 `additionalContext` 를 하나로 합쳐 넘긴다(`hook-dispatch-rationale.md` §3).
- **compact 직후에는 `session-context.ps1` 이 이 스크립트의 `$Line` 을 읽어 같은 줄을 싣는다** — 근거는 `session-context-rationale.md` §41.

## §3 판정 불가는 침묵

stdin 이 JSON 이 아니거나 PreToolUse·Stop 이 아닌 이벤트면 아무것도 내지 않고 exit 0 이다. Skill 이 아닌 도구는 20회째가 아니거나 판정 재료(`session_id`)가 없으면 같은 침묵이고, Stop 은 `session_id`·`last_assistant_message` 가 없거나 재작성 표시를 쓰지 못하면 침묵한다. 주입이 빠져도 잃는 것은 리마인더 한 번이고, 실패가 스킬·도구 호출과 turn 종료를 막아서는 안 된다.

## §4 Stop 에서 영문 응답을 한 번 다시 쓰게 한다

**재발이다(2026-11-18)** — 스킬 발동·셸·쓰기 20회 주입과 완료 리뷰의 사후 계수가 있는데도 Karina 앱 체인 plan 6 에서 영문 상태 메모 약 60줄과 사용자에게 간 최종 보고 「## Plan 6 complete: …」 가 영문으로 나갔다. 주입은 응답을 쓰기 전의 리마인더라 쓴 뒤의 응답을 보지 못한다. `skills/DESIGN.md` 5절의 재발 예외(E16)로 turn 끝에서 기계로 판정한다.

- **입력은 Stop 페이로드의 `last_assistant_message` 다** — 공식 hooks 문서가 마지막 응답 텍스트는 transcript 대신 이 필드를 쓰라고 한다. transcript 는 비동기로 쓰여 Stop 시점에 마지막 응답이 빠질 수 있다(`loop-continue-rationale.md` §1).
- **형태는 `additionalContext` 다 — `decision:"block"`·`exit 2` 가 아니다(사용자 답)** — 공식 문서상 Stop 의 `additionalContext` 는 「대화를 잇는 비오류 피드백」이라 모델이 같은 turn 에서 다시 쓴다. 차단 형태는 이 레포가 쓰지 않고(`docs/harness-conventions.md` 「`guard-write`의 PLAN-EXEMPT 면제 경로」 머리말), 디스패처는 `additionalContext`·`hookEventName` 밖 필드를 버린다(`hook-dispatch-rationale.md` §3).
- **배선은 `loop-continue` 와 한 디스패처 묶음이다** — 별도 hook 항목이면 Stop 마다 pwsh 가 하나 더 뜬다. 묶음은 직접 호출보다 Stop 당 약 0.15초 늘었다(2026-11-18 5회 교대 — 중앙 1,062 → 1,209 ms).
- **판정식** — 코드 펜스(```` ``` ````·`~~~`)·인라인 코드·URL 을 지운 산문에서 라틴 낱말(`[A-Za-z]{2,}`)이 5개 이상이고 한글(가–힣·ㄱ–ㆎ) 글자 수가 라틴 낱말 수보다 적을 때만 다시 쓰게 한다.
  - **「한글 0자」 가 아니라 비율이다** — 실해 최종 보고는 한글 UI 문자열 인용(「설치되지 않음」·「로그」 등) 52자와 라틴 낱말 678개였다. 0자 식은 이것을 놓친다.
  - **경계 0.5(한글 글자 < 라틴 낱말)** — 2026-11 Karina·하니스 전사의 assistant 텍스트를 한글/(한글+라틴 낱말)로 나누면 0.5 아래 한국어 어미 문장은 6건(짧은 혼합 메모)뿐이고, 0.5~0.65 에는 식별자가 많은 한국어 진행 메모(「4번 검증 통과(lib …」)가 섞였다.
  - **라틴 낱말 5개 하한** — `Done.` 같은 짧은 응답과 명령만 낸 응답은 다시 쓰게 하지 않는다. 오탐의 비용은 사용자가 끝낸 turn 을 한 번 더 잇는 것이다.
- **한 번만 건다 — 이 hook 이 다시 쓰게 한 turn 만 거른다** — 재작성을 실을 때 `~/.claude/.state/reply-language/<sid>.stop` 표시를 쓰고, 다음 Stop 이 `stop_hook_active` 참이면서 표시가 있으면 표시를 지우고 침묵한다. `stop_hook_active` 가 거짓이면 남은 표시를 지우고 판정한다. `stop_hook_active` 만 보면 어떤 Stop hook 이 이었든 참이라 `loop-continue` 가 이은 implement 루프의 끝 보고 — 실해 경로 — 에서 검사가 꺼진다(계획 리뷰 MAJOR). 표시를 쓰지 못하면 재작성도 싣지 않는다 — 셀 수 없는 재작성은 상한이 없는 재작성이다. 폴더는 §2 의 카운터와 같아 `session-context` 가 30일 뒤 걷는다.
- **모든 세션에 건다** — 주입과 같은 범위다(§2 · 사용자 답 「모든 세션」). 서브에이전트 응답(SubagentStop)은 메인이 다시 써서 사용자에게 가므로 받지 않는다.
- **Stop 은 셸·쓰기 카운터를 읽지도 쓰지도 않는다** — 주기 주입과 재작성은 서로의 간격을 바꾸지 않는다.
