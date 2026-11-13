$planBulletRx = '(?m)^\s*([-*+]|\d+[.)])\s*'
$planFenceRx = '(?ms)^ {0,3}([`~])\1{2,}[^\r\n]*\r?$.*?(?:^ {0,3}\1{3}[^\r\n]*\r?$|\z)'

function Test-WorktreeGitFile([string]$dir) {
    $gf = Join-Path $dir '.git'
    if (-not (Test-Path -LiteralPath $gf -PathType Leaf)) { return $false }
    $first = [string](@(Get-Content -LiteralPath $gf -TotalCount 1 -ErrorAction SilentlyContinue)[0])
    return ($first -match '^gitdir:.*[\\/]worktrees[\\/]')
}
