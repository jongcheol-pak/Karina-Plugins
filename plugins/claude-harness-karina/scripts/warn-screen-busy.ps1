# warn-screen-busy.ps1 — 화면 검증 에이전트가 도는 동안 같은 레포 파일을 Write·Edit 하면 경고한다 — 근거는 `rules/screen-busy-rationale.md` §1

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
try { [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

function Get-KarinaTempRoot {
    $base = @($env:TMPDIR, $env:TEMP, $env:TMP) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -First 1
    if (-not $base) { $base = [System.IO.Path]::GetTempPath() }
    return (Join-Path $base 'karina-plugin')
}

# worktree 의 `.git` 파일(`gitdir: …/worktrees/…`)만 레포 경계로 본다 — 서브모듈(`…/modules/…`)은 아니다 — 근거는 `rules/write-gate-rationale.md` §25
function Test-WorktreeGitFile([string]$dir) {
    $gf = Join-Path $dir '.git'
    if (-not (Test-Path -LiteralPath $gf -PathType Leaf)) { return $false }
    $first = [string](@(Get-Content -LiteralPath $gf -TotalCount 1 -ErrorAction SilentlyContinue)[0])
    return ($first -match '^gitdir:.*[\\/]worktrees[\\/]')
}

function ConvertTo-RootKey([string]$p) { return ([System.IO.Path]::GetFullPath($p) -replace '/', '\').TrimEnd('\').ToLowerInvariant() }

try { $data = $(if ($null -ne $global:KarinaHookStdin) { $global:KarinaHookStdin } else { [Console]::In.ReadToEnd() }) | ConvertFrom-Json -ErrorAction Stop } catch { exit 0 }
if (-not $data) { exit 0 }

# 경고 조건 넷 — 근거는 `rules/screen-busy-rationale.md` §3
if (-not [string]::IsNullOrEmpty([string]$data.agent_id)) { exit 0 }
$busyDir = Join-Path (Get-KarinaTempRoot) 'screen-busy'
if (-not (Test-Path -LiteralPath $busyDir -PathType Container)) { exit 0 }
$target = [string]$data.tool_input.file_path
if (-not $target) { $target = [string]$data.tool_input.notebook_path }
if (-not $target) { exit 0 }

$live = @()
foreach ($f in @(Get-ChildItem -LiteralPath $busyDir -Filter '*.json' -File)) {
    try { $m = Get-Content -LiteralPath $f.FullName -Raw | ConvertFrom-Json -ErrorAction Stop } catch { continue }
    $alive = $m.pid -and (Get-Process -Id ([int]$m.pid) -ErrorAction SilentlyContinue)
    $fresh = $false
    try { $fresh = ((Get-Date) - [datetime]::Parse([string]$m.started, $null, [System.Globalization.DateTimeStyles]::RoundtripKind)).TotalSeconds -le 1500 } catch {}
    if (-not $alive -or -not $fresh) { try { [System.IO.File]::Delete($f.FullName) } catch {}; continue }
    if ($m.root) { $live += ConvertTo-RootKey ([string]$m.root) }
}
if (-not $live.Count) { exit 0 }

$dir = [System.IO.Path]::GetDirectoryName([System.IO.Path]::GetFullPath($target))
$repo = $null
while ($dir) {
    if ((Test-Path -LiteralPath (Join-Path $dir '.git') -PathType Container) -or (Test-WorktreeGitFile $dir)) { $repo = $dir; break }
    $parent = [System.IO.Path]::GetDirectoryName($dir)
    if ($parent -eq $dir) { break }
    $dir = $parent
}
if (-not $repo -or ($live -notcontains (ConvertTo-RootKey $repo))) { exit 0 }

$msg = "[karina 검증 대기 경고] 화면 검증 에이전트가 이 레포($repo)의 앱을 빌드·조작하는 중에 파일을 고치려 합니다 — 응답이 올 때까지 다음 task 는 읽기만 하고, Edit·Write·커밋·체크박스는 응답을 받은 뒤 합니다(implement references/loop-pacing.md「검증 대기」). 지금 고치면 검증이 더러운 작업 트리를 빌드하고 두 변경이 한 커밋에 섞입니다."
[Console]::Error.WriteLine($msg)
$out = @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; additionalContext = $msg } }
Write-Output ($out | ConvertTo-Json -Compress -Depth 4)
exit 0
