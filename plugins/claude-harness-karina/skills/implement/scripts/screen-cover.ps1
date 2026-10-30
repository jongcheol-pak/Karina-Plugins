# screen-cover.ps1 — 앱 검증 동안 Karina 화면 가리기를 걷고, 단계가 끝나면 걷은 모니터만 다시 덮는다 (모델이 부르는 헬퍼 — hook 아님)
#
# 언제·누가 부르는가는 `skills/SCREEN-COVER.md` 가 정본이다.
#   -Action pause  -Holder <이름>   가려진 모니터를 한 대씩 끄고 즉시 기록한다. 같은 보유자가 다시 불러도 무해하고,
#                                   그 사이 사용자가 다시 켠 모니터도 끄고 기록에 더한다.
#   -Action resume -Holder <이름>   보유자를 지우고, 남은 보유자가 없을 때만 기록한 모니터를 켠다.
# 잠금 방식·꺼짐 판정의 근거는 skills/implement/references/screen-cover-rationale.md
# CLI 선택 순서의 정본은 `karina-cli skills get karina-computer-use` 의 「Preconditions」 다
#   (KARINA_CLI_COMMAND → PATH 의 karina-cli·karina-dev-cli → 설치본 전체경로).
# 왜 출력에 한글이 없는가: Git Bash 를 거친 PowerShell 출력에서 한글이 깨진다(work-clock 과 같다).
param(
    [string]$Action = '',
    [string]$Holder = '',
    [string]$CliCommand = '',
    [string]$StateDir = '',
    [string]$Now = '',
    [double]$StaleHours = 12,
    [double]$LockTimeoutSec = 10
)

$fmt = 'yyyy-MM-dd HH:mm'
$inv = [System.Globalization.CultureInfo]::InvariantCulture

function Exit-Cover([string]$Text, [int]$Code) {
    Write-Output ('karina-cover ' + $Text)
    exit $Code
}

if (@('pause', 'resume') -notcontains $Action -or -not $Holder) { Exit-Cover 'ERROR usage' 1 }

$nowValue = Get-Date
if ($Now) {
    $parsed = [datetime]::MinValue
    if (-not [datetime]::TryParseExact($Now, $fmt, $inv, [System.Globalization.DateTimeStyles]::None, [ref]$parsed)) { Exit-Cover 'ERROR now-unparsed' 1 }
    $nowValue = $parsed
}

if (-not $StateDir) {
    $tempBase = @($env:TMPDIR, $env:TEMP, $env:TMP) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -First 1
    if (-not $tempBase) { $tempBase = [System.IO.Path]::GetTempPath() }
    $StateDir = Join-Path (Join-Path $tempBase 'karina-plugin') 'cover'
}
New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
$statePath = Join-Path $StateDir 'cover-state.json'
$lockPath = Join-Path $StateDir 'cover.lock'

function Resolve-KarinaCli {
    if ($CliCommand) {
        if (Get-Command $CliCommand -ErrorAction SilentlyContinue) { return $CliCommand }
        return $null
    }
    $candidates = @($env:KARINA_CLI_COMMAND, 'karina-cli', 'karina-dev-cli')
    if ($env:LOCALAPPDATA) { $candidates += (Join-Path $env:LOCALAPPDATA 'Programs\Karina\karina-cli.exe') }
    foreach ($c in $candidates) {
        if ($c -and (Get-Command $c -ErrorAction SilentlyContinue)) { return $c }
    }
    return $null
}

# Karina CLI 는 오류까지 늘 JSON 으로 답한다(karina-computer-use 「Preconditions」)
function Invoke-KarinaCli([string[]]$CliArgs) {
    $raw = & $script:cli @CliArgs 2>$null | Out-String
    $code = $LASTEXITCODE
    $json = $null
    try { $json = $raw | ConvertFrom-Json -ErrorAction Stop } catch { $json = $null }
    $ok = ($code -eq 0) -and ($null -ne $json) -and ($json.ok -eq $true)
    return [pscustomobject]@{ Ok = $ok; Code = $code; Json = $json }
}

function Get-AppState {
    $st = Invoke-KarinaCli @('status', '--json')
    if (-not $st.Ok) { return 'error' }
    if ($st.Json.result.appRunning -eq $false) { return 'off' }
    return 'on'
}

