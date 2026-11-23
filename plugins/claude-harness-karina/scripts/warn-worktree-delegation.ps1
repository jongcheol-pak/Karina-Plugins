# warn-worktree-delegation.ps1 — implement 루프 중 병렬 그룹 밖 task 를 worktree 서브에이전트에 맡기면 경고한다 — 근거는 `rules/worktree-delegation-rationale.md` §1

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
try { [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

# 판정 불가는 침묵이다 — 근거는 `rules/worktree-delegation-rationale.md` §3
try { $data = $(if ($null -ne $global:KarinaHookStdin) { $global:KarinaHookStdin } else { [Console]::In.ReadToEnd() }) | ConvertFrom-Json -ErrorAction Stop } catch { exit 0 }
if (-not $data) { exit 0 }

# 경고 조건 다섯 — 근거는 `rules/worktree-delegation-rationale.md` §2
if ([string]$data.tool_input.isolation -ne 'worktree') { exit 0 }
if (-not [string]::IsNullOrEmpty([string]$data.agent_id)) { exit 0 }
$sid = [string]$data.session_id
$cwd = [string]$data.cwd
if ([string]::IsNullOrWhiteSpace($sid) -or [string]::IsNullOrWhiteSpace($cwd)) { exit 0 }
$base = if ([string]::IsNullOrEmpty($env:USERPROFILE)) { $HOME } else { $env:USERPROFILE }
$marker = Join-Path (Join-Path $base '.claude/.state/loop-continue') (($sid -replace '[^A-Za-z0-9._-]', '_') + '.active')
if (-not (Test-Path -LiteralPath $marker)) { exit 0 }
try { . (Join-Path $PSScriptRoot 'plan-round.ps1') } catch { exit 0 }
$plan = Find-SinglePlanUpwards -StartDir $cwd
if (-not $plan) { exit 0 }
try { $text = [System.IO.File]::ReadAllText($plan) } catch { exit 0 }
$groups = @([regex]::Matches($text, '(?m)^> 병렬 그룹:([^\r\n]*)') | ForEach-Object { $_.Groups[1].Value -replace '—.*$', '' })
$task = [regex]::Match([string]$data.tool_input.description, '\bT(\d+)\b')
if ($groups.Count -gt 0 -and $task.Success) {
    $grouped = @($groups | ForEach-Object { [regex]::Matches($_, 'T(\d+)') | ForEach-Object { $_.Groups[1].Value } })
    if ($grouped -contains $task.Groups[1].Value) { exit 0 }
}

$why = if ($groups.Count -eq 0) { 'plan.md 에 `> 병렬 그룹:` 줄이 없습니다' } else { '이 task 는 plan.md 의 `> 병렬 그룹:` 줄에 없습니다' }
$msg = "[karina 위임 경고] implement 루프 중 worktree 서브에이전트 위임 — $why. task 는 직접 실행하고, 서브에이전트 위임은 병렬 그룹이 묶은 task 만 references/parallel-run.md「띄우기」 서식(description `"T<N> 병렬 실행`")으로 합니다(implement SKILL.md「작업 범위」). 그룹 대기 중 그룹 밖 task 를 병행하지 않습니다(parallel-run.md「대기」)."
[Console]::Error.WriteLine($msg)
$out = @{ hookSpecificOutput = @{ hookEventName = 'PreToolUse'; additionalContext = $msg } }
Write-Output ($out | ConvertTo-Json -Compress -Depth 4)
exit 0
