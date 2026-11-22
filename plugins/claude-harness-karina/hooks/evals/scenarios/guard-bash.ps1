# scenarios/guard-bash.ps1 — guard-bash 로드 가드 시나리오 (dot-source 대상 부재 시 fail-open 가시화) (dot-source 전용, 단독 실행 금지)
if ((Test-HookSelected @('guard-bash')) -and (Test-ScenarioUnit 1)) {
$noLib = Join-Path $work 'dispatch-nolib'; New-Item -ItemType Directory $noLib -Force | Out-Null
Copy-Item (Join-Path $scriptsDir 'guard-bash.ps1') $noLib -Force
Copy-Item (Join-Path $scriptsDir 'git-commit-match.ps1') $noLib -Force
Copy-Item (Join-Path $scriptsDir 'plan-round.ps1') $noLib -Force
$noLibExe = Join-Path $noLib 'guard-bash.ps1'
# cwd 는 plan.md 없는 사본 폴더 — cwd 를 빼면 require-task-checkbox 가 러너 레포의 실제 plan.md 를 읽어 결과가 갈린다.
$outNoLib = (New-CommitJson $noLib 'T1: x') | pwsh -NoProfile -ExecutionPolicy Bypass -File $noLibExe 2>&1
$rNoLib = @{ code = $LASTEXITCODE; out = (($outNoLib | Out-String)).Trim() }
Assert-Case -Name "guard-bash: 라이브러리 부재 시 커밋 명령에 로드 가드 경고 + exit 0 (fail-open 가시화)" -R $rNoLib -ExpectExit 0 -ExpectContains '로드 실패'

# LZ3 (델타 음성): 부재 + 비커밋 읽기 명령 — 경고는 매 호출 나고 판정은 통과다.
$lz = @{ tool_name = 'Bash'; cwd = $noLib; tool_input = @{ command = 'grep -n x plan.md' } } | ConvertTo-Json -Compress
$o = $lz | pwsh -NoProfile -ExecutionPolicy Bypass -File $noLibExe 2>&1
$r = @{ code = $LASTEXITCODE; out = (($o | Out-String)).Trim() }
Assert-Case -Name "guard-bash: 라이브러리 부재 + 비커밋 읽기 명령도 로드 가드 경고 + exit 0 (LZ3)" -R $r -ExpectExit 0 -ExpectContains '로드 실패'

# LZ4 (양성): 부재여도 block-plan-write 차단은 산다 — 종전 코드는 exit 0 으로 통과시켰다.
$lz = @{ tool_name = 'Bash'; cwd = $noLib; tool_input = @{ command = 'echo x > plan.md' } } | ConvertTo-Json -Compress
$o = $lz | pwsh -NoProfile -ExecutionPolicy Bypass -File $noLibExe 2>&1
$r = @{ code = $LASTEXITCODE; out = (($o | Out-String)).Trim() }
Assert-Case -Name "guard-bash: 라이브러리 부재여도 block-plan-write 차단 유지 (LZ4)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'

# LZ5·LZ6 (양성·음성 쌍): 부재여도 require-task-checkbox 가 돈다.
$lzUn = Join-Path $work 'dispatch-nolib-unchecked'; New-Item -ItemType Directory $lzUn -Force | Out-Null
"# plan`n- [ ] T3. 검색 기능" | Set-Content (Join-Path $lzUn 'plan.md')
$lzOk = Join-Path $work 'dispatch-nolib-checked'; New-Item -ItemType Directory $lzOk -Force | Out-Null
"# plan`n- [x] T3. 검색 기능" | Set-Content (Join-Path $lzOk 'plan.md')
$o = (New-CommitJson $lzUn 'T3: 검색 요약') | pwsh -NoProfile -ExecutionPolicy Bypass -File $noLibExe 2>&1
$r = @{ code = $LASTEXITCODE; out = (($o | Out-String)).Trim() }
Assert-Case -Name "guard-bash: 라이브러리 부재여도 미완료 T 커밋 차단 (LZ5)" -R $r -ExpectExit 2 -ExpectContains '완료 커밋인데 plan의 T'
$o = (New-CommitJson $lzOk 'T3: 검색 요약') | pwsh -NoProfile -ExecutionPolicy Bypass -File $noLibExe 2>&1
$r = @{ code = $LASTEXITCODE; out = (($o | Out-String)).Trim() }
Assert-Case -Name "guard-bash: 라이브러리 부재 + 완료 [x] T 커밋은 통과 (LZ6)" -R $r -ExpectExit 0 -ExpectContains '로드 실패'

$stubLib = Join-Path $work 'dispatch-stublib'; New-Item -ItemType Directory $stubLib -Force | Out-Null
Copy-Item (Join-Path $scriptsDir 'guard-bash.ps1') $stubLib -Force
Copy-Item (Join-Path $scriptsDir 'git-commit-match.ps1') $stubLib -Force
Copy-Item (Join-Path $scriptsDir 'timed-git.ps1') $stubLib -Force
Copy-Item (Join-Path $scriptsDir 'plan-round.ps1') $stubLib -Force
New-Item -ItemType Directory (Join-Path $stubLib 'rules') -Force | Out-Null
Copy-Item (Join-Path $scriptsDir 'rules/*.json') (Join-Path $stubLib 'rules') -Force
'Set-Content -LiteralPath (Join-Path $PSScriptRoot ''loaded-cs.txt'') x; function Invoke-WarnCommitSecrets { param($data) New-HookResult }' | Set-Content (Join-Path $stubLib 'guard-commit-secrets.ps1')
'Set-Content -LiteralPath (Join-Path $PSScriptRoot ''loaded-sd.txt'') x; function Invoke-WarnStaleDocs { param($data) New-HookResult }' | Set-Content (Join-Path $stubLib 'guard-stale-docs.ps1')
'Set-Content -LiteralPath (Join-Path $PSScriptRoot ''loaded-ta.txt'') x; function Invoke-WarnTaskAudit { param($data) New-HookResult }' | Set-Content (Join-Path $stubLib 'guard-task-audit.ps1')
'Set-Content -LiteralPath (Join-Path $PSScriptRoot ''loaded-cc.txt'') x; function Invoke-BlockCommitComments { param($data) New-HookResult }' | Set-Content (Join-Path $stubLib 'guard-commit-comments.ps1')
$stubMarks = @((Join-Path $stubLib 'loaded-cs.txt'), (Join-Path $stubLib 'loaded-sd.txt'), (Join-Path $stubLib 'loaded-ta.txt'), (Join-Path $stubLib 'loaded-cc.txt'))
$lz = @{ tool_name = 'Bash'; cwd = $stubLib; tool_input = @{ command = 'ls -la' } } | ConvertTo-Json -Compress
$o = $lz | pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $stubLib 'guard-bash.ps1') 2>&1
$r = @{ code = $(if (@($stubMarks | Where-Object { Test-Path -LiteralPath $_ }).Count) { 1 } else { $LASTEXITCODE }); out = (($o | Out-String)).Trim() }
Assert-Case -Name "guard-bash: 비커밋 명령은 커밋 판정 라이브러리를 dot-source 하지 않는다 (LZ1 — 표식 파일 0개)" -R $r -ExpectExit 0 -ExpectNotContains '로드 실패'
$o = (New-CommitJson $stubLib 'x') | pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $stubLib 'guard-bash.ps1') 2>&1
$r = @{ code = @($stubMarks | Where-Object { Test-Path -LiteralPath $_ }).Count; out = (($o | Out-String)).Trim() }
Assert-Case -Name "guard-bash: 커밋 명령은 커밋 판정 라이브러리 넷을 dot-source 한다 (LZ2 — 표식 파일 4개)" -R $r -ExpectExit 4 -ExpectNotContains '로드 실패'

function Get-CommitLibRedefinitions([string]$Dir) {
    $isFn = { $args[0] -is [System.Management.Automation.Language.FunctionDefinitionAst] }
    $owned = @(foreach ($f in @('guard-bash.ps1', 'git-commit-match.ps1')) {
        [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Dir $f), [ref]$null, [ref]$null).FindAll($isFn, $true) | ForEach-Object Name
    })
    $dups = @(foreach ($lib in @('guard-commit-secrets.ps1', 'guard-stale-docs.ps1', 'guard-task-audit.ps1', 'guard-commit-comments.ps1', 'comment-lines.ps1', 'timed-git.ps1')) {
        [System.Management.Automation.Language.Parser]::ParseFile((Join-Path $Dir $lib), [ref]$null, [ref]$null).FindAll($isFn, $true) |
            Where-Object { $owned -contains $_.Name } | ForEach-Object { $lib + ':' + $_.Name }
    })
    if ($dups.Count) { return 'dup=' + ($dups -join ',') }
    return 'dup=none'
}
$r = @{ code = 0; out = (Get-CommitLibRedefinitions $scriptsDir) }
Assert-Case -Name "guard-bash: 커밋 시점 라이브러리는 디스패처·커밋 판정 함수를 다시 정의하지 않는다" -R $r -ExpectExit 0 -ExpectContains 'dup=none'
$redefLib = Join-Path $work 'dispatch-redef'; New-Item -ItemType Directory $redefLib -Force | Out-Null
foreach ($f in @('guard-bash.ps1', 'git-commit-match.ps1', 'guard-commit-secrets.ps1', 'guard-stale-docs.ps1', 'guard-commit-comments.ps1', 'comment-lines.ps1', 'timed-git.ps1')) { Copy-Item (Join-Path $scriptsDir $f) $redefLib -Force }
('function New-HookResult { param() }' + [Environment]::NewLine + (Get-Content -LiteralPath (Join-Path $scriptsDir 'guard-task-audit.ps1') -Raw)) | Set-Content (Join-Path $redefLib 'guard-task-audit.ps1')
$r = @{ code = 0; out = (Get-CommitLibRedefinitions $redefLib) }
Assert-Case -Name "guard-bash: 라이브러리가 디스패처 함수를 다시 정의하면 그 이름을 짚는다" -R $r -ExpectExit 0 -ExpectContains 'guard-task-audit.ps1:New-HookResult'

$bsJson = @{ tool_name = 'Bash'; cwd = $work; tool_input = @{ command = "python - <<'PY'`nx = 'C:\\'`nprint(len(x))`nPY" } } | ConvertTo-Json -Compress
$bsOs = $env:OS
try {
    $env:OS = 'Linux'
    $r = Invoke-Hook 'guard-bash.ps1' $bsJson
} finally { $env:OS = $bsOs }
Assert-Case -Name "guard-bash: Windows 가 아니면 역슬래시 축소 검사(차단·경고)를 하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains '역슬래시'

$noMatch = Join-Path $work 'dispatch-nomatch'; New-Item -ItemType Directory $noMatch -Force | Out-Null
Copy-Item (Join-Path $scriptsDir 'guard-bash.ps1') $noMatch -Force
$noMatchExe = Join-Path $noMatch 'guard-bash.ps1'
$o = (New-CommitJson $noMatch 'x') | pwsh -NoProfile -ExecutionPolicy Bypass -File $noMatchExe 2>&1
$r = @{ code = $LASTEXITCODE; out = (($o | Out-String)).Trim() }
Assert-Case -Name "guard-bash: 커밋 판정 정의 부재 시 커밋 명령 차단 (LZ7 — fail-closed)" -R $r -ExpectExit 2 -ExpectContains 'git-commit-match.ps1'
$lz = @{ tool_name = 'Bash'; cwd = $noMatch; tool_input = @{ command = 'ls -la' } } | ConvertTo-Json -Compress
$o = $lz | pwsh -NoProfile -ExecutionPolicy Bypass -File $noMatchExe 2>&1
$r = @{ code = $LASTEXITCODE; out = (($o | Out-String)).Trim() }
Assert-Case -Name "guard-bash: 커밋 판정 정의 부재여도 비커밋 명령은 통과 (LZ8 — 음성 짝)" -R $r -ExpectExit 0
}   # ---- 로드 가드 게이트 끝 (guard-bash) ----

