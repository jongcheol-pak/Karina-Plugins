# python-newcode.ps1 — python·셸 명령(sed·printf·echo·cat·tee)으로 소스 파일에 새 코드·주석을 쓰는 명령 판정 (dot-source 전용) — 근거는 `rules/bash-guard-rationale.md` §22

$script:PyTargetExts = @{}
try {
    $cl = [System.IO.File]::ReadAllText((Join-Path $PSScriptRoot 'comment-lines.ps1'))
    foreach ($fam in 'Slash', 'Hash') {
        $m = [regex]::Match($cl, '(?m)^\$script:Comment' + $fam + 'Exts = @\(([^)]*)\)')
        if ($m.Success) { $script:PyTargetExts[$fam] = @([regex]::Matches($m.Groups[1].Value, "'([^']+)'") | ForEach-Object { $_.Groups[1].Value }) }
    }
} catch {}

$script:PyInvokeRx = '(?i)(?:^|[\s;&|(''"/\\])(?:python3?|py)(?:\.exe)?(?=\s|$|["''])'
$script:PyWriteRx = [regex]::new('write_text|write_bytes|\.write\(|\bopen\s*\([^)]*?[''"](?:w|a|r\+|wb|ab|w\+|a\+)[''"]')
$script:PyLiteralRx = [regex]::new('(?s)(?<![A-Za-z0-9_])[rRbBfFuU]{0,2}(''''''.*?''''''|""".*?"""|''(?:[^''\\\r\n]|\\.)*''|"(?:[^"\\\r\n]|\\.)*")')
$script:PyDeclRx = [regex]::new('^\s*(?:pub\b|public\b|private\b|internal\b|protected\b|export\b|(?:async\s+|unsafe\s+)?(?:fn|struct|enum|impl|trait|mod|const|static|class|interface|function|def|func)\b)')
$script:PyDeclNameRx = [regex]::new('(?:\b(?:fn|struct|enum|trait|mod|const|static|class|interface|function|def|func|type)\s+|^\s*(?:pub(?:\([^)]*\))?|public|private|internal|protected)\s+(?=[A-Za-z_]\w*\s*:))(?<n>[A-Za-z_]\w*)')
$script:PyLocalDeclRx = [regex]::new('^\s*(?:(?:var|let(?:\s+mut)?)\s+(?<n>(?!_\b)[A-Za-z_]\w*)\s*[:=](?!:)|(?!(?:let|var|return|else|await|yield|throw|case|in|is|not|and|or|if|elif|while|for|new|print)\b)[A-Za-z_][\w.]*(?:<[\w<>,\s.?\[\]]*>)?(?:\[\])?\??\s+(?<n>[A-Za-z_]\w*)\s*=(?!=))')
$script:PyFieldRx = [regex]::new('^\s*(?!(?:default|case|else)\b)(?<n>[a-z_]\w*)\s*:(?!:)\s*\S')
$script:ShellTokenRx = [regex]::new('''[^'']*''|"(?:[^"\\]|\\.)*"|[^\s''"]+')
$script:SedAddrRx = '^(?:\d+|\$|/(?:\\.|[^/])*/)?(?:,(?:\d+|\$|/(?:\\.|[^/])*/))?\s*'
$script:PyAttrRx =[regex]::new('^\s*(?:\[[A-Z]\w*(?:\(.*\))?(?:\s*,\s*[A-Z]\w*(?:\(.*\))?)*\]|#!?\[[A-Za-z_][\w:]*(?:\(.*\))?\])\s*$')
$script:PyPatternArgRx =[regex]::new('(?:\bre\.(?:sub|subn|compile|search|match|fullmatch|findall|finditer|split)|\.replace)\s*\(\s*$')
$script:PySlashCommentRx =[regex]::new('^\s*(?://|/\*)')
$script:PyHashCommentRx = [regex]::new('^\s*#(?![\[!])')

