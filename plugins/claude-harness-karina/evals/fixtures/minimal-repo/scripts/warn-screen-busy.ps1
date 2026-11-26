function Get-KarinaTempRoot {
    $base = @($env:TMPDIR, $env:TEMP, $env:TMP) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -First 1
    if (-not $base) { $base = [System.IO.Path]::GetTempPath() }
    return (Join-Path $base 'karina-plugin')
}

function Test-WorktreeGitFile([string]$dir) {
    $gf = Join-Path $dir '.git'
    if (-not (Test-Path -LiteralPath $gf -PathType Leaf)) { return $false }
    $first = [string](@(Get-Content -LiteralPath $gf -TotalCount 1 -ErrorAction SilentlyContinue)[0])
    return ($first -match '^gitdir:.*[\\/]worktrees[\\/]')
}
