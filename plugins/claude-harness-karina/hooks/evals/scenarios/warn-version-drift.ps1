# scenarios/warn-version-drift.ps1 — warn-version-drift 시나리오 (§10) (dot-source 전용, 단독 실행 금지)
# 호출자(run-hook-evals.ps1)의 공용 헬퍼(Assert-Case·Invoke-Hook·New-WriteJson·New-CommitJson)와 공유 변수($work·$iso·$gitOk·$pw·$vdCache)를 그대로 쓴다.
# 파일명은 검증 대상 hook 기준이고, Invoke-Hook에 넘기는 문자열은 scripts/ 아래 hook 파일명이다.
# ==== 아래는 본체에서 원문 그대로 옮긴 구간 (순수 이동 — 재조립 등가 검사의 경계) ====
# =====================================================================
# 10) warn-version-drift 시나리오 (SessionStart — 설치본↔레포 버전 비교)
# =====================================================================
# 설치본은 $env:CLAUDE_PLUGIN_ROOT 픽스처로, 레포는 하니스 루트 마커(이름 karina 인 .claude-plugin/plugin.json +
# docs/harness-conventions.md — `harness-root.ps1`) 픽스처로 위장한다. 실행 후 CLAUDE_PLUGIN_ROOT는 원복(다른 시나리오 오염 방지).
if (Test-HookSelected @('warn-version-drift')) {
$vdRealRoot = $env:CLAUDE_PLUGIN_ROOT
try {
    # 가짜 설치본 (v1.0.0)
    $vdInst = Join-Path $work 'vd-installed'
    New-Item -ItemType Directory (Join-Path $vdInst '.claude-plugin') -Force | Out-Null
    '{ "name": "karina", "version": "1.0.0" }' | Set-Content (Join-Path $vdInst '.claude-plugin/plugin.json')
    $env:CLAUDE_PLUGIN_ROOT = $vdInst

    # 가짜 하네스 레포 (v9.9.9 — 불일치)
    $vdRepo = Join-Path $work 'vd-repo'
    New-Item -ItemType Directory (Join-Path $vdRepo '.claude-plugin') -Force | Out-Null
    New-Item -ItemType Directory (Join-Path $vdRepo '.claude-plugin') -Force | Out-Null
    '{ "name": "karina", "version": "9.9.9" }' | Set-Content (Join-Path $vdRepo '.claude-plugin/plugin.json')
    New-Item -ItemType Directory (Join-Path $vdRepo 'docs') -Force | Out-Null
    '# 규약' | Set-Content (Join-Path $vdRepo 'docs/harness-conventions.md')

    $vdJson = @{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $vdRepo } | ConvertTo-Json -Compress
    # 1) 불일치 → 드리프트 경고 (exit 0 — 비차단)
    $r = Invoke-Hook 'warn-version-drift.ps1' $vdJson
    Assert-Case -Name "version-drift: 설치본≠레포 경고" -R $r -ExpectExit 0 -ExpectContains '버전 드리프트'
    Assert-Case -Name "version-drift: 재설치 안내가 /plugin update 를 가리킨다" -R $r -ExpectExit 0 -ExpectContains '/plugin update'

    # 2) 일치 → 무출력
    '{ "name": "karina", "version": "1.0.0" }' | Set-Content (Join-Path $vdRepo '.claude-plugin/plugin.json')
    $r = Invoke-Hook 'warn-version-drift.ps1' $vdJson
    Assert-Case -Name "version-drift: 버전 일치 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

    # 3) 비레포 cwd(마커 없음) → 무출력
    $r = Invoke-Hook 'warn-version-drift.ps1' (@{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $work } | ConvertTo-Json -Compress)
    Assert-Case -Name "version-drift: 비레포 cwd 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

    # 4) CLAUDE_PLUGIN_ROOT 부재 → 무출력 (fail-open)
    $env:CLAUDE_PLUGIN_ROOT = $null
    '{ "name": "karina", "version": "9.9.9" }' | Set-Content (Join-Path $vdRepo '.claude-plugin/plugin.json')
    $r = Invoke-Hook 'warn-version-drift.ps1' $vdJson
    Assert-Case -Name "version-drift: CLAUDE_PLUGIN_ROOT 부재 무출력(fail-open)" -R $r -ExpectExit 0 -ExpectSilent $true

    if ($gitOk) {
        $vdGit = Join-Path $work 'vd-gitrepo'
        New-Item -ItemType Directory (Join-Path $vdGit '.claude-plugin') -Force | Out-Null
        New-Item -ItemType Directory (Join-Path $vdGit '.claude-plugin') -Force | Out-Null
        '{ "name": "karina", "version": "2.3.4" }' | Set-Content (Join-Path $vdGit '.claude-plugin/plugin.json')
        New-Item -ItemType Directory (Join-Path $vdGit 'docs') -Force | Out-Null
        '# 규약' | Set-Content (Join-Path $vdGit 'docs/harness-conventions.md')
        Push-Location -LiteralPath $vdGit
        try {
            & git init -q 2>$null
            & git config user.email eval@example.com 2>$null
            & git config user.name eval 2>$null
            & git add -A 2>$null
            & git commit -q -m 'v2.3.4' 2>$null
            & git update-ref refs/remotes/origin/main HEAD 2>$null
        } finally { Pop-Location }
        $vdGitJson = @{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $vdGit } | ConvertTo-Json -Compress

        $vdRecDir = Join-Path $env:USERPROFILE '.claude/plugins'
        $vdRecFile = Join-Path $vdRecDir 'installed_plugins.json'
        $vdWriteRec = {
            param($sha, $ver)
            New-Item -ItemType Directory $vdRecDir -Force | Out-Null
            (@{ version = 2; plugins = @{ 'karina@karina-plugins' = @(@{ scope = 'user'; version = $ver; gitCommitSha = $sha }) } } | ConvertTo-Json -Depth 5) | Set-Content -LiteralPath $vdRecFile
        }
        $vdCommit = {
            param($repo, $path, $msg)
            Push-Location -LiteralPath $repo
            try {
                New-Item -ItemType Directory (Split-Path $path) -Force | Out-Null
                $msg | Set-Content $path
                & git add -A 2>$null; & git commit -q -m $msg 2>$null
                & git update-ref refs/remotes/origin/main HEAD 2>$null
            } finally { Pop-Location }
        }
        Remove-Item -LiteralPath $vdRecFile -Force -ErrorAction SilentlyContinue

        $r = Invoke-Hook 'warn-version-drift.ps1' $vdGitJson
        Assert-Case -Name "version-drift: 미배포 — 설치 기록이 없으면 무출력(fail-open)" -R $r -ExpectExit 0 -ExpectSilent $true

        $vdInstSha = ((& git -C $vdGit rev-parse HEAD 2>$null) -join '').Trim()
        & $vdWriteRec $vdInstSha '2.3.4'
        $r = Invoke-Hook 'warn-version-drift.ps1' $vdGitJson
        Assert-Case -Name "version-drift: 미배포 — 설치 커밋이 origin/main 이면 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

        & $vdCommit $vdGit 'docs/note.md' 'docs 변경'
        $r = Invoke-Hook 'warn-version-drift.ps1' $vdGitJson
        Assert-Case -Name "version-drift: 미배포 — 설치 커밋 뒤 런타임 폴더 밖 변경만 있으면 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

        & $vdCommit $vdGit 'skills/a.md' 'skills 변경'
        $r = Invoke-Hook 'warn-version-drift.ps1' $vdGitJson
        Assert-Case -Name "version-drift: 미배포 — 설치 커밋 뒤 런타임 커밋 · 버전 같음 → 발화" -R $r -ExpectExit 0 -ExpectContains '[karina 미배포]'
        Assert-Case -Name "version-drift: 미배포 — 버전 같으면 버전을 올리라고 안내" -R $r -ExpectExit 0 -ExpectContains '버전을 올리지 않은'
        Assert-Case -Name "version-drift: 미배포 — 런타임 커밋 건수를 싣는다" -R $r -ExpectExit 0 -ExpectContains '1건'
        Assert-Case -Name "version-drift: 미배포 — 릴리즈·태그 문구가 없다" -R $r -ExpectExit 0 -ExpectNotContains '릴리즈'

        $vdOriginSha = ((& git -C $vdGit rev-parse HEAD 2>$null) -join '').Trim()
        & git -C $vdGit update-ref -d refs/remotes/origin/main 2>$null
        $r = Invoke-Hook 'warn-version-drift.ps1' $vdGitJson
        Assert-Case -Name "version-drift: origin/main 부재 무출력(fail-open)" -R $r -ExpectExit 0 -ExpectSilent $true
        & git -C $vdGit update-ref refs/remotes/origin/main $vdOriginSha 2>$null

        & $vdCommit $vdGit '.claude-plugin/plugin.json' '{ "name": "karina", "version": "2.4.0" }'
        $r = Invoke-Hook 'warn-version-drift.ps1' $vdGitJson
        Assert-Case -Name "version-drift: 미배포 — 버전이 다르면 /plugin update 안내" -R $r -ExpectExit 0 -ExpectContains '/plugin update'
        Assert-Case -Name "version-drift: 미배포 — origin/main 버전을 싣는다" -R $r -ExpectExit 0 -ExpectContains 'v2.4.0'
        Assert-Case -Name "version-drift: 미배포 — 버전이 다르면 버전 올리기 안내가 없다" -R $r -ExpectExit 0 -ExpectNotContains '버전을 올리지 않은'

        & $vdWriteRec ('d' * 40) '2.3.4'
        $r = Invoke-Hook 'warn-version-drift.ps1' $vdGitJson
        Assert-Case -Name "version-drift: 미배포 — 설치 커밋이 로컬에 없으면 무출력(fail-open)" -R $r -ExpectExit 0 -ExpectSilent $true

        $vdMono = Join-Path $work 'vd-mono'
        $vdMonoH = Join-Path $vdMono 'plugins/claude-harness-karina'
        foreach ($d in @("$vdMonoH/.claude-plugin", "$vdMonoH/docs", "$vdMono/plugins/other/.claude-plugin", "$vdMono/.claude-plugin")) {
            New-Item -ItemType Directory $d -Force | Out-Null
        }
        '{ "name": "karina", "version": "5.6.7" }' | Set-Content (Join-Path $vdMonoH '.claude-plugin/plugin.json')
        '# 규약' | Set-Content (Join-Path $vdMonoH 'docs/harness-conventions.md')
        '{ "name": "other", "version": "0.1.0" }' | Set-Content (Join-Path $vdMono 'plugins/other/.claude-plugin/plugin.json')
        '{ "name": "karina-plugins" }' | Set-Content (Join-Path $vdMono '.claude-plugin/marketplace.json')
        Push-Location -LiteralPath $vdMono
        try {
            & git init -q 2>$null
            & git config user.email eval@example.com 2>$null
            & git config user.name eval 2>$null
            & git add -A 2>$null
            & git commit -q -m 'v5.6.7' 2>$null
            & git update-ref refs/remotes/origin/main HEAD 2>$null
        } finally { Pop-Location }
        $vdMonoJson = @{ hook_event_name = 'SessionStart'; source = 'startup'; cwd = $vdMonoH } | ConvertTo-Json -Compress
        & $vdWriteRec (((& git -C $vdMono rev-parse HEAD 2>$null) -join '').Trim()) '5.6.7'

        & $vdCommit $vdMono 'plugins/other/skills/x.md' 'other 변경'
        $r = Invoke-Hook 'warn-version-drift.ps1' $vdMonoJson
        Assert-Case -Name "version-drift: 모노레포 다른 플러그인 커밋은 미배포로 세지 않는다" -R $r -ExpectExit 0 -ExpectSilent $true

        & $vdCommit $vdMono 'plugins/claude-harness-karina/skills/y.md' 'karina 변경'
        $r = Invoke-Hook 'warn-version-drift.ps1' $vdMonoJson
        Assert-Case -Name "version-drift: 모노레포 하니스 런타임 커밋은 미배포 발화" -R $r -ExpectExit 0 -ExpectContains '[karina 미배포]'

        Remove-Item -LiteralPath $vdRecFile -Force -ErrorAction SilentlyContinue
        $env:CLAUDE_PLUGIN_ROOT = $vdInst
        $r = Invoke-Hook 'warn-version-drift.ps1' $vdMonoJson
        Assert-Case -Name "version-drift: 모노레포 하니스 폴더에서 설치본≠레포 경고" -R $r -ExpectExit 0 -ExpectContains '버전 드리프트'
        $env:CLAUDE_PLUGIN_ROOT = $null
    }
} finally {
    $env:CLAUDE_PLUGIN_ROOT = $vdRealRoot
}
}   # ---- §10 게이트 끝 (warn-version-drift) ----

