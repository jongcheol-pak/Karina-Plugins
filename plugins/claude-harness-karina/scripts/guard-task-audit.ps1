# guard-task-audit.ps1 — PreToolUse/Bash: task 완료 커밋의 소스 감사 누락 경고 (RED 줄 누락만 차단) — 근거는 `rules/task-audit-rationale.md`

$script:TaskAuditUntrackedMax = 50
$script:TaskAuditRedMissing = '  - RED 줄 없음'
$script:TaskEvidenceBaseRead = $false

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

$script:TaskAuditTargetFlags = @('--lib', '--bins', '--tests', '--examples', '--benches', '--all-targets', '--doc', '--workspace')
$script:TaskAuditTargetValueFlags = @('--bin', '--test', '--example', '--bench', '-p', '--package')

function Get-TaskAuditTargetKey([string]$Flags) {
    $set = New-Object 'System.Collections.Generic.SortedSet[string]' ([System.StringComparer]::Ordinal)
    $toks = @($Flags -split ' ' | Where-Object { $_ })
    for ($i = 0; $i -lt $toks.Count; $i++) {
        $t = $toks[$i]
        $eq = $t.IndexOf('=')
        $name = if ($eq -gt 0) { $t.Substring(0, $eq) } else { $t }
        if ($script:TaskAuditTargetFlags -ccontains $name) { [void]$set.Add($name); continue }
        if ($script:TaskAuditTargetValueFlags -cnotcontains $name) { continue }
        $value = ''
        if ($eq -gt 0) { $value = $t.Substring($eq + 1) }
        elseif ($i + 1 -lt $toks.Count) { $i++; $value = $toks[$i] }
        if ($name -eq '-p') { $name = '--package' }
        [void]$set.Add("$name $value")
    }
    return ($set -join ' ')
}

