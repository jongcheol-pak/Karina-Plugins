if (Test-HookSelected @('warn-screen-busy')) {

$sbTmp = Join-Path $work 'sb-tmp'
$sbBusy = Join-Path $sbTmp 'karina-plugin/screen-busy'
$sbRepo = Join-Path $work 'sb-repo'
New-Item -ItemType Directory (Join-Path $sbRepo '.git') -Force | Out-Null
New-Item -ItemType Directory (Join-Path $sbRepo 'src') -Force | Out-Null
$sbWt = Join-Path $sbRepo '.claude/worktrees/w1'
New-Item -ItemType Directory (Join-Path $sbWt 'src') -Force | Out-Null
"gitdir: $($sbRepo -replace '\\', '/')/.git/worktrees/w1" | Set-Content -LiteralPath (Join-Path $sbWt '.git') -Encoding UTF8
$sbSaved = @{ TMPDIR = $env:TMPDIR; TEMP = $env:TEMP; TMP = $env:TMP }

function Reset-SbBusy {
    if (Test-Path -LiteralPath $sbBusy) { Get-ChildItem -LiteralPath $sbBusy -File | ForEach-Object { [System.IO.File]::Delete($_.FullName) } }
    New-Item -ItemType Directory $sbBusy -Force | Out-Null
}
function Set-SbMarker([int]$ProcId, [string]$Root, [datetime]$Started) {
    $o = @{ pid = $ProcId; root = $Root; started = $Started.ToString('o') }
    $p = Join-Path $sbBusy ("$ProcId.json")
    [System.IO.File]::WriteAllText($p, ($o | ConvertTo-Json -Compress))
    return $p
}
function New-SbJson([string]$Tool, [string]$Path, [string]$AgentId = '') {
    $o = @{ session_id = 'sb'; hook_event_name = 'PreToolUse'; tool_name = $Tool; cwd = $sbRepo; tool_input = @{ file_path = $Path } }
    if ($AgentId) { $o.agent_id = $AgentId }
    return ($o | ConvertTo-Json -Compress -Depth 4)
}
$sbDead = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-Command', 'exit 0') -PassThru -NoNewWindow
$sbDead.WaitForExit()

try {
    $env:TMPDIR = $sbTmp
    Reset-SbBusy
    $null = Set-SbMarker $PID $sbRepo (Get-Date)
    $r = Invoke-Hook 'warn-screen-busy.ps1' (New-SbJson 'Edit' (Join-Path $sbRepo 'src/a.rs')) -SplitStreams
    Assert-Case -Name "warn-screen-busy: 살아 있는 표지 + 같은 레포 소스 Edit 는 경고" -R @{ code = $r.code; out = $r.out } -ExpectExit 0 -ExpectContains '"additionalContext"'
    Assert-Case -Name "warn-screen-busy: 경고가 검증 대기와 loop-pacing.md 를 가리킨다" -R @{ code = $r.code; out = $r.out } -ExpectContains 'loop-pacing.md'
    Assert-Case -Name "warn-screen-busy: 경고가 stderr 에도 실린다" -R @{ code = $r.code; out = $r.err } -ExpectContains '화면 검증'

    $r = Invoke-Hook 'warn-screen-busy.ps1' (New-SbJson 'Write' (Join-Path $sbRepo 'plan.md'))
    Assert-Case -Name "warn-screen-busy: 같은 레포 plan.md Write 도 경고" -R $r -ExpectExit 0 -ExpectContains '"additionalContext"'

    $r = Invoke-Hook 'warn-screen-busy.ps1' (New-SbJson 'Edit' (Join-Path $sbWt 'src/b.rs'))
    Assert-Case -Name "warn-screen-busy: worktree .git 파일 경계 안(다른 루트) 편집은 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

    $r = Invoke-Hook 'warn-screen-busy.ps1' (New-SbJson 'Edit' (Join-Path $sbRepo 'src/a.rs') 'sub-1')
    Assert-Case -Name "warn-screen-busy: 서브에이전트 안 편집은 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

    $env:TMPDIR = $null
    $env:TEMP = $sbTmp; $env:TMP = $sbTmp
    $r = Invoke-Hook 'warn-screen-busy.ps1' (New-SbJson 'Edit' (Join-Path $sbRepo 'src/a.rs'))
    Assert-Case -Name "warn-screen-busy: TMPDIR 없이 TEMP 만 있어도 같은 표지 폴더를 본다" -R $r -ExpectExit 0 -ExpectContains '"additionalContext"'
    $env:TEMP = $sbSaved.TEMP; $env:TMP = $sbSaved.TMP
    $env:TMPDIR = $sbTmp

    Reset-SbBusy
    $sbDeadPath = Set-SbMarker $sbDead.Id $sbRepo (Get-Date)
    $r = Invoke-Hook 'warn-screen-busy.ps1' (New-SbJson 'Edit' (Join-Path $sbRepo 'src/a.rs'))
    Assert-Case -Name "warn-screen-busy: PID 가 죽은 표지는 무출력" -R $r -ExpectExit 0 -ExpectSilent $true
    Assert-Case -Name "warn-screen-busy: PID 가 죽은 표지는 지운다" -R @{ code = 0; out = "exists=$(Test-Path -LiteralPath $sbDeadPath)" } -ExpectContains 'exists=False'

    Reset-SbBusy
    $null = Set-SbMarker $PID $sbRepo (Get-Date).AddSeconds(-1600)
    $r = Invoke-Hook 'warn-screen-busy.ps1' (New-SbJson 'Edit' (Join-Path $sbRepo 'src/a.rs'))
    Assert-Case -Name "warn-screen-busy: 1500초 넘은 표지는 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

    Reset-SbBusy
    [System.IO.Directory]::Delete($sbBusy, $true)
    $r = Invoke-Hook 'warn-screen-busy.ps1' (New-SbJson 'Edit' (Join-Path $sbRepo 'src/a.rs'))
    Assert-Case -Name "warn-screen-busy: 표지 폴더가 없으면 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

    $r = Invoke-Hook 'warn-screen-busy.ps1' 'not json'
    Assert-Case -Name "warn-screen-busy: 깨진 입력은 exit 0" -R $r -ExpectExit 0

    $swPath = Join-Path $pluginRoot 'skills/implement/scripts/screen-wait.ps1'
    $swState = Join-Path $work 'sw-state'
    $sw = Start-Process -FilePath 'pwsh' -ArgumentList @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$swPath`"", '-Root', "`"$sbRepo`"", '-Seconds', '3', '-StateDir', "`"$swState`"") -PassThru -NoNewWindow
    $swMarker = Join-Path $swState ("$($sw.Id).json")
    $swSeen = $false
    while (-not $swSeen -and -not $sw.HasExited) { if (Test-Path -LiteralPath $swMarker) { $swSeen = $true } else { Start-Sleep -Milliseconds 50 } }
    $swRoot = if ($swSeen) { [string]((Get-Content -LiteralPath $swMarker -Raw | ConvertFrom-Json).root) } else { '' }
    $null = $sw.WaitForExit(15000)
    Assert-Case -Name "screen-wait: 도는 동안 자기 PID 표지에 레포 루트를 쓴다" -R @{ code = 0; out = "seen=$swSeen root=$swRoot" } -ExpectContains "seen=True root=$sbRepo"
    Assert-Case -Name "screen-wait: 끝나면 표지를 지운다" -R @{ code = 0; out = "exists=$(Test-Path -LiteralPath $swMarker)" } -ExpectContains 'exists=False'
} finally {
    foreach ($k in $sbSaved.Keys) { [Environment]::SetEnvironmentVariable($k, $sbSaved[$k]) }
}

}
