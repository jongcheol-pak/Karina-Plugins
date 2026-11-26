if (Test-HookSelected @('away-precheck')) {

$apWork = Join-Path $iso '.claude/.state/work-start'
$apLoop = Join-Path $iso '.claude/.state/loop-continue'
New-Item -ItemType Directory -Path $apWork -Force | Out-Null
New-Item -ItemType Directory -Path $apLoop -Force | Out-Null
function New-ApJson([string]$sid, [string]$prompt) {
    return (@{ session_id = $sid; hook_event_name = 'UserPromptSubmit'; cwd = $pluginRoot; prompt = $prompt } | ConvertTo-Json -Compress)
}
function Set-ApWorkStart([string]$sid, [string]$json) {
    Set-Content -LiteralPath (Join-Path $apWork ($sid + '.json')) -Value $json -Encoding UTF8
}
function Get-ApContext([hashtable]$R) {
    if ([string]::IsNullOrWhiteSpace([string]$R.out)) { return @{ code = $R.code; out = 'silent' } }
    try { $o = $R.out | ConvertFrom-Json -ErrorAction Stop } catch { return @{ code = $R.code; out = 'not-json' } }
    return @{ code = $R.code; out = "event=$($o.hookSpecificOutput.hookEventName) ctx=$($o.hookSpecificOutput.additionalContext)" }
}

Set-ApWorkStart 'ap-plan' '{"plan":"2026-11-26 11:45"}'
foreach ($p in '이제 나 잠잔다', '오늘은 퇴근한다', '자러 갈게 나머지 부탁해', '잠시 자리 비울게', '외출했다 올게', '내일 이어서 하자', '이제 잔다', '오늘은 그만 잔다', '저 자러 가요', '자러 가', '잠 자야지') {
    $r = Invoke-Hook 'away-precheck.ps1' (New-ApJson 'ap-plan' $p)
    Assert-Case -Name "away-precheck: 한국어 부재 문구 「$p」 에 주입한다" -R (Get-ApContext $r) -ExpectExit 0 -ExpectContains 'ctx=[karina 부재 예고]'
}
foreach ($p in 'OK, Going To Bed now', 'heading home, AFK', 'signing off for today') {
    $r = Invoke-Hook 'away-precheck.ps1' (New-ApJson 'ap-plan' $p)
    Assert-Case -Name "away-precheck: 영어 부재 문구 「$p」 에 대소문자 없이 주입한다" -R (Get-ApContext $r) -ExpectExit 0 -ExpectContains 'ctx=[karina 부재 예고]'
}
foreach ($p in 'yes', '승인', 'T2 부터 계속해', '잔디 색을 바꿔줘', 'sleep 함수 타임아웃을 늘려줘') {
    $r = Invoke-Hook 'away-precheck.ps1' (New-ApJson 'ap-plan' $p)
    Assert-Case -Name "away-precheck: 부재 문구가 아닌 「$p」 는 무출력" -R $r -ExpectExit 0 -ExpectSilent $true
}

$r = Invoke-Hook 'away-precheck.ps1' (New-ApJson 'ap-plan' '나 잔다')
Assert-Case -Name "away-precheck: hookEventName 이 UserPromptSubmit 이다" -R (Get-ApContext $r) -ExpectContains 'event=UserPromptSubmit ctx='
$apCtx = (Get-ApContext $r).out
$apDoc = if ($apCtx -match ' — (.+AWAY-PRECHECK\.md) 「') { $Matches[1] } else { '' }
Assert-Case -Name "away-precheck: 주입 줄이 가리키는 skills/AWAY-PRECHECK.md 가 실재한다" -R @{ code = 0; out = "doc=$([bool]$apDoc) exists=$(if ($apDoc) { Test-Path -LiteralPath $apDoc -PathType Leaf } else { $false })" } -ExpectContains 'doc=True exists=True'

Set-ApWorkStart 'ap-chain' '{"chain-plan":"2026-11-26 11:45"}'
$r = Invoke-Hook 'away-precheck.ps1' (New-ApJson 'ap-chain' '퇴근한다')
Assert-Case -Name "away-precheck: chain-plan 기록만 있어도 주입한다" -R (Get-ApContext $r) -ExpectContains 'ctx=[karina 부재 예고]'

Set-Content -LiteralPath (Join-Path $apLoop 'ap-impl.active') -Value @((Get-Date -Format o), '') -Encoding UTF8
$r = Invoke-Hook 'away-precheck.ps1' (New-ApJson 'ap-impl' '퇴근한다')
Assert-Case -Name "away-precheck: implement 루프 마커만 있어도 주입한다" -R (Get-ApContext $r) -ExpectContains 'ctx=[karina 부재 예고]'

$r = Invoke-Hook 'away-precheck.ps1' (New-ApJson 'ap-none' '퇴근한다')
Assert-Case -Name "away-precheck: 스킬 상태가 없으면 부재 문구에도 무출력" -R $r -ExpectExit 0 -ExpectSilent $true
Set-ApWorkStart 'ap-other' '{"reflect":"2026-11-26 11:45"}'
$r = Invoke-Hook 'away-precheck.ps1' (New-ApJson 'ap-other' '퇴근한다')
Assert-Case -Name "away-precheck: plan·chain-plan 밖 기록만 있으면 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

$r = Invoke-Hook 'away-precheck.ps1' 'not json'
Assert-Case -Name "away-precheck: 깨진 stdin 은 exit 0 무출력" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'away-precheck.ps1' (@{ hook_event_name = 'UserPromptSubmit'; prompt = '퇴근한다' } | ConvertTo-Json -Compress)
Assert-Case -Name "away-precheck: session_id 가 없으면 exit 0 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

$apHooks = Get-Content -LiteralPath (Join-Path $pluginRoot 'hooks/hooks.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$apBlocks = @($apHooks.hooks.UserPromptSubmit | Where-Object { ($_.hooks.command -join ' ') -match 'away-precheck\.ps1' })
Assert-Case -Name "away-precheck: UserPromptSubmit 블록 하나가 이 스크립트를 부른다" -R @{ code = 0; out = "blocks=$($apBlocks.Count)" } -ExpectContains 'blocks=1'

}
