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

function Start-ScopeGit([string]$Dir, [string[]]$GitArgs) {
    $psi = [System.Diagnostics.ProcessStartInfo]::new('git')
    foreach ($a in @('-C', $Dir, '-c', 'core.quotepath=off') + $GitArgs) { $psi.ArgumentList.Add($a) }
    $psi.UseShellExecute = $false
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $p = [System.Diagnostics.Process]::Start($psi)
    return @{ Process = $p; Out = $p.StandardOutput.ReadToEndAsync(); Err = $p.StandardError.ReadToEndAsync() }
}

function Complete-ScopeGit($Run) {
    $Run.Process.WaitForExit()
    $text = $Run.Out.Result
    $null = $Run.Err.Result
    [string[]]$lines = @()
    if ($text -ne '') { $lines = @($text -replace '\r?\n$', '' -split '\r?\n') }
    return @{ Code = $Run.Process.ExitCode; Lines = $lines; Text = $text }
}

function Invoke-ScopeGit([string]$Dir, [string[]]$GitArgs) {
    return Complete-ScopeGit (Start-ScopeGit $Dir $GitArgs)
}

function Get-ScopeParallel { return [Math]::Max(4, [Math]::Min(12, [int][Math]::Floor([Environment]::ProcessorCount / 2))) }

function Invoke-ScopeGitMany([string]$Dir, [System.Collections.Generic.List[object]]$ArgLists) {
    $count = $ArgLists.Count
    $results = New-Object object[] $count
    if ($count -eq 0) { return , $results }
    $max = Get-ScopeParallel
    $running = New-Object System.Collections.Generic.Queue[object]
    $next = 0
    while ($next -lt $count -or $running.Count) {
        while ($next -lt $count -and $running.Count -lt $max) {
            $running.Enqueue(@{ Index = $next; Run = (Start-ScopeGit $Dir ([string[]]$ArgLists[$next])) })
            $next++
        }
        $done = $running.Dequeue()
        $results[$done.Index] = Complete-ScopeGit $done.Run
    }
    return , $results
}

function ConvertTo-ScopeFileLines($Result) {
    if ($null -eq $Result -or $Result.Code -ne 0) { return $null }
    return , ([string[]]@($Result.Text -split '\r?\n'))
}

function Get-ScopeFileText([string]$Root, [string]$Rev, [string]$Rel) {
    return ConvertTo-ScopeFileLines (Invoke-ScopeGit $Root @('show', "${Rev}:$Rel"))
}

function Get-ScopeBlameArgs([string]$BaseSha, [string]$Rel) { return , [string[]]@('blame', '--porcelain', '-M', '-C', "$BaseSha..HEAD", '--', $Rel) }

function Get-ScopeBoundary([string]$Root, [string]$BaseSha, [string]$Rel) {
    return ConvertFrom-ScopeBlame (Invoke-ScopeGit $Root (Get-ScopeBlameArgs $BaseSha $Rel))
}

$script:ScopeAddedRx = [regex]::new('(?m)^(?:\+\+\+ (?:(?<dev>/dev/null)|b/(?<path>[^\n]*))|@@ -\d+(?:,\d+)? \+(?<start>\d+)(?:,(?<count>\d+))? @@)')
$script:ScopeBlameHeadRx = [regex]::new('(?m)^([0-9a-f]{40}) \d+ (\d+)')

function ConvertFrom-ScopeBlame($r) {
    $edges = [System.Collections.Generic.HashSet[string]]::new()
    if ($r.Code -ne 0) { return @{ Heads = $null; Edges = $edges } }
    $text = $r.Text
    $at = $text.IndexOf("`nboundary`n")
    while ($at -ge 0) {
        $lineEnd = $at
        while ($lineEnd -gt 0) {
            $lineStart = $text.LastIndexOf("`n", $lineEnd - 1) + 1
            $m = $script:ScopeBlameHeadRx.Match($text, $lineStart, $lineEnd - $lineStart)
            if ($m.Success -and $m.Index -eq $lineStart) { [void]$edges.Add($m.Groups[1].Value); break }
            $lineEnd = $lineStart - 1
        }
        $at = $text.IndexOf("`nboundary`n", $at + 1)
    }
    return @{ Heads = $script:ScopeBlameHeadRx.Matches($text); Edges = $edges }
}

function Test-ScopeBoundaryLine($Blame, [int]$Line) {
    if ($null -eq $Blame.Heads -or $Blame.Edges.Count -eq 0 -or $Line -lt 1 -or $Line -gt $Blame.Heads.Count) { return $false }
    $m = $Blame.Heads[$Line - 1]
    if ([int]$m.Groups[2].Value -ne $Line) { return $false }
    return $Blame.Edges.Contains($m.Groups[1].Value)
}

