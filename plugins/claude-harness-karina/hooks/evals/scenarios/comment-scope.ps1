if (Test-HookSelected @('comment-scope')) {

$csPath = Join-Path $pluginRoot 'skills/no-comments/scripts/comment-scope.ps1'
$csRoot = Join-Path $work 'comment-scope'
New-Item -ItemType Directory -Path $csRoot -Force | Out-Null
$csUtf8 = [System.Text.UTF8Encoding]::new($false)

function Set-CsFile([string]$Repo, [string]$Rel, [string]$Text) {
    $p = Join-Path $Repo $Rel
    $d = Split-Path -Parent $p
    if (-not (Test-Path -LiteralPath $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
    [System.IO.File]::WriteAllText($p, $Text, $script:csUtf8)
}
function New-CsRepo([string]$Name) {
    $r = Join-Path $script:csRoot $Name
    New-Item -ItemType Directory -Path $r -Force | Out-Null
    git -C $r init -q; git -C $r config user.email t@t; git -C $r config user.name t; git -C $r config core.autocrlf false
    return $r
}
function Invoke-Cs([string[]]$CsArgs, [string]$Exe = 'pwsh') {
    $out = & $Exe -NoProfile -ExecutionPolicy Bypass -File $script:csPath @CsArgs 2>&1
    return @{ code = $LASTEXITCODE; out = ($out -join "`n") }
}

if ($gitOk) {

$sr = New-CsRepo 'scope'
Set-CsFile $sr 'AGENTS.md' "# AGENTS`n`n- **Test (감사)**: ``cargo test`` · 증가: ``^pub fn\b`` · 경로: ``*.rs```n- **Comment (보존)**: ``보존 표식`` · 경로: ``*.rs```n"
Set-CsFile $sr 'src/a.rs' "// 회차 전 설명.`nfn keep() {}`nfn target() {}`n// 짧은 주석.`nfn moved() {}`n/// 고칠 문구.`nfn reword() {}`n"
Set-CsFile $sr 'src/old.rs' "// 옮긴 파일 주석.`nfn o() {}`n"
Set-CsFile $sr 'doc.md' "# doc`n"
git -C $sr add .; git -C $sr commit -qm base
$srBase = (git -C $sr rev-parse HEAD).Trim()
git -C $sr mv src/old.rs src/new_name.rs
Set-CsFile $sr 'src/a.rs' "// 짧은 주석.`nfn moved() {}`n// 회차 전 설명.`n// 회차 새 설명.`nfn keep() {}`nfn target() {}`n/// 고친 문구.`nfn reword() {}`n/// 감사 대상 doc.`npub fn audited() {}`n/// 감사 밖 doc.`nfn private_doc() {}`n// 보존 표식 줄`nfn kept() {}`n"
Set-CsFile $sr 'src/b.ts' "// eslint-disable-next-line no-console`nconsole.log(1);`n"
Set-CsFile $sr 'doc.md' "# doc`n<!-- 문서 주석 -->`n"
git -C $sr add .; git -C $sr commit -qm round
Set-CsFile $sr 'src/c.rs' "// 미추적 주석.`nfn c() {}`n"
$srA = Get-Content -LiteralPath (Join-Path $sr 'src/a.rs') -Raw
Set-CsFile $sr 'src/a.rs' ("// 미커밋 주석.`n" + $srA)

$srOut = Join-Path $csRoot 'scope-out.txt'
$r = Invoke-Cs @('-Base', $srBase, '-Out', $srOut, '-Repo', $sr)
$listed = if (Test-Path -LiteralPath $srOut) { [System.IO.File]::ReadAllText($srOut) } else { '' }
$sl = @{ code = $r.code; out = ($r.out + "`n" + $listed) }
Assert-Case -Name "comment-scope: 회차 커밋이 더한 주석은 목록에 든다" -R $sl -ExpectExit 0 -ExpectContains "src/a.rs:4`t// 회차 새 설명."
Assert-Case -Name "comment-scope: 같은 hunk 문맥의 회차 전 주석은 뺀다" -R $sl -ExpectExit 0 -ExpectNotContains '// 회차 전 설명.'
Assert-Case -Name "comment-scope: 파일 안에서 옮기기만 한 짧은 한글 회차 전 주석은 뺀다" -R $sl -ExpectExit 0 -ExpectNotContains '// 짧은 주석.'
Assert-Case -Name "comment-scope: 이름을 바꾼 파일의 회차 전 주석은 뺀다" -R $sl -ExpectExit 0 -ExpectNotContains '// 옮긴 파일 주석.'
Assert-Case -Name "comment-scope: 회차가 문구만 고친 회차 전 주석은 목록에 든다" -R $sl -ExpectExit 0 -ExpectContains "src/a.rs:7`t/// 고친 문구."
Assert-Case -Name "comment-scope: Test (감사) 가 요구하는 doc 은 뺀다" -R $sl -ExpectExit 0 -ExpectNotContains '/// 감사 대상 doc.'
Assert-Case -Name "comment-scope: 감사 밖 doc 은 목록에 든다" -R $sl -ExpectExit 0 -ExpectContains "src/a.rs:11`t/// 감사 밖 doc."
Assert-Case -Name "comment-scope: Comment (보존) 선언에 맞는 주석은 뺀다" -R $sl -ExpectExit 0 -ExpectNotContains '// 보존 표식 줄'
Assert-Case -Name "comment-scope: 회차의 린트 억제 주석은 목록에 든다" -R $sl -ExpectExit 0 -ExpectContains "src/b.ts:1`t// eslint-disable-next-line no-console"
Assert-Case -Name "comment-scope: 주석 대상이 아닌 문서 파일은 보지 않는다" -R $sl -ExpectExit 0 -ExpectNotContains 'doc.md'
Assert-Case -Name "comment-scope: 미커밋·미추적 변경의 주석은 보지 않는다" -R $sl -ExpectExit 0 -ExpectNotContains '미커밋 주석'
Assert-Case -Name "comment-scope: 미추적 파일의 주석도 보지 않는다" -R $sl -ExpectExit 0 -ExpectNotContains '미추적 주석'
Assert-Case -Name "comment-scope: 끝 줄에 대상·회차 전·감사·보존 수를 낸다" -R $sl -ExpectExit 0 -ExpectContains 'RESULT: 대상 4 · 회차 전 3 · 감사 1 · 보존 1'

$srEmpty = Join-Path $csRoot 'scope-empty.txt'
$r = Invoke-Cs @('-Base', 'HEAD', '-Out', $srEmpty, '-Repo', $sr)
$emptyText = if (Test-Path -LiteralPath $srEmpty) { 'len=' + ([System.IO.File]::ReadAllText($srEmpty)).Length } else { 'missing' }
Assert-Case -Name "comment-scope: 범위가 비면 빈 목록과 대상 0 을 낸다" -R @{ code = $r.code; out = ($r.out + "`n" + $emptyText) } -ExpectExit 0 -ExpectContains 'RESULT: 대상 0'
Assert-Case -Name "comment-scope: 범위가 비면 목록 파일은 빈 파일이다" -R @{ code = $r.code; out = $emptyText } -ExpectExit 0 -ExpectContains 'len=0'

$r = Invoke-Cs @('-Base', '0123456789abcdef0123456789abcdef01234567', '-Out', $srOut, '-Repo', $sr)
Assert-Case -Name "comment-scope: 레포에 없는 BASE 는 거절한다" -R $r -ExpectExit 2 -ExpectContains 'comment-scope: BASE 를 찾을 수 없습니다'
$r = Invoke-Cs @('-Base', $srBase, '-Out', $srOut, '-Repo', $csRoot)
Assert-Case -Name "comment-scope: git 레포 밖은 거절한다" -R $r -ExpectExit 2 -ExpectContains 'comment-scope: git 레포가 아닙니다'

$csWinPs = Get-Command powershell.exe -ErrorAction SilentlyContinue
if ($csWinPs) {
    $r = Invoke-Cs @('-Base', $srBase, '-Out', $srOut, '-Repo', $sr) 'powershell.exe'
    Assert-Case -Name "comment-scope: PowerShell 5.1 로 부르면 거절한다" -R $r -ExpectExit 2 -ExpectContains 'comment-scope: PowerShell 7 이상이 필요합니다'
} else {
    Assert-Case -Name "comment-scope: PowerShell 5.1 로 부르면 거절한다" -R @{ code = 99; out = 'powershell.exe not found' } -ExpectExit 2 -ExpectContains 'comment-scope: PowerShell 7 이상이 필요합니다'
}

$csLib = Join-Path $pluginRoot 'scripts/comment-lines.ps1'
$out = & pwsh -NoProfile -Command ". '$csLib'; `$a = Get-CommentBodyLines 'x.ts' @('// eslint-disable-next-line no-console', 'x();'); `$b = Get-CommentBodyLines 'x.ts' @('// eslint-disable-next-line no-console', 'x();') -KeepDirectives; ""gate=`$(`$a.Count) keep=`$(`$b.Count)""" 2>&1
Assert-Case -Name "comment-scope: 게이트 판별은 스위치 없이 억제 지시문을 계속 건너뛴다" -R @{ code = $LASTEXITCODE; out = ($out -join "`n") } -ExpectExit 0 -ExpectContains 'gate=0 keep=1'

}

}
