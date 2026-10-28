# scenarios/screen-cover.ps1 — screen-cover 시나리오 (dot-source 전용, 단독 실행 금지)
# 호출자(run-hook-evals.ps1)의 공용 헬퍼(Assert-Case)와 공유 변수($pluginRoot·$work)를 그대로 쓴다.
# 무엇을 재는가: 화면 가리기 보유 헬퍼(skills/implement/scripts/screen-cover.ps1)의 갈래마다 한 케이스 —
#   가려진 모니터만 끔 · 기록한 것만 켬(원래 꺼짐 보존) · 재 pause 가 사용자가 다시 켠 모니터를 더함 · 보유자 둘 ·
#   처음부터 꺼짐 · CLI 없음 · pause 때 앱 꺼짐 세 형태 · 낡은 보유자 · 상태 없는 resume · 켜기 실패 ·
#   resume 때 앱 꺼짐 세 형태(보유자 둘) · 끄기 부분 실패 · 잠금 시한. 코드와 뜻의 정본은 스크립트 머리 주석이다.
# 실제 Karina 앱은 끄고 켤 수 없어 가짜 CLI(모니터 상태 JSON 을 읽고 쓰는 pwsh 스크립트)를 -CliCommand 로 넘긴다.
#   가짜의 monitor 와 displayNumber 를 일부러 다르게 두어, 스크립트가 엉뚱한 번호를 넘기면 다른 모니터가 바뀐다.
# 대상은 hook 이 아니라 스킬 로컬 헬퍼라 `Invoke-Hook` 을 쓰지 않고 인자를 넘기는 자식 pwsh 를 직접 띄운다.
if (Test-HookSelected @('screen-cover')) {

$scPath = Join-Path $pluginRoot 'skills/implement/scripts/screen-cover.ps1'
$scRoot = Join-Path $work 'screen-cover'
New-Item -ItemType Directory -Path $scRoot -Force | Out-Null
$scSeq = 0

$scFake = Join-Path $scRoot 'fake-cli.ps1'
Set-Content -LiteralPath $scFake -Encoding UTF8 -Value @'
$d = $env:FAKE_COVER_DIR
Add-Content -LiteralPath (Join-Path $d 'calls.log') -Value ($args -join ' ')
$mode = 'on'
$appFile = Join-Path $d 'app.txt'
if (Test-Path -LiteralPath $appFile) { $mode = (Get-Content -LiteralPath $appFile -Raw).Trim() }
$mons = @(Get-Content -LiteralPath (Join-Path $d 'monitors.json') -Raw | ConvertFrom-Json)
function Out-Fake($obj, [int]$code) { Write-Output (ConvertTo-Json -InputObject $obj -Depth 6 -Compress); exit $code }
if ($args[0] -eq 'status') {
    Out-Fake @{ ok = $true; result = @{ appRunning = ($mode -ne 'off-norunning') } } 0
}
if ($args[0] -ne 'cover') { Out-Fake @{ ok = $false; error = @{ code = 'unknown' } } 2 }
if ($mode -eq 'off-okfalse') { Out-Fake @{ ok = $false; error = @{ code = 'app_not_running' } } 0 }
if ($mode -eq 'off-exit') { Out-Fake @{ ok = $false; error = @{ code = 'app_not_running' } } 3 }
if ($args[1] -eq 'status') { Out-Fake @{ ok = $true; result = @{ monitors = $mons } } 0 }
$n = [int]$args[3]
$failFile = Join-Path $d ('fail-' + $args[1] + '.txt')
if ((Test-Path -LiteralPath $failFile) -and ((Get-Content -LiteralPath $failFile -Raw).Trim() -eq "$n")) {
    Out-Fake @{ ok = $false; error = @{ code = 'runtime_error' } } 1
}
foreach ($m in $mons) { if ($m.monitor -eq $n) { $m.covered = ($args[1] -eq 'on') } }
Set-Content -LiteralPath (Join-Path $d 'monitors.json') -Value (ConvertTo-Json -InputObject $mons -Depth 6)
Out-Fake @{ ok = $true; result = @{ monitors = $mons } } 0
'@

function New-CoverRig([int[]]$Covered) {
    $script:scSeq++
    $d = Join-Path $scRoot ('r' + $script:scSeq)
    New-Item -ItemType Directory -Path (Join-Path $d 'state') -Force | Out-Null
    $mons = @(
        [pscustomobject]@{ monitor = 1; displayNumber = 1; covered = ($Covered -contains 1) }
        [pscustomobject]@{ monitor = 2; displayNumber = 4; covered = ($Covered -contains 2) }
        [pscustomobject]@{ monitor = 3; displayNumber = 3; covered = ($Covered -contains 3) }
        [pscustomobject]@{ monitor = 4; displayNumber = 2; covered = ($Covered -contains 4) }
    )
    Set-Content -LiteralPath (Join-Path $d 'monitors.json') -Value (ConvertTo-Json -InputObject $mons -Depth 6)
    return $d
}
function Set-CoverRigFile($d, [string]$Name, [string]$Value) {
    Set-Content -LiteralPath (Join-Path $d $Name) -Value $Value
}
function Get-CoveredList($d) {
    $mons = @(Get-Content -LiteralPath (Join-Path $d 'monitors.json') -Raw | ConvertFrom-Json)
    return (@($mons | Where-Object { $_.covered } | ForEach-Object { $_.monitor }) -join ',')
}
function Invoke-ScreenCover($d, [string[]]$CoverArgs, [string]$Cli = $scFake) {
    Assert-EvalParentAlive
    $env:FAKE_COVER_DIR = $d
    $out = pwsh -NoProfile -ExecutionPolicy Bypass -File $scPath @CoverArgs -CliCommand $Cli -StateDir (Join-Path $d 'state') 2>&1
    $code = $LASTEXITCODE
    $env:FAKE_COVER_DIR = $null
    return @{ code = $code; out = (($out | Out-String)).Trim() }
}
# 출력과 모니터 상태를 한 문자열로 묶어 한 케이스에서 둘 다 단언한다
function Join-CoverResult($r, $d) {
    return @{ code = $r.code; out = ($r.out + ' [covered=' + (Get-CoveredList $d) + ']') }
}

# ---- ①② 가려진 모니터만 끄고, 기록한 것만 켠다 ----
$d = New-CoverRig @(2, 3)
$r = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'a')
Assert-Case -Name "screen-cover: pause 는 가려진 모니터만 monitor 번호로 끈다" -R (Join-CoverResult $r $d) -ExpectExit 0 -ExpectContains 'karina-cover paused 2,3 [covered=]'
$r = Invoke-ScreenCover $d @('-Action', 'resume', '-Holder', 'a')
Assert-Case -Name "screen-cover: resume 은 기록한 모니터만 켜고 원래 꺼진 모니터는 그대로 둔다" -R (Join-CoverResult $r $d) -ExpectExit 0 -ExpectContains 'karina-cover restored 2,3 [covered=2,3]'

