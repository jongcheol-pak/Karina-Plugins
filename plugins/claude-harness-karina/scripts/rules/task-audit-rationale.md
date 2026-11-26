# `guard-task-audit` 판정 근거

> `guard-task-audit.ps1`(`guard-bash.ps1` 이 dot-source 하는 커밋 시점 검사 `warn-task-audit`)의 판정 근거다. 줄 형식의 사용자 쪽 정본은 `skills/AGENTS-BOUNDARY.md` 의 `Test (감사)` 줄이다.

## §1 왜 커밋 자리인가

레포가 문면으로 「pub 항목을 더한 task 는 `-- doc_audit` 도 돌린다」를 적어 두었는데도, Karina 회차 둘(2026-10-08 픽셀 오피스 · 2026-11-02 에이전트 커서)이 필터 테스트만 돌려 task 를 닫았다. 감사는 회차 끝 무인자 실행에서야 빨개졌다. task 검증은 모델이 명령을 고르는 자리라 문면만으로는 강제되지 않는다. task 마다 반드시 지나는 기계 자리는 완료 커밋(`{유형}: T<N> — …`)이고, 그 본문에 검증 결과를 싣는 것이 implement 규약이다. 그래서 「본문에 감사 명령이 있는가」를 커밋 자리에서 잰다.

## §2 왜 경고가 기본이고 RED 줄 누락만 차단인가

차단(`exit 2`)을 내는 hook 은 넷으로 묶여 있고, 새 차단을 들이지 않는 것이 하니스 규약이다(`AGENTS.md` DO NOT). 사용자도 처음에는 경고를 골랐다. **예외는 RED 줄 누락 하나다(§7 · 2026-11-27 사용자 지시 — 안전 임계 hook 의 허용 종류 ⑤ 「사용자 지시의 비안전 차단 신설」, `../../docs/harness-conventions.md` 「검증 명령 상세」)** — 경고가 커밋 뒤에 읽혀, Karina plan 9 회차가 T2·T3·T6·T12 의 RED 줄을 빠뜨린 채 커밋하고 보충 빈 커밋 4건과 T12 변이 RED 재측정 2회를 치렀다(reflect 95bff2f0). RED 줄은 구현 전 실패 출력이라 커밋 뒤에는 다시 얻으려면 구현을 되돌려야 해, 커밋 자리에서 막아야 비용이 0 이 된다. 나머지 경고(감사 명령·화면·Acceptance·untracked)는 커밋 뒤에도 명령을 돌려 보충할 수 있어 경고로 둔다. PreToolUse 경고는 커밋이 실행된 뒤에 읽히므로, 경고 문구는 「명령을 돌린 뒤 `git commit --allow-empty` 보충 커밋에 결과를 남기고, 실패하면 수정 커밋」을 안내한다. 이 경고는 implement 커밋 절의 시크릿 경고 정지와 다르다. 커밋된 것에 시크릿이 없으니 멈출 이유가 없다.

## §3 무엇을 「이번 커밋의 변경」으로 보는가

PreToolUse 시점에는 같은 명령의 `git add` 가 아직 돌지 않아, `--cached` 만 보면 `git add … && git commit`·`git commit -a`·`git commit -- <경로>` 를 놓친다. 그래서 같은 명령을 읽어 커밋에 들 변경을 가른다(`Get-TaskAuditScope`). 커밋 인자 해석은 `guard-commit-comments.ps1` 의 `Get-CommitCommentArgs` 를 호출 시점에 쓴다 — 같은 갈래를 두 검사가 따로 두면 한쪽만 고쳐진다.

