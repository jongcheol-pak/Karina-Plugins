# harness-root.ps1 — 하니스 루트 판정 (dot-source 전용, hook 아님)
#
# 하니스는 모노레포(jongcheol-pak/Karina-Plugins)의 플러그인 폴더 plugins/claude-harness-karina 에 산다.
#   그래서 git 루트가 곧 하니스 루트라는 가정을 쓰지 않고, 시작 폴더에서 위로 올라가며 처음 만나는
#   「이름이 karina 인 플러그인 매니페스트 + 하니스 규약 문서」 폴더를 하니스 루트로 본다.
#   이름만 보면 같은 레포의 다른 플러그인이, 규약 문서만 보면 사용자 프로젝트가 걸리므로 둘을 함께 본다.
# git 루트(.git 이 있는 폴더)에서 멈춘다 — 레포 밖 상위 폴더를 하니스로 읽지 않는다.
# 쓰는 곳: guard-stale-docs.ps1 · warn-version-drift.ps1 · session-ledger-signal.ps1

function Find-HarnessRoot {
    param([string]$StartDir)
    if ([string]::IsNullOrWhiteSpace($StartDir)) { return $null }
    $dir = $null
    try { $dir = [System.IO.Path]::GetFullPath($StartDir) } catch { return $null }
    while ($dir) {
        $manifest = Join-Path $dir '.claude-plugin/plugin.json'
        if ((Test-Path -LiteralPath $manifest -PathType Leaf) -and
            (Test-Path -LiteralPath (Join-Path $dir 'docs/harness-conventions.md') -PathType Leaf)) {
            $name = $null
            try { $name = (Get-Content -LiteralPath $manifest -Raw -Encoding UTF8 | ConvertFrom-Json).name } catch {}
            if ($name -eq 'karina') { return $dir }
        }
        if (Test-Path -LiteralPath (Join-Path $dir '.git')) { return $null }
        $parent = [System.IO.Path]::GetDirectoryName($dir)
        if ([string]::IsNullOrEmpty($parent) -or $parent -eq $dir) { break }
        $dir = $parent
    }
    return $null
}