function Get-PythonInvocations([string]$Cmd, [string]$HeredocRx) {
    $found = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrEmpty($Cmd) -or $Cmd -notmatch $script:PyInvokeRx) { return , $found }
    $rest = $Cmd
    if ($HeredocRx) {
        foreach ($m in [regex]::Matches($Cmd, $HeredocRx)) {
            $line = $m.Groups['line'].Value
            if ($line -match $script:PyInvokeRx -or $line -match '>\s*\S+\.py\b') {
                $found.Add(@{ Kind = 'heredoc'; Text = $m.Groups['body'].Value })
            }
        }
        $rest = [regex]::Replace($Cmd, $HeredocRx, { param($m) $m.Groups['line'].Value })
    }
    foreach ($inv in [regex]::Matches($rest, $script:PyInvokeRx)) {
        $after = $rest.Substring($inv.Index + $inv.Length)
        $c = [regex]::Match($after, '^(?:\s+-[A-Za-z]+)*?\s+-c\s+(''[^'']*''|"(?:[^"\\]|\\.)*")')
        if ($c.Success) {
            $found.Add(@{ Kind = 'c'; Text = $c.Groups[1].Value.Substring(1, $c.Groups[1].Value.Length - 2) })
            continue
        }
        $seg = ($after -split '(?:&&|\|\||[;\r\n|])')[0]
        $f = [regex]::Match($seg, '(?:^|\s)("[^"]+\.py"|''[^'']+\.py''|[^\s"'']+\.py)(?=\s|$)')
        if ($f.Success) { $found.Add(@{ Kind = 'file'; Path = $f.Groups[1].Value.Trim('"', "'") }) }
    }
    return , $found
}

function Get-PythonLiteralLines([string]$Literal) {
    $triple = $Literal.StartsWith("'''") -or $Literal.StartsWith('"""')
    $body = if ($triple) { $Literal.Substring(3, $Literal.Length - 6) } else { $Literal.Substring(1, $Literal.Length - 2) }
    if (-not $triple -and -not $body.Contains('\n')) { return $null }
    return @(($body -replace '\\n', "`n") -split '\r?\n')
}

function Test-PythonTempPath([string]$Path) {
    $p = $Path -replace '\\', '/'
    if ($p -match '(^|/)\.\.(/|$)') { return $false }
    if ($p -match '(?i)(^/tmp/|/AppData/Local/Temp/)') { return $true }
    $tmp = ([System.IO.Path]::GetTempPath() -replace '\\', '/').TrimEnd('/')
    return ($tmp -and $p.StartsWith($tmp + '/', [System.StringComparison]::OrdinalIgnoreCase))
}

function Get-PythonLiteralLineSet([string]$Script) {
    $set = New-Object System.Collections.Generic.HashSet[string]
    if ([string]::IsNullOrEmpty($Script)) { return , $set }
    foreach ($m in $script:PyLiteralRx.Matches($Script)) {
        $ls = Get-PythonLiteralLines $m.Groups[1].Value
        if ($null -eq $ls) { continue }
        foreach ($x in $ls) { [void]$set.Add($x.Trim()) }
    }
    return , $set
}

function Test-NewCodeLine([string]$Line, [bool]$Slash, [bool]$Hash, [bool]$InParens = $false) {
    return ($script:PyDeclRx.IsMatch($Line) -or $script:PyLocalDeclRx.IsMatch($Line) -or $script:PyAttrRx.IsMatch($Line) -or
        ($Slash -and ((-not $InParens -and $script:PyFieldRx.IsMatch($Line)) -or $script:PySlashCommentRx.IsMatch($Line))) -or ($Hash -and $script:PyHashCommentRx.IsMatch($Line)))
}

function Get-ParenDepths([string[]]$Lines) {
    $depth = 0
    foreach ($l in $Lines) {
        $depth
        $depth += ([regex]::Matches($l, '\(').Count - [regex]::Matches($l, '\)').Count)
    }
}

