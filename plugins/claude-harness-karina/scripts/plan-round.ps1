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

function Test-ActivePlanRound {
    param([string]$PlanFile, [datetime]$Now = (Get-Date))
    if ([string]::IsNullOrEmpty($PlanFile) -or -not (Test-Path -LiteralPath $PlanFile -PathType Leaf)) { return $false }
    try { $text = [System.IO.File]::ReadAllText($PlanFile) } catch { return $false }
    if ($text -notmatch '(?m)^> 승인: \d{4}-\d{2}-\d{2}') { return $false }
    $done = [regex]::Match($text, '(?m)^> 완료: (\d{4}-\d{2}-\d{2})')
    if (-not $done.Success) { return $true }
    return ($done.Groups[1].Value -eq $Now.ToString('yyyy-MM-dd'))
}
