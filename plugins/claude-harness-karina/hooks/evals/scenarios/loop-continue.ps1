# scenarios/loop-continue.ps1 — loop-continue 시나리오 (dot-source 전용, 단독 실행 금지)
# 호출자(run-hook-evals.ps1)의 공용 헬퍼(Assert-Case·Invoke-Hook)와 공유 변수($work·$iso)를 그대로 쓴다.
# 무엇을 재는가: 발동 마커 3경로 · 주입 1경로 · 침묵 7경로 · 집합 변경 재주입 · plan 탐색(상위·docs/plan.md·레포 경계 둘·불릿 집합). 판정 근거는
#   `scripts/rules/loop-continue-rationale.md` 의 §2·§6 이다.
# 세션 id 를 케이스마다 다르게 쓴다 — 마커·카운터가 세션 단위라 앞 케이스의 상태가 뒤 케이스를 오염시키지 않게 한다.
if (Test-HookSelected @('loop-continue')) {

$lcState = Join-Path $iso '.claude/.state/loop-continue'
$lcProj = Join-Path $work 'lcproj'; New-Item -ItemType Directory $lcProj -Force | Out-Null
$lcPlan = Join-Path $lcProj 'plan.md'
"- [x] **T1-1** 끝`n- [ ] **T2-1** 남음`n- [/] **T2-2** 진행 중" | Set-Content -LiteralPath $lcPlan -Encoding UTF8
$lcDone = Join-Path $work 'lcdone'; New-Item -ItemType Directory $lcDone -Force | Out-Null
"- [x] **T1-1** 끝" | Set-Content -LiteralPath (Join-Path $lcDone 'plan.md') -Encoding UTF8

function New-LcSkillJson([string]$sid, [string]$skill) {
    return (@{ session_id = $sid; hook_event_name = 'PreToolUse'; tool_name = 'Skill'; tool_input = @{ skill = $skill } } | ConvertTo-Json -Compress)
}
function New-LcStopJson([string]$sid, [string]$cwd, [hashtable]$extra = @{}) {
    $o = @{ session_id = $sid; hook_event_name = 'Stop'; cwd = $cwd; stop_hook_active = $false; background_tasks = @() }
    foreach ($k in $extra.Keys) { $o[$k] = $extra[$k] }
    return ($o | ConvertTo-Json -Compress -Depth 4)
}
function Test-LcMarker([string]$sid) {
    return @{ code = 0; out = "marker=$(Test-Path -LiteralPath (Join-Path $lcState ($sid + '.active')))" }
}

# ---- 발동 마커 3경로 ----
$r = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-m1' 'karina:implement')
Assert-Case -Name "loop-continue: Skill karina:implement 는 무출력" -R $r -ExpectExit 0 -ExpectSilent $true
Assert-Case -Name "loop-continue: Skill karina:implement 가 마커를 세운다" -R (Test-LcMarker 'lc-m1') -ExpectContains 'marker=True'
$r = Invoke-Hook 'loop-continue.ps1' (@{ session_id = 'lc-m2'; hook_event_name = 'UserPromptExpansion'; command_name = 'karina:implement' } | ConvertTo-Json -Compress)
Assert-Case -Name "loop-continue: /karina:implement 직접 입력이 마커를 세운다" -R (Test-LcMarker 'lc-m2') -ExpectContains 'marker=True'
$r = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-m3' 'karina:record-project-fact')
Assert-Case -Name "loop-continue: 다른 스킬은 마커를 세우지 않는다" -R (Test-LcMarker 'lc-m3') -ExpectContains 'marker=False'

# ---- 주입 1경로 ----
$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-i1' 'implement')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-i1' $lcProj)
Assert-Case -Name "loop-continue: 마커+미완이면 additionalContext 로 주입" -R $r -ExpectExit 0 -ExpectContains '"additionalContext"'
Assert-Case -Name "loop-continue: 주입 안내가 미완 ID 를 적는다" -R $r -ExpectExit 0 -ExpectContains 'T2-1, T2-2'
Assert-Case -Name "loop-continue: 완료 task 는 안내에 없다" -R $r -ExpectExit 0 -ExpectNotContains 'T1-1'
Assert-Case -Name "loop-continue: 주입 안내가 사용자 중단을 유지할 정지로 적는다" -R $r -ExpectExit 0 -ExpectContains '사용자가 중단을 지시'

