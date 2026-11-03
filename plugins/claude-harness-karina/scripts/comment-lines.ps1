# comment-lines.ps1 — 새 주석 줄 판별 (dot-source 전용) — 근거는 `rules/post-write-rationale.md` §22

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

function Get-CommentGateDir {
    $homeBase = if ([string]::IsNullOrEmpty($env:USERPROFILE)) { $HOME } else { $env:USERPROFILE }
    return (Join-Path $homeBase '.claude/.state/comment-gate')
}

function Get-CommentGateSession($Data) {
    if ($Data.session_id) { return ([string]$Data.session_id) -replace '[^\w.-]', '_' }
    return 'nosid'
}

function Get-CommentGateKey([string]$Session, [string]$Scope, $Bodies) {
    $sorted = @($Bodies | Sort-Object) -join "`n"
    $md5 = [System.Security.Cryptography.MD5]::Create()
    $hash = ($md5.ComputeHash([System.Text.Encoding]::UTF8.GetBytes("$Session|$Scope|$sorted")) | ForEach-Object { $_.ToString('x2') }) -join ''
    return ($Session + '_' + $hash)
}

function Test-CommentGateRetry([string]$Key) {
    return (Test-Path -LiteralPath (Join-Path (Get-CommentGateDir) $Key) -PathType Leaf)
}

function Set-CommentGateRetry([string]$Key) {
    try {
        $dir = Get-CommentGateDir
        New-Item -ItemType Directory -Force -Path $dir -ErrorAction Stop | Out-Null
        New-Item -ItemType File -Force -Path (Join-Path $dir $Key) -ErrorAction Stop | Out-Null
        return $true
    } catch { return $false }
}

function Add-CommentGateApproved([string]$Session, $Bodies) {
    try {
        $dir = Get-CommentGateDir
        New-Item -ItemType Directory -Force -Path $dir -ErrorAction Stop | Out-Null
        Add-Content -LiteralPath (Join-Path $dir ($Session + '.approved')) -Value @($Bodies) -Encoding UTF8 -ErrorAction Stop
    } catch {}
}

function Get-CommentGateApproved([string]$Session) {
    $set = New-Object System.Collections.Generic.HashSet[string]
    $f = Join-Path (Get-CommentGateDir) ($Session + '.approved')
    if (Test-Path -LiteralPath $f -PathType Leaf) {
        foreach ($l in @(Get-Content -LiteralPath $f -Encoding UTF8)) { [void]$set.Add(([string]$l).Trim()) }
    }
    return , $set
}

function Format-CommentGatePreview($Bodies) {
    return @($Bodies | Select-Object -First 3 | ForEach-Object { '  | ' + $(if ($_.Length -gt 100) { $_.Substring(0, 100) + '…' } else { $_ }) })
}

$script:CommentGateRule = '  남길 수 있는 주석은 라이선스 고지 · 바꿀 수 없는 외부 제약 · 린트/포매터 지시문 · 공개 API 계약 doc · 이슈/RFC 링크와 프로젝트 규약이 요구하는 주석뿐입니다 (code-style.md「주석」).'

function Get-AddedCommentBodies([string]$Path, $Pairs) {
    $added = New-Object System.Collections.Generic.List[string]
    foreach ($pair in $Pairs) {
        $oldSet = New-Object System.Collections.Generic.HashSet[string]
        foreach ($o in ([string]$pair[0] -split '\r?\n')) { [void]$oldSet.Add($o.Trim()) }
        foreach ($c in (Get-CommentBodies $Path ([string]$pair[1] -split '\r?\n'))) {
            if (-not $oldSet.Contains($c)) { $added.Add($c) }
        }
    }
    return , $added
}