function Read-CoverState {
    $state = @{ paused = @(); holders = @{} }
    if (-not (Test-Path -LiteralPath $statePath)) { return $null }
    try {
        $j = Get-Content -LiteralPath $statePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    } catch { return $state }
    $state.paused = @($j.paused | Where-Object { $null -ne $_ } | ForEach-Object { [int]$_ })
    if ($j.holders) {
        foreach ($p in $j.holders.PSObject.Properties) { $state.holders[$p.Name] = [string]$p.Value }
    }
    return $state
}

function Write-CoverState($state) {
    $tmp = $statePath + '.tmp'
    $body = ConvertTo-Json -InputObject @{ paused = @($state.paused); holders = $state.holders } -Depth 4
    Set-Content -LiteralPath $tmp -Value $body -Encoding UTF8
    Move-Item -LiteralPath $tmp -Destination $statePath -Force
}

function Remove-StaleHolders($state) {
    $cutoff = $nowValue.AddHours(-$StaleHours)
    foreach ($name in @($state.holders.Keys)) {
        $t = [datetime]::MinValue
        $fresh = [datetime]::TryParseExact($state.holders[$name], $fmt, $inv, [System.Globalization.DateTimeStyles]::None, [ref]$t) -and ($t -ge $cutoff)
        if (-not $fresh) { $state.holders.Remove($name) }
    }
}

function Format-Monitors([int[]]$List) {
    if (-not $List -or $List.Count -eq 0) { return 'none' }
    return (($List | Sort-Object) -join ',')
}

$lock = $null
$deadline = (Get-Date).AddSeconds($LockTimeoutSec)
while (-not $lock) {
    try {
        $lock = [System.IO.File]::Open($lockPath, 'OpenOrCreate', 'ReadWrite', 'None')
    } catch {
        if ((Get-Date) -ge $deadline) { Exit-Cover 'ERROR lock-timeout' 1 }
        Start-Sleep -Milliseconds 100
    }
}

try {
    $state = Read-CoverState

    if ($Action -eq 'resume' -and $null -eq $state) { Exit-Cover 'restored none' 0 }

    $script:cli = Resolve-KarinaCli
    if (-not $script:cli) { Exit-Cover 'skip no-cli' 0 }

    if ($null -eq $state) { $state = @{ paused = @(); holders = @{} } }
    Remove-StaleHolders $state

    $app = Get-AppState

    if ($Action -eq 'pause') {
        if ($app -eq 'off') { Exit-Cover 'skip app-off' 0 }
        if ($app -eq 'error') { Exit-Cover 'ERROR status' 1 }
        $cover = Invoke-KarinaCli @('cover', 'status', '--json')
        if (-not $cover.Ok) { Exit-Cover 'ERROR cover-status' 1 }
        $state.holders[$Holder] = $nowValue.ToString($fmt, $inv)
        Write-CoverState $state
        $turnedOff = @()
        foreach ($m in @($cover.Json.result.monitors | Where-Object { $_.covered })) {
            $n = [int]$m.monitor
            $off = Invoke-KarinaCli @('cover', 'off', '--monitor', "$n", '--json')
            if (-not $off.Ok) { Exit-Cover ('ERROR cover-off ' + $n) 1 }
            if ($state.paused -notcontains $n) { $state.paused = @($state.paused) + $n }
            Write-CoverState $state
            $turnedOff += $n
        }
        Exit-Cover ('paused ' + (Format-Monitors $turnedOff)) 0
    }

    $state.holders.Remove($Holder)
    if ($app -eq 'off') {
        $state.paused = @()
        Write-CoverState $state
        Exit-Cover 'skip app-off' 0
    }
    if ($app -eq 'error') {
        Write-CoverState $state
        Exit-Cover 'ERROR status' 1
    }
    if ($state.holders.Count -gt 0) {
        Write-CoverState $state
        Exit-Cover ('held ' + $state.holders.Count) 0
    }
    $restored = @()
    foreach ($n in @($state.paused)) {
        $on = Invoke-KarinaCli @('cover', 'on', '--monitor', "$n", '--json')
        if (-not $on.Ok) {
            Write-CoverState $state
            Exit-Cover ('ERROR cover-on ' + $n) 1
        }
        $state.paused = @($state.paused | Where-Object { $_ -ne $n })
        $restored += $n
    }
    Remove-Item -LiteralPath $statePath -Force
    Exit-Cover ('restored ' + (Format-Monitors $restored)) 0
} finally {
    $lock.Dispose()
}