function Get-TaskAuditTaskTemplate([string]$AgentsPath) {
    foreach ($l in @(Get-Content -LiteralPath $AgentsPath -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        $m = [regex]::Match([string]$l, '^- \*\*Test \(task\)\*\*: `(?<cmd>[^`]+)`')
        if (-not $m.Success) { continue }
        $parts = @([regex]::Matches($m.Groups['cmd'].Value, '<[^>]*>|\S+') | ForEach-Object { $_.Value })
        $first = -1
        for ($i = 0; $i -lt $parts.Count; $i++) { if ($parts[$i].StartsWith('<')) { $first = $i; break } }
        if ($first -lt 1) { return $null }
        for ($i = $first; $i -lt $parts.Count -and $parts[$i].StartsWith('<'); $i++) {
            if ($parts[$i].StartsWith('<대상')) { return @{ Prefix = ($parts[0..($first - 1)] -join ' '); Skip = $i - $first } }
        }
        return $null
    }
    return $null
}

function Test-TaskAuditFilterCovered([string]$Message, [string]$Command, $Template) {
    $cm = [regex]::Match(($Command -replace '\s+', ' ').Trim(), '^cargo test(?<pre>(?: \S+)*?) -- (?<f>[^\s-]\S*)$')
    if (-not $cm.Success) { return $false }
    $want = Get-TaskAuditTargetKey $cm.Groups['pre'].Value
    $msg = ($Message -replace '\r', '') -replace '[ \t]+', ' '
    $opt = [System.Text.RegularExpressions.RegexOptions]::Multiline
    $rx = 'cargo test(?<pre>(?: (?!--(?: |$))(?![&|;>→]|\d>)[^\s`"'']+)*) -- (?<g>[^\s`"'']+)(?=$|[`"'']| (?:\d?>|\||;|&&|→))'
    foreach ($m in [regex]::Matches($msg, $rx, $opt)) {
        if ((Get-TaskAuditTargetKey $m.Groups['pre'].Value) -cne $want) { continue }
        if ($cm.Groups['f'].Value.Contains($m.Groups['g'].Value)) { return $true }
    }
    if (-not $Template) { return $false }
    $trx = [regex]::Escape($Template.Prefix) + '(?<a>(?: (?![&|;>→]|\d>)[^\s`"'']+)*)(?=$|[`"'']| (?:\d?>|\||;|&&|→))'
    foreach ($m in [regex]::Matches($msg, $trx, $opt)) {
        $toks = @($m.Groups['a'].Value -split ' ' | Where-Object { $_ })
        for ($i = $Template.Skip; $i -lt $toks.Count; $i++) {
            if (-not $toks[$i].StartsWith('-') -and $cm.Groups['f'].Value.Contains($toks[$i])) { return $true }
        }
    }
    return $false
}

# 이번 커밋에 드는 변경의 범위 — 근거는 `rules/task-audit-rationale.md` §3
function Get-TaskAuditScope([string]$Judge, $Cm, [string]$CommitDir) {
    $scope = @{ Wide = $true; Cached = $true; Paths = @(); UntrackedAll = $false; UntrackedPaths = @(); CommitDir = $CommitDir }
    $pre = $Judge.Substring(0, $Cm.Index)
    $adds = @([regex]::Matches($pre, '(?i)' + $script:GitAddRx + '\s+(?<args>[^&;|\r\n]*)') | ForEach-Object { $_.Groups['args'].Value.Trim() })
    $scope.UntrackedAll = [bool]@($adds | Where-Object { $_ -match '(^|\s)(-A|--all|-u|--update|\.)(\s|$)' }).Count
    if (-not (Get-Command Get-CommitCommentArgs -ErrorAction SilentlyContinue)) { $scope.UntrackedAll = [bool]$adds.Count; return $scope }
    $segment = (($Judge.Substring($Cm.Index) -replace '\r?\n\s*\)', ')') -split '(\|\||&&|;|\r?\n)')[0]
    $opt = Get-CommitCommentArgs $segment
    $addPaths = @($adds | ForEach-Object { $_ -split '\s+' } | Where-Object { $_ -and -not $_.StartsWith('-') } | ForEach-Object { $_.Trim('"', "'") })
    if ($scope.UntrackedAll) { return $scope }
    $scope.UntrackedPaths = $addPaths
    if ($opt.All) { return $scope }
    $scope.Wide = $false
    if ($opt.Paths.Count) {
        $scope.Paths = @($opt.Paths)
        $scope.Cached = [bool]$opt.Include
        return $scope
    }
    $scope.Paths = $addPaths
    return $scope
}

function Get-TaskAuditNames([string]$Dir, [string[]]$GitArgs, [string[]]$Spec) {
    return @((Invoke-CommitGit -Check 'warn-task-audit' -Dir $Dir -GitArgs (@('-c', 'core.quotepath=off') + $GitArgs + @('--') + $Spec)).Lines | Where-Object { $_ })
}

function Get-TaskAuditGrowth([string]$RuleDir, $Rule, $Scope) {
    $diffArgs = @('-c', 'core.quotepath=off', 'diff', '--unified=0', '--no-color', '--no-ext-diff')
    if ($Scope.Wide) {
        $run = Invoke-CommitGit -Check 'warn-task-audit' -Dir $RuleDir -GitArgs ($diffArgs + @('HEAD', '--') + @($Rule.Pathspec))
        if ($run.Code -ne 0 -and -not $run.TimedOut) { $run = Invoke-CommitGit -Check 'warn-task-audit' -Dir $RuleDir -GitArgs ($diffArgs + @('--cached', '--') + @($Rule.Pathspec)) }
        $diff = @($run.Lines)
    } else {
        $inRule = @(Get-TaskAuditNames $RuleDir @('diff', '--name-only', 'HEAD') @($Rule.Pathspec))
        $work = @()
        if ($Scope.Paths.Count) { $work = @(Get-TaskAuditNames $Scope.CommitDir @('diff', '--name-only', 'HEAD') @($Scope.Paths) | Where-Object { $inRule -ccontains $_ }) }
        $cached = @()
        if ($Scope.Cached) { $cached = @(Get-TaskAuditNames $RuleDir @('diff', '--name-only', '--cached') @($Rule.Pathspec) | Where-Object { $work -cnotcontains $_ }) }
        $diff = @()
        if ($work.Count) { $diff += @((Invoke-CommitGit -Check 'warn-task-audit' -Dir $RuleDir -GitArgs ($diffArgs + @('HEAD', '--') + @($work | ForEach-Object { ":(top,literal)$_" }))).Lines) }
        if ($cached.Count) { $diff += @((Invoke-CommitGit -Check 'warn-task-audit' -Dir $RuleDir -GitArgs ($diffArgs + @('--cached', '--') + @($cached | ForEach-Object { ":(top,literal)$_" }))).Lines) }
    }
    $net = 0
    foreach ($l in $diff) {
        if ($l -match '^(\+\+\+|---) (a/|b/|/dev/null)') { continue }
        if ($l.StartsWith('+') -and $Rule.Pattern.IsMatch($l.Substring(1))) { $net++ }
        elseif ($l.StartsWith('-') -and $Rule.Pattern.IsMatch($l.Substring(1))) { $net-- }
    }
    $capped = $false
    $files = @()
    if ($Scope.UntrackedAll) {
        $files = @(Get-TaskAuditNames $RuleDir @('ls-files', '--others', '--exclude-standard') @($Rule.Pathspec) | ForEach-Object { Join-Path $RuleDir $_ })
    } elseif ($Scope.UntrackedPaths.Count) {
        $ruleNew = @(Get-TaskAuditNames $RuleDir @('ls-files', '--others', '--exclude-standard', '--full-name') @($Rule.Pathspec))
        $top = [string](@((Invoke-CommitGit -Check 'warn-task-audit' -Dir $RuleDir -GitArgs @('rev-parse', '--show-toplevel')).Lines)[0])
        $files = @(Get-TaskAuditNames $Scope.CommitDir @('ls-files', '--others', '--exclude-standard', '--full-name') @($Scope.UntrackedPaths) | Where-Object { $ruleNew -ccontains $_ } | ForEach-Object { Join-Path $top $_ })
    }
    if ($files.Count) {
        if ($files.Count -gt $script:TaskAuditUntrackedMax) { $capped = $true; $files = $files[0..($script:TaskAuditUntrackedMax - 1)] }
        foreach ($full in $files) {
            if (-not (Test-Path -LiteralPath $full -PathType Leaf)) { continue }
            if ((Get-Item -LiteralPath $full).Length -gt 1MB) { $capped = $true; continue }
            foreach ($line in @(Get-Content -LiteralPath $full -Encoding UTF8 -ErrorAction SilentlyContinue)) {
                if ($Rule.Pattern.IsMatch([string]$line)) { $net++ }
            }
        }
    }
    return @{ Net = $net; Capped = $capped }
}

# RED·화면·Acceptance·원본 이탈 판정 줄 대조 — `skills/plan/scripts/check-plan.ps1` -Base 판정의 사본이다 · 근거는 `rules/task-audit-rationale.md` §7
function Get-TaskEvidenceLines([string]$AgentsPath, [string]$TaskId, [string]$Message) {
    $planPath = Join-Path ([System.IO.Path]::GetDirectoryName($AgentsPath)) 'plan.md'
    if (-not (Test-Path -LiteralPath $planPath -PathType Leaf)) { return @() }
    $plan = @(Get-Content -LiteralPath $planPath -Encoding UTF8 -ErrorAction SilentlyContinue)
    $block = @()
    $inBlock = $false
    foreach ($l in $plan) {
        if ($l -match '^#{2,3}\s') { $inBlock = $l -match ('^###\s+T' + $TaskId + '\.(\s|$)') ; continue }
        if ($inBlock) { $block += [string]$l }
    }
    $hasRed = [bool]@($block | Where-Object { $_.StartsWith('- **Files**:') -and $_.Contains('(RED)') }).Count
    $hasScreen = [bool]@($block | Where-Object { $_.StartsWith('- **화면**:') }).Count
    $acceptRow = @($block | Where-Object { $_.StartsWith('- **Acceptance**:') } | Select-Object -First 1)
    $originBare = @()
    if (@($block | Where-Object { $_.StartsWith('- **원본**:') }).Count) {
        $inProg = $false
        $fence = $null
        $prog = @(foreach ($l in $plan) {
            $fm = [regex]::Match([string]$l, '^ {0,3}(`{3,}|~{3,})')
            if ($fence) { if ($fm.Success -and $fm.Groups[1].Value[0] -eq $fence) { $fence = $null }; continue }
            if ($fm.Success) { $fence = $fm.Groups[1].Value[0]; continue }
            if ($l -match '^##\s') { $inProg = $l -match '^##\s+Progress Log'; continue }
            if ($inProg) { [string]$l }
        })
        $originBare = @($prog | Where-Object { $_ -match ('^- 판정(?:\([^)]*\))?:\s*T' + $TaskId + '(?:-\d+)?(?!\d)') -and $_ -match '대신|옮기지 않음' } | Where-Object {
            $basis = if ($_.Contains('— 근거:')) { ($_.Substring($_.IndexOf('— 근거:') + 5) -split '— 틀리면:', 2)[0] } else { '' }
            $basis -notmatch 'ask 답|사용자 답|→\s*\S'
        })
    }
    if (-not $hasRed -and -not $hasScreen -and -not $acceptRow.Count -and -not $originBare.Count) { return @() }

    $bodies = @($Message)
    $script:TaskEvidenceBaseRead = $false
    $baseLine = @($plan | Where-Object { $_ -match '^> BASE:\s*([0-9a-fA-F]{7,40})\s*$' } | Select-Object -First 1)
    if ($baseLine.Count -and $baseLine[0] -match '^> BASE:\s*([0-9a-fA-F]{7,40})') {
        $log = Invoke-CommitGit -Check 'warn-task-audit' -Dir ([System.IO.Path]::GetDirectoryName($AgentsPath)) -GitArgs @('-c', 'core.quotepath=off', '-c', 'i18n.logOutputEncoding=UTF-8', 'log', '--format=%B%x00', ($Matches[1] + '..HEAD'))
        if ($log.Code -eq 0) {
            $script:TaskEvidenceBaseRead = $true
            $titleRx = '^\s*(?:(?:기능|수정|리팩토링|문서|설정)\s*:\s*)?T' + $TaskId + '\s*(?::|—|-)'
            foreach ($c in ((@($log.Lines) -join "`n") -split "`0")) {
                $c = $c.Trim()
                if (-not $c) { continue }
                if ([regex]::IsMatch(@($c -split "`n")[0], $titleRx)) { $bodies += $c }
            }
        }
    }
    $text = $bodies -join "`n"
    $lineHead = '(?m)^\s*(?:[-*]\s*)?'
    $out = @()
    if ($acceptRow.Count -and @($bodies | Where-Object { [regex]::IsMatch($_, '검증\s*(?:결과|:)') }).Count) {
        $criteria = [regex]::Replace($acceptRow[0].Substring('- **Acceptance**:'.Length), '`[^`]*`', 'x')
        do { $prev = $criteria; $criteria = [regex]::Replace($criteria, '\([^()]*\)', '') } while ($criteria -ne $prev)
        $want = @($criteria -split '\s·\s' | Where-Object { $_.Trim() }).Count
        $have = [regex]::Matches($text, $lineHead + 'Acceptance\s*:\s*\S').Count
        if ($have -lt $want) {
            $out += "  - Acceptance 판정 줄 $have/$want — ``- **Acceptance**:`` 항목마다 본문에 ``Acceptance: <항목> — 참`` 줄을 둔다"
        }
    }
    if ($hasRed -and -not [regex]::IsMatch($text, $lineHead + 'RED(?:\((?:구현 전|사후[^)\r\n]*)\))?\s*:\s*\S')) {
        $out += "$($script:TaskAuditRedMissing) — Files 줄에 (RED) 가 있는 task 다. 본문에 ``RED(구현 전): <실패 출력>`` (또는 ``RED: 미확인 — <사유>``) 줄을 둔다"
    }
    $verdictRx = $lineHead + '화면:\s*(?:HEAD\s*(?:참|거짓)|미촬영\(HUMAN-VERIFY\))'
    if ($hasScreen -and -not [regex]::IsMatch($text, $verdictRx)) {
        $odd = @([regex]::Matches($Message, '(?m)^\s*(?:[-*]\s*)?화면\s*[^\s:]*\s*:.*$') | ForEach-Object { $_.Value.Trim() } | Select-Object -First 1)
        $seen = if ($odd.Count) { " — 본 줄: ``$($odd[0])``" } else { '' }
        $out += "  - 화면 판정 줄 없음 — ``- **화면**:`` 줄이 있는 task 다. 본문에 ``화면: HEAD 참|거짓 — <스크린샷>`` 또는 ``화면: 미촬영(HUMAN-VERIFY) · 사유 <…> · 시도 <…>`` 줄을 둔다$seen"
    }
    if ($originBare.Count) {
        $out += "  - 원본 이탈 판정 줄 근거 없음 $($originBare.Count)줄 — ``- **원본**:`` 줄 task 의 「대신」·「옮기지 않음」 판정 줄은 근거 칸에 ``<명령> → <출력 요지>``·``사용자 답``·``ask 답 <id>`` 를 싣는다(skills/implement/references/code-style.md「원본을 옮길 때」): ``$(([string]$originBare[0]).Trim())``"
    }
    $verify = @(Get-Content -LiteralPath $AgentsPath -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $_ -match '^\s*-\s*\*\*Verify \(앱 조작\)\*\*\s*:\s*(.*)$' } | Select-Object -First 1)
    $verifyOn = $verify.Count -and ($verify[0] -replace '^\s*-\s*\*\*Verify \(앱 조작\)\*\*\s*:\s*', '') -notmatch '^\W*없음'
    if ($hasScreen -and $verifyOn -and -not [regex]::IsMatch($text, $lineHead + '화면:\s*HEAD\s*참')) {
        $tails = @([regex]::Matches($text, $lineHead + '화면:\s*미촬영\(HUMAN-VERIFY\)(.*)$') | ForEach-Object { $_.Groups[1].Value })
        $withReason = @($tails | Where-Object { $_ -match '·\s*사유\s+\S' })
        $attempted = @($withReason | Where-Object { $_ -match '·\s*시도\s+(?!없음|[—-]\s*(?:$|[·(]))\S' -or $_ -match '·\s*사유\s+(?:기준선 흔들림|image-diff:\s*ERROR)' })
        if ($withReason.Count -and -not $attempted.Count) {
            $out += "  - 미촬영 줄에 시도 칸 없음 — 검증 스킬이 있는 레포다. 범용 도구·보강을 시도한 수단을 ``· 시도 <…>`` 칸으로 단다 — 값이 없음·—·- 면 빈 칸이다(사유가 기준선 흔들림·image-diff: ERROR 면 면제 · skills/implement/references/screen-scenarios.md)"
        }
    }
    return $out
}

