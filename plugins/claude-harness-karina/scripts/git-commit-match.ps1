# git-commit-match.ps1 — git 커밋·add 명령 판정식과 커밋이 도는 레포 해석 (dot-source 전용, hook 아님) — 근거는 `rules/bash-guard-rationale.md` §18

$script:GitOptValueRx = '(?:"[^"]*"|''[^'']*''|[^\s"'';&|]+)'
$script:GitGlobalOptsRx = '(?:\s+(?:-[cC]\s+' + $script:GitOptValueRx +
    '|--(?:git-dir|work-tree|namespace|exec-path|config-env|super-prefix)\s+' + $script:GitOptValueRx +
    '|-{1,2}[A-Za-z][\w-]*(?:=' + $script:GitOptValueRx + ')?))*'
$script:GitCommitRx = 'git' + $script:GitGlobalOptsRx + '\s+commit(?![\w-])'
$script:GitAddRx = 'git' + $script:GitGlobalOptsRx + '\s+add(?![\w-])'

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