# ---- 침묵 경로 ----
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-s1' $lcProj)
Assert-Case -Name "loop-continue: 마커 없으면 침묵" -R $r -ExpectExit 0 -ExpectSilent $true

$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-s2' 'karina:implement')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-s2' $lcDone)
Assert-Case -Name "loop-continue: 미완 0 이면 침묵" -R $r -ExpectExit 0 -ExpectSilent $true

$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-s3' 'karina:implement')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-s3' $lcProj @{ stop_hook_active = $true })
Assert-Case -Name "loop-continue: stop_hook_active 면 침묵" -R $r -ExpectExit 0 -ExpectSilent $true

$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-s4' 'karina:implement')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-s4' $lcProj @{ background_tasks = @(@{ id = 't1'; type = 'shell'; status = 'running' }) })
Assert-Case -Name "loop-continue: background_tasks 가 있으면 침묵" -R $r -ExpectExit 0 -ExpectSilent $true

$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-s5' 'karina:implement')
$null = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-s5' $lcProj)
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-s5' $lcProj)
Assert-Case -Name "loop-continue: 같은 집합 2회째는 주입(상한 2)" -R $r -ExpectExit 0 -ExpectContains '"additionalContext"'
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-s5' $lcProj)
Assert-Case -Name "loop-continue: 같은 집합 3회째는 침묵" -R $r -ExpectExit 0 -ExpectSilent $true

$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-s6' 'karina:implement')
$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-s6' 'karina:plan')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-s6' $lcProj)
Assert-Case -Name "loop-continue: karina:plan 발동 뒤에는 침묵(마커 제거)" -R $r -ExpectExit 0 -ExpectSilent $true

$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-s7' 'karina:implement')
$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-s7' 'karina:chain-plan')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-s7' $lcProj)
Assert-Case -Name "loop-continue: karina:chain-plan 발동 뒤에는 침묵(마커 제거)" -R $r -ExpectExit 0 -ExpectSilent $true

$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-s8' 'karina:implement')
$null = Invoke-Hook 'loop-continue.ps1' (@{ session_id = 'lc-s8'; hook_event_name = 'UserPromptExpansion'; command_name = 'chain-plan' } | ConvertTo-Json -Compress)
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-s8' $lcProj)
Assert-Case -Name "loop-continue: /chain-plan 직접 입력 뒤에는 침묵(마커 제거)" -R $r -ExpectExit 0 -ExpectSilent $true

$r = Invoke-Hook 'loop-continue.ps1' 'not json {'
Assert-Case -Name "loop-continue: 잘못된 stdin 은 침묵" -R $r -ExpectExit 0 -ExpectSilent $true

# ---- 집합 변경 재주입 — 상한이 세션 전체가 아니라 미완 집합 단위임을 본다 ----
$lcProj2 = Join-Path $work 'lcproj2'; New-Item -ItemType Directory $lcProj2 -Force | Out-Null
"- [ ] **T1-1** a`n- [ ] **T1-2** b" | Set-Content -LiteralPath (Join-Path $lcProj2 'plan.md') -Encoding UTF8
$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-c1' 'karina:implement')
$null = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-c1' $lcProj2)
$null = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-c1' $lcProj2)
"- [x] **T1-1** a`n- [ ] **T1-2** b" | Set-Content -LiteralPath (Join-Path $lcProj2 'plan.md') -Encoding UTF8
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-c1' $lcProj2)
Assert-Case -Name "loop-continue: 집합이 바뀌면 다시 주입" -R $r -ExpectExit 0 -ExpectContains 'T1-2'

