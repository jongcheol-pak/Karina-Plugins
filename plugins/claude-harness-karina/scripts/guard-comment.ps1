# guard-comment.ps1 — guard-harness 가 dot-source 하는 새 주석 첫 시도 판정 — 근거는 `rules/comment-gate-rationale.md` §3

function Invoke-GuardComment($Data, [string]$File) {
    $pass = @{ Block = $false; Lines = @() }
    if (-not (Get-Command Get-AddedCommentBodies -ErrorAction SilentlyContinue)) {
        try { . (Join-Path $PSScriptRoot 'comment-lines.ps1') } catch {}
    }
    if (-not (Get-Command Get-AddedCommentBodies -ErrorAction SilentlyContinue)) {
        return @{ Block = $false; Lines = @('guard-comment: comment-lines.ps1 로드 실패 — 새 주석 검사 미수행(fail-open). 플러그인 재설치를 권장합니다.') }
    }
    if (-not (Test-CommentTarget $File)) { return $pass }

    $fullPath = try { [System.IO.Path]::GetFullPath($File) -replace '/', '\' } catch { $File -replace '/', '\' }
    $tempRoot = [System.IO.Path]::GetTempPath().TrimEnd('\', '/') -replace '/', '\'
    if ($tempRoot -and $fullPath.StartsWith($tempRoot + '\', [System.StringComparison]::OrdinalIgnoreCase)) { return $pass }

    $pairs = @()
    switch ([string]$Data.tool_name) {
        'MultiEdit' { $pairs = @($Data.tool_input.edits | ForEach-Object { , @([string]$_.old_string, [string]$_.new_string) }) }
        'Edit' { $pairs = @(, @([string]$Data.tool_input.old_string, [string]$Data.tool_input.new_string)) }
        'Write' {
            $old = if (Test-Path -LiteralPath $File -PathType Leaf) { [System.IO.File]::ReadAllText($File) } else { '' }
            $pairs = @(, @($old, [string]$Data.tool_input.content))
        }
        default { return $pass }
    }
    $added = Get-AddedCommentBodies $File $pairs
    if ($added.Count -eq 0) { return $pass }

    $session = Get-CommentGateSession $Data
    $key = Get-CommentGateKey $session ('edit|' + $fullPath.ToLowerInvariant()) $added
    if (Test-CommentGateRetry $key) {
        Add-CommentGateApproved $session $added
        Write-GuardCommentEvent 'allow' $File
        return $pass
    }
    if (-not (Set-CommentGateRetry $key)) { return $pass }

    Write-GuardCommentEvent 'block' $File
    $lines = @("$File : 주석 $($added.Count)줄") + @(Format-CommentGatePreview $added) + @(
        $script:CommentGateRule,
        '  - 그중 하나면 같은 편집을 그대로 다시 내세요 — 통과합니다.',
        '  - 아니면 주석 없이 다시 쓰고, 남길 이유는 커밋 본문에 적으세요.')
    return @{ Block = $true; Lines = $lines }
}

function Write-GuardCommentEvent([string]$Decision, [string]$File) {
    try {
        if (Get-Command Write-HookEvent -ErrorAction SilentlyContinue) { Write-HookEvent 'guard-comment' $Decision 'new-comment' $File }
    } catch {}
}
