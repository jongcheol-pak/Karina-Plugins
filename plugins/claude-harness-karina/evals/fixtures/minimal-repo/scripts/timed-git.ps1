function Get-KarinaTempRoot {
    $base = @($env:TMPDIR, $env:TEMP, $env:TMP) | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Container) } | Select-Object -First 1
    if (-not $base) { $base = [System.IO.Path]::GetTempPath() }
    return (Join-Path $base 'karina-plugin')
}
