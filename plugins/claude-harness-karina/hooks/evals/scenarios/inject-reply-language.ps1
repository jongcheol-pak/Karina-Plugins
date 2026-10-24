# scenarios/inject-reply-language.ps1 — inject-reply-language 시나리오 (dot-source 전용, 단독 실행 금지)
# 호출자(run-hook-evals.ps1)의 공용 헬퍼(Assert-Case·Invoke-Hook)와 공유 변수($pluginRoot)를 그대로 쓴다.
# 무엇을 재는가: 주입 2이벤트(UserPromptSubmit·Skill 도구) · 스킬 이름 무관 · hookEventName · 침묵 3경로 ·
#   배선(hooks.json). 판정 근거는 `scripts/rules/reply-language-rationale.md` 다.
if (Test-HookSelected @('inject-reply-language')) {

function Get-RlContext([hashtable]$R) {
    try { $o = $R.out | ConvertFrom-Json -ErrorAction Stop } catch { return @{ code = $R.code; out = 'not-json' } }
    return @{ code = $R.code; out = "event=$($o.hookSpecificOutput.hookEventName) ctx=$($o.hookSpecificOutput.additionalContext)" }
}
function New-RlSkillJson([string]$skill) {
    return (@{ session_id = 'rl-s'; hook_event_name = 'PreToolUse'; tool_name = 'Skill'; tool_input = @{ skill = $skill } } | ConvertTo-Json -Compress)
}

# ---- 주입 ----
$r = Invoke-Hook 'inject-reply-language.ps1' (@{ session_id = 'rl-u'; hook_event_name = 'UserPromptSubmit'; prompt = 'implement this' } | ConvertTo-Json -Compress)
Assert-Case -Name "inject-reply-language: UserPromptSubmit 에 한글 응답 줄을 주입한다" -R (Get-RlContext $r) -ExpectExit 0 -ExpectContains 'event=UserPromptSubmit ctx=[karina 응답 언어]'
Assert-Case -Name "inject-reply-language: 주입 줄이 한글로 쓰라고 지시한다" -R (Get-RlContext $r) -ExpectContains '한글로 쓴다'
$r = Invoke-Hook 'inject-reply-language.ps1' (New-RlSkillJson 'karina:plan')
Assert-Case -Name "inject-reply-language: Skill karina:plan 발동에 주입한다" -R (Get-RlContext $r) -ExpectExit 0 -ExpectContains 'event=PreToolUse ctx=[karina 응답 언어]'
$r = Invoke-Hook 'inject-reply-language.ps1' (New-RlSkillJson 'simplify')
Assert-Case -Name "inject-reply-language: karina 밖 스킬 발동에도 주입한다" -R (Get-RlContext $r) -ExpectExit 0 -ExpectContains 'event=PreToolUse ctx=[karina 응답 언어]'

# ---- 침묵 ----
$r = Invoke-Hook 'inject-reply-language.ps1' (@{ session_id = 'rl-n1'; hook_event_name = 'PreToolUse'; tool_name = 'Bash'; tool_input = @{ command = 'ls' } } | ConvertTo-Json -Compress)
Assert-Case -Name "inject-reply-language: Skill 이 아닌 도구는 무출력" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'inject-reply-language.ps1' 'not json'
Assert-Case -Name "inject-reply-language: 깨진 stdin 은 exit 0 무출력" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'inject-reply-language.ps1' (@{ session_id = 'rl-n3'; hook_event_name = 'SessionStart'; source = 'startup' } | ConvertTo-Json -Compress)
Assert-Case -Name "inject-reply-language: 다른 이벤트는 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

# ---- 배선 — 위 케이스는 스크립트에 JSON 을 직접 넣어 hooks.json 을 거치지 않는다 ----
#   글자·|만으로 된 matcher 는 「정확 일치 목록」이라 정확 일치로 흉내 낸다(record-work-start 시나리오와 같은 방식).
$rlHooks = Get-Content -LiteralPath (Join-Path $pluginRoot 'hooks/hooks.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$rlUps = @($rlHooks.hooks.UserPromptSubmit | Where-Object { ($_.hooks.command -join ' ') -match 'inject-reply-language' })
$rlUpsOpen = @($rlUps | Where-Object { [string]::IsNullOrEmpty([string]$_.matcher) })
Assert-Case -Name "inject-reply-language: UserPromptSubmit 블록이 matcher 없이 이 스크립트를 부른다" -R @{ code = 0; out = "blocks=$($rlUps.Count) open=$($rlUpsOpen.Count)" } -ExpectContains 'blocks=1 open=1'
$rlPre = @($rlHooks.hooks.PreToolUse | Where-Object { ($_.hooks.command -join ' ') -match 'inject-reply-language' })
$rlPreHit = @('Skill', 'Bash' | Where-Object {
    $tool = $_
    @($rlPre | Where-Object {
        $m = [string]$_.matcher
        if ($m -match '^[A-Za-z0-9_ ,|-]*$') { ($m -split '[|,]' | ForEach-Object { $_.Trim() }) -contains $tool } else { $tool -match $m }
    }).Count -gt 0
})
Assert-Case -Name "inject-reply-language: PreToolUse 블록이 Skill 만 받고 Bash 는 받지 않는다" -R @{ code = 0; out = "blocks=$($rlPre.Count) hits=$($rlPreHit -join ',')" } -ExpectContains 'blocks=1 hits=Skill' -ExpectNotContains 'Bash'

}
