if (Test-HookSelected @('hook-dispatch')) {

$hd = Join-Path $work 'hd'; New-Item -ItemType Directory $hd -Force | Out-Null
function New-HdBashJson([string]$cmd) {
    return (@{ session_id = 'hd-bash'; hook_event_name = 'PreToolUse'; tool_name = 'Bash'; tool_input = @{ command = $cmd }; cwd = $hd } | ConvertTo-Json -Compress)
}
function New-HdSkillJson([string]$sid, [string]$skill) {
    return (@{ session_id = $sid; hook_event_name = 'PreToolUse'; tool_name = 'Skill'; tool_input = @{ skill = $skill }; cwd = $hd } | ConvertTo-Json -Compress)
}
function Get-HdJsonSummary([hashtable]$R) {
    try { $o = $R.out | ConvertFrom-Json -ErrorAction Stop } catch { return @{ code = $R.code; out = 'json=False' } }
    $ctx = [string]$o.hookSpecificOutput.additionalContext
    return @{ code = $R.code; out = "json=True event=$($o.hookSpecificOutput.hookEventName) start=$($ctx.Contains('[karina 작업 시작]')) lang=$($ctx.Contains('[karina 응답 언어]'))" }
}
$hdBashPair = @('-Blocking', 'block-destructive.ps1', 'guard-bash.ps1')

$r = Invoke-Hook 'hook-dispatch.ps1' (New-HdBashJson 'rm -rf /') -Arguments $hdBashPair
Assert-Case -Name "hook-dispatch: 차단 묶음에서 block-destructive 가 막으면 exit 2" -R $r -ExpectExit 2 -ExpectContains 'BLOCKED:'
$r = Invoke-Hook 'hook-dispatch.ps1' (New-HdBashJson 'git status') -Arguments $hdBashPair
Assert-Case -Name "hook-dispatch: 차단 묶음에 무해 명령은 exit 0" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

$r = Invoke-Hook 'hook-dispatch.ps1' (New-HdSkillJson 'hd-c' 'karina:plan') -Arguments @('loop-continue.ps1', 'record-work-start.ps1', 'inject-reply-language.ps1') -SplitStreams
Assert-Case -Name "hook-dispatch: 묶음의 컨텍스트가 stdout JSON 하나로 합쳐진다" -R (Get-HdJsonSummary $r) -ExpectExit 0 -ExpectContains 'json=True event=PreToolUse start=True lang=True'
$r = Invoke-Hook 'hook-dispatch.ps1' (New-HdSkillJson 'hd-k' 'karina:plan') -Arguments @('loop-continue.ps1', 'record-work-start.ps1', 'inject-reply-language.ps1') -SplitStreams -Process
Assert-Case -Name "hook-dispatch: 실제 stdout 파이프에서도 JSON 하나로 합쳐진다" -R (Get-HdJsonSummary $r) -ExpectExit 0 -ExpectContains 'json=True event=PreToolUse start=True lang=True'

$hdInstall = Join-Path $hd '.claude/plugins/cache/karina-plugins/karina/1.89.0'
$r = Invoke-Hook 'hook-dispatch.ps1' (New-WriteJson $hd (Join-Path $hdInstall 'scripts/block-destructive.ps1')) -Arguments @('-Blocking', 'guard-write.ps1', 'guard-harness.ps1')
Assert-Case -Name "hook-dispatch: 묶음 두 번째 스크립트도 같은 입력으로 판정한다" -R $r -ExpectExit 2 -ExpectContains '하니스 안전 hook 개조 시도 감지'

$r = Invoke-Hook 'hook-dispatch.ps1' (New-HdBashJson 'git push --force origin main') -Arguments $hdBashPair -SplitStreams
Assert-Case -Name "hook-dispatch: 앞 스크립트가 막아도 뒤 스크립트가 돈다 (차단 사유)" -R @{ code = $r.code; out = $r.err } -ExpectExit 2 -ExpectContains 'BLOCKED:'
Assert-Case -Name "hook-dispatch: 앞 스크립트가 막아도 뒤 스크립트가 돈다 (뒤 경고는 stdout 컨텍스트)" -R $r -ExpectExit 2 -ExpectContains '[EXTERNAL OP WARNING]'
Assert-Case -Name "hook-dispatch: 차단 사유(stderr)에 비차단 스크립트의 경고가 섞이지 않는다" -R @{ code = $r.code; out = $r.err } -ExpectExit 2 -ExpectNotContains '[EXTERNAL OP WARNING]'

$r = Invoke-Hook 'hook-dispatch.ps1' (New-HdBashJson 'git status') -Arguments @('nope.ps1')
Assert-Case -Name "hook-dispatch: 없는 스크립트 인자는 exit 1" -R $r -ExpectExit 1 -ExpectContains 'nope.ps1'
$r = Invoke-Hook 'hook-dispatch.ps1' (New-HdBashJson 'git status') -Arguments @('../x.ps1')
Assert-Case -Name "hook-dispatch: 폴더 밖을 가리키는 인자는 exit 1" -R $r -ExpectExit 1 -ExpectContains '../x.ps1'
$r = Invoke-Hook 'hook-dispatch.ps1' (New-HdBashJson 'git status') -Arguments @('hook-dispatch.ps1')
Assert-Case -Name "hook-dispatch: 자기 자신을 인자로 받지 않는다" -R $r -ExpectExit 1
$r = Invoke-Hook 'hook-dispatch.ps1' (New-HdBashJson 'git status')
Assert-Case -Name "hook-dispatch: 인자가 없으면 exit 1" -R $r -ExpectExit 1
$r = Invoke-Hook 'hook-dispatch.ps1' (New-HdBashJson 'git status') -Arguments @('-Blocking')
Assert-Case -Name "hook-dispatch: 스위치만 있고 스크립트가 없으면 exit 1" -R $r -ExpectExit 1

$r = Invoke-Hook 'hook-dispatch.ps1' '{not json' -Arguments $hdBashPair
Assert-Case -Name "hook-dispatch: 깨진 stdin 은 차단 묶음도 exit 0 (단독과 같다)" -R $r -ExpectExit 0

$null = Invoke-Hook 'hook-dispatch.ps1' (New-HdSkillJson 'hd-i1' 'karina:plan') -Arguments @('record-work-start.ps1')
$r = Invoke-Hook 'record-work-start.ps1' (New-HdSkillJson 'hd-i2' 'karina:chain-plan')
Assert-Case -Name "hook-dispatch: 끝난 뒤 공유 입력이 남지 않는다 (이어 부른 단독 스크립트가 자기 stdin 을 읽는다)" -R $r -ExpectExit 0 -ExpectContains 'karina:chain-plan'

$hdFake = Join-Path $work 'hd-fake'; New-Item -ItemType Directory $hdFake -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $scriptsDir 'hook-dispatch.ps1') -Destination $hdFake -Force
'throw "fake-throw"' | Set-Content -LiteralPath (Join-Path $hdFake 'f-throw.ps1') -Encoding UTF8
'exit 1' | Set-Content -LiteralPath (Join-Path $hdFake 'f-exit1.ps1') -Encoding UTF8
"[Console]::Error.WriteLine('FAKE-BLOCK'); exit 2" | Set-Content -LiteralPath (Join-Path $hdFake 'f-exit2.ps1') -Encoding UTF8
'[Console]::Out.WriteLine(''{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"FAKE-CTX"}}''); exit 0' | Set-Content -LiteralPath (Join-Path $hdFake 'f-ctx.ps1') -Encoding UTF8
'Set-Location -LiteralPath ([System.IO.Path]::GetTempPath()); exit 0' | Set-Content -LiteralPath (Join-Path $hdFake 'f-move.ps1') -Encoding UTF8
'$l = (Get-Location).ProviderPath.Replace(''\'', ''/''); [Console]::Out.WriteLine((@{ hookSpecificOutput = @{ hookEventName = ''PreToolUse''; additionalContext = "loc=$l" } } | ConvertTo-Json -Compress)); exit 0' | Set-Content -LiteralPath (Join-Path $hdFake 'f-loc.ps1') -Encoding UTF8
$hdFakeDispatch = Join-Path $hdFake 'hook-dispatch.ps1'
$hdIn = New-HdBashJson 'git status'

