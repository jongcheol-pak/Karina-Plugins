# guard-doc-owner.ps1 — guard-harness 가 dot-source 하는 doc 블록 주인 이동 차단 판정 — 근거는 `rules/doc-owner-rationale.md` §2

$script:DocOwnerExts = @('.rs', '.cs', '.ts', '.tsx', '.js', '.jsx')
$script:DocOwnerWindow = 80

function Get-DocOwnerBlocks([string]$File, [string[]]$Lines) {
    $docFlag = Get-CommentDocFlags $Lines
    $blocks = @{}
    $i = 0
    while ($i -lt $Lines.Count) {
        if (-not $docFlag[$i]) { $i++; continue }
        $start = $i
        while ($i + 1 -lt $Lines.Count -and $docFlag[$i + 1]) { $i++ }
        $first = ([string]$Lines[$start]).Trim()
        if (-not $first.StartsWith('//!')) {
            $parts = New-Object System.Collections.Generic.List[string]
            for ($j = $start; $j -le $i; $j++) { $parts.Add(([string]$Lines[$j]).Trim()) }
            $text = $parts -join "`n"
            $owner = Get-CommentDocTarget $File $Lines $i $docFlag
            if (-not $blocks.ContainsKey($text)) { $blocks[$text] = New-Object System.Collections.Generic.List[object] }
            $blocks[$text].Add(@{ Owner = $owner; First = $first })
        }
        $i++
    }
    return $blocks
}

function Invoke-GuardDocOwner($Data, [string]$File) {
    $pass = @{ Block = $false; Lines = @() }
    $tool = [string]$Data.tool_name
    if ($tool -ne 'Edit' -and $tool -ne 'MultiEdit') { return $pass }
    if ($script:DocOwnerExts -notcontains [System.IO.Path]::GetExtension($File).ToLower()) { return $pass }
    if (-not (Test-Path function:Get-CommentDocTarget)) {
        try { . (Join-Path $PSScriptRoot 'comment-lines.ps1') } catch {}
    }
    if (-not (Test-Path function:Get-CommentDocTarget)) { return $pass }
    $fullPath = try { [System.IO.Path]::GetFullPath($File) -replace '/', '\' } catch { $File -replace '/', '\' }
    $tempRoot = [System.IO.Path]::GetTempPath().TrimEnd('\', '/') -replace '/', '\'
    if ($tempRoot -and $fullPath.StartsWith($tempRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) { return $pass }
    if (-not (Test-Path -LiteralPath $File -PathType Leaf)) { return $pass }

    $edits = if ($tool -eq 'MultiEdit') { @($Data.tool_input.edits) } else { @($Data.tool_input) }
    $pre = [System.IO.File]::ReadAllText($File) -replace '\r\n', "`n"
    $text = $pre
    $oldLines = New-Object System.Collections.Generic.HashSet[string]
    foreach ($e in $edits) {
        $old = ([string]$e.old_string) -replace '\r\n', "`n"
        $new = ([string]$e.new_string) -replace '\r\n', "`n"
        if ($old -eq '' -or $text.IndexOf($old) -lt 0) { return $pass }
        foreach ($l in ($old -split "`n")) { [void]$oldLines.Add($l.Trim()) }
        if ($e.replace_all) { $text = $text.Replace($old, $new) }
        else { $at = $text.IndexOf($old); $text = $text.Substring(0, $at) + $new + $text.Substring($at + $old.Length) }
    }
    if ($pre -ceq $text) { return $pass }
    $preLines = [string[]]($pre -split "`n")
    $postLines = [string[]]($text -split "`n")
    $n = $preLines.Count; $m = $postLines.Count
    if ($edits.Count -eq 1 -and -not $edits[0].replace_all) {
        $at = $pre.IndexOf((([string]$edits[0].old_string) -replace '\r\n', "`n"))
        $p = $pre.Substring(0, $at).Split("`n").Length - 1
        $s = $n - $p - ((([string]$edits[0].old_string) -replace '\r\n', "`n").Split("`n").Length)
    } else {
        $p = 0
        while ($p -lt $n -and $p -lt $m -and $preLines[$p] -ceq $postLines[$p]) { $p++ }
        $s = 0
        while ($s -lt ($n - $p) -and $s -lt ($m - $p) -and $preLines[$n - 1 - $s] -ceq $postLines[$m - 1 - $s]) { $s++ }
    }
    $lo = [Math]::Max(0, $p - $script:DocOwnerWindow)
    $preWin = [string[]]$preLines[$lo..([Math]::Min($n - 1, $n - $s + $script:DocOwnerWindow))]
    $postWin = [string[]]$postLines[$lo..([Math]::Min($m - 1, $m - $s + $script:DocOwnerWindow))]
    $before = Get-DocOwnerBlocks $File $preWin
    $after = Get-DocOwnerBlocks $File $postWin
    foreach ($k in $before.Keys) {
        if ($before[$k].Count -ne 1 -or -not $after.ContainsKey($k) -or $after[$k].Count -ne 1) { continue }
        $x = $before[$k][0].Owner
        $y = $after[$k][0].Owner
        if (-not $x -or -not $y -or $x -eq $y -or $text.IndexOf($x, [System.StringComparison]::Ordinal) -lt 0) { continue }
        $touched = $false
        foreach ($l in ($k -split "`n")) { if ($oldLines.Contains($l)) { $touched = $true; break } }
        if ($touched) { continue }
        Write-GuardDocOwnerEvent $File
        return @{ Block = $true; Lines = @(
            "$File",
            "  - ``$x`` 의 doc 이 ``$y`` 로 넘어갑니다: $($before[$k][0].First)",
            '  - 앵커를 doc 블록의 첫 줄(///)로 잡아 그 위에 넣거나, 앞 항목 본문의 닫는 } 다음에 넣으세요.',
            '  - 같은 편집을 다시 내도 통과하지 않습니다. 이 판정이 틀렸으면 멈추고 사용자에게 보고하세요.') }
    }
    return $pass
}

function Write-GuardDocOwnerEvent([string]$File) {
    try {
        if (Get-Command Write-HookEvent -ErrorAction SilentlyContinue) { Write-HookEvent 'guard-doc-owner' 'block' 'doc-owner' $File }
    } catch {}
}
