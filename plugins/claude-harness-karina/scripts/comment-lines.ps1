# comment-lines.ps1 — 새 주석 줄 판별 (dot-source 전용) — 근거는 `rules/comment-gate-rationale.md` §2

$script:CommentSlashExts = @('.cs', '.ts', '.tsx', '.js', '.jsx', '.java', '.go', '.rs', '.cpp', '.c', '.h', '.hpp', '.fs', '.kt', '.swift')
$script:CommentHashExts = @('.py', '.ps1', '.sh')
$script:CommentExemptRx = '(?i)^(eslint-|prettier-ignore|@ts-|noqa|type:\s*ignore|pylint:|pyright:|mypy:|nolint|istanbul ignore|c8 ignore|biome-ignore|resharper|fmt:\s*(off|on)\b|isort:|<reference|spdx-license-identifier|copyright|@license|-\*-\s*coding)'

function Test-CommentTarget([string]$Path) {
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    return ($script:CommentSlashExts -contains $ext) -or ($script:CommentHashExts -contains $ext)
}

function Get-CommentBodies([string]$Path, [string[]]$Lines) {
    $bodies = New-Object System.Collections.Generic.List[string]
    if (-not (Test-CommentTarget $Path) -or $null -eq $Lines) { return , $bodies }
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    $isSlash = $script:CommentSlashExts -contains $ext
    $rawExempt = if ($isSlash) { '^//(go:|\s*#(end)?region\b)' } elseif ($ext -eq '.ps1') { '(?i)^#(requires|(end)?region)\b' } else { '(?!)' }
    $inBlock = $false
    foreach ($line in $Lines) {
        $t = ([string]$line).Trim()
        $body = $null
        if ($inBlock) {
            $body = $t -replace '^\*+(?!/)', ''
            if ($t -match '\*/|#>') { $inBlock = $false }
        } elseif ($isSlash -and $t.StartsWith('//')) {
            $body = $t -replace '^/{2,}!?', ''
        } elseif ($isSlash -and $t.StartsWith('/*')) {
            $body = $t -replace '^/\*+!?', ''
            $inBlock = -not ($body -match '\*/')
        } elseif ((-not $isSlash) -and $ext -eq '.ps1' -and $t.StartsWith('<#')) {
            $body = $t.Substring(2)
            $inBlock = -not ($body -match '#>')
        } elseif ((-not $isSlash) -and $t.StartsWith('#') -and -not $t.StartsWith('#!')) {
            $body = $t -replace '^#+', ''
        }
        if ($null -eq $body) { continue }
        $body = ($body -replace '(\*/|#>)\s*$', '').Trim()
        if ($body -eq '' -or $body -match $script:CommentExemptRx -or $t -match $rawExempt) { continue }
        $bodies.Add($t)
    }
    return , $bodies
}

function Format-CommentGatePreview($Bodies) {
    return @($Bodies | Select-Object -First 3 | ForEach-Object { '  | ' + $(if ($_.Length -gt 100) { $_.Substring(0, 100) + '…' } else { $_ }) })
}

$script:CommentGateRule = '  통과하는 주석은 라이선스·린트 지시문 · 이슈/RFC 링크·트래커 키·실재하는 레포 .md 경로가 든 줄 · .rs SAFETY: · 레포 감사(Test (감사))가 요구하거나 라이브러리 공개 항목 위의 doc · AGENTS.md Comment (보존) 선언 · 기존 주석의 문구 수정뿐입니다 (code-style.md「주석」).'
$script:CommentLinkRx = '(?i)https?://\S*(/issues/\d+|/pull/\d+|/-/issues/\d+|rfc-editor\.org)|\bRFC ?\d{3,4}\b|\b(issue|PR|GH)[ -]?#\d+|이슈 ?#\d+'
$script:CommentTrackerRx = '\b(?!(UTF|SHA|ISO|CP|IEC|IEEE|ECMA|ANSI|CRC|AES|RSA|TLS|HTTP|MD|BASE)[A-Z0-9]*-)[A-Z]{2,}[A-Z0-9]*-\d+\b'
$script:CommentTodoRx = '\b(TODO|FIXME|XXX)\b'
$script:CommentKeepLineRx = '^- \*\*Comment \(보존\)\*\*: `(?<rx>[^`]+)` · 경로: `(?<paths>[^`]+)`'