$r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('f-throw.ps1', 'f-ctx.ps1') -SplitStreams
Assert-Case -Name "hook-dispatch: 비차단 묶음은 스크립트 예외에도 exit 0" -R $r -ExpectExit 0 -ExpectContains 'FAKE-CTX'
Assert-Case -Name "hook-dispatch: 비차단 묶음의 실패는 stderr 한 줄로 남는다" -R @{ code = $r.code; out = $r.err } -ExpectExit 0 -ExpectContains 'f-throw.ps1'
$r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('f-exit1.ps1', 'f-ctx.ps1') -SplitStreams
Assert-Case -Name "hook-dispatch: 비차단 묶음은 exit 1 스크립트가 있어도 exit 0 이고 컨텍스트가 남는다" -R $r -ExpectExit 0 -ExpectContains 'FAKE-CTX'
$r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('-Blocking', 'f-exit1.ps1', 'f-ctx.ps1')
Assert-Case -Name "hook-dispatch: 차단 묶음은 exit 1 스크립트가 있으면 exit 1" -R $r -ExpectExit 1
$r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('-Blocking', 'f-throw.ps1', 'f-ctx.ps1')
Assert-Case -Name "hook-dispatch: 차단 묶음은 스크립트 예외면 exit 1" -R $r -ExpectExit 1
$r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('f-exit2.ps1', 'f-ctx.ps1')
Assert-Case -Name "hook-dispatch: 비차단 묶음도 exit 2 는 그대로 2" -R $r -ExpectExit 2 -ExpectContains 'FAKE-BLOCK'
$r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('-Blocking', 'f-exit1.ps1', 'f-exit2.ps1')
Assert-Case -Name "hook-dispatch: 차단 묶음에서 2 가 1 보다 앞선다" -R $r -ExpectExit 2 -ExpectContains 'FAKE-BLOCK'
"[Console]::Error.WriteLine('FAKE-WARN'); exit 0" | Set-Content -LiteralPath (Join-Path $hdFake 'f-warn.ps1') -Encoding UTF8
$r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('-Blocking', 'f-warn.ps1', 'f-exit2.ps1') -SplitStreams
Assert-Case -Name "hook-dispatch: exit 2 묶음의 stderr 는 2 를 낸 스크립트의 것만이다" -R @{ code = $r.code; out = $r.err } -ExpectExit 2 -ExpectContains 'FAKE-BLOCK'
Assert-Case -Name "hook-dispatch: exit 2 묶음의 stderr 에 exit 0 스크립트의 경고가 없다" -R @{ code = $r.code; out = $r.err } -ExpectExit 2 -ExpectNotContains 'FAKE-WARN'
$r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('f-warn.ps1', 'f-ctx.ps1') -SplitStreams
Assert-Case -Name "hook-dispatch: exit 0 묶음의 stderr 경고는 그대로 남는다" -R @{ code = $r.code; out = $r.err } -ExpectExit 0 -ExpectContains 'FAKE-WARN'
'[Console]::Out.WriteLine(''{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"deny","permissionDecisionReason":"FAKE-DENY"}}''); exit 0' | Set-Content -LiteralPath (Join-Path $hdFake 'f-deny.ps1') -Encoding UTF8
'[Console]::Out.WriteLine(''{"systemMessage":"FAKE-SYS"}''); exit 0' | Set-Content -LiteralPath (Join-Path $hdFake 'f-sysmsg.ps1') -Encoding UTF8
$r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('-Blocking', 'f-deny.ps1', 'f-ctx.ps1') -SplitStreams
Assert-Case -Name "hook-dispatch: 차단 묶음에서 전하지 못하는 JSON 필드(permissionDecision)는 exit 1 로 막는다" -R @{ code = $r.code; out = $r.err } -ExpectExit 1 -ExpectContains 'f-deny.ps1'
Assert-Case -Name "hook-dispatch: 전하지 못하는 JSON 필드 경고는 필드 이름을 밝힌다" -R @{ code = $r.code; out = $r.err } -ExpectExit 1 -ExpectContains 'permissionDecision'
$r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('f-deny.ps1', 'f-ctx.ps1') -SplitStreams
Assert-Case -Name "hook-dispatch: 비차단 묶음은 전하지 못하는 JSON 필드를 경고만 한다" -R @{ code = $r.code; out = $r.err } -ExpectExit 0 -ExpectContains 'permissionDecision'
$r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('-Blocking', 'f-sysmsg.ps1', 'f-ctx.ps1') -SplitStreams
Assert-Case -Name "hook-dispatch: 최상위 JSON 필드(systemMessage)도 차단 묶음에서 exit 1" -R @{ code = $r.code; out = $r.err } -ExpectExit 1 -ExpectContains 'systemMessage'
$r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('-Blocking', 'f-ctx.ps1') -SplitStreams
Assert-Case -Name "hook-dispatch: additionalContext 만 내는 JSON 은 차단 묶음에서도 경고 없이 exit 0" -R @{ code = $r.code; out = $r.err } -ExpectExit 0 -ExpectNotContains 'hook-dispatch:'

