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

$r = Invoke-Hook 'hook-dispatch.ps1' (New-HdBashJson 'git push --force origin main') -Arguments $hdBashPair
Assert-Case -Name "hook-dispatch: 앞 스크립트가 막아도 뒤 스크립트가 돈다 (차단)" -R $r -ExpectExit 2 -ExpectContains 'BLOCKED:'
Assert-Case -Name "hook-dispatch: 앞 스크립트가 막아도 뒤 스크립트가 돈다 (뒤 경고)" -R $r -ExpectExit 2 -ExpectContains '[EXTERNAL OP WARNING]'

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

Push-Location -LiteralPath $hd
try {
    $r = Invoke-Hook $hdFakeDispatch $hdIn -Arguments @('f-move.ps1', 'f-loc.ps1')
} finally { Pop-Location }
$hdFwd = $hd.Replace('\', '/')
Assert-Case -Name "hook-dispatch: 앞 스크립트가 위치를 옮겨도 다음 스크립트는 시작 위치에서 돈다" -R $r -ExpectExit 0 -ExpectContains "loc=$hdFwd"

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
foreach ($t in 'Bash', 'PowerShell') { $hdExpect["PreToolUse|$t"] = 'block-destructive,guard-bash'; $hdExpect["PostToolUse|$t"] = 'inject-reply-language,suggest-agents-record' }
foreach ($t in 'Write', 'Edit', 'MultiEdit', 'NotebookEdit') { $hdExpect["PreToolUse|$t"] = 'guard-harness,guard-write'; $hdExpect["PostToolUse|$t"] = 'inject-reply-language,post-write-checks' }
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
Assert-Case -Name "hook-dispatch: 배선 — 묶음에 든 스크립트는 모두 공유 입력을 먼저 읽는다" -R @{ code = 0; out = "bundled=$($hdBundled.Count) missing=$(if ($hdNoShared) { $hdNoShared -join ',' } else { 'none' })" } -ExpectContains 'bundled=11 missing=none'
$hdBlk = @(@($hdHooks.PreToolUse) | Where-Object { (Test-HdMatcher ([string]$_.matcher) 'Bash') -or (Test-HdMatcher ([string]$_.matcher) 'Write') } | ForEach-Object { @($_.hooks) } | ForEach-Object { "$($_.command -match ' -Blocking ')/$($_.onFailure)/$($_.timeout)" })
Assert-Case -Name "hook-dispatch: 배선 — 차단 묶음 둘은 -Blocking · onFailure block · timeout 60 이다" -R @{ code = 0; out = "blk=$($hdBlk -join ',')" } -ExpectContains 'blk=True/block/60,True/block/60'

}