# ---- require-task-checkbox 시나리오 흡수 (v1.225.0 — 그 hook이 guard-bash로 합쳐졌다) ----
# scenarios/guard-bash.ps1 — require-task-checkbox 시나리오 (§8 — 디스패처 동등성 포함) (dot-source 전용, 단독 실행 금지)
# 호출자(run-hook-evals.ps1)의 공용 헬퍼(Assert-Case·Invoke-Hook·New-WriteJson·New-CommitJson)와 공유 변수($work·$iso·$gitOk·$pw·$vdCache)를 그대로 쓴다.
# 파일명은 검증 대상 hook 기준이고, Invoke-Hook에 넘기는 문자열은 scripts/ 아래 hook 파일명이다.
# ==== 아래는 본체에서 원문 그대로 옮긴 구간 (순수 이동 — 재조립 등가 검사의 경계) ====
# =====================================================================
# 8) require-task-checkbox 시나리오 (plan 체크박스 게이트 — git 불요, plan 파일만)
# =====================================================================
# hook은 command 문자열 파싱 + plan 파일 Read만 하므로 git repo가 필요 없다.
# 무상태 음성(비커밋·checkpoint·merge 등)은 hook-cases.json, 여기는 plan 상태 필요분.
if (Test-HookSelected @('guard-bash')) {
function New-BashJson([string]$cmd) {
    return (@{ tool_name = 'Bash'; tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress)
}

if (Test-ScenarioUnit 2) {
$rtcUn = Join-Path $work 'rtc-unchecked'; New-Item -ItemType Directory $rtcUn -Force | Out-Null
"# plan`n- [ ] T3. 검색 기능`n- [x] T1. 완료분" | Set-Content (Join-Path $rtcUn 'plan.md')
$rtcIn = Join-Path $work 'rtc-inprog'; New-Item -ItemType Directory $rtcIn -Force | Out-Null
"# plan`n- [/] T3. 진행 중" | Set-Content (Join-Path $rtcIn 'plan.md')
$rtcOk = Join-Path $work 'rtc-checked'; New-Item -ItemType Directory $rtcOk -Force | Out-Null
"# plan`n- [x] T3. 검색 기능" | Set-Content (Join-Path $rtcOk 'plan.md')
$rtcMulti = Join-Path $work 'rtc-multi/docs/plans'; New-Item -ItemType Directory $rtcMulti -Force | Out-Null
"# 과거 회차 plan`n- [ ] T3. x" | Set-Content (Join-Path $rtcMulti '2026-07-01-a.md')

$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcUn 'T3: 검색 요약')
Assert-Case -Name "rtc: 미완료 [ ] T3 커밋 차단 (차단 사유 문구 고정)" -R $r -ExpectExit 2 -ExpectContains '완료 커밋인데 plan의 T'
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcIn 'T3: 검색 요약')
Assert-Case -Name "rtc: 진행중 [/] T3 커밋 차단" -R $r -ExpectExit 2 -ExpectContains 'T3'
$prToday = (Get-Date).ToString('yyyy-MM-dd'); $prYesterday = (Get-Date).AddDays(-1).ToString('yyyy-MM-dd')
function New-PrPlan([string]$Name, [string]$Head) {
    $d = Join-Path $work $Name; New-Item -ItemType Directory $d -Force | Out-Null
    ("# plan`n`n## Goal`n`n" + $Head + "`n`n- [x] **T1-1** a") | Set-Content (Join-Path $d 'plan.md')
    return $d
}
function New-PrCmd([string]$Cwd, [string]$Cmd) { return (@{ tool_name = 'Bash'; cwd = $Cwd; tool_input = @{ command = $Cmd } } | ConvertTo-Json -Compress) }
$prActive = New-PrPlan 'pr-active' "> 승인: $prToday · Y`n> 완료: <implement 가 채움>"
$prDoneToday = New-PrPlan 'pr-done-today' "> 승인: $prYesterday · Y`n> 완료: $prToday 01:50 · 소요 1시간"
$prDoneOld = New-PrPlan 'pr-done-old' "> 승인: $prYesterday · Y`n> 완료: $prYesterday 23:50 · 소요 1시간"
$prDraft = New-PrPlan 'pr-draft' "> 승인: <승인 직후 채움>"
$r = Invoke-Hook 'guard-bash.ps1' (New-PrCmd $prActive 'git push origin main')
Assert-Case -Name "plan-round: 승인된 plan 회차 진행 중 git push 는 외부 작업 경고를 내지 않는다" -R $r -ExpectExit 0 -ExpectNotContains 'EXTERNAL OP'
$r = Invoke-Hook 'guard-bash.ps1' (New-PrCmd $prDoneToday 'gh pr create --title x')
Assert-Case -Name "plan-round: 오늘 완료 기록된 회차의 gh pr create 는 경고를 내지 않는다" -R $r -ExpectExit 0 -ExpectNotContains 'EXTERNAL OP'
$r = Invoke-Hook 'guard-bash.ps1' (New-PrCmd $prDoneOld 'git push origin main')
Assert-Case -Name "plan-round: 어제 끝난 회차의 git push 는 경고한다" -R $r -ExpectExit 0 -ExpectContains 'EXTERNAL OP'
$r = Invoke-Hook 'guard-bash.ps1' (New-PrCmd $prDraft 'git push origin main')
Assert-Case -Name "plan-round: 승인 전 초안 plan 의 git push 는 경고한다" -R $r -ExpectExit 0 -ExpectContains 'EXTERNAL OP'
$r = Invoke-Hook 'guard-bash.ps1' (New-PrCmd $prActive 'git tag v9.9.9')
Assert-Case -Name "plan-round: 회차 진행 중에도 git tag 는 경고한다" -R $r -ExpectExit 0 -ExpectContains 'git tag'
$r = Invoke-Hook 'guard-bash.ps1' (New-PrCmd $prActive 'gh release create v9.9.9')
Assert-Case -Name "plan-round: 회차 진행 중에도 gh release create 는 경고한다" -R $r -ExpectExit 0 -ExpectContains 'gh release create'
$r = Invoke-Hook 'guard-bash.ps1' (New-PrCmd $prActive 'git reset --hard HEAD~1')
Assert-Case -Name "plan-round: 회차 진행 중에도 워킹트리 폐기는 경고한다" -R $r -ExpectExit 0 -ExpectContains 'LOCAL OP'
$prNoLib = Join-Path $work 'pr-nolib'; New-Item -ItemType Directory $prNoLib -Force | Out-Null
Copy-Item (Join-Path $scriptsDir '*') $prNoLib -Recurse -Force -Exclude 'plan-round.ps1'
$r = Invoke-Hook (Join-Path $prNoLib 'guard-bash.ps1') (New-CommitJson $prActive 'x') -Process
Assert-Case -Name "plan-round: 회차 헬퍼(plan-round.ps1)가 없으면 커밋 명령을 막는다" -R $r -ExpectExit 2 -ExpectContains 'plan-round.ps1'
$r = Invoke-Hook (Join-Path $prNoLib 'guard-bash.ps1') (New-PrCmd $prActive 'git status') -Process
Assert-Case -Name "plan-round: 회차 헬퍼가 없어도 커밋이 아닌 명령은 통과한다" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$rtcSub = Join-Path $work 'rtc-sub'; New-Item -ItemType Directory $rtcSub -Force | Out-Null
"# plan`n### T4. 묶음`n- [x] **T4-1** 앞 항목`n- [ ] **T4-2** 뒤 항목`n- [ ] **T4-10** 열째 항목" | Set-Content (Join-Path $rtcSub 'plan.md')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcSub '기능: T4-1 — 앞 항목')
Assert-Case -Name "rtc: 하위 ID 완료 커밋(T4-1 [x])은 형제 T4-2 미완으로 막지 않는다" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$rtcSubUn = Join-Path $work 'rtc-sub-un'; New-Item -ItemType Directory $rtcSubUn -Force | Out-Null
"# plan`n- [ ] **T4-1** 앞 항목`n- [x] **T4-10** 열째 항목" | Set-Content (Join-Path $rtcSubUn 'plan.md')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcSubUn '기능: T4-1 — 앞 항목')
Assert-Case -Name "rtc: 하위 ID 자신이 미완이면 막는다" -R $r -ExpectExit 2 -ExpectContains 'T4-1'
$rtcSub10 = Join-Path $work 'rtc-sub-10'; New-Item -ItemType Directory $rtcSub10 -Force | Out-Null
"# plan`n- [x] **T4-1** 앞 항목`n- [ ] **T4-10** 열째 항목" | Set-Content (Join-Path $rtcSub10 'plan.md')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcSub10 '기능: T4-1 — 앞 항목')
Assert-Case -Name "rtc: 하위 ID T4-1 검사는 T4-10 미완에 걸리지 않는다" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcSub '기능: T4 — 묶음')
Assert-Case -Name "rtc: 상위 ID 완료 커밋(T4)은 하위 미완(T4-2)으로 막는다" -R $r -ExpectExit 2 -ExpectContains 'T4-2'
Assert-Case -Name "rtc: 차단 안내는 Edit 로 [x] 뒤 별도 호출 commit 이고 재시작이 필요한 우회 변수를 권하지 않는다" -R $r -ExpectExit 2 -ExpectNotContains 'CLAUDE_HARNESS_QUICK'
$rtcSp = Join-Path $work 'rtc space dir'; New-Item -ItemType Directory $rtcSp -Force | Out-Null
"# plan`n- [ ] T2. 워커 작업" | Set-Content (Join-Path $rtcSp 'plan.md')
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'Bash'; cwd = $rtcSp; tool_input = @{ command = ('git -C "' + $rtcSp + '" commit -m "기능: T2 — 워커 작업"') } } | ConvertTo-Json -Compress)
Assert-Case -Name "rtc: 공백 경로 -C 커밋도 미완료 T2 차단" -R $r -ExpectExit 2 -ExpectContains '완료 커밋인데 plan의 T'
$rtcB = Join-Path $work 'rtc-b-unchecked'; New-Item -ItemType Directory $rtcB -Force | Out-Null
"# plan`n- [ ] T2. 워커 작업" | Set-Content (Join-Path $rtcB 'plan.md')
$rtcBok = Join-Path $work 'rtc-b-checked'; New-Item -ItemType Directory $rtcBok -Force | Out-Null
"# plan`n- [x] T2. 워커 작업" | Set-Content (Join-Path $rtcBok 'plan.md')
$rtcAun = Join-Path $work 'rtc-a-unchecked'; New-Item -ItemType Directory $rtcAun -Force | Out-Null
"# plan`n- [ ] T2. 다른 작업" | Set-Content (Join-Path $rtcAun 'plan.md')
$rtcAnone = Join-Path $work 'rtc-a-noplan'; New-Item -ItemType Directory $rtcAnone -Force | Out-Null
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'Bash'; cwd = $rtcAnone; tool_input = @{ command = 'cd ../rtc-b-unchecked && git commit -m "기능: T2 — 워커 작업"' } } | ConvertTo-Json -Compress)
Assert-Case -Name "rtc: 앞선 cd 대상 레포의 미완료 T2 차단" -R $r -ExpectExit 2 -ExpectContains '완료 커밋인데 plan의 T'
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'Bash'; cwd = $rtcAnone; tool_input = @{ command = 'git -C ../rtc-b-unchecked commit -m "기능: T2 — 워커 작업"' } } | ConvertTo-Json -Compress)
Assert-Case -Name "rtc: -C 대상 레포의 미완료 T2 차단" -R $r -ExpectExit 2 -ExpectContains '완료 커밋인데 plan의 T'
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'Bash'; cwd = $rtcAun; tool_input = @{ command = 'git -C ../rtc-b-checked commit -m "기능: T2 — 워커 작업"' } } | ConvertTo-Json -Compress)
Assert-Case -Name "rtc: cwd 가 미완료여도 -C 대상 레포가 완료면 통과" -R $r -ExpectExit 0
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcAun '기능: T2 — 다른 작업')
Assert-Case -Name "rtc: -C 없는 cwd 미완료 T2 차단 유지 (음성 짝)" -R $r -ExpectExit 2 -ExpectContains '완료 커밋인데 plan의 T'
$rtcWtRepo = Join-Path $work 'rtc-wt-repo'; New-Item -ItemType Directory (Join-Path $rtcWtRepo '.git') -Force | Out-Null
"# plan`n- [ ] T2. 부모 작업" | Set-Content (Join-Path $rtcWtRepo 'plan.md')
$rtcWt = Join-Path $rtcWtRepo 'wtroot/wt1'; New-Item -ItemType Directory $rtcWt -Force | Out-Null
"gitdir: $rtcWtRepo/.git/worktrees/wt1" | Set-Content (Join-Path $rtcWt '.git')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcWt '기능: T2 — 워커 작업')
Assert-Case -Name "rtc: worktree 커밋은 부모 레포 plan 으로 막지 않는다" -R $r -ExpectExit 0
$rtcWt2 = Join-Path $rtcWtRepo 'wtroot/wt2'; New-Item -ItemType Directory $rtcWt2 -Force | Out-Null
"gitdir: $rtcWtRepo/.git/worktrees/wt2" | Set-Content (Join-Path $rtcWt2 '.git')
"# plan`n- [ ] T2. 워커 작업" | Set-Content (Join-Path $rtcWt2 'plan.md')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcWt2 '기능: T2 — 워커 작업')
Assert-Case -Name "rtc: worktree 자기 plan 미완료는 차단 (음성 짝)" -R $r -ExpectExit 2 -ExpectContains '완료 커밋인데 plan의 T'
$rtcSm = Join-Path $rtcWtRepo 'sub'; New-Item -ItemType Directory $rtcSm -Force | Out-Null
'gitdir: ../.git/modules/sub' | Set-Content (Join-Path $rtcSm '.git')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcSm '기능: T2 — 부모 작업')
Assert-Case -Name "rtc: 서브모듈 커밋은 상위 plan 미완료로 차단 유지 (음성 짝)" -R $r -ExpectExit 2 -ExpectContains '완료 커밋인데 plan의 T'
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcOk 'T3: 검색 요약')
Assert-Case -Name "rtc: 완료 [x] T3 커밋 통과(무출력)" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcUn 'T99: 없는 task')
Assert-Case -Name "rtc: plan에 없는 T번호 통과(fail-open)" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson (Join-Path $work 'rtc-multi') 'T3: x')
Assert-Case -Name "rtc: docs/plans 과거 plan만 존재하면 통과(루트 plan.md 없음)" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcUn 'T1: 이미 완료된 task')
Assert-Case -Name "rtc: [x] T1은 통과·[ ] T3 무관(첫 매치만 판정)" -R $r -ExpectExit 0 -ExpectSilent $true
$rtcStar = Join-Path $work 'rtc-star'; New-Item -ItemType Directory $rtcStar -Force | Out-Null
"# plan`n* [ ] T3. 별표 불릿" | Set-Content (Join-Path $rtcStar 'plan.md')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcStar 'T3: 요약')
Assert-Case -Name "rtc: 별표 불릿 * [ ] T3 커밋 차단 (M6)" -R $r -ExpectExit 2 -ExpectContains 'BLOCKED'

# plan 파일이 아예 없는 프로젝트 → 통과 (fail-open. 상위 탐색은 .git/.claude 경계에서 멈춤)
$rtcNo = Join-Path $work 'rtc-noplan'; New-Item -ItemType Directory $rtcNo -Force | Out-Null
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcNo 'T3: 검색 요약')
Assert-Case -Name "rtc: plan 파일 없음 통과(fail-open)" -R $r -ExpectExit 0 -ExpectSilent $true

# ---- [P1T5] 제목이 아닌 본문·괄호의 T<N> 언급은 판정 제외 (제목 첫 줄만) ----
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcUn '문서: 릴리즈 노트 (T3: 스키마 변경 반영)')
Assert-Case -Name "rtc: 제목이 '문서:'이고 괄호에 T3 언급 → 통과 (P1T5 제목 한정)" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcUn 'T3: 실제 완료 커밋')
Assert-Case -Name "rtc: 제목이 T3:로 시작 → 미완료 차단 유지 (P1T5)" -R $r -ExpectExit 2 -ExpectContains 'BLOCKED'

# ---- [회차 44 T4] 현행 제목 형식 `{유형}: T<N> — …` + 템플릿 볼드 하위 항목 `- [ ] **T3-1**` ----
#   종전 정규식은 구형 `T3:` 제목과 비볼드 체크박스만 받아 현행 회차에서 한 번도 발화하지 않았다(게이트 사문화).
#   양성 2(신형 제목 · heredoc 제목) + 완료 통과 1 + 델타 음성 1(유형 뒤가 T 가 아닌 제목).
$rtcBold = Join-Path $work 'rtc-bold'; New-Item -ItemType Directory $rtcBold -Force | Out-Null
"# plan`n### T3. 검색`n- [ ] **T3-1** 검색 요약`n- [x] **T3-2** 인덱스" | Set-Content (Join-Path $rtcBold 'plan.md')
$rtcBoldOk = Join-Path $work 'rtc-bold-ok'; New-Item -ItemType Directory $rtcBoldOk -Force | Out-Null
"# plan`n### T3. 검색`n- [x] **T3-1** 검색 요약`n- [x] **T3-2** 인덱스" | Set-Content (Join-Path $rtcBoldOk 'plan.md')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcBold '기능: T3 — 검색 요약')
Assert-Case -Name "rtc: 신형 제목 기능: T3 — + 볼드 하위 항목 미완료 → 차단 (회차 44 T4)" -R $r -ExpectExit 2 -ExpectContains '완료 커밋인데 plan의 T'
Assert-Case -Name "rtc: 차단 안내가 중간 커밋 제목에서 T<N> — 를 빼라고 알린다" -R $r -ExpectExit 2 -ExpectContains '(T3 진행)'
$heredocMsg = [string]::Join("`n", @('$(cat <<''EOF''', '기능: T3 — 검색 요약', '', '본문', 'EOF', ')'))
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcBold $heredocMsg)
Assert-Case -Name "rtc: heredoc 제목(-m 뒤 cat heredoc 본문) 도 둘째 줄을 제목으로 읽어 차단 (회차 44 T4)" -R $r -ExpectExit 2 -ExpectContains 'BLOCKED'
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcBoldOk '기능: T3 — 검색 요약')
Assert-Case -Name "rtc: 볼드 하위 항목 전부 [x] → 신형 제목 통과(무출력) (회차 44 T4)" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcBold '설정: v1.258.0 — 회차 44: T3 정리')
Assert-Case -Name "rtc: 유형 뒤가 T<N> 이 아닌 제목은 판정 제외 (회차 44 T4 델타 음성)" -R $r -ExpectExit 0 -ExpectSilent $true

$rtcBt = '```'
$rtcDash = Join-Path $work 'rtc-dash'; New-Item -ItemType Directory $rtcDash -Force | Out-Null
"# plan`n### T3. 검색`n- [x] **T3-1** 검색 요약`n- [-] **T3-2** 인덱스" | Set-Content (Join-Path $rtcDash 'plan.md')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcDash '기능: T3 — 검색 요약')
Assert-Case -Name "rtc: [-] 하위 항목이 남은 T3 커밋 차단" -R $r -ExpectExit 2 -ExpectContains '완료 커밋인데 plan의 T'
$rtcNum = Join-Path $work 'rtc-num'; New-Item -ItemType Directory $rtcNum -Force | Out-Null
"# plan`n### T3. 검색`n1. [x] **T3-1** 검색 요약`n2. [ ] **T3-2** 인덱스" | Set-Content (Join-Path $rtcNum 'plan.md')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcNum '기능: T3 — 검색 요약')
Assert-Case -Name "rtc: 번호 불릿 1. [ ] 하위 항목이 남은 T3 커밋 차단" -R $r -ExpectExit 2 -ExpectContains '완료 커밋인데 plan의 T'
$rtcPlus = Join-Path $work 'rtc-plus'; New-Item -ItemType Directory $rtcPlus -Force | Out-Null
"# plan`n### T3. 검색`n+ [ ] T3 검색 요약" | Set-Content (Join-Path $rtcPlus 'plan.md')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcPlus '기능: T3 — 검색 요약')
Assert-Case -Name "rtc: + 불릿 미완 T3 커밋 차단" -R $r -ExpectExit 2 -ExpectContains '완료 커밋인데 plan의 T'
$rtcNumOk = Join-Path $work 'rtc-num-ok'; New-Item -ItemType Directory $rtcNumOk -Force | Out-Null
"# plan`n### T3. 검색`n1. [x] T3 검색 요약`n2. T3 메모 — 체크박스 없는 번호 줄" | Set-Content (Join-Path $rtcNumOk 'plan.md')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcNumOk '기능: T3 — 검색 요약')
Assert-Case -Name "rtc: 번호 불릿 [x] 와 체크박스 없는 번호 줄뿐인 T3 커밋 통과(무출력) (델타 음성)" -R $r -ExpectExit 0 -ExpectSilent $true
$rtcFence = Join-Path $work 'rtc-fence'; New-Item -ItemType Directory $rtcFence -Force | Out-Null
"# plan`n### T3. 검색`n- [x] **T3-1** 검색 요약`n$($rtcBt)markdown`n- [ ] **T3-9** 서식 예시`n$rtcBt" | Set-Content (Join-Path $rtcFence 'plan.md')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcFence '기능: T3 — 검색 요약')
Assert-Case -Name "rtc: 펜스 안 예시만 미완인 T3 커밋 통과(무출력)" -R $r -ExpectExit 0 -ExpectSilent $true
$rtcUpper = Join-Path $work 'rtc-upper'; New-Item -ItemType Directory $rtcUpper -Force | Out-Null
"# plan`n### T3. 검색`n- [X] **T3-1** 검색 요약`n- [X] **T3-2** 인덱스" | Set-Content (Join-Path $rtcUpper 'plan.md')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcUpper '기능: T3 — 검색 요약')
Assert-Case -Name "rtc: [X] 뿐인 T3 커밋 통과(무출력) (델타 음성)" -R $r -ExpectExit 0 -ExpectSilent $true
$rtcUnneeded = Join-Path $work 'rtc-unneeded'; New-Item -ItemType Directory $rtcUnneeded -Force | Out-Null
"# plan`n### T3. 검색`n- [x] (불요 — 이미 있음) **T3-1** 검색 요약" | Set-Content (Join-Path $rtcUnneeded 'plan.md')
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcUnneeded '기능: T3 — 검색 요약')
Assert-Case -Name "rtc: [x] (불요 뿐인 T3 커밋 통과(무출력) (델타 음성)" -R $r -ExpectExit 0 -ExpectSilent $true