function Get-ScopeAddedLines([string]$Root, [string]$BaseSha) {
    $byFile = @{}
    $set = $null
    $r = Invoke-ScopeGit $Root @('diff', '-U0', '-M', '--no-color', '--no-ext-diff', '--src-prefix=a/', '--dst-prefix=b/', $BaseSha, 'HEAD')
    foreach ($m in $script:ScopeAddedRx.Matches($r.Text)) {
        if ($m.Groups['dev'].Success) { $set = $null; continue }
        if ($m.Groups['path'].Success) { $set = [System.Collections.Generic.HashSet[int]]::new(); $byFile[$m.Groups['path'].Value.TrimEnd("`r")] = $set; continue }
        if ($null -eq $set) { continue }
        $start = [int]$m.Groups['start'].Value
        $count = if ($m.Groups['count'].Success) { [int]$m.Groups['count'].Value } else { 1 }
        for ($i = 0; $i -lt $count; $i++) { [void]$set.Add($start + $i) }
    }
    return $byFile
}

function Get-ScopeBaseBodies([string]$Rel, [string[]]$Lines) {
    $bodies = [System.Collections.Generic.HashSet[string]]::new()
    if (-not $Rel -or $null -eq $Lines) { return , $bodies }
    foreach ($c in (Get-CommentBodyLines $Rel $Lines -KeepDirectives)) { [void]$bodies.Add($c.Body) }
    return , $bodies
}

function Get-ScopeBaseDocs([string]$Rel, [string[]]$Lines) {
    $docs = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    if (-not $Rel -or $null -eq $Lines) { return , $docs }
    $flags = Get-CommentDocFlags $Lines
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        if (-not $flags[$i] -or ($i -gt 0 -and $flags[$i - 1])) { continue }
        $code = Get-CommentDocTarget $Rel $Lines $i $flags
        if ($code) { [void]$docs.Add($code) }
    }
    return , $docs
}

function Test-ScopeDocCandidate([string[]]$Lines) {
    return $script:CommentDocMarkRx.IsMatch(($Lines -join "`n"))
}

function Test-ScopeDocBefore([string]$Rel, [string[]]$Lines, [int]$Index, [bool[]]$DocFlag, $Targets) {
    if ($null -eq $DocFlag -or $null -eq $Targets -or $Targets.Count -eq 0 -or $Index -lt 0 -or $Index -ge $DocFlag.Count -or -not $DocFlag[$Index]) { return $false }
    $code = Get-CommentDocTarget $Rel $Lines $Index $DocFlag
    return [bool]($code -and $Targets.Contains($code))
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
    if ($null -eq $DocFlag -or -not $DocFlag[$Index]) { return $false }
    $code = Get-CommentDocTarget $Rel $Lines $Index $DocFlag
    if (-not $code) { return $false }
    $base = if ($Ctx.Agents) { Split-Path -Parent $Ctx.Agents } else { $Ctx.Dir }
    foreach ($a in $Ctx.AuditRules) {
        if ($a.Pattern.IsMatch($code) -and (Test-CommentPathLike $Full $base $a.Pathspec)) { return $true }
    }
    return $false
}

$script:ScopeContexts = @{}

function Get-ScopeContext([string]$Full) {
    $dir = Split-Path -Parent $Full
    if (-not $script:ScopeContexts.ContainsKey($dir)) { $script:ScopeContexts[$dir] = Get-CommentRepoContext $Full }
    return $script:ScopeContexts[$dir]
}

