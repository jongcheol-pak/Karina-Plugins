# guard-commit-comments.ps1 — git commit 직전 새 주석 첫 시도 차단 (dot-source 전용, hook 아님) — 근거는 `rules/comment-gate-rationale.md` §4

. (Join-Path $PSScriptRoot 'git-commit-match.ps1')
. (Join-Path $PSScriptRoot 'comment-lines.ps1')

$script:CommitCommentFileMax = 200
$script:CommitCommentLineMax = 20000

function Get-CommitCommentDiff([string[]]$GitArgs) {
    $out = @(& git -c core.quotepath=off diff --unified=0 --no-color @GitArgs 2>$null)
    if ($LASTEXITCODE -ne 0) { return $null }
    return $out
}

function Add-CommitCommentDiff($Files, $Lines) {
    $path = $null
    $inHeader = $false
    foreach ($l in $Lines) {
        if ($l.StartsWith('diff --git ')) { $inHeader = $true; $path = $null; continue }
        if ($inHeader) {
            if ($l.StartsWith('+++ ')) {
                $inHeader = $false
                $path = if ($l -eq '+++ /dev/null') { $null } else { $l.Substring(4) -replace '^b/', '' }
            }
            continue
        }
        if ($null -eq $path -or $l.StartsWith('@@')) { continue }
        if (-not $Files.ContainsKey($path)) { $Files[$path] = @{ Plus = New-Object System.Collections.Generic.List[string]; Minus = New-Object System.Collections.Generic.List[string] } }
        if ($l.StartsWith('+')) { $Files[$path].Plus.Add($l.Substring(1)) }
        elseif ($l.StartsWith('-')) { $Files[$path].Minus.Add($l.Substring(1)) }
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
            $d = Get-CommitCommentDiff @('HEAD'); if ($null -ne $d) { Add-CommitCommentDiff $Files $d }
            foreach ($u in @(& git -c core.quotepath=off ls-files --others --exclude-standard 2>$null)) { Add-CommitCommentNewFile $Files $u }
            continue
        }
        foreach ($t in @($argsText -split '\s+' | Where-Object { $_ -and -not $_.StartsWith('-') } | ForEach-Object { $_.Trim('"', "'") })) {
            if (@(& git ls-files -- $t 2>$null).Count -gt 0) {
                $d = Get-CommitCommentDiff @('HEAD', '--', $t); if ($null -ne $d) { Add-CommitCommentDiff $Files $d }
            } else {
                foreach ($u in @(& git -c core.quotepath=off ls-files --others --exclude-standard -- $t 2>$null)) { Add-CommitCommentNewFile $Files $u }
            }
        }
    }
}

function Add-CommitCommentNewFile($Files, [string]$Path) {
    if (-not (Test-CommentTarget $Path) -or -not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
    if (-not $Files.ContainsKey($Path)) { $Files[$Path] = @{ Plus = New-Object System.Collections.Generic.List[string]; Minus = New-Object System.Collections.Generic.List[string] } }
    foreach ($l in @(Get-Content -LiteralPath $Path -Encoding UTF8 -TotalCount ($script:CommitCommentLineMax + 1))) { $Files[$Path].Plus.Add([string]$l) }
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
            $d = Get-CommitCommentDiff (@('HEAD', '--') + @($opt.Paths)); if ($null -ne $d) { Add-CommitCommentDiff $files $d }
            if ($opt.Include) { $d = Get-CommitCommentDiff @('--cached'); if ($null -ne $d) { Add-CommitCommentDiff $files $d } }
        } elseif ($opt.All) {
            $d = Get-CommitCommentDiff @('HEAD'); if ($null -ne $d) { Add-CommitCommentDiff $files $d }
        } else {
            $d = Get-CommitCommentDiff @('--cached'); if ($null -ne $d) { Add-CommitCommentDiff $files $d }
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
        $session = Get-CommentGateSession $data
        $approved = Get-CommentGateApproved $session
        $found = New-Object System.Collections.Generic.List[string]
        $perFile = New-Object System.Collections.Generic.List[string]
        foreach ($k in ($targets | Sort-Object)) {
            $n = 0
            foreach ($c in (Get-CommentBodies $k $files[$k].Plus)) {
                if ($moved.Contains($c) -or $approved.Contains($c)) { continue }
                $found.Add($c); $n++
            }
            if ($n -gt 0) { $perFile.Add("  $k : 주석 $n줄") }
        }
        if ($found.Count -eq 0) { return New-HookResult }

        $key = Get-CommentGateKey $session ('commit|' + ([string]$commitDir).ToLowerInvariant()) $found
        if (Test-CommentGateRetry $key) {
            Add-CommentGateApproved $session $found
            return New-HookResult
        }
        if (-not (Set-CommentGateRetry $key)) { return New-HookResult }

        $lines = @("[HARNESS] BLOCKED: 커밋에 새 주석이 있습니다 — 첫 시도를 막습니다 (주석 $($found.Count)줄)") + @($perFile) + @(Format-CommentGatePreview $found) + @(
            $script:CommentGateRule,
            '  - 그중 하나면 같은 커밋 명령을 그대로 다시 실행하세요 — 통과합니다.',
            '  - 아니면 주석을 지우고 다시 커밋하고, 남길 이유는 커밋 본문에 적으세요.')
        return New-HookResult -Block $true -Stderr $lines
    } catch {
        return New-HookResult
    } finally {
        Set-Location -LiteralPath $origLoc
    }
}
