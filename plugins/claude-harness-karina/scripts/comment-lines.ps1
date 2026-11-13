# comment-lines.ps1 — 새 주석 줄 판별 (dot-source 전용) — 근거는 `rules/comment-gate-rationale.md` §2

try { . (Join-Path $PSScriptRoot 'timed-git.ps1') } catch {}

$script:CommentSlashExts = @('.cs', '.ts', '.tsx', '.js', '.jsx', '.java', '.go', '.rs', '.cpp', '.c', '.h', '.hpp', '.fs', '.kt', '.swift')
$script:CommentHashExts = @('.py', '.ps1', '.psm1', '.psd1', '.sh', '.yaml', '.yml', '.toml')
$script:CommentPsExts = @('.ps1', '.psm1', '.psd1')
$script:CommentConfExts = @('.yaml', '.yml', '.toml')
$script:CommentLegalRx = '(?i)^(spdx-license-identifier|copyright|@license|-\*-\s*coding)'
$script:CommentSlashMarkRx = [regex]::new('(?m)^[^\S\n]*(?://|/\*)')
$script:CommentHashMarkRx = [regex]::new('(?m)^[^\S\n]*<?#')
$script:CommentDocMarkRx = [regex]::new('(?m)^[^\S\n]*(?:///|//!|/\*\*)')
$script:CommentExemptRx = '(?i)^(eslint-|prettier-ignore|@ts-|noqa|type:\s*ignore|pylint:|pyright:|mypy:|nolint|istanbul ignore|c8 ignore|biome-ignore|resharper|fmt:\s*(off|on)\b|isort:|<reference|spdx-license-identifier|copyright|@license|-\*-\s*coding)'

function Test-CommentTarget([string]$Path) {
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    return ($script:CommentSlashExts -contains $ext) -or ($script:CommentHashExts -contains $ext)
}

function Get-CommentBodies([string]$Path, [string[]]$Lines) {
    $bodies = New-Object System.Collections.Generic.List[string]
    foreach ($e in (Get-CommentBodyLines $Path $Lines)) { $bodies.Add($e.Body) }
    return , $bodies
}

function Get-CommentBodyLines([string]$Path, [string[]]$Lines, [switch]$KeepDirectives) {
    $bodies = New-Object System.Collections.Generic.List[object]
    if (-not (Test-CommentTarget $Path) -or $null -eq $Lines) { return , $bodies }
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    $isSlash = $script:CommentSlashExts -contains $ext
    $exemptRx = if ($KeepDirectives) { $script:CommentLegalRx } else { $script:CommentExemptRx }
    $rawExempt = if ($KeepDirectives) { '(?!)' } elseif ($isSlash) { '^//(go:|\s*#(end)?region\b)' } elseif ($script:CommentPsExts -contains $ext) { '(?i)^#(requires|(end)?region)\b' } elseif ($script:CommentConfExts -contains $ext) { '^#(cloud-config\b|:schema\b|\s*yamllint (disable|enable)\b|\s*yaml-language-server:)' } else { '(?!)' }
    $isPs = $script:CommentPsExts -contains $ext
    $inBlock = $false
    $next = 0
    foreach ($start in (Get-CommentMarkerIndexes $Lines $(if ($isSlash) { $script:CommentSlashMarkRx } else { $script:CommentHashMarkRx }))) {
        if ($start -lt $next) { continue }
        $n = $start
        do {
            $t = ([string]$Lines[$n]).Trim()
            $body = $null
            if ($inBlock) {
                $body = $t -replace '^\*+(?!/)', ''
                if ($t -match '\*/|#>') { $inBlock = $false }
            } elseif ($isSlash -and $t.StartsWith('//')) {
                $body = $t -replace '^/{2,}!?', ''
            } elseif ($isSlash -and $t.StartsWith('/*')) {
                $body = $t -replace '^/\*+!?', ''
                $inBlock = -not ($body -match '\*/')
            } elseif ((-not $isSlash) -and $isPs -and $t.StartsWith('<#')) {
                $body = $t.Substring(2)
                $inBlock = -not ($body -match '#>')
            } elseif ((-not $isSlash) -and $t.StartsWith('#') -and -not $t.StartsWith('#!')) {
                $body = $t -replace '^#+', ''
            }
            if ($null -ne $body) {
                $body = ($body -replace '(\*/|#>)\s*$', '').Trim()
                if (-not ($body -eq '' -or $body -match $exemptRx -or $t -match $rawExempt)) { $bodies.Add(@{ Body = $t; Line = $n }) }
            }
            $n++
        } while ($inBlock -and $n -lt $Lines.Count)
        $next = $n
    }
    return , $bodies
}

