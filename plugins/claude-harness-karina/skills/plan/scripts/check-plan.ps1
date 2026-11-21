# check-plan.ps1 — plan.md 의 기계로 갈리는 서식과, 회차 끝에 [x] task 의 실행 증거를 검사한다
#   (karina:plan Step 6 과 karina:implement 최종 리뷰가 리뷰어보다 먼저 부르는 헬퍼 — hook 아님)
#
# 사용: check-plan.ps1 <plan.md 경로>                 서식 검사(계획 시점)
#       check-plan.ps1 <plan.md 경로> -Base <sha>     증거 대조만(회차 끝) — 서식 검사는 돌리지 않는다
# 출력은 ASCII 만이고 줄 종류는 일곱이다:
#   check-plan <줄>: <코드> <세부>        위반 하나
#   check-plan: note <코드> T<N>          -Base 모드의 보고 전용 표시(위반 아님 · 위반 수·종료 코드에 세지 않는다)
#   check-plan: skip <검사> <사유>        건너뛴 검사 하나(위반 아님)
#   check-plan: files <N>                 서식 검사 모드만 — 모든 task 의 Files 줄 백틱 경로(줄의 첫 「[면제」 앞까지) 합집합 수(위반 아님).
#                                         문서도 세고 문서뿐인 「[면제 ①」 줄도 센다 — 경량 판정(light-files)과 다른 값이다.
#                                         karina:plan Step 6 이 이 값으로 plan-reviewer 를 부를지 가른다
#   check-plan: ran plan-check exit 0     AGENTS.md 의 Plan check 가 돌아 통과함(위반 아님 · 로그 파일 없음)
#   check-plan: <N> problems              마지막 줄 — 위반 수
#   check-plan: ERROR <사유>              입력 오류(exit 2)
# 종료 코드: 0 위반 없음 · 1 위반 있음 · 2 입력 오류(경로 없음·파일 없음·읽기 실패 · -Base 모드의 git 밖·없는 BASE).
#
# 코드와 뜻 — 이 표가 정본이다(plan/SKILL.md Step 6 은 여기를 가리킨다):
#   empty-command                Investigation Log 표의 명령 칸이 비었거나 줄표(-·—·–)뿐인 행
#   open-question                Open Questions 절에 「- [ ]」 가 남음
#   acceptance-baseline T<N>     Acceptance 줄에 백틱(판정 명령·리터럴)이 있는데 「착수」 가 없음
#   case-mark T<N>               Files 줄에 (RED)·(GREEN·[면제 가 하나도 없음
#   outside-evidence T<N>        Files 줄 백틱 경로(첫 「[면제」 앞까지)가 하나 이상이고 전부 레포 밖(「~」 로 시작하거나, 루트 경로이면서
#                                plan 폴더의 git 최상위 아래가 아님)인데 그 task 블록에 「--allow-empty」 가 없음 — 다른 레포만 고치는 task 는 이 레포에 커밋이 생기지
#                                않아 회차 끝 no-task-commit 으로 늦게 잡힌다. 하위 항목으로 빈 증거 커밋을 계획에 둔다(plan 이 git 밖이면 재지 않는다)
#   parallel-size <k>            「## 작업 단계」 의 첫 「> 병렬 그룹:」 줄(첫 「—」 앞까지를 「|」 로 그룹, 그룹 안 T<N> 을 task 로 센다)에서
#                                k 번째 그룹의 task 가 2 미만이거나 3 초과 — 조건 정본은 plan/references/parallel-groups.md
#   parallel-order <k>           k 번째 그룹의 번호가 이웃하지 않음(앞 번호 + 1 이 아님)
#   parallel-task T<N> <사유>    그룹의 task 가 missing(블록 없음)·screen(「- **화면**:」 줄)·perf(「- **성능**:」 줄)·
#                                outside(Files 백틱 경로 하나라도 레포 밖 — outside-evidence 와 같은 판정)
#   parallel-overlap T<a> T<b>   같은 그룹 두 task 의 Files 백틱 경로(첫 「[면제」 앞까지 · 대소문자·구분자 무시)가 겹침
#   missing-section <절>       필수 절 없음 — goal·out-of-scope·investigation-log·tasks·verification·deferred
#                                (Goal 절에 「> 경량:」 줄이 있는 경량 plan 은 out-of-scope·verification 을 재지 않는다)
#   light-files <N>              경량 plan 의 task Files 줄 백틱 경로(줄의 첫 「[면제」 앞까지) 합집합이 2 를 넘음
#                                (「[면제 ①」 줄은 경로가 전부 문서·이미지 확장자면 세지 않는다)
#   light-structure T<N>         경량 plan 의 task 에 「- **구조**:」 줄이 있음(새 파일·새 절 추가·공개 표면·경계를 넘는 재구성)
#   light-approval               경량 plan 에 「승인 필요 항목」 절이 있음
#   light-relay                  경량 plan 의 「> 요구:」 가 「코디네이터 인터뷰 경유」(중계 모드는 경량 불허)
#   goal-head <줄>               request(첫 절 앞 「> 요구:」 원문 인용)·base·approval·start·done(Goal 절의 「> BASE:」 등) 없음
#   task-item T<N>               하위 항목이 「- [ ]·[x]·[X]·[/]·[~]·[-]」 뒤 (불요 …) 를 지나 **T<N>-<M>** 가 아니거나 번호가 제목과 다름
#   task-line T<N> <줄>          task 에 files·acceptance·verify 줄 없음
#   screen-line T<N> <요소>      「- **화면**:」 줄에 scenario(시나리오)·screenshot(스크린샷)·predicate(통과 조건) 조각이 없거나 값이 빔
#                                (화면 줄이 없는 task 는 재지 않는다 — 있어야 할 task 인지는 아래 screen-missing 과 plan-reviewer 가 본다)
#   screen-missing T<N>          AGENTS.md(아래 Plan check 와 같은 탐색)의 「- **UI 경로**: `패턴` · …」 에 Files 줄 백틱 경로가 하나라도
#                                맞는데(-like · 패턴은 그 AGENTS.md 폴더 기준 — plan 폴더가 그 아래면 사이 경로를 붙여 맞춘다)
#                                「- **화면**:」 줄도 Files 줄의 「[화면 없음 — <사유>]」 표지도 없음(사유가 빈 표지는 표지가 아니다)
#   ui-path-missing              서식 검사 모드만 — AGENTS.md(같은 탐색)의 「- **Verify (앱 조작)**:」 이 스킬을 가리키는데 「- **UI 경로**:」 줄이
#                                없거나 백틱 패턴이 하나도 없음(줄 1 · 값이 「[화면 없음 — <사유>]」 면 면제 — CLI·API 검증 스킬). 없으면 screen-missing 을 잴 수 없어 화면 줄 없는 UI 수정이 승인을 지난다 — 넘기지 않고 UI 경로를 단다
#   origin-missing T<N>          AGENTS.md(같은 탐색)에 「- **UI 재구현 기준 소스**:」 줄이 있는데 「- **화면**:」 줄이 있는 task 에
#                                「- **원본**:」 줄도 Files 줄의 「[원본 없음 — <사유>]」 표지도 없음(사유가 빈 표지는 표지가 아니다)
#   origin-line T<N> <요소>      「- **원본**:」 줄에 path(백틱 원본 경로)·verdict(옮김·미룸·이탈 중 하나)가 없음 — 선언과 무관하게 줄이 있으면 잰다
#   screen-baseline T<N>         Verify (앱 조작) 이 스킬을 가리키는데 화면 줄 통과 조건이 「기준선 일치」 로 시작하고
#                                그 task 첫 하위 항목(T<N>-1) 줄에 「기준선」 이 없음(편집 전 기준선 촬영 자리)
#   plan-check exit <n> log <파일>  plan 폴더에서 git 최상위까지 올라가며 찾은 AGENTS.md 의 「- **Plan check**: `<명령>`」 이
#                                exit 0 이 아님 — <줄> 은 AGENTS.md 의 줄 · 출력은 임시 폴더 karina-plugin\scratch\<파일>
#   plan-check timeout <s> log <파일>  그 명령이 상한(KARINA_PLAN_CHECK_TIMEOUT_SEC, 기본 120초)을 넘음
#                                (줄이 없으면 아무것도 내지 않는다 · -Base 모드는 돌리지 않는다)
# -Base 모드의 코드 — 대상은 하위 항목(마커 [ ]·[/]·[x]·[X]·[-]·[~])이 전부 [x]·[X] 인 task 이고, 전부 「(불요」 인 task 는 뺀다:
#   no-task-commit T<N>          BASE..HEAD 에 제목이 「{유형}: T<N> —」(또는 「T<N>:」)인 커밋이 없음 — 마지막 task 는
#                                그 블록이 <버전> 을 담으면 「설정: v<버전> —」(Release 형식 버전 커밋)도 센다
#   no-commit-evidence T<N>      그 커밋은 있으나 어느 본문에도 「검증 결과」·「검증:」 이 없음(HUMAN-VERIFY 낱말만으로는 증거가 아니다)
#   아래 다섯은 본문 증거가 있는 task 만 잰다. 줄 머리 「- 」 는 허용한다:
#   acceptance-evidence T<N> <have>/<want>  그 task 커밋 본문들의 「Acceptance: <항목> — <판정>」 줄 수(have)가 plan 의
#                                「- **Acceptance**:」 항목 수(want)보다 적음 — 항목은 그 줄 값에서 백틱 스팬을 한 글자로 바꾸고 괄호 안을 지운 뒤
#                                「 · 」 로 가른 조각이다(항목 문면은 대조하지 않는다 — 표현만 달라도 위반이 되지 않게)
#   no-red-evidence T<N>         Files 줄에 (RED) 가 있는데 어느 본문에도 「RED:」·「RED(구현 전):」·「RED(사후 …):」 줄이 없음
#                                (「RED: 미확인 — <사유>」 만 있으면 위반 대신 note red-unverified T<N>)
#   no-screen-verdict T<N>       「- **화면**:」 줄이 있는 task 인데 어느 본문에도 「화면: HEAD 참|거짓」·「화면: 미촬영(HUMAN-VERIFY)」 줄이 없음
#                                (그 task 의 T<N> 커밋 본문만 — 다른 커밋의 지목 줄 「화면: T<N> …」 은 받지 않는다)
#   screen-false T<N>            화면 판정이 「HEAD 거짓」 뿐임(「HEAD 참」 이 하나라도 있으면 통과)
#   screen-unshot T<N>           판정이 미촬영뿐이고 AGENTS.md(위 Plan check 와 같은 탐색)의 「- **Verify (앱 조작)**:」 값이
#                                「없음」 이 아님 — 미촬영 줄에 「· 사유 <…> · 시도 <…>」 칸이 있으면 위반 대신 note screen-unshot-reason T<N>
#                                (Verify 줄이 없거나 AGENTS.md 가 없으면 검증 스킬 없음 — 미촬영 통과)
#   screen-unshot-attempt T<N>   위 screen-unshot 에서 사유 칸은 있는데 「· 시도 <…>」 칸이 없음 — 사유가 「기준선 흔들림」·
#                                「image-diff: ERROR」 로 시작하면(조작은 성공) 시도 칸 없이 note
#                                (판정 사본: scripts/guard-task-audit.ps1 Get-TaskEvidenceLines)
#   no-red-evidence·no-screen-verdict 판정의 사본이 scripts/guard-task-audit.ps1 의 Get-TaskEvidenceLines 에 있다 —
#                                한쪽을 고치면 다른 쪽도 고친다(골든 guard-task-audit 의 「사본 정합」 케이스가 대조한다)
#   remaining-issue <종류>       task 단위가 아니라 「## Deferred / Follow-up」 항목 단위 — 넘김 사유 없이 남은 항목(줄 번호는 그 항목).
#                                종류: no-marker(마커 없음) · unjudged([미판정]) · no-reason([등재]·[미등재:대장 없음] 에 「넘김 사유 ①·②·
#                                다른 종류의 세션」 없음) · no-basis([다음 회차] 에 「(근거:」 없음) · over-approved([다음 회차] 가 승인 표지의
#                                「다음 회차 <N>」(없으면 0)을 넘음). 판정 정본은 scripts/deferred-handoff.ps1 이고 loop-continue 가 같은 함수를 쓴다
#                                (헬퍼를 못 읽으면 「check-plan: skip remaining-issue no-helper」)
#   ERROR no-git · ERROR bad-base  plan 이 git 밖 · BASE 가 커밋이 아님(exit 2)
# 제목 형식의 정본은 guard-bash 의 완료 커밋 판정이다(scripts/rules/bash-guard-rationale.md §14) — 같은 정규식을 쓴다.
#
# 왜 결정적 스크립트인가: 문자열로 갈리는 판정을 리뷰어(LLM)가 매 라운드 읽어 가르면 놓칠 수 있고 라운드를 쓴다.
#   리뷰어에 남는 것은 면제 사유의 옳음과 음성 짝이다 — 케이스 경로마다의 표시·명령마다의 착수값은 아무도 재지 않는다
#   (case-mark·acceptance-baseline 은 줄에 하나라도 있는가만 본다).
# 왜 출력에 한글이 없는가: Git Bash 를 거친 PowerShell 출력에서 한글이 깨진다(work-clock 과 같은 이유).
# 왜 펜스 안을 건너뛰는가: 템플릿·예시 펜스 안의 「## 」·「- [ ]」·표 행이 위반으로 잡힌다.
# 왜 「\|」 를 칸 경계로 보지 않는가: 표 칸 안의 정규식은 「\|」 로 적히고, 그것으로 가르면 명령 칸 자리가 밀린다.
# Deferred 마커 서식(위치·볼드)은 재지 않는다 — session-context hook 의 계수와 하니스 정합 검사가 이미 각자 구현한다.
#   -Base 모드의 remaining-issue 는 서식이 아니라 넘김 사유의 유무를 잰다.
# stdin 은 읽지 않는다. PS 5.1·7 양쪽에서 돈다 — Windows 에는 5.1 만 있을 수 있다.
param([string]$PlanPath = '', [string]$Base = '')

