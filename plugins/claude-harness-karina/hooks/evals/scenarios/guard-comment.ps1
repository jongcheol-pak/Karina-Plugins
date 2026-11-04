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
$gcBlock = '[HARNESS] BLOCKED: 새 주석을 더하는 편집을 막습니다'

$r = Invoke-GcEdit 'line.rs' 'fn a() {}' "// 섹션의 첫 행인가`nfn a() {}" 'gc-retry'
Assert-Case -Name "guard-comment: 줄 주석을 더한 Edit 첫 시도는 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
Assert-Case -Name "guard-comment: 차단 사유가 예외 목록과 다시 내도 통과하지 않음을 낸다" -R $r -ExpectExit 2 -ExpectContains '같은 편집을 다시 내도 통과하지 않습니다'

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

function New-GcRepo([string]$Name, [hashtable]$Files, [switch]$GitFile) {
    $d = Join-Path $gc $Name
    New-Item -ItemType Directory -Force -Path $d | Out-Null
    if ($GitFile) { [System.IO.File]::WriteAllText((Join-Path $d '.git'), 'gitdir: elsewhere') } else { New-Item -ItemType Directory -Force -Path (Join-Path $d '.git') | Out-Null }
    foreach ($k in $Files.Keys) {
        $p = Join-Path $d $k
        New-Item -ItemType Directory -Force -Path (Split-Path -Parent $p) | Out-Null
        [System.IO.File]::WriteAllText($p, [string]$Files[$k], [System.Text.UTF8Encoding]::new($false))
    }
    return $d
}
function Invoke-GcEditAt {
    param([string]$Path, [string]$Old, [string]$New, [string]$Session = '')
    $script:gcSeq++
    $sid = if ($Session) { $Session } else { "gc-$($script:gcSeq)" }
    $j = @{ session_id = $sid; tool_name = 'Edit'; cwd = (Split-Path -Parent $Path); tool_input = @{ file_path = $Path; old_string = $Old; new_string = $New } } | ConvertTo-Json -Compress -Depth 5
    return (Invoke-Hook 'guard-harness.ps1' $j)
}
$gcAuditAgents = "# A`n`n- **Test (감사)**: ``cargo test --lib -- doc_audit`` · 증가: ``^\s*pub(\([^)]*\))?\s+((async|unsafe|const|extern)\s+)*(fn|struct|enum|trait|const|static|type|mod|union)\b`` · 경로: ``*.rs```n"
$gcAudit = New-GcRepo 'audit' @{ 'Cargo.toml' = "[package]`nname = `"a`"`npublish = false`n"; 'src/lib.rs' = ''; 'src/q.rs' = "pub enum FollowUp {}`n"; 'AGENTS.md' = $gcAuditAgents }
$gcApp = New-GcRepo 'app' @{ 'Cargo.toml' = "[package]`nname = `"b`"`npublish = false`n"; 'src/lib.rs' = ''; 'src/x.rs' = "pub fn run() {}`n" }
$gcLib = New-GcRepo 'lib' @{ 'Cargo.toml' = "[package]`nname = `"c`"`n[lib]`n"; 'src/lib.rs' = "pub fn api() {}`nfn inner() {}`npub(crate) fn mid() {}`n"; 'docs/x.md' = '문서' }
$gcTs = New-GcRepo 'tslib' @{ 'package.json' = '{ "name": "t" }'; 'index.ts' = "export function f() {}`n" }
$gcCs = New-GcRepo 'cslib' @{ 'L.csproj' = '<Project><PropertyGroup><OutputType>Library</OutputType></PropertyGroup></Project>'; 'A.cs' = "public class A {}`n" }
$gcWt = New-GcRepo 'wt' @{ 'docs/rule.md' = '규칙'; 'tool.ps1' = "`$x = 1`n" } -GitFile
$gcKeep = New-GcRepo 'keep' @{ 'AGENTS.md' = "# K`n`n- **Comment (보존)**: ``.`` · 경로: ``scripts/head.ps1```n"; 'scripts/head.ps1' = "`$h = 1`n"; 'scripts/other.ps1' = "`$o = 1`n" }
$gcOld = Join-Path $gc 'olddoc.rs'
[System.IO.File]::WriteAllText($gcOld, "/// 옛 설명`nfn o() {}`n", [System.Text.UTF8Encoding]::new($false))

$r = Invoke-GcEdit 'retry2.rs' 'fn a() {}' "// 섹션의 첫 행인가`nfn a() {}" 'gc-retry2'
$r = Invoke-GcEdit 'retry2.rs' 'fn a() {}' "// 섹션의 첫 행인가`nfn a() {}" 'gc-retry2'
Assert-Case -Name "guard-comment: 같은 편집 두 번째도 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEditAt (Join-Path $gcAudit 'src/q.rs') 'pub enum FollowUp {}' "/// 작업 중 보낸 메시지가 가는 곳.`n#[derive(Clone)]`npub enum FollowUp {}"
Assert-Case -Name "guard-comment: 감사 레포 pub enum 위 /// 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-GcEditAt (Join-Path $gcLib 'src/lib.rs') 'pub fn api() {}' "/// 공개 계약.`npub fn api() {}"
Assert-Case -Name "guard-comment: 라이브러리 크레이트 pub fn 위 /// 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-GcEditAt (Join-Path $gcTs 'index.ts') 'export function f() {}' "/**`n * 공개 함수.`n */`nexport function f() {}"
Assert-Case -Name "guard-comment: export 위 /** */ 통과(private 아닌 package.json)" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-GcEditAt (Join-Path $gcCs 'A.cs') 'public class A {}' "/// <summary>공개 형식.</summary>`npublic class A {}"
Assert-Case -Name "guard-comment: .csproj 라이브러리 public 위 /// 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-GcEditAt (Join-Path $gcLib 'src/lib.rs') 'fn inner() {}' "// 근거는 ``docs/x.md```nfn inner() {}"
Assert-Case -Name "guard-comment: 실재 .md 경로 포인터 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-GcEditAt (Join-Path $gcWt 'tool.ps1') '$x = 1' "# 근거는 ``docs/rule.md```n`$x = 1"
Assert-Case -Name "guard-comment: worktree(.git 파일) 레포의 실재 경로 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-GcEdit 'issue.ts' 'g();' "// https://github.com/o/r/issues/12`ng();"
Assert-Case -Name "guard-comment: /issues/12 URL 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-GcEdit 'tracker.cs' 'int t;' "// PROJ-123 벤더 버그 회피`nint t;"
Assert-Case -Name "guard-comment: PROJ-123 트래커 키 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-GcEditAt (Join-Path $gcApp 'src/x.rs') 'pub fn run() {}' "/// 실행 진입점.`npub fn run() {}" 'gc-app2'
$r = Invoke-GcEditAt (Join-Path $gcApp 'src/x.rs') 'pub fn run() {}' "/// 실행 진입점.`npub fn run() {}" 'gc-app2'
Assert-Case -Name "guard-comment: publish=false·감사 없음 레포 pub fn 위 /// 두 번째도 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEditAt (Join-Path $gcLib 'src/lib.rs') 'fn inner() {}' "/// 내부 함수.`nfn inner() {}" 'gc-priv2'
$r = Invoke-GcEditAt (Join-Path $gcLib 'src/lib.rs') 'fn inner() {}' "/// 내부 함수.`nfn inner() {}" 'gc-priv2'
Assert-Case -Name "guard-comment: 라이브러리 비공개 fn 위 /// 두 번째도 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$gcMultiLib = @(@{ old_string = 'fn inner() {}'; new_string = 'pub fn inner() {}' }, @{ old_string = 'pub fn inner() {}'; new_string = "/// 이제 공개.`npub fn inner() {}" })
$r = Invoke-Hook 'guard-harness.ps1' (@{ session_id = 'gc-mlib'; tool_name = 'MultiEdit'; cwd = $gcLib; tool_input = @{ file_path = (Join-Path $gcLib 'src/lib.rs'); edits = $gcMultiLib } } | ConvertTo-Json -Compress -Depth 5)
Assert-Case -Name "guard-comment: MultiEdit 뒤쪽 쌍의 doc 이 앞쪽 쌍 적용 뒤 pub 항목이면 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-GcEditAt $gcOld "/// 옛 설명`nfn o() {}" "/// 새로 고친 설명`nfn o() {}"
Assert-Case -Name "guard-comment: 기존 doc 주석 문구만 고친 Edit 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-GcEditAt (Join-Path $gcKeep 'scripts/head.ps1') '$h = 1' "# 정본 머리 표`n`$h = 1"
Assert-Case -Name "guard-comment: AGENTS.md Comment (보존) 경로·정규식에 맞는 주석 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

$r = Invoke-GcEdit 'src.ts' 'h();' "// 출처 https://example.com/blog/post`nh();"
Assert-Case -Name "guard-comment: 출처 URL 만 든 줄 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'utf.cs' 'int u;' "// UTF-8 로 읽는다`nint u;"
Assert-Case -Name "guard-comment: // UTF-8 로 읽는다 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'step.ts' 'k();' "// T1-2 단계`nk();"
Assert-Case -Name "guard-comment: // T1-2 단계 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'color.ts' 'm();' "// #000 색`nm();"
Assert-Case -Name "guard-comment: // #000 색 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEditAt (Join-Path $gcLib 'src/lib.rs') 'fn inner() {}' "// 근거는 ``docs/none.md```nfn inner() {}"
Assert-Case -Name "guard-comment: 없는 .md 경로 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'todo.ts' 'n();' "// TODO(#12) https://github.com/o/r/issues/12`nn();"
Assert-Case -Name "guard-comment: 링크가 든 TODO 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'next.ts' 'p();' "// https://github.com/o/r/issues/3`n// 그래서 이렇게 한다`np();"
Assert-Case -Name "guard-comment: 링크 줄 다음의 링크 없는 줄 차단" -R $r -ExpectExit 2 -ExpectContains '주석 1줄'
$r = Invoke-GcEditAt (Join-Path $gcLib 'src/lib.rs') 'pub(crate) fn mid() {}' "/// 크레이트 안 공개.`npub(crate) fn mid() {}"
Assert-Case -Name "guard-comment: pub(crate) fn 위 /// 차단(라이브러리·감사 없음)" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'cnt.ts' 'q();' "// 이슈 2개면 나눈다`nq();"
Assert-Case -Name "guard-comment: // 이슈 2개면 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'pr.ts' 's();' "// PR 2건 이상이면 묶는다`ns();"
Assert-Case -Name "guard-comment: // PR 2건 이상 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$gcNoRoot = Join-Path $gc 'noroot'; New-Item -ItemType Directory -Force -Path $gcNoRoot | Out-Null
[System.IO.File]::WriteAllText((Join-Path $gcNoRoot 'Cargo.toml'), "[package]`nname = `"n`"`n[lib]`n")
$r = Invoke-GcEditAt (Join-Path (Join-Path $gcNoRoot 'src') 'm.rs') 'pub fn z() {}' "/// 루트 없음.`npub fn z() {}"
Assert-Case -Name "guard-comment: 레포 루트(.git) 없는 폴더의 pub fn 위 /// 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEditAt $gcOld "/// 옛 설명`nfn o() {}" "/// 옛 설명`n/// 늘어난 설명`nfn o() {}"
Assert-Case -Name "guard-comment: 기존 주석 1줄을 2줄로 늘린 Edit 은 늘어난 1줄 차단" -R $r -ExpectExit 2 -ExpectContains '주석 1줄'
$r = Invoke-GcEditAt (Join-Path $gcKeep 'scripts/other.ps1') '$o = 1' "# 정본 머리 표`n`$o = 1"
Assert-Case -Name "guard-comment: Comment (보존) 경로 밖 파일의 같은 주석 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock

$r = Invoke-Hook 'guard-harness.ps1' 'not json'
Assert-Case -Name "guard-comment: 깨진 stdin 은 exit 0 무출력" -R $r -ExpectExit 0 -ExpectSilent $true

$gcHooks = Get-Content -LiteralPath (Join-Path $pluginRoot 'hooks/hooks.json') -Raw | ConvertFrom-Json
$gcOwn = @($gcHooks.hooks.PreToolUse | Where-Object { @($_.hooks | Where-Object { $_.command -match 'guard-comment\.ps1' }).Count -gt 0 }).Count
$gcHost = @($gcHooks.hooks.PreToolUse | Where-Object { @($_.hooks | Where-Object { $_.command -match 'guard-harness\.ps1' }).Count -gt 0 } | ForEach-Object { $_.matcher })
Assert-Case -Name "guard-comment: 별도 hook 없이 guard-harness(Write·Edit·MultiEdit) 안에서 돈다" -R @{ code = 0; out = "own=$gcOwn host=$($gcHost -join ',')" } -ExpectExit 0 -ExpectContains 'own=0 host=Write|Edit|MultiEdit|NotebookEdit'
$r = Invoke-Hook 'guard-harness.ps1' (@{ session_id = 'gc-nb'; tool_name = 'NotebookEdit'; cwd = $gc; tool_input = @{ notebook_path = (Join-Path $gc 'nb.py'); new_source = "# 셀 설명`nx = 1" } } | ConvertTo-Json -Compress -Depth 5)
Assert-Case -Name "guard-comment: NotebookEdit 는 검사하지 않는다" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'

}