function Get-CommentMarkerIndexes([string[]]$Lines, [regex]$Rx) {
    $hits = New-Object System.Collections.Generic.List[int]
    if ($Lines.Count -eq 0) { return , $hits }
    $text = [string]::Join("`n", $Lines)
    $found = $Rx.Matches($text)
    if ($found.Count -eq 0) { return , $hits }
    $breaks = [regex]::Matches($text, "`n")
    if ($breaks.Count -eq 0) { foreach ($m in $found) { $hits.Add(0) }; return , $hits }
    [int[]]$at = $breaks.Index
    foreach ($m in $found) { $hits.Add(-bnot [Array]::BinarySearch($at, $m.Index)) }
    return , $hits
}

function Format-CommentGatePreview($Bodies) {
    return @($Bodies | Select-Object -First 3 | ForEach-Object { '  | ' + $(if ($_.Length -gt 100) { $_.Substring(0, 100) + '…' } else { $_ }) })
}

$script:CommentGateRule = '  통과하는 주석은 라이선스·린트 지시문 · 이슈/RFC 링크·트래커 키·실재하는 레포 .md 경로가 든 줄 · .rs SAFETY: · 레포 감사(Test (감사))가 요구하거나 라이브러리 공개 항목 위의 doc · AGENTS.md Comment (보존) 선언 · 기존 주석의 문구 수정 · 그 회차 plan.md BASE 커밋에 있던 주석 줄(복원)뿐입니다 (code-style.md「주석」).'
$script:CommentLinkRx = '(?i)https?://\S*(/issues/\d+|/pull/\d+|/-/issues/\d+|rfc-editor\.org)|\bRFC ?\d{3,4}\b|\b(issue|PR|GH)[ -]?#\d+|이슈 ?#\d+'
$script:CommentTrackerRx = '\b(?!(UTF|SHA|ISO|CP|IEC|IEEE|ECMA|ANSI|CRC|AES|RSA|TLS|HTTP|MD|BASE)[A-Z0-9]*-)[A-Z]{2,}[A-Z0-9]*-\d+\b'
$script:CommentTodoRx = '\b(TODO|FIXME|XXX)\b'
$script:CommentBaseBudgetMs = 10000
$script:CommentKeepLineRx = '^- \*\*Comment \(보존\)\*\*: `(?<rx>[^`]+)` · 경로: `(?<paths>[^`]+)`'
$script:TaskAuditLineRx = '^- \*\*Test \(감사\)\*\*: `(?<cmd>[^`]+)`(?<rest>.*)$'

function Get-TaskAuditRules([string]$AgentsPath) {
    $rules = New-Object System.Collections.Generic.List[object]
    if (-not (Test-Path -LiteralPath $AgentsPath -PathType Leaf)) { return $rules.ToArray() }
    $lines = @(Get-Content -LiteralPath $AgentsPath -Encoding UTF8)
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $m = [regex]::Match([string]$lines[$i], $script:TaskAuditLineRx)
        if (-not $m.Success) { continue }
        $rest = $m.Groups['rest'].Value
        $inc = [regex]::Match($rest, ' · 증가: `([^`]+)`')
        $pathM = [regex]::Match($rest, ' · 경로: `([^`]+)`')
        $rule = @{
            Line         = $i + 1
            Command      = $m.Groups['cmd'].Value.Trim()
            Pattern      = $null
            Pathspec     = if ($pathM.Success) { $pathM.Groups[1].Value } else { '.' }
            Alternatives = @([regex]::Matches($rest, ' · 또는: `([^`]+)`') | ForEach-Object { $_.Groups[1].Value.Trim() })
            Error        = $null
        }
        if (-not $inc.Success) { $rule.Error = '증가 정규식 없음' }
        else {
            try { $rule.Pattern = [regex]::new($inc.Groups[1].Value) } catch { $rule.Error = '정규식 오류' }
        }
        $rules.Add($rule)
    }
    return $rules.ToArray()
}

