# `loop-continue` 판정 근거

> `loop-continue.ps1`의 주석이 가리키는 판정 근거다. 스크립트에는 각 자리에 이 문서의 절을 가리키는 1줄만 남겼다.

## §1 담당 조항과 설계

`skills/DESIGN.md` §5 의 **E12(자율 루프를 중간에 멈추지 않는다)** 를 담당한다. 형태 판정의 정본은 여전히 `implement/references/loop-stop-patterns.md` 이고, 이 hook 은 **그 문면이 놓친 정지 가운데 plan 에 미완 task 가 남은 것과, task 는 다 닫혔는데 4번 검증 기록이 없거나 낡은 것(§7)**에만 계속을 주입하는 2차 방어선이다.

- **transcript 를 읽지 않고 문면도 판정하지 않는다** — v1.225.0 에 제거된 `require-evidence` 가 두 가지를 다 했다. transcript 는 비동기로 쓰여 Stop 시점에 마지막 응답이 빠질 수 있고(공식 hooks 문서 `transcript_path` 항), 파싱 상한·tail 줄 수를 조정할 때마다 fail-open 결함이 새로 났다(대장 종결분 6건). 한국어 정지 문면은 어미 조합이 무한해 정규식이 수렴하지 않는다. 그래서 이 hook 은 **발동 마커 · plan.md 체크박스 · Stop 페이로드의 필드**만 입력으로 쓴다.
- **`decision:"block"` 이 아니라 `additionalContext` 로 계속시킨다** — 공식 문서가 「설계대로 동작하는 안내」에 권하는 형태이고, 같은 루프 보호(`stop_hook_active`·연속 8회 상한)를 받는다. 트랜스크립트에 hook 오류가 아니라 피드백으로 표시된다. 이 형태는 `exit 0` 이므로 `AGENTS.md` 「hook 출력 규약」의 「차단은 `exit 2` 하나, 그것을 내는 hook 은 넷」을 바꾸지 않는다.
- **출처**: Opus 5.5 프롬프팅 가이드 「무인 에이전트 실행」 — 텍스트로 끝난 턴을 완료의 증거가 아니라 보고로 보고, 체크리스트에 항목이 남아 있으면 그 항목을 적은 짧은 메시지로 계속시키며, 같은 작업에 대한 자동 계속은 두세 번에서 멈춘다.

## §2 주입 조건과 상한

주입은 다섯 조건이 **모두** 참일 때만 한다.

1. 이 세션에 발동 마커가 있다(§6)
2. `stop_hook_active` 가 거짓이다 — 이미 이 hook 때문에 계속된 turn 이면 다시 밀지 않는다. 그래서 규약이 지목한 정당한 정지(승인 대기 등)와 사용자 중단(주입 문구가 둘 다 유지할 정지로 적는다)은 **1회 재촉**으로 끝난다: 모델이 막힌 이유를 말하고 멈추면 그 turn 은 `stop_hook_active` 가 참이다
3. `background_tasks` 가 비어 있다 — 모델이 시작한 백그라운드 명령·서브에이전트가 돌고 있으면 turn 종료는 대기이지 정지가 아니다(가이드: 그 작업이 끝나기를 기다린다)
4. `cwd` 에서 찾은 plan(§4 — 상위 폴더 포함 · 다른 레포 제외)에 미완 task 가 1개 이상이다 — 0개면 §7 의 회차 끝 판정으로 간다
5. **같은 미완 집합**에 대한 이 세션의 주입 횟수가 `$MaxPerSet`(2) 미만이다 — 집합은 미완 ID 목록의 해시로 가른다. 한 task 를 끝내면 집합이 바뀌어 다시 주입할 수 있고, 진전 없이 같은 자리에서 멈추면 두 번 뒤에는 침묵한다. 가이드의 「두세 번 후 중단」이고, 실제로 막힌 실행을 사람이 보게 하는 장치다

## §3 fail-open 은 침묵이다