'[Console]::Out.WriteLine(''{"hookSpecificOutput":{"hookEventName":"PreToolUse","additionalContext":"ADV-CTX"}}''); exit 0' | Set-Content -LiteralPath (Join-Path $hdFake 'f-adv-ctx.ps1') -Encoding UTF8
'[System.IO.File]::WriteAllText((Join-Path $PSScriptRoot ''adv-ran.txt''), ''x''); exit 0' | Set-Content -LiteralPath (Join-Path $hdFake 'f-mark.ps1') -Encoding UTF8
$hdMark = Join-Path $hdFake 'adv-ran.txt'
function Invoke-HdAdv([string[]]$HdArgs, [switch]$Process) {
    if (Test-Path -LiteralPath $hdMark) { [System.IO.File]::Delete($hdMark) }
    $res = if ($Process) { Invoke-Hook $hdFakeDispatch $hdIn -Arguments $HdArgs -SplitStreams -Process } else { Invoke-Hook $hdFakeDispatch $hdIn -Arguments $HdArgs -SplitStreams }
    $res.ran = Test-Path -LiteralPath $hdMark
    return $res
}
$r = Invoke-HdAdv @('-Blocking', 'f-ctx.ps1', 'advisory:', 'f-mark.ps1', 'f-adv-ctx.ps1')
Assert-Case -Name "hook-dispatch: 권고 — 차단 스크립트가 모두 통과하면 권고가 돈다" -R @{ code = $r.code; out = "ran=$($r.ran)" } -ExpectExit 0 -ExpectContains 'ran=True'
Assert-Case -Name "hook-dispatch: 권고 — 권고의 컨텍스트가 차단 스크립트 컨텍스트와 한 JSON 으로 합쳐진다" -R (Get-HdJsonSummary $r) -ExpectExit 0 -ExpectContains 'json=True event=PreToolUse'
Assert-Case -Name "hook-dispatch: 권고 — 합친 컨텍스트에 두 출력이 다 있다" -R $r -ExpectExit 0 -ExpectContains 'FAKE-CTX\n\nADV-CTX'
$r = Invoke-HdAdv @('-Blocking', 'f-ctx.ps1', 'advisory:', 'f-throw.ps1', 'f-adv-ctx.ps1')
Assert-Case -Name "hook-dispatch: 권고 — 권고 예외는 차단 묶음을 막지 않는다" -R $r -ExpectExit 0 -ExpectContains 'ADV-CTX'
Assert-Case -Name "hook-dispatch: 권고 — 권고 예외는 stderr 에 남는다" -R @{ code = $r.code; out = $r.err } -ExpectExit 0 -ExpectContains 'f-throw.ps1'
$r = Invoke-HdAdv @('-Blocking', 'f-ctx.ps1', 'advisory:', 'f-exit1.ps1')
Assert-Case -Name "hook-dispatch: 권고 — 권고 exit 1 은 차단 묶음을 막지 않는다" -R $r -ExpectExit 0
$r = Invoke-HdAdv @('-Blocking', 'f-ctx.ps1', 'advisory:', 'f-sysmsg.ps1')
Assert-Case -Name "hook-dispatch: 권고 — 권고의 여분 JSON 필드는 차단 묶음을 막지 않는다" -R $r -ExpectExit 0
$r = Invoke-HdAdv @('-Blocking', 'f-ctx.ps1', 'advisory:', 'f-exit2.ps1')
Assert-Case -Name "hook-dispatch: 권고 — 권고 exit 2 도 묶음 결과에 들지 않는다" -R $r -ExpectExit 0
$r = Invoke-HdAdv @('-Blocking', 'f-exit2.ps1', 'advisory:', 'f-mark.ps1')
Assert-Case -Name "hook-dispatch: 권고 — 차단 exit 2 면 권고를 돌리지 않는다" -R @{ code = $r.code; out = "ran=$($r.ran)" } -ExpectExit 2 -ExpectContains 'ran=False'
$r = Invoke-HdAdv @('-Blocking', 'f-exit1.ps1', 'advisory:', 'f-mark.ps1')
Assert-Case -Name "hook-dispatch: 권고 — 차단 exit 1 이면 권고를 돌리지 않는다" -R @{ code = $r.code; out = "ran=$($r.ran)" } -ExpectExit 1 -ExpectContains 'ran=False'
$r = Invoke-HdAdv @('-AdvisoryBudgetMs', '0', '-Blocking', 'f-ctx.ps1', 'advisory:', 'f-mark.ps1') -Process
Assert-Case -Name "hook-dispatch: 권고 — 권고 예산이 0 이면 권고를 돌리지 않고 exit 0" -R @{ code = $r.code; out = "ran=$($r.ran)" } -ExpectExit 0 -ExpectContains 'ran=False'
$r = Invoke-HdAdv @('-Blocking', 'f-ctx.ps1', 'advisory:', 'f-mark.ps1') -Process
Assert-Case -Name "hook-dispatch: 권고 — 실제 프로세스 경로에서도 기본 예산이면 권고가 돈다" -R @{ code = $r.code; out = "ran=$($r.ran)" } -ExpectExit 0 -ExpectContains 'ran=True'
$r = Invoke-HdAdv @('-Blocking', 'f-ctx.ps1', 'advisory:', 'nope.ps1')
Assert-Case -Name "hook-dispatch: 권고 — 없는 권고 스크립트 인자는 exit 1" -R @{ code = $r.code; out = $r.err } -ExpectExit 1 -ExpectContains 'nope.ps1'
$r = Invoke-HdAdv @('-Blocking', 'f-ctx.ps1', 'advisory:', 'f-mark.ps1', 'advisory:', 'f-adv-ctx.ps1')
Assert-Case -Name "hook-dispatch: 권고 — 구분 토큰이 두 번이면 exit 1" -R $r -ExpectExit 1
$r = Invoke-HdAdv @('-Blocking', 'f-ctx.ps1', 'advisory:')
Assert-Case -Name "hook-dispatch: 권고 — 구분 토큰 뒤가 비면 exit 1" -R $r -ExpectExit 1
$r = Invoke-HdAdv @('advisory:', 'f-mark.ps1')
Assert-Case -Name "hook-dispatch: 권고 — 구분 토큰 앞이 비면 exit 1" -R $r -ExpectExit 1