$rfJ = { param($cwd, $cmd, $tool = 'Bash') (@{ tool_name = $tool; cwd = $cwd; tool_input = @{ command = $cmd } } | ConvertTo-Json -Compress) }
$rfUn = Join-Path $work 'rf-unchecked'; New-Item -ItemType Directory $rfUn -Force | Out-Null
"# plan`n- [ ] T3. 검색 기능" | Set-Content (Join-Path $rfUn 'plan.md')
"T3: 검색 요약`n`n본문" | Set-Content (Join-Path $rfUn 'msg.txt')
"정리: 문서`n`nT3: 본문에만" | Set-Content (Join-Path $rfUn 'msg2.txt')
$rfOk = Join-Path $work 'rf-checked'; New-Item -ItemType Directory $rfOk -Force | Out-Null
"# plan`n- [x] T3. 검색 기능" | Set-Content (Join-Path $rfOk 'plan.md')
"T3: 검색 요약" | Set-Content (Join-Path $rfOk 'msg.txt')
$rfNoPlan = Join-Path $work 'rf-noplan'; New-Item -ItemType Directory $rfNoPlan -Force | Out-Null
$rfTmpName = 'karina-rf-msg-' + [guid]::NewGuid().ToString('N') + '.txt'
"T3: 검색 요약" | Set-Content (Join-Path $env:TEMP $rfTmpName)
$rfBlock = '완료 커밋인데 plan의 T'
$rfWarn = '제목을 읽지 못해'

$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn 'git commit -F msg.txt')
Assert-Case -Name "rf: -F 파일 첫 줄 T3 + 미완료 → 차단 (RF1)" -R $r -ExpectExit 2 -ExpectContains $rfBlock
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn "git commit -F - <<'MSG'`nT3: 검색 요약`n`n본문`nMSG")
Assert-Case -Name "rf: -F - heredoc 본문 첫 줄 T3 + 미완료 → 차단 (RF2)" -R $r -ExpectExit 2 -ExpectContains $rfBlock
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn "@'`nT3: 검색 요약`n본문`n'@ | git commit -F -" 'PowerShell')
Assert-Case -Name "rf: PowerShell here-string | -F - 첫 줄 T3 + 미완료 → 차단 (RF3)" -R $r -ExpectExit 2 -ExpectContains $rfBlock
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn "git commit -m '기능: T3 — 검색 요약`n`n본문'" 'PowerShell')
Assert-Case -Name "rf: PowerShell 여러 줄 작은따옴표 -m 첫 줄 T3 + 미완료 → 차단 (RF4 무회귀)" -R $r -ExpectExit 2 -ExpectContains $rfBlock
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn "git commit -m @'`nT3: 검색 요약`n본문`n'@" 'PowerShell')
Assert-Case -Name "rf: PowerShell -m @' here-string 다음 줄 T3 + 미완료 → 차단 (RF5)" -R $r -ExpectExit 2 -ExpectContains $rfBlock
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfOk 'git commit -F msg.txt')
Assert-Case -Name "rf: -F 파일 T3 + 완료 [x] → 통과(무출력) (RF6)" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn "git commit -F - <<'MSG'`n정리: 문서`nT3: 둘째 줄`nMSG")
Assert-Case -Name "rf: -F - 본문 첫 줄이 T 아님(둘째 줄 T3) → 통과(무출력) (RF7 델타 음성)" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn 'git commit -F msg2.txt')
Assert-Case -Name "rf: -F 파일 첫 줄이 T 아님 → 통과(무출력) (RF8 델타 음성)" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn 'git commit -m $msg')
Assert-Case -Name "rf: 변수 -m + plan 있음 → 경고·통과 (RF9)" -R $r -ExpectExit 0 -ExpectContains $rfWarn
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn 'git commit -F missing.txt')
Assert-Case -Name "rf: 없는 -F 파일 + plan 있음 → 경고·통과 (RF10)" -R $r -ExpectExit 0 -ExpectContains $rfWarn
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn ('git commit -F /tmp/' + $rfTmpName))
Assert-Case -Name "rf: -F /tmp/… 를 TEMP 로 변환해 첫 줄 T3 + 미완료 → 차단 (RF11)" -R $r -ExpectExit 2 -ExpectContains $rfBlock
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn "git commit -F - <<'MSG'`nT3: 검색 요약`n`n변수 -m 이면 경고`nMSG")
Assert-Case -Name "rf: -F - 본문 속 ' -m ' 을 -m 으로 오인하지 않는다 → 차단 (RF12)" -R $r -ExpectExit 2 -ExpectContains $rfBlock
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn 'grep -F x msg.txt; git commit -a')
Assert-Case -Name "rf: 다른 명령의 -F 는 커밋 파일이 아니다 → 통과(무출력) (RF13 델타 음성)" -R $r -ExpectExit 0 -ExpectSilent $true
$rfUnFwd = $rfUn -replace '\\', '/'
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn ('S="' + $rfUnFwd + '"; git add a && git commit -q -F "$S/msg.txt"'))
Assert-Case -Name "rf: 같은 명령의 S=`"…`" 대입으로 -F `"`$S/msg.txt`" 를 펼쳐 첫 줄 T3 + 미완료 → 차단 (RF18)" -R $r -ExpectExit 2 -ExpectContains $rfBlock
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn ("M='msg.txt'; git commit -F " + '"${M}"'))
Assert-Case -Name "rf: `${M} 꼴과 작은따옴표 대입도 펼친다 → 차단 (RF19)" -R $r -ExpectExit 2 -ExpectContains $rfBlock
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn ("cat > fresh-msg.txt <<'X'`nT3: 검색 요약`nX`ngit commit -F fresh-msg.txt"))
Assert-Case -Name "rf: 같은 명령의 cat > 파일 heredoc 본문을 -F 메시지로 받는다(파일 미존재) → 차단 (RF20)" -R $r -ExpectExit 2 -ExpectContains $rfBlock
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn 'git commit -F "$UNSET_DIR/msg.txt"')
Assert-Case -Name "rf: 대입 없는 변수 -F 경로는 기존대로 경고·통과 (RF21)" -R $r -ExpectExit 0 -ExpectContains $rfWarn
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn 'printf x | git commit -F -')
Assert-Case -Name "rf: -F - 인데 같은 명령에 본문 없음 + plan 있음 → 경고·통과 (RF14)" -R $r -ExpectExit 0 -ExpectContains $rfWarn
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfNoPlan 'git commit -m $msg')
Assert-Case -Name "rf: 변수 -m + plan 없음 → 통과(무출력) (RF15)" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn "git commit -m '`$5 수정'")
Assert-Case -Name "rf: 작은따옴표 리터럴 '`$5…' 는 변수가 아니다 → 통과(무출력) (RF16)" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'guard-bash.ps1' (& $rfJ $rfUn "@'`nT3: 검색 요약`n`n변수 -m 이면 경고`n'@ | git commit -F -" 'PowerShell')
Assert-Case -Name "rf: here-string 본문 속 ' -m ' 을 -m 으로 오인하지 않는다 → 차단 (RF17)" -R $r -ExpectExit 2 -ExpectContains $rfBlock
Remove-Item -LiteralPath (Join-Path $env:TEMP $rfTmpName) -ErrorAction SilentlyContinue

# QUICK 우회 — 별도 stderr 안내 출력이 있는 독립 분기 (silent 아님, exit 0)
$env:CLAUDE_HARNESS_QUICK = '1'
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcUn 'T3: 검색 요약')
Assert-Case -Name "rtc: QUICK=1 우회 (비차단 + 안내)" -R $r -ExpectExit 0 -ExpectContains 'QUICK'
$env:CLAUDE_HARNESS_QUICK = $null

# ---- [v1.99.0 T6] rtc 스테이트풀 케이스 디스패처 동등성 (plan cwd 필요분) ----
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcUn 'T3: 검색 요약')
Assert-Case -Name "dispatch=rtc: 미완료 [ ] T3 커밋 차단" -R $r -ExpectExit 2 -ExpectContains 'BLOCKED'
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcOk 'T3: 검색 요약')
Assert-Case -Name "dispatch=rtc: 완료 [x] T3 커밋 통과(무출력)" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'guard-bash.ps1' (New-CommitJson $rtcUn '문서: 릴리즈 노트 (T3: 반영)')
Assert-Case -Name "dispatch=rtc: 제목 아닌 T3 언급 통과 (제목 한정)" -R $r -ExpectExit 0 -ExpectSilent $true
}

if (Test-ScenarioUnit 3) {

$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "python - <<'PY'`np='plan.md'`ns=open(p).read()`nopen(p,'w').write(s)`nPY")
Assert-Case -Name "bpw: python open(p,'w') 로 plan.md 쓰기 차단 (BPW1)" -R $r -ExpectExit 2 -ExpectContains 'plan.md 를 스크립트로 쓰려 합니다'

# BPW2 (델타 음성 — 읽기): 조회는 막지 않는다. 막으면 실측·조사 자체가 불가능해진다.
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "grep -n 'Deferred' plan.md")
Assert-Case -Name "bpw: plan.md 읽기는 통과 (BPW2)" -R $r -ExpectExit 0 -ExpectSilent $true

# BPW3 (델타 음성 — 읽어서 다른 파일로): 리다이렉션 **대상**이 plan.md 가 아니다.
#   이 케이스가 없으면 「명령에 plan.md 와 `>` 가 있으면 막는다」로 구현해도 전건 green 이다.
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'head -12 plan.md > /tmp/plan_head.txt')
Assert-Case -Name "bpw: plan.md 를 읽어 다른 파일로 내보내는 형태는 통과 (BPW3)" -R $r -ExpectExit 0 -ExpectSilent $true

# BPW4 (델타 음성 — 다른 파일 쓰기): plan.md 를 언급조차 하지 않는 스크립트 쓰기.
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "python - <<'PY'`nopen('notes.md','w').write('x')`nPY")
Assert-Case -Name "bpw: 다른 파일을 쓰는 인라인 스크립트는 통과 (BPW4)" -R $r -ExpectExit 0 -ExpectSilent $true

# BPW5 (델타 음성 — 대상은 다른 파일인데 명령 텍스트에 plan.md 가 있다): 계획 리뷰 BLOCKER 를 고정한다.
#   sed -i 의 대상은 **마지막 위치 인자**이고 패턴 문자열 안의 plan.md 는 대상이 아니다.
#   초안 설계(「언급 ∧ 쓰기 신호」)면 회차 51 자신의 T4-1 이 이 형태라 스스로 차단됐다.
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "sed -i '/plan.md 를 스크립트로 후편집/d' docs/plans/deferred.md")
Assert-Case -Name "bpw: sed -i 패턴 안의 plan.md 는 대상이 아니다 (BPW5)" -R $r -ExpectExit 0 -ExpectSilent $true

# BPW6 (델타 음성 — 쓰기 동사를 본문에 담은 조회): 완료 리뷰 BLOCKER 를 고정한다.
#   쓰기 동사를 세그먼트 어디서나 찾으면 이 조회가 막힌다. 하필 이 회차의 plan.md·rationale 이
#   그 단어들을 담고 있어, 다음 세션이 자기 plan 을 grep 하는 순간 차단됐다(실측 5형태).
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "grep -n 'Copy-Item' plan.md")
Assert-Case -Name "bpw: 쓰기 동사를 본문에 담은 plan.md 조회는 통과 (BPW6)" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "grep -n Set-Content plan.md")
Assert-Case -Name "bpw: 쓰기 cmdlet 이름을 찾는 조회도 통과 (BPW6b)" -R $r -ExpectExit 0 -ExpectSilent $true

# BPW7~9 (양성 — 나머지 신호): 신호마다 양성이 없으면 그 분기를 지워도 전건 green 이다
#   (완료 리뷰 MAJOR — 7신호 중 6개가 음성으로만 등장했다).
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "echo x > plan.md")
Assert-Case -Name "bpw: 리다이렉션 대상이 plan.md 면 차단 (BPW7)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "sed -i 's/a/b/' plan.md")
Assert-Case -Name "bpw: sed -i 의 대상이 plan.md 면 차단 (BPW8)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
# ⚠ named parameter 형이 PowerShell 표준이다 — 위치 인자만 막으면 실사용 형태가 샌다.
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "Set-Content -Path plan.md -Value 'x'")
Assert-Case -Name "bpw: Set-Content -Path plan.md 차단 (BPW9)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "python -c ""p='plan.md'; open(p,'w').write('x')""")
Assert-Case -Name "bpw: 한 줄 -c 형태의 변수 대입도 역참조 (BPW10)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'

$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'echo x > ../plan.md')
Assert-Case -Name "bpw: 상위 경로 plan.md 리다이렉션 차단 (BPW11 미탐 보완)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "sed -i 's/a/b/' /d/repo/plan.md")
Assert-Case -Name "bpw: 절대 경로 plan.md 의 sed -i 차단 (BPW12 미탐 보완)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "Set-Content -Path 'C:\r\plan.md' -Value x")
Assert-Case -Name "bpw: 백슬래시 경로 plan.md 의 Set-Content 차단 (BPW13 미탐 보완)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'echo x > "D:\Personal Project\r\plan.md"')
Assert-Case -Name "bpw: 따옴표로 감싼 공백 경로 plan.md 리다이렉션 차단 (BPW14 미탐 보완)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'python -c "from pathlib import Path; Path(''plan.md'').write_text(''x'')"')
Assert-Case -Name "bpw: pathlib write_text 로 plan.md 쓰기 차단 (BPW15 미탐 보완)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'python -c "import pathlib; pathlib.Path(''../plan.md'').open(''w'').write(''x'')"')
Assert-Case -Name "bpw: pathlib open(w) 로 상위 경로 plan.md 쓰기 차단 (BPW16 미탐 보완)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'

$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'cat ../plan.md')
Assert-Case -Name "bpw: 상위 경로 plan.md 조회는 통과 (BPW17 델타 음성)" -R $r -ExpectExit 0 -ExpectNotContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'echo x > myplan.md')
Assert-Case -Name "bpw: plan.md 로 끝나는 다른 이름 myplan.md 쓰기는 통과 (BPW18 델타 음성)" -R $r -ExpectExit 0 -ExpectNotContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'cp plan.md plan.md.bak')
Assert-Case -Name "bpw: plan.md 를 plan.md.bak 으로 복사하는 것은 통과 (BPW19 델타 음성)" -R $r -ExpectExit 0 -ExpectNotContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'python -c "from pathlib import Path; print(Path(''plan.md'').read_text())"')
Assert-Case -Name "bpw: pathlib read_text 조회는 통과 (BPW20 델타 음성)" -R $r -ExpectExit 0 -ExpectNotContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'python -c "from pathlib import Path; Path(''plan.md'').open().read()"')
Assert-Case -Name "bpw: 모드 없는 pathlib open 조회는 통과 (BPW21 델타 음성)" -R $r -ExpectExit 0 -ExpectNotContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'python -c "from pathlib import Path; Path(''notes.md'').write_text(''x'')"')
Assert-Case -Name "bpw: pathlib 로 다른 파일 쓰기는 통과 (BPW22 델타 음성)" -R $r -ExpectExit 0 -ExpectNotContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'echo x > "D:\Personal Project\r\notes.md"')
Assert-Case -Name "bpw: 따옴표 공백 경로의 다른 파일 리다이렉션은 통과 (BPW23 델타 음성)" -R $r -ExpectExit 0 -ExpectNotContains '스크립트로 쓰려 합니다'

# ST1 (양성 — ②의 본체): 회차 51 이 실측한 유일한 MISS 형태.
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'sed -i "s|a|b|" plan.md')
Assert-Case -Name "split: 따옴표 안의 | 가 든 sed -i 도 plan.md 쓰기로 차단 (ST1)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'

# ST2 (경고 축 — warn-global-find): 따옴표 안의 `;` 가 분할을 깨면 뒤 세그먼트의 find 를 놓친다.
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'echo "a;b" && find / -name x')
Assert-Case -Name "split: 따옴표 안 ; 뒤의 루트 전역 탐색을 여전히 잡는다 (ST2)" -R $r -ExpectExit 0 -ExpectContains '[GLOBAL FIND WARNING]'

# ST3 (경고 축 — warn-dangerous-assignment): 대입값 자체가 따옴표 안 구분자를 담은 형태.
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'echo "x|y"; X=/; rm -rf $X')
Assert-Case -Name "split: 따옴표 안 | 가 있어도 위험 대입 경고가 산다 (ST3)" -R $r -ExpectExit 0 -ExpectContains '[DANGEROUS ASSIGNMENT WARNING]'

# ST4 (경고 축 — warn-external-ops): 같은 형태로 외부 작업 경고가 살아 있는지.
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'echo "a|b" && git push origin main')
Assert-Case -Name "split: 따옴표 안 | 뒤의 git push 를 여전히 잡는다 (ST4)" -R $r -ExpectExit 0 -ExpectContains '[EXTERNAL OP WARNING]'
# ST4b·ST4c (경고 문면): 승인 경계를 현행 규칙으로 말하는가 — 새 문면(양성)과 죽은 규칙 번호(음성)를 갈라 잰다.
Assert-Case -Name "split: 외부 작업 경고가 별도 승인 대상을 말한다 (ST4b)" -R $r -ExpectExit 0 -ExpectContains '별도 승인 대상'
Assert-Case -Name "split: 외부 작업 경고에 죽은 규칙 번호가 없다 (ST4c)" -R $r -ExpectExit 0 -ExpectNotContains '규칙 12'

# ST5 (도구별 이스케이프): PowerShell 도구에서 `\` 는 리터럴이라 `"C:\"` 가 닫힌 문자열이고
#   뒤의 `;` 가 구분자로 선다. bash 규칙으로 읽으면 인용이 열린 채 남아 분리가 안 된다(회차 44).
$psJson = (@{ tool_name = 'PowerShell'; tool_input = @{ command = 'echo "C:\"; X=/; Remove-Item -Recurse -Force $X' } } | ConvertTo-Json -Compress)
$r = Invoke-Hook 'guard-bash.ps1' $psJson
Assert-Case -Name 'split: PowerShell 도구의 "C:\" 뒤 세그먼트를 잃지 않는다 (ST5)' -R $r -ExpectExit 0 -ExpectContains '[DANGEROUS ASSIGNMENT WARNING]'

# ST6 (메시지 스트립 — D6): warn-external-ops 만 $cmd 가 아니라 $scanCmd 를 분할한다.
#   $cmd 를 넘기면 따옴표 인식이 메시지를 **한 세그먼트로 보존**해 그 안의 push 에 오경고가 난다.
#   착수 시점에 이 형태(단일 세그먼트)를 재는 케이스가 0건이었다.
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'git commit -m "will git push later"')
Assert-Case -Name "split: 커밋 메시지 안의 git push 는 경고하지 않는다 (ST6)" -R $r -ExpectExit 0 -ExpectSilent $true

# ST7~9 (③ 양성 — 신호 3종): cp/mv · Copy-Item 계열 · [System.IO.File]::WriteAll* 는
#   착수 시점에 양성이 하나도 없어 **그 분기를 지워도 전건 green** 이었다.
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'cp notes.md plan.md')
Assert-Case -Name "bpw: cp 의 마지막 인자가 plan.md 면 차단 (ST7)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'Copy-Item notes.md plan.md')
Assert-Case -Name "bpw: Copy-Item 의 대상이 plan.md 면 차단 (ST8)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "pwsh -c ""[System.IO.File]::WriteAllText('plan.md','x')""")
Assert-Case -Name "bpw: [System.IO.File]::WriteAllText 의 첫 인자가 plan.md 면 차단 (ST9)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'