function Get-NewCodeLocalName([string]$Line, [bool]$Slash) {
    $m = $script:PyLocalDeclRx.Match($Line)
    if ($m.Success) { return $m.Groups['n'].Value }
    if ($Slash) { $m = $script:PyFieldRx.Match($Line); if ($m.Success) { return $m.Groups['n'].Value } }
    return $null
}

function Test-PythonNewCodeScript([string]$Script, [string]$Baseline = $null) {
    $pass = @{ Block = $false; Target = $null; Line = $null }
    if ([string]::IsNullOrEmpty($Script) -or -not $script:PyWriteRx.IsMatch($Script)) { return $pass }
    if (-not ($Script.Contains("'''") -or $Script.Contains('"""') -or $Script.Contains('\n'))) { return $pass }
    if (-not $script:PyTargetExts['Slash'] -or -not $script:PyTargetExts['Hash']) { return $pass }

    $litMatches = @($script:PyLiteralRx.Matches($Script))
    $lits = @($litMatches | ForEach-Object { $_.Groups[1].Value })
    $targets = @()
    foreach ($l in $lits) {
        if ($l.StartsWith("'''") -or $l.StartsWith('"""')) { continue }
        $v = $l.Substring(1, $l.Length - 2)
        if ($v -match '[\r\n]' -or $v -notmatch '\.[A-Za-z0-9]+$') { continue }
        $ext = [System.IO.Path]::GetExtension($v).ToLower()
        $isTarget = ($script:PyTargetExts['Slash'] -contains $ext) -or ($script:PyTargetExts['Hash'] -contains $ext)
        if ($isTarget -and -not (Test-PythonTempPath $v)) { $targets += $v }
    }
    if ($targets.Count -eq 0) { return $pass }

    $slash = @($targets | Where-Object { $script:PyTargetExts['Slash'] -contains [System.IO.Path]::GetExtension($_).ToLower() }).Count -gt 0
    $hash = @($targets | Where-Object { $script:PyTargetExts['Hash'] -contains [System.IO.Path]::GetExtension($_).ToLower() }).Count -gt 0

    $lineSets = @()
    foreach ($l in $lits) {
        $ls = Get-PythonLiteralLines $l
        if ($null -eq $ls) { $ls = @($l.Substring(1, $l.Length - 2)) }
        $set = New-Object System.Collections.Generic.HashSet[string]
        foreach ($x in $ls) { [void]$set.Add($x.Trim()) }
        $lineSets += , $set
    }
    $known = Get-PythonLiteralLineSet $Baseline
    for ($i = 0; $i -lt $lits.Count; $i++) {
        $head = $Script.Substring([Math]::Max(0, $litMatches[$i].Index - 40), [Math]::Min(40, $litMatches[$i].Index))
        if ($script:PyPatternArgRx.IsMatch($head)) { continue }
        $var = [regex]::Match($head, '(?<![\w.])([A-Za-z_]\w*)\s*=\s*$')
        if ($var.Success -and [regex]::IsMatch($Script, '(?:\bre\.(?:sub|subn|search|match|fullmatch|findall|finditer|split)|\.replace)\s*\(\s*' + $var.Groups[1].Value + '\s*,')) { continue }
        $ls = Get-PythonLiteralLines $lits[$i]
        if ($null -eq $ls) { continue }
        $depths = @(Get-ParenDepths $ls)
        for ($li = 0; $li -lt $ls.Count; $li++) {
            $line = $ls[$li]
            $t = $line.Trim()
            if ($t -eq '' -or $known.Contains($t)) { continue }
            if (-not (Test-NewCodeLine $line $slash $hash ($depths[$li] -gt 0))) { continue }
            $seen = $false
            for ($j = 0; $j -lt $lineSets.Count; $j++) {
                if ($j -ne $i -and $lineSets[$j].Contains($t)) { $seen = $true; break }
            }
            $localName = Get-NewCodeLocalName $line $slash
            if (-not $seen -and $localName -and -not $script:PyDeclRx.IsMatch($line)) {
                for ($j = 0; $j -lt $lineSets.Count -and -not $seen; $j++) {
                    if ($j -eq $i) { continue }
                    foreach ($o in $lineSets[$j]) {
                        if ((Get-NewCodeLocalName $o $slash) -ceq $localName) { $seen = $true; break }
                    }
                }
            }
            $name = $script:PyDeclNameRx.Match($line)
            if (-not $seen -and $name.Success) {
                for ($j = 0; $j -lt $lits.Count -and -not $seen; $j++) {
                    if ($j -eq $i) { continue }
                    foreach ($o in $script:PyDeclNameRx.Matches($lits[$j])) {
                        if ($o.Groups['n'].Value -ceq $name.Groups['n'].Value) { $seen = $true; break }
                    }
                }
            }
            if (-not $seen) { return @{ Block = $true; Target = $targets[0]; Line = $t } }
        }
    }
    return $pass
}