- **`git add -A`·`--all`·`-u`·`.` 또는 `git commit -a` 면 `git diff HEAD`(인덱스와 작업 트리) 전체와, add 면 규칙 경로의 미추적 파일**
- **`git commit [--] <경로…>` 면 그 경로의 `git diff HEAD` 만** — git 은 경로를 주면 기본이 `--only` 라 다른 경로의 staged 는 커밋에 들지 않는다(병행 세션 커밋이 이 꼴이다 — 레포 `docs/conventions.md` 2026-09-10). `-i`/`--include` 면 staged 를 더한다.
- **`git add <경로…>` 면 staged 와 그 경로의 `git diff HEAD`·미추적 파일**, add 도 경로도 없으면 staged 만.

셈은 늘 규칙 경로(pathspec) 안의 파일만이고, 작업 트리 쪽과 staged 쪽에 같은 파일이 있으면 작업 트리 쪽(staged 를 품는다)으로 한 번만 센다. 미추적 파일 상한은 `guard-commit-secrets` 와 같은 50개·파일당 1MB 이고, 넘으면 경고 줄에 「일부만 셈」을 붙인다. 커밋 인자 해석 함수가 없으면(파일 부재) 종전처럼 `git diff HEAD` 전체로 넓게 센다. HEAD 가 없는 초기 저장소면 `--cached` 로 대신한다.

종전 판은 미스테이징 변경까지 `git diff HEAD` 로 세고 그 과경고를 「경고 한 번의 비용」으로 받아들였다. 실제 비용은 그보다 컸다 — 2026-11-20 Karina plan 11 의 T13 문서 커밋(`git add plan.md docs/…`)이 작업 트리의 T15 RED 시험 3개를 「증가 3줄」로 경고받아, 감사(`test_doc_audit` 85초)를 다시 돌리고 빈 보충 커밋 1개를 남겼다.

순증은 일치하는 `+` 줄 수에서 일치하는 `-` 줄 수를 뺀 **전체 합산**이다. 파일 사이 이동(A 에서 지우고 B 에 더함)에 경고하지 않으려는 선택이다. 대가로 서로 다른 항목이 두 파일에서 상쇄되는 경우는 놓친다. 그 경우는 회차 끝 전체 테스트가 잡는 기존 경로로 돌아간다.

## §4 「본문에 명령이 있다」의 경계

CR(-F 파일의 CRLF 줄 끝)을 걷고 공백을 정규화한 메시지에서 명령(또는 `또는:` 명령)이 나오고, 그 뒤가 줄 끝·백틱·따옴표이거나 공백 다음 토큰이 리다이렉션·연결 기호(`>`·`2>&1`·`|`·`;`·`&&`) 또는 `→` 일 때만 충족이다. 뒤에 아무 토큰이나 허용하면 대안 `cargo test` 가 `cargo test --lib -- x`·`cargo test computer_guard` 같은 필터 실행에 맞아, 이 검사가 막으려는 바로 그 꼴이 통과한다. 여러 `-m` 은 이어 붙여 읽는다(`Get-CommitMessage`). 메시지를 못 읽는 커밋(변수 `-m` 등)은 침묵한다. 같은 조건에서 `require-task-checkbox` 가 이미 heredoc 을 쓰라고 경고한다.

