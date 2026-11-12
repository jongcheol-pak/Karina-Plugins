# guard-commit-comments.ps1 — git commit 직전 새 주석 차단 (dot-source 전용, hook 아님) — 근거는 `rules/comment-gate-rationale.md` §4

. (Join-Path $PSScriptRoot 'git-commit-match.ps1')
. (Join-Path $PSScriptRoot 'comment-lines.ps1')

$script:CommitCommentFileMax = 200
$script:CommitCommentLineMax = 20000

function Get-CommitCommentDiff([string[]]$GitArgs) {
    $out = @(& git -c core.quotepath=off diff --unified=0 --no-color @GitArgs 2>$null)
    if ($LASTEXITCODE -ne 0) { return $null }
    return $out
}

function New-CommitCommentEntry([string]$Source) {
    return @{ Plus = New-Object System.Collections.Generic.List[string]; PlusLine = New-Object System.Collections.Generic.List[int]; Minus = New-Object System.Collections.Generic.List[string]; Hunks = New-Object System.Collections.Generic.List[object]; Source = $Source }
}

function Add-CommitCommentHunk($Entry) {
    $h = @{ Minus = New-Object System.Collections.Generic.List[string]; PlusStart = $Entry.Plus.Count; PlusCount = 0 }
    $Entry.Hunks.Add($h)
    return $h
}

function Get-CommitCommentEntry($Files, [string]$Path, [string]$Source) {
    if ($Files.ContainsKey($Path)) {
        $e = $Files[$Path]
        if ($e.Source -eq $Source) { return $e }
        if ($e.Source -eq 'worktree') { return $null }
    }
    $Files[$Path] = New-CommitCommentEntry $Source
    return $Files[$Path]
}

function Add-CommitCommentDiff($Files, $Lines, [string]$Source) {
    $entry = $null
    $hunk = $null
    $inHeader = $false
    $next = 0
    $seen = @{}
    foreach ($l in $Lines) {
        if ($l.StartsWith('diff --git ')) { $inHeader = $true; $entry = $null; $hunk = $null; continue }
        if ($inHeader) {
            if ($l.StartsWith('+++ ')) {
                $inHeader = $false
                $path = if ($l -eq '+++ /dev/null') { $null } else { $l.Substring(4) -replace '^b/', '' }
                if ($null -ne $path) {
                    if ($seen.ContainsKey($path)) { $entry = $Files[$path] }
                    else { $entry = Get-CommitCommentEntry $Files $path $Source; $seen[$path] = $true }
                }
            }
            continue
        }
        if ($null -eq $entry) { continue }
        if ($l.StartsWith('@@')) {
            $m = [regex]::Match($l, '\+(\d+)')
            $next = if ($m.Success) { [int]$m.Groups[1].Value } else { 0 }
            $hunk = Add-CommitCommentHunk $entry
            continue
        }
        if ($null -eq $hunk) { continue }
        if ($l.StartsWith('+')) { $entry.Plus.Add($l.Substring(1)); $entry.PlusLine.Add($next); $next++; $hunk.PlusCount++ }
        elseif ($l.StartsWith('-')) { $entry.Minus.Add($l.Substring(1)); $hunk.Minus.Add($l.Substring(1)) }
    }
}

function Get-CommitCommentArgs([string]$Segment) {
    $s = $Segment -replace '(?i)(^|\s)(-[a-zA-Z]*[mFCc]|--message|--file|--author|--date|--reuse-message|--reedit-message|--fixup|--squash|--cleanup|-t|--template|--trailer)(=|\s+)("[^"]*"|''[^'']*''|\S+)', '$1$2'
    $tokens = @([regex]::Matches($s, '"[^"]*"|''[^'']*''|\S+') | ForEach-Object { $_.Value.Trim('"', "'") })
    $ci = [array]::IndexOf(@($tokens | ForEach-Object { $_.ToLowerInvariant() }), 'commit')
    $rest = if ($ci -ge 0) { @($tokens | Select-Object -Skip ($ci + 1)) } else { @() }
    $paths = New-Object System.Collections.Generic.List[string]
    $afterDash = $false
    $flags = New-Object System.Collections.Generic.List[string]
    foreach ($t in $rest) {
        if ($afterDash) { $paths.Add($t); continue }
        if ($t -eq '--') { $afterDash = $true; continue }
        if ($t.StartsWith('-')) { $flags.Add($t); continue }
        $paths.Add($t)
    }
    $flagText = ' ' + ($flags -join ' ') + ' '
    return @{
        Paths = $paths
        All = ($flagText -match '\s-[a-zA-Z]*a[a-zA-Z]*\s') -or ($flagText -match '\s--all\s')
        Include = ($flagText -match '\s(-i|--include)\s')
    }
}