$script:CommentRewriteBudgetPairs = 2000

function New-CommentRewriteBudget { return @{ Pairs = $script:CommentRewriteBudgetPairs } }

function Get-CommentBigrams([string]$Body) {
    $t = $Body -replace '^(/{2,}!?|/\*+!?|\*+|<#|#+)\s*', ''
    $set = New-Object System.Collections.Generic.HashSet[string]
    for ($i = 0; $i -lt $t.Length - 1; $i++) { [void]$set.Add($t.Substring($i, 2)) }
    return , $set
}

function Get-RewordedCandidateIndexes($Gone, $Candidates, $Budget) {
    $picked = New-Object System.Collections.Generic.HashSet[int]
    $n = [Math]::Min($Gone.Count, $Candidates.Count)
    $cost = $Gone.Count * $Candidates.Count
    if ($Candidates.Count -le $Gone.Count -or $cost -gt $Budget.Pairs) {
        for ($i = 0; $i -lt $n; $i++) { [void]$picked.Add($i) }
        return , $picked
    }
    $Budget.Pairs -= $cost
    $candGrams = @($Candidates | ForEach-Object { , (Get-CommentBigrams $_.Body) })
    $scores = New-Object 'System.Collections.Generic.List[System.ValueTuple[double,int,int]]'
    for ($g = 0; $g -lt $Gone.Count; $g++) {
        $goneGrams = Get-CommentBigrams $Gone[$g]
        for ($c = 0; $c -lt $Candidates.Count; $c++) {
            $total = $goneGrams.Count + $candGrams[$c].Count
            $s = 0.0
            if ($goneGrams.Count -gt 0 -and $candGrams[$c].Count -gt 0) {
                $shared = [System.Collections.Generic.HashSet[string]]::new($goneGrams)
                $shared.IntersectWith($candGrams[$c])
                $s = (2.0 * $shared.Count) / $total
            }
            $scores.Add([System.ValueTuple]::Create(-$s, $c, $g))
        }
    }
    $scores.Sort()
    $usedGone = New-Object System.Collections.Generic.HashSet[int]
    foreach ($s in $scores) {
        if ($picked.Count -ge $n) { break }
        if ($usedGone.Contains($s.Item3) -or $picked.Contains($s.Item2)) { continue }
        [void]$usedGone.Add($s.Item3)
        [void]$picked.Add($s.Item2)
    }
    return , $picked
}

function Get-AddedCommentBodies([string]$Path, $Pairs, $Budget = $null) {
    if ($null -eq $Budget) { $Budget = New-CommentRewriteBudget }
    $added = New-Object System.Collections.Generic.List[object]
    for ($p = 0; $p -lt @($Pairs).Count; $p++) {
        $pair = @($Pairs)[$p]
        $oldBodies = Get-CommentBodies $Path ([string]$pair[0] -split '\r?\n')
        $newLines = Get-CommentBodyLines $Path ([string]$pair[1] -split '\r?\n')
        $oldSet = New-Object System.Collections.Generic.HashSet[string]
        foreach ($o in ([string]$pair[0] -split '\r?\n')) { [void]$oldSet.Add($o.Trim()) }
        $newSet = New-Object System.Collections.Generic.HashSet[string]
        foreach ($c in $newLines) { [void]$newSet.Add($c.Body) }
        $gone = @($oldBodies | Where-Object { -not $newSet.Contains($_) })
        $candidates = @($newLines | Where-Object { -not $oldSet.Contains($_.Body) })
        $reworded = Get-RewordedCandidateIndexes $gone $candidates $Budget
        for ($i = 0; $i -lt $candidates.Count; $i++) {
            if ($reworded.Contains($i)) { continue }
            $added.Add(@{ Body = $candidates[$i].Body; Pair = $p; Line = $candidates[$i].Line; Indexes = @() })
        }
    }
    return , $added
}

