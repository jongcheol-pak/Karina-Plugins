$script:TimedGitExe = $null

function ConvertTo-TimedGitArgument([string]$Arg) {
    return '"' + ([regex]::Replace($Arg, '(\\*)("|$)', { param($m) $m.Groups[1].Value + $m.Groups[1].Value + $(if ($m.Groups[2].Value) { '\"' } else { '' }) })) + '"'
}

function Invoke-TimedGit {
    param([string[]]$GitArgs, [string]$WorkDir = (Get-Location).ProviderPath, [int]$TimeoutMs)
    $none = [pscustomobject]@{ Code = -1; Lines = @() }
    if ($TimeoutMs -le 0) { return $none }
    $clock = [System.Diagnostics.Stopwatch]::StartNew()
    if (-not $script:TimedGitExe) { $script:TimedGitExe = @(Get-Command git -CommandType Application -ErrorAction SilentlyContinue | ForEach-Object { $_.Source })[0] }
    if (-not $script:TimedGitExe) { return $none }
    $argText = (@($GitArgs) | ForEach-Object { ConvertTo-TimedGitArgument $_ }) -join ' '
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    if ($script:TimedGitExe -match '(?i)\.(cmd|bat)$') {
        if (@($GitArgs | Where-Object { $_ -match '[%"]' }).Count -or $argText.Length -gt 7000) { return $none }
        $psi.FileName = $env:ComSpec
        $psi.Arguments = '/d /s /c "' + (ConvertTo-TimedGitArgument $script:TimedGitExe) + ' ' + $argText + '"'
    } else {
        $psi.FileName = $script:TimedGitExe
        $psi.Arguments = $argText
    }
    $psi.WorkingDirectory = $WorkDir
    $psi.UseShellExecute = $false
    $psi.CreateNoWindow = $true
    $psi.RedirectStandardInput = $true
    $psi.RedirectStandardOutput = $true
    $psi.RedirectStandardError = $true
    $psi.StandardOutputEncoding = [System.Text.UTF8Encoding]::new($false)
    $psi.StandardErrorEncoding = [System.Text.UTF8Encoding]::new($false)
    $p = $null
    try {
        $p = [System.Diagnostics.Process]::Start($psi)
        $p.StandardInput.Close()
        $outTask = $p.StandardOutput.ReadToEndAsync()
        $null = $p.StandardError.ReadToEndAsync()
        $left = [int][Math]::Max(0, $TimeoutMs - $clock.ElapsedMilliseconds)
        if (-not $p.WaitForExit($left)) {
            try {
                if ($PSVersionTable.PSVersion.Major -ge 7) { $p.Kill($true) }
                elseif ($env:OS -eq 'Windows_NT') { $null = & taskkill /T /F /PID $p.Id 2>$null }
                else { $p.Kill() }
            } catch {}
            return $none
        }
        $left = [int][Math]::Max(0, $TimeoutMs - $clock.ElapsedMilliseconds)
        if (-not $outTask.Wait($left)) { return $none }
        $lines = @($outTask.Result -split "`r?`n")
        if ($lines.Count -and $lines[-1] -eq '') { $lines = @($lines | Select-Object -First ($lines.Count - 1)) }
        return [pscustomobject]@{ Code = $p.ExitCode; Lines = $lines }
    } catch {
        return $none
    } finally {
        if ($p) { $p.Dispose() }
    }
}
