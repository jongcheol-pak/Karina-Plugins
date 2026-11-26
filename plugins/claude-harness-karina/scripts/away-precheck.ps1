# away-precheck.ps1 — 사용자 메시지가 부재를 예고하고 계획·체인·구현 상태가 있으면 사전 확인 절차를 Read 하라고 주입한다 — 근거는 `rules/away-precheck-rationale.md` §1

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
try { [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

# 부재 문구 — 근거는 `rules/away-precheck-rationale.md` §2
$AwayRx = '(?i)(잔다|잘게|자러\s*(가|간|갈)|잠\s*자|자야겠|퇴근|자리\s*(를\s*)?비|외출|내일\s*이어|going\s+to\s+(bed|sleep)|heading\s+(home|out)|signing\s+off|\bafk\b|good\s*night)'

# 판정 불가는 전부 침묵이다 — 근거는 `rules/away-precheck-rationale.md` §3
try { $data = $(if ($null -ne $global:KarinaHookStdin) { $global:KarinaHookStdin } else { [Console]::In.ReadToEnd() }) | ConvertFrom-Json -ErrorAction Stop } catch { exit 0 }
if (-not $data) { exit 0 }
$sid = [string]$data.session_id
if ([string]::IsNullOrWhiteSpace($sid)) { exit 0 }
if ([string]$data.prompt -notmatch $AwayRx) { exit 0 }

$base = if ([string]::IsNullOrEmpty($env:USERPROFILE)) { $HOME } else { $env:USERPROFILE }
$sidSafe = $sid -replace '[^A-Za-z0-9._-]', '_'
$active = Test-Path -LiteralPath (Join-Path $base ('.claude/.state/loop-continue/' + $sidSafe + '.active'))
if (-not $active) {
    try {
        $ws = Get-Content -LiteralPath (Join-Path $base ('.claude/.state/work-start/' + $sidSafe + '.json')) -Raw -Encoding UTF8 -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $active = -not [string]::IsNullOrEmpty([string]$ws.plan) -or -not [string]::IsNullOrEmpty([string]$ws.'chain-plan')
    } catch {}
}
if (-not $active) { exit 0 }

$doc = [System.IO.Path]::GetFullPath((Join-Path $PSScriptRoot '../skills/AWAY-PRECHECK.md'))
$line = "[karina 부재 예고] 사용자가 자리를 비운다고 했다 — $doc 「부재 사전 확인」 을 Read 해 따른다(계획 인터뷰 중이거나 계획·체인·구현 밖이면 그 절 첫 단계대로 아무것도 하지 않는다)."
$out = @{ hookSpecificOutput = @{ hookEventName = 'UserPromptSubmit'; additionalContext = $line } }
[Console]::Out.Write(($out | ConvertTo-Json -Compress -Depth 5))
exit 0
