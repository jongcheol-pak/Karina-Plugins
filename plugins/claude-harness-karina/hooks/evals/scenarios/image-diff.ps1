if (Test-HookSelected @('image-diff')) {

Add-Type -AssemblyName System.Drawing
$idPath = Join-Path $pluginRoot 'skills/implement/scripts/image-diff.ps1'
$idDir = Join-Path $EvalWork 'image-diff'
New-Item -ItemType Directory -Path $idDir -Force | Out-Null

function New-IdPng([string]$Name, [int]$W, [int]$H, [object[]]$Red = @()) {
    $p = Join-Path $idDir $Name
    $bmp = [System.Drawing.Bitmap]::new($W, $H)
    try {
        $g = [System.Drawing.Graphics]::FromImage($bmp)
        $g.Clear([System.Drawing.Color]::White); $g.Dispose()
        foreach ($pt in $Red) { $bmp.SetPixel($pt[0], $pt[1], [System.Drawing.Color]::Red) }
        $bmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
    } finally { $bmp.Dispose() }
    return $p
}
function Invoke-ImageDiff([string[]]$IdArgs) {
    Assert-EvalParentAlive
    $out = pwsh -NoProfile -ExecutionPolicy Bypass -File $idPath @IdArgs 2>&1
    return @{ code = $LASTEXITCODE; out = (($out | Out-String)).Trim() }
}

$idBase = New-IdPng 'base.png' 20 10
$idSame = New-IdPng 'same.png' 20 10
$idOne = New-IdPng 'one.png' 20 10 @(, @(3, 4))
$idWide = New-IdPng 'wide.png' 21 10

$r = Invoke-ImageDiff @('-Base', $idBase, '-Head', $idSame)
Assert-Case -Name "image-diff: 같은 이미지는 diff 0 px · exit 0" -R $r -ExpectExit 0 -ExpectContains 'image-diff: diff 0 px of 20x10'
$r = Invoke-ImageDiff @('-Base', $idBase, '-Head', $idOne)
Assert-Case -Name "image-diff: 1픽셀 다르면 diff 1 px · exit 1" -R $r -ExpectExit 1 -ExpectContains 'image-diff: diff 1 px of 20x10'
$r = Invoke-ImageDiff @('-Base', $idBase, '-Head', $idOne, '-Mask', '2,3,3,3')
Assert-Case -Name "image-diff: 다른 픽셀이 가림 안에만 있으면 diff 0 px · exit 0" -R $r -ExpectExit 0 -ExpectContains 'diff 0 px of 20x10 masked 1 px'
$r = Invoke-ImageDiff @('-Base', $idBase, '-Head', $idOne, '-Mask', '10,0,5,5')
Assert-Case -Name "image-diff: 가림 밖의 다른 픽셀은 센다 · exit 1" -R $r -ExpectExit 1 -ExpectContains 'image-diff: diff 1 px of 20x10'
$r = Invoke-ImageDiff @('-Base', $idBase, '-Head', $idWide)
Assert-Case -Name "image-diff: 크기가 다르면 size · exit 1" -R $r -ExpectExit 1 -ExpectContains 'image-diff: size 20x10 vs 21x10'
$r = Invoke-ImageDiff @('-Base', $idBase, '-Head', (Join-Path $idDir 'missing.png'))
$idNamed = $r.out -match 'image-diff: ERROR not found .*missing\.png'
Assert-Case -Name "image-diff: 파일이 없으면 그 파일을 대며 ERROR · exit 2" -R @{ code = $r.code; out = ($r.out + " named=$idNamed") } -ExpectExit 2 -ExpectContains 'named=True'
$r = Invoke-ImageDiff @('-Base', $idBase, '-Head', $idOne, '-Mask', '1,2,3')
Assert-Case -Name "image-diff: 가림 서식이 틀리면 ERROR mask · exit 2" -R $r -ExpectExit 2 -ExpectContains 'image-diff: ERROR mask'
$r = Invoke-ImageDiff @('-Base', $idBase, '-Head', $idOne, '-Mask', '15,5,10,10')
Assert-Case -Name "image-diff: 가림이 이미지 밖이면 잘라 쓰지 않고 ERROR mask · exit 2" -R $r -ExpectExit 2 -ExpectContains 'image-diff: ERROR mask'

$idBlue = Join-Path $idDir 'blue.png'
$idBmp = [System.Drawing.Bitmap]::new(20, 10)
try {
    $g = [System.Drawing.Graphics]::FromImage($idBmp); $g.Clear([System.Drawing.Color]::White); $g.Dispose()
    $idBmp.SetPixel(3, 4, [System.Drawing.Color]::Blue)
    $idBmp.Save($idBlue, [System.Drawing.Imaging.ImageFormat]::Png)
} finally { $idBmp.Dispose() }
$idOut = Join-Path $idDir 'diff-blue.png'
$r = Invoke-ImageDiff @('-Base', $idBase, '-Head', $idBlue, '-Out', $idOut)
$idMarked = 'missing'
if (Test-Path -LiteralPath $idOut) {
    $idOb = [System.Drawing.Bitmap]::new($idOut)
    try { $idMarked = '{0}/{1}' -f $idOb.GetPixel(3, 4).Name, $idOb.GetPixel(0, 0).Name } finally { $idOb.Dispose() }
}
Assert-Case -Name "image-diff: -Out 은 다른 픽셀만 빨강으로 칠한 PNG 를 남긴다" -R @{ code = $r.code; out = ($r.out + " marked=$idMarked") } -ExpectExit 1 -ExpectContains 'marked=ffff0000/ffffffff'

$idBig1 = New-IdPng 'big1.png' 1920 1080
$idBig2 = New-IdPng 'big2.png' 1920 1080 @(, @(1000, 500))
$idSw = [System.Diagnostics.Stopwatch]::StartNew()
$r = Invoke-ImageDiff @('-Base', $idBig1, '-Head', $idBig2)
$idSw.Stop()
$idFast = $idSw.Elapsed.TotalSeconds -le 5
Assert-Case -Name "image-diff: 1920x1080 두 장을 5초 안에 비교한다(기동 포함 — 병렬 전체에서만 실패하면 단독 재실행으로 가른다)" -R @{ code = $r.code; out = ($r.out + " fast=$idFast") } -ExpectExit 1 -ExpectContains 'diff 1 px of 1920x1080 fast=True'

}
