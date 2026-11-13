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
Assert-Case -Name "comment-scope: 회차가 문구만 고친 회차 전 doc 은 doc 대상이 BASE 에 doc 을 가졌으면 뺀다" -R $sl -ExpectExit 0 -ExpectNotContains '/// 고친 문구.'
Assert-Case -Name "comment-scope: Test (감사) 가 요구하는 doc 은 뺀다" -R $sl -ExpectExit 0 -ExpectNotContains '/// 감사 대상 doc.'
Assert-Case -Name "comment-scope: 감사 밖 doc 은 목록에 든다" -R $sl -ExpectExit 0 -ExpectContains "src/a.rs:11`t/// 감사 밖 doc."
Assert-Case -Name "comment-scope: Comment (보존) 선언에 맞는 주석은 뺀다" -R $sl -ExpectExit 0 -ExpectNotContains '// 보존 표식 줄'
Assert-Case -Name "comment-scope: 회차의 린트 억제 주석은 목록에 든다" -R $sl -ExpectExit 0 -ExpectContains "src/b.ts:1`t// eslint-disable-next-line no-console"
Assert-Case -Name "comment-scope: 주석 대상이 아닌 문서 파일은 보지 않는다" -R $sl -ExpectExit 0 -ExpectNotContains 'doc.md'
Assert-Case -Name "comment-scope: 미커밋·미추적 변경의 주석은 보지 않는다" -R $sl -ExpectExit 0 -ExpectNotContains '미커밋 주석'
Assert-Case -Name "comment-scope: 미추적 파일의 주석도 보지 않는다" -R $sl -ExpectExit 0 -ExpectNotContains '미추적 주석'
Assert-Case -Name "comment-scope: 끝 줄에 대상·회차 전·감사·보존 수를 낸다" -R $sl -ExpectExit 0 -ExpectContains 'RESULT: 대상 3 · 회차 전 4 · 감사 1 · 보존 1'

$st = New-CsRepo 'scope-testdoc'
Set-CsFile $st 'AGENTS.md' "# AGENTS`n`n- **Test (감사)**: ``cargo test --lib -- test_doc_audit`` · 증가: ``^\s*#\[(tokio::)?test\]`` · 경로: ``*.rs```n"
Set-CsFile $st 'src/t.rs' "fn x() {}`n"
git -C $st add .; git -C $st commit -qm base
$stBase = (git -C $st rev-parse HEAD).Trim()
Set-CsFile $st 'src/t.rs' "fn x() {}`n/// 시험 설명.`n#[test]`nfn t_one() {}`n"
git -C $st add .; git -C $st commit -qm round
$stOut = Join-Path $csRoot 'scope-testdoc-out.txt'
$r = Invoke-Cs @('-Base', $stBase, '-Out', $stOut, '-Repo', $st)
$stListed = if (Test-Path -LiteralPath $stOut) { [System.IO.File]::ReadAllText($stOut) } else { '' }
$stl = @{ code = $r.code; out = ($r.out + "`n" + $stListed) }
Assert-Case -Name "comment-scope: 시험 doc 감사 선언 레포의 #[test] 위 doc 은 감사로 뺀다" -R $stl -ExpectExit 0 -ExpectNotContains '/// 시험 설명.'

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

