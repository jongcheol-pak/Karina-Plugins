# comment-scope.ps1 — 회차 끝 주석 정리의 범위 목록·커밋 전 회차 전 주석 되살림 — 근거는 ../SKILL.md「자동 모드」
param(
    [string]$Base = '',
    [string]$Out = '',
    [string]$Repo = '.'
)

$ErrorActionPreference = 'Stop'

function Stop-Scope([string]$Message) {
    [Console]::Error.WriteLine('comment-scope: ' + $Message)
    exit 2
}

if ($PSVersionTable.PSVersion.Major -lt 7) { Stop-Scope 'PowerShell 7 이상이 필요합니다 (pwsh 로 부르세요)' }

[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
. (Join-Path $PSScriptRoot '../../../scripts/comment-lines.ps1')

function Invoke-ScopeGit([string]$Dir, [string[]]$GitArgs) {
    $psi = [System.Diagnostics.ProcessStartInfo]::new('git')
    foreach ($a in @('-C', $Dir, '-c', 'core.quotepath=off') + $GitArgs) { $psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $p = [System.Diagnostics.Process]::Start($psi)
    $outTask = $p.StandardOutput.ReadToEndAsync()
    $null = $p.StandardError.ReadToEndAsync()
    $p.WaitForExit()
    $text = $outTask.Result
    [string[]]$lines = @()
    if ($text -ne '') { $lines = @($text -replace '\r?\n$', '' -split '\r?\n') }
    return @{ Code = $p.ExitCode; Lines = $lines; Text = $text }
}

function Get-ScopeFileText([string]$Root, [string]$Rev, [string]$Rel) {
    $r = Invoke-ScopeGit $Root @('show', "${Rev}:$Rel")
    if ($r.Code -ne 0) { return $null }
    return , ([string[]]@($r.Text -split '\r?\n'))
}

function Get-ScopeBoundary([string]$Root, [string]$BaseSha, [string]$Rel, [string[]]$Range) {
    $flags = @{}
    $r = Invoke-ScopeGit $Root (@('blame', '--line-porcelain', '-M', '-C') + $Range + @("$BaseSha..HEAD", '--', $Rel))
    if ($r.Code -ne 0) { return $flags }
    $final = 0
    $boundary = $false
    foreach ($l in $r.Lines) {
        $m = [regex]::Match($l, '^[0-9a-f]{40} \d+ (\d+)')
        if ($m.Success) { $final = [int]$m.Groups[1].Value; $boundary = $false; continue }
        if ($l -eq 'boundary') { $boundary = $true; continue }
        if ($l.StartsWith("`t")) { $flags[$final] = $boundary }
    }
    return $flags
}

function Get-ScopeBaseBodies([string]$Root, [string]$BaseSha, [string]$Rel) {
    $set = [System.Collections.Generic.HashSet[string]]::new()
    if (-not $Rel) { return , $set }
    $lines = Get-ScopeFileText $Root $BaseSha $Rel
    if ($null -eq $lines) { return , $set }
    foreach ($c in (Get-CommentBodyLines $Rel $lines -KeepDirectives)) { [void]$set.Add($c.Body) }
    return , $set
}

function Resolve-ScopeRepo([string]$Dir) {
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { Stop-Scope "git 레포가 아닙니다: $Dir" }
    $r = Invoke-ScopeGit $Dir @('rev-parse', '--show-toplevel')
    if ($r.Code -ne 0 -or $r.Lines.Count -eq 0) { Stop-Scope "git 레포가 아닙니다: $Dir" }
    return [System.IO.Path]::GetFullPath($r.Lines[0])
}

function Resolve-ScopeBase([string]$Root, [string]$Rev) {
    if (-not $Rev) { Stop-Scope '인자 누락 — -Base <sha>' }
    $r = Invoke-ScopeGit $Root @('rev-parse', '--verify', '-q', "$Rev^{commit}")
    if ($r.Code -ne 0 -or $r.Lines.Count -eq 0) { Stop-Scope "BASE 를 찾을 수 없습니다: $Rev" }
    return $r.Lines[0].Trim()
}

function Test-ScopeKept($Ctx, [string]$Full, [string]$Body) {
    $base = if ($Ctx.Agents) { Split-Path -Parent $Ctx.Agents } else { $Ctx.Dir }
    foreach ($k in $Ctx.KeepRules) {
        if (-not $k.Pattern.IsMatch($Body)) { continue }
        foreach ($p in $k.Paths) { if (Test-CommentPathLike $Full $base $p) { return $true } }
    }
    return $false
}

function Test-ScopeAudited($Ctx, [string]$Full, [string]$Rel, [string[]]$Lines, [int]$Index, [bool[]]$DocFlag) {
    if (-not $DocFlag[$Index]) { return $false }
    $code = Get-CommentDocTarget $Rel $Lines $Index $DocFlag
    if (-not $code) { return $false }
    $base = if ($Ctx.Agents) { Split-Path -Parent $Ctx.Agents } else { $Ctx.Dir }
    foreach ($a in $Ctx.AuditRules) {
        if ($a.Pattern.IsMatch($code) -and (Test-CommentPathLike $Full $base $a.Pathspec)) { return $true }
    }
    return $false
}

function Invoke-ScopeList([string]$Root, [string]$BaseSha, [string]$OutPath) {
    if (-not $OutPath) { Stop-Scope '인자 누락 — -Out <파일>' }
    $listed = New-Object System.Collections.Generic.List[string]
    $pre = 0; $audit = 0; $kept = 0
    $status = Invoke-ScopeGit $Root @('diff', '--name-status', '-M', $BaseSha, 'HEAD')
    foreach ($row in $status.Lines) {
        $cols = $row -split "`t"
        if ($cols.Count -lt 2 -or $cols[0].StartsWith('D')) { continue }
        $rel = $cols[$cols.Count - 1]
        $oldRel = if ($cols[0].StartsWith('R')) { $cols[1] } elseif ($cols[0].StartsWith('A')) { '' } else { $rel }
        if (-not (Test-CommentTarget $rel)) { continue }
        $lines = Get-ScopeFileText $Root 'HEAD' $rel
        if ($null -eq $lines) { continue }
        $comments = Get-CommentBodyLines $rel $lines -KeepDirectives
        if ($comments.Count -eq 0) { continue }
        $boundary = Get-ScopeBoundary $Root $BaseSha $rel @()
        $baseBodies = Get-ScopeBaseBodies $Root $BaseSha $oldRel
        $full = [System.IO.Path]::GetFullPath((Join-Path $Root $rel))
        $ctx = Get-CommentRepoContext $full
        $docFlag = Get-CommentDocFlags $lines
        foreach ($c in $comments) {
            $n = [int]$c.Line
            if ($boundary[$n + 1] -or $baseBodies.Contains($c.Body)) { $pre++; continue }
            if (Test-ScopeKept $ctx $full $c.Body) { $kept++; continue }
            if (Test-ScopeAudited $ctx $full $rel $lines $n $docFlag) { $audit++; continue }
            $listed.Add("${rel}:$($n + 1)`t$($c.Body)")
        }
    }
    $text = if ($listed.Count) { ($listed -join "`n") + "`n" } else { '' }
    [System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($OutPath), $text, [System.Text.UTF8Encoding]::new($false))
    "RESULT: 대상 $($listed.Count) · 회차 전 $pre · 감사 $audit · 보존 $kept"
    exit 0
}

$root = Resolve-ScopeRepo $Repo
$baseSha = Resolve-ScopeBase $root $Base
Invoke-ScopeList $root $baseSha $Out