stdin 파싱 실패 · `session_id` 부재 · `cwd` 부재 · plan 을 못 찾음 · plan 읽기 실패 · 상태 파일 쓰기 실패는 전부 **아무것도 출력하지 않고 `exit 0`** 이다. 이 hook 이 틀려서 치르는 비용은 비대칭이다 — 잘못 주입하면 사용자가 멈춘 작업을 밀어붙이고, 잘못 침묵하면 문면만 있던 종전 상태로 돌아갈 뿐이다. 카운터를 쓰지 못하면 주입도 하지 않는 것도 같은 이유다 — 상한을 셀 수 없는 주입은 상한이 없는 주입이다.

## §4 미완 판정식과 plan 탐색

**plan 탐색** — `session-context.ps1` 과 같은 `Find-PlanFileUpwards` 로 찾는다. 규칙(후보 3종 · 8단계 · `.git` 폴더·파일과 `.claude` 폴더에서 멈춤 · 라벨)의 근거는 `session-context-rationale.md`「§5 ---- plan 탐색: 상위 탐색과 레포 경계」가 정본이다. 이 hook 에서 경계가 특히 중요한 이유는 찾은 plan 의 미완 task 로 「계속」을 주입하기 때문이다 — worktree 세션이 부모 레포 plan 을 잡으면 그 세션과 무관한 task 를 이어 하라고 밀게 된다. 주입 문구는 찾은 plan 의 라벨을 적는다(`docs/plan.md` · 위에서 찾았으면 전체 경로).

**미완 판정식** — `session-context.ps1` 의 미완 계수식(`$planBulletRx` + `\[[ /~-]\][ \t]*\**T\d+`)에 이름 그룹 ID 캡처(`(?<id>T\d+(?:-\d+)?)`)만 더한 식이다. `$planBulletRx` 가 번호 그룹을 가져 숫자 그룹을 쓰면 ID 가 아니라 불릿을 집는다. 템플릿 정본(`plan/references/plan-template.md` 「작업 단계」)의 `- [ ] **T1-1**` 과 구형 `- [ ] T1:` 을 함께 받는다. **완료는 `[x]`·`[X]` 뿐이고, 작성 게이트의 마커 집합(`guard-write.ps1` `$planTaskRx` — `[ ]`·`[/]`·`[x]`·`[X]`·`[-]`·`[~]`)의 나머지 넷은 전부 미완이다** — 종전 식은 `[ ]`·`[/]` 만 미완으로 세어 `[-]` 만 남은 task 가 계속 주입을 빠져나갔다(2026-11-06 임시 레포 실측). 집합 밖 글자(`[?]` 등)는 작성 게이트가 체크박스로 보지 않는 것과 같은 이유로 세지 않는다(`write-gate-rationale.md`).

