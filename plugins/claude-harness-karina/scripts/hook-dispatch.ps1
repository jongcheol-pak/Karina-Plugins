# hook-dispatch.ps1 — 같은 이벤트·matcher 의 hook 스크립트를 한 프로세스에서 차례로 부른다 — 근거는 `rules/hook-dispatch-rationale.md` §1

param(
    [switch]$Blocking,
    [Parameter(ValueFromRemainingArguments = $true)][string[]]$Scripts
)

$ErrorActionPreference = 'Continue'
try { [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

$hdNames = @($Scripts | Where-Object { $_ })
if ($hdNames.Count -eq 0) {
    [Console]::Error.WriteLine('hook-dispatch: 부를 스크립트가 없습니다')
    exit 1
}
$hdSelf = Split-Path -Leaf $PSCommandPath
$hdPaths = @()
foreach ($hdName in $hdNames) {
    $hdPath = Join-Path $PSScriptRoot $hdName
    if ($hdName -cnotmatch '^[a-z0-9-]+\.ps1$' -or $hdName -eq $hdSelf -or -not (Test-Path -LiteralPath $hdPath -PathType Leaf)) {
        [Console]::Error.WriteLine("hook-dispatch: 부를 수 없는 스크립트 인자 — $hdName")
        exit 1
    }
    $hdPaths += $hdPath
}

$global:KarinaHookStdin = [Console]::In.ReadToEnd()
$hdEvent = $null
try { $hdEvent = [string](($global:KarinaHookStdin | ConvertFrom-Json -ErrorAction Stop).hook_event_name) } catch {}
$hdOut = [Console]::Out
$hdStart = (Get-Location).ProviderPath
$hdContexts = New-Object System.Collections.Generic.List[string]
$hdFirstEvent = $null
$hdCodes = @()
try {
    foreach ($hdPath in $hdPaths) {
        $hdLeaf = Split-Path -Leaf $hdPath
        $hdBuf = New-Object System.IO.StringWriter
        $hdPipe = ''
        $hdCode = 0
        try {
            [Console]::SetOut($hdBuf)
            $global:LASTEXITCODE = 0
            $hdPipe = & $hdPath | Out-String
            $hdCode = [int]$global:LASTEXITCODE
        } catch {
            [Console]::Error.WriteLine("hook-dispatch: $hdLeaf 예외 — $($_.Exception.Message)")
            $hdCode = 1
        } finally {
            [Console]::SetOut($hdOut)
            Set-Location -LiteralPath $hdStart
        }
        if ($hdCode -ne 0 -and $hdCode -ne 2) { [Console]::Error.WriteLine("hook-dispatch: $hdLeaf exit $hdCode") }
        $hdCodes += $hdCode
        foreach ($hdLine in (($hdBuf.ToString() + "`n" + $hdPipe) -split "\r?\n")) {
            $hdTrim = $hdLine.Trim()
            if (-not $hdTrim) { continue }
            $hdObj = $null
            if ($hdTrim.StartsWith('{')) { try { $hdObj = $hdTrim | ConvertFrom-Json -ErrorAction Stop } catch {} }
            if ($hdObj -and $hdObj.hookSpecificOutput) {
                if (-not $hdFirstEvent -and $hdObj.hookSpecificOutput.hookEventName) { $hdFirstEvent = [string]$hdObj.hookSpecificOutput.hookEventName }
                $hdCtx = [string]$hdObj.hookSpecificOutput.additionalContext
                if ($hdCtx) { $hdContexts.Add($hdCtx) }
            } else {
                $hdContexts.Add($hdTrim)
            }
        }
    }
} finally {
    Remove-Variable -Name KarinaHookStdin -Scope Global -ErrorAction SilentlyContinue
}

if ($hdContexts.Count -gt 0) {
    if ($hdFirstEvent) { $hdEvent = $hdFirstEvent }
    $hdJson = @{ hookSpecificOutput = @{ hookEventName = $hdEvent; additionalContext = ($hdContexts -join "`n`n") } } | ConvertTo-Json -Compress -Depth 5
    [Console]::Out.WriteLine($hdJson)
}

$hdFinal = 0
if ($hdCodes -contains 2) { $hdFinal = 2 }
elseif ($Blocking -and @($hdCodes | Where-Object { $_ -ne 0 }).Count -gt 0) { $hdFinal = 1 }
exit $hdFinal
