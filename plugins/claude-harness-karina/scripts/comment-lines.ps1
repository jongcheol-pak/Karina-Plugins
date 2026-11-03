# comment-lines.ps1 — 새 주석 줄 판별 (dot-source 전용) — 근거는 `rules/post-write-rationale.md` §22

$script:CommentSlashExts = @('.cs', '.ts', '.tsx', '.js', '.jsx', '.java', '.go', '.rs', '.cpp', '.c', '.h', '.hpp', '.fs', '.kt', '.swift')
$script:CommentHashExts = @('.py', '.ps1', '.sh')
$script:CommentExemptRx = '(?i)^(eslint-|prettier-ignore|@ts-|noqa|type:\s*ignore|pylint:|pyright:|mypy:|nolint|istanbul ignore|c8 ignore|biome-ignore|resharper|fmt:\s*(off|on)\b|isort:|<reference|spdx-license-identifier|copyright|@license|-\*-\s*coding)'

function Test-CommentTarget([string]$Path) {
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    return ($script:CommentSlashExts -contains $ext) -or ($script:CommentHashExts -contains $ext)
}

function Get-CommentBodies([string]$Path, [string[]]$Lines) {
    $bodies = New-Object System.Collections.Generic.List[string]
    if (-not (Test-CommentTarget $Path) -or $null -eq $Lines) { return , $bodies }
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    $isSlash = $script:CommentSlashExts -contains $ext
    $rawExempt = if ($isSlash) { '^//(go:|\s*#(end)?region\b)' } elseif ($ext -eq '.ps1') { '(?i)^#(requires|(end)?region)\b' } else { '(?!)' }
    $inBlock = $false
    foreach ($line in $Lines) {
        $t = ([string]$line).Trim()
        $body = $null
        if ($inBlock) {
            $body = $t -replace '^\*+(?!/)', ''
            if ($t -match '\*/|#>') { $inBlock = $false }
        } elseif ($isSlash -and $t.StartsWith('//')) {
            $body = $t -replace '^/{2,}!?', ''
        } elseif ($isSlash -and $t.StartsWith('/*')) {
            $body = $t -replace '^/\*+!?', ''
            $inBlock = -not ($body -match '\*/')
        } elseif ((-not $isSlash) -and $ext -eq '.ps1' -and $t.StartsWith('<#')) {
            $body = $t.Substring(2)
            $inBlock = -not ($body -match '#>')
        } elseif ((-not $isSlash) -and $t.StartsWith('#') -and -not $t.StartsWith('#!')) {
            $body = $t -replace '^#+', ''
        }
        if ($null -eq $body) { continue }
        $body = ($body -replace '(\*/|#>)\s*$', '').Trim()
        if ($body -eq '' -or $body -match $script:CommentExemptRx -or $t -match $rawExempt) { continue }
        $bodies.Add($t)
    }
    return , $bodies
}

function Get-AddedCommentBodies([string]$Path, $Pairs) {
    $added = New-Object System.Collections.Generic.List[string]
    foreach ($pair in $Pairs) {
        $oldSet = New-Object System.Collections.Generic.HashSet[string]
        foreach ($o in ([string]$pair[0] -split '\r?\n')) { [void]$oldSet.Add($o.Trim()) }
        foreach ($c in (Get-CommentBodies $Path ([string]$pair[1] -split '\r?\n'))) {
            if (-not $oldSet.Contains($c)) { $added.Add($c) }
        }
    }
    return , $added
}
