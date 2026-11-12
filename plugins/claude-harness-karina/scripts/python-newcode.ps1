# python-newcode.ps1 — python 으로 소스 파일에 새 코드·주석을 쓰는 명령 판정 (dot-source 전용) — 근거는 `rules/bash-guard-rationale.md` §22

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
    if ($p -match '(?i)(^/tmp/|/AppData/Local/Temp/)') { return $true }
    $tmp = ([System.IO.Path]::GetTempPath() -replace '\\', '/').TrimEnd('/')
    return ($tmp -and $p.StartsWith($tmp + '/', [System.StringComparison]::OrdinalIgnoreCase))
}

function Test-PythonNewCodeScript([string]$Script) {
    $pass = @{ Block = $false; Target = $null; Line = $null }
    if ([string]::IsNullOrEmpty($Script) -or -not $script:PyWriteRx.IsMatch($Script)) { return $pass }
    if (-not $script:PyTargetExts['Slash'] -or -not $script:PyTargetExts['Hash']) { return $pass }

    $lits = @($script:PyLiteralRx.Matches($Script) | ForEach-Object { $_.Groups[1].Value })
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
    for ($i = 0; $i -lt $lits.Count; $i++) {
        $ls = Get-PythonLiteralLines $lits[$i]
        if ($null -eq $ls) { continue }
        foreach ($line in $ls) {
            $t = $line.Trim()
            if ($t -eq '') { continue }
            $hit = $script:PyDeclRx.IsMatch($line) -or ($slash -and $script:PySlashCommentRx.IsMatch($line)) -or ($hash -and $script:PyHashCommentRx.IsMatch($line))
            if (-not $hit) { continue }
            $seen = $false
            for ($j = 0; $j -lt $lineSets.Count; $j++) {
                if ($j -ne $i -and $lineSets[$j].Contains($t)) { $seen = $true; break }
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