$problems = New-Object System.Collections.Generic.List[string]
function Add-Problem([int]$Line, [string]$Text) { $problems.Add(('check-plan {0}: {1}' -f $Line, $Text)) }
$notes = New-Object System.Collections.Generic.List[string]
function Complete-Check {
    foreach ($p in $problems) { Write-Output $p }
    foreach ($t in $notes) { Write-Output ('check-plan: note ' + $t) }
    Write-Output ('check-plan: {0} problems' -f $problems.Count)
    if ($problems.Count) { exit 1 }
    exit 0
}
function Get-Text([int[]]$Codes) { return -join ($Codes | ForEach-Object { [char]$_ }) }

if (-not $PlanPath) { Write-Output 'check-plan: ERROR no-path'; exit 2 }
if (-not (Test-Path -LiteralPath $PlanPath -PathType Leaf)) { Write-Output 'check-plan: ERROR not-found'; exit 2 }
try {
    $raw = [System.IO.File]::ReadAllText((Resolve-Path -LiteralPath $PlanPath).Path, [System.Text.Encoding]::UTF8)
} catch {
    Write-Output 'check-plan: ERROR unreadable'; exit 2
}

# ---- 줄 목록 — 펜스 안 줄은 code 로 표시해 판정에서 뺀다 ----
$lines = @()
$fenceChar = $null
$n = 0
foreach ($text in ($raw -split "`r?`n")) {
    $n++
    $isCode = $false
    $m = [regex]::Match($text, '^ {0,3}(`{3,}|~{3,})')
    if ($fenceChar) {
        $isCode = $true
        if ($m.Success -and $m.Groups[1].Value[0] -eq $fenceChar) { $fenceChar = $null }
    } elseif ($m.Success) {
        $isCode = $true
        $fenceChar = $m.Groups[1].Value[0]
    }
    $lines += [pscustomobject]@{ N = $n; Text = $text; Code = $isCode }
}