function Find-CommentRepoRoot([string]$Dir) {
    $cur = $Dir
    while ($cur) {
        if (Test-Path -LiteralPath (Join-Path $cur '.git')) { return $cur }
        $parent = Split-Path -Parent $cur
        if (-not $parent -or $parent -eq $cur) { return $null }
        $cur = $parent
    }
    return $null
}

function Get-CommentSearchDirs([string]$Dir, [string]$Root) {
    if (-not $Root) { return @($Dir) }
    $dirs = New-Object System.Collections.Generic.List[string]
    $cur = $Dir
    while ($cur) {
        $dirs.Add($cur)
        if ($cur -eq $Root) { break }
        $parent = Split-Path -Parent $cur
        if (-not $parent -or $parent -eq $cur) { break }
        $cur = $parent
    }
    return $dirs.ToArray()
}

function Test-CommentPathLike([string]$File, [string]$Base, [string]$Pattern) {
    $rel = try { [System.IO.Path]::GetRelativePath($Base, $File) -replace '\\', '/' } catch { '' }
    $leaf = [System.IO.Path]::GetFileName($File)
    return ($rel -like $Pattern) -or ($leaf -like $Pattern)
}

function Test-CommentLineExempt([string]$Line, [string]$Path, [string]$Dir, [string]$Root) {
    if ($Line -match $script:CommentTodoRx) { return $false }
    if ($Line -match $script:CommentLinkRx -or $Line -cmatch $script:CommentTrackerRx) { return $true }
    if ([System.IO.Path]::GetExtension($Path).ToLower() -eq '.rs' -and $Line -match '^/{2,}!?\s*SAFETY:') { return $true }
    foreach ($m in [regex]::Matches($Line, '[\w.\\/-]+\.md\b')) {
        $tok = $m.Value
        foreach ($b in @($Dir, $Root)) {
            if ($b -and (Test-Path -LiteralPath (Join-Path $b $tok) -PathType Leaf)) { return $true }
        }
    }
    return $false
}

function Get-CommentRepoContext([string]$Path) {
    $full = [System.IO.Path]::GetFullPath($Path)
    $dir = Split-Path -Parent $full
    $root = Find-CommentRepoRoot $dir
    $ctx = @{ File = $full; Dir = $dir; Root = $root; Agents = $null; AuditRules = @(); KeepRules = @(); Library = $false }
    $dirs = Get-CommentSearchDirs $dir $root
    foreach ($d in $dirs) {
        $cand = Join-Path $d 'AGENTS.md'
        if (Test-Path -LiteralPath $cand -PathType Leaf) { $ctx.Agents = $cand; break }
    }
    if ($ctx.Agents) {
        $ctx.AuditRules = @(Get-TaskAuditRules $ctx.Agents | Where-Object { $_.Pattern })
        $keep = New-Object System.Collections.Generic.List[object]
        foreach ($l in @(Get-Content -LiteralPath $ctx.Agents -Encoding UTF8)) {
            $m = [regex]::Match([string]$l, $script:CommentKeepLineRx)
            if (-not $m.Success) { continue }
            try { $keep.Add(@{ Pattern = [regex]::new($m.Groups['rx'].Value); Paths = @($m.Groups['paths'].Value -split '\s+' | Where-Object { $_ }) }) } catch {}
        }
        $ctx.KeepRules = $keep.ToArray()
    }
    $ext = [System.IO.Path]::GetExtension($full).ToLower()
    foreach ($d in $dirs) {
        if ($ext -eq '.rs' -and (Test-Path -LiteralPath (Join-Path $d 'Cargo.toml') -PathType Leaf)) {
            $t = [System.IO.File]::ReadAllText((Join-Path $d 'Cargo.toml'))
            $hasLib = ($t -match '(?m)^\s*\[lib\]') -or (Test-Path -LiteralPath (Join-Path $d 'src/lib.rs') -PathType Leaf)
            $ctx.Library = $hasLib -and -not ($t -match '(?m)^\s*publish\s*=\s*false')
            break
        }
        if ($ext -eq '.cs') {
            $proj = @(Get-ChildItem -LiteralPath $d -Filter '*.csproj' -File -ErrorAction SilentlyContinue | Select-Object -First 1)
            if ($proj.Count) {
                $t = [System.IO.File]::ReadAllText($proj[0].FullName)
                $ctx.Library = -not ($t -match '<OutputType>\s*(Exe|WinExe)\s*<' -or $t -match '<IsPackable>\s*false\s*<')
                break
            }
        }
        if (@('.ts', '.tsx', '.js', '.jsx') -contains $ext -and (Test-Path -LiteralPath (Join-Path $d 'package.json') -PathType Leaf)) {
            $ctx.Library = -not ([System.IO.File]::ReadAllText((Join-Path $d 'package.json')) -match '"private"\s*:\s*true')
            break
        }
    }
    return $ctx
}

