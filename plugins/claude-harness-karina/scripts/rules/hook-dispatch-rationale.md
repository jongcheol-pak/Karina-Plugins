# hook-dispatch 근거

> `scripts/hook-dispatch.ps1` 의 주석이 가리키는 근거다. 어느 이벤트·matcher 에 어떤 스크립트가 묶이는지는 `hooks/hooks.json` 이 정본이고, 이 파일은 디스패처의 「왜」만 담는다.

## §1 묶음 실행

같은 이벤트·matcher 에 스크립트가 둘 이상 걸리면 `hooks.json` 은 디스패처 하나를 부르고, 디스패처가 인자로 받은 스크립트(`guard-bash.ps1` 꼴)를 한 PowerShell 프로세스 안에서 차례로 부른다. 묶음 목록을 디스패처가 이벤트·도구 이름으로 고르지 않는 것은 matcher 를 `hooks.json` 과 디스패처 두 곳에 두지 않기 위해서다. 스크립트가 하나뿐인 블록은 디스패처를 거치지 않고 지금처럼 직접 부른다 — 묶을 것이 없으면 디스패처는 일만 더한다.

- **인자는 `^[a-z0-9-]+\.ps1$` 이고 디스패처와 같은 폴더에 있는 파일만 받는다** — 디스패처 자신과 폴더 밖 경로는 받지 않는다. 인자 오류는 묶음과 관계없이 `1` 이라, 차단 묶음에서는 `onFailure: block` 으로 도구 호출이 막힌다.
- **`block-destructive` 도 묶음에 든다** — 2026-07-08 에는 「마지막 방어선을 공유 모듈 로드 실패에 결합하지 않는다」로 독립 실행을 남겼다. 지금은 `hooks.json` 의 `onFailure: block` 이 있어 디스패처가 시작하지 못하거나 예외로 죽으면 도구 호출이 막힌다(fail-closed). `block-destructive` 는 여전히 아무 파일도 dot-source 하지 않고, 디스패처는 그것을 부르는 쪽일 뿐이다.

## §2 입력 공유

디스패처가 stdin 을 한 번 읽어 `$global:KarinaHookStdin` 에 두고, 묶이는 스크립트는 그 변수가 있으면 그것을, 없으면 종전대로 `[Console]::In.ReadToEnd()` 를 읽는다. `[Console]::SetIn` 으로 다시 넣는 방법은 쓸 수 없다 — 묶이는 스크립트가 모두 `[Console]::InputEncoding` 을 설정하고, 그 setter 는 `Console.In` 을 OS 표준입력 핸들에서 다시 만들어 넣은 입력을 버린다. 표준입력 핸들을 바꾸는 방법(골든 러너의 방식)은 `Add-Type` 컴파일 비용이 매 호출에 든다. 공용 헬퍼 파일로 빼면 `block-destructive` 가 외부 파일에 의존하게 된다(`skills/DESIGN.md` 의 의도적 복제 ①).

- **디스패처는 끝날 때 그 변수를 지운다** — 골든 러너는 런스페이스를 재사용하므로, 남기면 뒤에 단독으로 부른 스크립트가 낡은 입력을 읽는다.
- **디스패처가 맨 앞에서 `InputEncoding`·`OutputEncoding` 을 UTF-8 로 정한 뒤 읽는다** — 종전에는 각 스크립트가 setter 뒤에 읽어 UTF-8 로 디코딩됐다. 디스패처가 먼저 읽으면서 setter 를 빼면 한글 입력이 콘솔 코드페이지로 읽혀 차단 판정의 입력이 달라진다.

## §3 출력 합치기와 종료 코드

스크립트마다 `[Console]::SetOut` 으로 stdout 을 받고 파이프라인 출력(`Write-Output`)도 함께 모은다. 판정은 스크립트 하나의 출력 전체로 한다 — Claude Code 가 hook 하나의 stdout 을 통째로 JSON 이거나 평문으로 읽기 때문이다. 전체가 JSON 객체면 그 `hookSpecificOutput.additionalContext` 를 받고(다른 필드는 버린다), 아니면 앞뒤 줄바꿈만 걷은 평문을 그대로 받는다. 스크립트마다 받은 것을 빈 줄 하나로 잇고 JSON 하나로 낸다. `hookEventName` 은 처음 낸 스크립트의 값이고, 없으면 입력의 `hook_event_name` 이다.

- **줄 단위로 자르지 않는다** — 2026-11-12 첫 판은 줄마다 Trim 하고 빈 줄을 끼워 이었다. 그러자 `session-context` 가 싣는 AGENTS.md 전문의 중첩 목록·표·코드 들여쓰기가 깨졌고, `{` 로 시작하는 평문 줄을 JSON 으로 읽었다.
- **평문은 SessionStart·UserPromptExpansion·UserPromptSubmit 에서만 싣는다** — 공식 hooks 문서상 평문 stdout 을 컨텍스트로 넣는 이벤트가 그것뿐이다(PostModelSwitch 는 묶음이 없다). PreToolUse·PostToolUse 의 평문은 단독일 때 transcript 에만 남았으므로, 묶음도 버린다.
- **stderr 는 스크립트마다 `[Console]::SetError` 로 받아 두었다가 끝에 순서대로 낸다 — 묶음이 `2` 로 끝나면 `2` 를 낸 스크립트의 것만 낸다** — exit 2 의 stderr 는 차단 사유로 Claude 에 가는데, 같은 묶음의 비차단 경고(`guard-bash` 의 외부 작업 경고)가 섞이면 차단 사유가 흐려진다. exit 0 의 stderr 는 Claude 에 가지 않는다. 합친 stdout JSON 은 `2` 여도 그대로 낸다 — 공식 문서 *"Exit 2 blocks even when your hook prints JSON … Claude Code still reads the JSON output fields, but they can't override the block"*.