**코드 펜스 안은 세지 않는다** — 판정 전에 `$planFenceRx` 로 펜스 구간을 지운다. 규칙은 `skills/plan/scripts/check-plan.ps1` 의 줄 단위 펜스 판정과 같다: 들여쓰기 0~3칸의 ```` ``` ````·`~~~`(3개 이상)로 열고, 여는 줄과 첫 글자가 같은 3개 이상 펜스 줄에서 닫히며(길이·뒤 글자 무관), 닫히지 않으면 끝까지 펜스다. `\r?$` 는 CRLF plan 에서 펜스 줄 끝을 맞추려는 것이다 — 없으면 CRLF 에서 펜스 안 체크박스가 샌다(실측). plan 에 서식 예시를 펜스로 실으면 그 안의 `- [ ] **T9-1**` 이 미완으로 주입되던 경로를 닫는다.

**사본이다** — `Find-PlanFileUpwards`·`$planBulletRx`·`$planFenceRx` 는 두 hook 에 같은 글자로 있고 `evals/check-harness-consistency.py` 의 「복제 사본 동기」 축이 일치를 잰다(공용 `.ps1` 은 차단 hook 보호 목록을 넓혀 만들지 않는다 — `session-context-rationale.md` §5). 판정식의 뒷부분은 두 hook 에서 모양이 갈려(계수 ↔ ID 캡처) 기계 대조 밖이라 **두 hook 의 근거 문서가 서로를 가리킨다**(이 절 ↔ `session-context-rationale.md`「§5-1 task 계수식」) — 한쪽만 고치면 세션 시작 안내와 계속 주입이 서로 다른 미완 수를 보게 되고, 그것은 두 hook 의 불릿 집합 골든이 각각 잡는다.

## §5 상태 파일과 정리

`~/.claude/.state/loop-continue/` 아래 세션별 마커 `<session_id>.active` 와 집합별 카운터 `<session_id>.<집합 해시 12자>.count` 를 둔다. 세션이 끝나도 지우지 않는다 — 다른 세션의 `session_id` 와는 겹치지 않아 해가 없고, `session-end-cleanup.ps1` 은 「다른 책임을 얹지 않는다」고 스스로 범위를 닫았다. 30일 지난 파일은 **세션 시작에 한 번** `session-context.ps1` 이 걷는다(`session-context-rationale.md` §38 — 2026-10-08 전에는 마커를 쓸 때마다 이 hook 이 걷었다).

## §6 발동 마커의 두 경로

마커는 **`karina:implement` 가 이 세션에서 발동했다**는 사실만 기록한다.

- **`PreToolUse` · `tool_name` = `Skill`** — 모델이 Skill 도구로 스킬을 부를 때다. `tool_input.skill` 이 `implement` 또는 `karina:implement` 이면 마커를 세운다
- **`UserPromptExpansion`** — 사용자가 `/karina:implement` 를 직접 쳐서 Skill 도구를 거치지 않는 경로다(공식 문서: 「typing `/skillname` directly bypasses `PreToolUse`」). `command_name` 에 플러그인 접두가 붙는지는 문서에 없어 두 형태를 다 받는다. **hooks.json matcher 도 정규식 — `^(karina:)?implement$` 블록(직접)과 `^(karina:)?(chain-)?plan$` 블록(디스패처로 `record-work-start` 와 함께)으로 둔다** — 글자·`|` 만으로 쓰면 「정확 일치 목록」으로 판정돼(hooks 문서 「Matcher patterns」) 접두 형태가 스크립트에 닿기 전에 떨어진다(완료 리뷰 BLOCKER)
- **`karina:plan` 이 발동하면 마커를 지운다** — 같은 세션에서 새 계획을 쓰기 시작하면 plan.md 의 미완 task 는 **승인 전 계획**의 것이다. 마커가 남아 있으면 승인 대기 turn 에 「이어서 진행하라」를 주입해 승인 없는 실행을 부추긴다. 승인 뒤 `karina:implement` 가 다시 발동하면 마커가 다시 선다
- **`karina:chain-plan` 이 발동해도 마커를 지운다** — 체인 코디네이터는 계획을 실행하지 않고, 워커가 같은 폴더의 `plan.md` 를 고치는 동안 미완 task 가 늘 보인다. 이 세션에서 앞서 `karina:implement` 를 돌렸으면 마커가 남아, 코디네이터가 백그라운드 대기 없이 turn 을 끝내는 자리(승인 화면·보고)마다 「이어서 진행하라」 가 주입됐다(2026-11-20 체인 plan 4 골든 재현)

- **마커는 발동 때 `cwd` 의 plan 정체(`> 요구:` 줄과 `> BASE:` 줄의 해시)를 둘째 줄에 적고, Stop 때 읽은 plan 의 정체가 다르면 침묵한다** — 체인 워커 둘이 같은 체크아웃에서 돌면 다른 워커가 `plan.md` 를 자기 계획으로 바꾸는데, 이 세션의 마커가 남아 남의 미완 task 28개로 「이어서 진행」 을 두 번 주입했다(2026-11-21 Karina 체인 run_994f7987 plan 3 · plan 4). 정체를 못 적은 마커(발동 입력에 `cwd` 가 없거나 plan 이 없거나 두 줄이 다 없음 · 옛 형식 마커)는 지금처럼 판정한다 — 마커가 그대로 남는 세션에서 판정을 끄면 안전망이 꺼진다(골든 LC-identity·LC-identity-same·LC-identity-compat).

## §7 회차 끝 판정

미완 task 가 0 이면 침묵하던 자리에서, 회차 끝 단계가 남았는지를 4번 검증 기록으로 본다(`Get-FinalCheckGap`). 2026-11-19 v3.38.0 회차가 리뷰 반영 커밋 뒤 4번을 다시 돌리지 않고 완료를 선언했는데, 미완이 0 이라 이 hook 은 침묵했다(`implement/references/final-review.md`「완료 순서」 는 문서만 바꾼 커밋도 재실행을 요구한다).

**주입 조건** — §2 의 1~3 에 더해 전부 참일 때다.

- plan 에 닫힌 task 가 1개 이상이고 승인 표지(`> 승인: <날짜>`)가 있다 — 표지가 없으면 초안이라 회차가 아니다
- `> 요구:` 줄에 「코디네이터 인터뷰 경유」 가 없다 — 중계 워커는 4번 뒤에 인계 절 커밋을 남기고 코디네이터가 따로 검증하므로, 넣으면 워커마다 거짓 주입이 난다
- `## Progress Log` 절(코드 펜스 밖)에 `4번 검증: <40자 SHA>` 줄이 없거나, 마지막 그 줄의 SHA 가 HEAD 가 아니고 `git diff --name-only <SHA>..HEAD` 에 plan 파일과 §8 의 선언 경로를 뺀 경로가 있다 — 절과 형식을 좁히지 않으면 Goal·Investigation Log 의 서식 예시를 SHA 로 집는다. plan 경로는 `git rev-parse --show-prefix` 로 레포 루트 기준으로 바꿔 대조한다

