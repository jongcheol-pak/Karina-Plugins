# session-end-cleanup-lib.ps1 — 고아 콘솔 프로세스 회수 함수 — 근거는 `rules/orphan-cleanup-rationale.md` §1

# 고아 콘솔 프로세스 회수 헬퍼 — 근거는 `rules/orphan-cleanup-rationale.md` §2

# 회수 대상. 실측된 고아가 이 둘뿐이라 목록을 넓히지 않는다 — 근거는 `rules/orphan-cleanup-rationale.md` §3
$script:OrphanTargetNames  = @('more.com', 'find.exe')   # CIM 조회용
$script:OrphanPreScanNames = @('more.com', 'find')       # Get-Process 선검사용(.exe 벗겨짐)

# 골든 스위트는 hook을 실기계에서 돌리는데 프로세스는 격리 대상이 아니다. — 근거는 `rules/orphan-cleanup-rationale.md` §4
$script:OrphanCleanupSuppressVar = 'CLAUDE_HARNESS_NO_PROC_CLEANUP'

try { . (Join-Path $PSScriptRoot 'hook-event-log.ps1') } catch {}

function Get-OrphanStateDir([string]$Leaf) {
    $homeBase = if ([string]::IsNullOrEmpty($env:USERPROFILE)) { $HOME } else { $env:USERPROFILE }
    if ([string]::IsNullOrEmpty($homeBase)) { return $null }
    return (Join-Path $homeBase ('.claude/.state/' + $Leaf))
}

function Get-UnkillableMarkers {
    # 반환: 현재 부팅 세션에서 '죽지 않는다'고 확인된 PID 집합. — 근거는 `rules/orphan-cleanup-rationale.md` §5
    param([string]$BootStamp)
    $set = @{}
    $dir = Get-OrphanStateDir 'orphan-unkillable'
    if (-not $dir -or -not (Test-Path -LiteralPath $dir -ErrorAction SilentlyContinue)) { return $set }
    try {
        $cutoff = (Get-Date).AddDays(-30)
        foreach ($f in @(Get-ChildItem -LiteralPath $dir -File -ErrorAction Stop)) {
            $parts = $f.Name -split '_'
            $stale = ($f.LastWriteTime -lt $cutoff) -or
                     ($parts.Count -ne 2) -or
                     ($BootStamp -and $parts[1] -ne $BootStamp)
            if ($stale) {
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
                continue
            }
            $set[$parts[0]] = $true
        }
    } catch {}
    return $set
}

function Add-UnkillableMarker {
    param([int]$ProcessId, [string]$BootStamp)
    if (-not $BootStamp) { return }   # 부팅 시각을 못 얻으면 마커 기능만 생략(회수 자체는 정상 진행)
    $dir = Get-OrphanStateDir 'orphan-unkillable'
    if (-not $dir) { return }
    try {
        if (-not (Test-Path -LiteralPath $dir -ErrorAction SilentlyContinue)) {
            New-Item -ItemType Directory -Path $dir -Force -ErrorAction SilentlyContinue | Out-Null
        }
        New-Item -ItemType File -Path (Join-Path $dir ("$ProcessId" + '_' + $BootStamp)) -Force -ErrorAction SilentlyContinue | Out-Null
    } catch {}
}