**감사 명령이 `cargo test … -- <필터>` 하나로 끝나면, 본문의 `cargo test <플래그> -- <F>` 에서 `--` 앞의 대상 선택 플래그 집합이 감사 명령과 같고 `F` 가 감사 필터의 부분 문자열일 때도 충족이다(`Test-TaskAuditFilterCovered`).** 대상 선택은 `--lib`·`--bins`·`--tests`·`--examples`·`--benches`·`--all-targets`·`--doc`·`--workspace` 와 값을 받는 `--bin`·`--test`·`--example`·`--bench`·`-p`/`--package <이름>` 이고(`--bin=x` 꼴 포함 · 순서 무관), 그 밖의 플래그(`--no-fail-fast`·`-j`·`--features` 등)는 실행 방식이라 무시한다. 앞부분을 글자 그대로 대조하던 판은 레포 규약이 강제하는 `cargo test --lib --no-fail-fast -- _audit` 를 덮음으로 세지 못해, 2026-11-14 Karina 회차 T2·T4·T7 에 빈 보충 커밋 3건이 났다. 무시 쪽을 고른 것은 무시할 실행 플래그 목록을 두면 새 실행 플래그마다 거짓 경고가 나기 때문이고, 그 대가로 컴파일 범위를 바꾸는 플래그로 돈 실행도 덮음으로 셀 수 있다 — 비차단 경고 하나가 빠지는 것이다. 앞부분은 명령 구분자(`&&`·`||`·`;`·`|`·`>`·`→`)를 넘어 잡지 않는다 — `cargo test --lib && cargo test -- x` 의 `--lib` 은 뒤 실행의 것이 아니다. libtest 필터는 테스트 경로의 부분 문자열 대조라, `F` 를 품은 감사 테스트는 그 실행에서 함께 돈다 — 방향은 실행 필터 ⊂ 감사 필터다(`doc_audit` ⊂ `test_doc_audit`). 2026-11-13 Karina 회차는 `cargo test --lib -- doc_audit` 실행 출력에 `test_doc_audit` 가 함께 통과했는데도 그 감사 누락 경고를 T2·T4·T5 에서 받아, 빈 보충 커밋 3건과 손으로 옮긴 수치를 고친 정정 커밋 1건(`187067d` → `9b808fe`)이 생겼다. 경계는 위와 같고 필터 뒤에 다른 인자가 붙으면(`--exact` 포함) 대조하지 않는다 — `--exact` 는 부분 문자열 대조를 끄고, 다른 인자의 뜻까지 해석하지 않는다. `또는:` 대체 명령은 필터 없는 전체 실행이라 이 판정을 걸지 않는다.

**같은 `AGENTS.md` 에 `Test (task)` 템플릿이 있으면, 본문의 그 명령 실행에서 뽑은 필터도 같은 포함 판정(필터 ⊂ 감사 필터)에 넣는다(`Get-TaskAuditTaskTemplate`).** 템플릿의 첫 `<…>` 자리 앞 토큰이 접두이고, 접두 뒤 `<대상` 으로 시작하는 자리(`<대상>`·`<대상…>` — 정본 서식 `skills/AGENTS-BOUNDARY.md`) 앞의 `<…>` 자리 수만큼 본문 토큰을 건너뛴 나머지(`-` 로 시작하지 않는 것)가 필터다. `<…>` 는 안의 공백까지 한 자리로 센다. 출력 파일 같은 앞 자리를 필터로 세면 그 이름이 우연히 감사 필터에 들 때 통과하고, `<대상` 자리가 없는 템플릿은 필터를 가를 근거가 없어 이 경로를 걸지 않는다. 경계(줄 끝·백틱·따옴표·리다이렉션·연결 기호·`→`)는 위 cargo 판정과 같다. **대상 선택 플래그는 보지 않는다** — 템플릿은 레포가 task 검증용으로 선언한 명령이라 어느 대상을 도는지는 레포가 정하고, Karina `docs/test-task.py` 는 `cargo test --no-fail-fast -- <필터…>` 로 lib·bin 을 함께 돈다. 2026-11-19 Karina 체인 run_c5849ef7 plan 9 는 `python docs/test-task.py <출력> <대상…> _audit every_child_process_hides_its_console` 로 `doc_audit` 를 이미 돈 완료 커밋에서 이 경고를 T1·T3·T4·T6·T8 다섯 번 받아, 감사를 다시 돌리고 빈 보충 커밋 5개를 남겼다.

## §5 어느 `AGENTS.md` 인가 · 깨진 줄

커밋 폴더(`Resolve-GitCommitDir`)에서 git 최상위까지 올라가며 처음 만난 `AGENTS.md` 하나를 읽는다. `check-plan` 의 `Plan check` 탐색과 같은 기준이고, 모노레포 하위 폴더의 `AGENTS.md` 를 읽게 된다. diff 와 경로(pathspec)는 그 `AGENTS.md` 폴더 기준이다(경로를 생략하면 `.`).