function Invoke-ScopeList([string]$Root, [string]$BaseSha, [string]$OutPath) {
    if (-not $OutPath) { Stop-Scope '인자 누락 — -Out <파일>' }
    $listed = New-Object System.Collections.Generic.List[string]
    $pre = 0; $audit = 0; $kept = 0
    $status = Invoke-ScopeGit $Root @('diff', '--name-status', '-M', $BaseSha, 'HEAD')
    $addedByFile = Get-ScopeAddedLines $Root $BaseSha
    $entries = New-Object System.Collections.Generic.List[object]
    foreach ($row in $status.Lines) {
        $cols = $row -split "`t"
        if ($cols.Count -lt 2 -or $cols[0].StartsWith('D')) { continue }
        $rel = $cols[$cols.Count - 1]
        $oldRel = if ($cols[0].StartsWith('R')) { $cols[1] } elseif ($cols[0].StartsWith('A')) { '' } else { $rel }
        if (Test-CommentTarget $rel) { $entries.Add(@{ Rel = $rel; OldRel = $oldRel }) }
    }
    $window = (Get-ScopeParallel) * 4
    for ($start = 0; $start -lt $entries.Count; $start += $window) {
        $chunk = @($entries[$start..([Math]::Min($start + $window, $entries.Count) - 1)])
        $showArgs = New-Object System.Collections.Generic.List[object]
        foreach ($e in $chunk) { $showArgs.Add([string[]]@('show', "HEAD:$($e.Rel)")) }
        $heads = Invoke-ScopeGitMany $Root $showArgs
        $records = New-Object System.Collections.Generic.List[object]
        for ($i = 0; $i -lt $chunk.Count; $i++) {
            $lines = ConvertTo-ScopeFileLines $heads[$i]
            if ($null -eq $lines) { continue }
            $rel = $chunk[$i].Rel
            $comments = Get-CommentBodyLines $rel $lines -KeepDirectives
            if ($comments.Count -eq 0) { continue }
            $addedLines = $addedByFile[$rel]
            $cands = New-Object System.Collections.Generic.List[object]
            foreach ($c in $comments) {
                if ($null -ne $addedLines -and $addedLines.Contains([int]$c.Line + 1)) { $cands.Add($c) } else { $pre++ }
            }
            if ($cands.Count -eq 0) { continue }
            $records.Add(@{ Rel = $rel; OldRel = $chunk[$i].OldRel; Lines = $lines; Cands = $cands })
        }
        $baseArgs = New-Object System.Collections.Generic.List[object]
        foreach ($r in $records) { $baseArgs.Add([string[]]@('show', "${BaseSha}:$(if ($r.OldRel) { $r.OldRel } else { $r.Rel })")) }
        $bases = Invoke-ScopeGitMany $Root $baseArgs
        $blamed = New-Object System.Collections.Generic.List[object]
        for ($i = 0; $i -lt $records.Count; $i++) {
            $r = $records[$i]
            $baseLines = if ($r.OldRel) { ConvertTo-ScopeFileLines $bases[$i] } else { $null }
            $bodies = Get-ScopeBaseBodies $r.OldRel $baseLines
            $fresh = @($r.Cands | Where-Object { -not $bodies.Contains($_.Body) })
            $r.DocFlag = $null
            if ($fresh.Count -gt 0 -and (Test-ScopeDocCandidate $r.Lines)) {
                $r.DocFlag = Get-CommentDocFlags $r.Lines
                $docs = Get-ScopeBaseDocs $r.OldRel $baseLines
                $fresh = @($fresh | Where-Object { -not (Test-ScopeDocBefore $r.Rel $r.Lines ([int]$_.Line) $r.DocFlag $docs) })
            }
            $pre += $r.Cands.Count - $fresh.Count
            if ($fresh.Count -eq 0) { continue }
            $r.Cands = $fresh
            $blamed.Add($r)
        }
        $blameArgs = New-Object System.Collections.Generic.List[object]
        foreach ($r in $blamed) { $blameArgs.Add((Get-ScopeBlameArgs $BaseSha $r.Rel)) }
        $blames = Invoke-ScopeGitMany $Root $blameArgs
        for ($i = 0; $i -lt $blamed.Count; $i++) {
            $r = $blamed[$i]
            $boundary = ConvertFrom-ScopeBlame $blames[$i]
            $full = [System.IO.Path]::GetFullPath((Join-Path $Root $r.Rel))
            $ctx = Get-ScopeContext $full
            foreach ($c in $r.Cands) {
                $n = [int]$c.Line
                if (Test-ScopeBoundaryLine $boundary ($n + 1)) { $pre++; continue }
                if (Test-ScopeKept $ctx $full $c.Body) { $kept++; continue }
                if (Test-ScopeAudited $ctx $full $r.Rel $r.Lines $n $r.DocFlag) { $audit++; continue }
                $listed.Add("$($r.Rel):$($n + 1)`t$($c.Body)")
            }
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
    foreach ($l in (Invoke-ScopeGit $Root @('diff', '-U0', '--no-color', '--no-ext-diff', '--src-prefix=a/', '--dst-prefix=b/', 'HEAD')).Lines) {
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
        $boundary = $null
        $inserts = New-Object System.Collections.Generic.List[object]
        foreach ($h in $files[$rel]) {
            $comments = Get-CommentBodyLines $rel ([string[]]$h.Lines) -KeepDirectives
            if ($comments.Count -eq 0) { continue }
            if ($null -eq $boundary) { $boundary = Get-ScopeBoundary $Root $BaseSha $rel }
            if ($null -eq $baseBodies) {
                $baseRel = if ($oldPaths.ContainsKey($rel)) { $oldPaths[$rel] } else { $rel }
                $baseLines = Get-ScopeFileText $Root $BaseSha $baseRel
                $baseBodies = Get-ScopeBaseBodies $baseRel $baseLines
                $baseDocs = Get-ScopeBaseDocs $baseRel $baseLines
                [string[]]$headLines = @()
                $shown = Get-ScopeFileText $Root 'HEAD' $rel
                if ($null -ne $shown) { $headLines = $shown }
                $headFlags = Get-CommentDocFlags $headLines
            }
            $isComment = @{}
            foreach ($c in $comments) { $isComment[[int]$c.Line] = $c.Body }
            $keep = New-Object System.Collections.Generic.List[string]
            for ($i = 0; $i -lt $h.Lines.Count; $i++) {
                if (-not $isComment.ContainsKey($i)) { continue }
                if ((Test-ScopeBoundaryLine $boundary ($h.Old + $i)) -or $baseBodies.Contains($isComment[$i]) -or (Test-ScopeDocBefore $rel $headLines ($h.Old + $i - 1) $headFlags $baseDocs)) {
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
