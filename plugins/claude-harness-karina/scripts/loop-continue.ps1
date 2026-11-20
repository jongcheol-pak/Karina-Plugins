# loop-continue.ps1 — 자율 루프가 plan 미완 task 나 회차 끝 4번 검증을 남기고 멈추면 계속을 주입한다 — 근거는 `rules/loop-continue-rationale.md` §1

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
try { [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

$base = if ([string]::IsNullOrEmpty($env:USERPROFILE)) { $HOME } else { $env:USERPROFILE }
$stateDir = Join-Path $base '.claude/.state/loop-continue'
# 같은 미완 집합에 주입하는 횟수의 상한 — 근거는 `rules/loop-continue-rationale.md` §2
$MaxPerSet = 2
$ImplementRx = '^(karina:)?implement$'
$PlanRx = '^(karina:)?plan$'

# 판정 불가는 전부 침묵이다 — 근거는 `rules/loop-continue-rationale.md` §3
try { $data = $(if ($null -ne $global:KarinaHookStdin) { $global:KarinaHookStdin } else { [Console]::In.ReadToEnd() }) | ConvertFrom-Json -ErrorAction Stop } catch { exit 0 }
if (-not $data) { exit 0 }
$sid = [string]$data.session_id
if ([string]::IsNullOrWhiteSpace($sid)) { exit 0 }
$sidSafe = $sid -replace '[^A-Za-z0-9._-]', '_'
$marker = Join-Path $stateDir ($sidSafe + '.active')

function Set-ActiveMarker {
    try { New-Item -Force -ItemType Directory -Path $stateDir -ErrorAction Stop | Out-Null } catch { return }
    try { Set-Content -LiteralPath $marker -Value (Get-Date -Format o) -Encoding UTF8 -ErrorAction Stop } catch {}
}

function Clear-ActiveMarker {
    try { Remove-Item -LiteralPath $marker -Force -ErrorAction Stop } catch {}
}

# plan 탐색과 미완 판정식 — session-context.ps1 과 같은 글자의 사본이다 — 근거는 `rules/loop-continue-rationale.md` §4
$planBulletRx = '(?m)^\s*([-*+]|\d+[.)])\s*'
$planFenceRx = '(?ms)^ {0,3}([`~])\1{2,}[^\r\n]*\r?$.*?(?:^ {0,3}\1{3}[^\r\n]*\r?$|\z)'
function Find-PlanFileUpwards([string]$StartDir, [int]$MaxDepth = 8) {
    if ([string]::IsNullOrEmpty($StartDir)) { return $null }
    $base = [System.IO.Path]::GetFullPath($StartDir).TrimEnd('\', '/')
    $dir = $base
    for ($i = 0; $i -lt $MaxDepth; $i++) {
        if (-not $dir) { break }
        foreach ($cand in @('plan.md', 'PLAN.md', 'docs/plan.md')) {
            $pf = Join-Path $dir $cand
            if (Test-Path -LiteralPath $pf -PathType Leaf) {
                $label = if ($dir -eq $base) { $cand } else { $pf }
                return @{ Path = $pf; Label = $label }
            }
        }
        if ((Test-Path -LiteralPath (Join-Path $dir '.git')) -or
            (Test-Path -LiteralPath (Join-Path $dir '.claude') -PathType Container)) {
            return $null
        }
        $parent = [System.IO.Path]::GetDirectoryName($dir)
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

function Get-OpenTaskIds([string]$planText) {
    $ms = [regex]::Matches([regex]::Replace($planText, $planFenceRx, ''), $planBulletRx + '\[[ /~-]\][ \t]*\**(?<id>T\d+(?:-\d+)?)')
    return @($ms | ForEach-Object { $_.Groups['id'].Value })
}

# Gate 재사용 경로 선언 읽기 — 근거는 `rules/loop-continue-rationale.md` §8
function Get-GateReuse([string]$PlanDir, [string]$TopDir) {
    $none = @{ Dir = $PlanDir; Globs = @() }
    $stop = ''
    try { $stop = [System.IO.Path]::GetFullPath($TopDir).TrimEnd('\', '/') } catch { return $none }
    $cur = [System.IO.Path]::GetFullPath($PlanDir).TrimEnd('\', '/')
    for ($i = 0; $i -lt 8 -and $cur; $i++) {
        $agents = Join-Path $cur 'AGENTS.md'
        if (Test-Path -LiteralPath $agents -PathType Leaf) {
            $text = ''
            try { $text = Get-Content -LiteralPath $agents -Raw -Encoding UTF8 -ErrorAction Stop } catch { return $none }
            $line = [regex]::Match([string]$text, '(?m)^- \*\*Gate 재사용 경로\*\*:(.*)$')
            if (-not $line.Success) { return $none }
            $globs = @([regex]::Matches($line.Groups[1].Value, '`([^`]+)`') | ForEach-Object { $_.Groups[1].Value.Trim() } | Where-Object { $_ })
            return @{ Dir = $cur; Globs = $globs }
        }
        if ($cur.Equals($stop, [System.StringComparison]::OrdinalIgnoreCase)) { break }
        $cur = [System.IO.Path]::GetDirectoryName($cur)
    }
    return $none
}

# 회차 끝 판정 — 근거는 `rules/loop-continue-rationale.md` §7
function Get-FinalCheckGap([string]$PlanPath, [string]$PlanText) {
    $body = [regex]::Replace($PlanText, $planFenceRx, '')
    if ($body -notmatch '(?m)^> 승인: [0-9]{4}-') { return $null }
    if ($body -notmatch ($planBulletRx + '\[[xX]\][ \t]*\**T\d+')) { return $null }
    $req = [regex]::Match($body, '(?m)^> 요구:.*$')
    if ($req.Success -and $req.Value.Contains('코디네이터 인터뷰 경유')) { return $null }
    try { . (Join-Path $PSScriptRoot 'timed-git.ps1') } catch { return $null }
    if (-not (Get-Command Invoke-TimedGit -ErrorAction SilentlyContinue)) { return $null }
    $dir = Split-Path -Parent $PlanPath
    $rp = Invoke-TimedGit -GitArgs @('rev-parse', 'HEAD', '--show-toplevel', '--show-prefix') -WorkDir $dir -TimeoutMs 3000
    if ($rp.Code -ne 0 -or $rp.Lines.Count -lt 2 -or $rp.Lines[0] -notmatch '^[0-9a-f]{40}$') { return $null }
    $head = [string]$rp.Lines[0]
    $top = [string]$rp.Lines[1]
    $prefix = if ($rp.Lines.Count -gt 2) { [string]$rp.Lines[2] } else { '' }
    $log = [regex]::Match($body, '(?ms)^## Progress Log[^\n]*\n(.*?)(?=^## |\z)')
    $shas = @()
    if ($log.Success) { $shas = @([regex]::Matches($log.Groups[1].Value, '4번 검증: ([0-9a-f]{40})') | ForEach-Object { $_.Groups[1].Value }) }
    if ($shas.Count -eq 0) { return @{ Head = $head; Files = @() } }
    if ($shas[-1] -eq $head) { return $null }
    $gate = Get-GateReuse $dir $top
    $diffArgs = @('-c', 'core.quotepath=off', 'diff', '--name-only', ($shas[-1] + '..HEAD'))
    if ($gate.Globs.Count -gt 0) { $diffArgs += @('--', ':/') + @($gate.Globs | ForEach-Object { ':(exclude,glob)' + $_ }) }
    $df = Invoke-TimedGit -GitArgs $diffArgs -WorkDir $gate.Dir -TimeoutMs 3000
    if ($df.Code -ne 0) { return $null }
    $planRel = $prefix + (Split-Path -Leaf $PlanPath)
    $files = @($df.Lines | Where-Object { $_ -and $_ -ne $planRel })
    if ($files.Count -eq 0) { return $null }
    return @{ Head = $head; Files = $files }
}

function Get-SetKey([string[]]$ids) {
    $sha = [System.Security.Cryptography.SHA1]::Create()
    $bytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes(($ids -join ',')))
    return (($bytes | ForEach-Object { $_.ToString('x2') }) -join '').Substring(0, 12)
}

$hookEvent = [string]$data.hook_event_name

# 발동 마커는 Skill 도구 호출과 슬래시 직접 입력 두 경로에서 선다 — 근거는 `rules/loop-continue-rationale.md` §6
if ($hookEvent -eq 'PreToolUse') {
    if ([string]$data.tool_name -ne 'Skill') { exit 0 }
    $skill = [string]$data.tool_input.skill
    if ($skill -match $ImplementRx) { Set-ActiveMarker }
    elseif ($skill -match $PlanRx) { Clear-ActiveMarker }
    exit 0
}
if ($hookEvent -eq 'UserPromptExpansion') {
    $cmdName = [string]$data.command_name
    if ($cmdName -match $ImplementRx) { Set-ActiveMarker }
    elseif ($cmdName -match $PlanRx) { Clear-ActiveMarker }
    exit 0
}
if ($hookEvent -ne 'Stop') { exit 0 }

if (-not (Test-Path -LiteralPath $marker)) { exit 0 }
if ($data.stop_hook_active -eq $true) { exit 0 }
$bg = @($data.background_tasks | Where-Object { $_ })
if ($bg.Count -gt 0) { exit 0 }

$cwd = [string]$data.cwd
if ([string]::IsNullOrWhiteSpace($cwd)) { exit 0 }
$planHit = Find-PlanFileUpwards -StartDir $cwd
if (-not $planHit) { exit 0 }
try { $planText = Get-Content -LiteralPath $planHit.Path -Raw -Encoding UTF8 -ErrorAction Stop } catch { exit 0 }
$ids = @(Get-OpenTaskIds $planText)
$gap = $null
if ($ids.Count -eq 0) {
    $gap = Get-FinalCheckGap $planHit.Path $planText
    if (-not $gap) { exit 0 }
}

$setKey = if ($gap) { Get-SetKey @('final', $gap.Head) } else { Get-SetKey $ids }
$counter = Join-Path $stateDir ($sidSafe + '.' + $setKey + '.count')
$n = 0
try { $n = [int](Get-Content -LiteralPath $counter -Raw -ErrorAction Stop).Trim() } catch { $n = 0 }
if ($n -ge $MaxPerSet) { exit 0 }
try { Set-Content -LiteralPath $counter -Value ($n + 1) -Encoding UTF8 -ErrorAction Stop } catch { exit 0 }

$keep = "implement 「멈추는 넷」·「목록 밖의 넷」에 해당하는 정지(승인 대기 등)이거나 사용자가 중단을 지시한 경우라면 그 정지를 유지합니다."
if ($gap) {
    $what = if ($gap.Files.Count -eq 0) {
        "Progress Log 에 「4번 검증: <full SHA> · clean」 줄이 없습니다. 회차 끝 단계(implement references/final-review.md 「완료 순서」 — 리뷰·4번 검증·push 전 확인·최종 보고)가 남았으면 이어서 진행하십시오."
    } else {
        $shownFiles = ($gap.Files | Select-Object -First 5) -join ', '
        $moreFiles = if ($gap.Files.Count -gt 5) { " 외 $($gap.Files.Count - 5)개" } else { '' }
        "Progress Log 의 「4번 검증」 줄 뒤에 plan 파일 밖 변경이 커밋됐습니다: ${shownFiles}${moreFiles}. 4번 검증을 최종 HEAD 에서 다시 돌리고 그 줄을 새 SHA 로 남기십시오(문서만 바꾼 커밋도 같습니다 — AGENTS.md 의 「Gate 재사용 경로」 에 걸리는 변경만 뺐습니다)."
    }
    $msg = "[karina loop-continue] $($planHit.Label) 의 task 는 모두 닫혔는데 $what $keep 회차가 이미 끝났고 이 커밋이 회차 밖이면 이 안내를 무시합니다."
} else {
    $shown = ($ids | Select-Object -First 5) -join ', '
    $more = if ($ids.Count -gt 5) { " 외 $($ids.Count - 5)개" } else { '' }
    $msg = "[karina loop-continue] $($planHit.Label) 에 미완 task 가 남은 채 turn 이 끝났습니다: ${shown}${more}. " +
        "사용자 답에 의존하지 않는 다음 task 를 이어서 진행하십시오. 막혔다면 무엇이 막는지 한 줄로 말하십시오 — " + $keep
}
$out = @{ hookSpecificOutput = @{ hookEventName = 'Stop'; additionalContext = $msg } }
[Console]::Out.Write(($out | ConvertTo-Json -Compress -Depth 4))
exit 0
