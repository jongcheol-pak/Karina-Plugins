# scenarios/session-context.ps1 — session-context 시나리오 (§13 — plan 요약·AGENTS 주입·vault 라인) (dot-source 전용, 단독 실행 금지)
# 호출자(run-hook-evals.ps1)의 공용 헬퍼(Assert-Case·Invoke-Hook·New-WriteJson·New-CommitJson)와 공유 변수($work·$iso·$gitOk·$pw·$vdCache)를 그대로 쓴다.
# 파일명은 검증 대상 hook 기준이고, Invoke-Hook에 넘기는 문자열은 scripts/ 아래 hook 파일명이다.
# ==== 아래는 본체에서 원문 그대로 옮긴 구간 (순수 이동 — 재조립 등가 검사의 경계) ====
# =====================================================================
# 13) session-context 시나리오 (SessionStart — plan 상태 요약 주입, v1.112.0)
# =====================================================================
if (Test-HookSelected @('session-context')) {
    # 픽스처: plan.md(T 3개 중 미완료 2 — [x]/[/]/[ ] 혼합). 형식도 혼합이다 — 템플릿 정본의 볼드 하위 항목
    #   `- [ ] **T3-1**` 과 구형 `- [/] T2:` 를 함께 두어 계수가 두 형식을 다 세는지 잰다(회차 44 T4 — 종전 픽스처는
    #   전부 구형이라 볼드를 못 세는 회귀가 green 이었다: 대장 2026-09-06·09-08).
    $scProj = Join-Path $work 'sc-proj'
    New-Item -ItemType Directory $scProj -Force | Out-Null
    @(
        '# Plan: test',
        '## Tasks',
        '- [x] **T1-1** done (Type A)',
        '- [/] T2: in progress (Type B)',
        '- [ ] **T3-1** todo (Type C)'
    ) | Set-Content -Encoding UTF8 (Join-Path $scProj 'plan.md')

    # SC1: startup → plan 미완료 카운트 주입
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scProj } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: plan 미완료 카운트 주입 (SC1)" -R $r -ExpectExit 0 -ExpectContains '미완료 2'

    # SC2: compact → 재확인 리마인더 추가 주입
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scProj } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: compact 재확인 리마인더 (SC2)" -R $r -ExpectExit 0 -ExpectContains '요약 직후'

    # SC2b: fork → startup과 같은 경로를 탄다(plan 카운트 주입), compact 전용 리마인더는 나오지 않는다.
    #   공식 SessionStart matcher 값은 startup|resume|clear|compact|fork인데 fork만 배선에서 빠져 있어
    #   fork 세션에는 plan 상태·vault·AGENTS.md가 통째로 주입되지 않았다. hooks.json에 fork를 넣은 뒤
    #   이 두 케이스가 그 경로를 고정한다 — 스크립트는 무수정이다($source가 'compact'가 아니면 동일 경로).
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'fork'; cwd = $scProj } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: fork도 plan 카운트 주입 (SC2b)" -R $r -ExpectExit 0 -ExpectContains '미완료 2'
    Assert-Case -Name "session-context: fork에는 compact 리마인더 없음 (SC2c)" -R $r -ExpectExit 0 -ExpectNotContains '요약 직후'

    # SC3: plan/notes 없는 빈 폴더 → 무출력 (비 karina 프로젝트 노이즈 방지)
    $scEmpty = Join-Path $work 'sc-empty'; New-Item -ItemType Directory $scEmpty -Force | Out-Null
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scEmpty } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: plan/notes 없음 무출력 (SC3)" -R $r -ExpectExit 0 -ExpectSilent $true

    # SC4: 루트 plan 없음 → docs/plans/에 체크박스 plan이 있어도 주입하지 않는다 (v1.210.0 — 폴백 제거).
    #   과거 회차 plan의 미완료분이 이번 세션의 상태로 주입되던 경로를 닫은 것이라, 기대는 '무출력'이다.
    $scDocs = Join-Path $work 'sc-docs'
    New-Item -ItemType Directory (Join-Path $scDocs 'docs/plans') -Force | Out-Null
    @('- [x] T1: a', '- [ ] T2: b') | Set-Content -Encoding UTF8 (Join-Path $scDocs 'docs/plans/2026-07-01-feature.md')
    '- [2026-07-10] deferred 항목 (T 체크박스 아님)' | Set-Content -Encoding UTF8 (Join-Path $scDocs 'docs/plans/deferred.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDocs } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: docs/plans 과거 plan은 주입하지 않는다 (SC4)" -R $r -ExpectExit 0 -ExpectSilent $true

    # SC5: task 체크박스 없는 plan.md(비 karina 형식) → 카운트 오보 대신 존재 강등 문구
    $scNoT = Join-Path $work 'sc-not'; New-Item -ItemType Directory $scNoT -Force | Out-Null
    '# 자유 형식 계획 문서' | Set-Content -Encoding UTF8 (Join-Path $scNoT 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scNoT } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 비 karina plan 존재 강등 문구 (SC5)" -R $r -ExpectExit 0 -ExpectContains '존재'

    # SC6: 빈 stdin → 무출력 exit 0 (fail-open)
    $r = Invoke-Hook 'session-context.ps1' ''
    Assert-Case -Name "session-context: 빈 stdin 무출력 fail-open (SC6)" -R $r -ExpectExit 0 -ExpectSilent $true

    # SC7~SC9: AGENTS.md 목차 주입 — CLAUDE.md 가 없으면 Claude Code 가 AGENTS.md 를 읽으므로 hook 은 목차만 싣는다. 전용 픽스처(기존 $scProj 오염 방지, 4-C)
    $scAgents = Join-Path $work 'sc-agents'; New-Item -ItemType Directory $scAgents -Force | Out-Null
    @(
        '---', 'type: x', '---',
        '# Agent Guide',
        'SC_AGENTS_UNIQUE_MARKER 이 문자열은 AGENTS.md 전문에만 있다',
        '## DO NOT', '금지 항목'
    ) | Set-Content -Encoding UTF8 (Join-Path $scAgents 'AGENTS.md')
    @('# Plan', '- [ ] T1: todo') | Set-Content -Encoding UTF8 (Join-Path $scAgents 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scAgents } | ConvertTo-Json -Compress)
    # SC7: 목차는 싣고(헤딩 'Agent Guide') 본문 줄은 싣지 않는다 — 본문을 다시 실으면 Claude Code 로드분과 이중이 된다.
    Assert-Case -Name "session-context: AGENTS.md 목차만 주입 — 본문 미주입 (SC7)" -R $r -ExpectExit 0 -ExpectContains 'Agent Guide' -ExpectNotContains 'SC_AGENTS_UNIQUE_MARKER'
    Assert-Case -Name "session-context: AGENTS.md 근거 요구 문구 (SC8)" -R $r -ExpectExit 0 -ExpectContains '단정'

    # SC9: 16KB 초과 AGENTS.md → 전문 대신 섹션 목차 폴백 (헤딩 포함, 바이트로 상한 초과)
    $scBig = Join-Path $work 'sc-agents-big'; New-Item -ItemType Directory $scBig -Force | Out-Null
    (@('---', 'type: x', '---', '# Big Guide', '## Section One') + (1..2500 | ForEach-Object { '가나다라마 반복 채우기 줄' }) + @('### Sub Section', '끝')) | Set-Content -Encoding UTF8 (Join-Path $scBig 'AGENTS.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scBig } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 16KB 초과 AGENTS.md 목차 폴백 (SC9)" -R $r -ExpectExit 0 -ExpectContains '섹션:'
    # 초과 폴백은 "왜 안 들어왔는지"만 알리고 해소 경로를 안 줬다 — 그 상태로는 다음 세션도 같은 폴백을 받는다.
    Assert-Case -Name "session-context: 초과 폴백에 이관 절차 안내 (SC9d)" -R $r -ExpectExit 0 -ExpectContains 'record-project-fact'

    # SC9a~SC9c: 주입 상한 임박 경고 (v1.190.0) — 초과한 뒤에 알리면 그 세션은 이미 가이드를 잃은 채 돈다.
    #   임계는 llm-wiki 예산 신호와 같은 2축(95% OR 여유 500B)이지만, 16KB 예산에서는 **잔여축이 비율축에
    #   항상 포함된다**(여유 500B 미만 = 15,885B 이상 = 이미 96.9%). 그래서 양성 케이스는 비율축 하나만
    #   고정하고, 임계 자체가 살아 있는지는 아래 음성 케이스(SC9c)가 지킨다.
    # SC9a (양성): 상한의 95% 이상 — 목차 줄 꼬리에 임박 경고가 붙는다.
    $scNear = Join-Path $work 'sc-agents-near'; New-Item -ItemType Directory $scNear -Force | Out-Null
    # '가나다라마 반복 채우기 줄'은 UTF-8 36B + CRLF 2B = 38B/줄. 헤더 2줄 30B + 410줄 = 15,610B(실측, 95.3%)
    (@('# Near Guide', '## Section One') + (1..410 | ForEach-Object { '가나다라마 반복 채우기 줄' })) | Set-Content -Encoding UTF8 (Join-Path $scNear 'AGENTS.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scNear } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: AGENTS.md 주입 상한 임박 경고 — 비율축 (SC9a)" -R $r -ExpectExit 0 -ExpectContains '주입 상한 임박'
    Assert-Case -Name "session-context: 상한 이하도 목차만 — 본문 미주입 (SC9b)" -R $r -ExpectExit 0 -ExpectContains '섹션:' -ExpectNotContains '반복 채우기 줄'

    # SC9c (음성·델타): 상한의 80%대 — 어느 축도 안 걸려 경고가 없어야 한다.
    #   이 케이스가 없으면 "항상 경고"로 바꿔도 SC9a가 통과해 임계 판정이 무력화된다.
    $scFar = Join-Path $work 'sc-agents-far'; New-Item -ItemType Directory $scFar -Force | Out-Null
    # 헤더 2줄 + 341줄 = 12,988B(실측, 79.3%) — 여유 3,396B로 두 축 모두 미달
    (@('# Far Guide', '## Section One') + (1..341 | ForEach-Object { '가나다라마 반복 채우기 줄' })) | Set-Content -Encoding UTF8 (Join-Path $scFar 'AGENTS.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scFar } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 임박 미달이면 경고 없음 (SC9c)" -R $r -ExpectExit 0 -ExpectContains 'Far Guide' -ExpectNotContains '주입 상한 임박'

    # SC7c~SC7i · SC9e: Claude Code 는 cwd·상위에 CLAUDE.md · .claude/CLAUDE.md · CLAUDE.local.md 가 있으면
    #   AGENTS.md 를 읽지 않는다(code.claude.com/docs/en/memory 「When Claude Code reads AGENTS.md」).
    #   그때 hook 이 목차만 실으면 AGENTS.md 가 컨텍스트에서 통째로 빠지므로 전문을 싣는다.
    #   홈의 .claude/CLAUDE.md 는 세지 않고, CLAUDE.md 가 @AGENTS.md 를 import 하면 로드된 것으로 본다.
    $scAgentsBody = @('# Agent Guide', 'SC_AGENTS_UNIQUE_MARKER 이 문자열은 AGENTS.md 전문에만 있다', '## DO NOT', '금지 항목')
    function New-ScAgentsCm {
        param([string]$Name, [string]$ClaudeRel, [string[]]$ClaudeBody = @('# 프로젝트 지침'))
        $dir = Join-Path $work $Name; New-Item -ItemType Directory $dir -Force | Out-Null
        $scAgentsBody | Set-Content -Encoding UTF8 (Join-Path $dir 'AGENTS.md')
        if ($ClaudeRel) {
            $cm = Join-Path $dir $ClaudeRel
            New-Item -ItemType Directory (Split-Path $cm -Parent) -Force | Out-Null
            $ClaudeBody | Set-Content -Encoding UTF8 $cm
        }
        return $dir
    }
    function Invoke-ScStart { param([string]$Cwd, [string]$Source = 'startup') Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = $Source; cwd = $Cwd } | ConvertTo-Json -Compress) }

    $r = Invoke-ScStart (New-ScAgentsCm 'sc-agents-cm-root' 'CLAUDE.md')
    Assert-Case -Name "session-context: CLAUDE.md 있으면 AGENTS.md 전문 주입 (SC7c)" -R $r -ExpectExit 0 -ExpectContains 'SC_AGENTS_UNIQUE_MARKER' -ExpectNotContains '자체 로드하므로'
    Assert-Case -Name "session-context: CLAUDE.md 있으면 자동 로드 안 됨을 알린다 (SC7c2)" -R $r -ExpectExit 0 -ExpectContains '자동 로드되지 않'
    $r = Invoke-ScStart (New-ScAgentsCm 'sc-agents-cm-local' 'CLAUDE.local.md')
    Assert-Case -Name "session-context: CLAUDE.local.md 도 전문 주입 (SC7d)" -R $r -ExpectExit 0 -ExpectContains 'SC_AGENTS_UNIQUE_MARKER'
    $r = Invoke-ScStart (New-ScAgentsCm 'sc-agents-cm-dotclaude' '.claude/CLAUDE.md')
    Assert-Case -Name "session-context: .claude/CLAUDE.md 도 전문 주입 (SC7e)" -R $r -ExpectExit 0 -ExpectContains 'SC_AGENTS_UNIQUE_MARKER'

    # SC7f: 상위 디렉터리의 CLAUDE.md 도 센다 — cwd 만 보면 모노레포 하위에서 빠진다.
    $scCmParent = Join-Path $work 'sc-agents-cm-parent'; New-Item -ItemType Directory $scCmParent -Force | Out-Null
    @('# 상위 지침') | Set-Content -Encoding UTF8 (Join-Path $scCmParent 'CLAUDE.md')
    $scCmChild = Join-Path $scCmParent 'child'; New-Item -ItemType Directory $scCmChild -Force | Out-Null
    $scAgentsBody | Set-Content -Encoding UTF8 (Join-Path $scCmChild 'AGENTS.md')
    $r = Invoke-ScStart $scCmChild
    Assert-Case -Name "session-context: 상위 CLAUDE.md 도 전문 주입 (SC7f)" -R $r -ExpectExit 0 -ExpectContains 'SC_AGENTS_UNIQUE_MARKER'

    # SC7g: CLAUDE.md 가 AGENTS.md 를 import 하면 Claude Code 가 그 경로로 싣는다 — 전문을 또 실으면 이중이다.
    $r = Invoke-ScStart (New-ScAgentsCm 'sc-agents-cm-import' 'CLAUDE.md' @('# 프로젝트 지침', '@AGENTS.md'))
    Assert-Case -Name "session-context: CLAUDE.md 가 AGENTS.md 를 import 하면 목차만 (SC7g)" -R $r -ExpectExit 0 -ExpectContains '섹션:' -ExpectNotContains 'SC_AGENTS_UNIQUE_MARKER'
    # SC7g2: import 로 로드되는 레포에 「CLAUDE.md 가 없어」라고 말하면 세션마다 거짓 사실이 들어간다.
    Assert-Case -Name "session-context: import 로드는 import 라고 알린다 (SC7g2)" -R $r -ExpectExit 0 -ExpectContains 'import' -ExpectNotContains 'CLAUDE.md 가 없어'

    # SC7j: 상위 CLAUDE.md 의 `@AGENTS.md` 는 **그 폴더의** AGENTS.md 다 — cwd 의 AGENTS.md 는 여전히 안 실린다.
    $scImpParent = Join-Path $work 'sc-agents-cm-import-parent'; New-Item -ItemType Directory $scImpParent -Force | Out-Null
    @('# 상위 지침', '@AGENTS.md') | Set-Content -Encoding UTF8 (Join-Path $scImpParent 'CLAUDE.md')
    @('# Root Guide') | Set-Content -Encoding UTF8 (Join-Path $scImpParent 'AGENTS.md')
    $scImpChild = Join-Path $scImpParent 'pkg'; New-Item -ItemType Directory $scImpChild -Force | Out-Null
    $scAgentsBody | Set-Content -Encoding UTF8 (Join-Path $scImpChild 'AGENTS.md')
    $r = Invoke-ScStart $scImpChild
    Assert-Case -Name "session-context: 상위 CLAUDE.md 가 자기 AGENTS.md 를 import 해도 cwd 전문 주입 (SC7j)" -R $r -ExpectExit 0 -ExpectContains 'SC_AGENTS_UNIQUE_MARKER'

    # SC7k: import 경로는 그 CLAUDE.md 위치 기준이다 — .claude/CLAUDE.md 의 `@../AGENTS.md` 가 cwd 의 AGENTS.md 다.
    $r = Invoke-ScStart (New-ScAgentsCm 'sc-agents-cm-import-rel' '.claude/CLAUDE.md' @('# 프로젝트 지침', '@../AGENTS.md'))
    Assert-Case -Name "session-context: .claude/CLAUDE.md 의 상대 import 도 로드로 본다 (SC7k)" -R $r -ExpectExit 0 -ExpectContains '섹션:' -ExpectNotContains 'SC_AGENTS_UNIQUE_MARKER'

    # SC7h: 홈의 .claude/CLAUDE.md 는 사용자 지침이라 세지 않는다 — 가짜 홈으로 그 호출만 격리한다.
    #   가짜 홈이 cwd 의 상위여야 상위 탐색이 그 파일을 실제로 지나간다.
    $scFakeHome = Join-Path $work 'sc-home'
    New-Item -ItemType Directory (Join-Path $scFakeHome '.claude') -Force | Out-Null
    @('# 사용자 지침') | Set-Content -Encoding UTF8 (Join-Path $scFakeHome '.claude/CLAUDE.md')
    $scHomeProj = Join-Path $scFakeHome 'proj'; New-Item -ItemType Directory $scHomeProj -Force | Out-Null
    $scAgentsBody | Set-Content -Encoding UTF8 (Join-Path $scHomeProj 'AGENTS.md')
    $scSavedProfile = $env:USERPROFILE
    try { $env:USERPROFILE = $scFakeHome; $r = Invoke-ScStart $scHomeProj } finally { $env:USERPROFILE = $scSavedProfile }
    Assert-Case -Name "session-context: 홈 .claude/CLAUDE.md 는 세지 않아 목차만 (SC7h)" -R $r -ExpectExit 0 -ExpectContains '섹션:' -ExpectNotContains 'SC_AGENTS_UNIQUE_MARKER'

    # SC7i: 압축 직후에도 같은 판정 — compact 가 AGENTS.md 를 되살리는 유일한 경로다.
    $r = Invoke-ScStart (Join-Path $work 'sc-agents-cm-root') 'compact'
    Assert-Case -Name "session-context: compact 도 CLAUDE.md 있으면 전문 주입 (SC7i)" -R $r -ExpectExit 0 -ExpectContains 'SC_AGENTS_UNIQUE_MARKER'

    # SC9e: CLAUDE.md 가 있어도 16KB 초과면 전문 대신 목차 + Read — 상한은 그대로 주입 비용의 상방이다.
    $scCmBig = Join-Path $work 'sc-agents-cm-big'; New-Item -ItemType Directory $scCmBig -Force | Out-Null
    (@('# Big Guide', '## Section One') + (1..2500 | ForEach-Object { '가나다라마 반복 채우기 줄' })) | Set-Content -Encoding UTF8 (Join-Path $scCmBig 'AGENTS.md')
    @('# 프로젝트 지침') | Set-Content -Encoding UTF8 (Join-Path $scCmBig 'CLAUDE.md')
    $r = Invoke-ScStart $scCmBig
    Assert-Case -Name "session-context: CLAUDE.md + 16KB 초과면 목차와 미로드 안내 (SC9e)" -R $r -ExpectExit 0 -ExpectContains '자동 로드되지 않' -ExpectNotContains '반복 채우기 줄'
    Assert-Case -Name "session-context: CLAUDE.md + 16KB 초과도 목차는 싣는다 (SC9e2)" -R $r -ExpectExit 0 -ExpectContains '섹션:'

    # SC10: AGENTS.md 없는 기존 픽스처($scProj: plan만)는 AGENTS 문자열 무오염 — T1 acceptance ⓑ의 영구 그물.
    #   SC3(완전 빈 폴더)은 plan은 있고 AGENTS만 없는 이 경로를 고정 못 하므로 별도 케이스로 둔다.
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scProj } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: AGENTS.md 없는 픽스처 무오염 (SC10)" -R $r -ExpectExit 0 -ExpectContains '미완료 2' -ExpectNotContains 'AGENTS'

    # SC11~SC13: AGENTS.md 주입 견고성 가드 (v1.135.0 리뷰 후속 — 비정상 입력에서 깨진/오도 컨텍스트 주입 방지)
    # SC11: UTF-8이 아닌 인코딩(CP949 등) → 깨진 전문 대신 디코딩 실패 안내 1줄 (U+FFFD 검출 가드)
    $scMoji = Join-Path $work 'sc-agents-moji'; New-Item -ItemType Directory $scMoji -Force | Out-Null
    # 0xB0A1 = CP949 '가' — UTF-8로 디코딩하면 U+FFFD가 된다 (CodePagesEncodingProvider 없이 재현 가능한 원시 바이트)
    [System.IO.File]::WriteAllBytes((Join-Path $scMoji 'AGENTS.md'), [byte[]](0x23, 0x20, 0xB0, 0xA1, 0xB0, 0xA1, 0x0A))
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scMoji } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 비UTF-8 AGENTS.md 디코딩 실패 안내 (SC11)" -R $r -ExpectExit 0 -ExpectContains '디코딩 실패'

    # SC12: 목차 폴백 상한(1MB) 초과 → 읽기·목차 스캔 생략, Read 지시만 (타임아웃·메모리 방어)
    $scHuge = Join-Path $work 'sc-agents-huge'; New-Item -ItemType Directory $scHuge -Force | Out-Null
    [System.IO.File]::WriteAllText((Join-Path $scHuge 'AGENTS.md'), "# Huge Guide`n" + ('a' * 1100000))
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scHuge } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 1MB 초과 AGENTS.md 목차 생략 Read 지시 (SC12)" -R $r -ExpectExit 0 -ExpectContains '전문 미주입' -ExpectNotContains '섹션:'

    # SC13: 목차 폴백이 0열 코드 펜스 안의 '# 주석'을 섹션으로 오인하지 않음 (펜스 제거 후 헤딩 추출)
    $scFence = Join-Path $work 'sc-agents-fence'; New-Item -ItemType Directory $scFence -Force | Out-Null
    (@('# Real Guide', '## Real Section', '```sh', '# FENCE_MARKER not a heading', 'echo hi', '```') + (1..2500 | ForEach-Object { '가나다라마 반복 채우기 줄' })) | Set-Content -Encoding UTF8 (Join-Path $scFence 'AGENTS.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scFence } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 목차 폴백 코드 펜스 내 # 비오인 (SC13)" -R $r -ExpectExit 0 -ExpectContains '섹션:' -ExpectNotContains 'FENCE_MARKER'

    # SC14~SC17: compact 재읽기 경로 지정 — 압축 후 스킬 뒷부분이 유실되고
    #   재invoke로는 복구되지 않으므로, 미완료 task가 있을 때만 Read 대상을 못박는다.
    #   경로 리터럴을 골든이 고정한다 — 문구가 흔들려도 "무엇을 읽어야 하는지"는 남아야 한다.
    # SC14: compact + 미완료 task 있는 plan → 경로 지시 주입
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scProj } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: compact 재읽기 경로 SKILL.md (SC14)" -R $r -ExpectExit 0 -ExpectContains 'implement/SKILL.md'
    # SC14c (**경로 실재**): 상대 경로(`implement/SKILL.md`)는 어느 cwd 에서도 풀리지 않아 압축 직후 Read 가 실패한다.
    #   hook 과 같은 식(`"$(Split-Path -Parent <scripts>)/skills/…"`)으로 만든 절대 경로를 잰다 — `Join-Path` 는 구분자를 백슬래시로 바꿔 식이 갈리면 FAIL 한다.
    $scSkillsAbs = "$(Split-Path -Parent $scriptsDir)/skills"
    Assert-Case -Name "session-context: compact 구현 재읽기 경로가 절대 경로 (SC14c)" -R $r -ExpectExit 0 -ExpectContains "$scSkillsAbs/implement/SKILL.md"

    # SC39~SC39d: compact 직후 루프 제어 규칙 **내용 주입** (v1.212.0 T1).
    #   경로만 지시하면 실제로 읽었는지 검증할 장치가 없다. 그래서 루프가 멈추는 것을 막는
    #   절 하나의 원문을 잘라 함께 주입한다.
    #   ⚠ 대조 문자열은 **주입 헤더 라벨에 없고 절 본문에만 있는 것**을 고른다 — 라벨에도 있는
    #   문자열(예: '중단 조건 표')로 재면 절이 통째로 빠져도 라벨만으로 통과해 검사가 무력해진다.
    #   $r은 위 SC14 호출(compact + $scProj) 결과를 그대로 쓴다.
    # SC39 (양성): SKILL.md 「자율 루프」 절이 실려 온다.
    Assert-Case -Name "session-context: compact 루프 규칙 절 주입 (SC39)" -R $r -ExpectExit 0 -ExpectContains 'task 사이에서 묻지 않는다'
    # SC39d (발췌 표기): 주입분이 전문이 아니라 발췌임을 밝힌다 — 없으면 모델이 이것을 전문으로
    #   오인해 "나머지는 없다"고 판단할 수 있다.
    Assert-Case -Name "session-context: 주입분에 원문 발췌 표기 (SC39d)" -R $r -ExpectExit 0 -ExpectContains '원문 발췌'

    # SC39c (델타 음성): startup에는 주입하지 않는다 — 압축 전용 보완이라 매 세션 그만큼을 얹으면
    #   그 자체가 예산 낭비다. 이 케이스가 없으면 "항상 주입"으로 바꿔도 위 셋이 전부 통과한다.
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scProj } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: startup엔 루프 규칙 미주입 (SC39c)" -R $r -ExpectExit 0 -ExpectContains '미완료 2' -ExpectNotContains 'task 사이에서 묻지 않는다'
    # $r을 되돌리지 않는다 — 이어지는 SC28·SC29가 각각 자기 $r을 새로 만든다(불필요한 hook 실행 방지).

    # SC28/SC29: 계획 세션의 압축 리마인더 (v1.198.0 T8).
    #   SC14 계열은 `if ($planPath)` 안이라 **진행 중 plan이 있는 세션**만 닿는다. 계획을 세우던 중
    #   압축되면 plan이 없거나 task가 0개라 그 지시를 못 받는데, karina:plan도 본체가
    #   밖으로 밀리는 것은 같다. 두 케이스가 그 분기를 고정한다 — 양성 하나만 걸면 **델타 음성**이
    #   비어 "미완료 task 세션에도 계획 지시가 새는" 회귀를 못 잡는다.
    # SC28 (양성): compact + plan 없는 프로젝트 → 계획 재읽기 지시 발화
    $scPlanless = Join-Path $work 'sc-planless'; New-Item -ItemType Directory $scPlanless -Force | Out-Null
    '# Agent Guide' | Set-Content -Encoding UTF8 (Join-Path $scPlanless 'AGENTS.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scPlanless } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: compact + plan 없음 → 계획 재읽기 지시 (SC28)" -R $r -ExpectExit 0 -ExpectContains 'plan/SKILL.md'
    # SC28c (**경로 실재**): SC14c 와 같은 축 — 계획 재읽기 지시도 실재하는 절대 경로를 준다.
    Assert-Case -Name "session-context: compact 계획 재읽기 경로가 절대 경로 (SC28c)" -R $r -ExpectExit 0 -ExpectContains "$scSkillsAbs/plan/SKILL.md"

    # SC29 (델타 음성): compact + 미완료 task 있는 plan → 구현 지시만, 계획 지시는 미발화
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scProj } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: compact + 미완료 task엔 계획 지시 없음 (SC29)" -R $r -ExpectExit 0 -ExpectNotContains 'plan/SKILL.md'

    $scFire = {
        param([string]$Sid, [string]$Skill)
        foreach ($h in @('loop-continue.ps1', 'record-work-start.ps1')) {
            $null = Invoke-Hook $h (@{ hook_event_name = 'PreToolUse'; tool_name = 'Skill'; tool_input = @{ skill = $Skill }; session_id = $Sid } | ConvertTo-Json -Compress)
        }
    }
    $scCompact = { param([string]$Cwd, [string]$Sid) Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $Cwd; session_id = $Sid } | ConvertTo-Json -Compress) }

    & $scFire 'sc41' 'karina:plan'
    $r = & $scCompact $scPlanless 'sc41'
    Assert-Case -Name "session-context: compact 계획 규칙 절 주입 (SC41)" -R $r -ExpectExit 0 -ExpectContains '모든 사실 주장은 명령을 실행해 얻는다'
    Assert-Case -Name "session-context: 계획 주입에 발췌 표기 (SC41b)" -R $r -ExpectExit 0 -ExpectContains '원문 발췌 — plan/SKILL.md'
    # SC41c (델타 음성): startup엔 주입하지 않는다 — 압축 전용 보완이라 매 세션 얹으면 예산 낭비다.
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scPlanless } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: startup엔 계획 규칙 미주입 (SC41c)" -R $r -ExpectExit 0 -ExpectNotContains '모든 사실 주장은 명령을 실행해 얻는다'
    # SC41d (델타 음성): compact + 미완료 task 세션엔 계획 주입이 새지 않는다.
    #   ⚠ 대조 문자열은 **주입 본문**이어야 한다 — `plan/SKILL.md`로 걸면 SC29와 완전히 같아 새 회귀를 못 잡는다.
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scProj } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 미완료 task 세션엔 계획 규칙 미주입 (SC41d)" -R $r -ExpectExit 0 -ExpectNotContains '모든 사실 주장은 명령을 실행해 얻는다'
    $r = & $scCompact $scPlanless 'sc41f'
    Assert-Case -Name "session-context: 발동 기록 없는 compact 엔 계획 규칙 미주입 (SC41f)" -R $r -ExpectExit 0 -ExpectContains 'plan/SKILL.md' -ExpectNotContains '모든 사실 주장은 명령을 실행해 얻는다'
    Assert-Case -Name "session-context: 발동 기록 없는 compact 엔 조회 절차 미주입 (SC43j)" -R $r -ExpectExit 0 -ExpectNotContains '위키 조회 절차:'
    & $scFire 'sc41g' 'karina:plan'
    & $scFire 'sc41g' 'karina:implement'
    $r = & $scCompact $scPlanless 'sc41g'
    Assert-Case -Name "session-context: plan 뒤 implement 발동 compact 엔 계획 규칙 미주입 (SC41g)" -R $r -ExpectExit 0 -ExpectNotContains '모든 사실 주장은 명령을 실행해 얻는다'
    Assert-Case -Name "session-context: implement 발동 compact 엔 조회 절차 주입 (SC43i)" -R $r -ExpectExit 0 -ExpectContains '위키 조회 절차:'

    & $scFire 'sc42' 'karina:implement'
    $r = & $scCompact $scPlanless 'sc42'
    Assert-Case -Name "session-context: compact 결정 기록 규약 절 주입 (SC42)" -R $r -ExpectExit 0 -ExpectContains '트리거는 둘이다'
    Assert-Case -Name "session-context: 결정 기록 규약 주입에 발췌 표기 (SC42b)" -R $r -ExpectExit 0 -ExpectContains '원문 발췌 — REPO-DECISIONS.md 「쓰기」'
    Assert-Case -Name "session-context: 결정 기록 규약 주입이 「쓰기」 끝까지 포함 (SC42f)" -R $r -ExpectExit 0 -ExpectContains '그 회차의 마지막 커밋에 함께 넣는다' -ExpectNotContains '새 항목을 쓰지 않는다'
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scPlanless } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: startup엔 결정 기록 규약 미주입 (SC42c)" -R $r -ExpectExit 0 -ExpectNotContains '트리거는 둘이다'
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scProj } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 미완료 task 세션엔 결정 기록 규약 미주입 (SC42d)" -R $r -ExpectExit 0 -ExpectNotContains '트리거는 둘이다'
    & $scFire 'sc42g' 'karina:plan'
    $r = & $scCompact $scPlanless 'sc42g'
    Assert-Case -Name "session-context: plan 만 발동한 compact 엔 결정 기록 규약 미주입 (SC42g)" -R $r -ExpectExit 0 -ExpectNotContains '트리거는 둘이다'
    $r = & $scCompact $scPlanless 'sc42h'
    Assert-Case -Name "session-context: 발동 기록 없는 compact 엔 결정 기록 규약 미주입 (SC42h)" -R $r -ExpectExit 0 -ExpectNotContains '트리거는 둘이다'
    & $scFire 'sc42i' 'karina:plan'
    & $scFire 'sc42i' 'karina:implement'
    $r = & $scCompact $scPlanless 'sc42i'
    Assert-Case -Name "session-context: plan 뒤 implement 발동 compact 엔 결정 기록 규약 주입 (SC42i)" -R $r -ExpectExit 0 -ExpectContains '트리거는 둘이다'
    & $scFire 'sc41h' 'karina:plan'
    & $scFire 'sc41h' 'karina:implement'
    & $scFire 'sc41h' 'karina:plan'
    $r = & $scCompact $scPlanless 'sc41h'
    Assert-Case -Name "session-context: implement 뒤 plan 재발동 compact 엔 계획 규칙 주입 (SC41h)" -R $r -ExpectExit 0 -ExpectContains '모든 사실 주장은 명령을 실행해 얻는다'
    Assert-Case -Name "session-context: implement 뒤 plan 재발동 compact 엔 결정 기록 규약 미주입 (SC42j)" -R $r -ExpectExit 0 -ExpectNotContains '트리거는 둘이다'

    & $scFire 'sc43' 'karina:plan'
    $r = & $scCompact $scPlanless 'sc43'
    Assert-Case -Name "session-context: compact 조회 절차 경로 지시 (SC43)" -R $r -ExpectExit 0 -ExpectContains '위키 조회 절차:'
    # SC43b (**경로 정확성**): 라인이 있는 것만으로는 부족하다 — 경로가 틀리면 세션이 그 파일을
    #   못 읽어 조회 절차가 통째로 사라지는데, SC43은 접두 라벨만 보므로 그 회귀를 못 잡는다.
    #   ⚠ 슬래시 표기를 그대로 잰다 — **`Join-Path`는 단일 인자여도 구분자를 백슬래시로
    #   정규화한다**(2026-09-02 실측 — 이 어서션이 첫 실행에서 그것을 FAIL로 잡았다). 그래서 hook은
    #   보간("$skillsDir/llm-wiki/...")으로 뒤쪽 세그먼트를 슬래시로 고정한다 — 그것이 계약이다.
    Assert-Case -Name "session-context: 조회 절차 경로가 정확한가 (SC43b)" -R $r -ExpectExit 0 -ExpectContains 'skills/WIKI.md'
    Assert-Case -Name "session-context: 조회 절차 지시에 행동 문구 (SC43f)" -R $r -ExpectExit 0 -ExpectContains '호출측 스킬이 지목한 절만 읽으세요' -ExpectNotContains 'vault 판정 게이트'
    # SC43g (**절 지목**): 파일째 Read 지시는 계획 세션에 쓰지 않는 절(§3 이하)까지 싣는다 — 호출측 스킬이
    #   지목한 절만 읽으라는 문구가 이 줄의 계약이다(2026-09-29 — 읽을 절을 SKILL 포인터가 지목하게 바꿨다).
    Assert-Case -Name "session-context: 조회 절차 지시가 지목한 절만 읽게 한다 (SC43g)" -R $r -ExpectExit 0 -ExpectContains '지목한 절만'
    # SC43h (**추출 수단 동봉**): 절만 읽으라면서 수단을 주지 않으면 세션이 펜스 없는 grep 으로 흐른다 — PS 문자열의
    #   백틱 여섯 겹이 출력에서 세 개로 풀렸는지를 이 문자열로 잰다(겹이 틀리면 펜스 토글이 사라진다).
    Assert-Case -Name "session-context: 조회 절차 지시에 절 추출 awk 동봉 (SC43h)" -R $r -ExpectExit 0 -ExpectContains '/^(```|~~~)/{f=!f} !f&&/^## /{c++} c==n'
    # SC43c (델타 음성): startup엔 넣지 않는다 — 압축 전용 보완이라 매 세션 얹으면 예산 낭비다.
    #   ⚠ 대조 문자열은 **새 라인의 것**이어야 한다 — 옛 문자열(K 1 본문)로 두면 주입이 사라진
    #   지금은 어떤 출력에도 없어 이 케이스가 항상 통과하고 델타 음성 축이 조용히 죽는다.
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scPlanless } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: startup엔 조회 절차 미주입 (SC43c)" -R $r -ExpectExit 0 -ExpectNotContains '위키 조회 절차:'
    # SC43d (델타 음성): compact + 미완료 task 세션엔 새지 않는다.
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scProj } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 미완료 task 세션엔 조회 절차 미주입 (SC43d)" -R $r -ExpectExit 0 -ExpectNotContains '위키 조회 절차:'

    # SC30 (델타 음성): compact + plan도 AGENTS.md도 없는 비 karina 폴더 → 계획 지시 미발화.
    #   리마인더 대상이 karina 워크플로라 무관한 폴더에 뜨면 노이즈다(`:16` 무출력 규칙과 같은 취지).
    #   기존 SC15·SC23이 같은 빈 픽스처를 쓰지만 각각 다른 문자열만 assert해 이 회귀를 못 잡는다.
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scEmpty } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: compact + 비 karina 폴더엔 계획 지시 없음 (SC30)" -R $r -ExpectExit 0 -ExpectNotContains 'plan/SKILL.md'

    # SC15: compact + plan 없음 → 기존 일반 리마인더만, 경로 지정 없음 (무회귀)
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scEmpty } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: compact plan 없음 경로 미지정 (SC15)" -R $r -ExpectExit 0 -ExpectContains '요약 직후' -ExpectNotContains 'implement/SKILL.md'

    # SC16: compact + 전 task 완료 → **구현 경로**는 지정하지 않는다. 재개할 루프가 없으면
    #   그 세 파일을 읽힐 이유가 없다(이 케이스가 재는 것은 그 미주입이고 그 판정은 불변이다).
    #   ⚠ v1.208.0부터 이 상태에도 **계획 재읽기 지시**(plan/SKILL.md)는 나간다 — 완료된 plan이
    #   남은 채 새 계획을 세우는 세션이 두 분기 사이로 빠지던 사각을 닫았다(아래 SC38). assert가
    #   구현 경로 부재만 보므로 이 케이스는 그대로 유효하다.
    #   ⚠ 이 상태에도 조회 절차 줄(SC43)이 나가며 §3 완료 기록 절을 **스킬 이름**(karina:implement)으로 지목한다 —
    #   경로 문자열이 아니라 구현 경로 주입이 아니다(2026-09-29 회차 D5). 이 어서션을 스킬 이름까지 넓히지 않는다.
    $scDone = Join-Path $work 'sc-done'; New-Item -ItemType Directory $scDone -Force | Out-Null
    @('# Plan', '- [x] T1: done', '- [x] T2: done') | Set-Content -Encoding UTF8 (Join-Path $scDone 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scDone } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: compact 전 task 완료 경로 미지정 (SC16)" -R $r -ExpectExit 0 -ExpectContains '전부 완료' -ExpectNotContains 'implement/SKILL.md'

    # SC17: compact + 존재하지 않는 cwd → 기존 compact 문구는 그대로 나온다.
    #   이 라인이 cwd 검사 블록 밖에 있어야 성립하므로, 블록 안으로 옮기는 회귀를 골든이 막는다.
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = (Join-Path $work 'sc-nonexistent') } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: compact 무효 cwd 기본 문구 유지 (SC17)" -R $r -ExpectExit 0 -ExpectContains '요약 직후'

    # SC18~SC23: 위키 vault 설정 상태 주입 (v1.146.0) — 절차 K의 "미설정" 오판정을 기계로 차단.
    #   전용 격리 홈에 llm-wiki-config.json을 심는다($iso에는 config가 없어 미설정 상태이며 SC20이 그것을 쓴다).
    #   무회귀 1건(SC20) + 델타 3건(SC21 과다 주입·SC22 과억제·SC23 리마인더 오신호) 구성 —
    #   통과만 확인하는 케이스는 게이팅을 고정하지 못한다.
    $isoV = Join-Path $EvalRunTemp ("karina-hook-evals-vault-" + $suffix)
    $isoVault = Join-Path $isoV 'my-wiki'
    New-Item -ItemType Directory -Path (Join-Path $isoV '.claude') -Force | Out-Null
    New-Item -ItemType Directory -Path $isoVault -Force | Out-Null
    (@{ vault_path = ($isoVault -replace '\\', '/') } | ConvertTo-Json) | Set-Content -Encoding UTF8 (Join-Path $isoV '.claude/llm-wiki-config.json')

    # SC18: 설정+실재 → 경로와 "단정 금지" 문구가 함께 주입된다 (문구 리터럴 고정)
    $env:USERPROFILE = $isoV
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scProj } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: vault 설정됨 상태 주입 (SC18)" -R $r -ExpectExit 0 -ExpectContains '위키 vault: 설정됨'
    Assert-Case -Name "session-context: vault 단정 금지 문구 (SC18b)" -R $r -ExpectExit 0 -ExpectContains '단정하지 마세요'
    Assert-Case -Name "session-context: vault 라인의 허브 조건부 지시 (SC18c)" -R $r -ExpectExit 0 -ExpectContains '코드를 읽는 것보다 빠르면'
    Assert-Case -Name "session-context: vault 라인의 글로벌 절 포인터 (SC18d)" -R $r -ExpectExit 0 -ExpectContains '「프로젝트 맥락」'
    # SC18e (**조회 정본 포인터**): 회차 46이 이 라인의 「절차 K 참조 가능」을 `skills/WIKI.md`
    #   지목으로 바꿨다 — 계획·구현 세션은 절차 K를 로드하지 않아 그 안내가 손에 없는 규약을
    #   가리켰다. ⚠ **그 문면을 재는 어서션이 없어 잘못된 지시가 두 커밋을 살아남았고**
    #   골든 812/812는 그것을 잡지 못했다(사람 리뷰가 잡았다). 이 케이스가 그 자리를 메운다.
    Assert-Case -Name "session-context: vault 라인이 조회 정본을 지목 (SC18e)" -R $r -ExpectExit 0 -ExpectContains 'skills/WIKI.md'
    # SC18f (**경로 실재**): SC14c 와 같은 축 — vault 라인의 조회 정본도 실재하는 절대 경로를 준다.
    Assert-Case -Name "session-context: vault 라인 조회 정본이 절대 경로 (SC18f)" -R $r -ExpectExit 0 -ExpectContains "$scSkillsAbs/WIKI.md"

    # SC21 (델타): 설정+실재인데 비 karina cwd(plan·AGENTS 전무) → 게이팅으로 미주입.
    #   vault는 cwd와 무관한 사용자 홈 자원이라, 게이팅이 없으면 위키를 쓰는 사용자의 모든 세션에 라인이 붙는다.
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scEmpty } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 비 karina cwd는 vault 라인 미주입 (SC21)" -R $r -ExpectExit 0 -ExpectSilent $true

    # SC23 (델타): compact + 빈 cwd → 리마인더는 나오되 vault 라인은 미주입.
    #   리마인더는 cwd 블록 밖에서 append되므로 게이팅 신호가 아니다 — $lines.Count -gt 0 판정을 이 케이스가 검출한다.
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scEmpty } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: compact 리마인더는 vault 게이팅 신호 아님 (SC23)" -R $r -ExpectExit 0 -ExpectContains '요약 직후' -ExpectNotContains '위키 vault'

    # ⚠ 대조 문자열은 `위키 vault: 설정`이다 — `위키 vault`만 쓰면 **주입 본문**이 문다.
    #   절차 K 1(SKILL.md:108)이 `[karina 세션 컨텍스트] 위키 vault: …` 라인을 **예시로 인용**하는데,
    #   v1.218.0 후속이 그 구간을 주입 대상으로 만들면서 세 케이스가 한꺼번에 FAIL했다(실측).
    # SC41e (회귀 고정 — v1.217.0): 계획 규칙 **주입**의 `$cwdBaseCount` 짝 증가.
    #   이 분기는 「$lines.Add 1회 = $cwdBaseCount++ 1회」가 짝인데, 주입을 넣고 기준선을 올리지
    #   않으면 `$lines.Count -gt $cwdBaseCount`가 참이 되어 **vault 라인이 새로 붙는다**.
    #   ⚠ 픽스처의 AGENTS.md는 **0바이트여야 한다** — 분기 조건은 `Test-Path`로 존재만 보지만
    #   주입 블록은 `$agentsInfo.Length -gt 0`이라(session-context.ps1:474) 내용이 있으면
    #   AGENTS 라인이 먼저 들어가 그 자체가 정당한 vault 신호가 되고 델타가 0이 된다.
    #   (v1.217.0이 내용 있는 픽스처로 시도해 FAIL을 보고 「원리상 불가」로 오판했다가 F-7이 잡았다.)
    #   SC23은 계획 분기가 아예 발화하지 않는 빈 cwd이고 SC31b는 plan 라인이 이미 정당한 신호라,
    #   **둘 다 이 짝 증가를 잡지 못한다**.
    $scEmptyAg = Join-Path $work 'sc-empty-agents'; New-Item -ItemType Directory $scEmptyAg -Force | Out-Null
    New-Item -ItemType File -Path (Join-Path $scEmptyAg 'AGENTS.md') -Force | Out-Null
    & $scFire 'sc41e' 'karina:plan'
    $r = & $scCompact $scEmptyAg 'sc41e'
    Assert-Case -Name "session-context: 계획 규칙 주입도 vault 게이팅 신호 아님 (SC41e)" -R $r -ExpectExit 0 -ExpectContains '모든 사실 주장은 명령을 실행해 얻는다' -ExpectNotContains '위키 vault: 설정'
    Assert-Case -Name "session-context: 조회 절차 지시도 vault 게이팅 신호 아님 (SC43e)" -R $r -ExpectExit 0 -ExpectContains '위키 조회 절차:' -ExpectNotContains '위키 vault: 설정'
    & $scFire 'sc42e' 'karina:implement'
    $r = & $scCompact $scEmptyAg 'sc42e'
    Assert-Case -Name "session-context: 결정 기록 규약 주입도 vault 게이팅 신호 아님 (SC42e)" -R $r -ExpectExit 0 -ExpectContains '트리거는 둘이다' -ExpectNotContains '위키 vault: 설정'

    # SC31b: 계획 지시 줄이 $cwdBaseCount를 전체 재설정하면(`= $lines.Count`) 그 앞의 「plan 존재」 신호까지
    #   흡수돼 vault가 조용히 빠진다 — `++`여야 하는 이유를 SC31b가 고정한다.
    #   ⚠ 이 두 케이스를 vault 설정($env:USERPROFILE = $isoV) **앞**에 두면 $vaultLine이 $null이라
    #     게이팅 로직 자체가 안 돌아 회귀를 못 잡는다(초안이 그 자리에 있었고 리뷰 2종이 각각 잡았다).
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scNoT } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: compact + task 0개 plan에도 계획 지시 (SC31)" -R $r -ExpectExit 0 -ExpectContains 'plan/SKILL.md'
    Assert-Case -Name "session-context: 계획 지시가 vault 신호를 삼키지 않음 (SC31b)" -R $r -ExpectExit 0 -ExpectContains '위키 vault: 설정됨'

    # SC38/SC38b (v1.208.0 — 완료 plan 사각): compact + task가 **전부 완료**된 plan. 종전에는
    #   위 `$open -gt 0` 분기(구현 경로 지시)에도, 아래 계획 리마인더(`-not $planPath -or $all -eq 0`)
    #   에도 걸리지 않아 **아무 재읽기 지시도 나가지 않았다.** 회차를 마치면 plan.md는 task가 전부 [x]인
    #   채 남고 다음 계획 세션이 그 위에서 시작하므로 이 상태가 오히려 흔하다.
    #   ⚠ SC16이 같은 상태를 쓰지만 **vault 설정 구간 밖**이라 SC38b(vault 신호 유지)를 잴 수 없다 —
    #     SC31b와 같은 배치 제약이며, 여기 두어야 $cwdBaseCount 회귀가 실제로 검사된다.
    $scDone2 = Join-Path $work 'sc-done2'; New-Item -ItemType Directory $scDone2 -Force | Out-Null
    @('# Plan', '- [x] T1: done', '- [x] T2: done') | Set-Content -Encoding UTF8 (Join-Path $scDone2 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scDone2 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: compact + 전 task 완료 plan에도 계획 지시 (SC38)" -R $r -ExpectExit 0 -ExpectContains 'plan/SKILL.md'
    Assert-Case -Name "session-context: 완료 plan 계획 지시가 vault 신호를 삼키지 않음 (SC38b)" -R $r -ExpectExit 0 -ExpectContains '위키 vault: 설정됨'
    Assert-Case -Name "session-context: 완료 plan엔 구현 경로 미주입 (SC38c)" -R $r -ExpectExit 0 -ExpectNotContains 'implement/SKILL.md'

    # SC40~SC40i: plan `## Deferred / Follow-up`의 **미판정 건수 주입** (v1.214.0 T3).
    #   plan.md는 gitignore + 다음 회차 교체라, 대장(docs/plans/deferred.md)으로 옮기지 못한 항목은
    #   회차와 함께 사라진다. task 체크박스는 위 케이스들이 재지만 Deferred는 아무도 세지 않았다.
    #   마커 4종([등재]/[미등재:<사유>]/[미판정]/[다음 회차] — 형식 정본은
    #   plan/references/deferred-rules.md)이
    #   그 상태를 기계 판독 가능하게 만들고, hook은 **판정 마커가 붙지 않은 것**을 센다
    #   (`[미판정]`을 찾는 것이 아니다 — 회차 28이 이 표현을 plan-template.md에서 정정했다).
    #   ⚠ 대조 문자열은 부기 리터럴 'Deferred 미판정'이다 — 숫자만 재면 문면이 바뀌어도 통과한다.
    $scDefBase = Join-Path $work 'sc-def'

    # SC40 (양성): 미판정 2건 → 건수가 실린다. 기본형.
    $scDef1 = Join-Path $scDefBase 'unjudged'; New-Item -ItemType Directory $scDef1 -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo', '', '## Deferred / Follow-up', '- [미판정] **A**', '- [미판정] **B**', '', '## Out of Scope') | Set-Content -Encoding UTF8 (Join-Path $scDef1 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDef1 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: Deferred 미판정 건수 주입 (SC40)" -R $r -ExpectExit 0 -ExpectContains 'Deferred 미판정 2건'

    # SC40b (델타 음성): 전부 판정됨([등재]/[미등재:기호]) → 부기 미발화.
    #   이 케이스가 없으면 "항상 부기"로 바꿔도 나머지가 전부 통과한다.
    $scDef2 = Join-Path $scDefBase 'judged'; New-Item -ItemType Directory $scDef2 -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo', '', '## Deferred / Follow-up', '- [등재] **A**', '- [미등재:ⓓ] **B**', '', '## Out of Scope') | Set-Content -Encoding UTF8 (Join-Path $scDef2 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDef2 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 전부 판정된 Deferred는 부기 미발화 (SC40b)" -R $r -ExpectExit 0 -ExpectContains '미완료 1' -ExpectNotContains 'Deferred 미판정'

    # SC40m: `[다음 회차]`도 판정 완료 마커다 → 그 항목만 있으면 부기 미발화, 섞이면 나머지만 센다.
    #   회차 28이 이 마커를 신설하면서 형식 정본(plan-template.md)만 고치고 이 계수를 빠뜨려,
    #   판정을 마친 4건이 「미판정 4건」으로 집계됐다(완료 리뷰 MAJOR). 두 방향을 함께 잰다 —
    #   전건 `[다음 회차]`면 0(미발화)이고, 마커 없는 1건이 섞이면 그 1건만 센다.
    #   ⚠ 픽스처에 **백틱 있는 형태와 없는 형태를 섞는다** — MAJOR1을 낳은 실물이 백틱 형태였고
    #   (형식 정본이 마커를 표 안 코드 스팬으로 보여 준다), 무백틱만 재면 누가 skip 줄의
    #   백틱 옵셔널을 떼도 이 케이스는 통과하고 실 plan.md만 깨진다(v1.233.0이 겪은 형태).
    $scDefN = Join-Path $scDefBase 'nextround'; New-Item -ItemType Directory $scDefN -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo', '', '## Deferred / Follow-up', '- [다음 회차] **A**', '- `[다음 회차]` **B**', '', '## Out of Scope') | Set-Content -Encoding UTF8 (Join-Path $scDefN 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDefN } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: [다음 회차]는 미판정으로 세지 않는다 (SC40m)" -R $r -ExpectExit 0 -ExpectContains '미완료 1' -ExpectNotContains 'Deferred 미판정'

    # SC40m2 (양성 대조): 같은 절에 마커 없는 항목이 하나 섞이면 그 1건만 센다 —
    #   위 케이스만 있으면 「절에 [다음 회차]가 있으면 통째로 skip」으로 구현해도 green이다.
    $scDefN2 = Join-Path $scDefBase 'nextround-mixed'; New-Item -ItemType Directory $scDefN2 -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo', '', '## Deferred / Follow-up', '- `[다음 회차]` **A**', '- **B** 마커 없음', '', '## Out of Scope') | Set-Content -Encoding UTF8 (Join-Path $scDefN2 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDefN2 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: [다음 회차]와 무마커가 섞이면 무마커만 센다 (SC40m2)" -R $r -ExpectExit 0 -ExpectContains 'Deferred 미판정 1건'

    # SC40p: `[1회 실패]`도 세지 않는다 — 등재 판정 대상이 아니라 재발 판정용 기록이다.
    #   그 표식은 `REPO-CONVENTIONS.md` 「쓰기」·`implement/SKILL.md` 「실패 처리」가 이 절에 두도록 **의무로**
    #   규정했는데 마커 4종에는 없어 skip 셋에서 빠져 있었다 — 회차 68이 그 줄을 실제로 놓아
    #   「미판정 1건」이 발화했다(완료 리뷰 MAJOR · 실측 defUnjudged=1). §36과 같은 형태다.
    #   ⚠ SC40m과 같은 이유로 백틱 있는/없는 형태를 섞는다 — 무백틱만 재면 백틱 옵셔널을
    #   떼도 통과하고 실 plan.md만 깨진다.
    $scDefF = Join-Path $scDefBase 'firstfail'; New-Item -ItemType Directory $scDefF -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo', '', '## Deferred / Follow-up', '- [1회 실패] 원인 A — 이렇게 풀었다', '- `[1회 실패]` 원인 B — 이렇게 풀었다', '', '## Out of Scope') | Set-Content -Encoding UTF8 (Join-Path $scDefF 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDefF } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: [1회 실패]는 미판정으로 세지 않는다 (SC40p)" -R $r -ExpectExit 0 -ExpectContains '미완료 1' -ExpectNotContains 'Deferred 미판정'

    # SC40p2 (양성 대조): 회차 68의 실제 형상 — `[미등재:…]` 2건 + `[1회 실패]` 1건 + 무마커 1건.
    #   위 케이스만 있으면 「절에 [1회 실패]가 있으면 통째로 skip」으로 구현해도 green이다.
    $scDefF2 = Join-Path $scDefBase 'firstfail-mixed'; New-Item -ItemType Directory $scDefF2 -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo', '', '## Deferred / Follow-up', '- `[미등재:실해 미관측]` **A**', '- `[미등재:Out of Scope]` **B**', '- `[1회 실패]` 원인 C — 이렇게 풀었다', '- **D** 마커 없음', '', '## Out of Scope') | Set-Content -Encoding UTF8 (Join-Path $scDefF2 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDefF2 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: [1회 실패]와 무마커가 섞이면 무마커만 센다 (SC40p2)" -R $r -ExpectExit 0 -ExpectContains 'Deferred 미판정 1건'

    # SC40c (델타 음성): `## Deferred / Follow-up` 절 자체가 없는 plan → 부기 미발화·오류 없음.
    #   기존 픽스처 대부분이 이 형태라 무회귀의 근거이기도 하다.
    $scDef3 = Join-Path $scDefBase 'nosection'; New-Item -ItemType Directory $scDef3 -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo') | Set-Content -Encoding UTF8 (Join-Path $scDef3 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDef3 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: Deferred 절 부재면 부기 미발화 (SC40c)" -R $r -ExpectExit 0 -ExpectContains '미완료 1' -ExpectNotContains 'Deferred 미판정'

    # SC40d (양성 — 혼재 계수): 3건 중 1건만 [등재], 2건은 마커 없음 → **2건**으로 센다.
    #   이것이 "이관 도중 압축된" 실제 형태다. "plan에 마커가 하나라도 있으면 폴백을 끈다"로
    #   구현하면 이 케이스만 FAIL한다(D3이 막으려는 형태).
    $scDef4 = Join-Path $scDefBase 'mixed'; New-Item -ItemType Directory $scDef4 -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo', '', '## Deferred / Follow-up', '- [등재] **A**', '- **B**', '- **C**', '', '## Out of Scope') | Set-Content -Encoding UTF8 (Join-Path $scDef4 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDef4 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 마커 혼재 plan은 마커 없는 항목만 계수 (SC40d)" -R $r -ExpectExit 0 -ExpectContains 'Deferred 미판정 2건'

    # SC40e (폴백 고정): 마커가 전무한 구형 plan → 전 항목을 미판정으로 센다.
    #   마커 도입 전 plan이 조용히 0건으로 빠지지 않게 하는 축.
    $scDef5 = Join-Path $scDefBase 'legacy'; New-Item -ItemType Directory $scDef5 -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo', '', '## Deferred / Follow-up', '- **A**', '- **B**', '', '## Out of Scope') | Set-Content -Encoding UTF8 (Join-Path $scDef5 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDef5 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 마커 전무한 구형 plan은 전 항목 미판정 (SC40e)" -R $r -ExpectExit 0 -ExpectContains 'Deferred 미판정 2건'

    # SC40f (회귀 고정): task 전부 완료 + 미판정 있음 → `전부 완료` 라인과 건수가 **함께** 나온다.
    #   위 SC38 계열 픽스처는 Deferred 절이 없어 이 조합을 재지 못한다. 회차를 마친 plan이
    #   미이관 항목을 남긴 채 다음 세션으로 넘어가는 것이 이 회차가 막으려는 바로 그 상태다.
    $scDef6 = Join-Path $scDefBase 'done-unjudged'; New-Item -ItemType Directory $scDef6 -Force | Out-Null
    @('# Plan', '## Tasks', '- [x] T1. done', '', '## Deferred / Follow-up', '- [미판정] **A**', '', '## Out of Scope') | Set-Content -Encoding UTF8 (Join-Path $scDef6 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDef6 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 전부 완료 plan에도 미판정 건수 (SC40f)" -R $r -ExpectExit 0 -ExpectContains '전부 완료'
    Assert-Case -Name "session-context: 전부 완료 + 미판정 동시 표기 (SC40f2)" -R $r -ExpectExit 0 -ExpectContains 'Deferred 미판정 1건'

    # SC40g (델타 음성 — placeholder): 템플릿 기본값(`- <이번엔 제외…>`)만 있는 절 → 부기 미발화.
    #   **갓 만든 모든 plan의 기본 상태**라, 꺾쇠 제외를 빠뜨리면 미판정 1건이 상시 오발화한다.
    #   T2 리뷰 1R이 실제로 이 결함을 재현으로 잡았다(마커 그룹이 필수라 치환 불발).
    $scDef7 = Join-Path $scDefBase 'placeholder'; New-Item -ItemType Directory $scDef7 -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo', '', '## Deferred / Follow-up', '- <이번엔 제외, 향후 별도 plan으로 진행할 작업>', '', '## Out of Scope') | Set-Content -Encoding UTF8 (Join-Path $scDef7 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDef7 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 템플릿 placeholder는 미판정으로 세지 않는다 (SC40g)" -R $r -ExpectExit 0 -ExpectContains '미완료 1' -ExpectNotContains 'Deferred 미판정'

    # SC40h (양성 — 기호 없는 미등재): `- [미등재] …`(게이트 기호 없음)는 **미판정으로 센다**.
    #   사유 없는 미등재는 게이트 ⓕ가 막으려는 「근거 미지목」과 같은 형태다. 이 케이스가 없으면
    #   구현자가 `[미등재]` 접두만 보고 제외해도 전건 green이다.
    #   ⚠ 둘째 항목이 **같은 줄 뒤쪽에 대괄호를 담는다** — 기호 정규식을 `.+`로 쓰면 `.`이 `]`도 먹어
    #     그 항목이 판정된 것으로 빠진다(F-7 2R m3). `[^\]]+`여야 이 픽스처가 2건으로 세어진다.
    $scDef8 = Join-Path $scDefBase 'no-gate'; New-Item -ItemType Directory $scDef8 -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo', '', '## Deferred / Follow-up', '- [미등재] **A**', '- [미등재:] **B** 참고 [ref]', '', '## Out of Scope') | Set-Content -Encoding UTF8 (Join-Path $scDef8 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDef8 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 기호 없는 미등재는 미판정으로 계수 (SC40h)" -R $r -ExpectExit 0 -ExpectContains 'Deferred 미판정 2건'

    # SC40k (델타 음성 — 백틱 코드 스팬 마커): 형식 정본(deferred-rules.md)이 마커를 표 안에서
    #   코드 스팬으로 보여 주므로 그대로 따라 적으면 `` `[등재]` `` 가 된다. 그 형태를 안 받으면
    #   **판정을 마친 항목이 통째로 미판정으로 집계된다** — v1.233.0 회차가 실제로 그렇게 됐고
    #   세션 시작에 '미판정 5건'이 떴다(전건 판정 완료 상태였다).
    $scDef10 = Join-Path $scDefBase 'backtick-marker'; New-Item -ItemType Directory $scDef10 -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo', '', '## Deferred / Follow-up', ('- ' + [char]96 + '[등재]' + [char]96 + ' **A**'), ('- ' + [char]96 + '[미등재:ⓓ]' + [char]96 + ' **B**'), '', '## Out of Scope') | Set-Content -Encoding UTF8 (Join-Path $scDef10 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDef10 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 백틱 코드 스팬 마커도 판정으로 인정 (SC40k)" -R $r -ExpectExit 0 -ExpectContains '미완료 1' -ExpectNotContains 'Deferred 미판정'

    # SC40l (양성 — 백틱을 넓혀도 미판정은 여전히 센다): 위 완화가 계수 자체를 무력화하지 않음을 잰다.
    #   음성만 늘리면 「받아 주다가 다 통과시킨」 상태와 구분되지 않는다.
    $scDef11 = Join-Path $scDefBase 'backtick-mixed'; New-Item -ItemType Directory $scDef11 -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo', '', '## Deferred / Follow-up', ('- ' + [char]96 + '[등재]' + [char]96 + ' **A**'), '- **B**', '', '## Out of Scope') | Set-Content -Encoding UTF8 (Join-Path $scDef11 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDef11 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 백틱 마커 혼재여도 마커 없는 항목은 계수 (SC40l)" -R $r -ExpectExit 0 -ExpectContains 'Deferred 미판정 1건'

    # SC40n (양성 — 볼드가 마커를 감싼 서식): `- **`[등재]` A**` 는 **미판정으로 센다**.
    #   회차 49 가 이 형태로 써서 판정을 마친 9건이 「미판정 9건」으로 출력됐고, 회차 50 은
    #   정규식을 넓히는 대신 **서식을 고정**해 닫았다(`plan/references/deferred-rules.md`).
    #   ⚠ 이 케이스가 이번 처방의 방향을 고정한다 — 없으면 다음 세션이 skip 정규식에 볼드
    #     접두를 받아들여도 전건 green 이라, 서식 정본과 hook 계수가 조용히 갈린다.
    #     (검사기 쪽 짝은 evals 골든 `harness-ledger-format-bold` 가 red 로 잡는다.)
    $scDef12 = Join-Path $scDefBase 'bold-wrapped-marker'; New-Item -ItemType Directory $scDef12 -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo', '', '## Deferred / Follow-up', ('- **' + [char]96 + '[등재]' + [char]96 + ' A**'), '', '## Out of Scope') | Set-Content -Encoding UTF8 (Join-Path $scDef12 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDef12 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 볼드가 감싼 마커는 판정으로 인정하지 않는다 (SC40n)" -R $r -ExpectExit 0 -ExpectContains 'Deferred 미판정 1건'

    # SC40i (양성 — 절이 파일 마지막): `## Deferred / Follow-up` 뒤에 다른 절이 없어 종료 앵커가
    #   없는 plan → 건수 정상 산출. 구간 추출이 종료 앵커를 못 찾아 **조용히 0건**이 되는 형태는
    #   이 회차가 막으려는 실패(미판정이 있는데 부기가 안 나감)와 같다.
    $scDef9 = Join-Path $scDefBase 'last-section'; New-Item -ItemType Directory $scDef9 -Force | Out-Null
    @('# Plan', '## Tasks', '- [ ] T1. todo', '', '## Deferred / Follow-up', '- [미판정] **A**') | Set-Content -Encoding UTF8 (Join-Path $scDef9 'plan.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scDef9 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: Deferred 절이 파일 마지막이어도 계수 (SC40i)" -R $r -ExpectExit 0 -ExpectContains 'Deferred 미판정 1건'

    # SC40j (문면 고정 — E안): compact 리마인더에 「아직 plan.md에 적지 않은 발견을 지금 적으라」
    #   1구가 실린다. **대조 문자열은 기존 리마인더에 없는 신규 어휘**여야 한다 — 기존 '요약 직후'로
    #   재면 이 1구가 지워져도 통과한다. 같은 공백을 F-7이 두 번 지적해 사후 추가한 선례가 있다.
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scDef1 } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: compact 리마인더에 미기록 발견 지시 (SC40j)" -R $r -ExpectExit 0 -ExpectContains '아직 plan.md에 적지 않은'

    Remove-Item -Recurse -Force $scDefBase -ErrorAction SilentlyContinue

    # SC22 (델타): AGENTS.md만 있고 plan 없는 cwd → vault 라인이 주입되고 AGENTS 라인보다 **앞**에 온다.
    #   ① 게이팅을 AGENTS 진입 전 시점에 판정하면 이 케이스가 억제된다(과억제 검출).
    #   ② 순서 단정은 Assert-Case로 불가하다 — ExpectContains가 [regex]::Escape를 거쳐 전후 관계를 비교할 수단이 없으므로
    #      IndexOf 비교 후 결과를 직접 push한다(§11 (b) 패턴과 동일).
    #   마커는 헤딩에 둔다 — hook 이 목차만 실으므로 본문 줄 마커는 출력에 나오지 않는다.
    $scVOnly = Join-Path $work 'sc-agents-only'; New-Item -ItemType Directory $scVOnly -Force | Out-Null
    @('# SC_VAULT_ORDER_MARKER Guide', '본문') | Set-Content -Encoding UTF8 (Join-Path $scVOnly 'AGENTS.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scVOnly } | ConvertTo-Json -Compress)
    $iVault  = $r.out.IndexOf('위키 vault: 설정됨')
    $iAgents = $r.out.IndexOf('SC_VAULT_ORDER_MARKER')
    if (($r.code -eq 0) -and ($iVault -ge 0) -and ($iAgents -gt $iVault)) {
        $script:results.Add(@{ ok = $true; line = "[PASS] session-context: AGENTS 단독 cwd vault 주입 + AGENTS보다 앞 (SC22)" })
    } else {
        $script:results.Add(@{ ok = $false; line = "[FAIL] session-context: SC22 주입·순서 위반 (exit=$($r.code), vault=$iVault, agents=$iAgents)" })
    }

    # SC22b/SC22c: 위 SC22와 **같은 조건을 source=fork로** 한 번 더 — fork 경로에서 vault 라인과
    #   AGENTS.md 목차가 함께 주입되는지 고정한다. 앞의 SC2b는 plan 축만 보는데, fork matcher를 넣은
    #   목적은 그 세션에 plan·vault·AGENTS 셋이 다 들어가게 하는 것이라 나머지 두 축도 골든에 박아 둔다
    #   ($source는 이 두 블록을 게이팅하지 않으므로 startup과 결과가 같아야 한다 — 그 사실 자체가 검증 대상).
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'fork'; cwd = $scVOnly } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: fork도 vault 라인 주입 (SC22b)" -R $r -ExpectExit 0 -ExpectContains '위키 vault: 설정됨'
    Assert-Case -Name "session-context: fork도 AGENTS 목차 주입 (SC22c)" -R $r -ExpectExit 0 -ExpectContains 'SC_VAULT_ORDER_MARKER'

    # SC19: 설정됐으나 폴더 부재(이동·삭제) → 부재 문구 주입 (경로 재확인 신호)
    $isoV2 = Join-Path $EvalRunTemp ("karina-hook-evals-vault-gone-" + $suffix)
    New-Item -ItemType Directory -Path (Join-Path $isoV2 '.claude') -Force | Out-Null
    (@{ vault_path = ((Join-Path $isoV2 'moved-away') -replace '\\', '/') } | ConvertTo-Json) | Set-Content -Encoding UTF8 (Join-Path $isoV2 '.claude/llm-wiki-config.json')
    $env:USERPROFILE = $isoV2
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scProj } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: vault 설정 경로 부재 주입 (SC19)" -R $r -ExpectExit 0 -ExpectContains '설정 경로 부재'
    Assert-Case -Name "session-context: 부재 라인이 기록을 요구하지 않는다 (SC19d)" -R $r -ExpectExit 0 -ExpectNotContains '1줄 기록'
    Assert-Case -Name "session-context: 부재 라인이 위키 연동 정본을 지목 (SC19b)" -R $r -ExpectExit 0 -ExpectContains 'skills/WIKI.md'
    Assert-Case -Name "session-context: 부재 라인 위키 연동 정본이 절대 경로 (SC19c)" -R $r -ExpectExit 0 -ExpectContains "$scSkillsAbs/WIKI.md"

    # SC20 (무회귀): config 없는 홈 → vault 라인 미주입. 미설정은 무출력이 설계다(노이즈 방지).
    $env:USERPROFILE = $iso
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scProj } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 미설정 홈은 vault 라인 미주입 (SC20)" -R $r -ExpectExit 0 -ExpectContains '미완료 2' -ExpectNotContains '위키 vault'



    $scStaleCwd = Join-Path $work ("sc-wiki-nostale-" + $suffix)
    New-Item -ItemType Directory $scStaleCwd -Force | Out-Null
    @('# Guide', 'SC_NOSTALE_MARKER') | Set-Content -Encoding UTF8 (Join-Path $scStaleCwd 'AGENTS.md')
    $scStaleHubDir = Join-Path $isoVault '20_projects/personal'
    New-Item -ItemType Directory $scStaleHubDir -Force | Out-Null
    $scStaleHub = Join-Path $scStaleHubDir 'scnostale.md'
    @('---', 'type: project', 'project: SCNoStale', ('updated: ' + (Get-Date).AddDays(-30).ToString('yyyy-MM-dd')),
      'synced_commit: 0000000000000000000000000000000000000000', '---', '', '# SCNoStale', '', '## 레포 정보',
      ('- **경로**: `' + ($scStaleCwd -replace '\\', '/') + '`')) | Set-Content -Encoding UTF8 $scStaleHub
    $env:USERPROFILE = $isoV
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scStaleCwd } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 오래된 허브도 뒤처짐 줄 미주입 (SC32)" -R $r -ExpectExit 0 -ExpectContains '위키 vault: 설정됨' -ExpectNotContains '위키 뒤처짐'
    Remove-Item -Force $scStaleHub -ErrorAction SilentlyContinue
    Remove-Item -Recurse -Force $scStaleCwd -ErrorAction SilentlyContinue

    # SC44~SC44n: Deferred 대장(docs/plans/deferred.md) 최고령 「마지막 판정일」 주입 (v1.221.0 T1).
    #   ⚠ **기대는 날짜부로 잰다** — 일수는 매일 늘어 픽스처 골든이 다음 날 깨진다.
    #   ⚠ 각 축은 **단독으로 무엇을 검출하는지**가 달라야 한다 — 한 픽스처가 두 규칙을 함께 태우면
    #     둘 중 하나만 살아도 통과해 어느 회귀도 못 잡는다(ⓒ 형식 한정 / ⓓ 미래 배제를 가른 이유).
    $scLed = Join-Path $work ("sc-ledger-" + $suffix)
    New-Item -ItemType Directory -Path (Join-Path $scLed '.claude-plugin') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $scLed 'docs/plans') -Force | Out-Null
    '{ "name": "karina" }' | Set-Content -Encoding UTF8 (Join-Path $scLed '.claude-plugin/plugin.json')
    '# 규약' | Set-Content -Encoding UTF8 (Join-Path $scLed 'docs/harness-conventions.md')
    $scLedFile = Join-Path $scLed 'docs/plans/deferred.md'
    $scLedInvoke = { Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scLed } | ConvertTo-Json -Compress) }

    # SC44 (양성): 대기 3건 → 라인이 나오고 건수가 실린다.
    @('# Deferred 대장', '', '## 대기', '', '- [2026-05-01] **A**', '- [2026-06-01] **B**', '- [2026-07-01] **C**') |
        Set-Content -Encoding UTF8 $scLedFile
    $r = & $scLedInvoke
    Assert-Case -Name "session-context: Deferred 대장 최고령 주입 (SC44)" -R $r -ExpectExit 0 -ExpectContains 'Deferred 대장: 대기 3건'

    # SC44mono [모노레포 이전]: 하니스가 git 루트 아래 플러그인 폴더에 있어도 그 폴더의 대장을 읽는다.
    $scLedMono = Join-Path $work ("sc-ledger-mono-" + $suffix)
    $scLedMonoH = Join-Path $scLedMono 'plugins/claude-harness-karina'
    New-Item -ItemType Directory -Path (Join-Path $scLedMonoH '.claude-plugin') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $scLedMonoH 'docs/plans') -Force | Out-Null
    '{ "name": "karina" }' | Set-Content -Encoding UTF8 (Join-Path $scLedMonoH '.claude-plugin/plugin.json')
    '# 규약' | Set-Content -Encoding UTF8 (Join-Path $scLedMonoH 'docs/harness-conventions.md')
    @('# Deferred 대장', '', '## 대기', '', '- [2026-05-01] **A**', '- [2026-06-01] **B**') |
        Set-Content -Encoding UTF8 (Join-Path $scLedMonoH 'docs/plans/deferred.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scLedMonoH } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 모노레포 하니스 폴더의 Deferred 대장 주입 (SC44mono)" -R $r -ExpectExit 0 -ExpectContains 'Deferred 대장: 대기 2건'
    Remove-Item -Recurse -Force $scLedMono -ErrorAction SilentlyContinue

    # SC44b (값 정확성 — 항목별 **최신** 스탬프): 등록일보다 재확인 표기가 최신이면 그쪽을 취한다.
    #   첫 스탬프를 취하는 회귀(v1.219.0 오산의 형태)면 (2026-01-01)이 나와 FAIL한다.
    #   **항목이 1건인 픽스처다** — 스칼라 반환 함정(@() 래핑 누락)을 실제로 태운다.
    @('# Deferred 대장', '', '## 대기', '', '- [2026-01-01] **A** (2026-06-01 재확인: 유지 — 근거)') |
        Set-Content -Encoding UTF8 $scLedFile
    $r = & $scLedInvoke
    Assert-Case -Name "session-context: 항목별 최신 스탬프를 판정일로 (SC44b)" -R $r -ExpectExit 0 -ExpectContains '(2026-06-01)'

    # SC44c (형식 한정 — 단독 검출): 괄호 **밖** 과거 날짜는 판정일이 아니다.
    #   형식 한정이 풀리면 A의 판정일이 2026-07-01로 밀려 최고령이 (2026-06-01)이 되어 FAIL.
    #   ⚠ 미래 날짜를 쓰지 않는다 — 그러면 미래 배제(SC44d)만으로도 통과해 이 축이 죽는다.
    @('# Deferred 대장', '', '## 대기', '', '- [2026-05-01] **A** — 본문에 2026-07-01 을 인용한다', '- [2026-06-01] **B**') |
        Set-Content -Encoding UTF8 $scLedFile
    $r = & $scLedInvoke
    Assert-Case -Name "session-context: 괄호 밖 인용 날짜는 판정일 아님 (SC44c)" -R $r -ExpectExit 0 -ExpectContains '(2026-05-01)'

    # SC44d (미래 배제 — 단독 검출): 괄호 **안** 미래 날짜는 후보에서 뺀다.
    #   형식 한정은 이 날짜를 통과시키므로, 미래 배제가 없으면 A가 2099로 밀려 (2026-06-01) FAIL.
    @('# Deferred 대장', '', '## 대기', '', '- [2026-05-01] **A** (2099-01-01 예정)', '- [2026-06-01] **B**') |
        Set-Content -Encoding UTF8 $scLedFile
    $r = & $scLedInvoke
    Assert-Case -Name "session-context: 괄호 안 미래 날짜는 후보 제외 (SC44d)" -R $r -ExpectExit 0 -ExpectContains '(2026-05-01)'

    # SC44e (최솟값 선택): 판정일이 서로 다른 3항목에서 **가장 오래된** 것을 고른다.
    #   max/min을 뒤집거나 첫 항목만 보는 회귀를 잡는다.
    @('# Deferred 대장', '', '## 대기', '', '- [2026-07-01] **A**', '- [2026-03-01] **B**', '- [2026-05-01] **C**') |
        Set-Content -Encoding UTF8 $scLedFile
    $r = & $scLedInvoke
    Assert-Case -Name "session-context: 항목별 최댓값들의 최솟값 (SC44e)" -R $r -ExpectExit 0 -ExpectContains '(2026-03-01)'

    # SC44f (항목 단위 묶기): 최신 스탬프가 **하위 불릿에만** 있는 항목.
    #   줄 단위로 되돌아가면 A의 판정일이 2026-05-01로 과소평가돼 (2026-05-01) FAIL.
    @('# Deferred 대장', '', '## 대기', '', '- [2026-05-01] **A**', '  - **(2026-08-01 재확인: 유지)** 하위 불릿', '- [2026-06-01] **B**') |
        Set-Content -Encoding UTF8 $scLedFile
    $r = & $scLedInvoke
    Assert-Case -Name "session-context: 하위 불릿도 같은 항목으로 묶는다 (SC44f)" -R $r -ExpectExit 0 -ExpectContains '(2026-06-01)'

    # SC44g (vN 부기 양성 — 접두 형식): 정본 ⓪이 예시하는 `[등록일, **vN…**]`.
    @('# Deferred 대장', '', '## 대기', '', '- [2026-05-01, **v1.147.0에서 부분 해소**] **A**', '- [2026-06-01] **B**') |
        Set-Content -Encoding UTF8 $scLedFile
    $r = & $scLedInvoke
    Assert-Case -Name "session-context: vN 부기(접두 형식) 표시 (SC44g)" -R $r -ExpectExit 0 -ExpectContains 'vN 부기 1건'

    # SC44g2 (vN 부기 양성 — 제목 뒤 형식): v1.185.0 T2가 세운 현행 관례. **실물은 전부 이 형태다.**
    #   접두 형식만 보는 구현이면 0건이 되어 이 케이스가 FAIL한다.
    @('# Deferred 대장', '', '## 대기', '', '- [2026-05-01] **A** (v1.147.0에서 부분 해소) — 본문', '- [2026-06-01] **B**') |
        Set-Content -Encoding UTF8 $scLedFile
    $r = & $scLedInvoke
    Assert-Case -Name "session-context: vN 부기(제목 뒤 형식) 표시 (SC44g2)" -R $r -ExpectExit 0 -ExpectContains 'vN 부기 1건'

    # SC44h (vN 부기 델타 음성): 그 형식이 없으면 부기가 붙지 않는다.
    #   이 케이스가 없으면 「항상 부기」로 바꿔도 나머지가 전부 통과한다.
    @('# Deferred 대장', '', '## 대기', '', '- [2026-05-01] **A**', '- [2026-06-01] **B**') |
        Set-Content -Encoding UTF8 $scLedFile
    $r = & $scLedInvoke
    Assert-Case -Name "session-context: vN 부기 없으면 미표시 (SC44h)" -R $r -ExpectExit 0 -ExpectNotContains 'vN 부기'

    # SC44i (델타 음성 — 비하네스 cwd): plugin.json 없이 대장만 있으면 미주입.
    #   게이팅이 풀리면 대장을 가진 모든 프로젝트에 이 라인이 뜬다.
    $scLedNoHarn = Join-Path $work ("sc-ledger-noharn-" + $suffix)
    New-Item -ItemType Directory -Path (Join-Path $scLedNoHarn 'docs/plans') -Force | Out-Null
    'x' | Set-Content -Encoding UTF8 (Join-Path $scLedNoHarn 'AGENTS.md')
    @('# Deferred 대장', '', '## 대기', '', '- [2026-05-01] **A**') |
        Set-Content -Encoding UTF8 (Join-Path $scLedNoHarn 'docs/plans/deferred.md')
    $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scLedNoHarn } | ConvertTo-Json -Compress)
    Assert-Case -Name "session-context: 비하네스 cwd는 대장 라인 미주입 (SC44i)" -R $r -ExpectExit 0 -ExpectNotContains 'Deferred 대장'

    # SC44j (델타 음성 — 대장 부재): 하네스 cwd인데 대장이 없으면 라인만 미주입(fail-open).
    Remove-Item -Force $scLedFile -ErrorAction SilentlyContinue
    $r = & $scLedInvoke
    Assert-Case -Name "session-context: 대장 부재 시 미주입 (SC44j)" -R $r -ExpectExit 0 -ExpectNotContains 'Deferred 대장'

    # SC44k (짝 계약): 이 라인은 vault 게이팅 신호가 아니다 — plan·AGENTS.md가 **둘 다 없는**
    #   픽스처에서 대장 라인만 나와도 vault 라인이 새면 안 된다($cwdBaseCount++ 누락 검출).
    @('# Deferred 대장', '', '## 대기', '', '- [2026-05-01] **A**') | Set-Content -Encoding UTF8 $scLedFile
    $env:USERPROFILE = $isoV
    $r = & $scLedInvoke
    Assert-Case -Name "session-context: 대장 라인은 vault 게이팅 신호 아님 (SC44k)" -R $r -ExpectExit 0 -ExpectContains 'Deferred 대장' -ExpectNotContains '위키 vault: 설정'

    # SC44l (방어 경로 — 무효 날짜): 형식은 맞지만 의미가 무효인 문자열이 섞여도 **그 날짜만**
    #   건너뛰고 항목은 살아남는다. 항목째로 버리면 그 항목이 최고령 후보에서 통째로 빠진다.
    @('# Deferred 대장', '', '## 대기', '', '- [2026-05-01] **A** (2026-13-45 무효)', '- [2026-06-01] **B**') |
        Set-Content -Encoding UTF8 $scLedFile
    $r = & $scLedInvoke
    Assert-Case -Name "session-context: 무효 날짜는 그것만 건너뛴다 (SC44l)" -R $r -ExpectExit 0 -ExpectContains '(2026-05-01)'

    # SC44m (방어 경로 — 전건 무효): 쓸 수 있는 날짜가 하나도 없으면 라인을 내지 않는다.
    #   억제 분기가 없으면 빈 배열에 [0] 인덱싱이 걸려 라인이 깨진 값으로 나가거나 catch로 사라진다.
    @('# Deferred 대장', '', '## 대기', '', '- [2099-01-01] **A** 미래만 있는 항목') |
        Set-Content -Encoding UTF8 $scLedFile
    $r = & $scLedInvoke
    Assert-Case -Name "session-context: 유효 판정일 0건이면 미주입 (SC44m)" -R $r -ExpectExit 0 -ExpectNotContains 'Deferred 대장'

    # SC44n (구조 줄 흡수 방지 — F-7 M1): `## 대기`에는 항목 뒤에 **앵커 줄**(`**▶ …`)과
    #   **인용 블록**(`> …`)이 온다. 그것을 직전 항목의 본문으로 흡수하면 거기 적힌 날짜가
    #   그 항목의 판정일로 밀려 올라가 최고령이 실제보다 최신이 된다(batch가 늦게 열린다).
    #   필터가 없으면 A의 판정일이 2026-08-05로 밀려 최고령이 (2026-07-01)이 되어 FAIL.
    @('# Deferred 대장', '', '## 대기', '', '- [2026-06-01] **A**', '**▶ 현행 잔량**: 대기 2 (2026-08-05 실측 2건)', '> 카운트 기준 인용 (2026-08-05 실측)', '- [2026-07-01] **B**') |
        Set-Content -Encoding UTF8 $scLedFile
    $r = & $scLedInvoke
    Assert-Case -Name "session-context: 앵커·인용 블록은 항목 본문이 아니다 (SC44n)" -R $r -ExpectExit 0 -ExpectContains '(2026-06-01)'

    Remove-Item -Recurse -Force $scLed, $scLedNoHarn -ErrorAction SilentlyContinue

    # ---- SC45: AGENTS.md 이관처 목차 주입 (회차 57 T3)
    #   AGENTS.md 는 Claude Code 나 전문 주입으로 컨텍스트에 들지만 그 분할본은 어느 로드 경로에도 없었다 —
    #   포인터는 그것이 있는 줄 알아야 따라간다. 네 케이스가 양성 2 · 델타 음성 2 다.
    $scToc = Join-Path $work 'sc-toc'
    New-Item -ItemType Directory (Join-Path $scToc 'docs') -Force | Out-Null
    @('# Guide', '', '## Build & Test') | Set-Content -Encoding UTF8 (Join-Path $scToc 'AGENTS.md')
    $scTocConv = Join-Path $scToc 'docs/harness-conventions.md'
    $scTocInvoke = { Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scToc } | ConvertTo-Json -Compress) }

    # SC45a (양성): 이관처가 있으면 그 절 제목이 **순번과 함께** 주입된다 (순번은 회차 69 T3).
    @('# 상세', '', '## 첫째 절', '', '본문', '', '## 둘째 절') | Set-Content -Encoding UTF8 $scTocConv
    $r = & $scTocInvoke
    Assert-Case -Name "session-context: 이관처 목차 주입 (SC45a)" -R $r -ExpectExit 0 -ExpectContains '1 첫째 절 · 2 둘째 절'

    # SC45e (양성): 순번과 짝인 추출 명령이 같은 줄에 실린다 (회차 69 T3).
    #   SC45a 와 축을 나눈다 — 순번만 재면 명령이 빠져도 green 이고, 그러면 세션이 순번을
    #   받고도 쓸 곳이 없어 전문 Read 로 돌아간다. 둘이 짝이라야 목록이 라우터가 된다.
    Assert-Case -Name "session-context: 절 추출 명령 동반 (SC45e)" -R $r -ExpectExit 0 -ExpectContains 'awk -v n='

    # SC45b (양성): 코드펜스 안의 `## ` 는 절이 아니다 — AGENTS.md 목차 폴백과 같은 축.
    @('# 상세', '', '## 진짜 절', '', '``````', '## 펜스 안 가짜', '``````') | Set-Content -Encoding UTF8 $scTocConv
    $r = & $scTocInvoke
    Assert-Case -Name "session-context: 목차는 코드펜스 안을 세지 않는다 (SC45b)" -R $r -ExpectExit 0 -ExpectNotContains '펜스 안 가짜'

    # SC45f (양성 — 회차 71): 순번을 **내는 쪽**과 **쓰는 쪽**이 같은 경계를 쓴다.
    #   SC45b 는 이 축의 절반만 잰다 — 목차(`$convHeads`)는 펜스를 거르는데 같은 줄이
    #   안내하는 추출 명령이 펜스를 세면, 세션이 받은 순번 n 과 그 명령이 뽑는 절이
    #   어긋난다. 절반만 재는 축은 나머지 절반이 깨져도 green 이다.
    #   ⚠ 앵커는 「펜스 토글 형태가 있다」가 아니라 **정본(`skills/WIKI.md`)과 바이트
    #   동일한 구간**이다 — 느슨하게 잡으면 사본이 *여전히 토글하면서* 정본과 다른
    #   정규식으로 갈릴 때 그 드리프트를 못 잡는다. 그 드리프트가 곧 우회 경로다.
    Assert-Case -Name "session-context: 추출 명령도 코드펜스를 센다 (SC45f)" -R $r -ExpectExit 0 -ExpectContains "/^(``````|~~~)/{f=!f} !f&&/^## /{c++} c==n"

    # SC45g (양성 — 회차 71): 목차가 상한을 넘어 잘리는 폴백에서도 같은 경계를 안내한다.
    #   `$convTocMaxBytes`(3,000) 초과 분기는 **회차 71 전까지 어느 케이스도 태우지
    #   않았다** — 그 분기의 안내 명령이 옛 `grep -n '^## '` 로 남아도 아무것도 안 걸렸다.
    #   절 제목을 길게 반복해 상한을 넘긴다(제목당 약 60B × 80 절 ≫ 3,000B).
    $scTocLines = @('# 상세', '')
    1..80 | ForEach-Object { $scTocLines += "## 아주 길게 늘여 쓴 절 제목으로 목차 상한을 넘긴다 $_"; $scTocLines += '' }
    $scTocLines | Set-Content -Encoding UTF8 $scTocConv
    $r = & $scTocInvoke
    Assert-Case -Name "session-context: 목차 절단 폴백도 펜스를 센다 (SC45g)" -R $r -ExpectExit 0 -ExpectContains "/^(``````|~~~)/{f=!f} !f&&/^## /{c++; print c"
    # 델타 음성 — 실제로 절단 분기를 탔는지 확인한다. 이것이 없으면 상한을 못 넘겨
    #   폴백이 안 돌았는데 위 케이스가 주 안내 문구로 통과할 수 있다.
    Assert-Case -Name "session-context: 목차 절단 분기 진입 확인 (SC45g2)" -R $r -ExpectExit 0 -ExpectContains '이하 생략'

    # SC45c (델타 음성): 이관처가 없으면 조용히 생략한다 — 이 hook 은 다른 레포에서도 돈다.
    Remove-Item -Force $scTocConv -ErrorAction SilentlyContinue
    $r = & $scTocInvoke
    Assert-Case -Name "session-context: 이관처 부재 시 침묵 (SC45c)" -R $r -ExpectExit 0 -ExpectNotContains '이관처'

    # SC45d (델타 음성): `## ` 헤딩이 하나도 없으면 빈 목차를 내지 않는다.
    @('# 상세', '', '헤딩 없는 산문뿐이다.') | Set-Content -Encoding UTF8 $scTocConv
    $r = & $scTocInvoke
    Assert-Case -Name "session-context: 절이 0건이면 미주입 (SC45d)" -R $r -ExpectExit 0 -ExpectNotContains '이관처'

    Remove-Item -Recurse -Force $scToc -ErrorAction SilentlyContinue

    Remove-Item -Recurse -Force $isoV, $isoV2 -ErrorAction SilentlyContinue

    # ---- [회차 3 T5] 세션 시작 1회 30일 마커 정리 ----
    # 호출마다 돌던 정리(post-write-checks · suggest-agents-record · loop-continue)를 세션 시작으로
    #   옮겼다. 폴더마다 「31일 마커는 지워지고 3일 마커는 남는다」를 따로 잰다 — 한 케이스에 묶으면
    #   어느 폴더가 빠졌는지 갈리지 않는다. 격리 홈($iso)의 .claude/.state 아래에 직접 심는다.
    #   ⚠ 이 자리에서는 앞 케이스들이 USERPROFILE 을 vault 홈($isoV)으로 바꿔 둔 채다 — hook 이
    #   $iso 를 보도록 이 블록 동안만 되돌린다(:164 과 같은 형태).
    $scMkProj = Join-Path $work 'sc-marker-proj'
    New-Item -ItemType Directory $scMkProj -Force | Out-Null
    $scMkDirs = @('post-write-warn', 'suggest-agents-record', 'loop-continue', 'trivial-tally', 'work-start', 'reply-language')
    foreach ($d in $scMkDirs) {
        $md = Join-Path $iso ('.claude/.state/' + $d)
        New-Item -ItemType Directory $md -Force | Out-Null
        Set-Content -LiteralPath (Join-Path $md 'sc-ttl-old') -Value ''
        (Get-Item (Join-Path $md 'sc-ttl-old')).LastWriteTime = (Get-Date).AddDays(-31)
        Set-Content -LiteralPath (Join-Path $md 'sc-ttl-new') -Value ''
        (Get-Item (Join-Path $md 'sc-ttl-new')).LastWriteTime = (Get-Date).AddDays(-3)
    }
    $scMkSaved = $env:USERPROFILE
    try {
        $env:USERPROFILE = $iso
        $null = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scMkProj } | ConvertTo-Json -Compress)
    } finally { $env:USERPROFILE = $scMkSaved }
    foreach ($d in $scMkDirs) {
        $md = Join-Path $iso ('.claude/.state/' + $d)
        $oldGone = -not (Test-Path -LiteralPath (Join-Path $md 'sc-ttl-old'))
        $newKept = Test-Path -LiteralPath (Join-Path $md 'sc-ttl-new')
        Assert-Case -Name "session-context: 세션 시작 30일 마커 정리 — $d (회차 3 T5)" -R @{ code = ([int](-not ($oldGone -and $newKept))); out = "31일 소실=$oldGone / 3일 잔존=$newKept" } -ExpectExit 0
        Remove-Item -Force (Join-Path $md 'sc-ttl-new') -ErrorAction SilentlyContinue
    }
    Remove-Item -Recurse -Force $scMkProj -ErrorAction SilentlyContinue

    # ---- 세션 시작 karina-plugin 임시 폴더 기한 정리 ----
    # 실제 사용자 임시 폴더를 건드리지 않게 TEMP·TMP 를 함께 $work 아래로 돌린다 — Windows GetTempPath 는 TMP 를,
    #   Python 은 TEMP 를 먼저 읽어 하나만 바꾸면 hook 이 실제 임시 폴더를 본다. 항목마다 따로 단언해 어느 폴더가 빠졌는지 갈리게 한다.
    $scTsProj = Join-Path $work 'sc-tempsweep-proj'
    New-Item -ItemType Directory $scTsProj -Force | Out-Null
    @('# Plan: test', '## Tasks', '- [ ] **T1-1** todo') | Set-Content -Encoding UTF8 (Join-Path $scTsProj 'plan.md')
    $scTsTmp = Join-Path $work 'sc-tempsweep-tmp'
    $scTsRoot = Join-Path $scTsTmp 'karina-plugin'
    function New-ScTsItem {
        param([string]$Rel, [int]$DaysAgo, [switch]$Dir)
        $p = Join-Path $scTsRoot $Rel
        if ($Rel -eq '..\stray.txt') { $p = Join-Path $scTsTmp 'stray.txt' }
        New-Item -ItemType Directory (Split-Path -Parent $p) -Force | Out-Null
        if ($Dir) { New-Item -ItemType Directory $p -Force | Out-Null; Set-Content -LiteralPath (Join-Path $p 'a.txt') -Value '' }
        else { Set-Content -LiteralPath $p -Value '' }
        (Get-Item -LiteralPath $p).LastWriteTime = (Get-Date).AddDays(-$DaysAgo)
        return $p
    }
    $scTsCases = @(
        @{ Rel = 'plan-variants\20260901-1000'; Days = 15; Dir = $true; Gone = $true }
        @{ Rel = 'plan-variants\20261020-1000'; Days = 3; Dir = $true; Gone = $false }
        @{ Rel = 'verify\notes\run-old'; Days = 15; Dir = $true; Gone = $true }
        @{ Rel = 'verify\notes\run-new'; Days = 3; Dir = $true; Gone = $false }
        @{ Rel = 'scratch\old.ps1'; Days = 8; Dir = $false; Gone = $true }
        @{ Rel = 'scratch\new.ps1'; Days = 1; Dir = $false; Gone = $false }
        @{ Rel = 'chain\karina-chain-run_old-decisions.md'; Days = 31; Dir = $false; Gone = $true }
        @{ Rel = 'chain\karina-chain-run_new-decisions.md'; Days = 3; Dir = $false; Gone = $false }
        @{ Rel = 'chain\karina-chain-wait-x.lock'; Days = 31; Dir = $false; Gone = $false }
        @{ Rel = 'chain\karina-chain-verify-x.log'; Days = 31; Dir = $false; Gone = $false }
        @{ Rel = 'backup\plan-old.md'; Days = 60; Dir = $false; Gone = $false }
        @{ Rel = 'worktree-backup\repo\wt-old'; Days = 60; Dir = $true; Gone = $false }
        @{ Rel = '..\stray.txt'; Days = 60; Dir = $false; Gone = $false }
    )
    foreach ($c in $scTsCases) { $c.Path = New-ScTsItem -Rel $c.Rel -DaysAgo $c.Days -Dir:$c.Dir }
    # 하위 폴더를 만든 뒤 앱 폴더의 시각이 갱신되므로 verify\notes 자체는 오래된 것으로 되돌려도 깊이 2 만 재는지 본다.
    (Get-Item -LiteralPath (Join-Path $scTsRoot 'verify\notes')).LastWriteTime = (Get-Date).AddDays(-60)
    $scTsSaved = @{ TEMP = $env:TEMP; TMP = $env:TMP; TMPDIR = $env:TMPDIR; P = $env:USERPROFILE; B = $env:KARINA_TEMP_SWEEP_BUDGET_MS }
    try {
        $env:TEMP = $scTsTmp; $env:TMP = $scTsTmp; $env:TMPDIR = $null; $env:USERPROFILE = $iso; $env:KARINA_TEMP_SWEEP_BUDGET_MS = $null
        $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scTsProj } | ConvertTo-Json -Compress)
        Assert-Case -Name "session-context: 임시 폴더 정리가 있어도 컨텍스트 출력은 그대로" -R $r -ExpectExit 0 -ExpectContains '미완료 1'
        foreach ($c in $scTsCases) {
            $exists = Test-Path -LiteralPath $c.Path
            $ok = if ($c.Gone) { -not $exists } else { $exists }
            $want = if ($c.Gone) { '지움' } else { '남김' }
            Assert-Case -Name "session-context: karina-plugin 임시 정리 — $($c.Rel) $($c.Days)일 → $want" -R @{ code = ([int](-not $ok)); out = "exists=$exists" } -ExpectExit 0
        }
        Assert-Case -Name "session-context: karina-plugin 임시 정리 — verify 앱 폴더 자체는 깊이 밖이라 남김" -R @{ code = ([int](-not (Test-Path -LiteralPath (Join-Path $scTsRoot 'verify\notes')))); out = '' } -ExpectExit 0
        $scTsBudget = New-ScTsItem -Rel 'scratch\budget-old.ps1' -DaysAgo 30
        $env:KARINA_TEMP_SWEEP_BUDGET_MS = '0'
        $null = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scTsProj } | ConvertTo-Json -Compress)
        Assert-Case -Name "session-context: karina-plugin 임시 정리 — 시간 상한 0 이면 아무것도 지우지 않음" -R @{ code = ([int](-not (Test-Path -LiteralPath $scTsBudget))); out = '' } -ExpectExit 0
    } finally {
        $env:TEMP = $scTsSaved.TEMP; $env:TMP = $scTsSaved.TMP; $env:TMPDIR = $scTsSaved.TMPDIR; $env:USERPROFILE = $scTsSaved.P; $env:KARINA_TEMP_SWEEP_BUDGET_MS = $scTsSaved.B
    }
    Remove-Item -Recurse -Force $scTsProj, $scTsTmp -ErrorAction SilentlyContinue

    # ---- compact 직후 작업 시작 시각 재주입 (record-work-start 의 상태 파일) ----
    # 상태 파일은 record-work-start 가 sid 를 [^A-Za-z0-9._-] → _ 로 바꿔 쓴다 — 같은 식으로 찾는지
    #   특수문자 sid 로 잰다. 위 블록과 같은 이유로 USERPROFILE 을 $iso 로 되돌린다.
    $scWsProj = Join-Path $work 'sc-ws-proj'
    New-Item -ItemType Directory $scWsProj -Force | Out-Null
    $scWsDir = Join-Path $iso '.claude/.state/work-start'
    New-Item -ItemType Directory $scWsDir -Force | Out-Null
    '{"plan":"2026-10-16 09:00","chain-plan":"2026-10-16 09:30"}' | Set-Content -LiteralPath (Join-Path $scWsDir 'sc-ws1.json') -Encoding UTF8
    '{"plan":"2026-10-16 08:15"}' | Set-Content -LiteralPath (Join-Path $scWsDir 'sc-ws2.json') -Encoding UTF8
    '{"plan":"2026-10-16 07:45"}' | Set-Content -LiteralPath (Join-Path $scWsDir 'sc_ws3_x.json') -Encoding UTF8
    $scWsSaved = $env:USERPROFILE
    try {
        $env:USERPROFILE = $iso
        $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scWsProj; session_id = 'sc-ws1' } | ConvertTo-Json -Compress)
        Assert-Case -Name "session-context: compact 직후 plan·chain-plan 시작 시각을 다시 주입한다" -R $r -ExpectExit 0 -ExpectContains '[karina 작업 시작] (압축 전 기록) karina:plan 2026-10-16 09:00 · karina:chain-plan 2026-10-16 09:30'
        $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scWsProj; session_id = 'sc-ws2' } | ConvertTo-Json -Compress)
        Assert-Case -Name "session-context: compact 재주입은 있는 키만 싣는다" -R $r -ExpectExit 0 -ExpectContains '[karina 작업 시작] (압축 전 기록) karina:plan 2026-10-16 08:15' -ExpectNotContains 'karina:chain-plan 20'
        $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scWsProj; session_id = 'sc/ws3:x' } | ConvertTo-Json -Compress)
        Assert-Case -Name "session-context: compact 재주입이 특수문자 sid 를 record-work-start 와 같은 식으로 찾는다" -R $r -ExpectExit 0 -ExpectContains 'karina:plan 2026-10-16 07:45'
        $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $scWsProj; session_id = 'sc-ws1' } | ConvertTo-Json -Compress)
        Assert-Case -Name "session-context: startup 에는 작업 시작 줄을 싣지 않는다" -R $r -ExpectExit 0 -ExpectNotContains '[karina 작업 시작]'
        $r = Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'compact'; cwd = $scWsProj; session_id = 'sc-ws-none' } | ConvertTo-Json -Compress)
        Assert-Case -Name "session-context: 상태 파일이 없으면 compact 에도 작업 시작 줄이 없다" -R $r -ExpectExit 0 -ExpectNotContains '[karina 작업 시작]'
    } finally { $env:USERPROFILE = $scWsSaved }
    Remove-Item -Recurse -Force $scWsProj, $scWsDir -ErrorAction SilentlyContinue

    # ---- [회차 4 T1] plan 상위 탐색 · 체크박스 불릿 집합 ----
    # guard-write 와 같은 후보(plan.md·PLAN.md·docs/plan.md)를 위로 찾되 `.git`(폴더·파일)에서 멈춘다 — 근거는
    #   `scripts/rules/session-context-rationale.md` 의 「§5 ---- plan 탐색: 상위 탐색과 레포 경계」. 부모 plan 에는
    #   그 케이스에만 있는 task 수를 심어, 경계에서 멈췄는지가 아니라 「부모 plan 의 고유 수가 안 나오는가」로 잰다.
    #   USERPROFILE 은 위 30일 정리 블록과 같은 이유로 $iso 에 고정한다(vault 홈이면 출력이 vault 줄로 갈린다).
    $scUpSaved = $env:USERPROFILE
    try {
        $env:USERPROFILE = $iso
        $scPlanOf = { param([int]$n) @('# Plan') + @(1..$n | ForEach-Object { "- [ ] **T$_-1** todo" }) }
        $scStart = { param([string]$cwd) Invoke-Hook 'session-context.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $cwd } | ConvertTo-Json -Compress) }

        $scUp = Join-Path $work 'sc-up-repo'
        New-Item -ItemType Directory (Join-Path $scUp '.git'), (Join-Path $scUp 'src/sub') -Force | Out-Null
        & $scPlanOf 7 | Set-Content -Encoding UTF8 (Join-Path $scUp 'plan.md')
        $r = & $scStart (Join-Path $scUp 'src/sub')
        Assert-Case -Name "session-context: 하위 폴더 cwd 는 레포 루트 plan 을 전체 경로로 알린다 (회차 4 T1)" -R $r -ExpectExit 0 -ExpectContains ((Join-Path $scUp 'plan.md') + ': task 7개')

        $scDp = Join-Path $work 'sc-docs-plan'
        New-Item -ItemType Directory (Join-Path $scDp 'docs') -Force | Out-Null
        & $scPlanOf 6 | Set-Content -Encoding UTF8 (Join-Path $scDp 'docs/plan.md')
        $r = & $scStart $scDp
        Assert-Case -Name "session-context: docs/plan.md 를 찾아 상대 경로로 알린다 (회차 4 T1)" -R $r -ExpectExit 0 -ExpectContains 'docs/plan.md: task 6개'

        $scNest = Join-Path $work 'sc-nest'
        New-Item -ItemType Directory (Join-Path $scNest 'child/.git') -Force | Out-Null
        & $scPlanOf 8 | Set-Content -Encoding UTF8 (Join-Path $scNest 'plan.md')
        $r = & $scStart (Join-Path $scNest 'child')
        Assert-Case -Name "session-context: 중첩 레포(.git 폴더)는 부모 plan 을 잡지 않는다 (회차 4 T1)" -R $r -ExpectExit 0 -ExpectNotContains 'task 8개'

        $scWt = Join-Path $work 'sc-wt-parent'
        $scWtChild = Join-Path $scWt '.claude/worktrees/wt1'
        New-Item -ItemType Directory (Join-Path $scWt '.git'), $scWtChild -Force | Out-Null
        & $scPlanOf 9 | Set-Content -Encoding UTF8 (Join-Path $scWt 'plan.md')
        'gitdir: ../../../.git/worktrees/wt1' | Set-Content -Encoding UTF8 (Join-Path $scWtChild '.git')
        $r = & $scStart $scWtChild
        Assert-Case -Name "session-context: worktree(.git 파일)는 부모 레포 plan 을 잡지 않는다 (회차 4 T1)" -R $r -ExpectExit 0 -ExpectNotContains 'task 9개'

        $scBul = Join-Path $work 'sc-bullets'
        New-Item -ItemType Directory $scBul -Force | Out-Null
        @('# Plan', '+ [ ] **T1-1** a', '1. [ ] T2: b', '  - [/] T3: c', '- [X] T4: d', '- [ ] 통과 체크(ID 없음)') |
            Set-Content -Encoding UTF8 (Join-Path $scBul 'plan.md')
        $r = & $scStart $scBul
        Assert-Case -Name "session-context: guard-write 불릿 집합·[X] 로 task 를 센다 (회차 4 T1)" -R $r -ExpectExit 0 -ExpectContains 'task 4개 중 미완료 3개'

        $scMk = Join-Path $work 'sc-markers'
        New-Item -ItemType Directory $scMk -Force | Out-Null
        @('# Plan', '- [x] **T1-1** a', '- [-] **T1-2** b', '- [~] **T1-3** c') | Set-Content -Encoding UTF8 (Join-Path $scMk 'plan.md')
        $r = & $scStart $scMk
        Assert-Case -Name "session-context: [-]·[~] 를 미완료로 센다" -R $r -ExpectExit 0 -ExpectContains 'task 3개 중 미완료 2개'
        $scBt = '```'
        @('# Plan', '- [ ] **T1-1** a', $scBt, '- [ ] **T9-1** x', $scBt, '~~~', '- [x] **T9-2** y', '~~~', ($scBt + 'text'), '- [ ] **T9-3** z') |
            Set-Content -Encoding UTF8 (Join-Path $scMk 'plan.md')
        $r = & $scStart $scMk
        Assert-Case -Name "session-context: 백틱·~~~·닫히지 않은 펜스 안 체크박스는 세지 않는다" -R $r -ExpectExit 0 -ExpectContains 'task 1개 중 미완료 1개'
        @('# Plan', '- [x] **T1-1** a', '- [X] **T1-2** b') | Set-Content -Encoding UTF8 (Join-Path $scMk 'plan.md')
        $r = & $scStart $scMk
        Assert-Case -Name "session-context: [x]·[X] 뿐이면 미완료로 세지 않는다" -R $r -ExpectExit 0 -ExpectNotContains '중 미완료'
    } finally { $env:USERPROFILE = $scUpSaved }
    Remove-Item -Recurse -Force $scUp, $scDp, $scNest, $scWt, $scBul, $scMk -ErrorAction SilentlyContinue
}

