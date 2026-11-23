# inject-reply-language.ps1 — 스킬 발동 때 「사용자 보고는 한글」 한 줄을 주입하고, 셸·쓰기 도구 직전 assistant 텍스트가 영문 위주면 그 텍스트에 한 번 교정 줄을 싣고(같은 세션 세 번째부터는 그 호출을 한 번 막고), turn 끝 응답이 영문 위주면 한 번 다시 쓰게 한다 — 근거는 `rules/reply-language-rationale.md` §1

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
try { [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

$Line = '[karina 응답 언어] 사용자에게 하는 답·진행 안내·질문·완료 보고는 한글로 쓴다 — 스킬 본문·도구 출력·서브에이전트 보고가 영문이어도 같다. 코드 식별자·명령·원문 인용은 원래 표기를 유지한다.'
$StopLine = '[karina 응답 언어] 방금 응답의 산문이 한글이 아니라 영문 위주입니다. 같은 내용을 한글로 다시 써서 답하십시오 — 코드 식별자·명령·원문 인용은 원래 표기를 유지합니다.'

# 판정 불가는 전부 침묵이다 — 근거는 `rules/reply-language-rationale.md` §3
try { $data = $(if ($null -ne $global:KarinaHookStdin) { $global:KarinaHookStdin } else { [Console]::In.ReadToEnd() }) | ConvertFrom-Json -ErrorAction Stop } catch { exit 0 }
if (-not $data) { exit 0 }

$PreLine = '[karina 응답 언어] 직전 진행 메모가 영문 위주였습니다 — 이어지는 안내·메모·보고는 한글로 쓴다. 코드 식별자·명령·원문 인용은 원래 표기를 유지한다.'
$BlockAfter = 2
$BlockLine = "[차단] 영문 진행 메모 세 번째 — 이 도구 호출을 한 번 막았습니다" + ' [karina 응답 언어] 이 세션에서 영문 메모 교정이 이미 두 번 나갔습니다. 방금 메모를 한글로 다시 쓴 뒤 같은 도구 호출을 다시 내십시오 — 코드 식별자·명령·원문 인용은 원래 표기를 유지합니다.'

function Test-LatinProse([string]$Text) {
    $prose = $Text -replace '(?ms)^ {0,3}(```|~~~).*?(^ {0,3}\1[^\n]*$|\z)', ' '
    $prose = $prose -replace '`[^`\r\n]*`', ' ' -replace 'https?://\S+', ' '
    $latin = [regex]::Matches($prose, '[A-Za-z]{2,}').Count
    $hangul = [regex]::Matches($prose, '[가-힣ㄱ-ㆎ]').Count
    return ($latin -ge 5 -and $hangul -lt $latin)
}

# 전사 꼬리의 마지막 assistant 텍스트 — 근거는 `rules/reply-language-rationale.md` §2
function Get-LastAssistantText([string]$Path) {
    $fs = [System.IO.File]::Open($Path, 'Open', 'Read', 'ReadWrite')
    try {
        $size = $fs.Length
        $len = [int][Math]::Min(262144, $size)
        $null = $fs.Seek(-$len, 'End')
        $buf = New-Object byte[] $len
        $got = $fs.Read($buf, 0, $len)
    } finally { $fs.Dispose() }
    $rows = [System.Text.Encoding]::UTF8.GetString($buf, 0, $got) -split "`n"
    $first = if ($len -lt $size) { 1 } else { 0 }
    for ($i = $rows.Count - 1; $i -ge $first; $i--) {
        $row = $rows[$i]
        if ($row -notmatch '"type":\s*"assistant"' -or $row -notmatch '"type":\s*"text"') { continue }
        try { $o = $row | ConvertFrom-Json -ErrorAction Stop } catch { continue }
        if ([string]$o.type -ne 'assistant') { continue }
        $texts = @($o.message.content | Where-Object { $_.type -eq 'text' } | ForEach-Object { [string]$_.text })
        if ($texts.Count -gt 0) { return @{ Uuid = [string]$o.uuid; Text = ($texts -join "`n") } }
    }
    return $null
}

# Skill 발동 주입과 PreToolUse 셸·쓰기 판정형 주입 — 근거는 `rules/reply-language-rationale.md` §2
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
    if (-not (Test-LatinProse $msg)) { exit 0 }
    try {
        New-Item -Force -ItemType Directory -Path (Split-Path -Parent $stopMark) -ErrorAction Stop | Out-Null
        Set-Content -LiteralPath $stopMark -Value '1' -NoNewline -ErrorAction Stop
    } catch { exit 0 }
    $out = @{ hookSpecificOutput = @{ hookEventName = 'Stop'; additionalContext = $StopLine } }
    Write-Output ($out | ConvertTo-Json -Compress -Depth 4)
    exit 0
}
if ($hookEvent -ne 'PreToolUse') { exit 0 }
if ([string]$data.tool_name -eq 'Skill') {
    $out = @{ hookSpecificOutput = @{ hookEventName = $hookEvent; additionalContext = $Line } }
    Write-Output ($out | ConvertTo-Json -Compress -Depth 4)
    exit 0
}
$sid = [string]$data.session_id
$tx = [string]$data.transcript_path
if (-not [string]::IsNullOrEmpty([string]$data.agent_id) -or [string]::IsNullOrWhiteSpace($sid) -or [string]::IsNullOrWhiteSpace($tx)) { exit 0 }
try { $last = Get-LastAssistantText $tx } catch { exit 0 }
if (-not $last -or -not $last.Uuid -or -not (Test-LatinProse $last.Text)) { exit 0 }
$base = if ([string]::IsNullOrEmpty($env:USERPROFILE)) { $HOME } else { $env:USERPROFILE }
$statePath = Join-Path (Join-Path $base '.claude/.state/reply-language') (($sid -replace '[^A-Za-z0-9._-]', '_') + '.txt')
$seen = $null
try { $seen = (Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop).Trim() } catch {}
if ($seen -eq $last.Uuid) { exit 0 }
try {
    New-Item -Force -ItemType Directory -Path (Split-Path -Parent $statePath) -ErrorAction Stop | Out-Null
    Set-Content -LiteralPath $statePath -Value $last.Uuid -NoNewline -ErrorAction Stop
} catch { exit 0 }

# 같은 세션 세 번째 영문 메모부터 다음 셸·쓰기 호출을 한 번 막는다 — 근거는 `rules/reply-language-rationale.md` §5
$countPath = [System.IO.Path]::ChangeExtension($statePath, '.count')
$n = 0
try { $n = [int](Get-Content -LiteralPath $countPath -Raw -ErrorAction Stop).Trim() } catch { $n = 0 }
$counted = $true
try { Set-Content -LiteralPath $countPath -Value ($n + 1) -NoNewline -ErrorAction Stop } catch { $counted = $false }
if ($counted -and $n -ge $BlockAfter) {
    [Console]::Error.WriteLine($BlockLine)
    exit 2
}

$out = @{ hookSpecificOutput = @{ hookEventName = $hookEvent; additionalContext = $PreLine } }
Write-Output ($out | ConvertTo-Json -Compress -Depth 4)
exit 0
