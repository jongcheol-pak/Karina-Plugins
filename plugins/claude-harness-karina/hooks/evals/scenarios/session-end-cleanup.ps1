# scenarios/session-end-cleanup.ps1 — 고아 콘솔 프로세스 회수 시나리오 (dot-source 전용, 단독 실행 금지)
# 호출자(run-hook-evals.ps1)의 공용 헬퍼(Assert-Case·Invoke-Hook)와 공유 변수($work·$iso)를 그대로 쓴다.
#
# 다른 시나리오와 다른 점: 이 시나리오는 hook에 stdin을 주입하는 대신 **헬퍼 함수를 직접 호출**한다.
#   회수 로직의 검증 대상이 판정(어떤 프로세스를 고아로 볼 것인가)이고, 그것은 실제 프로세스 없이
#   목 레코드로 닫히기 때문이다. **실제 프로세스를 만들지 않는다** — 프로세스는 격리 대상이 아니라
#   스위트가 실기계 상태에 의존하는 순간 결정성이 깨진다(eval-common이 수집 경로를 억제하는 것과 같은 이유).
#   SessionEnd hook만 stdin 주입으로 검증한다(그쪽은 hook 계약 확인이라 Invoke-Hook이 맞다).
if (Test-HookSelected @('session-end-cleanup')) {

# 경로는 eval-common이 계산해 둔 공유 변수를 쓴다 — 여기서 상대 순회로 재계산하면
# 디렉터리 구조가 바뀔 때 이 시나리오만 조용히 깨진다(다른 시나리오도 $scriptsDir를 쓴다).
. (Join-Path $scriptsDir 'session-end-cleanup-lib.ps1')

$opcNow = Get-Date
$opcSid = (Get-Process -Id $PID).SessionId

# ---- 판정 8종 (Select-OrphanProcesses — 순수 함수) ----
# ParentStartTime = $null 이 부모 부재(고아)를 뜻한다. 부모 조회 실패도 보수적으로 여기로 온다.
$opcMock = @(
    @{ Id=201; Name='more.com';    SessionId=$opcSid;     StartTime=$opcNow.AddMinutes(-10); ParentId=8001; ParentStartTime=$null;                    CpuSec=100 }  # 고아 more.com
    @{ Id=202; Name='find.exe';    SessionId=$opcSid;     StartTime=$opcNow.AddMinutes(-10); ParentId=8002; ParentStartTime=$null;                    CpuSec=200 }  # 고아 find.exe
    @{ Id=203; Name='find.exe';    SessionId=$opcSid;     StartTime=$opcNow.AddMinutes(-10); ParentId=8003; ParentStartTime=$opcNow.AddMinutes(-30);  CpuSec=0   }  # 부모 생존
    @{ Id=204; Name='more.com';    SessionId=$opcSid;     StartTime=$opcNow.AddMinutes(-10); ParentId=8004; ParentStartTime=$opcNow.AddMinutes(-2);   CpuSec=50  }  # PID 재사용
    @{ Id=205; Name='more.com';    SessionId=$opcSid + 7; StartTime=$opcNow.AddMinutes(-10); ParentId=8005; ParentStartTime=$null;                    CpuSec=0   }  # 타 세션
    @{ Id=206; Name='notepad.exe'; SessionId=$opcSid;     StartTime=$opcNow.AddMinutes(-10); ParentId=8006; ParentStartTime=$null;                    CpuSec=0   }  # 대상 아닌 이름
)
$opcSel = @(Select-OrphanProcesses -Records $opcMock -SessionId $opcSid)
$opcGot = (($opcSel | ForEach-Object { $_.Id }) | Sort-Object) -join ','
Assert-Case -Name "orphan-cleanup: 고아·PID재사용만 선택(두 이름 혼재)" `
    -R @{ code = 0; out = $opcGot } -ExpectExit 0 -ExpectContains '201,202,204'
Assert-Case -Name "orphan-cleanup: 부모 생존·타 세션·대상 외 이름은 제외" `
    -R @{ code = 0; out = $opcGot } -ExpectExit 0 -ExpectNotContains '203'

$opcEmpty = @(Select-OrphanProcesses -Records @() -SessionId $opcSid)
Assert-Case -Name "orphan-cleanup: 빈 입력 → 0건" `
    -R @{ code = 0; out = "count=$($opcEmpty.Count)" } -ExpectExit 0 -ExpectContains 'count=0'
$opcNull = @(Select-OrphanProcesses -Records $null -SessionId $opcSid)
Assert-Case -Name "orphan-cleanup: null 입력 → 0건" `
    -R @{ code = 0; out = "count=$($opcNull.Count)" } -ExpectExit 0 -ExpectContains 'count=0'

# ---- 억제 (D11) — 실기계 수집 경로만 멈추고 주입은 통과 ----
# eval-common이 CLAUDE_HARNESS_NO_PROC_CLEANUP=1을 세워 둔 상태가 이 스위트의 기본값이다.
$opcSup = Invoke-OrphanProcessCleanup -Hook 'golden-suppress'
Assert-Case -Name "orphan-cleanup: 억제 시 수집 경로 즉시 반환" `
    -R @{ code = 0; out = "suppressed=$($opcSup.Suppressed) scanned=$($opcSup.Scanned)" } `
    -ExpectExit 0 -ExpectContains 'suppressed=True scanned=0'

# ---- 주입 + DryRun (D15) — 회수 카운트와 이벤트 적재 ----
$opcBoot = Get-Date -Year 2026 -Month 11 -Day 8 -Hour 21 -Minute 19 -Second 7 -Millisecond 0
function New-OpcProc([int]$Id, [string]$Name, [int]$Sid, $Created, [int]$ParentId) {
    [pscustomobject]@{ ProcessId = $Id; Name = $Name; SessionId = $Sid; CreationDate = $Created; ParentProcessId = $ParentId; KernelModeTime = 0; UserModeTime = 0 }
}
$opcSysProc = New-OpcProc 4 'System' 0 $opcBoot 0
$opcProcs = @($opcSysProc)
foreach ($r in $opcMock) {
    $opcProcs += New-OpcProc $r.Id $r.Name $r.SessionId $r.StartTime $r.ParentId
    if ($null -ne $r.ParentStartTime) { $opcProcs += New-OpcProc $r.ParentId 'parent.exe' $r.SessionId $r.ParentStartTime 0 }
}
$opcStateDir = Join-Path $iso '.claude/.state'
function Clear-OpcState {
    foreach ($d in @('orphan-unkillable', 'orphan-pending')) {
        $p = Join-Path $opcStateDir $d
        if (Test-Path -LiteralPath $p) { Get-ChildItem -LiteralPath $p -Force | Remove-Item -Force -ErrorAction SilentlyContinue }
    }
}
function Get-OpcCount([string]$Dir, [string]$Filter = '*') {
    $p = Join-Path $opcStateDir $Dir
    if (-not (Test-Path -LiteralPath $p)) { return 0 }
    return @(Get-ChildItem -LiteralPath $p -File -Filter $Filter -ErrorAction SilentlyContinue).Count
}

$opcSnap = ConvertTo-OrphanSnapshot -Processes $opcProcs
$opcSnapSel = (@(Select-OrphanProcesses -Records $opcSnap.Records -SessionId $opcSid) | ForEach-Object { $_.Id } | Sort-Object) -join ','
Assert-Case -Name "orphan-cleanup: 목록 변환 — 부모가 목록에 없으면 고아" `
    -R @{ code = 0; out = "sel=$opcSnapSel" } -ExpectExit 0 -ExpectContains '201,202'
Assert-Case -Name "orphan-cleanup: 목록 변환 — 먼저 생긴 부모가 목록에 있으면 제외" `
    -R @{ code = 0; out = "sel=$opcSnapSel" } -ExpectExit 0 -ExpectNotContains '203'
Assert-Case -Name "orphan-cleanup: 목록 변환 — 자식보다 늦게 생긴 부모는 PID 재사용(고아)" `
    -R @{ code = 0; out = "sel=$opcSnapSel" } -ExpectExit 0 -ExpectContains '204'
Assert-Case -Name "orphan-cleanup: 목록 변환 — PID 4 생성시각이 부팅 표지" `
    -R @{ code = 0; out = "boot=$($opcSnap.BootStamp)" } -ExpectExit 0 -ExpectContains 'boot=20261108211907'

Assert-Case -Name "orphan-cleanup: 대기 기록이 있으면 선검사 결과와 무관하게 목록 조회" `
    -R @{ code = 0; out = "need=$(Test-OrphanScanNeeded -PendingCount 1 -PreScanCount 0)" } -ExpectExit 0 -ExpectContains 'need=True'
Assert-Case -Name "orphan-cleanup: 대기 기록도 선검사 대상도 없으면 목록 조회 안 함" `
    -R @{ code = 0; out = "need=$(Test-OrphanScanNeeded -PendingCount 0 -PreScanCount 0)" } -ExpectExit 0 -ExpectContains 'need=False'

Clear-OpcState
$opcDry = Invoke-OrphanProcessCleanup -Hook 'golden-dry' -Processes $opcProcs -DryRun
Assert-Case -Name "orphan-cleanup: 억제 중에도 주입 경로는 동작(회수 3건)" `
    -R @{ code = 0; out = "suppressed=$($opcDry.Suppressed) killed=$($opcDry.Killed)" } `
    -ExpectExit 0 -ExpectContains 'suppressed=False killed=3'

# 적재는 격리 홈($iso)의 hook-events jsonl에 쌓인다 — DryRun은 rule을 분리해 실회수 기록과 섞이지 않는다.
$opcLogDir = Join-Path $iso '.claude/.state/hook-events'
$opcLines = @()
if (Test-Path -LiteralPath $opcLogDir) {
    $opcLines = @(Get-ChildItem -LiteralPath $opcLogDir -Filter '*.jsonl' -ErrorAction SilentlyContinue |
        ForEach-Object { Get-Content -LiteralPath $_.FullName -Encoding UTF8 })
}
$opcDryCount = @($opcLines | Where-Object { $_ -match 'orphan-process-dryrun' -and $_ -match 'golden-dry' }).Count
Assert-Case -Name "orphan-cleanup: DryRun 이벤트가 회수 건수만큼 적재" `
    -R @{ code = 0; out = "dry=$opcDryCount" } -ExpectExit 0 -ExpectContains 'dry=3'
$opcHookOk = @($opcLines | Where-Object { $_ -match '"hook"\s*:\s*"golden-dry"' }).Count
Assert-Case -Name "orphan-cleanup: hook 필드가 비지 않음(리포트에서 버려지지 않는다)" `
    -R @{ code = 0; out = "hook=$opcHookOk" } -ExpectExit 0 -ExpectContains 'hook=3'

# ---- Unkillable 계상 + 마커 (D18) ----
Clear-OpcState
$opcDead = @((New-OpcProc 4 'find.exe' $opcSid $opcBoot 9999))
$opcUn1 = Invoke-OrphanProcessCleanup -Hook 'golden-unkill' -Processes $opcDead
Assert-Case -Name "orphan-cleanup: kill 요청은 같은 회수에서 판정하지 않고 대기로 남긴다" `
    -R @{ code = 0; out = "requested=$($opcUn1.Requested) killed=$($opcUn1.Killed) unkillable=$($opcUn1.Unkillable) pending=$(Get-OpcCount 'orphan-pending')" } `
    -ExpectExit 0 -ExpectContains 'requested=1 killed=0 unkillable=0 pending=1'

$opcUn2 = Invoke-OrphanProcessCleanup -Hook 'golden-unkill' -Processes $opcDead
Assert-Case -Name "orphan-cleanup: 다음 회수 목록에 같은 생성시각으로 남으면 Unkillable·마커" `
    -R @{ code = 0; out = "requested=$($opcUn2.Requested) killed=$($opcUn2.Killed) unkillable=$($opcUn2.Unkillable) marker=$(Get-OpcCount 'orphan-unkillable') pending=$(Get-OpcCount 'orphan-pending')" } `
    -ExpectExit 0 -ExpectContains 'requested=0 killed=0 unkillable=1 marker=1 pending=0'

$opcUn3 = Invoke-OrphanProcessCleanup -Hook 'golden-unkill' -Processes $opcDead
Assert-Case -Name "orphan-cleanup: 마커 이후 재시도 억제" `
    -R @{ code = 0; out = "requested=$($opcUn3.Requested) unkillable=$($opcUn3.Unkillable) pending=$(Get-OpcCount 'orphan-pending')" } `
    -ExpectExit 0 -ExpectContains 'requested=0 unkillable=0 pending=0'

Clear-OpcState
$opcGhost = New-OpcProc 2147483000 'more.com' $opcSid $opcBoot.AddDays(1) 999999
$opcG1 = Invoke-OrphanProcessCleanup -Hook 'golden-pending' -Processes @($opcSysProc, $opcGhost)
$opcG2 = Invoke-OrphanProcessCleanup -Hook 'golden-pending' -Processes @($opcSysProc)
$opcLogDir2 = Join-Path $iso '.claude/.state/hook-events'
$opcPendEv = @(Get-ChildItem -LiteralPath $opcLogDir2 -Filter '*.jsonl' -ErrorAction SilentlyContinue |
    ForEach-Object { Get-Content -LiteralPath $_.FullName -Encoding UTF8 } |
    Where-Object { $_ -match '"hook"\s*:\s*"golden-pending"' -and $_ -match '"rule"\s*:\s*"orphan-process"' -and $_ -match 'pid=2147483000' }).Count
Assert-Case -Name "orphan-cleanup: 다음 회수 목록에서 사라졌으면 Killed·이벤트" `
    -R @{ code = 0; out = "req1=$($opcG1.Requested) killed=$($opcG2.Killed) ev=$opcPendEv pending=$(Get-OpcCount 'orphan-pending')" } `
    -ExpectExit 0 -ExpectContains 'req1=1 killed=1 ev=1 pending=0'
Assert-Case -Name "orphan-cleanup: 대상 이름이 없는 목록에서도 대기 판정이 먼저 돈다" `
    -R @{ code = 0; out = "scanned=$($opcG2.Scanned) killed=$($opcG2.Killed)" } `
    -ExpectExit 0 -ExpectContains 'scanned=0 killed=1'

Clear-OpcState
$opcClaimGhost = New-OpcProc 2147483002 'more.com' $opcSid $opcBoot.AddDays(1) 999999
$null = Invoke-OrphanProcessCleanup -Hook 'golden-claim' -Processes @($opcSysProc, $opcClaimGhost)
Get-ChildItem -LiteralPath (Join-Path $opcStateDir 'orphan-pending') -File | ForEach-Object { Rename-Item -LiteralPath $_.FullName -NewName ($_.Name + '.claim') }
$opcC2 = Invoke-OrphanProcessCleanup -Hook 'golden-claim' -Processes @($opcSysProc)
Assert-Case -Name "orphan-cleanup: 다른 회수가 선점(.claim)한 대기 기록은 판정하지 않는다" `
    -R @{ code = 0; out = "killed=$($opcC2.Killed) claim=$(Get-OpcCount 'orphan-pending' '*.claim')" } `
    -ExpectExit 0 -ExpectContains 'killed=0 claim=1'

Clear-OpcState
$opcFailGhost = New-OpcProc 2147483003 'more.com' $opcSid $opcBoot.AddDays(1) 999999
$null = Invoke-OrphanProcessCleanup -Hook 'golden-fail' -Processes @($opcSysProc, $opcFailGhost)
$opcF2 = Invoke-OrphanProcessCleanup -Hook 'golden-fail' -Processes @($opcSysProc) -SnapshotFailed
Assert-Case -Name "orphan-cleanup: 목록 조회가 실패하면 대기 기록을 판정하지 않고 남긴다" `
    -R @{ code = 0; out = "killed=$($opcF2.Killed) pending=$(Get-OpcCount 'orphan-pending')" } `
    -ExpectExit 0 -ExpectContains 'killed=0 pending=1'
Clear-OpcState

$opcBudgetCand = Get-OrphanProcessCandidates -BudgetMs 500
Assert-Case -Name "orphan-cleanup: 남은 예산이 1초 미만이면 목록 조회를 부르지 않는다" `
    -R @{ code = 0; out = "exhausted=$($opcBudgetCand.BudgetExhausted) cim=$($opcBudgetCand.CimCalls)" } `
    -ExpectExit 0 -ExpectContains 'exhausted=True cim=0'

$opcBudgetSaved = $env:KARINA_ORPHAN_CLEANUP_BUDGET_MS
try {
    $env:KARINA_ORPHAN_CLEANUP_BUDGET_MS = '0'
    $opcBudgetGhost = New-OpcProc 2147483001 'more.com' $opcSid $opcBoot.AddDays(1) 999999
    $opcB = Invoke-OrphanProcessCleanup -Hook 'golden-budget' -Processes @($opcSysProc, $opcBudgetGhost)
    Assert-Case -Name "orphan-cleanup: 환경변수 예산 0 이면 kill 요청을 내지 않는다" `
        -R @{ code = 0; out = "requested=$($opcB.Requested) exhausted=$($opcB.BudgetExhausted) pending=$(Get-OpcCount 'orphan-pending')" } `
        -ExpectExit 0 -ExpectContains 'requested=0 exhausted=True pending=0'
} finally {
    $env:KARINA_ORPHAN_CLEANUP_BUDGET_MS = $opcBudgetSaved
    Clear-OpcState
}

# ---- SessionEnd hook 계약 (stdin 주입) ----
# 회수 사실은 이벤트 로그에만 남으므로 이 hook은 어떤 사유로 불려도 무출력·exit 0이어야 한다.
foreach ($opcReason in @('clear', 'logout', 'prompt_input_exit', 'other')) {
    $opcJson = @{ hook_event_name = 'SessionEnd'; session_id = 'golden'; cwd = $work; session_end_reason = $opcReason } | ConvertTo-Json -Compress
    $r = Invoke-Hook 'session-end-cleanup.ps1' $opcJson
    Assert-Case -Name "session-end-cleanup: $opcReason → exit 0 무출력" -R $r -ExpectExit 0 -ExpectSilent $true
}

}
