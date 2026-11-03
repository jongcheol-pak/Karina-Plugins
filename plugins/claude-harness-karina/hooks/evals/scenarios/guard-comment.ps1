if (Test-HookSelected @('guard-comment', 'guard-harness')) {

$gc = Join-Path $work 'gcproj'; New-Item -ItemType Directory $gc -Force | Out-Null
$gcSeq = 0
function Invoke-GcEdit {
    param([string]$Name, [string]$Old, [string]$New, [string]$Session = '')
    $script:gcSeq++
    $sid = if ($Session) { $Session } else { "gc-$($script:gcSeq)" }
    $j = @{ session_id = $sid; tool_name = 'Edit'; cwd = $gc; tool_input = @{ file_path = (Join-Path $gc $Name); old_string = $Old; new_string = $New } } | ConvertTo-Json -Compress -Depth 5
    return (Invoke-Hook 'guard-harness.ps1' $j)
}
function Invoke-GcWrite {
    param([string]$Path, [string]$Content, [string]$Session = '')
    $script:gcSeq++
    $sid = if ($Session) { $Session } else { "gc-$($script:gcSeq)" }
    $j = @{ session_id = $sid; tool_name = 'Write'; cwd = $gc; tool_input = @{ file_path = $Path; content = $Content } } | ConvertTo-Json -Compress -Depth 5
    return (Invoke-Hook 'guard-harness.ps1' $j)
}
$gcBlock = '[HARNESS] BLOCKED: 새 주석을 더하는 편집은 첫 시도를 막습니다'

$r = Invoke-GcEdit 'line.rs' 'fn a() {}' "// 섹션의 첫 행인가`nfn a() {}" 'gc-retry'
Assert-Case -Name "guard-comment: 줄 주석을 더한 Edit 첫 시도는 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
Assert-Case -Name "guard-comment: 차단 사유가 예외 목록과 재제출 안내를 낸다" -R $r -ExpectExit 2 -ExpectContains '같은 편집을 그대로 다시 내세요'
$r = Invoke-GcEdit 'line.rs' 'fn a() {}' "// 섹션의 첫 행인가`nfn a() {}" 'gc-retry'
Assert-Case -Name "guard-comment: 같은 편집 재제출은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-GcEdit 'line.rs' 'fn a() {}' "// 다른 설명으로 바꿈`nfn a() {}" 'gc-retry'
Assert-Case -Name "guard-comment: 주석을 바꿔 다시 내면 다시 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'line.rs' 'fn a() {}' "// 섹션의 첫 행인가`nfn a() {}" 'gc-other-session'
Assert-Case -Name "guard-comment: 다른 세션의 재제출 표지는 쓰지 않는다(다시 차단)" -R $r -ExpectExit 2 -ExpectContains $gcBlock

$r = Invoke-GcEdit 'doc.rs' 'pub fn b() {}' "/// 그 모니터 작업 영역 가운데.`npub fn b() {}"
Assert-Case -Name "guard-comment: doc 주석(///) 추가도 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$multiEdits = @(@{ old_string = 'const a = 0;'; new_string = 'const a = 1;' }, @{ old_string = 'const b = 2;'; new_string = "// 설명`nconst b = 2;" })
$r = Invoke-Hook 'guard-harness.ps1' (@{ session_id = 'gc-multi'; tool_name = 'MultiEdit'; cwd = $gc; tool_input = @{ file_path = (Join-Path $gc 'multi.ts'); edits = $multiEdits } } | ConvertTo-Json -Compress -Depth 5)
Assert-Case -Name "guard-comment: MultiEdit 둘째 편집 쌍의 주석도 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'block.cs' 'int x = 1;' "/* 첫 줄`n * 둘째 줄`n * 셋째 줄 */`nint x = 1;"
Assert-Case -Name "guard-comment: 블록 주석은 블록 안 줄까지 센다" -R $r -ExpectExit 2 -ExpectContains '주석 3줄'
$r = Invoke-GcEdit 'tool.ps1' '$a = 1' "# 설명`n`$a = 1"
Assert-Case -Name "guard-comment: .ps1 # 주석도 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'word.ts' 'const r = 1;' "// 이 region 좌표는 화면 기준`nconst r = 1;"
Assert-Case -Name "guard-comment: 지시문 낱말이 본문 중간에 있으면 제외하지 않는다" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'requires.cs' 'int p = 0;' "// Requires admin rights to open the port`nint p = 0;"
Assert-Case -Name "guard-comment: Requires 로 시작하는 일반 주석은 .ps1 지시문이 아니다" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'region.ts' 'let q = 0;' "// region of interest is the visible rect`nlet q = 0;"
Assert-Case -Name "guard-comment: region 으로 시작하는 일반 주석은 접기 지시문이 아니다" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'go.py' 'v = 0' "# go: 이 값은 첫 화면 기준`nv = 0"
Assert-Case -Name "guard-comment: .py 의 go: 로 시작하는 주석은 Go 지시문이 아니다" -R $r -ExpectExit 2 -ExpectContains $gcBlock

$r = Invoke-GcEdit 'ps_directive.ps1' '$z = 0' "#Requires -Version 7`n#region Helpers`n#endregion`n`$z = 0"
Assert-Case -Name "guard-comment: .ps1 의 #Requires·#region 지시문은 통과" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-GcEdit 'go_directive.go' 'var w = 0' "//go:generate stringer -type=W`n// #region A`n// #endregion`nvar w = 0"
Assert-Case -Name "guard-comment: // 계열의 //go:·// #region 지시문은 통과" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-GcEdit 'move.rs' "// 기존 설명`nfn a() {}" "fn b() {}`n// 기존 설명"
Assert-Case -Name "guard-comment: 옮기기만 한 주석은 통과" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-GcEdit 'lint.ts' 'f();' "// eslint-disable-next-line`n// @ts-ignore`n// prettier-ignore`nf();"
Assert-Case -Name "guard-comment: 린트·포매터 지시문만 더하면 통과" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-GcWrite (Join-Path $gc 'head.sh') "#!/usr/bin/env bash`n# SPDX-License-Identifier: MIT`necho hi"
Assert-Case -Name "guard-comment: shebang·라이선스 줄만 있는 Write 는 통과" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-GcEdit 'note.md' '본문' "<!-- 메모 -->`n본문"
Assert-Case -Name "guard-comment: 문서 HTML 주석은 대상이 아니다" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-GcEdit 'ptr.c' 'int y;' "int y;`n*ptr = 1;"
Assert-Case -Name "guard-comment: 블록 밖 * 시작 줄은 주석이 아니다" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-GcEdit 'code.rs' 'let x = 1;' "let x = 1;`nlet y = 2;"
Assert-Case -Name "guard-comment: 주석 없는 편집은 통과" -R $r -ExpectExit 0 -ExpectSilent $true

$r = Invoke-GcWrite (Join-Path $gc 'new.py') "# 설명`nx = 1"
Assert-Case -Name "guard-comment: 새 파일 Write 는 파일 전체의 주석을 센다" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$gcExisting = Join-Path $gc 'existing.go'
[System.IO.File]::WriteAllText($gcExisting, "// 기존 설명`nvar a = 1", [System.Text.UTF8Encoding]::new($false))
$r = Invoke-GcWrite $gcExisting "// 기존 설명`n// 새 설명`nvar a = 1"
Assert-Case -Name "guard-comment: 기존 파일 Write 는 새로 더한 주석만 센다" -R $r -ExpectExit 2 -ExpectContains '주석 1줄'
$r = Invoke-GcWrite $gcExisting "// 기존 설명`nvar a = 1`nvar b = 2"
Assert-Case -Name "guard-comment: 기존 파일 Write 의 원래 주석은 다시 막지 않는다" -R $r -ExpectExit 0 -ExpectSilent $true

$gcTempFile = Join-Path ([System.IO.Path]::GetTempPath()) 'karina-gc-scratch.py'
$r = Invoke-GcWrite $gcTempFile "# 스크래치 설명`nx = 1"
Assert-Case -Name "guard-comment: 시스템 임시 폴더 아래 파일은 통과" -R $r -ExpectExit 0 -ExpectSilent $true

$gcStateDir = Join-Path $env:USERPROFILE '.claude/.state/comment-gate'
$gcStateBackup = $null
if (Test-Path -LiteralPath $gcStateDir) { $gcStateBackup = "$gcStateDir.bak-eval"; Move-Item -LiteralPath $gcStateDir -Destination $gcStateBackup -Force }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $gcStateDir) | Out-Null
Set-Content -LiteralPath $gcStateDir -Value 'not a directory'
$r = Invoke-GcEdit 'state.rs' 'fn s() {}' "// 상태 폴더를 못 쓰는 경우`nfn s() {}"
Assert-Case -Name "guard-comment: 상태 폴더를 쓸 수 없으면 통과(fail-open)" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
Remove-Item -LiteralPath $gcStateDir -Force
if ($gcStateBackup) { Move-Item -LiteralPath $gcStateBackup -Destination $gcStateDir -Force }