function Select-OrphanProcesses {
    <#
      순수 판정 — 프로세스 레코드 배열에서 회수 대상만 골라 반환한다.
      레코드: @{ Id; Name; SessionId; StartTime; ParentId; ParentStartTime }
        ParentStartTime = $null 이면 부모 부재(고아).
      판정: 대상 이름 AND 세션 일치 AND (부모 부재 OR 부모가 자식보다 나중에 생성됨).
      마지막 조건이 PID 재사용 방어다 — 죽은 부모의 PID가 재할당되면 '부모 생존'으로 오판해
      영영 회수되지 않는다.
    #>
    param(
        [object[]]$Records,
        [int]$SessionId,
        [hashtable]$SkipPids = $null
    )
    $out = New-Object System.Collections.Generic.List[object]
    if (-not $Records) { return @() }
    foreach ($r in $Records) {
        if ($null -eq $r) { continue }
        if (-not ($script:OrphanTargetNames -contains ([string]$r.Name).ToLowerInvariant())) { continue }
        if ([int]$r.SessionId -ne $SessionId) { continue }
        if ($SkipPids -and $SkipPids.ContainsKey([string]$r.Id)) { continue }
        $orphan = $false
        if ($null -eq $r.ParentStartTime) {
            $orphan = $true                                   # 부모 부재 — 조회 실패도 여기로 온다(보수적)
        } elseif ($r.ParentStartTime -gt $r.StartTime) {
            $orphan = $true                                   # 부모 PID가 재사용됨
        }
        if ($orphan) { $out.Add($r) }
    }
    return $out.ToArray()
}

function ConvertTo-OrphanSnapshot {
    param([object[]]$Processes)
    $created = @{}
    $boot = $null
    foreach ($p in @($Processes)) {
        if ($null -eq $p -or $null -eq $p.CreationDate) { continue }
        $at = [datetime]$p.CreationDate
        $created[[string]$p.ProcessId] = $at
        if ([int]$p.ProcessId -eq 4) { $boot = $at.ToString('yyyyMMddHHmmss') }
    }
    $records = New-Object System.Collections.Generic.List[object]
    foreach ($p in @($Processes)) {
        if ($null -eq $p -or $null -eq $p.CreationDate) { continue }
        $name = ([string]$p.Name).ToLowerInvariant()
        if (-not ($script:OrphanTargetNames -contains $name)) { continue }
        $parentKey = [string]$p.ParentProcessId
        $records.Add(@{
            Id              = [int]$p.ProcessId
            Name            = $name
            SessionId       = [int]$p.SessionId
            StartTime       = [datetime]$p.CreationDate
            ParentId        = [int]$p.ParentProcessId
            ParentStartTime = $(if ($created.ContainsKey($parentKey)) { $created[$parentKey] } else { $null })
            CpuSec          = [math]::Round(([double]$p.KernelModeTime + [double]$p.UserModeTime) / 10000000, 0)
        })
    }
    return @{ Records = $records.ToArray(); Created = $created; BootStamp = $boot }
}

function Test-OrphanScanNeeded {
    param([int]$PendingCount, [int]$PreScanCount)
    return ($PendingCount -gt 0 -or $PreScanCount -gt 0)
}

function Get-OrphanCleanupBudgetMs {
    $raw = 0
    if ([int]::TryParse([string]$env:KARINA_ORPHAN_CLEANUP_BUDGET_MS, [ref]$raw) -and $raw -ge 0) { return $raw }
    return 8000
}

function Get-OrphanProcessCandidates {
    # 예산은 CIM 호출마다 -OperationTimeoutSec 로 건다 — 근거는 `rules/orphan-cleanup-rationale.md` §8
    param([int]$BudgetMs = (Get-OrphanCleanupBudgetMs))
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    $exhausted = @{ Snapshot = $null; CimCalls = 0; Ok = $false; BudgetExhausted = $true }
    if ($BudgetMs - $clock.ElapsedMilliseconds -lt 1000) { return $exhausted }
    $none = @{ Snapshot = $null; CimCalls = 0; Ok = $false; BudgetExhausted = $false }
    $pendingCount = 0
    $pendingDir = Get-OrphanStateDir 'orphan-pending'
    if ($pendingDir -and (Test-Path -LiteralPath $pendingDir)) {
        $pendingCount = @(Get-ChildItem -LiteralPath $pendingDir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notlike '*.claim' }).Count
    }
    $preCount = 0
    if ($pendingCount -eq 0) {
        try { $preCount = @(Get-Process -Name $script:OrphanPreScanNames -ErrorAction SilentlyContinue).Count } catch {}
    }
    if (-not (Test-OrphanScanNeeded -PendingCount $pendingCount -PreScanCount $preCount)) { return $none }

    $timeoutSec = [int][Math]::Floor(($BudgetMs - $clock.ElapsedMilliseconds) / 1000)
    if ($timeoutSec -lt 1) { return $exhausted }
    try {
        $procs = @(Get-CimInstance Win32_Process -Property ProcessId, ParentProcessId, CreationDate, Name, SessionId, KernelModeTime, UserModeTime -OperationTimeoutSec $timeoutSec -ErrorAction Stop)
        return @{ Snapshot = (ConvertTo-OrphanSnapshot -Processes $procs); CimCalls = 1; Ok = $true; BudgetExhausted = $false }
    } catch {
        return @{ Snapshot = $null; CimCalls = 1; Ok = $false; BudgetExhausted = ($clock.ElapsedMilliseconds -ge $BudgetMs) }
    }
}

