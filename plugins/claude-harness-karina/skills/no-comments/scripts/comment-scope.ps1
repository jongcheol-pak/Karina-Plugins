# comment-scope.ps1 — 회차 끝 주석 정리의 범위 목록·커밋 전 회차 전 주석 되살림 — 근거는 ../SKILL.md「자동 모드」
param(
    [string]$Base = '',
    [string]$Out = '',
    [string]$Repo = '.',
    [string]$Snapshot = '',
    [switch]$CheckDeletions,
    [string]$Before = '',
    [switch]$Restore
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

function Invoke-ScopeSnapshot([string]$Root, [string]$OutPath) {
    $paths = [System.Collections.Generic.SortedSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($l in (Invoke-ScopeGit $Root @('diff', '--name-only', 'HEAD')).Lines) { if ($l) { [void]$paths.Add($l) } }
    foreach ($l in (Invoke-ScopeGit $Root @('ls-files', '--others', '--exclude-standard')).Lines) { if ($l) { [void]$paths.Add($l) } }
    $text = if ($paths.Count) { (@($paths) -join "`n") + "`n" } else { '' }
    [System.IO.File]::WriteAllText([System.IO.Path]::GetFullPath($OutPath), $text, [System.Text.UTF8Encoding]::new($false))
    "RESULT: 스냅숏 $($paths.Count)"
    exit 0
}

function Get-ScopeDeletionHunks([string]$Root) {
    $files = [ordered]@{}
    $cur = $null
    $hunk = $null
    foreach ($l in (Invoke-ScopeGit $Root @('diff', '-U0', '--no-color', '--no-ext-diff', 'HEAD')).Lines) {
        if ($l.StartsWith('diff --git ')) { $cur = $null; $hunk = $null; continue }
        if ($l.StartsWith('+++ ')) {
            $cur = if ($l -eq '+++ /dev/null') { $null } else { $l.Substring(6) }
            if ($cur -and -not $files.Contains($cur)) { $files[$cur] = New-Object System.Collections.Generic.List[object] }
            continue
        }
        $m = [regex]::Match($l, '^@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@')
        if ($m.Success) {
            $hunk = $null
            $newCount = if ($m.Groups[4].Success) { [int]$m.Groups[4].Value } else { 1 }
            if ($cur -and $newCount -eq 0) {
                $hunk = @{ Old = [int]$m.Groups[1].Value; After = [int]$m.Groups[3].Value; Lines = New-Object System.Collections.Generic.List[string] }
                $files[$cur].Add($hunk)
            }
            continue
        }
        if ($hunk -and $l.StartsWith('-')) { $hunk.Lines.Add($l.Substring(1)) }
    }
    return $files
}

function Restore-ScopeLines([string]$Full, $Inserts) {
    $bytes = [System.IO.File]::ReadAllBytes($Full)
    $bom = $bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF
    $text = [System.Text.UTF8Encoding]::new($false).GetString($bytes, $(if ($bom) { 3 } else { 0 }), $bytes.Length - $(if ($bom) { 3 } else { 0 }))
    $nl = if ($text.Contains("`r`n")) { "`r`n" } else { "`n" }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.AddRange([string[]]($text -split '\r?\n'))
    foreach ($ins in @($Inserts | Sort-Object { $_.After } -Descending)) {
        $lines.InsertRange([Math]::Min($ins.After, $lines.Count), [string[]]$ins.Lines)
    }
    $out = [System.Text.UTF8Encoding]::new($false).GetBytes(($lines -join $nl))
    if ($bom) { $out = [byte[]](0xEF, 0xBB, 0xBF) + $out }
    [System.IO.File]::WriteAllBytes($Full, $out)
}

function Invoke-ScopeCheck([string]$Root, [string]$BaseSha, [string]$BeforePath, [bool]$DoRestore) {
    if (-not $BeforePath -or -not (Test-Path -LiteralPath $BeforePath -PathType Leaf)) { Stop-Scope '인자 누락 — -Before <스냅숏 파일>' }
    $before = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($l in [System.IO.File]::ReadAllLines([System.IO.Path]::GetFullPath($BeforePath))) { if ($l) { [void]$before.Add($l.Trim()) } }
    $restored = 0; $roundDel = 0; $skipped = 0
    $oldPaths = @{}
    foreach ($row in (Invoke-ScopeGit $Root @('diff', '--name-status', '-M', $BaseSha, 'HEAD')).Lines) {
        $cols = $row -split "`t"
        if ($cols.Count -ge 3 -and $cols[0].StartsWith('R')) { $oldPaths[$cols[2]] = $cols[1] }
    }
    $files = Get-ScopeDeletionHunks $Root
    foreach ($rel in $files.Keys) {
        if ($files[$rel].Count -eq 0 -or -not (Test-CommentTarget $rel)) { continue }
        if ($before.Contains($rel)) { $skipped++; continue }
        $baseBodies = $null
        $inserts = New-Object System.Collections.Generic.List[object]
        foreach ($h in $files[$rel]) {
            $comments = Get-CommentBodyLines $rel ([string[]]$h.Lines) -KeepDirectives
            if ($comments.Count -eq 0) { continue }
            $boundary = Get-ScopeBoundary $Root $BaseSha $rel @('-L', "$($h.Old),+$($h.Lines.Count)")
            if ($null -eq $baseBodies) { $baseBodies = Get-ScopeBaseBodies $Root $BaseSha $(if ($oldPaths.ContainsKey($rel)) { $oldPaths[$rel] } else { $rel }) }
            $isComment = @{}
            foreach ($c in $comments) { $isComment[[int]$c.Line] = $c.Body }
            $keep = New-Object System.Collections.Generic.List[string]
            for ($i = 0; $i -lt $h.Lines.Count; $i++) {
                if (-not $isComment.ContainsKey($i)) { continue }
                if ($boundary[$h.Old + $i] -or $baseBodies.Contains($isComment[$i])) {
                    $keep.Add($h.Lines[$i])
                    "RESTORE ${rel}:$($h.Old + $i)`t$($isComment[$i])"
                } else { $roundDel++ }
            }
            if ($keep.Count) { $restored += $keep.Count; $inserts.Add(@{ After = $h.After; Lines = $keep.ToArray() }) }
        }
        if ($DoRestore -and $inserts.Count) { Restore-ScopeLines ([System.IO.Path]::GetFullPath((Join-Path $Root $rel))) $inserts }
    }
    "RESULT: 되살림 $restored · 회차 삭제 $roundDel · 건너뜀 $skipped"
    exit $(if ($restored) { 1 } else { 0 })
}

$root = Resolve-ScopeRepo $Repo
if ($Snapshot) { Invoke-ScopeSnapshot $root $Snapshot }
$baseSha = Resolve-ScopeBase $root $Base
if ($CheckDeletions) { Invoke-ScopeCheck $root $baseSha $Before ([bool]$Restore) }
Invoke-ScopeList $root $baseSha $Out
