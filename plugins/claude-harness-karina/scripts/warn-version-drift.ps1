# warn-version-drift.ps1 — SessionStart: 설치본 ↔ 하네스 레포 버전 드리프트 경고 (비차단) — 근거는 `rules/version-drift-rationale.md` §1

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
# stdin도 UTF-8로 디코딩 (v1.129.0) — Claude Code는 UTF-8 바이트로 보내는데 콘솔 기본 코드페이지(cp949)로
#   읽으면 한글 경로가 깨져 cwd 기준 plugin.json 탐색이 어긋난다. 실패해도 종전 동작 유지.
try { [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

try {
    # ---- 입력 파싱 (cwd) ----
    $raw = $(if ($null -ne $global:KarinaHookStdin) { $global:KarinaHookStdin } else { [Console]::In.ReadToEnd() })
    if ([string]::IsNullOrWhiteSpace($raw)) { exit 0 }
    $inp = $null
    try { $inp = $raw | ConvertFrom-Json } catch { exit 0 }
    $cwd = [string]$inp.cwd
    if ([string]::IsNullOrWhiteSpace($cwd)) { exit 0 }

    # ---- 하네스 레포 판정 — 모노레포의 플러그인 폴더를 위로 올라가며 찾는다(`harness-root.ps1`). 없으면 즉시 종료 ----
    . (Join-Path $PSScriptRoot 'harness-root.ps1')
    $harnessRoot = Find-HarnessRoot -StartDir $cwd
    if (-not $harnessRoot) { exit 0 }
    $repoPluginJson = Join-Path $harnessRoot '.claude-plugin/plugin.json'

    # ---- 미배포 감지 — 설치 커밋 뒤 origin/main 의 런타임 폴더 커밋 — 근거는 `rules/version-drift-rationale.md` §2
    try {
        $vdHome = if ([string]::IsNullOrEmpty($env:USERPROFILE)) { $HOME } else { $env:USERPROFILE }
        $installedRec = Join-Path $vdHome '.claude/plugins/installed_plugins.json'
        $inst = $null
        if (Test-Path -LiteralPath $installedRec) {
            $inst = @((Get-Content -LiteralPath $installedRec -Raw | ConvertFrom-Json).plugins.'karina@karina-plugins') | Where-Object { $_ -and $_.gitCommitSha } | Select-Object -First 1
        }
        if ($inst -and ([string]$inst.gitCommitSha) -match '^[0-9a-f]{7,40}$') {
            $instSha = [string]$inst.gitCommitSha
            $instVer = [string]$inst.version
            Push-Location -LiteralPath $harnessRoot
            try {
                # 하니스 루트의 git 루트 기준 위치(모노레포면 plugins/claude-harness-karina/, 아니면 빈 값)
                $harnessPrefix = ((& git rev-parse --show-prefix 2>$null) -join '').Trim()
                # `-join` 필수 — git show는 **줄 배열**을 반환한다 — 근거는 `rules/version-drift-rationale.md` §3
                $pushedJson = (& git show "origin/main:${harnessPrefix}.claude-plugin/plugin.json" 2>$null) -join "`n"
                if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($pushedJson)) {
                    $pushedVer = $null
                    try { $pushedVer = ($pushedJson | ConvertFrom-Json).version } catch { $pushedVer = $null }
                    & git cat-file -e "$instSha^{commit}" 2>$null
                    if ($LASTEXITCODE -eq 0 -and -not [string]::IsNullOrWhiteSpace($pushedVer)) {
                        $undeployed = @(& git log --format=%h "$instSha..origin/main" -- .claude-plugin agents evals hooks scripts skills 2>$null | Where-Object { $_ })
                        if ($LASTEXITCODE -eq 0 -and $undeployed.Count -gt 0) {
                            $instLabel = "설치본(v${instVer} · 커밋 $($instSha.Substring(0, 8)))"
                            if ($pushedVer -eq $instVer) {
                                Write-Output "[karina 미배포] ${instLabel} 뒤 origin/main 에 하니스 런타임 폴더 커밋 $($undeployed.Count)건이 버전을 올리지 않은 채 있습니다 — 버전 커밋으로 버전을 올려 push 한 뒤 /plugin update 해야 설치본에 갑니다(docs/harness-conventions.md 「판정 시점」)."
                            } else {
                                Write-Output "[karina 미배포] origin/main 의 v${pushedVer} 가 ${instLabel}에 아직 없습니다(하니스 런타임 폴더 커밋 $($undeployed.Count)건) — 사용 PC 에서 /plugin update 로 반영하세요."
                            }
                        }
                    }
                }
            } finally { Pop-Location }
        }
    } catch {}

    # ---- 자기(설치본) 버전 ----
    $root = $env:CLAUDE_PLUGIN_ROOT
    if ([string]::IsNullOrWhiteSpace($root)) { exit 0 }
    $selfPluginJson = Join-Path $root '.claude-plugin/plugin.json'
    if (-not (Test-Path -LiteralPath $selfPluginJson)) { exit 0 }

    $repoVer = $null; $selfVer = $null
    try { $repoVer = (Get-Content -LiteralPath $repoPluginJson -Raw | ConvertFrom-Json).version } catch { exit 0 }
    try { $selfVer = (Get-Content -LiteralPath $selfPluginJson -Raw | ConvertFrom-Json).version } catch { exit 0 }
    if ([string]::IsNullOrWhiteSpace($repoVer) -or [string]::IsNullOrWhiteSpace($selfVer)) { exit 0 }

    if ($repoVer -ne $selfVer) {
        # stdout → 세션 컨텍스트 주입 (SessionStart exit 0 규약)
        Write-Output "[karina 버전 드리프트] 설치본 v$selfVer ≠ 레포 v$repoVer — 재설치 전까지 이 세션의 hook·스킬은 설치본(v$selfVer) 기준으로 동작합니다. 레포 변경분을 세션에 반영하려면 재설치가 필요합니다 (커밋·push 뒤 /plugin update — 사용자 실행)."
    }

    exit 0
} catch {
    exit 0
}