$r = Invoke-Hook 'guard-harness.ps1' 'not json'
Assert-Case -Name "guard-comment: 깨진 stdin 은 exit 0 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

$gcHooks = Get-Content -LiteralPath (Join-Path $pluginRoot 'hooks/hooks.json') -Raw | ConvertFrom-Json
$gcOwn = @($gcHooks.hooks.PreToolUse | Where-Object { @($_.hooks | Where-Object { $_.command -match 'guard-comment\.ps1' }).Count -gt 0 }).Count
$gcHost = @($gcHooks.hooks.PreToolUse | Where-Object { @($_.hooks | Where-Object { $_.command -match 'guard-harness\.ps1' }).Count -gt 0 } | ForEach-Object { $_.matcher })
Assert-Case -Name "guard-comment: 별도 hook 없이 guard-harness(Write·Edit·MultiEdit) 안에서 돈다" -R @{ code = 0; out = "own=$gcOwn host=$($gcHost -join ',')" } -ExpectExit 0 -ExpectContains 'own=0 host=Write|Edit|MultiEdit|NotebookEdit'
$r = Invoke-Hook 'guard-harness.ps1' (@{ session_id = 'gc-nb'; tool_name = 'NotebookEdit'; cwd = $gc; tool_input = @{ notebook_path = (Join-Path $gc 'nb.py'); new_source = "# 셀 설명`nx = 1" } } | ConvertTo-Json -Compress -Depth 5)
Assert-Case -Name "guard-comment: NotebookEdit 는 검사하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

}
