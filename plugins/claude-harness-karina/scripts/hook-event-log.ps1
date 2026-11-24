# hook-event-log.ps1 — 공유 이벤트 로깅 헬퍼 — 근거는 `rules/event-log-rationale.md` §1

function Write-HookEvent {
    param(
        [string]$Hook,
        [ValidateSet('block', 'warn', 'allow', 'cleanup', 'slow')][string]$Decision,
        [string]$Rule,
        [string]$CommandText = '',
        [string]$SessionId = ''
    )
    try {
        $homeBase = if ([string]::IsNullOrEmpty($env:USERPROFILE)) { $HOME } else { $env:USERPROFILE }
        if ([string]::IsNullOrEmpty($homeBase)) { return }
        $dir = Join-Path $homeBase '.claude/.state/hook-events'
        if (-not (Test-Path -LiteralPath $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }

        # 90일 초과 월 파일 정리 (세션 시작 30일 마커 정리와 같은 패턴 — best-effort)
        try {
            $cutoff = (Get-Date).AddDays(-90)
            Get-ChildItem -LiteralPath $dir -Filter '*.jsonl' -ErrorAction SilentlyContinue |
                Where-Object { $_.LastWriteTime -lt $cutoff } |
                Remove-Item -Force -ErrorAction SilentlyContinue
        } catch {}

        $entry = [ordered]@{
            ts       = (Get-Date).ToString('yyyy-MM-ddTHH:mm:sszzz')
            hook     = $Hook
            decision = $Decision
            rule     = if ($Rule -and $Rule.Length -gt $(if ($Decision -eq 'slow') { 400 } else { 120 })) { $Rule.Substring(0, $(if ($Decision -eq 'slow') { 400 } else { 120 })) } else { $Rule }
        }
        if (-not [string]::IsNullOrWhiteSpace($SessionId)) {
            $sid = $SessionId -replace '[^\w.-]', '_'
            $entry.session_id = if ($sid.Length -gt 64) { $sid.Substring(0, 64) } else { $sid }
        }

        if (-not [string]::IsNullOrWhiteSpace($CommandText)) {
            # 시크릿 검사는 절단 전 원문 전체에 수행한다 (200자 경계 밖 시크릿도 판정에 반영 — 보수적).
            $safe = $false
            try {
                if (-not (Get-Command Get-SecretMatches -ErrorAction SilentlyContinue)) {
                    . (Join-Path $PSScriptRoot 'secret-patterns.ps1')
                }
                if (Get-Command Get-SecretMatches -ErrorAction SilentlyContinue) {
                    $hits = @(Get-SecretMatches $CommandText)
                    if ($hits.Count -eq 0) { $safe = $true }
                }
            } catch { $safe = $false }   # 판정 불가 → 기록 생략 (fail-closed)
            if ($safe) {
                $entry.cmd = if ($CommandText.Length -gt 200) { $CommandText.Substring(0, 200) } else { $CommandText }
            }
        }

        $line = $entry | ConvertTo-Json -Compress -Depth 3
        $file = Join-Path $dir ((Get-Date).ToString('yyyy-MM') + '.jsonl')
        Add-Content -LiteralPath $file -Value $line -Encoding UTF8
    } catch {}
}

# 느린 실행 기록 — 근거는 `rules/event-log-rationale.md` §2
function Write-HookSlowEvent {
    param([string]$Hook, [string]$CommandText = '', [string]$SessionId = '', [Nullable[datetime]]$EntryAt = $null, [string]$Detail = '')
    try {
        $limitMs = [long]5000
        $parsed = [long]0
        if ([long]::TryParse([string]$env:KARINA_HOOK_SLOW_MS, [ref]$parsed) -and $parsed -ge 0) { $limitMs = $parsed }
        $procStart = [System.Diagnostics.Process]::GetCurrentProcess().StartTime
        $elapsedMs = [long]([DateTime]::Now - $procStart).TotalMilliseconds
        if ($elapsedMs -lt $limitMs) { return }
        $entry = if ($global:KarinaHookT0 -is [datetime]) { $global:KarinaHookT0 } elseif ($null -ne $EntryAt) { [datetime]$EntryAt } else { [DateTime]::Now }
        $startupMs = [long][Math]::Max(0, ($entry - $procStart).TotalMilliseconds)
        $rule = "elapsed_ms=$elapsedMs startup_ms=$startupMs"
        if ($Detail) { $rule += ' ' + $Detail }
        Write-HookEvent $Hook 'slow' $rule $CommandText -SessionId $SessionId
    } catch {}
}
