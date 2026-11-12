# inject-reply-language.ps1 — 스킬 발동 때와 셸·쓰기 도구 20회마다 「사용자 보고는 한글」 한 줄을 컨텍스트에 주입한다 — 근거는 `rules/reply-language-rationale.md` §1

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
try { [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

$Line = '[karina 응답 언어] 사용자에게 하는 답·진행 안내·질문·완료 보고는 한글로 쓴다 — 스킬 본문·도구 출력·서브에이전트 보고가 영문이어도 같다. 코드 식별자·명령·원문 인용은 원래 표기를 유지한다.'

# 판정 불가는 전부 침묵이다 — 근거는 `rules/reply-language-rationale.md` §3
try { $data = $(if ($null -ne $global:KarinaHookStdin) { $global:KarinaHookStdin } else { [Console]::In.ReadToEnd() }) | ConvertFrom-Json -ErrorAction Stop } catch { exit 0 }
if (-not $data) { exit 0 }

# Skill 발동 주입과 PostToolUse 20회 주기 주입 — 근거는 `rules/reply-language-rationale.md` §2
$Every = 20
$hookEvent = [string]$data.hook_event_name
$isSkill = $hookEvent -eq 'PreToolUse' -and [string]$data.tool_name -eq 'Skill'
if (-not $isSkill -and $hookEvent -ne 'PostToolUse') { exit 0 }
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