**상한** — 같은 HEAD 에 `$MaxPerSet`(2)회다. 집합 키는 미완 ID 대신 HEAD 다.

**판정 불가는 침묵이다(§3)** — git 밖 폴더 · HEAD 를 못 얻음 · diff 실패 · git 호출이 3초 상한(`timed-git.ps1`)을 넘김. Stop 디스패처는 응답 언어 hook 과 10초를 함께 쓴다.

**남는 거짓 주입 둘** — 회차가 끝난 뒤 같은 세션에서 한 회차 밖 커밋(마커는 `karina:plan` 발동이나 세션 종료까지 남는다 — §6) · 4번은 통과했으나 clean 이 아니어서 줄을 남기지 않고 push 도 하지 않는 회차. 회차 안팎을 가를 신호가 plan 에 없어(완료 시각 줄은 재실행을 빼먹은 회차도 채웠다) 상한 2회와 주입 문구의 「회차 밖이면 무시」·정지 유지 구절로 받는다. push 직전 재검증은 통과하면 같은 줄을 남긴다(`implement/references/push-flow.md`「push 전 확인」). 버전 파일만 바꾼 커밋은 가르지 않는다 — 버전 커밋은 회차의 마지막 task 라 4번보다 앞이다.

## §8 Gate 재사용 경로

**4번 검증 줄 뒤의 변경에서 그 레포 `AGENTS.md` 의 `Gate 재사용 경로` glob 에 걸리는 파일은 뺀다(`Get-GateReuse`).** 종전에는 문서만 바꾼 커밋에도 재실행을 주입해, 리뷰 뒤 기록 커밋마다 전체 검증을 다시 돌았다(사용자 답 2026-11-20 「면제한다」 — `docs/decisions.md`). 면제 집합의 정본은 `skills/implement/references/push-flow.md`「push 전 확인」 이고 이 hook 은 그 집합에서 plan 파일과 선언 경로만 기계로 뺀다(버전 파일 집합은 §7 대로 가르지 않는다).

