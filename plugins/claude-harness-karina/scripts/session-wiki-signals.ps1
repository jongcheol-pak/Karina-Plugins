# session-wiki-signals.ps1 — 세션 시작 주입의 위키 vault 신호 — 근거는 `rules/wiki-signals-rationale.md` §1

function Get-WikiSignals {
            # ---- 위키 vault 설정 상태 판정 — 근거는 `rules/session-context-rationale-wiki.md` §23
            $vaultLine = $null
            $userHome = [string]$env:USERPROFILE
            if (-not [string]::IsNullOrWhiteSpace($userHome)) {
                $vaultCfg = Join-Path $userHome '.claude/llm-wiki-config.json'
                if (Test-Path -LiteralPath $vaultCfg -PathType Leaf) {
                    $vaultPath = $null
                    # 손상 JSON·BOM·권한 오류는 조용히 통과(fail-open) — 세션 시작을 막지 않는다
                    try { $vaultPath = [string]((Get-Content -LiteralPath $vaultCfg -Raw -Encoding UTF8 | ConvertFrom-Json).vault_path) } catch {}
                    if (-not [string]::IsNullOrWhiteSpace($vaultPath)) {
                        if (Test-Path -LiteralPath $vaultPath -PathType Container) {
                            $vaultLine = "[karina 세션 컨텍스트] 위키 vault: 설정됨 ($vaultPath) — 프로젝트 맥락이 필요하면 AGENTS.md의 '## 위키'가 지목한 허브를 먼저 Read하세요(판정 단서는 글로벌 지침 「프로젝트 맥락」). 읽고 쓰는 시점은 $(Split-Path -Parent $PSScriptRoot)/skills/WIKI.md 가 정본입니다. `"미설정`"으로 단정하지 마세요."
                        } else {
                            # 파일을 가리키는 경우도 여기로 온다(-PathType Container 실패) — vault로 쓸 수 없으므로 부재와 동일 취급
                            $vaultLine = "[karina 세션 컨텍스트] 위키 vault: 설정 경로 부재 ($vaultPath) — 조용히 통과하되 확인한 사실을 1줄 기록하세요(형식은 $(Split-Path -Parent $PSScriptRoot)/skills/WIKI.md 의 기록 의무). 위키 작업 요청 시 경로 재확인이 필요합니다."
                        }
                    }
                }
            }
    return @{ VaultLine = $vaultLine }
}