function New-TaskAuditResult([string]$TaskId, $AuditLines, $EvidenceLines, [string[]]$Extra = @()) {
    $parts = @($Extra)
    if (@($AuditLines).Count) {
        $parts += "[HARNESS] T$TaskId 완료 커밋에 AGENTS.md 「Test (감사)」 명령이 없습니다 — 필터 테스트는 이 감사를 돌리지 않습니다."
        $parts += @($AuditLines)
    }
    if (@($EvidenceLines).Count) {
        $parts += "[HARNESS] T$TaskId 완료 커밋의 검증 기록이 회차 끝 증거 대조(check-plan -Base)에 걸립니다:"
        $parts += @($EvidenceLines)
    }
    if (-not (@($AuditLines).Count + @($EvidenceLines).Count)) {
        if (@($Extra).Count) { return New-HookResult -Stderr @($Extra) }
        return New-HookResult
    }
    $redBlock = $script:TaskEvidenceBaseRead -and @($EvidenceLines | Where-Object { ([string]$_).StartsWith($script:TaskAuditRedMissing) }).Count
    if ($redBlock) {
        $parts = @("[HARNESS] BLOCKED: 완료 커밋에 RED 줄이 없습니다 — T$TaskId 는 Files 줄에 (RED) 가 있는 task 라 본문에 ``RED(구현 전): <실패 출력>`` 또는 ``RED: 미확인 — <사유>`` 줄을 넣어 같은 커밋을 다시 내세요(커밋 뒤 보충 커밋이 아닙니다).") + $parts
        $parts += '위 다른 항목도 같은 메시지에 함께 넣으세요.'
        return New-HookResult -Block $true -Stderr @(($parts | ForEach-Object { $_ }) -join "`n")
    }
    $parts += "이 경고는 커밋을 막지 않습니다. 커밋 뒤 빠진 명령·기록을 ``git commit --allow-empty`` 보충 커밋(제목 ``{유형}: T$TaskId — 검증 기록 보충``)의 본문에 남기세요. 실패하면 수정 커밋을 합니다."
    $msg = ($parts | ForEach-Object { $_ }) -join "`n"
    return New-HookResult -Block $false -Stderr @($msg) -Context $msg
}