function ConvertFrom-ShellEscapes([string]$Text) {
    return [regex]::Replace($Text, '\\(.)', { param($m) if ($m.Groups[1].Value -ceq 'n') { "`n" } else { $m.Groups[1].Value } })
}

function Get-ShellNewCodeWrites([string]$Cmd, [string]$HeredocRx) {
    $found = New-Object System.Collections.Generic.List[object]
    if ([string]::IsNullOrEmpty($Cmd)) { return , $found }
    $rest = $Cmd
    if ($HeredocRx) {
        foreach ($m in [regex]::Matches($Cmd, $HeredocRx)) {
            $line = $m.Groups['line'].Value
            if ($line -match $script:PyInvokeRx) { continue }
            $t = [regex]::Match($line, '(?:^|[\s;&|(])(?:cat\b[^>\r\n]*?>>?|tee\s+(?:-a\s+)?)\s*(?<t>"[^"]+"|''[^'']+''|[^\s;&|<>]+)')
            if ($t.Success) { $found.Add(@{ Target = $t.Groups['t'].Value.Trim('"', "'"); Lines = @($m.Groups['body'].Value -split '\r?\n'); Known = @(); CommentOnly = $false }) }
        }
        $rest = [regex]::Replace($Cmd, $HeredocRx, { param($m) $m.Groups['line'].Value })
    }
    $segs = if (Get-Command Get-TopLevelSegments -ErrorAction SilentlyContinue) { @(Get-TopLevelSegments $rest) } else { @($rest) }
    foreach ($seg in $segs) {
        $tk = @($script:ShellTokenRx.Matches([string]$seg) | ForEach-Object { $_.Value })
        $i = 0
        while ($i -lt $tk.Count -and $tk[$i] -match '^(?:sudo|env|[A-Za-z_]\w*=.*)$') { $i++ }
        if ($i -ge $tk.Count) { continue }
        $name = $tk[$i]
        $argv = @(if ($i + 1 -lt $tk.Count) { $tk[($i + 1)..($tk.Count - 1)] })
        if ($name -eq 'sed') {
            if (-not @($argv | Where-Object { $_ -match '^-[A-Za-z]*i|^--in-place' }).Count) { continue }
            $exprs = @(); $files = @(); $expectExpr = $false; $sawExpr = $false
            foreach ($tok in $argv) {
                $v = $tok.Trim('"', "'")
                if ($expectExpr) { $exprs += $v; $expectExpr = $false; $sawExpr = $true; continue }
                if ($tok -match '^-[A-Za-z]*e$|^--expression$') { $expectExpr = $true; continue }
                if ($tok.StartsWith('-')) { continue }
                if (-not $sawExpr) { $exprs += $v; $sawExpr = $true } else { $files += $v }
            }
            foreach ($f in $files) {
                foreach ($e in $exprs) {
                    $s = [regex]::Match($e, $script:SedAddrRx + 's(?<d>[^\w\s\\])(?<p>(?:\\.|(?!\k<d>).)*)\k<d>(?<r>(?:\\.|(?!\k<d>).)*)\k<d>')
                    if ($s.Success) {
                        $repl = ConvertFrom-ShellEscapes $s.Groups['r'].Value
                        $found.Add(@{ Target = $f; Lines = @($repl -split '\r?\n'); Known = @((ConvertFrom-ShellEscapes $s.Groups['p'].Value) -split '\r?\n'); CommentOnly = -not $repl.Contains("`n") })
                        continue
                    }
                    $am = [regex]::Match($e, $script:SedAddrRx + '[aic](?:\\\s*|\s+)(?<t>[\s\S]+)$')
                    if ($am.Success) { $found.Add(@{ Target = $f; Lines = @((ConvertFrom-ShellEscapes $am.Groups['t'].Value) -split '\r?\n'); Known = @(); CommentOnly = $false }) }
                }
            }
        } elseif ($name -eq 'printf' -or $name -eq 'echo') {
            $r = -1
            for ($k = 0; $k -lt $argv.Count; $k++) { if ($argv[$k] -match '^>>?') { $r = $k; break } }
            if ($r -lt 0) { continue }
            $target = if ($argv[$r] -match '^>>?([^>].*)$') { $Matches[1] } elseif ($r + 1 -lt $argv.Count) { $argv[$r + 1] } else { $null }
            if (-not $target) { continue }
            $content = @($argv[0..($r - 1)] | Where-Object { $r -gt 0 -and -not ($_ -match '^-[A-Za-z]*$|^--$') } | ForEach-Object { $_.Trim('"', "'") })
            if ($name -eq 'printf') { $content = @($content | Select-Object -First 1) }
            $text = ConvertFrom-ShellEscapes ($content -join ' ')
            $found.Add(@{ Target = $target.Trim('"', "'"); Lines = @($text -split '\r?\n'); Known = @(); CommentOnly = $false })
        }
    }
    return , $found
}

