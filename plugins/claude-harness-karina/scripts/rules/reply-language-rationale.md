# inject-reply-language 근거

> `scripts/inject-reply-language.ps1` 의 주석이 가리키는 근거다. 조항↔hook 대응은 `skills/DESIGN.md` 「5. hook이 강제하는 것」 E16 행이다.

## §1 왜 hook 이 응답 언어를 주입하는가

긴 세션에서 스킬이 발동된 뒤 응답이 영문으로 기우는 현상이 있었다. 하니스 스킬·에이전트·hook 어디에도 사용자 출력 언어 지시가 없고(2026-10-24 실측 — 지시 형태 검색 0줄), 응답 언어 규칙은 사용자 글로벌 지침 머리에만 있다. 영문 스킬 본문·도구 출력·서브에이전트 보고가 쌓이면 생성 위치에서 먼 그 규칙이 밀린다.

- **강제가 아니라 주입이다** — `DESIGN.md` 5절 머리 원칙(hook 은 되돌릴 수 없는 것만 강제한다)에 걸리지 않는다. 차단·경고 없이 한 줄만 싣는다(E9·E11 과 같은 형태).
- **스킬·에이전트 본문에 문구를 넣지 않는다** — 파일마다 같은 줄을 복제해야 하고 새 스킬이 생길 때마다 빠진다.
- **한글 고정 · 끄는 스위치 없음** — 하니스가 한글 우선이고, 한 줄 주입이라 끌 이유가 적다(사용자 결정).

## §2 두 이벤트 — 스킬 이름은 거르지 않는다

- **`UserPromptSubmit`** — 매 사용자 턴이다. 슬래시 명령을 직접 입력한 경우도 이 이벤트가 그 줄을 받으므로(공식 hooks 문서) `UserPromptExpansion` 에는 걸지 않는다.
- **`PreToolUse` · `tool_name` = `Skill`** — 스킬 본문이 들어오는 자리다. `karina:implement` 루프처럼 사용자 입력 없이 도구 호출이 이어지는 동안에도 스킬 발동 때마다 본문 옆에 실린다.
- **모든 스킬에 주입한다** — 영문으로 쓰인 다른 플러그인 스킬도 쏠림의 원인이다.
- **`record-work-start` 와 파일을 나눈다** — 같은 이벤트를 받지만 변경 이유가 다르다. 같은 이벤트의 hook 은 병렬로 돌고, 여러 hook 이 낸 `additionalContext` 는 모두 전달된다(공식 hooks 문서 「When several hooks return `additionalContext` for the same event, Claude receives all of the values.」).
- **비용** — `UserPromptSubmit` 에는 다른 hook 이 없어 pwsh 기동 시간(실측 0.5~0.7초)이 사용자 턴마다 더해진다. bash `echo` 로 줄이는 안은 문구가 두 곳에 갈라져 기각했다(사용자 결정).

## §3 판정 불가는 침묵

stdin 이 JSON 이 아니거나, 다른 이벤트이거나, Skill 이 아닌 도구면 아무것도 내지 않고 exit 0 이다. 주입이 빠져도 잃는 것은 리마인더 한 번이고, 실패가 사용자 입력이나 스킬 호출을 막아서는 안 된다.