# 회차 전 untracked 파일이 커밋에 드는가 — 근거는 `rules/task-audit-rationale.md` §8
function Get-UntrackedStartLines([string]$Judge, $Cm, [string]$CommitDir) {
    if (-not (Get-Command Find-SinglePlanUpwards -ErrorAction SilentlyContinue)) { return @() }
    $planFile = Find-SinglePlanUpwards -StartDir $CommitDir
    if (-not $planFile) { return @() }
    $base = @(Get-Content -LiteralPath $planFile -Encoding UTF8 -ErrorAction SilentlyContinue | Where-Object { $_ -match '^> BASE:\s*[0-9a-fA-F]{7,40}\s*$' } | Select-Object -First 1)
    if (-not $base.Count) { return @() }
    $sha7 = ([regex]::Match($base[0], '[0-9a-fA-F]{7,40}').Value).Substring(0, 7).ToLower()
    $planDir = [System.IO.Path]::GetDirectoryName($planFile)
    $snapName = 'untracked-start-' + (Split-Path -Leaf $planDir) + '-' + $sha7 + '.txt'
    $snap = Join-Path ([System.IO.Path]::GetTempPath()) (Join-Path 'karina-plugin/scratch' $snapName)
    if (-not (Test-Path -LiteralPath $snap -PathType Leaf)) { return @() }
    $prefix = (@((Invoke-CommitGit -Check 'warn-task-audit' -Dir $planDir -GitArgs @('rev-parse', '--show-prefix')).Lines) -join '').Trim()
    $start = New-Object System.Collections.Generic.HashSet[string]
    foreach ($l in @(Get-Content -LiteralPath $snap -Encoding UTF8 -ErrorAction SilentlyContinue)) {
        $t = ([string]$l).Trim()
        if ($t) { [void]$start.Add($prefix + ($t -replace '\\', '/')) }
    }
    if (-not $start.Count) { return @() }
    $entering = @(Get-TaskAuditNames $CommitDir @('diff', '--cached', '--name-only', '--diff-filter=A') @())
    $scope = Get-TaskAuditScope $Judge $Cm $CommitDir
    if ($scope.UntrackedAll) { $entering += @(Get-TaskAuditNames $CommitDir @('ls-files', '--others', '--exclude-standard', '--full-name') @()) }
    elseif (@($scope.UntrackedPaths).Count) { $entering += @(Get-TaskAuditNames $CommitDir @('ls-files', '--others', '--exclude-standard', '--full-name') @($scope.UntrackedPaths)) }
    $hits = @($entering | Where-Object { $start.Contains($_) } | Select-Object -Unique)
    if (-not $hits.Count) { return @() }
    $shown = ($hits | Select-Object -First 5) -join ', '
    $more = if ($hits.Count -gt 5) { " 외 $($hits.Count - 5)개" } else { '' }
    return @("[HARNESS] 회차 전부터 있던 untracked 파일이 이 커밋에 들어갑니다: ${shown}${more} — 의도한 것이 아니면 커밋 뒤 ``git rm --cached $($hits[0])`` 처럼 추적만 되돌리고, 다음부터 파일 이름으로 add 하세요(스냅숏 $snapName · 경고 전용).")
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
    $r = Invoke-TaskAuditOnCommit $cmd $judge $cm $commitDir
    $untracked = @(Get-UntrackedStartLines $judge $cm $commitDir)
    if (-not $untracked.Count) { return $r }
    $msg = $untracked -join "`n"
    $ctx = if ($r -and $r.Context) { [string]$r.Context + "`n`n" + $msg } else { $msg }
    $stderr = @(if ($r) { $r.Stderr }) + @($msg) | Where-Object { $_ }
    if ($r -and $r.Block) { return New-HookResult -Block $true -Stderr $stderr }
    return New-HookResult -Block $false -Stderr $stderr -Context $ctx
}