$pyDir = Join-Path $work 'py-newcode'; New-Item -ItemType Directory $pyDir -Force | Out-Null
"from pathlib import Path`np = Path('src/view.rs')`np.write_text(p.read_text() + '''`n/// 새 설명`nfn added() {}`n''')`n" | Set-Content -LiteralPath (Join-Path $pyDir 'gen.py') -Encoding utf8
"from pathlib import Path`np = Path('src/view.rs')`np.write_text(p.read_text().replace('old_name', 'new_name'))`n" | Set-Content -LiteralPath (Join-Path $pyDir 'ren.py') -Encoding utf8
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'Bash'; cwd = $pyDir; tool_input = @{ command = 'python -I gen.py' } } | ConvertTo-Json -Compress)
Assert-Case -Name "python 새 코드: Write 로 만든 .py 를 python 으로 돌려 새 /// 를 쓰면 차단 (PN-file)" -R $r -ExpectExit 2 -ExpectContains 'python 스크립트로 소스 파일에 새 코드·주석을 씁니다'
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'PowerShell'; cwd = $work; tool_input = @{ command = "python `"$(Join-Path $pyDir 'gen.py')`"" } } | ConvertTo-Json -Compress)
Assert-Case -Name "python 새 코드: PowerShell 도구의 python <파일.py> 도 같은 판정 (PN-ps)" -R $r -ExpectExit 2 -ExpectContains 'python 스크립트로 소스 파일에 새 코드·주석을 씁니다'
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'Bash'; cwd = $pyDir; tool_input = @{ command = 'python ren.py' } } | ConvertTo-Json -Compress)
Assert-Case -Name "python 새 코드 (음성): .py 파일의 한 줄 치환은 통과 (PN-file-neg)" -R $r -ExpectExit 0 -ExpectNotContains 'python 스크립트로 소스 파일에 새 코드·주석을 씁니다'

$pyRepo = Join-Path $work 'py-tracked'; New-Item -ItemType Directory $pyRepo -Force | Out-Null
git -C $pyRepo init -q 2>&1 | Out-Null
Copy-Item (Join-Path $pyDir 'gen.py') (Join-Path $pyRepo 'gen.py') -Force
git -C $pyRepo add gen.py 2>&1 | Out-Null
git -C $pyRepo -c user.name=t -c user.email=t@t -c commit.gpgsign=false commit -q -m init 2>&1 | Out-Null
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'Bash'; cwd = $pyRepo; tool_input = @{ command = 'python gen.py' } } | ConvertTo-Json -Compress)
Assert-Case -Name "python 새 코드 (음성): 커밋돼 바뀌지 않은 .py 실행은 통과 (PN-tracked 오탐 수정)" -R $r -ExpectExit 0 -ExpectNotContains 'python 스크립트로 소스 파일에 새 코드·주석을 씁니다'
Copy-Item (Join-Path $pyDir 'gen.py') (Join-Path $pyRepo 'new.py') -Force
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'Bash'; cwd = $pyRepo; tool_input = @{ command = 'python new.py' } } | ConvertTo-Json -Compress)
Assert-Case -Name "python 새 코드: 레포 안 미추적 .py 실행은 차단 유지 (PN-untracked)" -R $r -ExpectExit 2 -ExpectContains 'python 스크립트로 소스 파일에 새 코드·주석을 씁니다'
Add-Content -LiteralPath (Join-Path $pyRepo 'gen.py') -Value 'x = 1' -Encoding utf8
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'Bash'; cwd = $pyRepo; tool_input = @{ command = 'python gen.py' } } | ConvertTo-Json -Compress)
Assert-Case -Name "python 새 코드 (음성): 커밋 뒤 코드 문자열 없이 수정한 .py 실행은 통과 — HEAD 에 있던 문자열은 판정하지 않는다 (PN-modified 오탐 수정)" -R $r -ExpectExit 0 -ExpectNotContains 'python 스크립트로 소스 파일에 새 코드·주석을 씁니다'
Add-Content -LiteralPath (Join-Path $pyRepo 'gen.py') -Value "p.write_text(p.read_text() + '''`n/// 수정으로 더한 설명`nfn later() {}`n''')" -Encoding utf8
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'Bash'; cwd = $pyRepo; tool_input = @{ command = 'python gen.py' } } | ConvertTo-Json -Compress)
Assert-Case -Name "python 새 코드: 커밋 뒤 수정으로 새 /// 문자열을 더한 .py 실행은 차단 (PN-modified-newcode)" -R $r -ExpectExit 2 -ExpectContains 'python 스크립트로 소스 파일에 새 코드·주석을 씁니다'

$pnMsg = 'python 스크립트로 소스 파일에 새 코드·주석을 씁니다'
$snMsg = '셸 명령으로 소스 파일에 새 코드·주석을 씁니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "python - <<'EOF'`np='src/fixture.rs'`nt=open(p).read()`nt=t.replace('    projects: P,\n}', '    projects: P,\n    dir: PathBuf,\n}')`nopen(p,'w').write(t)`nEOF")
Assert-Case -Name "python 새 코드: pub 없는 새 필드 줄 → 차단 (PN-field)" -R $r -ExpectExit 2 -ExpectContains $pnMsg
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "python - <<'EOF'`np='cfg.yaml'`nopen(p,'w').write('name: x\nport: 1\n')`nEOF")
Assert-Case -Name "python 새 코드 (음성): yaml 키 줄은 필드로 보지 않는다 (PN-field-yaml)" -R $r -ExpectExit 0 -ExpectNotContains $pnMsg
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "sed -i '12s|    projects: P,|    projects: P,\n    dir: PathBuf,|' src/fixture.rs")
Assert-Case -Name "셸 새 코드: sed 다줄 치환으로 새 필드 → 차단 (SN-sed-multi)" -R $r -ExpectExit 2 -ExpectContains $snMsg
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "sed -i '112s|/// 옛 설명이다|/// 새로 쓴 설명이다|' src/refresh.rs")
Assert-Case -Name "셸 새 코드: sed 한 줄 치환으로 doc 주석 줄 교체 → 차단 (SN-sed-comment)" -R $r -ExpectExit 2 -ExpectContains $snMsg
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "sed -i '3a\    pub x: u8,' src/a.rs")
Assert-Case -Name "셸 새 코드: sed a 명령으로 새 필드 줄 추가 → 차단 (SN-sed-append)" -R $r -ExpectExit 2 -ExpectContains $snMsg
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "printf '\npub fn probe(line: &str) {\n}\n' >> src/a.rs")
Assert-Case -Name "셸 새 코드: printf >> 로 새 fn → 차단 (SN-printf)" -R $r -ExpectExit 2 -ExpectContains $snMsg
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "echo -e '\nfn added() {}' >> src/a.rs")
Assert-Case -Name "셸 새 코드: echo -e >> 로 새 fn → 차단 (SN-echo)" -R $r -ExpectExit 2 -ExpectContains $snMsg
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "cat >> src/a.rs <<'X'`nfn added() {}`nX")
Assert-Case -Name "셸 새 코드: cat >> heredoc 으로 새 fn → 차단 (SN-cat)" -R $r -ExpectExit 2 -ExpectContains $snMsg
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "tee -a src/a.rs <<'X'`npub fn added() {}`nX")
Assert-Case -Name "셸 새 코드: tee -a heredoc 으로 새 fn → 차단 (SN-tee)" -R $r -ExpectExit 2 -ExpectContains $snMsg
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "sed -i '419s| origin_url: None,| origin_url: Some(x),|' src/refresh.rs")
Assert-Case -Name "셸 새 코드 (음성): sed 한 줄 값 치환은 통과 (SN-sed-value)" -R $r -ExpectExit 0 -ExpectNotContains $snMsg
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "sed -i '140s| origin_url: None,| origin_url: remote\n    .github_slug\n    .map(f),|' src/refresh.rs")
Assert-Case -Name "셸 새 코드 (음성): 같은 이름 필드의 값을 다줄로 바꾸는 sed 는 통과 (SN-sed-samefield)" -R $r -ExpectExit 0 -ExpectNotContains $snMsg
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "printf -- '- a\n- b\n' >> docs/x.md")
Assert-Case -Name "셸 새 코드 (음성): 대상 확장자 밖(.md) printf 는 통과 (SN-printf-md)" -R $r -ExpectExit 0 -ExpectNotContains $snMsg
}

if (Test-ScenarioUnit 3) {
$bwMark = '[SCREEN BASELINE WARNING]'
function New-BwRepo([string]$Name, [string]$VerifyLine) {
    $d = Join-Path $work $Name
    New-Item -ItemType Directory (Join-Path $d '.git') -Force | Out-Null
    $body = '# AGENTS.md' + [Environment]::NewLine + [Environment]::NewLine + '- **Build**: `cargo build`' + [Environment]::NewLine
    if ($VerifyLine) { $body += $VerifyLine + [Environment]::NewLine }
    $body | Set-Content (Join-Path $d 'AGENTS.md')
    return $d
}
function Invoke-BwCase([string]$Cwd, [string]$Command) {
    return Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'Bash'; cwd = $Cwd; tool_input = @{ command = $Command } } | ConvertTo-Json -Compress)
}
$bwRepo = New-BwRepo 'bw-verify' '- **Verify (앱 조작)**: `.claude/skills/verify-app/`'
$bwNone = New-BwRepo 'bw-verify-none' '- **Verify (앱 조작)**: 없음'
$bwBare = New-BwRepo 'bw-verify-absent' ''
$r = Invoke-BwCase $bwRepo ('cd "' + $bwRepo + '"; B="' + $work + '/base-a84d4b8"; git worktree add --detach "$B" a84d4b8 2>&1 | tail -1')
Assert-Case -Name "base-worktree: Verify (앱 조작) 레포의 BASE worktree add 는 화면 기준선 경고 + exit 0" -R $r -ExpectExit 0 -ExpectContains $bwMark
$r = Invoke-BwCase $work ('git -C "' + $bwRepo + '" worktree add ../b HEAD')
Assert-Case -Name "base-worktree: 다른 cwd 에서 -C 로 그 레포에 worktree add 해도 경고" -R $r -ExpectExit 0 -ExpectContains $bwMark
$r = Invoke-BwCase $bwRepo ('git -C "' + $bwRepo + '" worktree add --detach "' + $work + '/scratch/chain-parent-3" abc1234')
Assert-Case -Name "base-worktree: 체인 감사 worktree(chain-parent-*)는 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $bwMark
$r = Invoke-BwCase $bwNone 'git worktree add ../b HEAD'
Assert-Case -Name "base-worktree: Verify (앱 조작) 이 없음이면 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $bwMark
$r = Invoke-BwCase $bwBare 'git worktree add ../b HEAD'
Assert-Case -Name "base-worktree: Verify 줄 없는 AGENTS.md 레포는 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $bwMark
$r = Invoke-BwCase $bwRepo 'git worktree list'
Assert-Case -Name "base-worktree: worktree list 는 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $bwMark
$r = Invoke-BwCase $bwRepo "grep -n 'git worktree add' notes.md"
Assert-Case -Name "base-worktree: 검색 명령의 따옴표 문자열 속 worktree add 는 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $bwMark
$r = Invoke-BwCase $work ('cd "' + $bwRepo + '"; git worktree add ../b HEAD')
Assert-Case -Name "base-worktree: 다른 cwd 에서 cd <레포>; 뒤의 worktree add 도 경고" -R $r -ExpectExit 0 -ExpectContains $bwMark
$r = Invoke-BwCase $work ('cd "' + $bwRepo + '" && git worktree add ../b HEAD')
Assert-Case -Name "base-worktree: 다른 cwd 에서 cd <레포> && 뒤의 worktree add 도 경고" -R $r -ExpectExit 0 -ExpectContains $bwMark
$r = Invoke-BwCase $bwRepo 'git.exe worktree add ../b HEAD'
Assert-Case -Name "base-worktree: git.exe worktree add 도 경고" -R $r -ExpectExit 0 -ExpectContains $bwMark
$r = Invoke-BwCase $bwRepo 'git --no-pager worktree add ../b HEAD'
Assert-Case -Name "base-worktree: 전역 옵션(--no-pager) 뒤의 worktree add 도 경고" -R $r -ExpectExit 0 -ExpectContains $bwMark
$r = Invoke-BwCase $bwRepo 'GIT_TRACE=0 git worktree add ../b HEAD'
Assert-Case -Name "base-worktree: 환경변수 대입 접두 뒤의 worktree add 도 경고" -R $r -ExpectExit 0 -ExpectContains $bwMark
$r = Invoke-BwCase $bwRepo '(git worktree add ../b HEAD)'
Assert-Case -Name "base-worktree: 괄호로 감싼 worktree add 도 경고" -R $r -ExpectExit 0 -ExpectContains $bwMark
$r = Invoke-BwCase $bwRepo 'git worktree add ../base -b chain-parent-x'
Assert-Case -Name "base-worktree: 브랜치 이름이 chain-parent- 여도 경로가 아니면 경고" -R $r -ExpectExit 0 -ExpectContains $bwMark
$bwMsys = '/' + $bwRepo.Substring(0, 1).ToLower() + ($bwRepo.Substring(2) -replace '\\', '/')
$r = Invoke-BwCase $work ('cd "' + $bwMsys + '" && git worktree add ../b HEAD')
Assert-Case -Name "base-worktree: cd 대상이 Git Bash 꼴(/c/…)이어도 경고" -R $r -ExpectExit 0 -ExpectContains $bwMark
$r = Invoke-BwCase $bwRepo 'cd /no/such/dir-xyz; git worktree add ../b HEAD'
Assert-Case -Name "base-worktree: cd 대상이 폴더가 아니면 직전 기준 폴더로 판정해 경고" -R $r -ExpectExit 0 -ExpectContains $bwMark
$r = Invoke-BwCase $bwRepo ('cd "' + $bwNone + '"; git worktree add ../b HEAD')
Assert-Case -Name "base-worktree: cd 로 Verify 없는 레포에 옮겨 가면 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $bwMark
$r = Invoke-BwCase $bwRepo ('git worktree add --detach "' + $work + '/sp ace/chain-parent-3" abc1234')
Assert-Case -Name "base-worktree: 공백 든 따옴표 경로의 chain-parent-* 도 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $bwMark
$svMark = '[SCREEN VERIFIER WARNING]'
$svState = Join-Path $env:USERPROFILE '.claude/.state/loop-continue'
New-Item -ItemType Directory $svState -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $svState 'sv-on.active'), '')
function Invoke-SvCase([string]$Cwd, [string]$Command, [string]$Sid = 'sv-on', [string]$AgentId = '') {
    $o = @{ session_id = $Sid; tool_name = 'Bash'; cwd = $Cwd; tool_input = @{ command = $Command } }
    if ($AgentId) { $o.agent_id = $AgentId }
    return Invoke-Hook 'guard-bash.ps1' ($o | ConvertTo-Json -Compress)
}
$r = Invoke-SvCase $bwRepo 'pwsh -NoProfile -File .claude/skills/verify-app/helpers/launch.ps1 -Fresh'
Assert-Case -Name "screen-verifier: implement 루프 중 메인이 Verify 스킬 스크립트를 -File 로 실행하면 경고 + exit 0" -R $r -ExpectExit 0 -ExpectContains $svMark
$r = Invoke-SvCase $bwRepo ('& "' + $bwRepo + '\.claude\skills\verify-app\helpers\shot.ps1"')
Assert-Case -Name "screen-verifier: 역슬래시 절대 경로의 & 호출도 경고" -R $r -ExpectExit 0 -ExpectContains $svMark
$r = Invoke-SvCase $bwRepo 'cd x; bash .claude/skills/verify-app/run.sh'
Assert-Case -Name "screen-verifier: 앞 세그먼트 뒤의 bash 실행도 경고" -R $r -ExpectExit 0 -ExpectContains $svMark
$r = Invoke-SvCase $bwRepo 'S=.claude/skills/verify-app/helpers; pwsh -NoProfile -File $S/launch.ps1 -Fresh'
Assert-Case -Name "screen-verifier: 같은 명령의 변수 대입으로 넘긴 스킬 경로 실행도 경고" -R $r -ExpectExit 0 -ExpectContains $svMark
$r = Invoke-SvCase $bwRepo 'S=".claude/skills/verify-app/helpers" && bash "${S}/run.sh"'
Assert-Case -Name "screen-verifier: 따옴표 대입과 중괄호 변수 꼴도 경고" -R $r -ExpectExit 0 -ExpectContains $svMark
$r = Invoke-SvCase $bwRepo 'S=.claude/skills/verify-app/helpers; grep -n Fresh $S/launch.ps1'
Assert-Case -Name "screen-verifier (음성): 변수 경로를 grep 으로 읽기만 하면 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $svMark
$r = Invoke-SvCase $bwRepo 'S=.claude/other; pwsh -NoProfile -File $S/launch.ps1'
Assert-Case -Name "screen-verifier (음성): 변수가 스킬 폴더 밖을 가리키면 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $svMark
$r = Invoke-SvCase $bwRepo 'pwsh -NoProfile -File .claude/skills/verify-app/helpers/launch.ps1' -AgentId 'a1'
Assert-Case -Name "screen-verifier (음성): 서브에이전트 실행은 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $svMark
$r = Invoke-SvCase $bwRepo 'pwsh -NoProfile -File .claude/skills/verify-app/helpers/launch.ps1' -Sid 'sv-off'
Assert-Case -Name "screen-verifier (음성): implement 발동 마커가 없으면 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $svMark
$r = Invoke-SvCase $bwNone 'pwsh -NoProfile -File .claude/skills/verify-app/helpers/launch.ps1'
Assert-Case -Name "screen-verifier (음성): Verify (앱 조작) 이 없음이면 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $svMark
$r = Invoke-SvCase $bwBare 'pwsh -NoProfile -File .claude/skills/verify-app/helpers/launch.ps1'
Assert-Case -Name "screen-verifier (음성): Verify 줄 없는 레포는 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $svMark
$r = Invoke-SvCase $bwRepo 'grep -n Fresh .claude/skills/verify-app/helpers/launch.ps1'
Assert-Case -Name "screen-verifier (음성): 스킬 스크립트를 grep 으로 읽기만 하면 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $svMark
$r = Invoke-SvCase $bwRepo 'cat .claude/skills/verify-app/helpers/launch.ps1'
Assert-Case -Name "screen-verifier (음성): 스킬 스크립트를 cat 으로 읽기만 하면 경고하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains $svMark
}