# ---- [회차 4 T2] plan 상위 탐색 · 레포 경계 · 불릿 집합 ----
# session-context 와 같은 Find-PlanFileUpwards 사본으로 찾는다 — 근거는 `scripts/rules/loop-continue-rationale.md` 의
#   「§4 미완 판정식과 plan 탐색」. 케이스마다 발동 마커를 먼저 세운다 — 마커가 없으면 탐색 전에 침묵해 경계 케이스가
#   경계와 무관하게 통과한다. 부모 plan 의 미완 ID 는 그 케이스에만 있는 것(T9-9)이라 「잡았는가」가 ID 로 갈린다.
$lcUp = Join-Path $work 'lc-up-repo'
New-Item -ItemType Directory (Join-Path $lcUp '.git'), (Join-Path $lcUp 'src/sub') -Force | Out-Null
"- [ ] **T9-9** 부모" | Set-Content -LiteralPath (Join-Path $lcUp 'plan.md') -Encoding UTF8
$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-u1' 'karina:implement')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-u1' (Join-Path $lcUp 'src/sub'))
Assert-Case -Name "loop-continue: 하위 폴더 cwd 는 레포 루트 plan 의 미완 ID 를 주입한다 (회차 4 T2)" -R $r -ExpectExit 0 -ExpectContains 'T9-9'

$lcDp = Join-Path $work 'lc-docs-plan'
New-Item -ItemType Directory (Join-Path $lcDp 'docs') -Force | Out-Null
"- [ ] **T8-1** 문서 plan" | Set-Content -LiteralPath (Join-Path $lcDp 'docs/plan.md') -Encoding UTF8
$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-u2' 'karina:implement')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-u2' $lcDp)
Assert-Case -Name "loop-continue: docs/plan.md 를 찾아 그 라벨로 주입한다 (회차 4 T2)" -R $r -ExpectExit 0 -ExpectContains 'docs/plan.md 에 미완 task'

$lcNest = Join-Path $work 'lc-nest'
New-Item -ItemType Directory (Join-Path $lcNest 'child/.git') -Force | Out-Null
"- [ ] **T9-9** 부모" | Set-Content -LiteralPath (Join-Path $lcNest 'plan.md') -Encoding UTF8
$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-u3' 'karina:implement')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-u3' (Join-Path $lcNest 'child'))
Assert-Case -Name "loop-continue: 중첩 레포(.git 폴더)는 부모 plan 으로 주입하지 않는다 (회차 4 T2)" -R $r -ExpectExit 0 -ExpectSilent $true

$lcWt = Join-Path $work 'lc-wt-parent'
$lcWtChild = Join-Path $lcWt '.claude/worktrees/wt1'
New-Item -ItemType Directory (Join-Path $lcWt '.git'), $lcWtChild -Force | Out-Null
"- [ ] **T9-9** 부모" | Set-Content -LiteralPath (Join-Path $lcWt 'plan.md') -Encoding UTF8
'gitdir: ../../../.git/worktrees/wt1' | Set-Content -LiteralPath (Join-Path $lcWtChild '.git') -Encoding UTF8
$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-u4' 'karina:implement')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-u4' $lcWtChild)
Assert-Case -Name "loop-continue: worktree(.git 파일)는 부모 레포 plan 으로 주입하지 않는다 (회차 4 T2)" -R $r -ExpectExit 0 -ExpectSilent $true

$lcBul = Join-Path $work 'lc-bullets'; New-Item -ItemType Directory $lcBul -Force | Out-Null
"1. [ ] **T5-1** a`n+ [/] T5-2: b`n  - [ ] T5-3: c" | Set-Content -LiteralPath (Join-Path $lcBul 'plan.md') -Encoding UTF8
$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-u5' 'karina:implement')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-u5' $lcBul)
Assert-Case -Name "loop-continue: guard-write 불릿 집합의 미완 ID 를 모두 주입한다 (회차 4 T2)" -R $r -ExpectExit 0 -ExpectContains 'T5-1, T5-2, T5-3'
Remove-Item -Recurse -Force $lcUp, $lcDp, $lcNest, $lcWt, $lcBul -ErrorAction SilentlyContinue