- **선언은 plan 폴더에서 git 최상위까지 올라가며 처음 만난 `AGENTS.md` 의 `- **Gate 재사용 경로**:` 줄이고, glob 은 그 줄의 백틱 스팬이다** — `skills/plan/scripts/check-plan.ps1` 의 `AGENTS.md` 탐색과 같은 순서다. 줄이 없거나 백틱 glob 이 하나도 없으면(「없음」 등) 선언 없음이라 종전대로 전부 센다.
- **glob 대조는 git 에 맡긴다 — 기존 `git diff --name-only` 호출에 `-- :/ :(exclude,glob)<g>…` pathspec 을 붙이고 작업 폴더를 그 `AGENTS.md` 폴더로 둔다** — 선언이 「이 `AGENTS.md` 폴더 기준 · `**` 는 하위 전체」 라(`skills/AGENTS-BOUNDARY.md` 템플릿) git 의 `:(glob)` 규칙과 같고, hook 안에 glob 을 구현하면 `skills/chain-plan/scripts/run-verify.py` 의 구현과 갈릴 사본이 하나 더 생긴다. git 호출 수는 늘지 않는다(`rev-parse` 에 `--show-toplevel` 인자 하나, `diff` 에 pathspec).
- **확장자(`.md`·`.txt`)로는 빼지 않는다** — 문서가 빌드 입력·실행 자산인 레포가 있다(Karina 의 `include_str!` · 이 하니스의 스킬 문면 — `skills/chain-plan/references/run-verify-rationale.md`). 이 하니스 `AGENTS.md` 는 그 줄을 선언하지 않아 여기서는 문서 커밋도 계속 주입한다.
- **선언 glob 이 검증 매핑 경로와 겹치는지는 재지 않는다** — 겹치지 않게 선언하는 것이 그 레포의 책임이고(`skills/AGENTS-BOUNDARY.md`), 겹침 판정 명령은 문면(`push-flow.md`)이 `skills/chain-plan/references/continuation.md`「코디네이터 검증」 을 가리킨다.
- **잘못된 pathspec 으로 `git diff` 가 실패하면 §3 대로 침묵한다** — 선언을 읽을 수 없는 경우(파일 읽기 실패)는 선언 없음으로 본다.

## §9 넘김 사유 없는 남은 이슈

**회차 끝에 `## Deferred / Follow-up` 에 넘김 사유 없는 항목이 남았으면 완료가 아니라고 보고 계속을 주입한다.** 판정은 `scripts/deferred-handoff.ps1` 의 `Get-UnhandedDeferred` 하나이고, 회차 끝 증거 대조(`skills/plan/scripts/check-plan.ps1 -Base` 의 `remaining-issue`)가 같은 함수를 dot-source 한다 — 두 자리에 규칙을 따로 두면 한쪽만 고쳐 갈린다. 사용자 관측(2026-11-21): 검증하지 않은 것·빼먹은 것·하지 않은 작업이 「남은 이슈」 로 실려 완료로 보고됐다. 남은 이슈로 넘길 수 있는 범주의 정본은 `skills/plan/references/deferred-rules.md` 다.

- **위반 다섯** — 마커 없음(`no-marker`) · `[미판정]`(`unjudged`) · `[등재]`·`[미등재:대장 없음]` 인데 본문(이어지는 들여쓴 줄 포함)에 `넘김 사유 ①`·`②`·`다른 종류의 세션`(콜론 허용)이 없음(`no-reason`) · `[다음 회차]` 에 `(근거:` 없음(`no-basis`) · `[다음 회차]` 가 승인 표지의 `다음 회차 <N>` 을 넘음(`over-approved` — N 이 없으면 0). 그 밖의 `[미등재:<사유>]`·`[1회 실패]`·「없음」 은 통과다 — 버린 지적의 사유 진위는 문면으로 가를 수 없어 완료 리뷰가 본다.
- **`[다음 회차]` 는 승인 표지의 수로 고정한다** — `plan.md` 는 gitignore 인 레포가 있어 BASE 판을 읽을 수 없고, 승인 표지는 plan 스킬이 승인 직후 쓰는 줄이라 구현 중에 붙인 항목과 가른다.
- **주입 조건은 §7 의 회차 끝 조건(승인 표지·닫힌 task·중계 제외)을 공유하고, 4번 검증 공백이 있으면 그 안내가 먼저다** — 한 번에 두 안내를 내면 순서가 흐려진다. 상한은 §2 와 같은 2회이고 집합 키는 걸린 항목 줄이다.
- **헬퍼를 읽지 못하면 침묵한다(§3)** — `check-plan` 은 `skip remaining-issue no-helper` 줄을 낸다.