function Invoke-TaskAuditOnCommit([string]$cmd, [string]$judge, $cm, [string]$commitDir) {
    $message = Get-CommitMessage $cmd $commitDir
    if ($null -eq $message -or $message -is [bool]) { return New-HookResult }
    $title = @($message -split '\r?\n')[0]
    $tm = [regex]::Match($title, '^\s*(?:(?:기능|수정|리팩토링|문서|설정)\s*:\s*)?T(\d+(?:-\d+)?)\s*(?::|—|-)')
    if (-not $tm.Success) { return New-HookResult }

    $agents = Find-TaskAuditAgents $commitDir
    if (-not $agents) { return New-HookResult }
    $t = $tm.Groups[1].Value
    $evidence = @(if (-not $t.Contains('-')) { Get-TaskEvidenceLines $agents $t $message })
    # 감사 줄 파서는 comment-lines.ps1 에 있고 검사 호출 시점에만 부른다 — 근거는 `rules/task-audit-rationale.md` §6
    if (-not (Get-Command Get-TaskAuditRules -ErrorAction SilentlyContinue)) {
        try { . (Join-Path $PSScriptRoot 'comment-lines.ps1') } catch {}
    }
    if (-not (Get-Command Get-TaskAuditRules -ErrorAction SilentlyContinue)) {
        $w = '[guard-bash] comment-lines.ps1 로드 실패 — task 감사 누락 검사 미수행(fail-open). 플러그인 재설치를 권장합니다.'
        return New-TaskAuditResult $t @() $evidence @($w)
    }
    $rules = @(Get-TaskAuditRules $agents)
    if (-not $rules.Count) { return New-TaskAuditResult $t @() $evidence }
    $ruleDir = [System.IO.Path]::GetDirectoryName($agents)
    $scope = Get-TaskAuditScope $judge $cm $commitDir

    $lines = New-Object System.Collections.Generic.List[string]
    $taskTemplate = Get-TaskAuditTaskTemplate $agents
    foreach ($rule in $rules) {
        if ($rule.Error) {
            $lines.Add("  - 규칙을 읽지 못함: AGENTS.md:$($rule.Line) ($($rule.Error)) — 이 줄은 검사되지 않습니다")
            continue
        }
        $g = Get-TaskAuditGrowth $ruleDir $rule $scope
        if ($g.Net -le 0) { continue }
        $accepted = @($rule.Command) + @($rule.Alternatives)
        if (@($accepted | Where-Object { Test-TaskAuditCommandInMessage $message $_ }).Count) { continue }
        if (Test-TaskAuditFilterCovered $message $rule.Command $taskTemplate) { continue }
        $note = if ($g.Capped) { ' (미추적 파일 상한에 걸려 일부만 셈)' } else { '' }
        $lines.Add("  - ``$($rule.Command)`` — 증가 $($g.Net)줄$note (AGENTS.md:$($rule.Line))")
    }
    if (Test-CommitGitTimedOut 'warn-task-audit') {
        $w = "[guard-bash] git 이 시간 상한($(Get-CommitGitLimitMs)ms) 안에 답하지 않아 task 감사 누락 검사를 건너뜁니다."
        return New-TaskAuditResult $t @() $evidence @($w)
    }
    return New-TaskAuditResult $t $lines.ToArray() $evidence
}