증가 정규식이 없거나 컴파일되지 않는 줄은 침묵하지 않고 「규칙을 읽지 못함」으로 알린다. 침묵하면 줄을 망가뜨리는 것이 검사를 끄는 수단이 된다(`stale-docs-rationale.md` 의 fail-closed 와 같은 취지).

**완료 커밋 제목은 하위 ID(`T1-2`)까지 읽어 경고와 보충 커밋 제목에 그대로 쓴다** — 제목 정규식은 require-task-checkbox 와 같은 사본이다(`bash-guard-rationale.md` §15).

**git 이 상한 안에 답하지 않으면 감사 누락 검사를 건너뛰고 한 줄로 알린다** — 감사 누락은 경고 검사라 막지 않는다(RED 줄 차단도 그 git 이 답하지 않으면 경고로 내린다 — §7). 커밋 경로 git 의 상한·캐시는 `bash-guard-rationale.md` §18 이 정본이다.

## §6 감사 줄 파서는 `comment-lines.ps1` 에 있다

**`Test (감사)` 줄 파서(`$script:TaskAuditLineRx`·`Get-TaskAuditRules`)는 `comment-lines.ps1` 에 두고 이 검사가 그것을 쓴다.** 새 주석 게이트(`comment-gate-rationale.md` §3 doc 묶음 ①)도 같은 파서로 감사 대상 doc 을 통과시키는데, 종전에는 파서가 이 파일에 있어 `comment-lines` 가 이 파일을 dot-source 했다. 그래서 이 파일이 없거나 깨지면 감사 규칙이 빈 채로 남아, 감사가 요구하는 doc 주석까지 막혔다 — 비안전 차단의 판정 실패가 막는 쪽으로 떨어지는 fail-closed 였다(2026-11-13 하니스 검토 — 오탐 수정). 차단 게이트가 쓰는 파서를 차단 게이트 쪽 라이브러리에 두면 그 의존이 사라진다.

**이 검사는 파서를 호출 시점에만 부른다** — 커밋 명령의 라이브러리 로드 순서가 secrets → stale-docs → task-audit → commit-comments 라, 파일 머리에서 부르면 뒤의 `guard-commit-comments.ps1` 이 `comment-lines.ps1` 을 다시 불러 이중 로드가 된다. 검사 호출 때는 넷 다 로드된 뒤라 이미 정의돼 있다. 그래도 없으면(파일 부재·로드 실패) 경고 한 줄을 내고 통과한다(fail-open — 감사 누락은 경고 전용이다).

## §7 RED·화면·Acceptance 판정 줄도 완료 커밋에서 대조한다

회차 끝 증거 대조(`check-plan.ps1 -Base`)는 `[x]` task 마다 그 커밋 본문에 RED 줄(Files 줄에 `(RED)` 가 있으면)과 화면 판정 줄(`- **화면**:` 줄이 있으면)과 Acceptance 판정 줄(항목 수만큼)이 있는지 본다. 그것이 회차 끝에만 돌아, 2026-11-20 Karina plan 11 은 비서식 화면 줄(`화면(verify-karina):`)과 판정형 task 의 RED 누락 9건을 마지막에 받고 빈 보충 커밋 5개를 남겼다. task 마다 반드시 지나는 기계 자리가 완료 커밋이라(§1) 같은 대조를 그 자리에서 낸다 — RED 줄 누락은 차단, 나머지는 비차단 경고다(§2).