$lcMk = Join-Path $work 'lc-markers'; New-Item -ItemType Directory $lcMk -Force | Out-Null
$lcBt = '```'
"- [x] **T1-1** a`n- [-] **T2-1** b`n- [~] **T2-2** c" | Set-Content -LiteralPath (Join-Path $lcMk 'plan.md') -Encoding UTF8
$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-f1' 'karina:implement')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-f1' $lcMk)
Assert-Case -Name "loop-continue: [-]·[~] 하위 항목을 미완 ID 로 주입한다" -R $r -ExpectExit 0 -ExpectContains 'T2-1, T2-2'
"- [ ] **T1-1** a`n$($lcBt)markdown`n- [ ] **T9-1** x`n$lcBt" | Set-Content -LiteralPath (Join-Path $lcMk 'plan.md') -Encoding UTF8
$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-f2' 'karina:implement')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-f2' $lcMk)
Assert-Case -Name "loop-continue: 백틱 펜스 밖 미완 ID 는 주입한다" -R $r -ExpectExit 0 -ExpectContains 'T1-1'
Assert-Case -Name "loop-continue: 백틱 펜스 안 체크박스는 주입하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains 'T9-1'
"- [ ] **T1-1** a`n~~~`n- [ ] **T9-1** x`n~~~" | Set-Content -LiteralPath (Join-Path $lcMk 'plan.md') -Encoding UTF8
$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-f3' 'karina:implement')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-f3' $lcMk)
Assert-Case -Name "loop-continue: ~~~ 펜스 안 체크박스는 주입하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains 'T9-1'
"- [ ] **T1-1** a`n$($lcBt)text`n- [ ] **T9-1** x" | Set-Content -LiteralPath (Join-Path $lcMk 'plan.md') -Encoding UTF8
$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-f4' 'karina:implement')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-f4' $lcMk)
Assert-Case -Name "loop-continue: 닫히지 않은 펜스 뒤 체크박스는 주입하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains 'T9-1'
"- [x] **T1-1** a`n- [X] **T1-2** b" | Set-Content -LiteralPath (Join-Path $lcMk 'plan.md') -Encoding UTF8
$null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson 'lc-f5' 'karina:implement')
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-f5' $lcMk)
Assert-Case -Name "loop-continue: [x]·[X] 뿐이면 침묵" -R $r -ExpectExit 0 -ExpectSilent $true
Remove-Item -Recurse -Force $lcMk -ErrorAction SilentlyContinue

