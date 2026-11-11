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
Assert-Case -Name "guard-comment: 차단 사유가 낡은 옛 주석을 고치거나 지우라고 안내한다" -R $r -ExpectExit 2 -ExpectContains '새 주석만 빼고 낡은 주석을 남기지 마세요'

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
$r = Invoke-GcEdit 'mod.psm1' '$m = 1' "# 설명`n`$m = 1"
Assert-Case -Name "guard-comment: .psm1 # 주석 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'man.psd1' '@{ A = 1 }' "<# 첫 줄`n 둘째 줄`n 셋째 줄 #>`n@{ A = 1 }"
Assert-Case -Name "guard-comment: .psd1 <# #> 블록은 블록 안 줄까지 센다" -R $r -ExpectExit 2 -ExpectContains '주석 3줄'
$r = Invoke-GcEdit 'conf.yaml' 'a: 1' "# 설명`na: 1"
Assert-Case -Name "guard-comment: .yaml # 주석 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'ci.yml' 'on: push' "# 설명`non: push"
Assert-Case -Name "guard-comment: .yml # 주석 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'cfg.toml' 'a = 1' "# 설명`na = 1"
Assert-Case -Name "guard-comment: .toml # 주석 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'lint.yaml' 'b: 1' "# yamllint 규칙은 느슨하게 둔다`nb: 1"
Assert-Case -Name "guard-comment: .yaml 의 yamllint 로 시작하는 일반 주석은 지시문이 아니다" -R $r -ExpectExit 2 -ExpectContains $gcBlock
$r = Invoke-GcEdit 'ps_directive.psm1' '$z = 0' "#Requires -Version 7`n#region Helpers`n#endregion`n`$z = 0"
Assert-Case -Name "guard-comment: .psm1 의 #Requires·#region 지시문은 통과" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-GcWrite (Join-Path $gc 'lic.yaml') "# SPDX-License-Identifier: MIT`nc: 1"
Assert-Case -Name "guard-comment: .yaml 라이선스 줄만 있는 Write 는 통과" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-GcEdit 'color.toml' 'a = 1' "a = 1`ncolor = `"#000`""
Assert-Case -Name "guard-comment: .toml 문자열 속 # 은 주석이 아니다" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-GcWrite (Join-Path $gc 'cloud.yaml') "#cloud-config`n# yaml-language-server: `$schema=./s.json`n# yamllint disable-line rule:line-length`n# yamllint enable`nd: 1"
Assert-Case -Name "guard-comment: .yaml 의 cloud-config·yaml-language-server·yamllint 지시문은 통과" -R $r -ExpectExit 0 -ExpectSilent $true
$r = Invoke-GcWrite (Join-Path $gc 'schema.toml') "#:schema ./s.json`ne = 1"
Assert-Case -Name "guard-comment: .toml 의 #:schema 지시문은 통과" -R $r -ExpectExit 0 -ExpectSilent $true
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
[System.IO.File]::WriteAllText((Join-Path $gcAudit 'src/h.rs'), "fn helper() {}`n")
$r = Invoke-GcEditAt (Join-Path $gcAudit 'src/h.rs') 'fn helper() {}' "/// 감사 대상이 아닌 비공개 함수.`nfn helper() {}"
Assert-Case -Name "guard-comment: 감사 레포 비공개 fn 위 /// 차단" -R $r -ExpectExit 2 -ExpectContains '주석 1줄'
[System.IO.File]::WriteAllText((Join-Path $gcAudit 'src/dup.rs'), "/// # Errors`npub fn a() {}`nfn helper() {}`n")
$r = Invoke-GcEditAt (Join-Path $gcAudit 'src/dup.rs') 'fn helper() {}' "/// # Errors`nfn helper() {}"
Assert-Case -Name "guard-comment: 같은 문구 사본: 비공개 fn 위 /// 차단(첫 사본은 pub fn 위)" -R $r -ExpectExit 2 -ExpectContains $gcBlock
[System.IO.File]::WriteAllText((Join-Path $gcAudit 'src/dup2.rs'), "/// 내부 설명`nfn first() {}`npub fn api() {}`n")
$r = Invoke-GcEditAt (Join-Path $gcAudit 'src/dup2.rs') 'pub fn api() {}' "/// 내부 설명`npub fn api() {}"
Assert-Case -Name "guard-comment: 같은 문구 사본: pub fn 위 /// 통과(첫 사본은 비공개 fn 위)" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
[System.IO.File]::WriteAllText((Join-Path $gcAudit 'src/attr.rs'), "pub struct S;`n")
$r = Invoke-GcEditAt (Join-Path $gcAudit 'src/attr.rs') 'pub struct S;' "/// 계약.`n#[derive(`n    Debug,`n)]`npub struct S;"
Assert-Case -Name "guard-comment: 여러 줄 속성 #[derive(…)] 뒤 pub struct 위 /// 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
[System.IO.File]::WriteAllText((Join-Path $gcAudit 'src/attr1.rs'), "pub struct T;`n")
$r = Invoke-GcEditAt (Join-Path $gcAudit 'src/attr1.rs') 'pub struct T;' "/// 계약.`n#[derive(Debug)]`npub struct T;"
Assert-Case -Name "guard-comment: 단일 줄 속성 뒤 pub struct 위 /// 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
[System.IO.File]::WriteAllText((Join-Path $gcAudit 'src/multi.rs'), "/// 표지`nfn first() {}`nfn gap() {}`npub fn api() {}`n")
$gcMultiDup = @(@{ old_string = 'fn gap() {}'; new_string = "fn gap() {}`nfn gap2() {}" }, @{ old_string = 'pub fn api() {}'; new_string = "/// 표지`npub fn api() {}" })
$r = Invoke-Hook 'guard-harness.ps1' (@{ session_id = 'gc-mdup'; tool_name = 'MultiEdit'; cwd = $gcAudit; tool_input = @{ file_path = (Join-Path $gcAudit 'src/multi.rs'); edits = $gcMultiDup } } | ConvertTo-Json -Compress -Depth 5)
Assert-Case -Name "guard-comment: MultiEdit: 첫 사본은 비공개 fn 위인 파일에서 앞 쌍이 위쪽 줄 수를 늘린 뒤 뒤 쌍이 pub fn 위에 단 /// 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
[System.IO.File]::WriteAllText((Join-Path $gcAudit 'src/ra.rs'), "#[x]`npub fn a() {}`n#[x]`nfn b() {}`n")
$r = Invoke-Hook 'guard-harness.ps1' (@{ session_id = 'gc-ra'; tool_name = 'Edit'; cwd = $gcAudit; tool_input = @{ file_path = (Join-Path $gcAudit 'src/ra.rs'); old_string = '#[x]'; new_string = "/// 표시`n#[x]"; replace_all = $true } } | ConvertTo-Json -Compress -Depth 5)
Assert-Case -Name "guard-comment: replace_all: 같은 쌍이 pub fn(위쪽)과 비공개 fn(아래쪽) 두 자리에 /// 를 넣으면 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
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

