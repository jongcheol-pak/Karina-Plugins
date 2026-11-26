# screen-wait.ps1 — 화면 검증 에이전트 요청의 시한 타이머 겸 「검증 중」 표지 (모델이 백그라운드 셸로 부르는 헬퍼 — hook 아님) — 근거는 `../../../scripts/rules/screen-busy-rationale.md` §2
param(
    [string]$Root = '',
    [int]$Seconds = 1200,
    [string]$StateDir = ''
)

function Get-KarinaTempRoot {
    $base = @($env:TMPDIR, $env:TEMP, $env:TMP) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -First 1
    if (-not $base) { $base = [System.IO.Path]::GetTempPath() }
    return (Join-Path $base 'karina-plugin')
}

if (-not $Root) { $Root = [string](git rev-parse --show-toplevel 2>$null) }
if (-not $Root) { $Root = (Get-Location).Path }
$Root = [System.IO.Path]::GetFullPath($Root)
if (-not $StateDir) { $StateDir = Join-Path (Get-KarinaTempRoot) 'screen-busy' }
New-Item -ItemType Directory -Path $StateDir -Force | Out-Null
$marker = Join-Path $StateDir ("$PID.json")
try {
    [System.IO.File]::WriteAllText($marker, (@{ pid = $PID; root = $Root; started = (Get-Date).ToString('o') } | ConvertTo-Json -Compress))
    Start-Sleep -Seconds $Seconds
    Write-Output "timeout ${Seconds}s"
} finally {
    if (Test-Path -LiteralPath $marker) { [System.IO.File]::Delete($marker) }
}
