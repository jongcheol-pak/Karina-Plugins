# scenarios/hook-event-log.ps1 — hook 이벤트 로깅 시나리오 (§11 적재·격리·시크릿 fail-closed + §12) (dot-source 전용, 단독 실행 금지)
# 호출자(run-hook-evals.ps1)의 공용 헬퍼(Assert-Case·Invoke-Hook·New-WriteJson·New-CommitJson)와 공유 변수($work·$iso·$gitOk·$pw·$vdCache)를 그대로 쓴다.
# 파일명은 검증 대상 hook 기준이고, Invoke-Hook에 넘기는 문자열은 scripts/ 아래 hook 파일명이다.
# ==== 아래는 본체에서 원문 그대로 옮긴 구간 (순수 이동 — 재조립 등가 검사의 경계) ====
# =====================================================================
# 11) hook 이벤트 로깅 (hook-event-log.ps1 — 적재·격리·시크릿 fail-closed)
# =====================================================================
# 로그는 격리 홈($iso)의 .claude/.state/hook-events/{YYYY-MM}.jsonl에 쓰인다.
# 게이트 태그 4개: 이벤트 로깅 검증이 block-destructive(차단 적재)·guard-bash(warn 적재)·
# guard-harness(헬퍼 개조 차단)를 실행 수단으로 쓴다 — 그 hook들의 필터에서도 커버 유지.
if (Test-HookSelected @('hook-event-log', 'block-destructive', 'guard-bash', 'guard-harness')) {

# (a) 쓰기 불가 격리 — 로그 경로가 막혀도 차단 동작은 정상 (별도 격리 홈에서 hook-events 자리를 파일로 선점).
#     ※ (b)보다 먼저: $iso에는 앞 섹션들의 경고 로깅으로 이미 디렉터리가 생겨 있을 수 있어 새 홈을 쓴다.
$iso2 = Join-Path $EvalRunTemp ("karina-hook-evals-lockedlog-" + $suffix)
New-Item -ItemType Directory -Path (Join-Path $iso2 '.claude/.state') -Force | Out-Null
'lock' | Set-Content (Join-Path $iso2 '.claude/.state/hook-events')   # 디렉터리 자리에 파일 — 로깅만 실패 유도
$env:USERPROFILE = $iso2
$r = Invoke-Hook 'block-destructive.ps1' (@{ tool_name = 'Bash'; tool_input = @{ command = 'rm -rf /' } } | ConvertTo-Json -Compress)
Assert-Case -Name "event-log: 로그 경로 쓰기 불가여도 차단 정상(exit 2)" -R $r -ExpectExit 2 -ExpectContains 'BLOCKED'
$env:USERPROFILE = $iso
Remove-Item -Recurse -Force $iso2 -ErrorAction SilentlyContinue

# (b) 차단 이벤트 적재 실증 — block-destructive 차단 1건 후 로그 라인 존재.
$r = Invoke-Hook 'block-destructive.ps1' (@{ tool_name = 'Bash'; tool_input = @{ command = 'rm -rf /' } } | ConvertTo-Json -Compress)
$evDir = Join-Path $iso '.claude/.state/hook-events'
$evText = ''
try { $evText = (Get-ChildItem -LiteralPath $evDir -Filter '*.jsonl' -ErrorAction Stop | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n" } catch {}
if (($r.code -eq 2) -and ($evText -match '"hook":"block-destructive"') -and ($evText -match '"decision":"block"')) {
    $script:results.Add(@{ ok = $true; line = "[PASS] event-log: 차단 이벤트 jsonl 적재" })
} else {
    $script:results.Add(@{ ok = $false; line = "[FAIL] event-log: 차단 이벤트 적재 누락 (exit=$($r.code), 로그검색 실패)" })
}

# (c) 시크릿 fail-closed — warn 명령에 시크릿 값 포함 시 로그에 평문 부재 (cmd 필드 생략).
$fakeKey = 'ZXCV9876QWER5432'   # 가짜 값 (러너 자체 오탐 방지용 분리 기재 불필요 — 패턴 좌변 없음)
$secCmd = 'git push origin main && export api_key="' + $fakeKey + '"'
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'Bash'; tool_input = @{ command = $secCmd } } | ConvertTo-Json -Compress)
$evText2 = ''
try { $evText2 = (Get-ChildItem -LiteralPath $evDir -Filter '*.jsonl' -ErrorAction Stop | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n" } catch {}
if (($r.code -eq 0) -and ($evText2 -match '"hook":"warn-external-ops"') -and ($evText2 -notmatch [regex]::Escape($fakeKey))) {
    $script:results.Add(@{ ok = $true; line = "[PASS] event-log: 시크릿 포함 명령 fail-closed (평문 미기록)" })
} else {
    $script:results.Add(@{ ok = $false; line = "[FAIL] event-log: 시크릿 fail-closed 위반 또는 warn 미적재 (exit=$($r.code))" })
}

# (d) guard-harness: 설치본 hook-event-log(헬퍼) 개조 차단 (이름 집합 합류 실증)
$elTarget = (Join-Path $vdCache 'hook-event-log.ps1') -replace '\\', '/'
$r = Invoke-Hook 'guard-harness.ps1' (@{ tool_name = 'Write'; tool_input = @{ file_path = $elTarget; content = 'x' } } | ConvertTo-Json -Compress)
Assert-Case -Name "guard-harness: 설치본 hook-event-log 개조 차단" -R $r -ExpectExit 2 -ExpectContains 'BLOCKED'
function Get-EvLines {
    try { return @(Get-ChildItem -LiteralPath $evDir -Filter '*.jsonl' -ErrorAction Stop | ForEach-Object { Get-Content -LiteralPath $_.FullName }) } catch { return @() }
}
function Test-SlowDelta {
    param([string]$Name, [string]$Hook, [string]$Command, [int]$ExpectExit, [string]$SlowMs, [bool]$ExpectSlow)
    $before = (Get-EvLines).Count
    $prevSlow = $env:KARINA_HOOK_SLOW_MS
    $env:KARINA_HOOK_SLOW_MS = $SlowMs
    try { $r = Invoke-Hook $Hook (@{ tool_name = 'Bash'; tool_input = @{ command = $Command } } | ConvertTo-Json -Compress) }
    finally { $env:KARINA_HOOK_SLOW_MS = $prevSlow }
    $hookName = $Hook -replace '\.ps1$', ''
    $new = @(Get-EvLines | Select-Object -Skip $before)
    $slow = @($new | Where-Object { $_ -match ('"hook":"' + [regex]::Escape($hookName) + '"') -and $_ -match '"decision":"slow"' -and $_ -match '"rule":"elapsed_ms=\d+"' })
    $ok = ($r.code -eq $ExpectExit) -and ((($slow.Count -eq 1) -and $ExpectSlow) -or (($slow.Count -eq 0) -and -not $ExpectSlow))
    $tag = if ($ok) { 'PASS' } else { 'FAIL' }
    $script:results.Add(@{ ok = $ok; line = "[$tag] event-log slow: $Name (exit=$($r.code), 새 slow 줄 $($slow.Count))" })
}
Test-SlowDelta -Name 'guard-bash 통과 경로가 기준 이상이면 slow 1줄' -Hook 'guard-bash.ps1' -Command 'ls -la' -ExpectExit 0 -SlowMs '0' -ExpectSlow $true
Test-SlowDelta -Name 'guard-bash 차단 경로도 slow 1줄 · 차단 유지' -Hook 'guard-bash.ps1' -Command 'cp notes.md plan.md' -ExpectExit 2 -SlowMs '0' -ExpectSlow $true
Test-SlowDelta -Name 'block-destructive 통과 경로가 기준 이상이면 slow 1줄' -Hook 'block-destructive.ps1' -Command 'ls -la' -ExpectExit 0 -SlowMs '0' -ExpectSlow $true
Test-SlowDelta -Name 'block-destructive 차단 경로도 slow 1줄 · 차단 유지' -Hook 'block-destructive.ps1' -Command 'rm -rf /' -ExpectExit 2 -SlowMs '0' -ExpectSlow $true
Test-SlowDelta -Name '기준 밑이면 slow 줄 없음 (음성 짝)' -Hook 'guard-bash.ps1' -Command 'ls -la' -ExpectExit 0 -SlowMs '86400000' -ExpectSlow $false
}