- **RED 줄 누락은 `[HARNESS] BLOCKED: 완료 커밋에 RED 줄이 없습니다 — T<N> …` 로 막고, 같은 결과의 다른 누락 줄을 함께 싣는다 — 단 `plan.md` `> BASE:` 이후 log 를 읽었을 때만이다** — BASE 줄이 없거나 자리표시자이거나 git 이 실패·시간 초과면 앞 커밋 본문의 RED 줄을 확인하지 못해, 막으면 판정 실패가 막는 쪽으로 떨어진다(fail-closed). 그때는 종전대로 경고다(골든 TE-redblock-nobase·TE-redblock-nobaseline). 판정 정규식은 그대로라 `RED: 미확인 — <사유>` 도 통과다(TE-redunverified). 회차 전 untracked 경고와 합칠 때도 차단을 잇는다(TE-redblock-untracked) — 합치는 자리가 결과를 비차단으로 다시 만들면 차단이 사라진다.

- **대상은 하위 ID 없는 `T<N>` 완료 커밋이고, `AGENTS.md` 폴더의 `plan.md` 에서 `### T<N>.` 블록을 읽는다** — 하위 커밋(`T3-1`)마다 재면 마지막 하위 커밋에 둘 기록을 앞 커밋에서 경고한다. `plan.md` 나 블록이 없으면 침묵한다. 감사 규칙(`Test (감사)`) 유무와 상관없이 돈다 — 감사 줄 없는 레포가 더 많다.
- **증거는 이번 메시지와 `plan.md` `> BASE:` 이후(`BASE..HEAD`)의 같은 `T<N>` 커밋 본문이다 — 다른 커밋의 지목 줄 `화면: T<N> …` 은 받지 않는다** — `check-plan -Base` 가 같은 `T<N>` 커밋 본문으로 재므로 같은 기준이어야 회차 끝 위반과 맞는다. BASE 를 못 읽으면 메시지만 본다. 지목 줄은 화면 판정을 묶음 커밋으로 미루던 시절의 서식이고, 화면 판정이 task 단위로 바뀌면서(v3.48.0 · `../../skills/implement/references/screen-scenarios.md`「화면 시나리오 실행」) 판정을 task 밖으로 미루는 길이라 걷었다(골든 TE-tagged).
- **판정 정규식은 `check-plan.ps1` 의 사본이다** — 그 스크립트는 `exit` 하는 독립 실행이라 dot-source 할 수 없다. 두 곳이 갈리지 않게 골든 「사본 정합」 케이스가 같은 커밋 이력을 두 검사에 넣어 같은 판정이 나는지 잰다. `RED: 미확인 — <사유>` 는 check-plan 이 위반이 아닌 note 로 다루므로 여기서도 통과다.
- **묶음 대기 줄(`화면: 묶음 대기 — …` · `화면: T2~T6 묶음 …`)은 화면 판정이 아니다 — 판정 줄이 없는 다른 완료 커밋과 같이 「화면 판정 줄 없음」 을 경고한다** — v3.47.0 까지는 이 줄에 묶음 안내 한 줄만 냈으나(2026-11-21 Karina 체인 run_994f7987 plan 3 — 거짓 경고 10회), 화면 판정이 task 단위로 바뀌어 미룰 묶음이 없다(골든 TE-bundle).
- **화면 판정이 없을 때 메시지에 `화면…:` 꼴 줄이 있으면 그 줄을 인용해 기대 서식을 보인다** — 비서식 줄은 기록할 뜻은 있었는데 서식만 어긋난 것이라, 무엇을 고칠지 보이는 것이 경고의 쓸모다.
- **`- **Acceptance**:` 줄이 있는 task 는 본문의 `Acceptance: <항목> — <판정>` 줄 수가 그 줄의 항목 수보다 적으면 「Acceptance 판정 줄 <있음>/<항목 수>」 를 경고한다 — check-plan 의 `acceptance-evidence` 사본이다(항목 셈: 백틱 스팬을 한 글자로 · 괄호 안 제거 · ` · ` 분할 · 문면은 대조하지 않는다 · 골든 TE-accept · 사본 정합)** — RED 줄만 커밋 때 잡히고 Acceptance 줄은 회차 끝에만 재던 탓에, 2026-11-23 Karina 세션 46c9c1b1 plan 4 회차가 T1·T2·T6·T8 의 누락을 회차 끝 `acceptance-evidence 1/2` 로 받아 재측정 75초와 빈 보충 커밋 4개를 남겼다. **check-plan 과 같게 본문 중 하나라도 `검증 결과`·`검증:` 이 있을 때만 잰다** — check-plan 은 증거 없는 task 를 `no-commit-evidence` 로만 내고 판정 줄을 세지 않아, 증거 없는 중간 커밋에서 세면 회차 끝 판정과 갈린다(골든 TE-accept-noevidence).
- **`AGENTS.md` 의 `Verify (앱 조작)` 가 스킬을 가리키는데 HEAD 참 없이 사유 단 미촬영 줄만 있고 그 줄들에 `· 시도 <…>` 칸이 없으면(사유가 `기준선 흔들림`·`image-diff: ERROR` 로 시작하면 면제) 「시도 칸 없음」 을 경고한다 — check-plan 의 `screen-unshot-attempt` 사본이다(골든 TE-attempt · 사본 정합)** — 검증 스킬에 없는 화면은 범용 도구로 조작하고 보강하는 것이 규칙이라(`../../skills/implement/references/screen-scenarios.md`「화면 시나리오 실행」) 시도 없는 미촬영은 공백을 메우지 않은 것이다. 사유 칸은 자유 서술이라 시도 여부를 기계로 가르려면 고정 칸이 필요하다(2026-11-21 빈틈 확인 — 사유만 있으면 note 로 통과했다).