# ---- 절 — `## ` 로 가르고 이름은 대괄호 표기 앞까지 ----
$sections = @()
$head = New-Object System.Collections.Generic.List[object]
foreach ($l in $lines) {
    if (-not $l.Code -and $l.Text -match '^## (.+?)\s*(\[.*)?$') {
        $sections += [pscustomobject]@{ Title = $Matches[1].Trim(); N = $l.N; Body = (New-Object System.Collections.Generic.List[object]) }
    } elseif ($sections.Count) {
        $sections[-1].Body.Add($l)
    } else {
        $head.Add($l)
    }
}
# 접두 비교는 서수로 한다 — 문화권 비교는 .NET Framework(PS 5.1)와 .NET(7)에서 한글 결과가 갈릴 수 있다.
function Test-Prefix([string]$Text, [string]$Prefix) { return $Text.StartsWith($Prefix, [System.StringComparison]::Ordinal) }
function Find-Section([string]$Title) { foreach ($s in $sections) { if ($s.Title -eq $Title) { return $s } }; return $null }
function Get-ProseLines($Section) { if ($Section) { return @($Section.Body | Where-Object { -not $_.Code }) }; return @() }

# 표 행을 칸으로 가른다 — 「\|」 는 칸 경계가 아니다.
function Split-Row([string]$Row) {
    $cells = [regex]::Split($Row.Trim(), '(?<!\\)\|')
    if ($cells.Count -ge 3) { return $cells[1..($cells.Count - 2)] | ForEach-Object { $_.Trim() } }
    return @()
}

# task 블록 — `### T<N>.` 줄부터 다음 그 줄 앞까지.
$tasksTitle = Get-Text @(0xC791, 0xC5C5, 0x20, 0xB2E8, 0xACC4)    # 작업 단계
function Get-TaskBlocks {
    $blocks = @()
    foreach ($l in (Get-ProseLines (Find-Section $tasksTitle))) {
        if ($l.Text -match '^### T(\d+)\.') {
            $blocks += [pscustomobject]@{ Id = [int]$Matches[1]; N = $l.N; Lines = (New-Object System.Collections.Generic.List[object]) }
        } elseif ($blocks.Count) {
            $blocks[-1].Lines.Add($l)
        }
    }
    return $blocks
}