function Get-AddedCommentBodies([string]$Path, $Pairs) {
    $added = New-Object System.Collections.Generic.List[string]
    foreach ($pair in $Pairs) {
        $oldBodies = Get-CommentBodies $Path ([string]$pair[0] -split '\r?\n')
        $newBodies = Get-CommentBodies $Path ([string]$pair[1] -split '\r?\n')
        $oldSet = New-Object System.Collections.Generic.HashSet[string]
        foreach ($o in ([string]$pair[0] -split '\r?\n')) { [void]$oldSet.Add($o.Trim()) }
        $newSet = New-Object System.Collections.Generic.HashSet[string]
        foreach ($c in $newBodies) { [void]$newSet.Add($c) }
        $rewritten = @($oldBodies | Where-Object { -not $newSet.Contains($_) }).Count
        foreach ($c in $newBodies) {
            if ($oldSet.Contains($c)) { continue }
            if ($rewritten -gt 0) { $rewritten--; continue }
            $added.Add($c)
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
        if (-not (Get-Command Get-TaskAuditRules -ErrorAction SilentlyContinue)) {
            try { . (Join-Path $PSScriptRoot 'guard-task-audit.ps1') } catch {}
        }
        if (Get-Command Get-TaskAuditRules -ErrorAction SilentlyContinue) {
            $ctx.AuditRules = @(Get-TaskAuditRules $ctx.Agents | Where-Object { $_.Pattern })
        }
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

function Get-CommentDocTarget([string]$Path, [string[]]$Lines, [int]$Index) {
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    $docFlag = New-Object bool[] $Lines.Count
    $inDoc = $false
    for ($i = 0; $i -lt $Lines.Count; $i++) {
        $t = ([string]$Lines[$i]).Trim()
        if ($inDoc) { $docFlag[$i] = $true; if ($t -match '\*/') { $inDoc = $false }; continue }
        if ($t.StartsWith('///') -or $t.StartsWith('//!')) { $docFlag[$i] = $true }
        elseif ($t.StartsWith('/**')) { $docFlag[$i] = $true; $inDoc = -not ($t.Substring(3) -match '\*/') }
    }
    if ($Index -lt 0 -or -not $docFlag[$Index]) { return $null }
    $attrRx = switch ($ext) { '.rs' { '^#!?\[' } '.cs' { '^\[' } default { '^@' } }
    for ($j = $Index + 1; $j -lt $Lines.Count; $j++) {
        $t = ([string]$Lines[$j]).Trim()
        if ($t -eq '' -or $docFlag[$j] -or $t.StartsWith('//') -or $t -match $attrRx) { continue }
        return $t
    }
    return $null
}

function Get-BlockedCommentBodies([string]$Path, $Added, [string[]]$PostLines) {
    $blocked = New-Object System.Collections.Generic.List[string]
    if ($Added.Count -eq 0) { return , $blocked }
    $ctx = Get-CommentRepoContext $Path
    $ext = [System.IO.Path]::GetExtension($Path).ToLower()
    $trimmed = @($PostLines | ForEach-Object { ([string]$_).Trim() })
    foreach ($c in $Added) {
        if (Test-CommentLineExempt $c $Path $ctx.Dir $ctx.Root) { continue }
        $base = if ($ctx.Agents) { Split-Path -Parent $ctx.Agents } else { $ctx.Dir }
        $kept = $false
        foreach ($k in $ctx.KeepRules) {
            if (-not $k.Pattern.IsMatch($c)) { continue }
            foreach ($p in $k.Paths) { if (Test-CommentPathLike $ctx.File $base $p) { $kept = $true } }
        }
        if ($kept) { continue }
        if ($c -notmatch $script:CommentTodoRx -and @('.rs', '.cs', '.ts', '.tsx', '.js', '.jsx') -contains $ext) {
            $code = Get-CommentDocTarget $Path $PostLines ([array]::IndexOf($trimmed, $c))
            if ($code) {
                $audited = @($ctx.AuditRules | Where-Object { $_.Pattern.IsMatch($code) -and (Test-CommentPathLike $ctx.File $base $_.Pathspec) }).Count -gt 0
                if ($audited -or ($ctx.Library -and (Test-CommentPublicItem $ext $code))) { continue }
            }
        }
        $blocked.Add($c)
    }
    return , $blocked
}

function Get-CommentPostImage([string]$File, $Data) {
    $ti = $Data.tool_input
    if ([string]$Data.tool_name -eq 'Write') { return ([string]$ti.content -split '\r?\n') }
    $edits = if ([string]$Data.tool_name -eq 'MultiEdit') { @($ti.edits) } else { @($ti) }
    $text = if (Test-Path -LiteralPath $File -PathType Leaf) { [System.IO.File]::ReadAllText($File) } else { $null }
    foreach ($e in $edits) {
        $old = [string]$e.old_string; $new = [string]$e.new_string
        if ($null -eq $text -or $old -eq '' -or $text.IndexOf($old) -lt 0) { $text = $null; break }
        if ($e.replace_all) { $text = $text.Replace($old, $new) }
        else { $i = $text.IndexOf($old); $text = $text.Substring(0, $i) + $new + $text.Substring($i + $old.Length) }
    }
    if ($null -eq $text) { $text = (@($edits | ForEach-Object { [string]$_.new_string }) -join "`n") }
    return ($text -split '\r?\n')
}