if (Test-ScenarioUnit 1) {
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "cat > a.txt <<'EOF'`necho x > plan.md`nEOF")
Assert-Case -Name "hd: cat > a.txt 데이터 싱크 본문의 > plan.md 는 통과 (HD1 오탐 수정)" -R $r -ExpectExit 0 -ExpectNotContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "mkdir -p d && cat > d/a.txt <<'EOF'`necho x > plan.md`nEOF")
Assert-Case -Name "hd: 앞에 명령이 붙은 데이터 싱크(mkdir && cat >) 본문도 통과 (HD2 오탐 수정)" -R $r -ExpectExit 0 -ExpectNotContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "tee a.txt <<'EOF'`necho x > plan.md`nEOF")
Assert-Case -Name "hd: tee 데이터 싱크 본문의 > plan.md 는 통과 (HD3 오탐 수정)" -R $r -ExpectExit 0 -ExpectNotContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "cat > plan.md <<'EOF'`nx`nEOF")
Assert-Case -Name "hd: cat > plan.md 는 여는 줄이 남아 차단 (HD4 차단 유지)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "python - <<'EOF'`nopen('plan.md','w').write('x')`nEOF")
Assert-Case -Name "hd: 실행 heredoc 본문의 open(plan.md,w) 는 차단 (HD5 차단 유지)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "cat > w.py <<'EOF'`nopen('plan.md','w').write('x')`nEOF`npython w.py")
Assert-Case -Name "hd: 파일로 쓰고 실행 — 싱크 본문의 open(plan.md,w) 는 원문 검사가 막는다 (HD6 차단 유지)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'

$ptBlock = '스크립트로 쓰려 합니다'
$ptTemp = [System.IO.Path]::GetTempPath().TrimEnd('\', '/') -replace '\\', '/'
$ptTempDeny = @(
    @{ Name = '절대 Temp 경로의 plan.md 리다이렉트도 차단하고 Write 도구를 안내'; Cmd = ('echo x > "' + $ptTemp + '/fx/plan.md"') },
    @{ Name = '따옴표 없이 쓴 절대 Temp 경로도 차단하고 Write 도구를 안내'; Cmd = ('echo x > ' + $ptTemp + '/fx/plan.md') },
    @{ Name = 'tee <절대 Temp 경로>/plan.md 도 차단하고 Write 도구를 안내'; Cmd = ('echo x | tee "' + $ptTemp + '/karina-plugin/scratch/snap/plan.md"') },
    @{ Name = 'Set-Content -Path <절대 Temp 경로>/plan.md 도 차단하고 Write 도구를 안내'; Cmd = ('Set-Content -Path "' + $ptTemp + '/fx/plan.md" -Value x') },
    @{ Name = 'mkdir 뒤 printf 로 절대 Temp 경로에 쓰기도 차단하고 Write 도구를 안내'; Cmd = ('mkdir -p "' + $ptTemp + '/fx" && printf ''# plan\n- [ ] T1 $x (a)\n'' > "' + $ptTemp + '/fx/plan.md"') }
)
foreach ($c in $ptTempDeny) {
    $r = Invoke-Hook 'guard-bash.ps1' (New-BashJson $c.Cmd)
    Assert-Case -Name "plan-write Temp — $($c.Name)" -R $r -ExpectExit 2 -ExpectContains 'Write 도구로 그 경로에 쓰거나'
}
$ptDeny = @(
    @{ Name = '레포 plan.md 리다이렉트는 차단'; Cmd = 'echo x > plan.md' },
    @{ Name = 'Temp 스크립트로 레포 plan.md 를 쓰는 python 은 차단'; Cmd = "cat > `"`$TEMP/pl.py`" <<'EOF'`np='plan.md'`nopen(p,'w').write('x')`nEOF`npython `"`$TEMP/pl.py`"" },
    @{ Name = '풀리지 않는 변수 접두는 차단'; Cmd = 'echo x > "$UNKNOWN_DIR/plan.md"' },
    @{ Name = 'Temp 를 벗어나는 상위 폴더 경로는 차단'; Cmd = 'echo x > "$TEMP/../../../../repo/plan.md"' },
    @{ Name = 'Temp 로 cd 한 뒤 레포로 다시 cd 한 상대 plan.md 는 차단'; Cmd = 'cd "$TEMP" && cd "D:/repo" && echo x > plan.md' },
    @{ Name = '서브셸 ( cd <Temp> ) 뒤 상대 plan.md 는 차단'; Cmd = '(cd "$TEMP") && echo x > plan.md' },
    @{ Name = 'Temp 로 대입한 변수를 . 로 다시 대입하면 차단'; Cmd = 'D="$TEMP/x"; D=.; echo x > "$D/plan.md"' },
    @{ Name = '%TEMP%/plan.md 는 차단'; Cmd = 'echo x > "%TEMP%/plan.md"' },
    @{ Name = 'Temp 로 cd 한 뒤 상대 plan.md 는 차단(cwd 를 추론하지 않는다)'; Cmd = ('S="' + $ptTemp + '/sp"; mkdir -p "$S" && cd "$S" && git init -q r && cd r && echo x > plan.md') },
    @{ Name = '없는 Temp 폴더로 cd 가 실패한 뒤 ; 로 이은 상대 plan.md 는 차단'; Cmd = 'cd "$TEMP/nonexist" ; echo x > plan.md' },
    @{ Name = 'cd <Temp> || 뒤 상대 plan.md 는 차단'; Cmd = 'cd "$TEMP/x" || echo x > plan.md' },
    @{ Name = 'Temp 로 cd 한 뒤 bash -c 안에서 레포로 cd 한 상대 plan.md 는 차단'; Cmd = 'cd "$TEMP/x" && bash -c ''cd D:/repo && echo x > plan.md''' },
    @{ Name = 'Temp 로 cd 한 뒤 cd - 로 돌아온 상대 plan.md 는 차단'; Cmd = 'cd "$TEMP/x" && cd - && echo x > plan.md' },
    @{ Name = 'pushd <Temp> 뒤 popd 한 상대 plan.md 는 차단'; Cmd = 'pushd "$TEMP/x" && popd && echo x > plan.md' },
    @{ Name = 'Temp 로 cd 한 뒤 cd ~/… 한 상대 plan.md 는 차단'; Cmd = 'cd "$TEMP/x" && cd ~/repo && echo x > plan.md' },
    @{ Name = 'Temp 로 cd 한 뒤 인자 없는 cd 뒤 상대 plan.md 는 차단'; Cmd = 'cd "$TEMP/x" && cd && echo x > plan.md' },
    @{ Name = '$TEMP 접두 경로는 차단(환경변수 값을 짐작하지 않는다)'; Cmd = 'echo x > "$TEMP/fx/plan.md"' },
    @{ Name = '$env:TEMP 접두 경로는 차단'; Cmd = 'echo y > "$env:TEMP/fx/plan.md"' },
    @{ Name = '값이 Temp 경로인 변수 접두도 차단'; Cmd = ('D="' + $ptTemp + '/pc"; mkdir -p "$D" && printf x > "$D/plan.md"') },
    @{ Name = '값이 절대 Temp 경로인 변수 통째 대상도 차단'; Cmd = ('P=plan.md; false && P="' + $ptTemp + '/fx/plan.md"; echo x > "$P"') },
    @{ Name = '실행되지 않는 PWD 대입 뒤 $PWD 접두는 차단'; Cmd = 'false && PWD="$TEMP/x"; echo x > "$PWD/plan.md"' },
    @{ Name = '한 명령 앞 접두 대입 PWD 뒤 $PWD 접두는 차단'; Cmd = 'PWD="$TEMP/x" echo x > "$PWD/plan.md"' },
    @{ Name = '서브셸 안 PWD 대입 뒤 $PWD 접두는 차단'; Cmd = '(PWD="$TEMP/x"); echo x > "$PWD/plan.md"' },
    @{ Name = 'for 로 재대입한 변수 접두는 차단'; Cmd = 'D="$TEMP/x"; for D in .; do echo x > "$D/plan.md"; done' },
    @{ Name = 'read 로 재대입한 변수 접두는 차단'; Cmd = 'D="$TEMP/x"; read D <<< . ; echo x > "$D/plan.md"' },
    @{ Name = '+= 로 Temp 를 벗어난 변수 접두는 차단'; Cmd = 'D="$TEMP/x"; D+=/../../../../../d/repo; echo x > "$D/plan.md"' },
    @{ Name = 'TEMP=. 재대입 뒤 $TEMP 접두는 차단'; Cmd = 'TEMP=.; echo x > "$TEMP/plan.md"' },
    @{ Name = 'export TMP=<레포> 뒤 $TMP 접두는 차단'; Cmd = 'export TMP=D:/repo; echo x > "$TMP/plan.md"' },
    @{ Name = 'printf -v 로 재대입한 변수 접두는 차단'; Cmd = 'D="$TEMP/x"; printf -v D %s .; echo x > "$D/plan.md"' },
    @{ Name = '절대 Temp 경로에서 .. 로 벗어나면 차단'; Cmd = ('echo x > "' + $ptTemp + '/../../../../repo/plan.md"') },
    @{ Name = '절대 Temp 경로 안의 명령 치환은 차단'; Cmd = ('echo x > "' + $ptTemp + '/$(echo ../../..)/plan.md"') },
    @{ Name = '절대 Temp 경로 안의 백틱 치환은 차단'; Cmd = ('echo x > "' + $ptTemp + '/`echo ..`/plan.md"') },
    @{ Name = '절대 Temp 경로 안의 중괄호·글롭 확장은 차단'; Cmd = ('cp plan.md ' + $ptTemp + '/{..,x}/../plan.md') },
    @{ Name = 'msys 꼴 /c/… 경로는 차단(마운트를 짐작하지 않는다)'; Cmd = ('echo x > "' + ($ptTemp -replace '^([A-Za-z]):', '/$1') + '/fx/plan.md"') },
    @{ Name = '장치 접두 \\?\ 경로는 차단'; Cmd = ('echo x > "\\?\' + ($ptTemp -replace '/', '\') + '\fx\plan.md"') },
    @{ Name = 'Temp 와 이름이 앞부분만 같은 형제 폴더는 차단'; Cmd = ('echo x > "' + $ptTemp + 'x/plan.md"') },
    @{ Name = '끝이 점인 세그먼트가 든 절대 Temp 경로는 차단'; Cmd = ('echo x > "' + $ptTemp + '/fx./plan.md"') },
    @{ Name = '끝이 공백인 세그먼트가 든 절대 Temp 경로는 차단'; Cmd = ('echo x > "' + $ptTemp + '/fx /plan.md"') },
    @{ Name = '구분자가 겹친 절대 Temp 경로는 차단'; Cmd = ('echo x > "' + $ptTemp + '//fx/plan.md"') },
    @{ Name = '8.3 짧은 이름(~)이 든 경로는 차단'; Cmd = 'echo x > "C:/Users/PUBLIC~1/AppData/Local/Temp/fx/plan.md"' },
    @{ Name = '안쪽 따옴표로 이어 붙인 절대 Temp 경로는 차단'; Cmd = ('echo x > ' + $ptTemp + '/"fx"/plan.md') },
    @{ Name = '같은 명령에서 mklink 로 junction 을 만든 뒤 그 아래 plan.md 는 차단'; Cmd = ('cmd //c mklink /J "' + $ptTemp + '/ptl" D:/repo && echo x > "' + $ptTemp + '/ptl/plan.md"') },
    @{ Name = '괄호 식으로 쓴 리다이렉트 대상 (''plan.md'') 는 차단'; Cmd = 'echo x > (''plan.md'')' },
    @{ Name = '괄호로 감싼 변수 리다이렉트 대상 ($f) 는 차단'; Cmd = '$f=''plan.md''; echo x > ($f)' },
    @{ Name = '역슬래시로 이스케이프한 괄호가 든 리다이렉트 대상은 차단'; Cmd = 'echo x > a\(b\)/plan.md' },
    @{ Name = '역슬래시로 이스케이프한 세미콜론이 든 리다이렉트 대상은 차단'; Cmd = 'echo x > a\;b/plan.md' },
    @{ Name = '역슬래시로 이스케이프한 앰퍼샌드가 든 리다이렉트 대상은 차단'; Cmd = 'echo x > a\&b/plan.md' },
    @{ Name = '백틱으로 이스케이프한 괄호가 든 리다이렉트 대상은 차단'; Cmd = 'echo x > a`(b`)/plan.md' },
    @{ Name = '빈 대입 뒤에 온 따옴표 대입 변수 대상은 차단'; Cmd = 'x= f="plan.md"; echo hi > $f' },
    @{ Name = '연쇄 대입한 변수의 리다이렉트 대상은 차단'; Cmd = '$x = $f = ''plan.md''; ''hi'' > $f' },
    @{ Name = '연쇄 대입한 변수의 Set-Content 대상은 차단'; Cmd = '$x = $f = ''plan.md''; Set-Content $f ''hi''' },
    @{ Name = 'python 연쇄 대입 뒤 open(f, w) 는 차단'; Cmd = 'python -c "q = f = ''plan.md''; open(f, ''w'').write(''x'')"' },
    @{ Name = '역슬래시로 쓴 절대 Temp 경로는 차단'; Cmd = ('echo x > "' + ($ptTemp -replace '/', '\') + '\fx\plan.md"') },
    @{ Name = '닫는 큰따옴표 뒤에 꼬리를 붙인 절대 Temp 경로는 차단'; Cmd = ('echo x > "' + $ptTemp + '/x/plan.md"/../../../plan.md') },
    @{ Name = '닫는 작은따옴표 뒤에 꼬리를 붙인 절대 Temp 경로는 차단'; Cmd = ('echo x > ''' + $ptTemp + '/x/plan.md''/../../../plan.md') },
    @{ Name = '줄 연속으로 꼬리를 붙인 절대 Temp 경로는 차단'; Cmd = ('echo x > "' + $ptTemp + "/x/plan.md`"\`n/../../../plan.md") },
    @{ Name = '앞 공백 값 대입 뒤 따옴표 없이 재대입한 변수 대상은 차단'; Cmd = ('P=" ' + $ptTemp + '/x/plan.md"; P=plan.md; echo x > "$P"') },
    @{ Name = '탭 값 대입 뒤 따옴표 없이 재대입한 변수 대상은 차단'; Cmd = ("P=`"`t" + $ptTemp + '/x/plan.md"; P=plan.md; echo x > $P') },
    @{ Name = 'python 8진 이스케이프로 Temp 를 벗어나는 open 은 차단'; Cmd = ("python -c `"open('" + $ptTemp + "\057\056\056\plan.md','w').write('x')`"") },
    @{ Name = 'python 16진 이스케이프로 Temp 를 벗어나는 open 은 차단'; Cmd = ("python -c `"open('" + $ptTemp + "\x2e\x2e\plan.md','w').write('x')`"") },
    @{ Name = 'cp -t . <절대 Temp 경로>/plan.md 는 차단'; Cmd = ('cp -t . "' + $ptTemp + '/x/plan.md"') },
    @{ Name = 'cp plan.md <절대 Temp 경로>/plan.md 는 차단(원본 쪽 맨 plan.md 언급)'; Cmd = ('cp plan.md "' + $ptTemp + '/karina-plugin/scratch/snap/plan.md"') },
    @{ Name = 'cp notes.md <절대 Temp 경로>/plan.md 는 차단'; Cmd = ('cp notes.md "' + $ptTemp + '/karina-plugin/scratch/snap/plan.md"') },
    @{ Name = 'cp -vt . <절대 Temp 경로>/plan.md 는 차단'; Cmd = ('cp -vt . "' + $ptTemp + '/x/plan.md"') },
    @{ Name = 'cp --target=. <절대 Temp 경로>/plan.md 는 차단'; Cmd = ('cp --target=. "' + $ptTemp + '/x/plan.md"') },
    @{ Name = 'cp --t . <절대 Temp 경로>/plan.md 는 차단'; Cmd = ('cp --t . "' + $ptTemp + '/x/plan.md"') },
    @{ Name = 'mv -ft . <절대 Temp 경로>/plan.md 는 차단'; Cmd = ('mv -ft . "' + $ptTemp + '/x/plan.md"') },
    @{ Name = 'Copy-Item -Destination . <절대 Temp 경로>/plan.md 는 차단'; Cmd = ('Copy-Item -Destination . "' + $ptTemp + '/x/plan.md"') },
    @{ Name = 'Move-Item -Destination . <절대 Temp 경로>/plan.md 는 차단'; Cmd = ('Move-Item -Destination . "' + $ptTemp + '/x/plan.md"') },
    @{ Name = '따옴표 안 mklink 로 만든 junction 아래 plan.md 는 차단'; Cmd = ('cmd //c "mklink /J ' + ($ptTemp -replace '/', '\') + '\pj5 D:\repo" && echo x > "' + $ptTemp + '/pj5/plan.md"') },
    @{ Name = '/usr/bin/ln -s 로 만든 링크 아래 plan.md 는 차단'; Cmd = ('/usr/bin/ln -s /d/repo "' + $ptTemp + '/pj6" && echo x > "' + $ptTemp + '/pj6/plan.md"') },
    @{ Name = 'New-Item -ItemType:Junction 뒤 그 아래 plan.md 는 차단'; Cmd = ('New-Item -ItemType:Junction -Path "' + $ptTemp + '/pj8" -Value D:/repo; echo x > "' + $ptTemp + '/pj8/plan.md"') },
    @{ Name = '백틱 치환 안 ln 뒤 링크 아래 plan.md 는 차단'; Cmd = ('x=`ln -s /d/repo ' + $ptTemp + '/pj9`; echo x > "' + $ptTemp + '/pj9/plan.md"') },
    @{ Name = 'python os.symlink 뒤 링크 아래 plan.md 는 차단'; Cmd = ("python -c `"import os; os.symlink('D:/repo','" + $ptTemp + "/pj10')`"; echo x > `"" + $ptTemp + '/pj10/plan.md"') },
    @{ Name = 'ls 가 함께 든 절대 Temp 경로 쓰기는 차단'; Cmd = ('ls -ln; echo x > "' + $ptTemp + '/fx/plan.md"') },
    @{ Name = 'python open(<절대 Temp 경로>/plan.md) 는 차단'; Cmd = ("python -c `"open('" + $ptTemp + "/fx/plan.md','w').write('x')`"") },
    @{ Name = 'ni -it j 로 만든 junction 아래 plan.md 는 차단'; Cmd = ('ni -it j "' + $ptTemp + '/pj11" -Value D:/repo; echo x > "' + $ptTemp + '/pj11/plan.md"') },
    @{ Name = 'New-Item -ItemType Jun 뒤 그 아래 plan.md 는 차단'; Cmd = ('New-Item -ItemType Jun -Path "' + $ptTemp + '/pj12" -Value D:/repo; echo x > "' + $ptTemp + '/pj12/plan.md"') },
    @{ Name = 'pwsh -c 안에서 만든 링크 아래 plan.md 는 차단'; Cmd = ('pwsh -c "ni -it j ' + $ptTemp + '/pj13 -Value D:/repo" && echo x > "' + $ptTemp + '/pj13/plan.md"') },
    @{ Name = 'cmd 캐럿 표기 mk^link 뒤 그 아래 plan.md 는 차단'; Cmd = ('cmd //c "mk^link /J ' + $ptTemp + '/pj14 D:/repo" && echo x > "' + $ptTemp + '/pj14/plan.md"') },
    @{ Name = 'tee 의 둘째 대상을 글롭 변수로 숨긴 명령은 차단'; Cmd = ('X=D:/repo/pla?.md; echo x | tee "' + $ptTemp + '/fx/plan.md" $X') },
    @{ Name = 'PowerShell 괄호 식이 든 명령은 차단'; Cmd = ('Set-Content -Path "' + $ptTemp + '/fx/plan.md" -Value (Get-Date)') },
    @{ Name = '큰따옴표 안 작은따옴표로 뒤 명령을 가린 꼴은 차단'; Cmd = ('echo "it''s" ; ni -it j "' + $ptTemp + '/pj15" -Value D:/repo ; echo x > "' + $ptTemp + '/pj15/plan.md" ; echo ''z''') },
    @{ Name = '주석 안 작은따옴표로 다음 줄 명령을 가린 꼴은 차단'; Cmd = ("echo a # it's`nni -it j `"" + $ptTemp + "/pj16`" -Value D:/repo`necho 'x' > `"" + $ptTemp + '/pj16/plan.md"') },
    @{ Name = 'Set-Content Function: 뒤 junction 아래 plan.md 는 차단'; Cmd = ('Set-Content Function:mkdir "ni -it j ' + $ptTemp + '/pj17 D:/repo"; mkdir; echo x > "' + $ptTemp + '/pj17/plan.md"') },
    @{ Name = '유니코드 작은따옴표로 닫아 뒤 명령을 숨긴 꼴은 차단'; Cmd = ("echo 'a" + [char]0x2018 + '; ni -it j "' + $ptTemp + '/pj30" -Value D:/repo; echo ' + [char]0x2018 + "b'; echo x > `"" + $ptTemp + '/pj30/plan.md"') },
    @{ Name = '유니코드 큰따옴표로 닫아 뒤 명령을 숨긴 꼴은 차단'; Cmd = ("echo 'a" + [char]0x201C + '; ni -it j ' + $ptTemp + '/pj32 -Value D:/repo; echo ' + [char]0x201C + "b'; Set-Content -Path `"" + $ptTemp + '/pj32/plan.md" -Value x') },
    @{ Name = 'heredoc 본문의 작은따옴표로 링크 생성 줄을 숨긴 꼴은 차단'; Cmd = ("cat <<echo > " + $ptTemp + "/pa9/a.txt`necho '`necho`npwsh -NoProfile -c ni -it j " + $ptTemp + "/pj93 -Value D:/repo`necho PWNED > " + $ptTemp + "/pj93/plan.md`ncat <<echo > " + $ptTemp + "/pa9/b.txt`n'`necho") },
    @{ Name = 'heredoc 본문의 큰따옴표로 링크 생성 줄을 숨긴 꼴은 차단'; Cmd = ("cat <<echo > " + $ptTemp + "/pa9/a.txt`necho `"`necho`npwsh -NoProfile -c ni -it j " + $ptTemp + "/pj94 -Value D:/repo`necho PWNED > " + $ptTemp + "/pj94/plan.md`ncat <<echo > " + $ptTemp + "/pa9/b.txt`n`"`necho") },
    @{ Name = 'heredoc 으로 절대 Temp 경로에 쓰는 명령은 차단'; Cmd = ("cat > `"" + $ptTemp + "/fx/plan.md`" <<EOF`nx`nEOF") },
    @{ Name = '작은따옴표 조각을 이어 붙여 이름을 숨긴 둘째 쓰기가 든 명령은 차단'; Cmd = ('echo x > "' + $ptTemp + '/fx/plan.md"; echo y > ''D:/repo/pla''''n.md''') },
    @{ Name = '맨 글자와 따옴표 조각을 이어 붙인 tee 둘째 대상이 든 명령은 차단'; Cmd = ('echo x | tee "' + $ptTemp + '/fx/plan.md" D:/repo/pla"n".md') },
    @{ Name = '변수 대입 접두가 든 명령은 차단'; Cmd = ('PATH=D:/evil tee "' + $ptTemp + '/fx/plan.md"') },
    @{ Name = '큰따옴표 안 치환이 든 명령은 차단'; Cmd = ('echo "$(ni -it j a b)" > "' + $ptTemp + '/fx/plan.md"') },
    @{ Name = '절대 Temp 경로와 맨 plan.md 언급이 함께 있으면 차단'; Cmd = ('echo plan.md; echo x > "' + $ptTemp + '/fx/plan.md"') }
)
foreach ($c in $ptDeny) {
    $r = Invoke-Hook 'guard-bash.ps1' (New-BashJson $c.Cmd)
    Assert-Case -Name "plan-write Temp — $($c.Name)" -R $r -ExpectExit 2 -ExpectContains $ptBlock
}
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'echo x > (''C:/Users/u/.claude/plugins/cache/karina-plugins/karina/1.0.0/scripts/guard-bash.ps1'')')
Assert-Case -Name "installed-write — 괄호 식으로 쓴 설치본 스크립트 리다이렉트는 차단" -R $r -ExpectExit 2 -ExpectContains 'BLOCKED'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'x= f="C:/Users/u/.claude/plugins/cache/karina-plugins/karina/1.0.0/scripts/guard-bash.ps1"; echo hi > $f')
Assert-Case -Name "installed-write — 빈 대입 뒤에 온 따옴표 대입 변수의 설치본 스크립트 리다이렉트는 차단" -R $r -ExpectExit 2 -ExpectContains 'BLOCKED'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'echo done 2>&1 >&2; grep -c x plan.md > count.txt')
Assert-Case -Name "plan-write — 2>&1·>&2 와 다른 파일로 가는 리다이렉트는 통과 (음성 짝)" -R $r -ExpectExit 0 -ExpectNotContains $ptBlock
$ptPsWild = 'Set-Content -Path "' + $ptTemp + '/fx/plan.md" -Value x; Add-Content ''D:/repo/pla?.md'' y'
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'PowerShell'; cwd = $noLib; tool_input = @{ command = $ptPsWild } } | ConvertTo-Json -Compress)
Assert-Case -Name "plan-write Temp — PowerShell 도구에서 작은따옴표 안 와일드카드로 이름을 숨긴 둘째 쓰기는 차단" -R $r -ExpectExit 2 -ExpectContains $ptBlock
$ptPsTick = 'Set-Content -Path "' + $ptTemp + '/fx/plan.md" -Value x; Add-Content ''D:/repo/pla`n.md'' y'
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'PowerShell'; cwd = $noLib; tool_input = @{ command = $ptPsTick } } | ConvertTo-Json -Compress)
Assert-Case -Name "plan-write Temp — PowerShell 도구에서 작은따옴표 안 백틱으로 이름을 숨긴 둘째 쓰기는 차단" -R $r -ExpectExit 2 -ExpectContains $ptBlock
$ptPsPlain = 'Set-Content -Path "' + $ptTemp + '/fx/plan.md" -Value ''plain text'''
$r = Invoke-Hook 'guard-bash.ps1' (@{ tool_name = 'PowerShell'; cwd = $noLib; tool_input = @{ command = $ptPsPlain } } | ConvertTo-Json -Compress)
Assert-Case -Name "plan-write Temp — PowerShell 도구의 Set-Content 절대 Temp 경로 쓰기도 차단하고 Write 도구를 안내" -R $r -ExpectExit 2 -ExpectContains 'Write 도구로 그 경로에 쓰거나'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "cat > run.sh <<'EOF'`necho x > plan.md`nEOF")
Assert-Case -Name "hd: 실행 가능 스크립트(.sh) 싱크 본문의 > plan.md 는 차단 (HD7 차단 유지)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
# HD8·HD9: 대상 인자 뒤에 리다이렉션 토큰이 붙어도 마지막 실효 인자를 본다(2026-10-13 실해 — 미탐 보완).
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "sed -i 's/a/b/' plan.md 2>&1 | head -2")
Assert-Case -Name "bpw: sed -i … plan.md 2>&1 도 차단 (HD8 미탐 보완)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson "grep -n x plan.md 2>&1 | head")
Assert-Case -Name "bpw: grep … plan.md 2>&1 읽기는 통과 (HD9 델타 음성)" -R $r -ExpectExit 0 -ExpectNotContains '스크립트로 쓰려 합니다'

# ST10 (짝 안 맞는 따옴표 — 미탐 쪽 못박기): 여는 따옴표가 닫히지 않으면 그 뒤 전부가 한
#   세그먼트로 남고, **첫 실효 토큰으로 판정하는 동사 신호**(ⓒsed -i·ⓔcp/mv·ⓓSet-Content)는
#   그 세그먼트의 첫 토큰이 `echo` 라 발화하지 않는다. ⚠ **block-plan-write 는 차단 게이트이므로
#   이것은 곧 plan.md 쓰기 차단의 미탐이다.** 통과가 옳아서가 아니라 **지금 그렇다는 것을 고정**
#   하는 케이스이고, 바꾸려면 미완결 인용의 셸 의미를 먼저 정해야 한다(실측: sed -i·cp·Set-Content
#   세 형태 모두 exit 0).
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'echo "unclosed; cp notes.md plan.md')
Assert-Case -Name "split: 닫히지 않은 따옴표 뒤의 동사 신호는 미탐이다 (ST10)" -R $r -ExpectExit 0 -ExpectSilent $true

# ST11 (같은 형태에서 리다이렉션 신호는 산다): ⓑ 는 세그먼트의 **첫 토큰**이 아니라 세그먼트 안의
#   `>` 대상을 보므로 인용이 열려 있어도 잡힌다. ST10 과 짝을 이뤄 **미탐의 경계가 어디인지**를
#   고정한다 — 「따옴표가 안 닫히면 다 샌다」가 아니다.
$r = Invoke-Hook 'guard-bash.ps1' (New-BashJson 'echo "unclosed; echo x > plan.md')
Assert-Case -Name "split: 닫히지 않은 따옴표 뒤여도 리다이렉션 대상은 잡는다 (ST11)" -R $r -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'

# ---- [회차 52] rules/external-ops.json 로드 실패 격리 ----
#   판정 패턴과 경고 문면이 json 으로 내려갔다. 그 파일이 없으면 warn-external-ops **만** 꺼지고
#   차단 게이트(require-task-checkbox·block-plan-write)는 계속 돌아야 한다. 기존 로드 가드
#   (guard-commit-secrets 부재)는 `exit 0` 이라 6검사 전부를 끄는데, 이 가드는 그 형태를 답습하지
#   않는다 — `Invoke-WarnExternalOps` 안의 `exit` 은 함수 스코프를 넘어 프로세스를 죽이므로
#   `return New-HookResult` 로 그 함수만 종료한다.
$noJson = Join-Path $work 'ops-nojson'; New-Item -ItemType Directory (Join-Path $noJson 'rules') -Force | Out-Null
Copy-Item (Join-Path $scriptsDir 'guard-bash.ps1') $noJson -Force
Copy-Item (Join-Path $scriptsDir 'guard-commit-secrets.ps1') $noJson -Force
Copy-Item (Join-Path $scriptsDir 'git-commit-match.ps1') $noJson -Force
Copy-Item (Join-Path $scriptsDir 'rules/*.md') (Join-Path $noJson 'rules') -Force -ErrorAction SilentlyContinue

# EOJ1: json 부재 → 외부 작업 경고는 사라지고 stderr 로 그 사실이 보인다(침묵 fail-open 아님).
$eojJson = @{ tool_name = 'Bash'; tool_input = @{ command = 'git push origin main' } } | ConvertTo-Json -Compress
$outEoj = $eojJson | pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $noJson 'guard-bash.ps1') 2>&1
$rEoj = @{ code = $LASTEXITCODE; out = (($outEoj | Out-String)).Trim() }
Assert-Case -Name "eoj: external-ops.json 부재 시 경고 미수행 + stderr 가시화 (EOJ1)" -R $rEoj -ExpectExit 0 -ExpectContains 'external-ops.json 로드 실패'

# EOJ2: 같은 상태에서 **차단 게이트는 살아 있다** — 전체 exit 0 으로 빠져나가지 않는다.
$eojBlock = @{ tool_name = 'Bash'; tool_input = @{ command = 'echo x > plan.md' } } | ConvertTo-Json -Compress
$outEojB = $eojBlock | pwsh -NoProfile -ExecutionPolicy Bypass -File (Join-Path $noJson 'guard-bash.ps1') 2>&1
$rEojB = @{ code = $LASTEXITCODE; out = (($outEojB | Out-String)).Trim() }
Assert-Case -Name "eoj: json 부재여도 block-plan-write 차단은 유지 (EOJ2)" -R $rEojB -ExpectExit 2 -ExpectContains '스크립트로 쓰려 합니다'
}

}

