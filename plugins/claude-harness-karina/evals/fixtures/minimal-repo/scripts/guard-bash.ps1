$planFenceRx = '(?ms)^ {0,3}([`~])\1{2,}[^\r\n]*\r?$.*?(?:^ {0,3}\1{3}[^\r\n]*\r?$|\z)'
$planBulletRx = '(?m)^\s*([-*+]|\d+[.)])\s*'

function Split-TopLevel([string]$s, [bool]$PsQuoting = $false) {
    $parts = New-Object System.Collections.Generic.List[string]
    $cur = ''
    $q = $null
    foreach ($ch in $s.ToCharArray()) {
        if ($q) {
            $cur += $ch
            if ($ch -eq $q) { $q = $null }
        } elseif ($ch -eq '"' -or $ch -eq "'") {
            $q = $ch; $cur += $ch
        } elseif ($ch -eq ';' -or $ch -eq '|') {
            $parts.Add($cur); $cur = ''
        } else {
            $cur += $ch
        }
    }
    $parts.Add($cur)
    return $parts
}

# heredoc 정규식 — 같은 축의 리터럴 묶음 대상
$script:HeredocBlockRx = '(?m)^(?<line>[^\r\n]*<<-?\s*(?<q>["'']?)(?<tag>\w+)\k<q>[^\r\n]*)\r?\n(?<body>[\s\S]*?)\r?\n[ \t]*\k<tag>[ \t]*(?=\r?\n|$)'
$installedWtRx = '(?i)^.*/\.claude/worktrees/[^/]+'
$installedAssetRx = '(?i)/\.claude/.*/(hooks\.json|scripts/rules/[^/]+\.json|scripts/[^/]+\.ps1)$'

function Test-WorktreeGitFile([string]$dir) {
    $gf = Join-Path $dir '.git'
    if (-not (Test-Path -LiteralPath $gf -PathType Leaf)) { return $false }
    $first = [string](@(Get-Content -LiteralPath $gf -TotalCount 1 -ErrorAction SilentlyContinue)[0])
    return ($first -match '^gitdir:.*[\\/]worktrees[\\/]')
}
