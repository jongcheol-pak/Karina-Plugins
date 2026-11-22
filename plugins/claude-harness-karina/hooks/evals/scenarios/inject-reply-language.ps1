# scenarios/inject-reply-language.ps1 — inject-reply-language 시나리오 (dot-source 전용, 단독 실행 금지)
# 호출자(run-hook-evals.ps1)의 공용 헬퍼(Assert-Case·Invoke-Hook)와 공유 변수($pluginRoot)를 그대로 쓴다.
if (Test-HookSelected @('inject-reply-language')) {

function Get-RlContext([hashtable]$R) {
    try { $o = $R.out | ConvertFrom-Json -ErrorAction Stop } catch { return @{ code = $R.code; out = 'not-json' } }
    return @{ code = $R.code; out = "event=$($o.hookSpecificOutput.hookEventName) ctx=$($o.hookSpecificOutput.additionalContext)" }
}
function New-RlSkillJson([string]$skill) {
    return (@{ session_id = 'rl-s'; hook_event_name = 'PreToolUse'; tool_name = 'Skill'; tool_input = @{ skill = $skill } } | ConvertTo-Json -Compress)
}

$r = Invoke-Hook 'inject-reply-language.ps1' (@{ session_id = 'rl-u'; hook_event_name = 'UserPromptSubmit'; prompt = 'implement this' } | ConvertTo-Json -Compress)
Assert-Case -Name "inject-reply-language: UserPromptSubmit 는 무출력(매 턴 주입 폐지)" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'inject-reply-language.ps1' (New-RlSkillJson 'karina:plan')
Assert-Case -Name "inject-reply-language: Skill karina:plan 발동에 주입한다" -R (Get-RlContext $r) -ExpectExit 0 -ExpectContains 'event=PreToolUse ctx=[karina 응답 언어]'
Assert-Case -Name "inject-reply-language: 주입 줄이 한글로 쓰라고 지시한다" -R (Get-RlContext $r) -ExpectContains '한글로 쓴다'
$r = Invoke-Hook 'inject-reply-language.ps1' (New-RlSkillJson 'simplify')
Assert-Case -Name "inject-reply-language: karina 밖 스킬 발동에도 주입한다" -R (Get-RlContext $r) -ExpectExit 0 -ExpectContains 'event=PreToolUse ctx=[karina 응답 언어]'

# ---- 침묵 ----
$r = Invoke-Hook 'inject-reply-language.ps1' (@{ session_id = 'rl-n1'; hook_event_name = 'PreToolUse'; tool_name = 'Bash'; tool_input = @{ command = 'ls' } } | ConvertTo-Json -Compress)
Assert-Case -Name "inject-reply-language: Skill 이 아닌 도구의 첫 호출은 무출력" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'inject-reply-language.ps1' 'not json'
Assert-Case -Name "inject-reply-language: 깨진 stdin 은 exit 0 무출력" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'inject-reply-language.ps1' (@{ session_id = 'rl-n3'; hook_event_name = 'SessionStart'; source = 'startup' } | ConvertTo-Json -Compress)
Assert-Case -Name "inject-reply-language: 다른 이벤트는 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

$rlRun = [guid]::NewGuid().ToString('N').Substring(0, 8)
$rlTxDir = Join-Path $work 'rl-transcripts'; New-Item -ItemType Directory $rlTxDir -Force | Out-Null
function New-RlRow([string]$uuid, [string]$type, $content) {
    return (@{ type = $type; uuid = $uuid; message = @{ role = $type; content = $content } } | ConvertTo-Json -Compress -Depth 6)
}
function New-RlTranscript([string]$name, [string[]]$rows) {
    $p = Join-Path $rlTxDir "$name.jsonl"
    [System.IO.File]::WriteAllText($p, (($rows -join "`n") + "`n"))
    return $p
}
function Add-RlRow([string]$path, [string]$row) { [System.IO.File]::AppendAllText($path, $row + "`n") }
function Invoke-RlPre([string]$sid, [string]$tx, [string]$tool = 'Bash', [string]$agentId = '', [string]$hookEvent = 'PreToolUse') {
    $o = @{ hook_event_name = $hookEvent; tool_name = $tool; tool_input = @{ command = 'ls' } }
    if ($sid) { $o.session_id = $sid }
    if ($tx) { $o.transcript_path = $tx }
    if ($agentId) { $o.agent_id = $agentId }
    return (Invoke-Hook 'inject-reply-language.ps1' ($o | ConvertTo-Json -Compress))
}
function Invoke-RlSkill([string]$sid, [string]$agentId = '') {
    $o = @{ hook_event_name = 'PreToolUse'; tool_name = 'Skill'; tool_input = @{ skill = 'karina:implement' } }
    if ($sid) { $o.session_id = $sid }
    if ($agentId) { $o.agent_id = $agentId }
    return (Invoke-Hook 'inject-reply-language.ps1' ($o | ConvertTo-Json -Compress))
}
$rlUser = New-RlRow 'u1' 'user' 'T3 진행해'
$rlToolUse = New-RlRow 'a9' 'assistant' @(@{ type = 'tool_use'; id = 't1'; name = 'Bash'; input = @{ command = 'ls' } })
$rlEnMemo = 'Waiting for the server launch to finish before checking the log output.'
$rlTxEn = New-RlTranscript 'en' @($rlUser, (New-RlRow 'a1' 'assistant' @(@{ type = 'text'; text = $rlEnMemo })), $rlToolUse)
$r = Invoke-RlPre "rl-t1-$rlRun" $rlTxEn
Assert-Case -Name "inject-reply-language: 직전 assistant 텍스트가 영문 메모면 셸 PreToolUse 에 교정 줄을 싣는다" -R (Get-RlContext $r) -ExpectExit 0 -ExpectContains 'event=PreToolUse ctx=[karina 응답 언어] 직전'
Assert-Case -Name "inject-reply-language: 같은 텍스트(uuid)에는 두 번 싣지 않는다" -R (Invoke-RlPre "rl-t1-$rlRun" $rlTxEn) -ExpectExit 0 -ExpectSilent $true
Add-RlRow $rlTxEn (New-RlRow 'a10' 'assistant' @(@{ type = 'text'; text = 'Now the build is running again and the output looks fine so far.' }))
Assert-Case -Name "inject-reply-language: 새 영문 텍스트(다른 uuid)에는 다시 싣는다" -R (Get-RlContext (Invoke-RlPre "rl-t1-$rlRun" $rlTxEn)) -ExpectExit 0 -ExpectContains 'event=PreToolUse ctx=[karina 응답 언어] 직전'
Assert-Case -Name "inject-reply-language: 쓰기 도구도 영문 메모에 교정 줄을 싣는다" -R (Get-RlContext (Invoke-RlPre "rl-t2-$rlRun" $rlTxEn 'Write')) -ExpectExit 0 -ExpectContains 'event=PreToolUse ctx=[karina 응답 언어] 직전'
$rlTxKo = New-RlTranscript 'ko' @($rlUser, (New-RlRow 'a1' 'assistant' @(@{ type = 'text'; text = '서버가 뜰 때까지 기다린 뒤 `launch.log` 출력을 봅니다.' })), $rlToolUse)
Assert-Case -Name "inject-reply-language: 한글 메모는 무출력" -R (Invoke-RlPre "rl-t3-$rlRun" $rlTxKo) -ExpectExit 0 -ExpectSilent $true
$rlTxShort = New-RlTranscript 'short' @($rlUser, (New-RlRow 'a1' 'assistant' @(@{ type = 'text'; text = 'Done. All good.' })), $rlToolUse)
Assert-Case -Name "inject-reply-language: 라틴 낱말 4개 이하의 짧은 메모는 무출력" -R (Invoke-RlPre "rl-t4-$rlRun" $rlTxShort) -ExpectExit 0 -ExpectSilent $true
Assert-Case -Name "inject-reply-language: 서브에이전트 PreToolUse 는 무출력" -R (Invoke-RlPre "rl-t5-$rlRun" $rlTxEn 'Bash' 'sub-1') -ExpectExit 0 -ExpectSilent $true
Assert-Case -Name "inject-reply-language: transcript_path 없는 셸 호출은 무출력" -R (Invoke-RlPre "rl-t6-$rlRun" '') -ExpectExit 0 -ExpectSilent $true
Assert-Case -Name "inject-reply-language: 전사 파일을 읽지 못하면 무출력" -R (Invoke-RlPre "rl-t7-$rlRun" (Join-Path $rlTxDir 'missing.jsonl')) -ExpectExit 0 -ExpectSilent $true
$rlTxNone = New-RlTranscript 'none' @($rlUser, $rlToolUse)
Assert-Case -Name "inject-reply-language: 전사 꼬리에 assistant 텍스트가 없으면 무출력" -R (Invoke-RlPre "rl-t8-$rlRun" $rlTxNone) -ExpectExit 0 -ExpectSilent $true
Assert-Case -Name "inject-reply-language: session_id 없는 셸 호출은 무출력" -R (Invoke-RlPre '' $rlTxEn) -ExpectExit 0 -ExpectSilent $true
Assert-Case -Name "inject-reply-language: PostToolUse 는 무출력" -R (Invoke-RlPre "rl-t9-$rlRun" $rlTxEn 'Bash' '' 'PostToolUse') -ExpectExit 0 -ExpectSilent $true
Assert-Case -Name "inject-reply-language: session_id 없는 Skill 도 주입한다" -R (Get-RlContext (Invoke-RlSkill '')) -ExpectExit 0 -ExpectContains 'event=PreToolUse ctx=[karina 응답 언어]'
Assert-Case -Name "inject-reply-language: 서브에이전트 Skill 도 주입한다" -R (Get-RlContext (Invoke-RlSkill 'rl-p4' 'sub-2')) -ExpectContains 'event=PreToolUse ctx=[karina 응답 언어]'

function Invoke-RlStop([string]$sid, $msg, [bool]$active = $false) {
    $o = @{ session_id = "$sid-$rlRun"; hook_event_name = 'Stop'; cwd = $pluginRoot; stop_hook_active = $active; background_tasks = @() }
    if ($null -ne $msg) { $o.last_assistant_message = $msg }
    return (Invoke-Hook 'inject-reply-language.ps1' ($o | ConvertTo-Json -Compress))
}
$rlEn = 'Plan 6 complete: all tasks are done and verified, and the report follows below.'
$rlEnQuoted = 'Plan 6 complete: the plugin screen now shows the "설치되지 않음" tab and the "로그" section, matching the original design exactly.'
$r = Invoke-RlStop 'rl-st1' $rlEn
Assert-Case -Name "inject-reply-language: Stop 영문 산문 응답에 재작성 줄을 싣는다" -R (Get-RlContext $r) -ExpectExit 0 -ExpectContains 'event=Stop ctx=[karina 응답 언어]'
Assert-Case -Name "inject-reply-language: Stop 재작성 줄이 한글로 다시 쓰라고 지시한다" -R (Get-RlContext $r) -ExpectContains '한글로 다시'
Assert-Case -Name "inject-reply-language: Stop 한글 UI 문자열을 인용한 영문 보고도 잡는다" -R (Get-RlContext (Invoke-RlStop 'rl-st2' $rlEnQuoted)) -ExpectContains 'event=Stop ctx=[karina 응답 언어]'
Assert-Case -Name "inject-reply-language: Stop 한글 산문은 무출력" -R (Invoke-RlStop 'rl-st3' '계획 6 완료 — 모든 task 를 끝내고 검증했습니다.') -ExpectExit 0 -ExpectSilent $true
Assert-Case -Name "inject-reply-language: Stop 한글 산문 + 영문 코드 펜스는 무출력" -R (Invoke-RlStop 'rl-st4' "결과를 아래에 적습니다.`n``````text`nAll tests passed and the build succeeded without any warnings`n``````") -ExpectExit 0 -ExpectSilent $true
Assert-Case -Name "inject-reply-language: Stop 영문이 코드·인라인 코드·URL 안에만 있으면 무출력" -R (Invoke-RlStop 'rl-st5' "``git commit -m fix the build and push all changes now```n``````n`nrun the full test suite again please now`n``````n`nhttps://example.com/some/long/path/with/many/words") -ExpectExit 0 -ExpectSilent $true
Assert-Case -Name "inject-reply-language: Stop 라틴 낱말 4개 이하의 짧은 응답은 무출력" -R (Invoke-RlStop 'rl-st6' 'Done. All good.') -ExpectExit 0 -ExpectSilent $true
Assert-Case -Name "inject-reply-language: Stop last_assistant_message 가 없으면 무출력" -R (Invoke-RlStop 'rl-st7' $null) -ExpectExit 0 -ExpectSilent $true
$null = Invoke-RlStop 'rl-st8' $rlEn
Assert-Case -Name "inject-reply-language: Stop 이 hook 이 이은 turn 은 다시 걸지 않는다" -R (Invoke-RlStop 'rl-st8' $rlEn $true) -ExpectExit 0 -ExpectSilent $true
$rlStateDir = Join-Path $env:USERPROFILE '.claude/.state/reply-language'
Assert-Case -Name "inject-reply-language: Stop 재진입 뒤 재작성 표시를 지운다" -R @{ code = 0; out = 'mark=' + (Test-Path -LiteralPath (Join-Path $rlStateDir "rl-st8-$rlRun.stop")) } -ExpectContains 'mark=False'
New-Item -Force -ItemType Directory -Path $rlStateDir | Out-Null
Set-Content -LiteralPath (Join-Path $rlStateDir "rl-st11-$rlRun.stop") -Value '1' -NoNewline
Assert-Case -Name "inject-reply-language: Stop 새 turn(stop_hook_active 거짓)은 남은 표시가 있어도 판정한다" -R (Get-RlContext (Invoke-RlStop 'rl-st11' $rlEn)) -ExpectContains 'event=Stop ctx=[karina 응답 언어]'
Assert-Case -Name "inject-reply-language: Stop 다른 hook 이 이은 turn(stop_hook_active 참·자기 표시 없음)의 영문은 잡는다" -R (Get-RlContext (Invoke-RlStop 'rl-st9' $rlEn $true)) -ExpectContains 'event=Stop ctx=[karina 응답 언어]'
$rlCounter = Join-Path $env:USERPROFILE ".claude/.state/reply-language/rl-st10-$rlRun.txt"
New-Item -Force -ItemType Directory -Path (Split-Path -Parent $rlCounter) | Out-Null
Set-Content -LiteralPath $rlCounter -Value 7 -NoNewline
$null = Invoke-RlStop 'rl-st10' $rlEn
Assert-Case -Name "inject-reply-language: Stop 은 셸·쓰기 상태 파일을 바꾸지 않는다" -R @{ code = 0; out = 'counter=' + (Get-Content -LiteralPath $rlCounter -Raw) } -ExpectContains 'counter=7'

$rlHooks = Get-Content -LiteralPath (Join-Path $pluginRoot 'hooks/hooks.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$rlStop = @($rlHooks.hooks.Stop | ForEach-Object { @($_.hooks) } | Where-Object { [string]$_.command -match 'hook-dispatch\.ps1"? loop-continue\.ps1 inject-reply-language\.ps1' })
Assert-Case -Name "inject-reply-language: Stop 은 loop-continue 와 한 디스패처 묶음으로 부른다" -R @{ code = 0; out = "stop=$($rlStop.Count) blocks=$(@($rlHooks.hooks.Stop).Count)" } -ExpectContains 'stop=1 blocks=1'
$rlUps = @($rlHooks.hooks.UserPromptSubmit | Where-Object { ($_.hooks.command -join ' ') -match 'inject-reply-language' })
Assert-Case -Name "inject-reply-language: UserPromptSubmit 블록이 이 스크립트를 부르지 않는다" -R @{ code = 0; out = "blocks=$($rlUps.Count)" } -ExpectContains 'blocks=0'
$rlPre = @($rlHooks.hooks.PreToolUse | Where-Object { ($_.hooks.command -join ' ') -match 'inject-reply-language' })
$rlPreHit = @('Skill', 'Bash', 'PowerShell', 'Write', 'Edit', 'MultiEdit', 'NotebookEdit', 'Read', 'Grep', 'Glob' | Where-Object {
    $tool = $_
    @($rlPre | Where-Object {
        $m = [string]$_.matcher
        if ($m -match '^[A-Za-z0-9_ ,|-]*$') { ($m -split '[|,]' | ForEach-Object { $_.Trim() }) -contains $tool } else { $tool -match $m }
    }).Count -gt 0
})
Assert-Case -Name "inject-reply-language: PreToolUse 블록이 Skill·셸·쓰기 도구만 받는다" -R @{ code = 0; out = "blocks=$($rlPre.Count) hits=[$($rlPreHit -join ',')]" } -ExpectContains 'blocks=3 hits=[Skill,Bash,PowerShell,Write,Edit,MultiEdit,NotebookEdit]'
$rlPreAdv = @($rlPre | Where-Object { [string]$_.matcher -ne 'Skill' } | ForEach-Object { @($_.hooks) } | Where-Object { [string]$_.command -match 'advisory:.*inject-reply-language' })
Assert-Case -Name "inject-reply-language: 셸·쓰기 PreToolUse 에서는 권고(advisory:) 뒤에 선다" -R @{ code = 0; out = "adv=$($rlPreAdv.Count)" } -ExpectContains 'adv=2'
$rlPost = @($rlHooks.hooks.PostToolUse | Where-Object { ($_.hooks.command -join ' ') -match 'inject-reply-language' })
Assert-Case -Name "inject-reply-language: PostToolUse 블록이 이 스크립트를 부르지 않는다" -R @{ code = 0; out = "blocks=$($rlPost.Count)" } -ExpectContains 'blocks=0'

}