function Test-ShellNewCode($Write) {
    $target = [string]$Write.Target
    if (-not $target -or (Test-PythonTempPath $target) -or -not $script:PyTargetExts['Slash']) { return $null }
    $ext = [System.IO.Path]::GetExtension($target).ToLower()
    $slash = $script:PyTargetExts['Slash'] -contains $ext
    $hash = $script:PyTargetExts['Hash'] -contains $ext
    if (-not ($slash -or $hash)) { return $null }
    $known = New-Object System.Collections.Generic.HashSet[string]
    $knownNames = New-Object System.Collections.Generic.HashSet[string]
    foreach ($k in @($Write.Known)) {
        [void]$known.Add(([string]$k).Trim())
        $ln = Get-NewCodeLocalName $k $slash
        if ($ln) { [void]$knownNames.Add($ln) }
        foreach ($d in $script:PyDeclNameRx.Matches([string]$k)) { [void]$knownNames.Add($d.Groups['n'].Value) }
    }
    $lines = @($Write.Lines | ForEach-Object { [string]$_ })
    $depths = @(Get-ParenDepths $lines)
    for ($li = 0; $li -lt $lines.Count; $li++) {
        $line = $lines[$li]
        $t = $line.Trim()
        if ($t -eq '' -or $known.Contains($t)) { continue }
        $hit = if ($Write.CommentOnly) { ($slash -and $script:PySlashCommentRx.IsMatch($line)) -or ($hash -and $script:PyHashCommentRx.IsMatch($line)) } else { Test-NewCodeLine $line $slash $hash ($depths[$li] -gt 0) }
        if (-not $hit) { continue }
        $ln = Get-NewCodeLocalName $line $slash
        if ($ln -and -not $script:PyDeclRx.IsMatch($line) -and $knownNames.Contains($ln)) { continue }
        $dn = $script:PyDeclNameRx.Match($line)
        if ($dn.Success -and $knownNames.Contains($dn.Groups['n'].Value)) { continue }
        return $t
    }
    return $null
}