if ($gitOk) {
function New-LcFinalRepo([string]$Name) {
    $d = Join-Path $work $Name
    New-Item -ItemType Directory (Join-Path $d 'src') -Force | Out-Null
    git -C $d init -q; git -C $d config user.email t@t; git -C $d config user.name t; git -C $d config core.autocrlf false
    'a' | Set-Content -LiteralPath (Join-Path $d 'src/a.txt') -Encoding UTF8
    git -C $d add src; git -C $d commit -qm base
    return $d
}
function Set-LcFinalPlan([string]$Dir, [string]$LogLine, [string]$Request = '직접 요청') {
    $lcF = '```'
    $text = "# plan`n`n> 요구: $Request`n`n## Goal`n`n> BASE: 0000000`n> 승인: 2026-11-19 · 화면 Y`n`n서식 예시 — 4번 검증: <SHA>`n`n## Investigation Log`n`n| 4번 줄 서식 | grep | 4번 검증: <full SHA> · clean |`n`n## 작업 단계`n`n- [x] **T1-1** 끝`n`n## Progress Log`n`n$lcF`n- 4번 검증: 1111111111111111111111111111111111111111 · clean`n$lcF`n$LogLine`n"
    [System.IO.File]::WriteAllText((Join-Path $Dir 'plan.md'), $text, [System.Text.UTF8Encoding]::new($false))
}
function Invoke-LcFinalStop([string]$Sid, [string]$Dir, [hashtable]$Extra = @{}) {
    $null = Invoke-Hook 'loop-continue.ps1' (New-LcSkillJson $Sid 'karina:implement')
    return Invoke-Hook 'loop-continue.ps1' (New-LcStopJson $Sid $Dir $Extra)
}

$lcFin = New-LcFinalRepo 'lc-final'
Set-LcFinalPlan $lcFin ''
$r = Invoke-LcFinalStop 'lc-e1' $lcFin
Assert-Case -Name "loop-continue: 전 task 완료·승인 plan 에 4번 검증 줄이 없으면 회차 끝 안내를 주입" -R $r -ExpectExit 0 -ExpectContains '4번 검증'
Assert-Case -Name "loop-continue: 서식 예시·펜스 안 줄은 4번 검증 줄로 세지 않는다" -R $r -ExpectExit 0 -ExpectContains '"additionalContext"'
Assert-Case -Name "loop-continue: 회차 끝 안내가 정지 유지와 회차 밖 커밋을 적는다" -R $r -ExpectExit 0 -ExpectContains '회차 밖'
Assert-Case -Name "loop-continue: 회차 끝 안내가 사용자 중단을 유지할 정지로 적는다" -R $r -ExpectExit 0 -ExpectContains '사용자가 중단을 지시'
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-e1' $lcFin)
Assert-Case -Name "loop-continue: 같은 HEAD 2회째 회차 끝 안내는 주입" -R $r -ExpectExit 0 -ExpectContains '"additionalContext"'
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-e1' $lcFin)
Assert-Case -Name "loop-continue: 같은 HEAD 3회째 회차 끝 안내는 침묵" -R $r -ExpectExit 0 -ExpectSilent $true

$lcHead = (git -C $lcFin rev-parse HEAD).Trim()
Set-LcFinalPlan $lcFin "- 4번 검증: $lcHead · clean"
$r = Invoke-LcFinalStop 'lc-e2' $lcFin
Assert-Case -Name "loop-continue: 4번 검증 SHA 가 HEAD 면 침묵" -R $r -ExpectExit 0 -ExpectSilent $true

'b' | Set-Content -LiteralPath (Join-Path $lcFin 'src/a.txt') -Encoding UTF8
git -C $lcFin commit -qam review-fix
$r = Invoke-LcFinalStop 'lc-e3' $lcFin
Assert-Case -Name "loop-continue: 4번 검증 뒤 plan 밖 파일이 커밋됐으면 재실행 안내를 주입" -R $r -ExpectExit 0 -ExpectContains 'src/a.txt'

$lcHead = (git -C $lcFin rev-parse HEAD).Trim()
Set-LcFinalPlan $lcFin "- 4번 검증: $lcHead · clean"
git -C $lcFin add plan.md; git -C $lcFin commit -qm plan-file
$r = Invoke-LcFinalStop 'lc-e4' $lcFin
Assert-Case -Name "loop-continue: 4번 검증 뒤 커밋이 plan 파일뿐이면 침묵" -R $r -ExpectExit 0 -ExpectSilent $true

$lcHead = (git -C $lcFin rev-parse HEAD).Trim()
Set-LcFinalPlan $lcFin ("- 4번 검증: $lcHead · clean`n`n## Deferred / Follow-up`n`n- ``[등재]`` **골든 미실행** — 검증하지 않았다")
$r = Invoke-LcFinalStop 'lc-r1' $lcFin
Assert-Case -Name "loop-continue: 4번 clean 뒤 넘김 사유 없는 남은 이슈가 있으면 주입" -R $r -ExpectExit 0 -ExpectContains '넘김 사유'
Assert-Case -Name "loop-continue: 남은 이슈 안내가 걸린 항목을 적는다" -R $r -ExpectExit 0 -ExpectContains '골든 미실행'
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-r1' $lcFin)
Assert-Case -Name "loop-continue: 같은 남은 이슈 2회째는 주입" -R $r -ExpectExit 0 -ExpectContains '"additionalContext"'
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-r1' $lcFin)
Assert-Case -Name "loop-continue: 같은 남은 이슈 3회째는 침묵" -R $r -ExpectExit 0 -ExpectSilent $true
Set-LcFinalPlan $lcFin ("- 4번 검증: $lcHead · clean`n`n## Deferred / Follow-up`n`n- ``[등재]`` **경고 조건 변경** — 넘김 사유 ②(의도된 동작 변경)")
$r = Invoke-LcFinalStop 'lc-r2' $lcFin
Assert-Case -Name "loop-continue: 남은 이슈에 넘김 사유가 있으면 침묵" -R $r -ExpectExit 0 -ExpectSilent $true
Set-LcFinalPlan $lcFin "`n## Deferred / Follow-up`n`n- ``[등재]`` **골든 미실행** — 검증하지 않았다"
$r = Invoke-LcFinalStop 'lc-r3' $lcFin
Assert-Case -Name "loop-continue: 4번 공백이 있으면 남은 이슈보다 4번 안내가 먼저다" -R $r -ExpectExit 0 -ExpectNotContains '넘김 사유'
Set-LcFinalPlan $lcFin ("- 4번 검증: $lcHead · clean`n`n## Deferred / Follow-up`n`n- ``[등재]`` **골든 미실행** — 검증하지 않았다") '코디네이터 인터뷰 경유 — spec 원문'
$r = Invoke-LcFinalStop 'lc-r4' $lcFin
Assert-Case -Name "loop-continue: 중계 plan 은 남은 이슈 안내 대상이 아니다" -R $r -ExpectExit 0 -ExpectSilent $true

Set-LcFinalPlan $lcFin '' '코디네이터 인터뷰 경유 — spec 원문'
$r = Invoke-LcFinalStop 'lc-e5' $lcFin
Assert-Case -Name "loop-continue: 중계 plan 은 회차 끝 안내 대상이 아니다" -R $r -ExpectExit 0 -ExpectSilent $true

$lcPlanFile = Join-Path $lcFin 'plan.md'
$lcHead = (git -C $lcFin rev-parse HEAD).Trim()
Set-LcFinalPlan $lcFin ''
[System.IO.File]::WriteAllText($lcPlanFile, ([System.IO.File]::ReadAllText($lcPlanFile) -replace '서식 예시 — 4번 검증: <SHA>', "- 4번 검증: $lcHead · clean"), [System.Text.UTF8Encoding]::new($false))
$r = Invoke-LcFinalStop 'lc-e9' $lcFin
Assert-Case -Name "loop-continue: Progress Log 밖(Goal)의 4번 검증 줄은 세지 않고 주입" -R $r -ExpectExit 0 -ExpectContains '"additionalContext"'
Set-LcFinalPlan $lcFin ''
[System.IO.File]::WriteAllText($lcPlanFile, ([System.IO.File]::ReadAllText($lcPlanFile) -replace '> 승인: 2026-11-19 · 화면 Y', '> 승인: <승인일 YYYY-MM-DD>'), [System.Text.UTF8Encoding]::new($false))
$r = Invoke-LcFinalStop 'lc-e10' $lcFin
Assert-Case -Name "loop-continue: 승인 표지 없는 완료 plan 은 git 레포 안에서도 침묵" -R $r -ExpectExit 0 -ExpectSilent $true

Set-LcFinalPlan $lcFin ''
$r = Invoke-Hook 'loop-continue.ps1' (New-LcStopJson 'lc-e6' $lcFin)
Assert-Case -Name "loop-continue: 마커 없으면 회차 끝 안내도 침묵" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-LcFinalStop 'lc-e7' $lcFin @{ background_tasks = @(@{ id = 't1'; type = 'shell'; status = 'running' }) }
Assert-Case -Name "loop-continue: background_tasks 가 있으면 회차 끝 안내도 침묵" -R $r -ExpectExit 0 -ExpectSilent $true

$lcNoGit = Join-Path $work 'lc-final-nogit'; New-Item -ItemType Directory $lcNoGit -Force | Out-Null
Set-LcFinalPlan $lcNoGit ''
$r = Invoke-LcFinalStop 'lc-e8' $lcNoGit
Assert-Case -Name "loop-continue: git 밖 폴더의 완료 plan 은 침묵" -R $r -ExpectExit 0 -ExpectSilent $true
function New-LcGateRepo([string]$Name, [string]$AgentsLine) {
    $d = New-LcFinalRepo $Name
    New-Item -ItemType Directory (Join-Path $d 'assets'), (Join-Path $d 'docs') -Force | Out-Null
    'x' | Set-Content -LiteralPath (Join-Path $d 'assets/logo.txt') -Encoding UTF8
    'x' | Set-Content -LiteralPath (Join-Path $d 'docs/guide.md') -Encoding UTF8
    if ($AgentsLine) { [System.IO.File]::WriteAllText((Join-Path $d 'AGENTS.md'), "# AGENTS`n`n## Build & Test`n`n$AgentsLine`n", [System.Text.UTF8Encoding]::new($false)) }
    git -C $d add -A; git -C $d commit -qm fixtures
    return $d
}
function Add-LcGateCommit([string]$Dir, [string[]]$Paths) {
    foreach ($p in $Paths) { Add-Content -LiteralPath (Join-Path $Dir $p) -Value 'more' -Encoding UTF8 }
    git -C $Dir add -A -- $Paths; git -C $Dir commit -qm after-check
}
$lcGateLine = '- **Gate 재사용 경로**: `assets/**` · `notes/*.txt`'
$lcGate = New-LcGateRepo 'lc-gate' $lcGateLine
Set-LcFinalPlan $lcGate ("- 4번 검증: " + (git -C $lcGate rev-parse HEAD).Trim() + " · clean")
Add-LcGateCommit $lcGate @('assets/logo.txt')
$r = Invoke-LcFinalStop 'lc-g1' $lcGate
Assert-Case -Name "loop-continue: 4번 검증 뒤 커밋이 Gate 재사용 경로 안 파일뿐이면 침묵" -R $r -ExpectExit 0 -ExpectSilent $true
Add-LcGateCommit $lcGate @('assets/logo.txt', 'src/a.txt')
$r = Invoke-LcFinalStop 'lc-g2' $lcGate
Assert-Case -Name "loop-continue: Gate 재사용 경로 안·밖이 섞이면 재실행 안내를 주입" -R $r -ExpectExit 0 -ExpectContains 'src/a.txt'
Assert-Case -Name "loop-continue: 재실행 안내 문구에 Gate 재사용 경로 안 파일은 싣지 않는다" -R $r -ExpectExit 0 -ExpectNotContains 'assets/logo.txt'

$lcGateNone = New-LcGateRepo 'lc-gate-none' ''
Set-LcFinalPlan $lcGateNone ("- 4번 검증: " + (git -C $lcGateNone rev-parse HEAD).Trim() + " · clean")
Add-LcGateCommit $lcGateNone @('docs/guide.md')
$r = Invoke-LcFinalStop 'lc-g3' $lcGateNone
Assert-Case -Name "loop-continue: Gate 재사용 경로 선언이 없으면 문서만 바꾼 커밋에도 주입" -R $r -ExpectExit 0 -ExpectContains 'docs/guide.md'

$lcGateSub = New-LcGateRepo 'lc-gate-sub' $lcGateLine
$lcGateSubPlan = Join-Path $lcGateSub 'src'
Set-LcFinalPlan $lcGateSubPlan ("- 4번 검증: " + (git -C $lcGateSub rev-parse HEAD).Trim() + " · clean")
Add-LcGateCommit $lcGateSub @('assets/logo.txt')
$r = Invoke-LcFinalStop 'lc-g4' $lcGateSubPlan
Assert-Case -Name "loop-continue: plan 이 하위 폴더에 있어도 glob 을 AGENTS.md 폴더 기준으로 맞춰 침묵" -R $r -ExpectExit 0 -ExpectSilent $true

$lcGateEmpty = New-LcGateRepo 'lc-gate-empty' '- **Gate 재사용 경로**: 없음'
Set-LcFinalPlan $lcGateEmpty ("- 4번 검증: " + (git -C $lcGateEmpty rev-parse HEAD).Trim() + " · clean")
Add-LcGateCommit $lcGateEmpty @('assets/logo.txt')
$r = Invoke-LcFinalStop 'lc-g5' $lcGateEmpty
Assert-Case -Name "loop-continue: Gate 재사용 경로 줄에 백틱 glob 이 없으면 선언 없음으로 보고 주입" -R $r -ExpectExit 0 -ExpectContains 'assets/logo.txt'
Remove-Item -Recurse -Force $lcFin, $lcNoGit, $lcGate, $lcGateNone, $lcGateSub, $lcGateEmpty -ErrorAction SilentlyContinue
}

$lcHooks = Get-Content -LiteralPath (Join-Path $pluginRoot 'hooks/hooks.json') -Raw -Encoding UTF8 | ConvertFrom-Json
$lcUpeMatchers = @($lcHooks.hooks.UserPromptExpansion | Where-Object { ($_.hooks.command -join ' ') -match 'loop-continue' } | ForEach-Object { [string]$_.matcher })
$lcHit = @('karina:implement', 'implement', 'karina:plan', 'plan' | Where-Object {
    $cmd = $_
    @($lcUpeMatchers | Where-Object {
        if ($_ -match '^[A-Za-z0-9_ ,|-]*$') { ($_ -split '[|,]' | ForEach-Object { $_.Trim() }) -contains $cmd } else { $cmd -match $_ }
    }).Count -gt 0
})
Assert-Case -Name "loop-continue: UserPromptExpansion matcher 가 karina: 접두·무접두 두 형태를 모두 받는다" -R @{ code = 0; out = "hits=$($lcHit.Count)" } -ExpectContains 'hits=4'

}
