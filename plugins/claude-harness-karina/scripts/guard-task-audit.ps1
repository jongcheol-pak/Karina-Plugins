# guard-task-audit.ps1 — PreToolUse/Bash: task 완료 커밋의 소스 감사 누락 경고 (비차단) — 근거는 `rules/task-audit-rationale.md`

$script:TaskAuditUntrackedMax = 50

function Find-TaskAuditAgents([string]$Dir) {
    $topRun = Invoke-CommitGit -Check 'warn-task-audit' -Dir $Dir -GitArgs @('rev-parse', '--show-toplevel')
    $top = [string](@($topRun.Lines)[0])
    if ($topRun.Code -ne 0 -or -not $top) { return $null }
    $top = [System.IO.Path]::GetFullPath($top)
    $cur = [System.IO.Path]::GetFullPath($Dir)
    while ($cur) {
        $cand = Join-Path $cur 'AGENTS.md'
        if (Test-Path -LiteralPath $cand -PathType Leaf) { return $cand }
        if ($cur.TrimEnd('\', '/') -eq $top.TrimEnd('\', '/')) { break }
        $parent = [System.IO.Path]::GetDirectoryName($cur)
        if (-not $parent -or $parent -eq $cur) { break }
        $cur = $parent
    }
    return $null
}

function Test-TaskAuditCommandInMessage([string]$Message, [string]$Command) {
    $msg = ($Message -replace '\r', '') -replace '[ \t]+', ' '
    $cmd = ($Command -replace '\s+', ' ').Trim()
    $rx = [regex]::Escape($cmd) + '(?=$|[`"'']| (?:\d?>|\||;|&&|→))'
    return [regex]::IsMatch($msg, $rx, [System.Text.RegularExpressions.RegexOptions]::Multiline)
}

function Test-TaskAuditFilterCovered([string]$Message, [string]$Command) {
    $cm = [regex]::Match(($Command -replace '\s+', ' ').Trim(), '^(?<pre>cargo test\b.*?) -- (?<f>[^\s-]\S*)$')
    if (-not $cm.Success) { return $false }
    $msg = ($Message -replace '\r', '') -replace '[ \t]+', ' '
    $rx = [regex]::Escape($cm.Groups['pre'].Value + ' -- ') + '(?<g>[^\s`"'']+)(?=$|[`"'']| (?:\d?>|\||;|&&|→))'
    foreach ($m in [regex]::Matches($msg, $rx, [System.Text.RegularExpressions.RegexOptions]::Multiline)) {
        if ($cm.Groups['f'].Value.Contains($m.Groups['g'].Value)) { return $true }
    }
    return $false
}

function Get-TaskAuditGrowth([string]$RuleDir, $Rule, [bool]$IncludeUntracked) {
    $run = Invoke-CommitGit -Check 'warn-task-audit' -Dir $RuleDir -GitArgs (@('-c', 'core.quotepath=off', 'diff', '--unified=0', '--no-color', '--no-ext-diff', 'HEAD', '--') + @($Rule.Pathspec))
    if ($run.Code -ne 0 -and -not $run.TimedOut) { $run = Invoke-CommitGit -Check 'warn-task-audit' -Dir $RuleDir -GitArgs (@('-c', 'core.quotepath=off', 'diff', '--unified=0', '--no-color', '--no-ext-diff', '--cached', '--') + @($Rule.Pathspec)) }
    $diff = @($run.Lines)
    $net = 0
    foreach ($l in $diff) {
        if ($l -match '^(\+\+\+|---) (a/|b/|/dev/null)') { continue }
        if ($l.StartsWith('+') -and $Rule.Pattern.IsMatch($l.Substring(1))) { $net++ }
        elseif ($l.StartsWith('-') -and $Rule.Pattern.IsMatch($l.Substring(1))) { $net-- }
    }
    $capped = $false
    if ($IncludeUntracked) {
        $files = @((Invoke-CommitGit -Check 'warn-task-audit' -Dir $RuleDir -GitArgs (@('-c', 'core.quotepath=off', 'ls-files', '--others', '--exclude-standard', '--') + @($Rule.Pathspec))).Lines | Where-Object { $_ })
        if ($files.Count -gt $script:TaskAuditUntrackedMax) { $capped = $true; $files = $files[0..($script:TaskAuditUntrackedMax - 1)] }
        foreach ($f in $files) {
            $full = Join-Path $RuleDir $f
            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
            if ((Get-Item -LiteralPath $full).Length -gt 1MB) { $capped = $true; continue }
            foreach ($line in @(Get-Content -LiteralPath $full -Encoding UTF8 -ErrorAction SilentlyContinue)) {
                if ($Rule.Pattern.IsMatch([string]$line)) { $net++ }
            }
        }
    }
    return @{ Net = $net; Capped = $capped }
}

function Invoke-WarnTaskAudit {
    param($data)
    $cmd = [string]$data.tool_input.command
    if ([string]::IsNullOrWhiteSpace($cmd)) { return New-HookResult }
    $judge = Remove-HeredocBodyForJudge $cmd
    $cm = [regex]::Match($judge, $script:GitCommitRx)
    if (-not $cm.Success) { return New-HookResult }

    $startDir = if ($data.cwd) { [string]$data.cwd } elseif ($env:CLAUDE_PROJECT_DIR) { $env:CLAUDE_PROJECT_DIR } else { (Get-Location).Path }
    $commitDir = Resolve-GitCommitDir $judge $startDir
    $message = Get-CommitMessage $cmd $commitDir
    if ($null -eq $message -or $message -is [bool]) { return New-HookResult }
    $title = @($message -split '\r?\n')[0]
    $tm = [regex]::Match($title, '^\s*(?:(?:기능|수정|리팩토링|문서|설정)\s*:\s*)?T(\d+(?:-\d+)?)\s*(?::|—|-)')
    if (-not $tm.Success) { return New-HookResult }

    $agents = Find-TaskAuditAgents $commitDir
    if (-not $agents) { return New-HookResult }
    # 감사 줄 파서는 comment-lines.ps1 에 있고 검사 호출 시점에만 부른다 — 근거는 `rules/task-audit-rationale.md` §6
    if (-not (Get-Command Get-TaskAuditRules -ErrorAction SilentlyContinue)) {
        try { . (Join-Path $PSScriptRoot 'comment-lines.ps1') } catch {}
    }
    if (-not (Get-Command Get-TaskAuditRules -ErrorAction SilentlyContinue)) {
        $w = '[guard-bash] comment-lines.ps1 로드 실패 — task 감사 누락 검사 미수행(fail-open). 플러그인 재설치를 권장합니다.'
        return New-HookResult -Stderr @($w)
    }
    $rules = @(Get-TaskAuditRules $agents)
    if (-not $rules.Count) { return New-HookResult }
    $ruleDir = [System.IO.Path]::GetDirectoryName($agents)
    $preAdd = [regex]::IsMatch($judge.Substring(0, $cm.Index), $script:GitAddRx)

    $lines = New-Object System.Collections.Generic.List[string]
    foreach ($rule in $rules) {
        if ($rule.Error) {
            $lines.Add("  - 규칙을 읽지 못함: AGENTS.md:$($rule.Line) ($($rule.Error)) — 이 줄은 검사되지 않습니다")
            continue
        }
        $g = Get-TaskAuditGrowth $ruleDir $rule $preAdd
        if ($g.Net -le 0) { continue }
        $accepted = @($rule.Command) + @($rule.Alternatives)
        if (@($accepted | Where-Object { Test-TaskAuditCommandInMessage $message $_ }).Count) { continue }
        if (Test-TaskAuditFilterCovered $message $rule.Command) { continue }
        $note = if ($g.Capped) { ' (미추적 파일 상한에 걸려 일부만 셈)' } else { '' }
        $lines.Add("  - ``$($rule.Command)`` — 증가 $($g.Net)줄$note (AGENTS.md:$($rule.Line))")
    }
    if (Test-CommitGitTimedOut 'warn-task-audit') {
        $w = "[guard-bash] git 이 시간 상한($(Get-CommitGitLimitMs)ms) 안에 답하지 않아 task 감사 누락 검사를 건너뜁니다."
        return New-HookResult -Stderr @($w)
    }
    if (-not $lines.Count) { return New-HookResult }

    $t = $tm.Groups[1].Value
    $msg = (@(
        "[HARNESS] T$t 완료 커밋에 AGENTS.md 「Test (감사)」 명령이 없습니다 — 필터 테스트는 이 감사를 돌리지 않습니다.",
        $lines.ToArray(),
        "이 경고는 커밋을 막지 않습니다. 커밋 뒤 위 명령을 돌리고 결과를 ``git commit --allow-empty`` 보충 커밋(제목 ``{유형}: T$t — 검증 기록 보충``)의 본문에 남기세요. 실패하면 수정 커밋을 합니다."
    ) | ForEach-Object { $_ }) -join "`n"
    return New-HookResult -Block $false -Stderr @($msg) -Context $msg
}