function Add-CommitCommentPreAdd($Files, [string]$PreText) {
    foreach ($m in [regex]::Matches($PreText, '(?i)' + $script:GitAddRx + '\s+(?<args>[^&;|\r\n]*)')) {
        $argsText = $m.Groups['args'].Value.Trim()
        if ($argsText -match '(^|\s)(-A|--all|-u|--update|\.)(\s|$)') {
            $d = Get-CommitCommentDiff @('HEAD'); if ($null -ne $d) { Add-CommitCommentDiff $Files $d 'worktree' }
            foreach ($u in @(& git -c core.quotepath=off ls-files --others --exclude-standard --full-name 2>$null)) { Add-CommitCommentNewFile $Files $u }
            continue
        }
        foreach ($t in @($argsText -split '\s+' | Where-Object { $_ -and -not $_.StartsWith('-') } | ForEach-Object { $_.Trim('"', "'") })) {
            if (@(& git ls-files -- $t 2>$null).Count -gt 0) {
                $d = Get-CommitCommentDiff @('HEAD', '--', $t); if ($null -ne $d) { Add-CommitCommentDiff $Files $d 'worktree' }
            } else {
                foreach ($u in @(& git -c core.quotepath=off ls-files --others --exclude-standard --full-name -- $t 2>$null)) { Add-CommitCommentNewFile $Files $u }
            }
        }
    }
}

function Add-CommitCommentNewFile($Files, [string]$Path) {
    $top = [string](& git rev-parse --show-toplevel 2>$null)
    $abs = if ($top) { Join-Path $top $Path } else { $Path }
    if (-not (Test-CommentTarget $Path) -or -not (Test-Path -LiteralPath $abs -PathType Leaf)) { return }
    $Files[$Path] = New-CommitCommentEntry 'worktree'
    $hunk = Add-CommitCommentHunk $Files[$Path]
    $n = 1
    foreach ($l in @(Get-Content -LiteralPath $abs -Encoding UTF8 -TotalCount ($script:CommitCommentLineMax + 1))) { $Files[$Path].Plus.Add([string]$l); $Files[$Path].PlusLine.Add($n); $n++; $hunk.PlusCount++ }
}