function Add-OrphanPending {
    param([hashtable]$Target, [string]$BootStamp)
    if (-not $BootStamp) { return }
    $dir = Get-OrphanStateDir 'orphan-pending'
    if (-not $dir) { return }
    try {
        if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force -ErrorAction Stop | Out-Null }
        $name = '{0}_{1}_{2}' -f $Target.Id, ([datetime]$Target.StartTime).Ticks, $BootStamp
        Set-Content -LiteralPath (Join-Path $dir $name) -Value ('name=' + $Target.Name + ' cpuSec=' + $Target.CpuSec) -NoNewline -Encoding UTF8 -ErrorAction Stop
    } catch {}
}

function Resolve-OrphanPending {
    # 지난 회수의 kill 요청을 이번 목록으로 판정한다 — 근거는 `rules/orphan-cleanup-rationale.md` §9
    param([hashtable]$Snapshot, [string]$Hook, [hashtable]$Result)
    $dir = Get-OrphanStateDir 'orphan-pending'
    if (-not $dir -or -not (Test-Path -LiteralPath $dir)) { return }
    $cutoff = (Get-Date).AddDays(-30)
    foreach ($f in @(Get-ChildItem -LiteralPath $dir -File -ErrorAction SilentlyContinue)) {
        $isClaim = $f.Name.EndsWith('.claim')
        $parts = ($f.Name -replace '\.claim$', '') -split '_'
        $stale = ($f.LastWriteTime -lt $cutoff) -or ($parts.Count -ne 3) -or ($parts[2] -ne $Snapshot.BootStamp)
        if ($stale) {
            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction SilentlyContinue
            continue
        }
        if ($isClaim) { continue }
        $claim = $f.FullName + '.claim'
        try { Move-Item -LiteralPath $f.FullName -Destination $claim -ErrorAction Stop } catch { continue }
        $info = [string](Get-Content -LiteralPath $claim -Raw -ErrorAction SilentlyContinue)
        $pidKey = $parts[0]
        $alive = $Snapshot.Created.ContainsKey($pidKey) -and ([string]$Snapshot.Created[$pidKey].Ticks -eq $parts[1])
        if ($alive) {
            $Result.Unkillable++
            Add-UnkillableMarker -ProcessId ([int]$pidKey) -BootStamp $Snapshot.BootStamp
        } else {
            $Result.Killed++
            if ($info -match 'cpuSec=(\d+)') { $Result.CpuSec += [int]$Matches[1] }
            if (Get-Command Write-HookEvent -ErrorAction SilentlyContinue) {
                try { Write-HookEvent -Hook $Hook -Decision 'cleanup' -Rule 'orphan-process' -CommandText ('pid=' + $pidKey + ' ' + $info) } catch {}
            }
        }
        Remove-Item -LiteralPath $claim -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-OrphanProcessCleanup {
    <#
      회수 본체. 화면 출력 없음(안전 계약 ②) — 회수 사실은 hook-event-log에만 적재한다.
        -Hook     적재할 hook 이름. 비면 이벤트 로그의 hook 필드가 비어 어느 hook의 회수였는지
                  사후에 가릴 수 없으므로 호출측이 반드시 준다(골든이 이 필드를 고정한다).
        -Processes 주면 CIM 수집을 건너뛰고 그 프로세스 목록으로 판정한다(골든 검증용 주입 seam).
        -DryRun   Stop-Process를 생략한다. 목 PID가 실재 프로세스와 겹칠 때 무관한 프로세스를
                  죽이는 것을 막는다. 이때 적재 rule을 분리해 실로그 오염도 막는다.
      반환: @{ Suppressed; Scanned; CimQueried; CimCalls; Requested; Killed; Unkillable; CpuSec }
    #>
    param(
        [string]$Hook = 'session-end-cleanup-lib',
        [object[]]$Processes = $null,
        [switch]$SnapshotFailed,
        [switch]$DryRun,
        [int]$BudgetMs = -1
    )
    $result = @{ Suppressed = $false; Scanned = 0; CimQueried = $false; CimCalls = 0; Requested = 0; Killed = 0; Unkillable = 0; CpuSec = 0; BudgetExhausted = $false }
    try {
        # 안전 계약 ②를 이 파일만으로 자기완결시킨다 — 근거는 `rules/orphan-cleanup-rationale.md` §6
        $ErrorActionPreference = 'SilentlyContinue'
        $injected = $PSBoundParameters.ContainsKey('Processes')

        # 억제는 부작용이 있는 실기계 수집 경로에만 건다. 주입은 명시적 테스트 호출이라 대상이 아니다.
        if (-not $injected) {
            $suppress = [Environment]::GetEnvironmentVariable($script:OrphanCleanupSuppressVar)
            if (-not [string]::IsNullOrEmpty($suppress)) {
                $result.Suppressed = $true
                return $result
            }
        }

        $sessionId = 0
        try { $sessionId = (Get-Process -Id $PID -ErrorAction Stop).SessionId } catch {}

        if ($BudgetMs -lt 0) { $BudgetMs = Get-OrphanCleanupBudgetMs }
        $clock = [System.Diagnostics.Stopwatch]::StartNew()
        if ($injected) {
            $cand = @{ Snapshot = (ConvertTo-OrphanSnapshot -Processes $Processes); CimCalls = 0; Ok = (-not $SnapshotFailed); BudgetExhausted = $false }
        } else {
            $cand = Get-OrphanProcessCandidates -BudgetMs $BudgetMs
        }
        $result.BudgetExhausted = [bool]$cand.BudgetExhausted
        $result.CimCalls = [int]$cand.CimCalls
        $result.CimQueried = ($result.CimCalls -gt 0)
        if (-not $cand.Ok -or $null -eq $cand.Snapshot) { return $result }
        $snap = $cand.Snapshot

        # Stop-Process의 성공 반환을 소멸의 근거로 쓰지 않는다 — 근거는 `rules/orphan-cleanup-rationale.md` §7
        if ($snap.BootStamp) { Resolve-OrphanPending -Snapshot $snap -Hook $Hook -Result $result }

        $result.Scanned = @($snap.Records).Count
        if ($result.Scanned -eq 0) { return $result }

        $skip = Get-UnkillableMarkers -BootStamp $snap.BootStamp
        $targets = @(Select-OrphanProcesses -Records $snap.Records -SessionId $sessionId -SkipPids $skip)
        foreach ($t in $targets) {
            if ($DryRun) {
                $result.Killed++
                $result.CpuSec += [int]$t.CpuSec
                if (Get-Command Write-HookEvent -ErrorAction SilentlyContinue) {
                    try {
                        Write-HookEvent -Hook $Hook -Decision 'cleanup' -Rule 'orphan-process-dryrun' `
                            -CommandText ("pid=" + $t.Id + " name=" + $t.Name + " cpuSec=" + $t.CpuSec)
                    } catch {}
                }
                continue
            }
            if ($clock.ElapsedMilliseconds -ge $BudgetMs) {
                $result.BudgetExhausted = $true
                break
            }
            try { Stop-Process -Id $t.Id -Force -ErrorAction Stop } catch {}
            $result.Requested++
            Add-OrphanPending -Target $t -BootStamp $snap.BootStamp
        }
    } catch {}
    return $result
}
