if (Test-HookSelected @('guard-bash', 'guard-task-audit')) {
if (-not $gitOk) {
    Write-Host '[SKIP] guard-task-audit: git 없음 — 변경 판정이 성립하지 않는다'
} else {
$taRoot = Join-Path $work 'ta-repo'
try {
    $taCmd = 'cargo test --lib -- doc_audit'
    $taRule = '- **Test (감사)**: `' + $taCmd + '` · 증가: `^\s*pub\s+fn\b` · 경로: `*.rs` · 또는: `cargo test --no-fail-fast` · 또는: `cargo test`'
    $taMdRule = '- **Test (감사)**: `md-audit-run` · 증가: `^TODO` · 경로: `*.md`'
    $nl = [Environment]::NewLine
    New-Item -ItemType Directory (Join-Path $taRoot 'src') -Force | Out-Null
    New-Item -ItemType Directory (Join-Path $taRoot 'sub') -Force | Out-Null
    ('# AGENTS.md' + $nl + $nl + '## Build & Test' + $nl + $nl + $taRule + $nl + $taMdRule + $nl) | Set-Content (Join-Path $taRoot 'AGENTS.md')
    ('# AGENTS.md' + $nl + $nl + '- **Test (감사)**: `sub-audit-run` · 증가: `^\s*pub\s+fn\b` · 경로: `*.rs`' + $nl) | Set-Content (Join-Path $taRoot 'sub/AGENTS.md')
    'pub fn old() {}' | Set-Content (Join-Path $taRoot 'src/lib.rs')
    'fn inner() {}' | Set-Content (Join-Path $taRoot 'sub/x.rs')
    '# 문서' | Set-Content (Join-Path $taRoot 'README.md')
    & git -C $taRoot init -q 2>$null
    & git -C $taRoot add -A 2>$null
    & git -C $taRoot -c user.email=t@t -c user.name=t commit -q -m 'init' 2>$null

    function Reset-TaRepo {
        & git -C $taRoot reset -q --hard 2>$null
        & git -C $taRoot clean -fdq 2>$null
    }
    function New-TaCommitCmd([string]$Title, [string]$Body, [string]$Prefix = '', [string]$Flags = '') {
        return $Prefix + 'git commit ' + $Flags + '-m "$(cat <<''MSG''' + "`n" + $Title + "`n`n" + $Body + "`nMSG`n)" + '"'
    }
    function Invoke-TaCase([string]$Command, [string]$Cwd = $taRoot) {
        $json = @{ hook_event_name = 'PreToolUse'; tool_name = 'Bash'; cwd = $Cwd
                   tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
        Push-Location $Cwd
        try { return (Invoke-Hook 'guard-bash.ps1' $json) } finally { Pop-Location }
    }
    $taTitle = '기능: T1 — 항목 추가'
    $taBodyNone = '검증 결과:' + "`n" + '- cargo test --lib -- computer_guard → ok'

    Reset-TaRepo
    ('pub fn old() {}' + $nl + 'pub fn added() {}') | Set-Content (Join-Path $taRoot 'src/lib.rs')
    & git -C $taRoot add -A 2>$null
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone)
    Assert-Case -Name 'task-audit: pub 증가 + 명령 없음 → 명령을 지목해 경고(exit 0)' -R $r -ExpectExit 0 -ExpectContains $taCmd
    Assert-Case -Name 'task-audit: 경고는 보충 커밋 경로를 안내한다' -R $r -ExpectExit 0 -ExpectContains '--allow-empty'

    $r = Invoke-TaCase (New-TaCommitCmd $taTitle ('검증 결과:' + "`n" + '- `' + $taCmd + '` → test result: ok'))
    Assert-Case -Name 'task-audit: 본문에 명령 있음 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true

    $r = Invoke-TaCase (New-TaCommitCmd '기능: 정리' $taBodyNone)
    Assert-Case -Name 'task-audit: 완료 커밋 아님 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true

    $r = Invoke-TaCase (New-TaCommitCmd $taTitle ('- cargo test --no-fail-fast > out.txt 2>&1 → 0 failed'))
    Assert-Case -Name 'task-audit: 대안 명령 + 리다이렉션 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle ('- ' + $taCmd + ' → test result: ok'))
    Assert-Case -Name 'task-audit: 백틱 없는 명령 + 화살표 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle ('- cargo test computer_guard → ok'))
    Assert-Case -Name 'task-audit: 대안 명령에 위치 인자 필터 → 경고' -R $r -ExpectExit 0 -ExpectContains $taCmd

    $r = Invoke-TaCase ('git commit -m "' + $taTitle + '" -m "' + $taCmd + ' → ok"')
    Assert-Case -Name 'task-audit: 두 번째 -m 의 명령도 읽는다 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true

    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone)
    Assert-Case -Name 'task-audit: 걸리지 않은 규칙의 명령은 지목하지 않는다' -R $r -ExpectExit 0 -ExpectContains $taCmd -ExpectNotContains 'md-audit-run'

    Reset-TaRepo
    'pub fn renamed() {}' | Set-Content (Join-Path $taRoot 'src/lib.rs')
    & git -C $taRoot add -A 2>$null
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone)
    Assert-Case -Name 'task-audit: 순증 0 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true

    Reset-TaRepo
    ('# 문서' + $nl + 'pub fn in_doc() {}') | Set-Content (Join-Path $taRoot 'README.md')
    & git -C $taRoot add -A 2>$null
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone)
    Assert-Case -Name 'task-audit: 경로 밖 파일 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true

    Reset-TaRepo
    ('# AGENTS.md' + $nl) | Set-Content (Join-Path $taRoot 'AGENTS.md')
    ('pub fn old() {}' + $nl + 'pub fn added() {}') | Set-Content (Join-Path $taRoot 'src/lib.rs')
    & git -C $taRoot add src/lib.rs 2>$null
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone)
    Assert-Case -Name 'task-audit: Test (감사) 줄 없음 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true

    ('# AGENTS.md' + $nl + '- **Test (감사)**: `broken-run` · 증가: `(` · 경로: `*.rs`' + $nl) | Set-Content (Join-Path $taRoot 'AGENTS.md')
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone)
    Assert-Case -Name 'task-audit: 깨진 정규식 줄 → 규칙을 읽지 못함 경고' -R $r -ExpectExit 0 -ExpectContains '규칙을 읽지 못함'

    Reset-TaRepo
    'pub fn fresh() {}' | Set-Content (Join-Path $taRoot 'src/new.rs')
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone 'git add src/new.rs && ')
    Assert-Case -Name 'task-audit: add && commit 의 미추적 새 파일 → 경고' -R $r -ExpectExit 0 -ExpectContains $taCmd

    Reset-TaRepo
    ('pub fn old() {}' + $nl + 'pub fn added() {}') | Set-Content (Join-Path $taRoot 'src/lib.rs')
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone '' '-a ')
    Assert-Case -Name 'task-audit: -a 커밋의 미스테이징 변경 → 경고' -R $r -ExpectExit 0 -ExpectContains $taCmd

    & git -C $taRoot add -A 2>$null
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone) (Join-Path $taRoot 'src')
    Assert-Case -Name 'task-audit: 하위 폴더 커밋 → 최상위 AGENTS.md 규칙으로 경고' -R $r -ExpectExit 0 -ExpectContains $taCmd
    Reset-TaRepo
    ('fn inner() {}' + $nl + 'pub fn more() {}') | Set-Content (Join-Path $taRoot 'sub/x.rs')
    & git -C $taRoot add -A 2>$null
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone) (Join-Path $taRoot 'sub')
    Assert-Case -Name 'task-audit: 하위 폴더에 AGENTS.md 가 있으면 그쪽 규칙만 따른다' -R $r -ExpectExit 0 -ExpectContains 'sub-audit-run' -ExpectNotContains $taCmd
} finally {
    if (Test-Path $taRoot) { Remove-Item $taRoot -Recurse -Force -ErrorAction SilentlyContinue }
}
}
}