$cr = New-CsRepo 'check'
Set-CsFile $cr 'a.rs' "fn a() {}`n// 회차 전 표식.`nfn b() {}`n// 섞임 전.`nfn c() {}`nfn d() {}`n// 아래 전.`nfn e() {}`n"
$crCs = [byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes("class A {`r`n// 회차 전 cs.`r`nint x;`r`n}`r`n")
[System.IO.File]::WriteAllBytes((Join-Path $cr 'w.cs'), $crCs)
Set-CsFile $cr 'm.rs' "// 코드 옆 전.`nfn m() {}`n"
Set-CsFile $cr 'u.rs' "// 사용자 전.`nfn u() {}`n"
git -C $cr add .; git -C $cr commit -qm base
$crBase = (git -C $cr rev-parse HEAD).Trim()
Set-CsFile $cr 'a.rs' "fn a() {}`n// 회차 전 표식.`nfn b() {}`n// 섞임 전.`n// 섞임 회차.`nfn c() {}`n// 회차 주석.`nfn d() {}`n// 아래 전.`nfn e() {}`n"
git -C $cr commit -qam round
Set-CsFile $cr 'u.rs' "fn u() {}`n"
$crSnap = Join-Path $csRoot 'check-snap.txt'
$r = Invoke-Cs @('-Snapshot', $crSnap, '-Repo', $cr)
$snapText = if (Test-Path -LiteralPath $crSnap) { [System.IO.File]::ReadAllText($crSnap) } else { 'missing' }
Assert-Case -Name "comment-scope: 스냅숏은 정리 전 미커밋 경로를 적는다" -R @{ code = $r.code; out = $snapText } -ExpectExit 0 -ExpectContains 'u.rs'
Set-CsFile $cr 'a.rs' "fn a() {}`nfn b() {}`nfn c() {}`nfn d() {}`nfn e() {}`n"
[System.IO.File]::WriteAllBytes((Join-Path $cr 'w.cs'), ([byte[]](0xEF, 0xBB, 0xBF) + [System.Text.Encoding]::UTF8.GetBytes("class A {`r`nint x;`r`n}`r`n")))
Set-CsFile $cr 'm.rs' "fn m2() {}`n"
$crBeforeA = [System.IO.File]::ReadAllText((Join-Path $cr 'a.rs'))

$r = Invoke-Cs @('-CheckDeletions', '-Base', $crBase, '-Before', $crSnap, '-Repo', $cr)
Assert-Case -Name "comment-scope: 회차 전 주석의 순수 삭제를 찾으면 exit 1 과 RESTORE 줄을 낸다" -R $r -ExpectExit 1 -ExpectContains "RESTORE a.rs:2`t// 회차 전 표식."
Assert-Case -Name "comment-scope: -Restore 없이는 파일을 바꾸지 않는다" -R @{ code = 0; out = ('same=' + ([System.IO.File]::ReadAllText((Join-Path $cr 'a.rs')) -eq $crBeforeA)) } -ExpectExit 0 -ExpectContains 'same=True'

$r = Invoke-Cs @('-CheckDeletions', '-Base', $crBase, '-Before', $crSnap, '-Repo', $cr, '-Restore')
Assert-Case -Name "comment-scope: 되살림·회차 삭제·건너뜀 수를 낸다" -R $r -ExpectExit 1 -ExpectContains 'RESULT: 되살림 4 · 회차 삭제 2 · 건너뜀 1'
$crA = [System.IO.File]::ReadAllText((Join-Path $cr 'a.rs'))
$crWant = "fn a() {}`n// 회차 전 표식.`nfn b() {}`n// 섞임 전.`nfn c() {}`nfn d() {}`n// 아래 전.`nfn e() {}`n"
Assert-Case -Name "comment-scope: 여러 hunk 의 회차 전 주석을 제자리에 되살린다" -R @{ code = 0; out = ('match=' + ($crA -eq $crWant)) } -ExpectExit 0 -ExpectContains 'match=True'
Assert-Case -Name "comment-scope: 한 hunk 에 섞이면 회차 전 주석만 되살린다" -R @{ code = 0; out = $crA } -ExpectExit 0 -ExpectNotContains '섞임 회차'
Assert-Case -Name "comment-scope: 회차 주석의 순수 삭제는 되살리지 않는다" -R @{ code = 0; out = $crA } -ExpectExit 0 -ExpectNotContains '// 회차 주석.'
$crCsNow = [System.IO.File]::ReadAllBytes((Join-Path $cr 'w.cs'))
Assert-Case -Name "comment-scope: CRLF·BOM 파일은 줄바꿈·BOM 을 지켜 되살린다" -R @{ code = 0; out = ('bytes=' + ([System.Convert]::ToBase64String($crCsNow) -eq [System.Convert]::ToBase64String($crCs))) } -ExpectExit 0 -ExpectContains 'bytes=True'
Assert-Case -Name "comment-scope: + 줄이 있는 hunk 는 건드리지 않는다" -R @{ code = 0; out = [System.IO.File]::ReadAllText((Join-Path $cr 'm.rs')) } -ExpectExit 0 -ExpectNotContains '코드 옆 전'
Assert-Case -Name "comment-scope: 정리 전부터 미커밋이던 파일은 건너뛴다" -R @{ code = 0; out = [System.IO.File]::ReadAllText((Join-Path $cr 'u.rs')) } -ExpectExit 0 -ExpectNotContains '사용자 전'
$crDiff = (git -C $cr diff -U0 HEAD -- a.rs w.cs) -join "`n"
Assert-Case -Name "comment-scope: 되살린 뒤 diff 에 회차 전 주석 삭제가 남지 않는다" -R @{ code = 0; out = $crDiff } -ExpectExit 0 -ExpectNotContains '전 표식'
$r = Invoke-Cs @('-CheckDeletions', '-Base', $crBase, '-Before', $crSnap, '-Repo', $cr)
Assert-Case -Name "comment-scope: 회차 주석 삭제만 남으면 exit 0" -R $r -ExpectExit 0 -ExpectContains 'RESULT: 되살림 0 · 회차 삭제 2 · 건너뜀 1'

$rr = New-CsRepo 'check-rename'
Set-CsFile $rr 'old.rs' "// 짧은.`nfn a() {}`nfn b() {}`nfn c() {}`n"
git -C $rr add .; git -C $rr commit -qm base
$rrBase = (git -C $rr rev-parse HEAD).Trim()
git -C $rr mv old.rs new.rs
Set-CsFile $rr 'new.rs' "fn a() {}`nfn b() {}`n// 짧은.`nfn c() {}`n"
git -C $rr add .; git -C $rr commit -qm round
$rrSnap = Join-Path $csRoot 'check-rename-snap.txt'
$null = Invoke-Cs @('-Snapshot', $rrSnap, '-Repo', $rr)
Set-CsFile $rr 'new.rs' "fn a() {}`nfn b() {}`nfn c() {}`n"
$r = Invoke-Cs @('-CheckDeletions', '-Base', $rrBase, '-Before', $rrSnap, '-Repo', $rr, '-Restore')
Assert-Case -Name "comment-scope: 이름을 바꾼 파일에서 지운 회차 전 짧은 주석도 옛 경로 BASE 본문으로 되살린다" -R $r -ExpectExit 1 -ExpectContains 'RESULT: 되살림 1 · 회차 삭제 0 · 건너뜀 0'

$dr = New-CsRepo 'docscope'
Set-CsFile $dr 'a.rs' "/// 옛 설명.`nfn old_doc() {}`nfn no_doc() {}`n/// 이름 바꿀 함수 설명.`nfn renamed_before() {}`n/// 시험 설명.`n#[test]`nfn t_case() {}`n"
git -C $dr add .; git -C $dr commit -qm base
$drBase = (git -C $dr rev-parse HEAD).Trim()
Set-CsFile $dr 'a.rs' "/// 옛 설명을 고침.`nfn old_doc() {}`n/// 새로 단 설명.`nfn no_doc() {}`n/// 이름 바꿀 함수 설명을 고침.`nfn renamed_after() {}`n/// 시험 설명을 고침.`n#[test]`nfn t_case() {}`n"
git -C $dr commit -qam round
$drOut = Join-Path $csRoot 'docscope-out.txt'
$r = Invoke-Cs @('-Base', $drBase, '-Out', $drOut, '-Repo', $dr)
$dl = @{ code = $r.code; out = ($r.out + "`n" + $(if (Test-Path -LiteralPath $drOut) { [System.IO.File]::ReadAllText($drOut) } else { '' })) }
Assert-Case -Name "comment-scope: doc 대상 — 기존 항목에 새로 단 doc 은 목록에 남는다" -R $dl -ExpectExit 0 -ExpectContains "a.rs:3`t/// 새로 단 설명."
Assert-Case -Name "comment-scope: doc 대상 — 이름을 바꾼 항목의 doc 은 목록에 남는다" -R $dl -ExpectExit 0 -ExpectContains "a.rs:5`t/// 이름 바꿀 함수 설명을 고침."
Assert-Case -Name "comment-scope: doc 대상 — doc 과 fn 사이에 #[test] 가 있어도 문구만 고친 시험 doc 은 뺀다" -R $dl -ExpectExit 0 -ExpectNotContains '시험 설명을 고침'
Assert-Case -Name "comment-scope: doc 대상 — 끝 줄 수" -R $dl -ExpectExit 0 -ExpectContains 'RESULT: 대상 2 · 회차 전 2 · 감사 0 · 보존 0'
$drSnap = Join-Path $csRoot 'docscope-snap.txt'
$null = Invoke-Cs @('-Snapshot', $drSnap, '-Repo', $dr)
Set-CsFile $dr 'a.rs' "fn old_doc() {}`nfn no_doc() {}`n/// 이름 바꿀 함수 설명을 고침.`nfn renamed_after() {}`n/// 시험 설명을 고침.`n#[test]`nfn t_case() {}`n"
$r = Invoke-Cs @('-CheckDeletions', '-Base', $drBase, '-Before', $drSnap, '-Repo', $dr, '-Restore')
Assert-Case -Name "comment-scope: doc 대상 — 문구만 고친 회차 전 doc 의 삭제는 되살린다" -R $r -ExpectExit 1 -ExpectContains "RESTORE a.rs:1`t/// 옛 설명을 고침."
Assert-Case -Name "comment-scope: doc 대상 — 새로 단 doc 의 삭제는 되살리지 않는다" -R $r -ExpectExit 1 -ExpectNotContains '새로 단 설명'
Assert-Case -Name "comment-scope: doc 대상 — 되살림·회차 삭제 수" -R $r -ExpectExit 1 -ExpectContains 'RESULT: 되살림 1 · 회차 삭제 1 · 건너뜀 0'
$drA = [System.IO.File]::ReadAllText((Join-Path $dr 'a.rs'))
Assert-Case -Name "comment-scope: doc 대상 — 되살린 doc 은 제자리에 있다" -R @{ code = 0; out = ('match=' + ($drA -eq "/// 옛 설명을 고침.`nfn old_doc() {}`nfn no_doc() {}`n/// 이름 바꿀 함수 설명을 고침.`nfn renamed_after() {}`n/// 시험 설명을 고침.`n#[test]`nfn t_case() {}`n")) } -ExpectExit 0 -ExpectContains 'match=True'

$mr = New-CsRepo 'many'
$mrNames = @(for ($i = 1; $i -le 50; $i++) { '{0}/f{1:D2}.rs' -f $(if ($i -le 25) { 'one' } else { 'two' }), $i })
foreach ($n in $mrNames) { Set-CsFile $mr $n "fn f() {}`n" }
Set-CsFile $mr 'two/AGENTS.md' "# AGENTS`n`n- **Comment (보존)**: ``f50`` · 경로: ``*.rs```n"
git -C $mr add .; git -C $mr commit -qm base
$mrBase = (git -C $mr rev-parse HEAD).Trim()
foreach ($n in $mrNames) { Set-CsFile $mr $n "// 회차 주석 $n`nfn f() {}`n" }
git -C $mr commit -qam round
$mrOut = Join-Path $csRoot 'many-out.txt'
$r = Invoke-Cs @('-Base', $mrBase, '-Out', $mrOut, '-Repo', $mr)
Assert-Case -Name "comment-scope: 창보다 많은 50파일·2폴더 — 끝 줄 수(폴더마다 다른 보존 규칙)" -R $r -ExpectExit 0 -ExpectContains 'RESULT: 대상 49 · 회차 전 0 · 감사 0 · 보존 1'
$mrWant = (@($mrNames | Where-Object { $_ -notmatch 'f50' } | ForEach-Object { "${_}:1`t// 회차 주석 $_" }) -join "`n") + "`n"
$mrGot = if (Test-Path -LiteralPath $mrOut) { [System.IO.File]::ReadAllText($mrOut) } else { '' }
Assert-Case -Name "comment-scope: 창보다 많은 50파일·2폴더 — 목록이 입력 순서 그대로다" -R @{ code = 0; out = ('match=' + ($mrGot -eq $mrWant)) } -ExpectExit 0 -ExpectContains 'match=True'

$br = New-CsRepo 'blockbody'
Set-CsFile $br 'a.rs' "fn a() -> i32 {`n    let x = 1;`n    x`n}`n"
Set-CsFile $br 'b.rs' "/**`n * old text here`n */`npub fn f() {}`n"
git -C $br add .; git -C $br commit -qm base
$brBase = (git -C $br rev-parse HEAD).Trim()
Set-CsFile $br 'a.rs' "fn a() -> i32 {`n    let x = 1;`n    x`n}`n/*`nlet x = 1;`n*/`n"
Set-CsFile $br 'b.rs' "/**`n * old text here`nmore words`n */`npub fn f() {}`n"
git -C $br commit -qam round
$brOut = Join-Path $csRoot 'blockbody-out.txt'
$r = Invoke-Cs @('-Base', $brBase, '-Out', $brOut, '-Repo', $br)
$brList = if (Test-Path -LiteralPath $brOut) { [System.IO.File]::ReadAllText($brOut) } else { '' }
Assert-Case -Name "comment-scope: 회차가 주석 블록으로 막은 BASE 코드 줄은 목록에 든다" -R @{ code = $r.code; out = $brList } -ExpectExit 0 -ExpectContains "a.rs:6`tlet x = 1;"
Assert-Case -Name "comment-scope: 회차 전 doc 블록 안에 * 없이 더한 줄은 doc 대상 대조로 뺀다" -R @{ code = $r.code; out = $brList } -ExpectExit 0 -ExpectNotContains 'more words'
Assert-Case -Name "comment-scope: 블록 본문 케이스 — 끝 줄 수" -R $r -ExpectExit 0 -ExpectContains 'RESULT: 대상 1 · 회차 전 2 · 감사 0 · 보존 0'
$brSnap = Join-Path $csRoot 'blockbody-snap.txt'
$null = Invoke-Cs @('-Snapshot', $brSnap, '-Repo', $br)
Set-CsFile $br 'a.rs' "fn a() -> i32 {`n    let x = 1;`n    x`n}`n"
$r = Invoke-Cs @('-CheckDeletions', '-Base', $brBase, '-Before', $brSnap, '-Repo', $br)
Assert-Case -Name "comment-scope: 회차가 막은 코드 줄 블록을 지운 것은 되살리지 않는다" -R $r -ExpectExit 0 -ExpectContains 'RESULT: 되살림 0 · 회차 삭제 1 · 건너뜀 0'

$nr = New-CsRepo 'noprefix'
git -C $nr config diff.noprefix true
git -C $nr config diff.mnemonicPrefix true
Set-CsFile $nr 'a.rs' "// 회차 전 표식.`nfn a() {}`n"
git -C $nr add .; git -C $nr commit -qm base
$nrBase = (git -C $nr rev-parse HEAD).Trim()
Set-CsFile $nr 'a.rs' "// 회차 전 표식.`n// 회차가 단 주석.`nfn a() {}`n"
git -C $nr commit -qam round
$nrOut = Join-Path $csRoot 'noprefix-out.txt'
$r = Invoke-Cs @('-Base', $nrBase, '-Out', $nrOut, '-Repo', $nr)
Assert-Case -Name "comment-scope: diff.noprefix·mnemonicPrefix 설정에서도 회차 주석을 목록에 낸다" -R $r -ExpectExit 0 -ExpectContains 'RESULT: 대상 1 · 회차 전 1'
$nrSnap = Join-Path $csRoot 'noprefix-snap.txt'
$null = Invoke-Cs @('-Snapshot', $nrSnap, '-Repo', $nr)
Set-CsFile $nr 'a.rs' "// 회차가 단 주석.`nfn a() {}`n"
$r = Invoke-Cs @('-CheckDeletions', '-Base', $nrBase, '-Before', $nrSnap, '-Repo', $nr)
Assert-Case -Name "comment-scope: diff.noprefix·mnemonicPrefix 설정에서도 회차 전 주석 삭제를 찾는다" -R $r -ExpectExit 1 -ExpectContains "RESTORE a.rs:1`t// 회차 전 표식."

}

}
