# 픽스처용 최소 hook — 추출 앵커 축이 이 파일을 파싱한다.
$sectionMaxBytes = 4000
$skillsDir = Join-Path $PSScriptRoot '..' 'skills'
$s = Get-SkillSection -Path (Join-Path $skillsDir 'sample/SKILL.md') -StartHeading '## 주입 대상 절' -StopHeading '## 그다음 절'
Write-Output $s

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