## §8 회차 전 untracked 파일이 커밋에 들면 경고한다

2026-11-21 Karina 체인 run_994f7987 plan 3 에서 `git add docs` 가 회차 전부터 있던 남의 untracked 파일 `docs/release.md` 를 두 번 커밋에 담았다(54f654b·057384d — 그 뒤 `git rm --cached` 로 추적만 되돌림). `karina:implement` 는 루프 진입 전 `untracked-start-<레포 폴더명>-<BASE sha7>.txt` 스냅숏을 남기지만(`skills/implement/SKILL.md`「작업 범위」), 그것을 읽는 자리는 회차 끝 clean 판정뿐이라 커밋 시점에는 아무도 대조하지 않았다.

- **커밋마다(T 번호와 무관하게) `plan.md` 가 있는 폴더 이름과 그 `> BASE:` sha7 로 스냅숏을 찾고, 있으면 이번 커밋에 들어갈 새 파일과 교집합을 경고한다** — 들어갈 새 파일은 이미 stage 된 추가(`git diff --cached --diff-filter=A`)와 같은 명령의 `git add` 범위 안 아직 untracked 파일(`ls-files --others --full-name` — 범위는 §3 의 `Get-TaskAuditScope`)의 합이다. PreToolUse 시점에는 같은 명령의 `git add docs` 가 아직 돌지 않아 cached 만 보면 실해 형태를 놓친다.
- **스냅숏 줄은 `plan.md` 폴더 기준 경로라 `rev-parse --show-prefix` 를 붙여 최상위 기준으로 맞춘다** — 하니스처럼 plan 폴더가 레포 하위인 세션에서는 두 목록의 기준이 갈려 교집합이 늘 빈다(계획 리뷰 지적 · 골든 UT-subdir).
- **스냅숏·BASE·plan 이 없으면 침묵하고 막지 않는다** — 스냅숏은 implement 회차에만 있고, 회차 전 untracked 를 일부러 커밋하는 경우도 있어 판단은 경고를 읽는 쪽이 한다. 별도 검사로 등록하지 않고 `Invoke-WarnTaskAudit` 안에서 부른다 — 등록하면 「검사 15종」 사본 여섯 곳이 함께 바뀐다.