function Invoke-BlockCommitComments {
    param($data)
    $cmd = [string]$data.tool_input.command
    if ([string]::IsNullOrWhiteSpace($cmd)) { return New-HookResult }
    $judge = Remove-HeredocBodyForJudge $cmd
    $cm = [regex]::Match($judge, $script:GitCommitRx)
    if (-not $cm.Success) { return New-HookResult }
    $segment = (($judge.Substring($cm.Index) -replace '\r?\n\s*\)', ')') -split '(\|\||&&|;|\r?\n)')[0]
    if ($segment -match '(^|\s)(--dry-run|--help|-h)(\s|$)') { return New-HookResult }

    $startDir = if ($data.cwd) { [string]$data.cwd } elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
    $commitDir = Resolve-GitCommitDir $judge $startDir
    if (-not $commitDir -or -not (Test-Path -LiteralPath $commitDir -PathType Container)) { return New-HookResult }
    $origLoc = Get-Location
    try {
        Set-Location -LiteralPath $commitDir
        $gitDir = & git rev-parse --git-dir 2>$null
        if (-not $gitDir -or $LASTEXITCODE -ne 0) { return New-HookResult }
        if (Test-Path -LiteralPath (Join-Path $gitDir 'MERGE_HEAD')) { return New-HookResult }

        $opt = Get-CommitCommentArgs $segment
        $files = @{}
        if ($opt.Paths.Count -gt 0) {
            $d = Get-CommitCommentDiff (@('HEAD', '--') + @($opt.Paths)); if ($null -ne $d) { Add-CommitCommentDiff $files $d 'worktree' }
            if ($opt.Include) { $d = Get-CommitCommentDiff @('--cached'); if ($null -ne $d) { Add-CommitCommentDiff $files $d 'index' } }
        } elseif ($opt.All) {
            $d = Get-CommitCommentDiff @('HEAD'); if ($null -ne $d) { Add-CommitCommentDiff $files $d 'worktree' }
        } else {
            $d = Get-CommitCommentDiff @('--cached'); if ($null -ne $d) { Add-CommitCommentDiff $files $d 'index' }
        }
        Add-CommitCommentPreAdd $files $judge.Substring(0, $cm.Index)

        $targets = @($files.Keys | Where-Object { Test-CommentTarget $_ })
        $lineTotal = 0
        foreach ($k in $targets) { $lineTotal += $files[$k].Plus.Count }
        if ($targets.Count -gt $script:CommitCommentFileMax -or $lineTotal -gt $script:CommitCommentLineMax) {
            return New-HookResult -Stderr @("[commit-comments] 검사 상한(파일 $($script:CommitCommentFileMax) · 추가 줄 $($script:CommitCommentLineMax)) 초과 — 새 주석 검사를 건너뜁니다(파일 $($targets.Count) · 추가 줄 $lineTotal).")
        }

        $moved = New-Object System.Collections.Generic.HashSet[string]
        foreach ($k in $targets) { foreach ($c in (Get-CommentBodies $k $files[$k].Minus)) { [void]$moved.Add($c) } }
        $top = [string](& git rev-parse --show-toplevel 2>$null)
        $found = New-Object System.Collections.Generic.List[string]
        $perFile = New-Object System.Collections.Generic.List[string]
        $baseBudget = New-CommentBaseBudget
        $rewriteBudget = New-CommentRewriteBudget
        foreach ($k in ($targets | Sort-Object)) {
            $full = if ($top) { [System.IO.Path]::GetFullPath((Join-Path $top $k)) } else { [System.IO.Path]::GetFullPath($k) }
            $entry = $files[$k]
            $pairs = @($entry.Hunks | ForEach-Object { , @(($_.Minus -join "`n"), ($entry.Plus.GetRange($_.PlusStart, $_.PlusCount) -join "`n")) })
            $added = New-Object System.Collections.Generic.List[object]
            foreach ($c in (Get-AddedCommentBodies $k $pairs $rewriteBudget)) { if (-not $moved.Contains($c.Body)) { $added.Add($c) } }
            $text = $null
            if ($entry.Source -eq 'index') {
                $shown = @(& git -c core.quotepath=off show ":$k" 2>$null)
                if ($LASTEXITCODE -eq 0) { $text = $shown -join "`n" }
            } elseif (Test-Path -LiteralPath $full -PathType Leaf) {
                $text = [System.IO.File]::ReadAllText($full)
            }
            if ($null -ne $text) {
                $post = @($text -split '\r?\n')
                foreach ($a in $added) { $a.Indexes = @([int]$entry.PlusLine[$entry.Hunks[$a.Pair].PlusStart + $a.Line] - 1) }
            } else {
                $post = @($entry.Plus)
                foreach ($a in $added) { $a.Indexes = @($entry.Hunks[$a.Pair].PlusStart + $a.Line) }
            }
            $blocked = Get-BlockedCommentBodies $full $added $post $baseBudget
            foreach ($c in $blocked) { $found.Add($c) }
            if ($blocked.Count -gt 0) { $perFile.Add("  $k : 주석 $($blocked.Count)줄") }
        }
        if ($found.Count -eq 0) { return New-HookResult }

        $lines = @("[HARNESS] BLOCKED: 커밋에 새 주석이 있습니다 (주석 $($found.Count)줄)") + @($perFile) + @(Format-CommentGatePreview $found) + @(
            $script:CommentGateRule,
            '  - 같은 커밋을 다시 내도 통과하지 않습니다. 주석을 지우고 다시 커밋하고, 남길 이유는 커밋 본문에 적으세요.',
            '  - 고친 코드를 설명하던 옛 주석이 있으면 같은 자리(같은 hunk)에서 같은 줄 수 안에서 고치거나 지우세요 — 문구 수정·삭제는 막지 않습니다. 새 주석만 빼고 낡은 주석을 남기지 마세요.',
            '  - 위 예외에 드는데 막혔으면 멈추고 사용자에게 보고하세요.')
        return New-HookResult -Block $true -Stderr $lines
    } catch {
        return New-HookResult
    } finally {
        Set-Location -LiteralPath $origLoc
    }
}
