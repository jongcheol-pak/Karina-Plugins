# git-commit-match.ps1 — git 커밋·add 명령 판정식과 커밋이 도는 레포 해석 (dot-source 전용, hook 아님) — 근거는 `rules/bash-guard-rationale.md` §18

$script:GitOptValueRx = '(?:"[^"]*"|''[^'']*''|[^\s"'';&|]+)'
$script:GitGlobalOptsRx = '(?:\s+(?:-[cC]\s+' + $script:GitOptValueRx +
    '|--(?:git-dir|work-tree|namespace|exec-path|config-env|super-prefix)\s+' + $script:GitOptValueRx +
    '|-{1,2}[A-Za-z][\w-]*(?:=' + $script:GitOptValueRx + ')?))*'
$script:GitCommitRx = 'git' + $script:GitGlobalOptsRx + '\s+commit(?![\w-])'
$script:GitAddRx = 'git' + $script:GitGlobalOptsRx + '\s+add(?![\w-])'

# 커밋 경로 git 호출 — 호출당 시간 상한·같은 호출 캐시 — 근거는 `rules/bash-guard-rationale.md` §18
if ($null -eq $script:CommitGitCache) {
    $script:CommitGitCache = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::Ordinal)
    $script:CommitGitTimedOut = @{}
    $script:CommitGitHung = $false
}
function Get-CommitGitLimitMs {
    if ($env:KARINA_COMMIT_GIT_TIMEOUT_MS -match '^\d+$' -and [int]$env:KARINA_COMMIT_GIT_TIMEOUT_MS -gt 0) { return [int]$env:KARINA_COMMIT_GIT_TIMEOUT_MS }
    return 20000
}
function Test-CommitGitTimedOut([string]$Check) { return [bool]$script:CommitGitTimedOut[$Check] }
function Get-CommitGitTimeoutLines([string]$What) {
    return @(
        "[HARNESS] BLOCKED: git 이 시간 상한($(Get-CommitGitLimitMs)ms) 안에 답하지 않아 $What 을 하지 못했습니다.",
        '  - 같은 커밋을 다시 내세요 — 일시적인 지연(동시 git·백신 검사)이면 다음 시도는 통과합니다.',
        '  - 계속 막히면 그 레포의 git 상태(index.lock·아주 큰 diff)를 확인하고, 그래도 안 되면 멈추고 사용자에게 보고하세요.')
}
function Invoke-CommitGit {
    param([string]$Check, [string[]]$GitArgs, [string]$Dir = (Get-Location).ProviderPath)
    $key = $Dir + [char]0 + (@($GitArgs) -join [char]0)
    $hit = $null
    if ($script:CommitGitCache.TryGetValue($key, [ref]$hit)) { return $hit }
    if ($script:CommitGitHung) {
        $script:CommitGitTimedOut[$Check] = $true
        return [pscustomobject]@{ Code = -1; Lines = @(); TimedOut = $true }
    }
    if (-not (Get-Command Invoke-TimedGit -ErrorAction SilentlyContinue)) { return [pscustomobject]@{ Code = -1; Lines = @(); TimedOut = $false } }
    $run = Invoke-TimedGit -GitArgs $GitArgs -WorkDir $Dir -TimeoutMs (Get-CommitGitLimitMs)
    if ($run.TimedOut) { $script:CommitGitTimedOut[$Check] = $true; $script:CommitGitHung = $true } else { $script:CommitGitCache[$key] = $run }
    return $run
}

function Join-GitCommitPath([string]$base, [string]$token) {
    $p = $token.Trim('"', "'")
    if ($p -match '^/([A-Za-z])/(.*)$') { $p = $Matches[1] + ':\' + ($Matches[2] -replace '/', '\') }
    if ([System.IO.Path]::IsPathRooted($p)) { return $p }
    return (Join-Path $base $p)
}

# 커밋이 도는 레포 폴더 — 근거는 `rules/bash-guard-rationale.md` §19
function Resolve-GitCommitDir([string]$cmd, [string]$cwd) {
    if ([string]::IsNullOrEmpty($cwd)) { return $cwd }
    $m = [regex]::Match($cmd, $script:GitCommitRx)
    if (-not $m.Success) { return $cwd }
    $dir = $cwd
    $cdRx = '(?i)(?:^|[;&|(]|\s)(?:cd|pushd|Set-Location|Push-Location)\s+(?:-(?:Literal)?Path\s+)?(' + $script:GitOptValueRx + ')'
    foreach ($c in [regex]::Matches($cmd.Substring(0, $m.Index), $cdRx)) { $dir = Join-GitCommitPath $dir $c.Groups[1].Value }
    foreach ($c in [regex]::Matches($m.Value, '\s-C\s+(' + $script:GitOptValueRx + ')')) { $dir = Join-GitCommitPath $dir $c.Groups[1].Value }
    if (Test-Path -LiteralPath $dir -PathType Container) { return (Resolve-Path -LiteralPath $dir).ProviderPath }
    return $cwd
}