- **앞 스크립트가 `2` 여도 뒤 스크립트를 돌린다** — 종전에는 같은 이벤트의 hook 이 모두 돌았다. 건너뛰면 뒤 스크립트의 이벤트 로그·경고 같은 부수 효과가 달라진다.
- **차단 묶음(`-Blocking`)** — `2` 가 하나라도 있으면 `2`, 아니면 비0 이 있으면 `1`, 아니면 `0`. 스크립트가 단독으로 실패했을 때처럼 `onFailure: block` 으로 막혀야 한다.
- **비차단 묶음** — `2` 는 그대로 `2` 이고, 그 밖의 비0·예외는 stderr 에 한 줄을 남기고 `0` 으로 낮춘다. Claude Code 는 `2` 가 아닌 비0 종료 코드(non-blocking error)의 stdout JSON 을 읽지 않아, 낮추지 않으면 한 스크립트의 실패가 같은 묶음의 다른 컨텍스트까지 버린다.
- **디스패처는 리터럴 `exit 2` 를 쓰지 않는다** — `hooks/evals/check-block-coverage.py` 는 리터럴 `exit 2` 가 있는 파일에서 차단 사유를 뽑는데, 디스패처에는 자기 차단 사유가 없다.

## §4 스크립트 사이의 격리

- **스크립트마다 위치를 시작 위치로 되돌린다** — `post-write-checks.ps1` 이 `Set-Location` 한다.
- **디스패처 변수는 `$hd` 접두를 쓴다** — `&` 로 부른 스크립트는 자기 스코프에 없는 변수를 부모 스코프에서 찾는다. 이름이 겹치면 스크립트가 대입 전에 읽는 값이 바뀐다. 매개변수 `$Blocking`·`$Scripts` 는 예외이고, 묶이는 스크립트에 그 이름이 없다.
- **스크립트 예외는 잡아서 `1` 로 센다** — 처리되지 않은 예외가 뒤 스크립트를 건너뛰게 두지 않는다.
- **프로세스 환경변수는 복원하지 않는다** — 묶이는 스크립트가 쓰는 것은 `warn-version-drift.ps1` 의 `GIT_TERMINAL_PROMPT=0` 하나이고, 뒤의 `session-context` 가 git 을 부를 때 인증 프롬프트를 끄는 쪽이라 해가 없다.
- **PowerShell 5.1 문법만 쓴다** — hook 셸은 pwsh 7 이 없으면 5.1 이다.

## §5 왜 묶는가 — 실측

여러 Claude Code 세션을 띄우면 도구 호출마다 hook 별로 pwsh 가 떠 CPU 를 먹었다. 2026-11-12, 다른 세션 6개가 도는 부하에서 BASE(08aad3c1 — 스크립트마다 pwsh)와 HEAD(묶음)를 같은 입력으로 교대 5쌍 쟀다. 지표는 도구 1회분 hook 프로세스의 CPU 합과 벽시계다(Pre·Post 단계 합, 단계 안은 BASE 병렬·HEAD 단일). 30회 실행 모두 exit 0 이고 stdout JSON 이 파싱됐다.

| 도구 | pwsh 수 | CPU 중앙값 (범위) BASE → HEAD | 벽시계 중앙값 (범위) BASE → HEAD |
|---|---|---|---|
| Bash | 4 → 2 | 6,797 (6,156–7,562) → 4,016 (3,719–4,375) ms · 59% | 3,386 (2,849–3,895) → 3,649 (3,446–4,276) ms · 108% |
| Edit | 4 → 2 | 6,250 (5,297–6,969) → 3,453 (2,984–3,719) ms · 55% | 3,470 (2,795–4,947) → 3,595 (3,208–8,060) ms · 104% |
| Skill | 3 → 1 | 5,219 (4,312–6,797) → 1,781 (1,266–2,203) ms · 34% | 2,073 (1,193–6,250) → 1,828 (1,096–6,627) ms · 88% |

병목은 pwsh 기동 CPU 다. 줄어든 CPU 를 없앤 기동 수로 나누면 Bash 2,781ms ÷ 2 ≈ 1,390ms · Edit 2,797 ÷ 2 ≈ 1,400 · Skill 3,438 ÷ 2 ≈ 1,720 으로 기동 하나 값이 세 도구에서 비슷하다. 빈 pwsh 기동의 CPU 를 따로 잰 값은 없어(같은 날 잰 것은 벽시계 1,452~3,968ms 뿐이다) 이 산술은 도구 간 일치로 갈음한 것이다. 벽시계는 단계 안 병렬이 순차로 바뀌어 Bash·Edit 에서 조금 늘었고(120% 안), 차단 묶음이 든 Pre+Post 의 HEAD 최대치는 8,060ms 로 timeout 60초에 멀다.

## §6 timeout 과 실행 시간 로그

비차단 묶음 timeout 은 묶음 안 스크립트의 종전 timeout 합으로 잡는다 — 이제 한 프로세스 안에서 차례로 돌고, Claude Code 는 timeout 에 걸린 hook 의 출력을 통째로 버린다. 2026-11-12 첫 판은 「합 이하」로 Skill 묶음 셋에 15초를 줘, 하나만 늦어도 셋의 컨텍스트가 모두 사라질 수 있었다. 차단 묶음은 종전처럼 60초다. `hook-event-log.ps1` 의 `slow` 줄은 「지금 − 프로세스 시작」이라, 묶음 뒤쪽 스크립트가 남기면 앞 스크립트가 쓴 시간도 들어간다. 그 값의 용도가 timeout 을 다시 정하는 것이고 timeout 이 이제 묶음 단위라 그대로 둔다.