# ---- ③ 같은 보유자 재 pause — 그 사이 사용자가 켠 모니터도 끄고 기록에 더한다 ----
$d = New-CoverRig @(1)
$null = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'a')
$mons = @(Get-Content -LiteralPath (Join-Path $d 'monitors.json') -Raw | ConvertFrom-Json)
foreach ($m in $mons) { if ($m.monitor -eq 4) { $m.covered = $true } }
Set-Content -LiteralPath (Join-Path $d 'monitors.json') -Value (ConvertTo-Json -InputObject $mons -Depth 6)
$null = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'a')
$r = Invoke-ScreenCover $d @('-Action', 'resume', '-Holder', 'a')
Assert-Case -Name "screen-cover: 재 pause 가 사용자가 다시 켠 모니터를 끄고 resume 이 둘 다 켠다" -R (Join-CoverResult $r $d) -ExpectExit 0 -ExpectContains 'karina-cover restored 1,4 [covered=1,4]'

# ---- ④ 보유자 둘 — 마지막 보유자가 끝날 때만 켠다 ----
$d = New-CoverRig @(1)
$null = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'a')
$null = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'b')
$r = Invoke-ScreenCover $d @('-Action', 'resume', '-Holder', 'a')
Assert-Case -Name "screen-cover: 다른 보유자가 남으면 resume 은 켜지 않는다" -R (Join-CoverResult $r $d) -ExpectExit 0 -ExpectContains 'karina-cover held 1 [covered=]'
$r = Invoke-ScreenCover $d @('-Action', 'resume', '-Holder', 'b')
Assert-Case -Name "screen-cover: 마지막 보유자의 resume 이 켠다" -R (Join-CoverResult $r $d) -ExpectExit 0 -ExpectContains 'karina-cover restored 1 [covered=1]'

