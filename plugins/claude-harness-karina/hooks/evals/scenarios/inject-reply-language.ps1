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

function Invoke-RlPost([string]$sid, [int]$n, [string]$agentId = '', [string]$hookEvent = 'PreToolUse', [string]$tool = 'Bash') {
    $hits = @(); $last = $null
    for ($i = 1; $i -le $n; $i++) {
        $o = @{ hook_event_name = $hookEvent; tool_name = $tool; tool_input = @{ command = 'ls' } }
        if ($sid) { $o.session_id = $sid }
        if ($agentId) { $o.agent_id = $agentId }
        $r = Invoke-Hook 'inject-reply-language.ps1' ($o | ConvertTo-Json -Compress)
        if (-not [string]::IsNullOrWhiteSpace([string]$r.out)) { $hits += $i; $last = $r }
    }
    return @{ code = 0; out = "hits=[$($hits -join ',')]"; last = $last }
}
function Invoke-RlSkill([string]$sid, [string]$agentId = '') {
    $o = @{ hook_event_name = 'PreToolUse'; tool_name = 'Skill'; tool_input = @{ skill = 'karina:implement' } }
    if ($sid) { $o.session_id = $sid }
    if ($agentId) { $o.agent_id = $agentId }
    return (Invoke-Hook 'inject-reply-language.ps1' ($o | ConvertTo-Json -Compress))
}

$p = Invoke-RlPost 'rl-p1' 40
Assert-Case -Name "inject-reply-language: PreToolUse 셸 도구는 20회째마다 주입한다" -R $p -ExpectContains 'hits=[20,40]'
$pCtx = if ($p.last) { Get-RlContext $p.last } else { @{ code = 0; out = 'none' } }
Assert-Case -Name "inject-reply-language: PreToolUse 주입은 같은 한글 줄이다" -R $pCtx -ExpectContains 'event=PreToolUse ctx=[karina 응답 언어]'
Assert-Case -Name "inject-reply-language: PreToolUse 쓰기 도구도 20회째에 주입한다" -R (Invoke-RlPost 'rl-w1' 20 '' 'PreToolUse' 'Write') -ExpectContains 'hits=[20]'
Assert-Case -Name "inject-reply-language: PostToolUse 는 세지도 주입하지도 않는다" -R (Invoke-RlPost 'rl-post' 40 '' 'PostToolUse') -ExpectContains 'hits=[]'
$null = Invoke-RlPost 'rl-p2' 15
$null = Invoke-RlSkill 'rl-p2'
Assert-Case -Name "inject-reply-language: Skill 주입이 카운터를 0으로 되돌린다" -R (Invoke-RlPost 'rl-p2' 20) -ExpectContains 'hits=[20]'
Assert-Case -Name "inject-reply-language: session_id 없는 PreToolUse 셸 호출은 무출력" -R (Invoke-RlPost '' 20) -ExpectContains 'hits=[]'
Assert-Case -Name "inject-reply-language: session_id 없는 Skill 도 주입한다" -R (Get-RlContext (Invoke-RlSkill '')) -ExpectExit 0 -ExpectContains 'event=PreToolUse ctx=[karina 응답 언어]'
$null = Invoke-RlPost 'rl-p3' 10 'sub-1'
Assert-Case -Name "inject-reply-language: 서브에이전트 PreToolUse 는 세지 않는다 — 메인 10회째 무출력" -R (Invoke-RlPost 'rl-p3' 10) -ExpectContains 'hits=[]'
Assert-Case -Name "inject-reply-language: 서브에이전트 호출을 뺀 메인 20회째에 주입한다" -R (Invoke-RlPost 'rl-p3' 10) -ExpectContains 'hits=[10]'
$null = Invoke-RlPost 'rl-p4' 15
$sub = Invoke-RlSkill 'rl-p4' 'sub-2'
Assert-Case -Name "inject-reply-language: 서브에이전트 Skill 도 주입한다" -R (Get-RlContext $sub) -ExpectContains 'event=PreToolUse ctx=[karina 응답 언어]'
Assert-Case -Name "inject-reply-language: 서브에이전트 Skill 은 메인 카운터를 되돌리지 않는다" -R (Invoke-RlPost 'rl-p4' 5) -ExpectContains 'hits=[5]'

$rlHooks = Get-Content -LiteralPath (Join-Path $pluginRoot 'hooks/hooks.json') -Raw -Encoding UTF8 | ConvertFrom-Json
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
