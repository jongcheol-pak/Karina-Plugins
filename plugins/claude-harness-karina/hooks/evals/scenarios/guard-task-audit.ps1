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
    $r = Invoke-TaCase (New-TaCommitCmd '기능: T1-2 — 항목 추가' $taBodyNone)
    Assert-Case -Name 'task-audit: 하위 ID 완료 커밋은 경고와 보충 커밋 제목에 하위 ID 를 그대로 쓴다' -R $r -ExpectExit 0 -ExpectContains 'T1-2 완료 커밋에'
    $taNoCl = Join-Path $work 'ta-no-comment-lines'; New-Item -ItemType Directory $taNoCl -Force | Out-Null
    Copy-Item (Join-Path $scriptsDir '*') $taNoCl -Recurse -Force -Exclude 'comment-lines.ps1'
    if (Test-Path -LiteralPath (Join-Path $taNoCl 'comment-lines.ps1')) { throw 'task-audit 사본에 comment-lines.ps1 이 남았다 — 전제 깨짐' }
    $taNoClJson = @{ hook_event_name = 'PreToolUse'; tool_name = 'Bash'; cwd = $taRoot
                     tool_input = @{ command = (New-TaCommitCmd $taTitle $taBodyNone) } } | ConvertTo-Json -Compress
    Push-Location $taRoot
    try { $r = Invoke-Hook (Join-Path $taNoCl 'guard-bash.ps1') $taNoClJson -Process } finally { Pop-Location }
    Assert-Case -Name 'task-audit: 감사 파서(comment-lines.ps1) 로드 실패면 경고하고 통과(fail-open)' -R $r -ExpectExit 0 -ExpectContains 'task 감사 누락 검사 미수행'

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
    [System.IO.File]::WriteAllText((Join-Path $taRoot 'msg.txt'), ($taTitle + "`r`n`r`n- " + $taCmd + "`r`n"), [System.Text.UTF8Encoding]::new($false))
    $r = Invoke-TaCase 'git commit -F msg.txt'
    Assert-Case -Name 'task-audit: -F 파일의 CRLF 줄 끝 명령도 읽는다 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true

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
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone)
    Assert-Case -Name 'task-audit: 선행 add 없는 미추적 새 파일은 세지 않는다 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true

    Reset-TaRepo
    ('pub fn old() {}' + $nl + 'pub fn added() {}') | Set-Content (Join-Path $taRoot 'src/lib.rs')
    ('# 문서' + $nl + '본문') | Set-Content (Join-Path $taRoot 'README.md')
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone 'git add README.md && ')
    Assert-Case -Name 'task-audit: add 명시 경로 밖의 미스테이징 증가는 세지 않는다 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true
    & git -C $taRoot add README.md 2>$null
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone)
    Assert-Case -Name 'task-audit: add 없는 커밋은 staged 만 센다 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone 'git add src/lib.rs && ')
    Assert-Case -Name 'task-audit: add 명시 경로의 증가 → 경고' -R $r -ExpectExit 0 -ExpectContains $taCmd
    $r = Invoke-TaCase ((New-TaCommitCmd $taTitle $taBodyNone) + ' -- src/lib.rs')
    Assert-Case -Name 'task-audit: commit -- <경로> 의 미스테이징 증가 → 경고' -R $r -ExpectExit 0 -ExpectContains $taCmd
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $taBodyNone 'git add -A && ')
    Assert-Case -Name 'task-audit: add -A 는 작업 트리 전체를 센다 → 경고' -R $r -ExpectExit 0 -ExpectContains $taCmd
    & git -C $taRoot add src/lib.rs 2>$null
    $r = Invoke-TaCase ((New-TaCommitCmd $taTitle $taBodyNone) + ' -- README.md')
    Assert-Case -Name 'task-audit: commit -- <경로> 는 다른 경로의 staged 증가를 세지 않는다 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true
    $r = Invoke-TaCase ((New-TaCommitCmd $taTitle $taBodyNone '' '-i ') + ' -- README.md')
    Assert-Case -Name 'task-audit: commit -i -- <경로> 는 staged 증가도 센다 → 경고' -R $r -ExpectExit 0 -ExpectContains $taCmd

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

    Reset-TaRepo
    $taSubCmd = 'cargo test --lib -- test_doc_audit'
    ('# AGENTS.md' + $nl + '- **Test (감사)**: `' + $taSubCmd + '` · 증가: `^\s*pub\s+fn\b` · 경로: `*.rs` · 또는: `cargo test`' + $nl) | Set-Content (Join-Path $taRoot 'AGENTS.md')
    ('pub fn old() {}' + $nl + 'pub fn added() {}') | Set-Content (Join-Path $taRoot 'src/lib.rs')
    & git -C $taRoot add src/lib.rs 2>$null
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- cargo test --lib -- doc_audit → 5 passed')
    Assert-Case -Name 'task-audit: 감사 필터를 부분 문자열로 품는 cargo 필터 실행 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- cargo test --lib -- other_audit → ok')
    Assert-Case -Name 'task-audit: 감사 필터에 들지 않는 cargo 필터 → 경고' -R $r -ExpectExit 0 -ExpectContains $taSubCmd
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- cargo test --lib -- doc_audit --exact → ok')
    Assert-Case -Name 'task-audit: --exact 가 붙은 부분 필터 → 경고' -R $r -ExpectExit 0 -ExpectContains $taSubCmd
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- cargo test -- doc_audit → ok')
    Assert-Case -Name 'task-audit: 필터 앞부분이 감사 명령과 다른 cargo 실행 → 경고' -R $r -ExpectExit 0 -ExpectContains $taSubCmd
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- cargo test --lib --no-fail-fast -- _audit → ok')
    Assert-Case -Name 'task-audit: 대상 선택 뒤에 --no-fail-fast 가 낀 부분 필터 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- cargo test --no-fail-fast --lib -- doc_audit → ok')
    Assert-Case -Name 'task-audit: 대상 선택 앞에 --no-fail-fast 가 낀 부분 필터 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- cargo test --bin karina --no-fail-fast -- doc_audit → ok')
    Assert-Case -Name 'task-audit: 대상 선택이 다른(--bin) 부분 필터 → 경고' -R $r -ExpectExit 0 -ExpectContains $taSubCmd
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- cargo test --no-fail-fast -- doc_audit → ok')
    Assert-Case -Name 'task-audit: 실행 플래그만 있고 --lib 이 없는 부분 필터 → 경고' -R $r -ExpectExit 0 -ExpectContains $taSubCmd
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- cargo test --lib && cargo test -- doc_audit → ok')
    Assert-Case -Name 'task-audit: 명령 구분자 앞의 --lib 은 뒤 실행의 대상 선택이 아니다 → 경고' -R $r -ExpectExit 0 -ExpectContains $taSubCmd

    $ttTemplate = '- **Test (task)**: `python docs/test-task.py <출력 파일> <대상…> _audit every_child_process_hides_its_console` (빌드 포함)'
    ('# AGENTS.md' + $nl + $taRule + $nl + $ttTemplate + $nl) | Set-Content (Join-Path $taRoot 'AGENTS.md')
    & git -C $taRoot add src/lib.rs 2>$null
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- python docs/test-task.py target/fix-zoom-msg.txt zoom_badge _audit every_child_process_hides_its_console → exit 0')
    Assert-Case -Name 'task-audit: Test (task) 실행의 _audit 필터가 감사 필터에 들면 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle 'GREEN: python docs/test-task.py target/fix.txt session_cookies _audit every_child_process_hides_its_console → 실행 1077건 · cargo exit 0')
    Assert-Case -Name 'task-audit: 줄 머리 GREEN: 이 붙은 Test (task) 실행 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- python docs/test-task.py target/t.txt other_audit → ok')
    Assert-Case -Name 'task-audit: Test (task) 필터가 감사 필터에 들지 않으면 → 경고' -R $r -ExpectExit 0 -ExpectContains $taCmd
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- python docs/test-task.py doc_audit zoom_badge → ok')
    Assert-Case -Name 'task-audit: Test (task) 출력 파일 자리만 감사 필터와 같으면 → 경고' -R $r -ExpectExit 0 -ExpectContains $taCmd
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- python docs/test-task.py target/t.txt zoom_badge && echo _audit → ok')
    Assert-Case -Name 'task-audit: Test (task) 의 명령 구분자 뒤 토큰은 필터가 아니다 → 경고' -R $r -ExpectExit 0 -ExpectContains $taCmd
    ('# AGENTS.md' + $nl + $taRule + $nl + '- **Test (task)**: `python t.py <대상>`' + $nl) | Set-Content (Join-Path $taRoot 'AGENTS.md')
    & git -C $taRoot add src/lib.rs 2>$null
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- python t.py _audit → ok')
    Assert-Case -Name 'task-audit: 정본 서식 <대상> 템플릿의 Test (task) 실행 → 무출력' -R $r -ExpectExit 0 -ExpectSilent $true
    ('# AGENTS.md' + $nl + $taRule + $nl) | Set-Content (Join-Path $taRoot 'AGENTS.md')
    & git -C $taRoot add src/lib.rs 2>$null
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '- python docs/test-task.py target/fix-zoom-msg.txt zoom_badge _audit every_child_process_hides_its_console → exit 0')
    Assert-Case -Name 'task-audit: Test (task) 줄이 없는 레포의 같은 본문 → 경고' -R $r -ExpectExit 0 -ExpectContains $taCmd

    Reset-TaRepo
    $teBase = (& git -C $taRoot rev-parse HEAD 2>$null)
    $tePlan = Join-Path $taRoot 'plan.md'
    @('# plan', '', '## Goal', '', ('> BASE: ' + $teBase), '', '## 작업 단계', '', '### T1. 항목', '',
      '- [x] **T1-1** 항목을 더한다', '- **Files**: `src/lib.rs` — 케이스: 「항목」 (RED)', '- **화면**: 시나리오 열기 · 스크린샷 t1.png · 통과 조건 보인다', '',
      '### T2. 문서', '', '- [x] **T2-1** 문서', '- **Files**: `README.md` — `[면제 ①]` 문서') | Set-Content -LiteralPath $tePlan -Encoding UTF8
    $teOk = '검증 결과: ok' + "`n" + '- `' + $taCmd + '` → ok'
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $teOk)
    Assert-Case -Name 'task-evidence: (RED) task 완료 커밋에 RED 줄이 없으면 경고' -R $r -ExpectExit 0 -ExpectContains 'RED 줄'
    Assert-Case -Name 'task-evidence: 화면 task 완료 커밋에 화면 판정 줄이 없으면 경고' -R $r -ExpectExit 0 -ExpectContains '화면 판정 줄'
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle ($teOk + "`n" + 'RED(구현 전): 케이스 FAIL' + "`n" + '화면(verify-karina): 보인다'))
    Assert-Case -Name 'task-evidence: 서식이 다른 화면 줄은 인용해 기대 서식을 보인다' -R $r -ExpectExit 0 -ExpectContains '화면(verify-karina): 보인다' -ExpectNotContains 'RED 줄'
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle ($teOk + "`n" + 'RED(구현 전): 케이스 FAIL' + "`n" + '화면: HEAD 참 — t1.png'))
    Assert-Case -Name 'task-evidence: RED·화면 판정 줄이 있으면 경고 없음' -R $r -ExpectExit 0 -ExpectSilent $true
    $r = Invoke-TaCase (New-TaCommitCmd '기능: T1-2 — 하위' $teOk)
    Assert-Case -Name 'task-evidence: 하위 ID 커밋은 RED·화면을 재지 않는다' -R $r -ExpectExit 0 -ExpectNotContains 'RED 줄'
    $r = Invoke-TaCase (New-TaCommitCmd '문서: T2 — 문서' $teOk)
    Assert-Case -Name 'task-evidence: (RED)·화면 줄이 없는 task 는 재지 않는다' -R $r -ExpectExit 0 -ExpectSilent $true
    ('# AGENTS.md' + $nl) | Set-Content (Join-Path $taRoot 'AGENTS.md')
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle '검증 결과: ok')
    Assert-Case -Name 'task-evidence: 감사 규칙이 없는 레포에서도 RED 누락을 경고' -R $r -ExpectExit 0 -ExpectContains 'RED 줄'
    & git -C $taRoot checkout -q -- AGENTS.md 2>$null
    Rename-Item -LiteralPath $tePlan -NewName 'plan-off.md'
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $teOk)
    Assert-Case -Name 'task-evidence: plan.md 가 없으면 침묵' -R $r -ExpectExit 0 -ExpectSilent $true
    Rename-Item -LiteralPath (Join-Path $taRoot 'plan-off.md') -NewName 'plan.md'

    $teCheck = Join-Path $scriptsDir '../skills/plan/scripts/check-plan.ps1'
    & git -C $taRoot -c user.email=t@t -c user.name=t commit -q --allow-empty -m $taTitle -m $teOk 2>$null
    $teCp = (& pwsh -NoProfile -File $teCheck $tePlan -Base $teBase 2>&1) -join ' '
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $teOk)
    Assert-Case -Name 'task-evidence: 같은 본문을 check-plan -Base 도 RED·화면 위반으로 낸다 (사본 정합)' -R @{ code = $r.code; out = "cp=$teCp" } -ExpectExit 0 -ExpectContains 'no-red-evidence T1'
    Assert-Case -Name 'task-evidence: 같은 이력에 hook 도 RED·화면 경고를 낸다 (사본 정합)' -R $r -ExpectExit 0 -ExpectContains 'RED 줄 없음'
    Assert-Case -Name 'task-evidence: 같은 이력에 hook 도 화면 경고를 낸다 (사본 정합)' -R $r -ExpectExit 0 -ExpectContains '화면 판정 줄 없음'
    Assert-Case -Name 'task-evidence: 같은 본문을 check-plan -Base 도 화면 위반으로 낸다 (사본 정합)' -R @{ code = $r.code; out = "cp=$teCp" } -ExpectExit 0 -ExpectContains 'no-screen-verdict T1'
    & git -C $taRoot -c user.email=t@t -c user.name=t commit -q --allow-empty -m '기능: T1 — 앞 커밋' -m ($teOk + "`n" + 'RED(구현 전): 케이스 FAIL' + "`n" + '화면: HEAD 참 — t1.png') 2>$null
    $teCp = (& pwsh -NoProfile -File $teCheck $tePlan -Base $teBase 2>&1) -join ' '
    $r = Invoke-TaCase (New-TaCommitCmd $taTitle $teOk)
    Assert-Case -Name 'task-evidence: 앞 T1 커밋 본문에 RED·화면 판정이 있으면 경고 없음' -R $r -ExpectExit 0 -ExpectSilent $true
    Assert-Case -Name 'task-evidence: 그 이력을 check-plan -Base 도 통과시킨다 (사본 정합)' -R @{ code = 0; out = "cp=$teCp" } -ExpectExit 0 -ExpectContains 'no-task-commit T2' -ExpectNotContains 'T1'
} finally {
    if (Test-Path $taRoot) { Remove-Item $taRoot -Recurse -Force -ErrorAction SilentlyContinue }
}

