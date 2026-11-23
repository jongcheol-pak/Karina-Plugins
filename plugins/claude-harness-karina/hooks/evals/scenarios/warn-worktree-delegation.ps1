if (Test-HookSelected @('warn-worktree-delegation')) {

$wdState = Join-Path $iso '.claude/.state/loop-continue'
New-Item -ItemType Directory $wdState -Force | Out-Null
$wdNoGroup = Join-Path $work 'wd-nogroup'; New-Item -ItemType Directory $wdNoGroup -Force | Out-Null
"# plan`n`n> 승인: 2026-11-23 · 화면 Y · 다음 회차 0`n`n### T1. 일`n`n- [ ] **T1-1** 남음" | Set-Content -LiteralPath (Join-Path $wdNoGroup 'plan.md') -Encoding UTF8
$wdGroup = Join-Path $work 'wd-group'; New-Item -ItemType Directory $wdGroup -Force | Out-Null
"# plan`n`n> 승인: 2026-11-23 · 화면 Y · 다음 회차 0`n`n## 작업 단계`n`n> 병렬 그룹: T2·T3 — 근거: 의존 없음`n`n### T2. 일`n`n- [ ] **T2-1** 남음" | Set-Content -LiteralPath (Join-Path $wdGroup 'plan.md') -Encoding UTF8

function New-WdJson([string]$sid, [string]$cwd, [hashtable]$toolInput, [string]$agentId = '') {
    $o = @{ session_id = $sid; hook_event_name = 'PreToolUse'; tool_name = 'Agent'; cwd = $cwd; tool_input = $toolInput }
    if ($agentId) { $o.agent_id = $agentId }
    return ($o | ConvertTo-Json -Compress -Depth 4)
}
function Set-WdMarker([string]$sid) { Set-Content -LiteralPath (Join-Path $wdState ($sid + '.active')) -Value @((Get-Date -Format o), '') -Encoding UTF8 }

Set-WdMarker 'wd-a'
$r = Invoke-Hook 'warn-worktree-delegation.ps1' (New-WdJson 'wd-a' $wdNoGroup @{ isolation = 'worktree'; description = 'Port T14 remote'; prompt = 'x' }) -SplitStreams
Assert-Case -Name "warn-worktree-delegation: 그룹 줄 없는 plan 의 worktree 위임은 경고" -R $r -ExpectExit 0 -ExpectContains '"additionalContext"'
Assert-Case -Name "warn-worktree-delegation: 경고가 병렬 그룹과 parallel-run.md 를 가리킨다" -R @{ code = $r.code; out = $r.out } -ExpectContains 'parallel-run.md'
Assert-Case -Name "warn-worktree-delegation: 경고가 stderr 에도 실린다" -R @{ code = $r.code; out = $r.err } -ExpectContains '병렬 그룹'

Set-WdMarker 'wd-b'
$r = Invoke-Hook 'warn-worktree-delegation.ps1' (New-WdJson 'wd-b' $wdGroup @{ isolation = 'worktree'; description = 'T2 병렬 실행'; prompt = 'x' })
Assert-Case -Name "warn-worktree-delegation: 그룹 줄이 묶은 task 의 위임은 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

Set-WdMarker 'wd-c'
$r = Invoke-Hook 'warn-worktree-delegation.ps1' (New-WdJson 'wd-c' $wdGroup @{ isolation = 'worktree'; description = 'T9 병렬 실행'; prompt = 'x' })
Assert-Case -Name "warn-worktree-delegation: 그룹 줄에 없는 task 번호의 위임은 경고" -R $r -ExpectExit 0 -ExpectContains '"additionalContext"'

Set-WdMarker 'wd-d'
$r = Invoke-Hook 'warn-worktree-delegation.ps1' (New-WdJson 'wd-d' $wdNoGroup @{ description = 'Map source'; prompt = 'x' })
Assert-Case -Name "warn-worktree-delegation: isolation 없는 Agent 호출은 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

$r = Invoke-Hook 'warn-worktree-delegation.ps1' (New-WdJson 'wd-e' $wdNoGroup @{ isolation = 'worktree'; description = 'Port T14'; prompt = 'x' })
Assert-Case -Name "warn-worktree-delegation: implement 마커가 없으면 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

Set-WdMarker 'wd-f'
$r = Invoke-Hook 'warn-worktree-delegation.ps1' (New-WdJson 'wd-f' $wdNoGroup @{ isolation = 'worktree'; description = 'Port T14'; prompt = 'x' } 'agent-1')
Assert-Case -Name "warn-worktree-delegation: 서브에이전트 안 호출은 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

$r = Invoke-Hook 'warn-worktree-delegation.ps1' 'not json'
Assert-Case -Name "warn-worktree-delegation: 깨진 stdin 은 exit 0 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

}