$gcRwBase = "fn c() {`n    /// 아틀라스에서 그림을 내리지 않는다.`n    let x = 1;`n}`n"
$gcRwFixed = "fn c() {`n    /// 아틀라스에서 그림을 직접 내리지 않는다.`n    let x = 1;`n}`n"
foreach ($n in @('rw_a.rs', 'rw_b.rs', 'rw_c.rs')) { [System.IO.File]::WriteAllText((Join-Path $gcLib "src/$n"), $gcRwBase, [System.Text.UTF8Encoding]::new($false)) }
$r = Invoke-GcWrite (Join-Path $gcLib 'src/rw_a.rs') ("/// 썸네일을 칠하는 설정 창.`npub fn bind() {}`n" + $gcRwFixed)
Assert-Case -Name "guard-comment: Write 의 새 pub doc(앞) + 다른 자리 doc 문구 수정(뒤)은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-GcWrite (Join-Path $gcLib 'src/rw_b.rs') ("/// 내부 도우미 설명.`nfn helper() {}`n" + $gcRwFixed)
Assert-Case -Name "guard-comment: Write 의 새 비공개 doc(앞) + 문구 수정(뒤)은 새 doc 을 막는다" -R $r -ExpectExit 2 -ExpectContains '내부 도우미 설명' -ExpectNotContains '직접 내리지'
$r = Invoke-GcEditAt (Join-Path $gcLib 'src/rw_c.rs') "fn c() {`n    /// 아틀라스에서 그림을 내리지 않는다." "/// 썸네일을 칠하는 설정 창.`npub fn bind() {}`nfn c() {`n    /// 아틀라스에서 그림을 직접 내리지 않는다."
Assert-Case -Name "guard-comment: Edit 한 쌍의 새 pub doc(앞) + 문구 수정(뒤)은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
[System.IO.File]::WriteAllText((Join-Path $gcLib 'src/rw_f.rs'), "/// 공개 진입점을 연다.`npub fn open() {}`n", [System.Text.UTF8Encoding]::new($false))
$r = Invoke-GcWrite (Join-Path $gcLib 'src/rw_f.rs') "/// 내부 도우미 설명.`nfn helper() {}`n/// 공개 진입점을 바로 연다.`npub fn open() {}`n"
Assert-Case -Name "guard-comment: Write 의 새 비공개 doc(앞) + pub 위 doc 문구 수정(뒤)은 새 doc 을 막는다" -R $r -ExpectExit 2 -ExpectContains '내부 도우미 설명' -ExpectNotContains '바로 연다'
[System.IO.File]::WriteAllText((Join-Path $gc 'rw_e.rs'), $gcRwBase, [System.Text.UTF8Encoding]::new($false))
$r = Invoke-GcEdit 'rw_e.rs' '    /// 아틀라스에서 그림을 내리지 않는다.' '    /// cache refill on miss'
Assert-Case -Name "guard-comment: 주석 1줄을 닮지 않은 주석 1줄로 바꾼 Edit 은 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
[System.IO.File]::WriteAllText((Join-Path $gc 'rw_g.rs'), $gcRwBase, [System.Text.UTF8Encoding]::new($false))
$r = Invoke-GcEdit 'rw_g.rs' "    /// 아틀라스에서 그림을 내리지 않는다.`n    let x = 1;" "    // qqq zzz`n    // www vvv`n    let x = 1;"
Assert-Case -Name "guard-comment: 닮은 줄이 없으면 문구 수정 몫은 앞 줄에 쓰여 뒷 줄을 막는다" -R $r -ExpectExit 2 -ExpectContains 'www vvv' -ExpectNotContains 'qqq zzz'
$gcBigOld = (1..45 | ForEach-Object { "// 원래 설명 #$_ 렌더러 아틀라스`nint a$_;" }) -join "`n"
$gcBigNew = "// qqq xxx zzz`n" + ((1..45 | ForEach-Object { "// 고친 설명 #$_ 렌더러 아틀라스`nint a$_;" }) -join "`n")
[System.IO.File]::WriteAllText((Join-Path $gc 'rw_h.cs'), $gcBigOld, [System.Text.UTF8Encoding]::new($false))
$r = Invoke-GcWrite (Join-Path $gc 'rw_h.cs') $gcBigNew
Assert-Case -Name "guard-comment: 유사도 예산을 넘는 전면 재작성은 순서대로 봐주고 마지막 줄을 막는다" -R $r -ExpectExit 2 -ExpectContains '#45 렌더러' -ExpectNotContains 'qqq xxx'
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