# ---- ⑤ 처음부터 모두 꺼짐 (음성 짝) ----
$d = New-CoverRig @()
$r = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'a')
Assert-Case -Name "screen-cover: 가려진 모니터가 없으면 pause 는 아무것도 끄지 않는다" -R (Join-CoverResult $r $d) -ExpectExit 0 -ExpectContains 'karina-cover paused none [covered=]'
$r = Invoke-ScreenCover $d @('-Action', 'resume', '-Holder', 'a')
$calls = Get-Content -LiteralPath (Join-Path $d 'calls.log') -Raw
Assert-Case -Name "screen-cover: 원래 꺼져 있던 모니터는 resume 이 켜지 않는다" -R @{ code = $r.code; out = ($r.out + ' ' + $calls) } -ExpectExit 0 -ExpectContains 'karina-cover restored none' -ExpectNotContains 'cover on'

# ---- ⑥ CLI 없음 (음성 짝) ----
$d = New-CoverRig @(1)
$r = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'a') -Cli (Join-Path $scRoot 'no-such-cli.exe')
Assert-Case -Name "screen-cover: CLI 가 없으면 건너뛰고 exit 0" -R (Join-CoverResult $r $d) -ExpectExit 0 -ExpectContains 'karina-cover skip no-cli [covered=1]'

# ---- ⑦ pause 때 앱 꺼짐 세 형태 (음성 짝) ----
foreach ($form in @('off-okfalse', 'off-exit', 'off-norunning')) {
    $d = New-CoverRig @(1)
    Set-CoverRigFile $d 'app.txt' $form
    $r = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'a')
    $stateNote = if (Test-Path -LiteralPath (Join-Path $d 'state/cover-state.json')) { ' state-exists' } else { ' state-none' }
    Assert-Case -Name "screen-cover: pause 때 앱이 꺼져 있으면($form) 상태를 남기지 않고 건너뛴다" -R @{ code = $r.code; out = ($r.out + $stateNote) } -ExpectExit 0 -ExpectContains 'karina-cover skip app-off state-none'
}

# ---- ⑧ 낡은 보유자는 무시한다 ----
$d = New-CoverRig @(1)
$null = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'old', '-Now', '2026-10-27 00:00')
$null = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'new', '-Now', '2026-10-28 16:00')
$r = Invoke-ScreenCover $d @('-Action', 'resume', '-Holder', 'new', '-Now', '2026-10-28 16:00')
Assert-Case -Name "screen-cover: 기한이 지난 보유자는 남은 보유자로 세지 않는다" -R (Join-CoverResult $r $d) -ExpectExit 0 -ExpectContains 'karina-cover restored 1 [covered=1]'

