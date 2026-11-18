# inject-reply-language.ps1 — 스킬 발동 때와 셸·쓰기 도구 20회마다 「사용자 보고는 한글」 한 줄을 컨텍스트에 주입하고, turn 끝 응답이 영문 위주면 한 번 다시 쓰게 한다 — 근거는 `rules/reply-language-rationale.md` §1

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
try { [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

$Line = '[karina 응답 언어] 사용자에게 하는 답·진행 안내·질문·완료 보고는 한글로 쓴다 — 스킬 본문·도구 출력·서브에이전트 보고가 영문이어도 같다. 코드 식별자·명령·원문 인용은 원래 표기를 유지한다.'
$StopLine = '[karina 응답 언어] 방금 응답의 산문이 한글이 아니라 영문 위주입니다. 같은 내용을 한글로 다시 써서 답하십시오 — 코드 식별자·명령·원문 인용은 원래 표기를 유지합니다.'

# 판정 불가는 전부 침묵이다 — 근거는 `rules/reply-language-rationale.md` §3
try { $data = $(if ($null -ne $global:KarinaHookStdin) { $global:KarinaHookStdin } else { [Console]::In.ReadToEnd() }) | ConvertFrom-Json -ErrorAction Stop } catch { exit 0 }
if (-not $data) { exit 0 }

# Skill 발동 주입과 PreToolUse 셸·쓰기 20회 주기 주입 — 근거는 `rules/reply-language-rationale.md` §2
$Every = 20
$hookEvent = [string]$data.hook_event_name
# Stop 영문 산문 응답의 한글 재작성 1회 — 근거는 `rules/reply-language-rationale.md` §4
if ($hookEvent -eq 'Stop') {
    $sid = [string]$data.session_id
    $msg = [string]$data.last_assistant_message
    if ([string]::IsNullOrWhiteSpace($sid) -or [string]::IsNullOrWhiteSpace($msg)) { exit 0 }
    $base = if ([string]::IsNullOrEmpty($env:USERPROFILE)) { $HOME } else { $env:USERPROFILE }
    $stopMark = Join-Path (Join-Path $base '.claude/.state/reply-language') (($sid -replace '[^A-Za-z0-9._-]', '_') + '.stop')
    if (Test-Path -LiteralPath $stopMark) {
        Remove-Item -LiteralPath $stopMark -Force -ErrorAction SilentlyContinue
        if ($data.stop_hook_active -eq $true) { exit 0 }
    }
    $prose = $msg -replace '(?ms)^ {0,3}(```|~~~).*?(^ {0,3}\1[^\n]*$|\z)', ' '
    $prose = $prose -replace '`[^`\r\n]*`', ' ' -replace 'https?://\S+', ' '
    $latin = [regex]::Matches($prose, '[A-Za-z]{2,}').Count
    $hangul = [regex]::Matches($prose, '[가-힣ㄱ-ㆎ]').Count
    if ($latin -lt 5 -or $hangul -ge $latin) { exit 0 }
    try {
        New-Item -Force -ItemType Directory -Path (Split-Path -Parent $stopMark) -ErrorAction Stop | Out-Null
        Set-Content -LiteralPath $stopMark -Value '1' -NoNewline -ErrorAction Stop
    } catch { exit 0 }
    $out = @{ hookSpecificOutput = @{ hookEventName = 'Stop'; additionalContext = $StopLine } }
    Write-Output ($out | ConvertTo-Json -Compress -Depth 4)
    exit 0
}
if ($hookEvent -ne 'PreToolUse') { exit 0 }
$isSkill = [string]$data.tool_name -eq 'Skill'
$sid = [string]$data.session_id
$isSub = -not [string]::IsNullOrEmpty([string]$data.agent_id)
if (-not $isSkill -and ($isSub -or [string]::IsNullOrWhiteSpace($sid))) { exit 0 }

$count = 0
if (-not [string]::IsNullOrWhiteSpace($sid) -and -not $isSub) {
    $base = if ([string]::IsNullOrEmpty($env:USERPROFILE)) { $HOME } else { $env:USERPROFILE }
    $stateDir = Join-Path $base '.claude/.state/reply-language'
    $statePath = Join-Path $stateDir (($sid -replace '[^A-Za-z0-9._-]', '_') + '.txt')
    if (-not $isSkill) {
        $raw = $null
        try { $raw = (Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop).Trim() } catch {}
        if (-not [int]::TryParse([string]$raw, [ref]$count)) { $count = 0 }
        $count++
        if ($count -ge $Every) { $count = 0 }
    }
    try {
        New-Item -Force -ItemType Directory -Path $stateDir -ErrorAction Stop | Out-Null
        Set-Content -LiteralPath $statePath -Value $count -NoNewline -ErrorAction Stop
    } catch {}
    if (-not $isSkill -and $count -ne 0) { exit 0 }
}

$out = @{ hookSpecificOutput = @{ hookEventName = $hookEvent; additionalContext = $Line } }
Write-Output ($out | ConvertTo-Json -Compress -Depth 4)
exit 0