if ($gitOk) {
$gb = Join-Path $gc 'basegit'; New-Item -ItemType Directory -Force -Path (Join-Path $gb 'src') | Out-Null
$gbFile = Join-Path $gb 'src/e.rs'
[System.IO.File]::WriteAllText($gbFile, "/// 화면에 보이는 줄 범위를 센다.`nfn rows() {}`n", [System.Text.UTF8Encoding]::new($false))
git -C $gb init -q; git -C $gb config user.email t@t; git -C $gb config user.name t; git -C $gb config core.autocrlf false
git -C $gb add .; git -C $gb commit -qm base
$gbBase = (git -C $gb rev-parse --short HEAD).Trim()
[System.IO.File]::WriteAllText($gbFile, "fn rows() {}`n", [System.Text.UTF8Encoding]::new($false))
git -C $gb commit -qam drop
$gbPlan = Join-Path $gb 'plan.md'
function Set-GbPlan([string]$Head) { [System.IO.File]::WriteAllText($gbPlan, "# plan`n`n## Goal`n`n$Head`n", [System.Text.UTF8Encoding]::new($false)) }
$gbRestore = "/// 화면에 보이는 줄 범위를 센다.`nfn rows() {}"

Set-GbPlan "> BASE: $gbBase`n> 승인: 2026-11-05 · 화면 Y"
$r = Invoke-GcEditAt $gbFile 'fn rows() {}' $gbRestore
Assert-Case -Name "guard-comment: plan BASE 에 있던 비공개 fn doc 을 되살리는 Edit 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
Set-GbPlan "> BASE: $gbBase`n> 승인: 2026-11-05 · 화면 Y`n> 완료: 2026-11-05 10:00 · 소요 1시간"
$r = Invoke-GcEditAt $gbFile 'fn rows() {}' $gbRestore
Assert-Case -Name "guard-comment: 완료 기록이 있는 plan 의 BASE doc 복원도 통과" -R $r -ExpectExit 0 -ExpectNotContains 'BLOCKED'
$r = Invoke-GcEditAt $gbFile 'fn rows() {}' "/// BASE 에 없던 새 설명.`nfn rows() {}"
Assert-Case -Name "guard-comment: plan BASE 에 없던 doc 은 같은 레포에서도 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
Set-GbPlan '> BASE: <승인 시점 HEAD 의 SHA>'
$r = Invoke-GcEditAt $gbFile 'fn rows() {}' $gbRestore
Assert-Case -Name "guard-comment: BASE 가 자리표시인 plan 이면 복원 Edit 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
Set-GbPlan '> BASE: 0123456789abcdef0123'
$r = Invoke-GcEditAt $gbFile 'fn rows() {}' $gbRestore
Assert-Case -Name "guard-comment: 레포에 없는 BASE 면 복원 Edit 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
Set-GbPlan "> BASE: $gbBase`n> 승인: 2026-11-05 · 화면 Y"
$gbBudgetScript = Join-Path $gc 'base-budget.ps1'
[System.IO.File]::WriteAllText($gbBudgetScript, @'
param([string]$Lib, [string]$File, [int]$Ms, [int]$SleepMs)
. $Lib
$script:CommentBaseBudgetMs = $Ms
$budget = New-CommentBaseBudget
Start-Sleep -Milliseconds $SleepMs
$body = '/// 화면에 보이는 줄 범위를 센다.'
$added = New-Object System.Collections.Generic.List[object]
$added.Add(@{ Body = $body; Pair = 0; Line = 0; Indexes = @(0) })
$blocked = Get-BlockedCommentBodies $File $added @($body, 'fn rows() {}') $budget
"blocked=$($blocked.Count)"
'@, [System.Text.UTF8Encoding]::new($true))
$gbLib = Join-Path $pluginRoot 'scripts/comment-lines.ps1'
$out = & pwsh -NoProfile -ExecutionPolicy Bypass -File $gbBudgetScript $gbLib $gbFile 3000 3300 2>&1
Assert-Case -Name "guard-comment: BASE 예산 — 판정 처리 시간이 예산을 넘어도 BASE 복원 doc 은 통과" -R @{ code = $LASTEXITCODE; out = ($out -join "`n") } -ExpectExit 0 -ExpectContains 'blocked=0'
$out = & pwsh -NoProfile -ExecutionPolicy Bypass -File $gbBudgetScript $gbLib $gbFile 0 0 2>&1
Assert-Case -Name "guard-comment: BASE 예산 — 예산이 바닥났으면 복원 doc 도 차단" -R @{ code = $LASTEXITCODE; out = ($out -join "`n") } -ExpectExit 0 -ExpectContains 'blocked=1'
[System.IO.File]::Delete($gbPlan)
$r = Invoke-GcEditAt $gbFile 'fn rows() {}' $gbRestore
Assert-Case -Name "guard-comment: plan.md 가 없으면 복원 Edit 차단" -R $r -ExpectExit 2 -ExpectContains $gcBlock
}

}