# ---- ⑨ 상태 없이 resume (음성 짝) ----
$d = New-CoverRig @(2)
$r = Invoke-ScreenCover $d @('-Action', 'resume', '-Holder', 'a')
Assert-Case -Name "screen-cover: 기록 없이 resume 하면 아무것도 켜지 않는다" -R (Join-CoverResult $r $d) -ExpectExit 0 -ExpectContains 'karina-cover restored none [covered=2]'

# ---- ⑩ 켜기 실패 — ERROR 와 기록 유지 ----
$d = New-CoverRig @(1, 2)
$null = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'a')
Set-CoverRigFile $d 'fail-on.txt' '2'
$r = Invoke-ScreenCover $d @('-Action', 'resume', '-Holder', 'a')
Assert-Case -Name "screen-cover: 켜기가 실패하면 ERROR 와 exit 1" -R (Join-CoverResult $r $d) -ExpectExit 1 -ExpectContains 'karina-cover ERROR'
Set-CoverRigFile $d 'fail-on.txt' ''
$r = Invoke-ScreenCover $d @('-Action', 'resume', '-Holder', 'a')
Assert-Case -Name "screen-cover: 켜지 못한 모니터는 기록에 남아 다음 resume 이 켠다" -R (Join-CoverResult $r $d) -ExpectExit 0 -ExpectContains 'karina-cover restored 2 [covered=1,2]'

# ---- ⑪ resume 때 앱 꺼짐 세 형태 — 보유자 둘이어도 기록을 지워 나중에 켜지 않는다 ----
foreach ($form in @('off-okfalse', 'off-exit', 'off-norunning')) {
    $d = New-CoverRig @(1)
    $null = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'a')
    $null = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'b')
    Set-CoverRigFile $d 'app.txt' $form
    $r1 = Invoke-ScreenCover $d @('-Action', 'resume', '-Holder', 'a')
    Set-CoverRigFile $d 'app.txt' 'on'
    $r2 = Invoke-ScreenCover $d @('-Action', 'resume', '-Holder', 'b')
    Assert-Case -Name "screen-cover: resume 때 앱이 꺼져 있으면($form) 기록을 지워 남은 보유자도 켜지 않는다" -R (Join-CoverResult @{ code = $r2.code; out = ($r1.out + ' / ' + $r2.out) } $d) -ExpectExit 0 -ExpectContains 'karina-cover skip app-off / karina-cover restored none [covered=]'
}

# ---- ⑫ 끄기 부분 실패 — 끈 모니터는 기록돼 resume 이 켠다 ----
$d = New-CoverRig @(1, 2)
Set-CoverRigFile $d 'fail-off.txt' '2'
$r = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'a')
Assert-Case -Name "screen-cover: 끄기가 중간에 실패하면 ERROR 와 exit 1" -R (Join-CoverResult $r $d) -ExpectExit 1 -ExpectContains 'karina-cover ERROR'
$r = Invoke-ScreenCover $d @('-Action', 'resume', '-Holder', 'a')
Assert-Case -Name "screen-cover: 실패 전에 끈 모니터만 resume 이 켠다" -R (Join-CoverResult $r $d) -ExpectExit 0 -ExpectContains 'karina-cover restored 1 [covered=1,2]'

# ---- ⑬ 잠금을 다른 프로세스가 쥐면 시한 안에 ERROR ----
$d = New-CoverRig @(1)
$lockStream = [System.IO.File]::Open((Join-Path $d 'state/cover.lock'), 'OpenOrCreate', 'ReadWrite', 'None')
try {
    $r = Invoke-ScreenCover $d @('-Action', 'pause', '-Holder', 'a', '-LockTimeoutSec', '1')
} finally {
    $lockStream.Dispose()
}
Assert-Case -Name "screen-cover: 잠금을 못 얻으면 시한 안에 ERROR 로 끝나고 아무것도 끄지 않는다" -R (Join-CoverResult $r $d) -ExpectExit 1 -ExpectContains 'karina-cover ERROR lock-timeout [covered=1]'

}