function Test-CommentPublicItem([string]$Ext, [string]$Code) {
    switch ($Ext) {
        '.rs' { return $Code -match '^pub\s' }
        '.cs' { return $Code -match '^(public|protected)\s' }
        default { return $Code -match '^export\s' }
    }
}

function Get-CommentDocFlags([string[]]$Lines) {
    $docFlag = New-Object bool[] $Lines.Count
    $inDoc = $false
    $next = 0
    foreach ($start in (Get-CommentMarkerIndexes $Lines $script:CommentDocMarkRx)) {
        if ($start -lt $next) { continue }
        $i = $start
        do {
            $t = ([string]$Lines[$i]).Trim()
            if ($inDoc) { $docFlag[$i] = $true; if ($t -match '\*/') { $inDoc = $false } }
            elseif ($t.StartsWith('///') -or $t.StartsWith('//!')) { $docFlag[$i] = $true }
            elseif ($t.StartsWith('/**')) { $docFlag[$i] = $true; $inDoc = -not ($t.Substring(3) -match '\*/') }
            $i++
        } while ($inDoc -and $i -lt $Lines.Count)
        $next = $i
    }
    return , $docFlag
}

function Get-CommentDocTarget([string]$Path, [string[]]$Lines, [int]$Index, [bool[]]$DocFlag, $Attrs = $null) {
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    $docFlag = $DocFlag
    if ($Index -lt 0 -or $Index -ge $docFlag.Count -or -not $docFlag[$Index]) { return $null }
    $attrRx = switch ($ext) { '.rs' { '^#!?\[' } '.cs' { '^\[' } default { '^@' } }
    for ($j = $Index + 1; $j -lt $Lines.Count; $j++) {
        $t = ([string]$Lines[$j]).Trim()
        if ($t -eq '' -or $docFlag[$j] -or $t.StartsWith('//')) { continue }
        if ($t -match $attrRx) {
            if ($null -ne $Attrs) { $Attrs.Add($t) }
            $depth = 0
            while ($j -lt $Lines.Count) {
                $s = [string]$Lines[$j]
                $depth += ([regex]::Matches($s, '[\[(]')).Count - ([regex]::Matches($s, '[\])]')).Count
                if ($depth -le 0) { break }
                $j++
            }
            if ($j -ge $Lines.Count) { return $null }
            continue
        }
        return $t
    }
    return $null
}

function New-CommentBaseBudget { return @{ LeftMs = [int]$script:CommentBaseBudgetMs } }

function Get-CommentPlanBase([string]$Dir, [string]$Root) {
    foreach ($d in (Get-CommentSearchDirs $Dir $Root)) {
        $cand = Join-Path $d 'plan.md'
        if (-not (Test-Path -LiteralPath $cand -PathType Leaf)) { continue }
        $m = [regex]::Match([System.IO.File]::ReadAllText($cand), '(?m)^> BASE: ([0-9a-f]{7,40})\b')
        if ($m.Success) { return $m.Groups[1].Value }
        return $null
    }
    return $null
}