if ((Test-HookSelected @('guard-bash')) -and $gitOk) {
$ccRoot = Join-Path $work 'ccrepos'; New-Item -ItemType Directory $ccRoot -Force | Out-Null
$ccSeq = 0
function New-CcRepo {
    $script:ccSeq++
    $d = Join-Path $ccRoot "r$($script:ccSeq)"; New-Item -ItemType Directory $d -Force | Out-Null
    Push-Location $d
    git init -q; git config user.email t@t; git config user.name t; git config core.autocrlf false
    [System.IO.File]::WriteAllText((Join-Path $d 'a.cs'), "// 기존 설명`nint a;`n")
    [System.IO.File]::WriteAllText((Join-Path $d 'b.cs'), "int b;`n")
    [System.IO.File]::WriteAllText((Join-Path $d 'doc.md'), "# 문서`n")
    git add .; git commit -qm base
    Pop-Location
    return $d
}
function Invoke-CcCommit([string]$Dir, [string]$Command, [string]$Session) {
    return (Invoke-Hook 'guard-bash.ps1' (@{ session_id = $Session; tool_name = 'Bash'; cwd = $Dir; tool_input = @{ command = $Command } } | ConvertTo-Json -Compress))
}
function Set-CcFile([string]$Dir, [string]$Name, [string]$Text) { [System.IO.File]::WriteAllText((Join-Path $Dir $Name), $Text) }
$ccBlock = '[HARNESS] BLOCKED: 커밋에 새 주석이 있습니다 (주석'
$ccMoveA = "/// 옮겨 갈 시험 설명.`nfn t_moved() {}`n`nfn keep() {}`n"
$ccRealGit = @(Get-Command git -CommandType Application | ForEach-Object { $_.Source })[0]
$ccBudgetLine = 'BASE 확인 git 이 예산('
function New-CcMoveRepo {
    $m = New-CcRepo
    Set-CcFile $m 'm.rs' $ccMoveA; Set-CcFile $m 'n.rs' "fn other() {}`n"
    git -C $m add .; git -C $m commit -qm move-base
    Set-CcFile $m 'plan.md' "# plan`n`n## Goal`n`n> BASE: $((git -C $m rev-parse --short HEAD).Trim())`n"
    Set-CcFile $m 'm.rs' "fn keep() {}`n"
    Set-CcFile $m 'n.rs' "fn other() {}`n`n/// 옮겨 갈 시험 설명.`nfn t_moved() {}`n"
    return $m
}

if (Test-ScenarioUnit 4) {

$d = New-CcRepo
Set-CcFile $d 'a.cs' "// 기존 설명`n// 새 설명`nint a;`n"; git -C $d add a.cs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-retry'
Assert-Case -Name "commit-comments: staged 새 주석이 있는 커밋 첫 시도는 차단" -R $r -ExpectExit 2 -ExpectContains $ccBlock
Assert-Case -Name "commit-comments: 차단 사유가 다시 내도 통과하지 않음을 낸다" -R $r -ExpectExit 2 -ExpectContains '같은 커밋을 다시 내도 통과하지 않습니다'
Assert-Case -Name "commit-comments: 차단 사유가 낡은 옛 주석을 고치거나 지우라고 안내한다" -R $r -ExpectExit 2 -ExpectContains '새 주석만 빼고 낡은 주석을 남기지 마세요'
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-retry'
Assert-Case -Name "commit-comments: 같은 주석 집합 두 번째도 차단" -R $r -ExpectExit 2 -ExpectContains $ccBlock
$d = New-CcRepo
Set-CcFile $d 'ci.yaml' "# 새 설명`non: push`n"; git -C $d add ci.yaml
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-yaml'
Assert-Case -Name "commit-comments: .yaml 새 # 주석을 staged 한 커밋 차단" -R $r -ExpectExit 2 -ExpectContains $ccBlock
$d = New-CcRepo
Set-CcFile $d 'mod.psm1' "#Requires -Version 7`n`$m = 1`n"; git -C $d add mod.psm1
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-psm1'
Assert-Case -Name "commit-comments: .psm1 #Requires 만 staged 한 커밋 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

$d = New-CcRepo
[System.IO.File]::WriteAllText((Join-Path $d 'AGENTS.md'), "# A`n`n- **Test (감사)**: ``cargo test`` · 증가: ``^\s*pub\s+(fn|enum|struct)\b`` · 경로: ``*.rs```n")
[System.IO.File]::WriteAllText((Join-Path $d 'q.rs'), "fn x() {}`npub enum E {}`n")
git -C $d add .; git -C $d commit -qm rs
Set-CcFile $d 'q.rs' "fn x() {}`n/// 감사가 요구하는 계약.`npub enum E {}`n"; git -C $d add q.rs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-audit'
Assert-Case -Name "commit-comments: 기존 pub 항목 위에 /// 만 더한 커밋(감사 레포)은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
Set-CcFile $d 'q.rs' "fn x() {}`n/// 감사가 요구하는 계약.`n#[a]`n#[b]`n#[c]`n#[d]`npub enum E {}`n"; git -C $d add q.rs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-attr'
Assert-Case -Name "commit-comments: 속성 4줄 뒤 pub 항목은 커밋 대상 내용에서 읽어 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
Set-CcFile $d 'q.rs' "/// 감사 대상이 아닌 비공개 함수.`nfn x() {}`n/// 감사가 요구하는 계약.`n#[a]`n#[b]`n#[c]`n#[d]`npub enum E {}`n"; git -C $d add q.rs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-audit-neg'
Assert-Case -Name "commit-comments: 감사 레포 비공개 fn 위 /// 차단" -R $r -ExpectExit 2 -ExpectContains '(주석 1줄)'
$d = New-CcRepo
[System.IO.File]::WriteAllText((Join-Path $d 'AGENTS.md'), "# A`n`n- **Test (감사)**: ``cargo test --lib -- test_doc_audit`` · 증가: ``^\s*#\[(tokio::)?test\]`` · 경로: ``*.rs```n")
[System.IO.File]::WriteAllText((Join-Path $d 't.rs'), "#[test]`nfn t_one() {}`n")
git -C $d add .; git -C $d commit -qm rs
Set-CcFile $d 't.rs' "/// 시험 설명.`n#[test]`nfn t_one() {}`n"; git -C $d add t.rs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-testdoc'
Assert-Case -Name "commit-comments: 시험 doc 감사 선언 레포의 #[test] 위 /// 커밋 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

function New-CcAuditRepo([string]$Name, [string]$Base) {
    $a = New-CcRepo
    [System.IO.File]::WriteAllText((Join-Path $a 'AGENTS.md'), "# A`n`n- **Test (감사)**: ``cargo test`` · 증가: ``^\s*pub\s+(fn|enum|struct)\b`` · 경로: ``*.rs```n")
    [System.IO.File]::WriteAllText((Join-Path $a $Name), $Base)
    git -C $a add .; git -C $a commit -qm rs
    return $a
}
$d = New-CcAuditRepo 'dup.rs' "/// # Errors`npub fn a() {}`nfn helper() {}`n"
Set-CcFile $d 'dup.rs' "/// # Errors`npub fn a() {}`n/// # Errors`nfn helper() {}`n"; git -C $d add dup.rs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-dup'
Assert-Case -Name "commit-comments: 같은 문구 사본: 비공개 fn 위 /// 를 더한 커밋 차단(첫 사본은 pub fn 위)" -R $r -ExpectExit 2 -ExpectContains '(주석 1줄)'
$d = New-CcAuditRepo 'dup2.rs' "/// 내부 설명`nfn first() {}`npub fn api() {}`n"
Set-CcFile $d 'dup2.rs' "/// 내부 설명`nfn first() {}`n/// 내부 설명`npub fn api() {}`n"; git -C $d add dup2.rs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-dup2'
Assert-Case -Name "commit-comments: 같은 문구 사본: pub fn 위 /// 커밋 통과(첫 사본은 비공개 fn 위)" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$d = New-CcAuditRepo 's1.rs' "fn x() {}`n"
Set-CcFile $d 's1.rs' "/// 설명.`nfn x() {}`n"; git -C $d add s1.rs
Set-CcFile $d 's1.rs' "/// 설명.`npub fn x() {}`n"
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-stage-priv'
Assert-Case -Name "commit-comments: staged 는 비공개 fn 위 ///, 작업 트리만 pub 으로 바꾼 커밋 차단" -R $r -ExpectExit 2 -ExpectContains $ccBlock
$d = New-CcAuditRepo 's2.rs' "pub fn y() {}`n"
Set-CcFile $d 's2.rs' "/// 설명.`npub fn y() {}`n"; git -C $d add s2.rs
Set-CcFile $d 's2.rs' "/// 설명.`nfn y() {}`n"
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-stage-pub'
Assert-Case -Name "commit-comments: staged 는 pub 위 ///, 작업 트리만 비공개로 바꾼 커밋 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$d = New-CcAuditRepo 'ma.rs' "pub struct S;`n"
Set-CcFile $d 'ma.rs' "/// 계약.`n#[derive(`n    Debug,`n)]`npub struct S;`n"; git -C $d add ma.rs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-mattr'
Assert-Case -Name "commit-comments: 여러 줄 속성 뒤 pub 항목 위 /// 커밋 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$d = New-CcAuditRepo 'z.rs' "fn z() {}`n"
Set-CcFile $d 'z.rs' "/// 설명.`nfn z() {}`n"; git -C $d add z.rs
Set-CcFile $d 'z.rs' "/// 설명.`npub fn z() {}`n"
$r = Invoke-CcCommit $d 'git add z.rs && git commit -m x' 'cc-two-src'
Assert-Case -Name "commit-comments: git add x && git commit: staged 는 비공개 fn 위, 작업 트리는 pub 위 /// 이면 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$d = New-CcAuditRepo 'rw.rs' "fn a() {}`nfn b() {}`nfn c() {`n    /// 아틀라스에서 그림을 내리지 않는다.`n    let x = 1;`n}`n"
Set-CcFile $d 'rw.rs' "/// 썸네일을 칠하는 설정 창.`npub fn bind() {}`nfn a() {}`nfn b() {}`nfn c() {`n    /// 아틀라스에서 그림을 직접 내리지 않는다.`n    let x = 1;`n}`n"; git -C $d add rw.rs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-reword-split'
Assert-Case -Name "commit-comments: 새 pub doc(앞 hunk) + 다른 hunk 의 doc 문구 수정 커밋은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$d = New-CcRepo
Set-CcFile $d 'hk.cs' "// 첫 설명`nint a;`nint b;`nint c;`nint d;`n"; git -C $d add hk.cs; git -C $d commit -qm hk
Set-CcFile $d 'hk.cs' "int a;`nint b;`nint c;`n// 전혀 다른 내용`nint d;`n"; git -C $d add hk.cs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-hunk-far'
Assert-Case -Name "commit-comments: 한 hunk 에서 지운 주석이 떨어진 hunk 의 다른 새 주석을 봐주지 않는다" -R $r -ExpectExit 2 -ExpectContains '전혀 다른 내용'
$d = New-CcRepo
Set-CcFile $d 'mv.cs' "// 이동할 설명`nint a;`nint b;`nint c;`nint d;`n"; git -C $d add mv.cs; git -C $d commit -qm mv
Set-CcFile $d 'mv.cs' "int a;`nint b;`nint c;`n// 이동할 설명`nint d;`n"; git -C $d add mv.cs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-hunk-move'
Assert-Case -Name "commit-comments: 파일 안 주석을 떨어진 자리로 옮긴 커밋은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$d = New-CcAuditRepo 'sh.rs' "pub fn a() {}`n/// 옛 설명 문장이다.`nfn b() {}`n"
Set-CcFile $d 'sh.rs' "pub fn a() {}`n/// 새 공개 함수.`npub fn n() {}`n/// 옛 설명 문장을 고쳤다.`nfn b() {}`n"; git -C $d add sh.rs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-hunk-same'
Assert-Case -Name "commit-comments: 한 hunk 안 새 pub doc + 문구 수정 커밋은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$ccTwoBase = "fn a() {}`nfn b() {}`nfn c() {}`nfn d() {}`npub fn e() {}`nfn f() {}`n"
$d = New-CcAuditRepo 'h2.rs' $ccTwoBase
Set-CcFile $d 'h2.rs' "fn a2() {}`nfn b() {}`nfn c() {}`nfn d() {}`npub fn e() {}`n/// 두 번째 hunk 설명.`nfn f() {}`n"; git -C $d add h2.rs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-hunk2-priv'
Assert-Case -Name "commit-comments: 두 번째 hunk 의 비공개 fn 위 /// 커밋 차단" -R $r -ExpectExit 2 -ExpectContains '두 번째 hunk 설명'
$d = New-CcAuditRepo 'h3.rs' $ccTwoBase
Set-CcFile $d 'h3.rs' "fn a2() {}`nfn b() {}`nfn c() {}`nfn d() {}`n/// 두 번째 hunk 설명.`npub fn e() {}`nfn f() {}`n"; git -C $d add h3.rs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-hunk2-pub'
Assert-Case -Name "commit-comments: 두 번째 hunk 의 pub fn 위 /// 커밋 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

$d = New-CcRepo
[System.IO.File]::WriteAllText((Join-Path $d 'h.ps1'), "$([char]0xFEFF)# h.ps1 — 옛 머리 설명`n`$h = 1`n")
git -C $d add h.ps1; git -C $d commit -qm h
[System.IO.File]::WriteAllText((Join-Path $d 'h.ps1'), "$([char]0xFEFF)# h.ps1 — 고친 머리 설명`n`$h = 1`n"); git -C $d add h.ps1
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-bom'
Assert-Case -Name "commit-comments: BOM 첫 줄 머리 주석의 문구 수정은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

$d = New-CcRepo
Set-CcFile $d 'b.cs' "// 경로 커밋 설명`nint b;`n"
$r = Invoke-CcCommit $d 'git commit -m x -- b.cs' 'cc-path'
Assert-Case -Name "commit-comments: git commit -- <경로> 의 add 안 한 추적 파일 새 주석도 차단" -R $r -ExpectExit 2 -ExpectContains $ccBlock
$r = Invoke-CcCommit $d 'git commit -am x' 'cc-am'
Assert-Case -Name "commit-comments: git commit -am 의 추적 파일 새 주석도 차단" -R $r -ExpectExit 2 -ExpectContains $ccBlock
$r = Invoke-CcCommit $d 'git add b.cs && git commit -m x' 'cc-add'
Assert-Case -Name "commit-comments: 같은 명령 앞선 git add <추적 파일> 의 새 주석도 차단" -R $r -ExpectExit 2 -ExpectContains $ccBlock

$d = New-CcRepo
Set-CcFile $d 'new.py' "# 새 파일 설명`nx = 1`n"
$r = Invoke-CcCommit $d 'git add new.py && git commit -m x' 'cc-new'
Assert-Case -Name "commit-comments: 같은 명령 앞선 git add <untracked 새 파일> 의 주석도 차단" -R $r -ExpectExit 2 -ExpectContains $ccBlock
$d = New-CcRepo
$ccSub = Join-Path $d 'sub'; New-Item -ItemType Directory (Join-Path $ccSub 'rules') -Force | Out-Null
Set-CcFile (Join-Path $ccSub 'rules') 'r.md' "# 근거`n"
Set-CcFile $ccSub 'ptr.py' "# 근거는 ``rules/r.md```nx = 1`n"
$r = Invoke-CcCommit $ccSub 'git add ptr.py && git commit -m x' 'cc-sub-ptr'
Assert-Case -Name "commit-comments: 하위 폴더에서 git add <새 파일> && commit — 파일 폴더 기준 실재 .md 경로 주석은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
Set-CcFile $ccSub 'plain.py' "# 새 파일 설명`nx = 1`n"
$r = Invoke-CcCommit $ccSub 'git add plain.py && git commit -m x' 'cc-sub-plain'
Assert-Case -Name "commit-comments: 하위 폴더에서 git add <새 파일> && commit — 예외 없는 주석은 차단 (음성 짝)" -R $r -ExpectExit 2 -ExpectContains $ccBlock

$d = New-CcRepo
$ccEditJson = @{ session_id = 'cc-approved'; tool_name = 'Edit'; cwd = $d; tool_input = @{ file_path = (Join-Path $d 'b.cs'); old_string = 'int b;'; new_string = "// 편집 때 남긴 설명`nint b;" } } | ConvertTo-Json -Compress -Depth 5
$null = Invoke-Hook 'guard-harness.ps1' $ccEditJson
$null = Invoke-Hook 'guard-harness.ps1' $ccEditJson
Set-CcFile $d 'b.cs' "// 편집 때 남긴 설명`nint b;`n"; git -C $d add b.cs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-approved'
Assert-Case -Name "commit-comments: 편집 게이트에 두 번 낸 주석도 커밋에서 차단" -R $r -ExpectExit 2 -ExpectContains '[HARNESS] BLOCKED: 커밋에 새 주석이 있습니다'
Assert-Case -Name "commit-comments: 차단 메시지가 보존 등록·rationale 선작성을 안내한다" -R $r -ExpectExit 2 -ExpectContains 'Comment (보존) 경로에 그 파일을 등록한 뒤, 근거 포인터 주석이면 가리키는 .md 문서를 먼저 만든'

$d = New-CcRepo
Set-CcFile $d 'a.cs' "int a;`n"; Set-CcFile $d 'b.cs' "// 기존 설명`nint b;`n"; git -C $d add a.cs b.cs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-move'
Assert-Case -Name "commit-comments: 주석을 파일 사이로 옮긴 커밋은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

$d = New-CcRepo
Set-CcFile $d 's.py' ('Y = """' + "`n# 안쪽 줄`njobs:`n" + '"""' + "`nx = 1`n"); git -C $d add s.py
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-pystr'
Assert-Case -Name "commit-comments: .py 문자열 안의 # 줄만 더한 커밋은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$d = New-CcRepo
Set-CcFile $d 's.py' ('Y = """' + "`njobs:`n" + '"""' + "`n# 닫힌 뒤 주석`nx = 1`n"); git -C $d add s.py
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-pystr-neg'
Assert-Case -Name "commit-comments: .py 문자열이 닫힌 뒤의 # 주석을 더한 커밋은 차단" -R $r -ExpectExit 2 -ExpectContains $ccBlock

$d = New-CcRepo
Set-CcFile $d 'q.rs' "/// 화면에 보이는 줄 범위를 센다.`nfn rows() {}`n`n/// 보이는 칸 수를 센다.`n/// 접힌 칸은 빼지 않는다.`nfn span() {}`n"; git -C $d add q.rs; git -C $d commit -qm doc
$ccBase = (git -C $d rev-parse --short HEAD).Trim()
Set-CcFile $d 'q.rs' "fn rows() {}`n`nfn span() {}`n"; git -C $d commit -qam drop
Set-CcFile $d 'plan.md' "# plan`n`n## Goal`n`n> BASE: $ccBase`n"
Set-CcFile $d 'q.rs' "/// 화면에 보이는 줄 범위를 센다.`nfn rows() {}`n"; git -C $d add q.rs
$r = Invoke-CcCommit $d 'git commit -m x -- q.rs' 'cc-base-restore'
Assert-Case -Name "commit-comments: 앞 커밋에서 지운 plan BASE doc 을 되살린 커밋은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
Set-CcFile $d 'q.rs' "fn rows() {}`n`n/// BASE 에 없던 새 설명.`nfn cols() {}`n"; git -C $d add q.rs
$r = Invoke-CcCommit $d 'git commit -m x -- q.rs' 'cc-base-new'
Assert-Case -Name "commit-comments: plan BASE 에 doc 이 없던 항목의 doc 커밋은 같은 레포에서도 차단" -R $r -ExpectExit 2 -ExpectContains $ccBlock
Set-CcFile $d 'q.rs' "/// 보이는 줄의 범위를 센다.`nfn rows() {}`n"; git -C $d add q.rs
$r = Invoke-CcCommit $d 'git commit -m x -- q.rs' 'cc-base-reword'
Assert-Case -Name "commit-comments: plan BASE 때 같은 항목의 doc 을 문구만 고쳐 되살린 커밋은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
Set-CcFile $d 'q.rs' "/// 보이는 줄의 범위를 센다.`n/// 스크롤 위치는 보지 않는다.`nfn rows() {}`n"; git -C $d add q.rs
$r = Invoke-CcCommit $d 'git commit -m x -- q.rs' 'cc-base-reword-grow'
Assert-Case -Name "commit-comments: plan BASE 때보다 줄이 많은 문구 수정 복원 커밋은 차단" -R $r -ExpectExit 2 -ExpectContains $ccBlock
Set-CcFile $d 'q.rs' "fn rows() {}`n`n/// 보이는 칸의 수를 센다.`n/// 접힌 칸은 세지 않는다.`nfn span() {}`n"; git -C $d add q.rs
$r = Invoke-CcCommit $d 'git commit -m x -- q.rs' 'cc-base-reword-two'
Assert-Case -Name "commit-comments: plan BASE 때 2줄이던 doc 을 2줄로 문구만 고쳐 되살린 커밋은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

$d = New-CcRepo
Set-CcFile $d 'a.cs' "// 기존 설명`n// 남의 staged 설명`nint a;`n"; git -C $d add a.cs
Set-CcFile $d 'b.cs' "int b;`nint c;`n"
$r = Invoke-CcCommit $d 'git commit -m x -- b.cs' 'cc-only'
Assert-Case -Name "commit-comments: 다른 파일에 주석이 staged 돼도 git commit -- <주석 없는 경로> 는 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

$d = New-CcRepo
Set-CcFile $d 'a.cs' "// 기존 설명`n// 병합으로 온 설명`nint a;`n"; git -C $d add a.cs
Set-Content -LiteralPath (Join-Path $d '.git/MERGE_HEAD') -Value (git -C $d rev-parse HEAD)
$r = Invoke-CcCommit $d 'git commit --no-edit' 'cc-merge'
Assert-Case -Name "commit-comments: MERGE_HEAD 가 있는 커밋은 검사하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

$d = New-CcRepo
Set-CcFile $d 'b.cs' "int b;`nint c;`n"; git -C $d add b.cs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-code'
Assert-Case -Name "commit-comments: 주석 없는 커밋은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
Set-CcFile $d 'a.cs' "int a;`n"; git -C $d add a.cs
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-del'
Assert-Case -Name "commit-comments: 주석을 지우기만 한 커밋은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
Set-CcFile $d 'doc.md' "# 문서`n<!-- 메모 -->`n"; git -C $d add doc.md
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-md'
Assert-Case -Name "commit-comments: .md 만 담은 커밋은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

$d = New-CcRepo
Set-CcFile $d 'a.cs' "// 기존 설명`n// 드라이런 설명`nint a;`n"; git -C $d add a.cs
$r = Invoke-CcCommit $d 'git commit --dry-run -m x' 'cc-dry'
Assert-Case -Name "commit-comments: --dry-run 은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-CcCommit $d "git commit -m `"`$(cat <<'MSG'`n# 제목처럼 보이는 줄`nMSG`n)`" -- doc.md" 'cc-heredoc'
Assert-Case -Name "commit-comments: heredoc 메시지 본문의 # 줄은 주석으로 세지 않는다" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

$ccOut = Join-Path $ccRoot 'nogit'; New-Item -ItemType Directory $ccOut -Force | Out-Null
$r = Invoke-CcCommit $ccOut 'git commit -m x' 'cc-nogit'
Assert-Case -Name "commit-comments: 레포 밖(git 실패)은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

$d = New-CcRepo
for ($i = 0; $i -lt 201; $i++) { Set-CcFile $d "f$i.cs" "// 대량 설명 $i`nint v$i;`n" }
git -C $d add .
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-cap'
Assert-Case -Name "commit-comments: 수집 상한을 넘으면 알리고 통과" -R $r -ExpectExit 0 -ExpectContains '상한'

$d = New-CcMoveRepo
$r = Invoke-CcCommit $d 'git commit -m x -- n.rs' 'cc-move'
Assert-Case -Name "commit-comments: 다른 파일 BASE 의 doc 을 그 파일에서 지우고 옮긴 커밋은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
Set-CcFile $d 'm.rs' $ccMoveA
$r = Invoke-CcCommit $d 'git commit -m x -- n.rs' 'cc-copy'
Assert-Case -Name "commit-comments: 원래 파일에 남은 doc 의 복사 커밋은 차단" -R $r -ExpectExit 2 -ExpectContains $ccBlock

$ccBig = ((1..20001 | ForEach-Object { "`$v$_ = $_" }) -join "`n") + "`n"
$ccUnity = ((1..25000 | ForEach-Object { "  m_Field${_}: {fileID: $_}" }) -join "`n") + "`n"
$ccHalf = ((1..12000 | ForEach-Object { "`$w$_ = $_" }) -join "`n") + "`n"
$d = New-CcRepo
Set-CcFile $d 'big.ps1' $ccBig; git -C $d add big.ps1
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-line-cap'
Assert-Case -Name "commit-comments: 대상 파일 추가 줄이 상한(20000)을 넘으면 알리고 통과" -R $r -ExpectExit 0 -ExpectContains '추가 줄 20001'
$d = New-CcRepo
Set-CcFile $d 'Big.unity' $ccUnity; Set-CcFile $d 'a.cs' "// 기존 설명`n// 큰 비대상 옆 새 설명`nint a;`n"; git -C $d add .
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-big-nontarget'
Assert-Case -Name "commit-comments: 큰 비대상 파일과 함께 스테이징한 대상 파일의 새 주석은 차단" -R $r -ExpectExit 2 -ExpectContains '큰 비대상 옆 새 설명'
$d = New-CcRepo
Set-CcFile $d 'Big.unity' $ccUnity; Set-CcFile $d 'a.cs' "// 기존 설명`n// 큰 비대상 옆 새 설명`nint a;`n"
$r = Invoke-CcCommit $d 'git add -A && git commit -m x' 'cc-big-nontarget-add'
Assert-Case -Name "commit-comments: git add -A && commit 으로 큰 비대상 파일과 함께 낸 대상 파일 새 주석도 차단" -R $r -ExpectExit 2 -ExpectContains '큰 비대상 옆 새 설명'
$d = New-CcRepo
Set-CcFile $d 'half.ps1' $ccHalf; git -C $d add half.ps1
Set-CcFile $d 'half.ps1' ($ccHalf + "# 작업 트리에만 더한 설명`n")
$r = Invoke-CcCommit $d 'git add -A && git commit -m x' 'cc-index-worktree'
Assert-Case -Name "commit-comments: 같은 파일의 index·작업 트리 줄을 두 번 세지 않아 상한 아래면 새 주석을 차단" -R $r -ExpectExit 2 -ExpectContains '작업 트리에만 더한 설명'
$d = New-CcRepo
Set-CcFile $d 'notes.txt' "# 옮겨 갈 설명`n`$n = 1`n"; git -C $d add notes.txt; git -C $d commit -qm notes
git -C $d mv notes.txt notes.ps1
$r = Invoke-CcCommit $d 'git commit -m x' 'cc-rename'
Assert-Case -Name "commit-comments: 비대상 파일을 대상 확장자로 이름만 바꾼 커밋은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$d = New-CcRepo
Set-CcFile $d 'fresh.ps1' $ccBig
$r = Invoke-CcCommit $d 'git add -A && git commit -m x' 'cc-untracked-cap'
Assert-Case -Name "commit-comments: git add -A 로 넣는 untracked 대상 파일이 상한을 넘으면 알리고 통과" -R $r -ExpectExit 0 -ExpectContains '추가 줄 20001'
}

if (Test-ScenarioUnit 8) {
$ccSlowDir = Join-Path $ccRoot 'slow-base-git'; New-Item -ItemType Directory $ccSlowDir -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $ccSlowDir 'git.cmd'), "@echo %*| findstr /c:show /c:grep >nul && ping -n 7 127.0.0.1 >nul`r`n@`"$ccRealGit`" %*`r`n")
$d = New-CcMoveRepo
$ccSaved = @{ PATH = $env:PATH; T = $env:KARINA_COMMIT_GIT_TIMEOUT_MS }
try {
    $env:PATH = $ccSlowDir + [System.IO.Path]::PathSeparator + $env:PATH
    $env:KARINA_COMMIT_GIT_TIMEOUT_MS = '60000'
    $r = Invoke-Hook 'guard-bash.ps1' (@{ session_id = 'cc-move-slow'; tool_name = 'Bash'; cwd = $d; tool_input = @{ command = 'git commit -m x -- n.rs' } } | ConvertTo-Json -Compress) -Process
} finally { $env:PATH = $ccSaved.PATH; $env:KARINA_COMMIT_GIT_TIMEOUT_MS = $ccSaved.T }
Assert-Case -Name "commit-comments: BASE 복원·이동 판정 git 이 6초씩 늦어도 다른 파일 BASE doc 을 옮긴 커밋은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
Set-CcFile $d 'm.rs' $ccMoveA
$r = Invoke-CcCommit $d 'git commit -m x -- n.rs' 'cc-copy-budget'
Assert-Case -Name "commit-comments: 예산이 남은 커밋 차단에는 BASE 확인 예산 원인 줄이 없다" -R $r -ExpectExit 2 -ExpectNotContains $ccBudgetLine
}

if (Test-ScenarioUnit 7) {
$ccVerySlowDir = Join-Path $ccRoot 'very-slow-base-git'; New-Item -ItemType Directory $ccVerySlowDir -Force | Out-Null
[System.IO.File]::WriteAllText((Join-Path $ccVerySlowDir 'git.cmd'), "@echo %*| findstr /c:show /c:grep >nul && ping -n 17 127.0.0.1 >nul`r`n@`"$ccRealGit`" %*`r`n")
$d = New-CcMoveRepo
$ccSaved = @{ PATH = $env:PATH; T = $env:KARINA_COMMIT_GIT_TIMEOUT_MS }
try {
    $env:PATH = $ccVerySlowDir + [System.IO.Path]::PathSeparator + $env:PATH
    $env:KARINA_COMMIT_GIT_TIMEOUT_MS = '60000'
    $r = Invoke-Hook 'guard-bash.ps1' (@{ session_id = 'cc-move-veryslow'; tool_name = 'Bash'; cwd = $d; tool_input = @{ command = 'git commit -m x -- n.rs' } } | ConvertTo-Json -Compress) -Process
} finally { $env:PATH = $ccSaved.PATH; $env:KARINA_COMMIT_GIT_TIMEOUT_MS = $ccSaved.T }
Assert-Case -Name "commit-comments: BASE 복원·이동 판정 git 이 예산을 넘겨 막으면 원인 줄과 재시도 안내를 낸다" -R $r -ExpectExit 2 -ExpectContains $ccBudgetLine
Assert-Case -Name "commit-comments: 예산 소진 차단은 '다시 내도 통과하지 않는다' 대신 재시도 안내를 낸다" -R $r -ExpectExit 2 -ExpectContains 'git 이 한가할 때 같은 커밋을 다시 내면 통과할 수 있습니다' -ExpectNotContains '같은 커밋을 다시 내도 통과하지 않습니다'
}
}