Push-Location -LiteralPath $hd
try {
    $r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('f-move.ps1', 'f-loc.ps1')
} finally { Pop-Location }
$hdFwd = $hd.Replace('\', '/')
Assert-Case -Name "hook-dispatch: 앞 스크립트가 위치를 옮겨도 다음 스크립트는 시작 위치에서 돈다" -R $r -ExpectExit 0 -ExpectContains "loc=$hdFwd"

$hdPlainText = "    PLAIN-MARK code line`n- a`n  - nested`n`n| x | y |`n|---|---|`n{""hookSpecificOutput"":{""additionalContext"":""INNER""}}`n    tail"
[System.IO.File]::WriteAllText((Join-Path $hdFake 'plain.txt'), $hdPlainText, [System.Text.UTF8Encoding]::new($false))
'Write-Output ([System.IO.File]::ReadAllText((Join-Path $PSScriptRoot ''plain.txt'')))' | Set-Content -LiteralPath (Join-Path $hdFake 'f-plain.ps1') -Encoding UTF8
function Get-HdCtx([hashtable]$R) {
    try { $o = $R.out | ConvertFrom-Json -ErrorAction Stop } catch { return $null }
    return $o.hookSpecificOutput
}
$hdSsIn = @{ session_id = 'hd-ss'; hook_event_name = 'SessionStart'; source = 'startup'; cwd = $hd } | ConvertTo-Json -Compress
$hdUpeIn = @{ session_id = 'hd-upe'; hook_event_name = 'UserPromptExpansion'; command_name = 'plan'; cwd = $hd } | ConvertTo-Json -Compress
$r = Invoke-Hook $hdFakeDispatch $hdSsIn -Arguments @('f-plain.ps1', 'f-ctx.ps1') -SplitStreams
$hdGot = [string](Get-HdCtx $r).additionalContext
Assert-Case -Name "hook-dispatch: 평문 보존 — 묶음 컨텍스트가 스크립트가 낸 평문(들여쓰기·표·빈 줄·{ 시작 줄)과 글자 단위로 같다" -R @{ code = $r.code; out = "eq=$($hdGot -ceq ($hdPlainText + "`n`nFAKE-CTX"))" } -ExpectExit 0 -ExpectContains 'eq=True'
$r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('f-plain.ps1', 'f-ctx.ps1') -SplitStreams
Assert-Case -Name "hook-dispatch: 도구 이벤트 평문 제외 — PreToolUse 평문은 컨텍스트로 가지 않는다" -R $r -ExpectExit 0 -ExpectNotContains 'PLAIN-MARK'
$r = Invoke-Hook $hdFakeDispatch $hdUpeIn -Arguments @('f-plain.ps1', 'f-ctx.ps1') -SplitStreams
Assert-Case -Name "hook-dispatch: UserPromptExpansion 평문은 컨텍스트로 실린다" -R @{ code = $r.code; out = [string](Get-HdCtx $r).additionalContext } -ExpectExit 0 -ExpectContains 'PLAIN-MARK'
$r = Invoke-Hook $hdFakeDispatch $hdSsIn -Arguments @('f-plain.ps1', 'f-plain.ps1') -SplitStreams
Assert-Case -Name "hook-dispatch: 평문만 낸 묶음의 이벤트 이름은 입력값이다" -R @{ code = $r.code; out = "event=$([string](Get-HdCtx $r).hookEventName)" } -ExpectExit 0 -ExpectContains 'event=SessionStart'

$hdKo = Join-Path $work 'hd-한글프로젝트'; New-Item -ItemType Directory $hdKo -Force | Out-Null
$hdKoJson = New-WriteJson $hdKo (Join-Path $hdKo '소스파일.cs')
$rSolo = Invoke-Hook 'guard-write.ps1' $hdKoJson -Process -SplitStreams
$rPair = Invoke-Hook 'hook-dispatch.ps1' $hdKoJson -Arguments @('-Blocking', 'guard-write.ps1', 'guard-harness.ps1') -Process -SplitStreams
Assert-Case -Name "hook-dispatch: 한글 입력 — 단독 guard-write 가 막는다 (기준)" -R @{ code = $rSolo.code; out = $rSolo.err } -ExpectExit 2 -ExpectContains '소스파일.cs'
Assert-Case -Name "hook-dispatch: 한글 입력 — 묶음도 같은 exit 와 한글 경로로 막는다" -R @{ code = $rPair.code; out = $rPair.err } -ExpectExit 2 -ExpectContains '소스파일.cs'

$hdHooks = (Get-Content -LiteralPath (Join-Path $pluginRoot 'hooks/hooks.json') -Raw -Encoding UTF8 | ConvertFrom-Json).hooks
function Test-HdMatcher([string]$m, [string]$v) {
    if ([string]::IsNullOrEmpty($m)) { return $true }
    if ($m -match '^[A-Za-z0-9_ ,|-]*$') { return (($m -split '[|,]' | ForEach-Object { $_.Trim() }) -contains $v) }
    return ($v -match $m)
}
function Get-HdWiring([string]$ev, [string]$v) {
    $cmds = @(@($hdHooks.$ev) | Where-Object { Test-HdMatcher ([string]$_.matcher) $v } | ForEach-Object { @($_.hooks) } | ForEach-Object { [string]$_.command })
    $names = @($cmds | ForEach-Object { [regex]::Matches($_, '[a-z0-9-]+\.ps1') | ForEach-Object { $_.Value } } | Where-Object { $_ -ne 'hook-dispatch.ps1' } | ForEach-Object { $_ -replace '\.ps1$', '' } | Sort-Object -Unique)
    return @{ Count = $cmds.Count; Names = ($names -join ',') }
}
$hdExpect = [ordered]@{}
foreach ($t in 'Bash', 'PowerShell') { $hdExpect["PreToolUse|$t"] = 'block-destructive,guard-bash,inject-reply-language,suggest-agents-record'; $hdExpect["PostToolUse|$t"] = '' }
foreach ($t in 'Write', 'Edit', 'MultiEdit', 'NotebookEdit') { $hdExpect["PreToolUse|$t"] = 'guard-harness,guard-write,inject-reply-language'; $hdExpect["PostToolUse|$t"] = 'post-write-checks' }
$hdExpect['PreToolUse|Skill'] = 'inject-reply-language,loop-continue,record-work-start'
$hdExpect['PostToolUse|Skill'] = ''
foreach ($s in 'startup', 'resume', 'clear') { $hdExpect["SessionStart|$s"] = 'session-context,warn-version-drift' }
foreach ($s in 'compact', 'fork') { $hdExpect["SessionStart|$s"] = 'session-context' }
foreach ($c in 'plan', 'karina:plan') { $hdExpect["UserPromptExpansion|$c"] = 'loop-continue,record-work-start' }
foreach ($c in 'implement', 'karina:implement') { $hdExpect["UserPromptExpansion|$c"] = 'loop-continue' }
foreach ($c in 'chain-plan', 'karina:chain-plan') { $hdExpect["UserPromptExpansion|$c"] = 'record-work-start' }
$hdOver = @(); $hdSetDiff = @()
foreach ($k in $hdExpect.Keys) {
    $ev, $v = $k -split '\|', 2
    $w = Get-HdWiring $ev $v
    if ($w.Count -gt 1) { $hdOver += "$k=$($w.Count)" }
    if ($w.Names -ne $hdExpect[$k]) { $hdSetDiff += "$k=[$($w.Names)]" }
}
Assert-Case -Name "hook-dispatch: 배선 — 이벤트·도구·원인·명령마다 pwsh 명령이 하나 이하다" -R @{ code = 0; out = 'over=' + $(if ($hdOver) { $hdOver -join ' ' } else { 'none' }) } -ExpectContains 'over=none'
Assert-Case -Name "hook-dispatch: 배선 — 묶음이 부르는 스크립트 집합이 종전 배선과 같다" -R @{ code = 0; out = 'diff=' + $(if ($hdSetDiff) { $hdSetDiff -join ' ' } else { 'none' }) } -ExpectContains 'diff=none'
$hdBundled = @($hdHooks.PSObject.Properties | ForEach-Object { @($_.Value) } | ForEach-Object { @($_.hooks) } | ForEach-Object { [string]$_.command } | Where-Object { $_ -match 'hook-dispatch\.ps1' } | ForEach-Object { [regex]::Matches($_, '[a-z0-9-]+\.ps1') | ForEach-Object { $_.Value } } | Where-Object { $_ -ne 'hook-dispatch.ps1' } | Sort-Object -Unique)
$hdNoShared = @($hdBundled | Where-Object { -not (Select-String -LiteralPath (Join-Path $scriptsDir $_) -SimpleMatch -Pattern 'KarinaHookStdin' -Quiet) })
Assert-Case -Name "hook-dispatch: 배선 — 묶음에 든 스크립트는 모두 공유 입력을 먼저 읽는다" -R @{ code = 0; out = "bundled=$($hdBundled.Count) missing=$(if ($hdNoShared) { $hdNoShared -join ',' } else { 'none' })" } -ExpectContains 'bundled=10 missing=none'
$hdAdvWire = @(@($hdHooks.PreToolUse) | Where-Object { (Test-HdMatcher ([string]$_.matcher) 'Bash') -or (Test-HdMatcher ([string]$_.matcher) 'Write') } | ForEach-Object { @($_.hooks) } | ForEach-Object { $c = [string]$_.command; $i = $c.IndexOf(' advisory: '); if ($i -lt 0) { 'none' } else { (([regex]::Matches($c.Substring($i), '[a-z0-9-]+\.ps1') | ForEach-Object { $_.Value }) -join '+') } })
Assert-Case -Name "hook-dispatch: 배선 — 셸·쓰기 차단 묶음의 권고 구간에는 권고 스크립트만 있다" -R @{ code = 0; out = "adv=$($hdAdvWire -join ',')" } -ExpectContains 'adv=suggest-agents-record.ps1+inject-reply-language.ps1,inject-reply-language.ps1'
$hdBlk = @(@($hdHooks.PreToolUse) | Where-Object { (Test-HdMatcher ([string]$_.matcher) 'Bash') -or (Test-HdMatcher ([string]$_.matcher) 'Write') } | ForEach-Object { @($_.hooks) } | ForEach-Object { "$($_.command -match ' -Blocking ')/$($_.onFailure)/$($_.timeout)" })
Assert-Case -Name "hook-dispatch: 배선 — 차단 묶음 둘은 -Blocking · onFailure block · timeout 60 이다" -R @{ code = 0; out = "blk=$($hdBlk -join ',')" } -ExpectContains 'blk=True/block/60,True/block/60'
$hdTimeoutExpect = [ordered]@{ 'PreToolUse|Skill' = 30; 'SessionStart|startup' = 20; 'UserPromptExpansion|plan' = 20 }
$hdTimeoutDiff = @()
foreach ($k in $hdTimeoutExpect.Keys) {
    $ev, $v = $k -split '\|', 2
    $t = @(@($hdHooks.$ev) | Where-Object { Test-HdMatcher ([string]$_.matcher) $v } | ForEach-Object { @($_.hooks) } | Where-Object { [string]$_.command -match 'hook-dispatch\.ps1' } | ForEach-Object { [int]$_.timeout })
    if ($t.Count -ne 1 -or $t[0] -ne $hdTimeoutExpect[$k]) { $hdTimeoutDiff += "$k=$($t -join '/')" }
}
Assert-Case -Name "hook-dispatch: 배선 — 비차단 묶음 timeout 은 묶인 스크립트의 종전 timeout 합이다" -R @{ code = 0; out = 'diff=' + $(if ($hdTimeoutDiff) { $hdTimeoutDiff -join ' ' } else { 'none' }) } -ExpectContains 'diff=none'

}
