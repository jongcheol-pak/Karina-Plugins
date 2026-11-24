# plan-round.ps1 — plan 상향 탐색과 승인된 회차 진행 중 판정 (dot-source 전용, hook 아님) — 근거는 `rules/bash-guard-rationale.md` §13

# worktree 의 `.git` 파일(`gitdir: …/worktrees/…`)만 레포 경계로 본다 — 서브모듈(`…/modules/…`)은 아니다 — 근거는 `rules/bash-guard-rationale.md` §20
function Test-WorktreeGitFile([string]$dir) {
    $gf = Join-Path $dir '.git'
    if (-not (Test-Path -LiteralPath $gf -PathType Leaf)) { return $false }
    $first = [string](@(Get-Content -LiteralPath $gf -TotalCount 1 -ErrorAction SilentlyContinue)[0])
    return ($first -match '^gitdir:.*[\\/]worktrees[\\/]')
}
function Find-SinglePlanUpwards {
    param([string]$StartDir, [int]$MaxDepth = 8)
    if ([string]::IsNullOrEmpty($StartDir)) { return $null }
    $dir = $StartDir
    for ($i = 0; $i -lt $MaxDepth; $i++) {
        if (-not $dir) { break }
        foreach ($cand in @('plan.md', 'PLAN.md', 'docs/plan.md')) {
            $pf = Join-Path $dir $cand
            if (Test-Path -LiteralPath $pf -PathType Leaf) { return $pf }
        }
        if ((Test-Path -LiteralPath (Join-Path $dir '.git') -PathType Container) -or
            (Test-WorktreeGitFile $dir) -or
            (Test-Path -LiteralPath (Join-Path $dir '.claude') -PathType Container)) {
            return $null
        }
        $parent = [System.IO.Path]::GetDirectoryName($dir)
        if ($parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}

# worktree 에서 본 레포의 plan 까지 따라간다 (외부 작업 경고 전용) — 근거는 `rules/bash-guard-rationale.md` §13
function Find-RoundPlan {
    param([string]$StartDir)
    $found = Find-SinglePlanUpwards -StartDir $StartDir
    if ($found -or [string]::IsNullOrEmpty($StartDir)) { return $found }
    $dir = $StartDir
    for ($i = 0; $i -lt 8 -and $dir; $i++) {
        if (Test-WorktreeGitFile $dir) {
            $first = [string](@(Get-Content -LiteralPath (Join-Path $dir '.git') -TotalCount 1 -ErrorAction SilentlyContinue)[0])
            if ($first -notmatch '^gitdir:\s*(.+?)[\\/]\.git[\\/]worktrees[\\/][^\\/]+\s*$') { return $null }
            $main = $Matches[1]
            $rel = $StartDir.Substring($dir.Length).TrimStart('\', '/')
            $mapped = if ($rel) { Join-Path $main $rel } else { $main }
            if (Test-Path -LiteralPath $mapped -PathType Container) {
                $found = Find-SinglePlanUpwards -StartDir $mapped
                if ($found) { return $found }
            }
            $parent = [System.IO.Path]::GetDirectoryName($dir.TrimEnd('\', '/'))
            if ($parent) { return Find-SinglePlanUpwards -StartDir $parent }
            return $null
        }
        if (Test-Path -LiteralPath (Join-Path $dir '.git') -PathType Container) { return $null }
        $up = [System.IO.Path]::GetDirectoryName($dir.TrimEnd('\', '/'))
        if (-not $up -or $up -eq $dir) { break }
        $dir = $up
    }
    return $null
}

function Test-ActivePlanRound {
    param([string]$PlanFile, [datetime]$Now = (Get-Date))
    if ([string]::IsNullOrEmpty($PlanFile) -or -not (Test-Path -LiteralPath $PlanFile -PathType Leaf)) { return $false }
    try { $text = [System.IO.File]::ReadAllText($PlanFile) } catch { return $false }
    if ($text -notmatch '(?m)^> 승인: \d{4}-\d{2}-\d{2}') { return $false }
    $done = [regex]::Match($text, '(?m)^> 완료: (\d{4}-\d{2}-\d{2})')
    if (-not $done.Success) { return $true }
    return ($done.Groups[1].Value -eq $Now.ToString('yyyy-MM-dd'))
}