$utMark = '회차 전부터 있던 untracked 파일'
$utScratch = Join-Path ([System.IO.Path]::GetTempPath()) 'karina-plugin/scratch'
New-Item -ItemType Directory $utScratch -Force | Out-Null
$utTop = Join-Path $work ('ut-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
$utSnaps = @()
try {
    New-Item -ItemType Directory (Join-Path $utTop 'sub/docs') -Force | Out-Null
    New-Item -ItemType Directory (Join-Path $utTop 'docs') -Force | Out-Null
    'x' | Set-Content (Join-Path $utTop 'README.md')
    & git -C $utTop init -q 2>$null
    & git -C $utTop add -A 2>$null
    & git -C $utTop -c user.email=t@t -c user.name=t commit -q -m 'init' 2>$null
    $utSha = ((& git -C $utTop rev-parse HEAD) | Out-String).Trim().Substring(0, 7)
    ("# plan`n`n## Goal`n`n> BASE: $utSha`n") | Set-Content (Join-Path $utTop 'plan.md')
    'old' | Set-Content (Join-Path $utTop 'docs/release.md')
    $utSnap = Join-Path $utScratch ('untracked-start-' + (Split-Path -Leaf $utTop) + '-' + $utSha + '.txt')
    "docs/release.md`nplan.md" | Set-Content $utSnap
    $utSnaps += $utSnap
    function Invoke-UtCase([string]$Command, [string]$Cwd) {
        $json = @{ hook_event_name = 'PreToolUse'; tool_name = 'Bash'; cwd = $Cwd; tool_input = @{ command = $Command } } | ConvertTo-Json -Compress
        Push-Location $Cwd
        try { return (Invoke-Hook 'guard-bash.ps1' $json) } finally { Pop-Location }
    }

    $r = Invoke-UtCase 'git add docs && git commit -m "정리: 문서"' $utTop
    Assert-Case -Name 'untracked-start: 같은 명령의 git add docs 가 회차 전 untracked 를 담으면 경고 (UT-add)' -R $r -ExpectExit 0 -ExpectContains $utMark
    Assert-Case -Name 'untracked-start: 경고가 파일 이름과 rm --cached 를 안내 (UT-add-hint)' -R $r -ExpectExit 0 -ExpectContains 'git rm --cached docs/release.md'
    & git -C $utTop add docs/release.md 2>$null
    $r = Invoke-UtCase 'git commit -m "기능: 항목"' $utTop
    Assert-Case -Name 'untracked-start: 이미 stage 된 회차 전 untracked 도 경고 (UT-staged)' -R $r -ExpectExit 0 -ExpectContains $utMark
    & git -C $utTop reset -q 2>$null
    'new' | Set-Content (Join-Path $utTop 'docs/new.md')
    Remove-Item (Join-Path $utTop 'docs/release.md') -Force
    $r = Invoke-UtCase 'git add docs && git commit -m "정리: 문서"' $utTop
    Assert-Case -Name 'untracked-start (음성): 스냅숏 밖 새 파일만이면 침묵 (UT-new)' -R $r -ExpectExit 0 -ExpectNotContains $utMark
    'old' | Set-Content (Join-Path $utTop 'docs/release.md')
    ("# plan`n`n## Goal`n`n> BASE: 0000000`n") | Set-Content (Join-Path $utTop 'plan.md')
    $r = Invoke-UtCase 'git add docs && git commit -m "정리: 문서"' $utTop
    Assert-Case -Name 'untracked-start (음성): 그 BASE 의 스냅숏 파일이 없으면 침묵 (UT-nosnap)' -R $r -ExpectExit 0 -ExpectNotContains $utMark
    "# plan`n" | Set-Content (Join-Path $utTop 'plan.md')
    $r = Invoke-UtCase 'git add docs && git commit -m "정리: 문서"' $utTop
    Assert-Case -Name 'untracked-start (음성): plan 에 BASE 가 없으면 침묵 (UT-nobase)' -R $r -ExpectExit 0 -ExpectNotContains $utMark

    $utSub = Join-Path $utTop 'sub'
    ("# plan`n`n## Goal`n`n> BASE: $utSha`n") | Set-Content (Join-Path $utSub 'plan.md')
    'old' | Set-Content (Join-Path $utSub 'docs/r.md')
    $utSubSnap = Join-Path $utScratch ('untracked-start-sub-' + $utSha + '.txt')
    $utSubBackup = $null
    if (Test-Path -LiteralPath $utSubSnap) { $utSubBackup = Get-Content -LiteralPath $utSubSnap -Raw }
    "docs/r.md" | Set-Content $utSubSnap
    try {
        $r = Invoke-UtCase 'git add docs && git commit -m "정리: 문서"' $utSub
        Assert-Case -Name 'untracked-start: 하위 폴더 plan 의 스냅숏 경로를 최상위 기준으로 맞춰 경고 (UT-subdir)' -R $r -ExpectExit 0 -ExpectContains $utMark
    } finally {
        if ($null -ne $utSubBackup) { Set-Content -LiteralPath $utSubSnap -Value $utSubBackup -NoNewline } else { Remove-Item -LiteralPath $utSubSnap -Force -ErrorAction SilentlyContinue }
    }
} finally {
    foreach ($s in $utSnaps) { Remove-Item -LiteralPath $s -Force -ErrorAction SilentlyContinue }
    if (Test-Path $utTop) { Remove-Item $utTop -Recurse -Force -ErrorAction SilentlyContinue }
}
}
}