function Get-CommentBaseLines([string]$File, [string]$Dir, [string]$Root, $Budget) {
    try {
        if (-not $Root -or -not $File.StartsWith($Root, [System.StringComparison]::OrdinalIgnoreCase)) { return @() }
        $sha = Get-CommentPlanBase $Dir $Root
        if (-not $sha) { return @() }
        $left = [int]$Budget.LeftMs
        if ($left -le 0) { return @() }
        $rel = $File.Substring($Root.Length).TrimStart('\', '/') -replace '\\', '/'
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $run = Invoke-TimedGit -GitArgs @('-C', $Root, '-c', 'core.quotepath=off', 'show', "${sha}:$rel") -WorkDir $Root -TimeoutMs $left
        $Budget.LeftMs = $left - [int]$sw.ElapsedMilliseconds
        if ($run.Code -ne 0) { return @() }
        return @($run.Lines)
    } catch { return @() }
}

function Get-BlockedCommentBodies([string]$Path, $Added, [string[]]$PostLines, $Budget = $null) {
    $blocked = New-Object System.Collections.Generic.List[string]
    if ($Added.Count -eq 0) { return , $blocked }
    $ctx = Get-CommentRepoContext $Path
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    $base = if ($ctx.Agents) { Split-Path -Parent $ctx.Agents } else { $ctx.Dir }
    $docFlag = $null
    foreach ($a in $Added) {
        $c = [string]$a.Body
        if (Test-CommentLineExempt $c $Path $ctx.Dir $ctx.Root) { continue }
        $kept = $false
        foreach ($k in $ctx.KeepRules) {
            if (-not $k.Pattern.IsMatch($c)) { continue }
            foreach ($p in $k.Paths) { if (Test-CommentPathLike $ctx.File $base $p) { $kept = $true } }
        }
        if ($kept) { continue }
        if ($c -notmatch $script:CommentTodoRx -and @('.rs', '.cs', '.ts', '.tsx', '.js', '.jsx') -contains $ext -and @($a.Indexes).Count -gt 0) {
            $allOk = $true
            if ($null -eq $docFlag) { $docFlag = Get-CommentDocFlags $PostLines }
            foreach ($ix in @($a.Indexes)) {
                $attrs = New-Object System.Collections.Generic.List[string]
                $code = Get-CommentDocTarget $Path $PostLines $ix $docFlag $attrs
                $ok = $false
                if ($code) {
                    $cands = @($code) + @($attrs)
                    $audited = @($ctx.AuditRules | Where-Object { $rule = $_; (@($cands | Where-Object { $rule.Pattern.IsMatch($_) }).Count -gt 0) -and (Test-CommentPathLike $ctx.File $base $rule.Pathspec) }).Count -gt 0
                    $ok = $audited -or ($ctx.Library -and (Test-CommentPublicItem $ext $code))
                }
                if (-not $ok) { $allOk = $false; break }
            }
            if ($allOk) { continue }
        }
        $blocked.Add($c)
    }
    if ($blocked.Count -eq 0) { return , $blocked }
    if ($null -eq $Budget) { $Budget = New-CommentBaseBudget }
    $baseSet = New-Object System.Collections.Generic.HashSet[string]
    foreach ($b in (Get-CommentBodies $Path (Get-CommentBaseLines $ctx.File $ctx.Dir $ctx.Root $Budget))) { [void]$baseSet.Add($b) }
    $kept = New-Object System.Collections.Generic.List[string]
    foreach ($c in $blocked) { if (-not $baseSet.Contains($c)) { $kept.Add($c) } }
    if ($kept.Count -eq 0) { return , $kept }
    return , (Get-CommentMovedBodies $ctx $kept $Budget)
}

function Get-CommentMovedBodies($Ctx, $Bodies, $Budget) {
    try {
        $root = $Ctx.Root
        if (-not $root -or -not $Ctx.File.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) { return , $Bodies }
        $sha = Get-CommentPlanBase $Ctx.Dir $root
        $left = [int]$Budget.LeftMs
        if (-not $sha -or $left -le 0) { return , $Bodies }
        $gitArgs = New-Object System.Collections.Generic.List[string]
        foreach ($a in @('-C', $root, '-c', 'core.quotepath=off', 'grep', '-F', '--no-color')) { $gitArgs.Add($a) }
        foreach ($c in ($Bodies | Select-Object -Unique)) { $gitArgs.Add('-e'); $gitArgs.Add([string]$c) }
        $gitArgs.Add($sha); $gitArgs.Add('--')
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        $run = Invoke-TimedGit -GitArgs $gitArgs.ToArray() -WorkDir $root -TimeoutMs $left
        $Budget.LeftMs = $left - [int]$sw.ElapsedMilliseconds
        if ($run.Code -ne 0) { return , $Bodies }
        $self = $Ctx.File.Substring($root.Length).TrimStart('\', '/') -replace '\\', '/'
        $origins = @{}
        foreach ($l in $run.Lines) {
            $s = [string]$l
            if (-not $s.StartsWith("${sha}:")) { continue }
            $rest = $s.Substring($sha.Length + 1)
            $cut = $rest.IndexOf(':')
            if ($cut -le 0) { continue }
            $rel = $rest.Substring(0, $cut)
            if ($rel -eq $self) { continue }
            $line = $rest.Substring($cut + 1).Trim()
            if (-not $origins.ContainsKey($line)) { $origins[$line] = New-Object System.Collections.Generic.HashSet[string] }
            [void]$origins[$line].Add($rel)
        }
        $now = @{}
        $kept = New-Object System.Collections.Generic.List[string]
        foreach ($c in $Bodies) {
            $moved = $false
            if ($origins.ContainsKey($c)) {
                foreach ($rel in $origins[$c]) {
                    if (-not $now.ContainsKey($rel)) {
                        $set = New-Object System.Collections.Generic.HashSet[string]
                        $full = Join-Path $root $rel
                        if (Test-Path -LiteralPath $full -PathType Leaf) { foreach ($x in [System.IO.File]::ReadAllLines($full)) { [void]$set.Add($x.Trim()) } }
                        $now[$rel] = $set
                    }
                    if (-not $now[$rel].Contains($c)) { $moved = $true; break }
                }
            }
            if (-not $moved) { $kept.Add($c) }
        }
        return , $kept
    } catch { return , $Bodies }
}

function Get-CommentPostImage([string]$File, $Data, $Added) {
    $ti = $Data.tool_input
    if ([string]$Data.tool_name -eq 'Write') {
        foreach ($a in $Added) { $a.Indexes = @($a.Line) }
        return ([string]$ti.content -split '\r?\n')
    }
    $edits = if ([string]$Data.tool_name -eq 'MultiEdit') { @($ti.edits) } else { @($ti) }
    $marked = New-Object System.Collections.Generic.List[string]
    for ($p = 0; $p -lt $edits.Count; $p++) {
        $lines = [string]$edits[$p].new_string -split '\r?\n'
        for ($k = 0; $k -lt $Added.Count; $k++) {
            if ($Added[$k].Pair -eq $p) { $lines[$Added[$k].Line] = [char]1 + [string]$k + [char]2 + $lines[$Added[$k].Line] }
        }
        $marked.Add($lines -join "`n")
    }
    $text = if (Test-Path -LiteralPath $File -PathType Leaf) { [System.IO.File]::ReadAllText($File) -replace '\r\n', "`n" } else { $null }
    for ($p = 0; $p -lt $edits.Count; $p++) {
        $old = ([string]$edits[$p].old_string) -replace '\r\n', "`n"
        if ($null -eq $text -or $old -eq '' -or $text.IndexOf($old) -lt 0) { $text = $null; break }
        if ($edits[$p].replace_all) { $text = $text.Replace($old, $marked[$p]) }
        else { $i = $text.IndexOf($old); $text = $text.Substring(0, $i) + $marked[$p] + $text.Substring($i + $old.Length) }
    }
    if ($null -eq $text) { $text = ($marked -join "`n") }
    $post = @($text -split "`n")
    $hits = @{}
    for ($n = 0; $n -lt $post.Count; $n++) {
        $m = [regex]::Match($post[$n], "^\x01(\d+)\x02")
        if (-not $m.Success) { continue }
        $k = [int]$m.Groups[1].Value
        if (-not $hits.ContainsKey($k)) { $hits[$k] = New-Object System.Collections.Generic.List[int] }
        $hits[$k].Add($n)
        $post[$n] = $post[$n].Substring($m.Length)
    }
    for ($k = 0; $k -lt $Added.Count; $k++) { if ($hits.ContainsKey($k)) { $Added[$k].Indexes = $hits[$k].ToArray() } }
    return , $post
}
