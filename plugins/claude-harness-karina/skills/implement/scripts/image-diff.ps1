param(
    [string]$Base,
    [string]$Head,
    [string]$Mask = '',
    [string]$Out = ''
)

function Stop-ImageDiff([string]$Reason) {
    Write-Output ('image-diff: ERROR ' + $Reason)
    exit 2
}

foreach ($p in @($Base, $Head)) {
    if (-not $p -or -not (Test-Path -LiteralPath $p -PathType Leaf)) { Stop-ImageDiff ('not found ' + $p) }
}

try { Add-Type -AssemblyName System.Drawing } catch { Stop-ImageDiff ('System.Drawing ' + $_.Exception.Message) }
if (-not ('ImageDiffCore' -as [type])) {
    Add-Type -ReferencedAssemblies System.Drawing.Common, System.Drawing.Primitives -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Imaging;
using System.Runtime.InteropServices;
public static class ImageDiffCore {
    static byte[] Bytes(Bitmap b, out int stride) {
        var d = b.LockBits(new Rectangle(0, 0, b.Width, b.Height), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        try {
            stride = d.Stride;
            var buf = new byte[d.Stride * b.Height];
            Marshal.Copy(d.Scan0, buf, 0, buf.Length);
            return buf;
        } finally { b.UnlockBits(d); }
    }
    public static long[] Compare(Bitmap a, Bitmap b, bool[] masked, string outPath) {
        int w = a.Width, h = a.Height, sa, sb;
        var xa = Bytes(a, out sa); var xb = Bytes(b, out sb);
        long diff = 0, hidden = 0, minX = w, minY = h, maxX = -1, maxY = -1;
        Bitmap mark = string.IsNullOrEmpty(outPath) ? null : new Bitmap(b);
        try {
            for (int y = 0; y < h; y++) {
                for (int x = 0; x < w; x++) {
                    int i = y * sa + x * 4, j = y * sb + x * 4;
                    if (xa[i] == xb[j] && xa[i + 1] == xb[j + 1] && xa[i + 2] == xb[j + 2] && xa[i + 3] == xb[j + 3]) continue;
                    if (masked[y * w + x]) { hidden++; continue; }
                    diff++;
                    minX = Math.Min(minX, x); minY = Math.Min(minY, y); maxX = Math.Max(maxX, x); maxY = Math.Max(maxY, y);
                    if (mark != null) mark.SetPixel(x, y, Color.Red);
                }
            }
            if (mark != null) mark.Save(outPath, ImageFormat.Png);
        } finally { if (mark != null) mark.Dispose(); }
        return new long[] { diff, hidden, minX, minY, maxX, maxY };
    }
}
'@
}

$a = $null; $b = $null
try {
    try {
        $a = [System.Drawing.Bitmap]::new((Resolve-Path -LiteralPath $Base).ProviderPath)
        $b = [System.Drawing.Bitmap]::new((Resolve-Path -LiteralPath $Head).ProviderPath)
    } catch { Stop-ImageDiff ('unreadable ' + $_.Exception.Message) }

    if ($a.Width -ne $b.Width -or $a.Height -ne $b.Height) {
        Write-Output ('image-diff: size {0}x{1} vs {2}x{3}' -f $a.Width, $a.Height, $b.Width, $b.Height)
        exit 1
    }

    $w = $a.Width; $h = $a.Height
    $masked = [bool[]]::new($w * $h)
    foreach ($rect in @($Mask -split ';' | Where-Object { $_.Trim() })) {
        $n = @($rect -split ',' | ForEach-Object { $_.Trim() })
        $v = @(0, 0, 0, 0)
        if ($n.Count -ne 4 -or @($n | Where-Object { $_ -notmatch '^\d+$' }).Count) { Stop-ImageDiff ('mask format ' + $rect) }
        for ($k = 0; $k -lt 4; $k++) { $v[$k] = [int]$n[$k] }
        if ($v[2] -lt 1 -or $v[3] -lt 1 -or $v[0] + $v[2] -gt $w -or $v[1] + $v[3] -gt $h) {
            Stop-ImageDiff ('mask outside {0}x{1} image: {2}' -f $w, $h, $rect)
        }
        for ($y = $v[1]; $y -lt $v[1] + $v[3]; $y++) {
            [System.Array]::Fill($masked, $true, $y * $w + $v[0], $v[2])
        }
    }

    $outPath = ''
    if ($Out) { $outPath = [System.IO.Path]::GetFullPath($Out) }
    try { $r = [ImageDiffCore]::Compare($a, $b, $masked, $outPath) } catch { Stop-ImageDiff ('compare ' + $_.Exception.InnerException.Message) }
    $line = 'image-diff: diff {0} px of {1}x{2}' -f $r[0], $w, $h
    if ($Mask.Trim()) { $line += (' masked {0} px' -f $r[1]) }
    if ($r[0] -gt 0) { $line += (' bbox {0},{1},{2},{3}' -f $r[2], $r[3], ($r[4] - $r[2] + 1), ($r[5] - $r[3] + 1)) }
    Write-Output $line
    if ($r[0] -eq 0) { exit 0 } else { exit 1 }
} finally {
    if ($a) { $a.Dispose() }
    if ($b) { $b.Dispose() }
}