# plan 폴더에서 git 최상위까지 올라가며 처음 만난 AGENTS.md — Plan check 줄과 -Base 의 Verify 줄이 같이 쓴다.
function Get-AgentsFile([string]$PlanFile) {
    $dir = Split-Path -Parent $PlanFile
    $top = $null
    try { $top = (& git -C $dir rev-parse --show-toplevel 2>$null) } catch { $top = $null }
    if ($LASTEXITCODE -ne 0 -or -not $top) { $top = $dir }
    $top = [System.IO.Path]::GetFullPath($top).TrimEnd('\', '/')
    while ($dir) {
        $agents = Join-Path $dir 'AGENTS.md'
        if (Test-Path -LiteralPath $agents -PathType Leaf) {
            return @{ Dir = $dir; Lines = [System.IO.File]::ReadAllLines($agents, [System.Text.Encoding]::UTF8) }
        }
        if ([System.IO.Path]::GetFullPath($dir).TrimEnd('\', '/') -eq $top) { return $null }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { return $null }
        $dir = $parent
    }
    return $null
}

# AGENTS.md 의 「- **<라벨>**: 값」 줄 값(없으면 $null).
function Get-AgentsLineValue($Agents, [string]$Label) {
    if (-not $Agents) { return $null }
    $rx = '^- \*\*' + [regex]::Escape($Label) + '\*\*:\s*(.*)$'
    foreach ($al in $Agents.Lines) {
        $m = [regex]::Match($al, $rx)
        if ($m.Success) { return $m.Groups[1].Value.Trim() }
    }
    return $null
}
# Verify (앱 조작) 값이 있고 「없음」 이 아니면 검증 스킬이 있다.
function Test-VerifySkill($Agents) {
    $value = Get-AgentsLineValue $Agents ('Verify (' + (Get-Text @(0xC571, 0x20, 0xC870, 0xC791)) + ')')    # Verify (앱 조작)
    return [bool]$value -and ($value -notmatch ('^\W*' + (Get-Text @(0xC5C6, 0xC74C))))    # 없음
}

# ---- 증거 대조 (-Base) — [x] 로 닫힌 task 마다 BASE..HEAD 의 T<N> 커밋 본문에 검증 기록이 있는가 ----
if ($Base) {
    # PS 5.1 은 네이티브 출력을 콘솔 코드페이지로 디코딩해 커밋의 한글을 깨뜨린다. 콘솔 없는 호스트에서는 setter 가 던진다.
    try { [Console]::OutputEncoding = [System.Text.Encoding]::UTF8 } catch { }
    $planDir = Split-Path -Parent (Resolve-Path -LiteralPath $PlanPath).Path
    $top = $null
    try { $top = (& git -C $planDir rev-parse --show-toplevel 2>$null) } catch { $top = $null }
    if ($LASTEXITCODE -ne 0 -or -not $top) { Write-Output 'check-plan: ERROR no-git'; exit 2 }
    $null = & git -C $top rev-parse --verify -q ($Base + '^{commit}') 2>$null
    if ($LASTEXITCODE -ne 0) { Write-Output 'check-plan: ERROR bad-base'; exit 2 }

    # 커밋 경계는 NUL — 본문의 줄바꿈과 섞이지 않는다.
    $logText = (& git -C $top log --format='%B%x00' ($Base + '..HEAD') 2>$null) -join "`n"
    $types = (@(@(0xAE30, 0xB2A5), @(0xC218, 0xC815), @(0xB9AC, 0xD329, 0xD1A0, 0xB9C1), @(0xBB38, 0xC11C), @(0xC124, 0xC815)) | ForEach-Object { Get-Text $_ }) -join '|'    # 기능|수정|리팩토링|문서|설정
    $titleRx = '^\s*(?:(?:' + $types + ')\s*:\s*)?T(\d+)\s*(?::|' + [char]0x2014 + '|-)'
    $verify = Get-Text @(0xAC80, 0xC99D)    # 검증
    $evidenceRx = $verify + '\s*(?:' + (Get-Text @(0xACB0, 0xACFC)) + '|:)'    # 검증 결과 · 검증:
    $lineHead = '(?m)^\s*(?:[-*]\s*)?'
    $unverified = Get-Text @(0xBBF8, 0xD655, 0xC778)    # 미확인
    $redRx = $lineHead + 'RED(?:\((?:' + (Get-Text @(0xAD6C, 0xD604, 0x20, 0xC804)) + '|' + (Get-Text @(0xC0AC, 0xD6C4)) + '[^)\r\n]*)\))?\s*:\s*(?!' + $unverified + ')\S'    # RED: · RED(구현 전): · RED(사후 …):
    $redUnRx = $lineHead + 'RED\s*:\s*' + $unverified
    $verdictRx = $lineHead + 'Acceptance\s*:\s*\S'
    $acceptLabel = '- **Acceptance**:'
    $itemSplitRx = '\s' + [char]0xB7 + '\s'
    $screenHead = $lineHead + (Get-Text @(0xD654, 0xBA74)) + ':\s*'    # 화면:
    $screenTrueRx = $screenHead + 'HEAD\s*' + (Get-Text @(0xCC38))    # 참
    $screenFalseRx = $screenHead + 'HEAD\s*' + (Get-Text @(0xAC70, 0xC9D3))    # 거짓
    $unshotRx = $screenHead + (Get-Text @(0xBBF8, 0xCD2C, 0xC601)) + '\(HUMAN-VERIFY\)(.*)$'    # 미촬영(HUMAN-VERIFY)
    $reasonRx = [char]0xB7 + '\s*' + (Get-Text @(0xC0AC, 0xC720)) + '\s+\S'    # · 사유 <…>
    $attemptRx = [char]0xB7 + '\s*' + (Get-Text @(0xC2DC, 0xB3C4)) + '\s+\S'    # · 시도 <…>
    $attemptFreeRx = [char]0xB7 + '\s*' + (Get-Text @(0xC0AC, 0xC720)) + '\s+(?:' + (Get-Text @(0xAE30, 0xC900, 0xC120, 0x20, 0xD754, 0xB4E4, 0xB9BC)) + '|image-diff:\s*ERROR)'    # · 사유 기준선 흔들림 | image-diff: ERROR
    $verifySkill = Test-VerifySkill (Get-AgentsFile (Resolve-Path -LiteralPath $PlanPath).Path)
    $versionRx = '^\s*' + (Get-Text @(0xC124, 0xC815)) + '\s*:\s*v(\d+\.\d+\.\d+)\s*' + [char]0x2014    # 설정: v<버전> —
    function Test-UnshotAttempt([string]$Tail) { return ($Tail -match $reasonRx) -and (($Tail -match $attemptRx) -or ($Tail -match $attemptFreeRx)) }
    $taskBlocks = @(Get-TaskBlocks)
    $lastText = if ($taskBlocks.Count) { (@($taskBlocks[-1].Lines | ForEach-Object { $_.Text }) -join "`n") } else { '' }
    $commits = @()
    foreach ($msg in ($logText -split "`0")) {
        $msg = $msg.Trim()
        if (-not $msg) { continue }
        $parts = $msg -split "`n", 2
        $body = if ($parts.Count -gt 1) { $parts[1] } else { '' }
        $m = [regex]::Match($parts[0], $titleRx)
        $v = [regex]::Match($parts[0], $versionRx)
        if ($m.Success) { $id = [int]$m.Groups[1].Value }
        elseif ($v.Success -and $taskBlocks.Count -and $lastText.Contains($v.Groups[1].Value)) { $id = $taskBlocks[-1].Id }
        else { continue }
        $unshots = @([regex]::Matches($body, $unshotRx) | ForEach-Object { $_.Groups[1].Value })
        $commits += [pscustomobject]@{
            Id = $id; Evidence = [regex]::IsMatch($body, $evidenceRx)
            Verdicts = [regex]::Matches($body, $verdictRx).Count
            Red = [regex]::IsMatch($body, $redRx); RedUnverified = [regex]::IsMatch($body, $redUnRx)
            ScreenTrue = [regex]::IsMatch($body, $screenTrueRx); ScreenFalse = [regex]::IsMatch($body, $screenFalseRx)
            Unshot = [bool]$unshots.Count; UnshotReason = [bool]@($unshots | Where-Object { $_ -match $reasonRx }).Count
            UnshotAttempt = [bool]@($unshots | Where-Object { Test-UnshotAttempt $_ }).Count
        }
    }
    $screenLabelBase = '- **' + (Get-Text @(0xD654, 0xBA74)) + '**:'    # - **화면**:
    $filesLabel = '- **Files**:'

    $unneeded = '(' + (Get-Text @(0xBD88, 0xC694))    # (불요
    foreach ($b in $taskBlocks) {
        $items = @($b.Lines | Where-Object { $_.Text -match '^- \[[ /xX~-]\]' })
        if (-not $items.Count) { continue }
        if (@($items | Where-Object { $_.Text -notmatch '^- \[[xX]\]' }).Count) { continue }
        if (-not @($items | Where-Object { -not $_.Text.Contains($unneeded) }).Count) { continue }
        $mine = @($commits | Where-Object { $_.Id -eq $b.Id })
        if (-not $mine.Count) { Add-Problem $b.N ('no-task-commit T' + $b.Id) }
        elseif (-not @($mine | Where-Object { $_.Evidence }).Count) { Add-Problem $b.N ('no-commit-evidence T' + $b.Id) }
        else {
            $tag = 'T' + $b.Id
            $hasRed = [bool]@($b.Lines | Where-Object { (Test-Prefix $_.Text $filesLabel) -and $_.Text.Contains('(RED)') }).Count
            if ($hasRed -and -not @($mine | Where-Object { $_.Red }).Count) {
                if (@($mine | Where-Object { $_.RedUnverified }).Count) { $notes.Add('red-unverified ' + $tag) }
                else { Add-Problem $b.N ('no-red-evidence ' + $tag) }
            }
            $acceptRow = $b.Lines | Where-Object { Test-Prefix $_.Text $acceptLabel } | Select-Object -First 1
            if ($acceptRow) {
                $criteria = [regex]::Replace($acceptRow.Text.Substring($acceptLabel.Length), '`[^`]*`', 'x')
                do { $before = $criteria; $criteria = [regex]::Replace($criteria, '\([^()]*\)', '') } while ($criteria -ne $before)
                $want = @($criteria -split $itemSplitRx | Where-Object { $_.Trim() }).Count
                $have = [int](($mine | Measure-Object -Property Verdicts -Sum).Sum)
                if ($have -lt $want) { Add-Problem $b.N ('acceptance-evidence ' + $tag + ' ' + $have + '/' + $want) }
            }
            $hasScreen = [bool]@($b.Lines | Where-Object { Test-Prefix $_.Text $screenLabelBase }).Count
            if ($hasScreen -and -not @($mine | Where-Object { $_.ScreenTrue }).Count) {
                if (@($mine | Where-Object { $_.ScreenFalse }).Count) { Add-Problem $b.N ('screen-false ' + $tag) }
                elseif (-not @($mine | Where-Object { $_.Unshot }).Count) { Add-Problem $b.N ('no-screen-verdict ' + $tag) }
                elseif ($verifySkill) {
                    if (@($mine | Where-Object { $_.UnshotAttempt }).Count) { $notes.Add('screen-unshot-reason ' + $tag) }
                    elseif (@($mine | Where-Object { $_.UnshotReason }).Count) { Add-Problem $b.N ('screen-unshot-attempt ' + $tag) }
                    else { Add-Problem $b.N ('screen-unshot ' + $tag) }
                }
            }
        }
    }
    $handoff = Join-Path (Split-Path (Split-Path (Split-Path $PSScriptRoot))) 'scripts/deferred-handoff.ps1'
    try { . $handoff } catch { }
    if (Get-Command Get-UnhandedDeferred -ErrorAction SilentlyContinue) {
        foreach ($u in @(Get-UnhandedDeferred $raw)) { Add-Problem $u.N ('remaining-issue ' + $u.Kind) }
    } else { Write-Output 'check-plan: skip remaining-issue no-helper' }
    Complete-Check
}

# ---- B1 필수 절 — 경량 plan 은 Out of Scope·검증 방법을 뺀다(task 의 검증 줄이 대신한다) ----
$goal = Find-Section 'Goal'
$lightLabel = '> ' + (Get-Text @(0xACBD, 0xB7C9)) + ':'    # > 경량:
$isLight = [bool]@(Get-ProseLines $goal | Where-Object { Test-Prefix $_.Text $lightLabel }).Count
$required = [ordered]@{
    'goal' = 'Goal'; 'out-of-scope' = 'Out of Scope'; 'investigation-log' = 'Investigation Log'
    'tasks' = $tasksTitle
    'verification' = ([string][char]0xAC80 + [char]0xC99D + ' ' + [char]0xBC29 + [char]0xBC95)    # 검증 방법
    'deferred' = 'Deferred / Follow-up'
}
foreach ($key in $required.Keys) {
    if ($isLight -and @('out-of-scope', 'verification') -contains $key) { continue }
    if (-not (Find-Section $required[$key])) { Add-Problem 1 ('missing-section ' + $key) }
}

# ---- B2 머리 줄 — 요구 줄은 첫 절 앞, 나머지 넷은 Goal 절 ----
$requestLabel = '> ' + [char]0xC694 + [char]0xAD6C + ':'    # > 요구:
$requestLines = @($head | Where-Object { -not $_.Code -and (Test-Prefix $_.Text $requestLabel) })
if (-not $requestLines.Count) { Add-Problem 1 'goal-head request' }
if ($goal) {
    $goalHeads = [ordered]@{
        'base' = '> BASE:'
        'approval' = '> ' + [char]0xC2B9 + [char]0xC778 + ':'    # > 승인:
        'start' = '> ' + [char]0xC2DC + [char]0xC791 + ':'       # > 시작:
        'done' = '> ' + [char]0xC644 + [char]0xB8CC + ':'        # > 완료:
    }
    $goalProse = Get-ProseLines $goal
    foreach ($key in $goalHeads.Keys) {
        if (-not ($goalProse | Where-Object { Test-Prefix $_.Text $goalHeads[$key] })) { Add-Problem $goal.N ('goal-head ' + $key) }
    }
}

# ---- B5 경량 조건 — 사용자 승인 말고도 기계로 갈리는 조건은 여기서 잰다(모델 판정만으로 경량을 열지 않는다) ----
$exemptMark = '[' + (Get-Text @(0xBA74, 0xC81C))                                  # [면제
$docExemptMark = $exemptMark + ' ' + [char]0x2460
$structLabel = '- **' + (Get-Text @(0xAD6C, 0xC870)) + '**:'                       # - **구조**:
$lightPaths = New-Object System.Collections.Generic.HashSet[string]
$unionPaths = New-Object System.Collections.Generic.HashSet[string]
foreach ($b in @(Get-TaskBlocks)) {
    foreach ($l in $b.Lines) {
        if ($isLight -and (Test-Prefix $l.Text $structLabel)) { Add-Problem $l.N ('light-structure T' + $b.Id) }
        if (-not (Test-Prefix $l.Text '- **Files**:')) { continue }
        $t = $l.Text
        $cut = $t.IndexOf($exemptMark, [System.StringComparison]::Ordinal)
        $docOnly = $cut -ge 0 -and $t.Substring($cut).StartsWith($docExemptMark, [System.StringComparison]::Ordinal)
        if ($cut -ge 0) { $t = $t.Substring(0, $cut) }
        $found = @([regex]::Matches($t, '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value.Trim() })
        foreach ($p in $found) { $null = $unionPaths.Add($p) }
        if ($docOnly -and $found.Count -and -not @($found | Where-Object { $_ -notmatch '\.(md|png|jpe?g|gif|svg|webp|ico)$' }).Count) { continue }
        foreach ($p in $found) { $null = $lightPaths.Add($p) }
    }
}
Write-Output ('check-plan: files ' + $unionPaths.Count)
if ($isLight) {
    if ($lightPaths.Count -gt 2) { Add-Problem $goal.N ('light-files ' + $lightPaths.Count) }
    $approval = Find-Section (Get-Text @(0xC2B9, 0xC778, 0x20, 0xD544, 0xC694, 0x20, 0xD56D, 0xBAA9))    # 승인 필요 항목
    if ($approval) { Add-Problem $approval.N 'light-approval' }
    $relayMark = Get-Text @(0xCF54, 0xB514, 0xB124, 0xC774, 0xD130, 0x20, 0xC778, 0xD130, 0xBDF0, 0x20, 0xACBD, 0xC720)    # 코디네이터 인터뷰 경유
    if (@($requestLines | Where-Object { $_.Text.Contains($relayMark) }).Count) { Add-Problem $requestLines[0].N 'light-relay' }
}

# ---- A1 Investigation Log ----
$log = Find-Section 'Investigation Log'
if ($log) {
    $logProse = Get-ProseLines $log
    $dashes = @('-', [string][char]0x2014, [string][char]0x2013)
    for ($i = 0; $i -lt $logProse.Count; $i++) {
        $row = $logProse[$i].Text
        if (-not $row.TrimStart().StartsWith('|')) { continue }
        if ($row -match '^\s*\|[\s:|-]+\|\s*$') { continue }    # 구분 행
        $next = if ($i + 1 -lt $logProse.Count) { $logProse[$i + 1].Text } else { '' }
        if ($next -match '^\s*\|[\s:|-]+\|\s*$') { continue }   # 머리 행
        $cells = @(Split-Row $row)
        if ($cells.Count -lt 2) { continue }
        if ($cells[1] -eq '' -or $dashes -contains $cells[1]) { Add-Problem $logProse[$i].N 'empty-command' }
    }
}

# ---- A4 Open Questions ----
foreach ($l in (Get-ProseLines (Find-Section 'Open Questions'))) {
    if ($l.Text -match '^\s*- \[ \]') { Add-Problem $l.N 'open-question' }
}

# ---- A5·A6·B3·B4 task 마다 ----
if (Find-Section $tasksTitle) {
    $blocks = @(Get-TaskBlocks)
    $verifyLabel = '- **' + [char]0xAC80 + [char]0xC99D + '**:'    # - **검증**:
    $baseline = [string][char]0xCC29 + [char]0xC218                # 착수
    $exempt = '[' + [char]0xBA74 + [char]0xC81C                     # [면제
    $screenLabel = '- **' + (Get-Text @(0xD654, 0xBA74)) + '**:'    # - **화면**:
    $screenParts = [ordered]@{
        'scenario' = Get-Text @(0xC2DC, 0xB098, 0xB9AC, 0xC624)            # 시나리오
        'screenshot' = Get-Text @(0xC2A4, 0xD06C, 0xB9B0, 0xC0F7)          # 스크린샷
        'predicate' = Get-Text @(0xD1B5, 0xACFC, 0x20, 0xC870, 0xAC74)     # 통과 조건
    }
    # UI 경로 — 패턴은 AGENTS.md 폴더 기준이라 Files 경로(plan 폴더 기준) 앞에 두 폴더 사이 경로를 붙여 맞춘다.
    $uiAgents = Get-AgentsFile (Resolve-Path -LiteralPath $PlanPath).Path
    $uiValue = Get-AgentsLineValue $uiAgents ('UI ' + (Get-Text @(0xACBD, 0xB85C)))    # UI 경로
    $uiPatterns = @()
    $uiPrefix = ''
    if ($uiValue) {
        $uiPatterns = @([regex]::Matches($uiValue, '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value.Replace('\', '/') })
        $planDir = [System.IO.Path]::GetFullPath((Split-Path -Parent (Resolve-Path -LiteralPath $PlanPath).Path)).TrimEnd('\', '/')
        $agentsDir = [System.IO.Path]::GetFullPath($uiAgents.Dir).TrimEnd('\', '/')
        if ($planDir.Length -gt $agentsDir.Length -and $planDir.StartsWith($agentsDir, [System.StringComparison]::OrdinalIgnoreCase)) {
            $uiPrefix = $planDir.Substring($agentsDir.Length + 1).Replace('\', '/') + '/'
        }
    }
    $noScreenRx = '\[' + (Get-Text @(0xD654, 0xBA74)) + '\s+' + (Get-Text @(0xC5C6, 0xC74C)) + '\s*' + [char]0x2014 + '\s*[^\]\s]'    # [화면 없음 — <사유>]
    $uiVerifySkill = Test-VerifySkill $uiAgents
    if ($uiVerifySkill -and -not $uiPatterns.Count -and -not [regex]::IsMatch([string]$uiValue, $noScreenRx)) { Add-Problem 1 'ui-path-missing' }
    $baselineWord = Get-Text @(0xAE30, 0xC900, 0xC120)    # 기준선
    $baselineMatch = $baselineWord + ' ' + (Get-Text @(0xC77C, 0xCE58))    # 기준선 일치
    $originWord = Get-Text @(0xC6D0, 0xBCF8)
    $originLabel = '- **' + $originWord + '**:'
    $originDeclared = [bool](Get-AgentsLineValue $uiAgents ('UI ' + (Get-Text @(0xC7AC, 0xAD6C, 0xD604, 0x20, 0xAE30, 0xC900, 0x20, 0xC18C, 0xC2A4))))
    $noOriginRx = '\[' + $originWord + '\s+' + (Get-Text @(0xC5C6, 0xC74C)) + '\s*' + [char]0x2014 + '\s*[^\]\s]'
    $originVerdictRx = (Get-Text @(0xC62E, 0xAE40)) + '|' + (Get-Text @(0xBBF8, 0xB8F8)) + '|' + (Get-Text @(0xC774, 0xD0C8))
    $planTop = $null
    try { $planTop = [string](& git -C (Split-Path -Parent (Resolve-Path -LiteralPath $PlanPath).Path) rev-parse --show-toplevel 2>$null) } catch { }
    if ($LASTEXITCODE -ne 0 -or -not $planTop) { $planTop = $null } else { $planTop = $planTop.Trim().Replace('\', '/').TrimEnd('/') + '/' }
    foreach ($b in $blocks) {
        $tag = 'T' + $b.Id
        $items = 0
        foreach ($l in $b.Lines) {
            if ($l.Text -match '^- \[[ /xX~-]\]') {
                $items++
                $m = [regex]::Match($l.Text, '^- \[[ /xX~-]\] (?:\([^)]*\) )?\*\*T(\d+)-\d+\*\*')
                if (-not $m.Success -or [int]$m.Groups[1].Value -ne $b.Id) { Add-Problem $l.N ('task-item ' + $tag) }
            }
        }
        if (-not $items) { Add-Problem $b.N ('task-item ' + $tag) }

        $files = $b.Lines | Where-Object { Test-Prefix $_.Text '- **Files**:' } | Select-Object -First 1
        $accept = $b.Lines | Where-Object { Test-Prefix $_.Text '- **Acceptance**:' } | Select-Object -First 1
        $verify = $b.Lines | Where-Object { Test-Prefix $_.Text $verifyLabel } | Select-Object -First 1
        if (-not $files) { Add-Problem $b.N ('task-line ' + $tag + ' files') }
        if (-not $accept) { Add-Problem $b.N ('task-line ' + $tag + ' acceptance') }
        if (-not $verify) { Add-Problem $b.N ('task-line ' + $tag + ' verify') }
        if ($files -and -not ($files.Text.Contains('(RED)') -or $files.Text.Contains('(GREEN') -or $files.Text.Contains($exempt))) {
            Add-Problem $files.N ('case-mark ' + $tag)
        }
        if ($files -and $planTop) {
            $head = $files.Text
            $cut = $head.IndexOf($exempt)
            if ($cut -ge 0) { $head = $head.Substring(0, $cut) }
            $paths = @([regex]::Matches($head, '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value })
            $inside = @($paths | Where-Object {
                -not $_.StartsWith('~') -and (-not [System.IO.Path]::IsPathRooted($_) -or
                ($_.Replace('\', '/') + '/').StartsWith($planTop, [System.StringComparison]::OrdinalIgnoreCase))
            })
            if ($paths.Count -and -not $inside.Count -and -not @($b.Lines | Where-Object { $_.Text.Contains('--allow-empty') }).Count) {
                Add-Problem $files.N ('outside-evidence ' + $tag)
            }
        }
        if ($accept -and $accept.Text.Contains('`') -and -not $accept.Text.Contains($baseline)) {
            Add-Problem $accept.N ('acceptance-baseline ' + $tag)
        }
        foreach ($s in @($b.Lines | Where-Object { Test-Prefix $_.Text $screenLabel })) {
            $pieces = @($s.Text.Substring($screenLabel.Length).Split([char]0xB7) | ForEach-Object { $_.Trim() })
            foreach ($key in $screenParts.Keys) {
                $head = $screenParts[$key] + ' '
                if (-not @($pieces | Where-Object { (Test-Prefix $_ $head) -and $_.Substring($head.Length).Trim() }).Count) {
                    Add-Problem $s.N ('screen-line ' + $tag + ' ' + $key)
                }
            }
            $predHead = $screenParts['predicate'] + ' '
            if ($uiVerifySkill -and @($pieces | Where-Object { (Test-Prefix $_ $predHead) -and (Test-Prefix $_.Substring($predHead.Length).Trim() $baselineMatch) }).Count) {
                $first = $b.Lines | Where-Object { $_.Text -match '^- \[[ /xX~-]\]' } | Select-Object -First 1
                if (-not $first -or -not $first.Text.Contains($baselineWord)) { Add-Problem $s.N ('screen-baseline ' + $tag) }
            }
        }
        if ($files -and $uiPatterns.Count -and -not [regex]::IsMatch($files.Text, $noScreenRx) -and
            -not @($b.Lines | Where-Object { Test-Prefix $_.Text $screenLabel }).Count) {
            $paths = @([regex]::Matches($files.Text, '`([^`]+)`') | ForEach-Object { $uiPrefix + $_.Groups[1].Value.Replace('\', '/') })
            if (@($paths | Where-Object { $p = $_; @($uiPatterns | Where-Object { $p -like $_ }).Count }).Count) {
                Add-Problem $files.N ('screen-missing ' + $tag)
            }
        }
        $origins = @($b.Lines | Where-Object { Test-Prefix $_.Text $originLabel })
        foreach ($o in $origins) {
            if ($o.Text -notmatch '`[^`]+`') { Add-Problem $o.N ('origin-line ' + $tag + ' path') }
            if ($o.Text -notmatch $originVerdictRx) { Add-Problem $o.N ('origin-line ' + $tag + ' verdict') }
        }
        if ($originDeclared -and -not $origins.Count -and @($b.Lines | Where-Object { Test-Prefix $_.Text $screenLabel }).Count -and
            -not ($files -and [regex]::IsMatch($files.Text, $noOriginRx))) {
            Add-Problem $b.N ('origin-missing ' + $tag)
        }
    }
    $groupHead = '> ' + (Get-Text @(0xBCD1, 0xB82C, 0x20, 0xADF8, 0xB8F9)) + ':'    # > 병렬 그룹:
    $group = Get-ProseLines (Find-Section $tasksTitle) | Where-Object { Test-Prefix $_.Text $groupHead } | Select-Object -First 1
    if ($group) {
        $perfLabel = '- **' + (Get-Text @(0xC131, 0xB2A5)) + '**:'    # - **성능**:
        $spec = $group.Text.Substring($groupHead.Length)
        $cut = $spec.IndexOf([char]0x2014)
        if ($cut -ge 0) { $spec = $spec.Substring(0, $cut) }
        $byId = @{}
        foreach ($b in $blocks) { $byId[$b.Id] = $b }
        $gi = 0
        foreach ($g in $spec.Split('|')) {
            $gi++
            $ids = @([regex]::Matches($g, 'T(\d+)') | ForEach-Object { [int]$_.Groups[1].Value })
            if ($ids.Count -lt 2 -or $ids.Count -gt 3) { Add-Problem $group.N ('parallel-size ' + $gi) }
            for ($k = 1; $k -lt $ids.Count; $k++) {
                if ($ids[$k] -ne $ids[$k - 1] + 1) { Add-Problem $group.N ('parallel-order ' + $gi); break }
            }
            $owner = @{}
            foreach ($id in $ids) {
                $tag = 'T' + $id
                $b = $byId[$id]
                if (-not $b) { Add-Problem $group.N ('parallel-task ' + $tag + ' missing'); continue }
                if (@($b.Lines | Where-Object { Test-Prefix $_.Text $screenLabel }).Count) { Add-Problem $group.N ('parallel-task ' + $tag + ' screen') }
                if (@($b.Lines | Where-Object { Test-Prefix $_.Text $perfLabel }).Count) { Add-Problem $group.N ('parallel-task ' + $tag + ' perf') }
                $files = $b.Lines | Where-Object { Test-Prefix $_.Text '- **Files**:' } | Select-Object -First 1
                if (-not $files) { continue }
                $head = $files.Text
                $cut = $head.IndexOf($exempt)
                if ($cut -ge 0) { $head = $head.Substring(0, $cut) }
                $paths = @([regex]::Matches($head, '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value })
                if (@($paths | Where-Object {
                    $_.StartsWith('~') -or ($planTop -and [System.IO.Path]::IsPathRooted($_) -and
                    -not ($_.Replace('\', '/') + '/').StartsWith($planTop, [System.StringComparison]::OrdinalIgnoreCase))
                }).Count) { Add-Problem $group.N ('parallel-task ' + $tag + ' outside') }
                foreach ($p in $paths) {
                    $key = $p.Replace('\', '/').ToLowerInvariant()
                    if ($owner.ContainsKey($key) -and $owner[$key] -ne $tag) { Add-Problem $group.N ('parallel-overlap ' + $owner[$key] + ' ' + $tag) }
                    else { $owner[$key] = $tag }
                }
            }
        }
    }
}

function Find-PlanCheck([string]$PlanFile) {
    $agents = Get-AgentsFile $PlanFile
    if (-not $agents) { return $null }
    for ($i = 0; $i -lt $agents.Lines.Count; $i++) {
        if ($agents.Lines[$i] -match '^- \*\*Plan check\*\*: `([^`]+)`') { return @{ Dir = $agents.Dir; Line = $i + 1; Command = $Matches[1] } }
    }
    return $null
}

function Get-KarinaTempRoot {
    $base = @($env:TMPDIR, $env:TEMP, $env:TMP) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -First 1
    if (-not $base) { $base = [System.IO.Path]::GetTempPath() }
    return (Join-Path $base 'karina-plugin')
}

$planFile = (Resolve-Path -LiteralPath $PlanPath).Path
$pc = Find-PlanCheck $planFile
if ($pc) {
    $utf8 = New-Object System.Text.UTF8Encoding($false)
    $logDir = Join-Path (Get-KarinaTempRoot) 'scratch'
    $logName = 'check-plan-' + (Get-Date -Format 'yyyyMMdd-HHmmss-fff') + '.log'
    $limit = 120
    $n = 0
    if ([int]::TryParse([string]$env:KARINA_PLAN_CHECK_TIMEOUT_SEC, [ref]$n) -and $n -gt 0) { $limit = $n }

    $script = '[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false); ' + $pc.Command + "`n" + 'exit $LASTEXITCODE'
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = (Get-Process -Id $PID).Path
    $psi.Arguments = '-NoProfile -NonInteractive -EncodedCommand ' + [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($script))
    $psi.WorkingDirectory = $pc.Dir
    $psi.UseShellExecute = $false
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = $utf8
    $psi.StandardErrorEncoding = $utf8
    $psi.EnvironmentVariables['KARINA_PLAN_PATH'] = $planFile
    $proc = [System.Diagnostics.Process]::Start($psi)
    $proc.StandardInput.Close()
    $outTask = $proc.StandardOutput.ReadToEndAsync()
    $errTask = $proc.StandardError.ReadToEndAsync()
    $timedOut = -not $proc.WaitForExit($limit * 1000)
    if ($timedOut) {
        # 5.1(.NET Framework)의 Kill() 은 자식만 끝내 손자가 출력 파이프를 쥔 채 남는다.
        if ($PSVersionTable.PSVersion.Major -ge 7) { try { $proc.Kill($true) } catch { } }
        else { $null = & taskkill.exe /T /F /PID $proc.Id 2>&1 }
    }
    $text = ''
    if ($outTask.Wait(5000)) { $text += $outTask.Result }
    if ($errTask.Wait(5000)) { $text += $errTask.Result }
    if ($timedOut -or $proc.ExitCode -ne 0) {
        New-Item -ItemType Directory -Path $logDir -Force | Out-Null
        [System.IO.File]::WriteAllText((Join-Path $logDir $logName), $text, $utf8)
    }
    if ($timedOut) { Add-Problem $pc.Line ('plan-check timeout ' + $limit + ' log ' + $logName) }
    elseif ($proc.ExitCode -ne 0) { Add-Problem $pc.Line ('plan-check exit ' + $proc.ExitCode + ' log ' + $logName) }
    else { Write-Output 'check-plan: ran plan-check exit 0' }
}

Complete-Check
