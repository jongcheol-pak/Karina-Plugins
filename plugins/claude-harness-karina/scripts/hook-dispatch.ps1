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
$hdPlainEvents = @('SessionStart', 'UserPromptExpansion', 'UserPromptSubmit')
$hdOut = [Console]::Out
$hdErr = [Console]::Error
$hdStart = (Get-Location).ProviderPath
$hdContexts = New-Object System.Collections.Generic.List[string]
$hdErrs = New-Object System.Collections.Generic.List[object]
$hdFirstEvent = $null
$hdCodes = @()
try {
    foreach ($hdPath in $hdPaths) {
        $hdLeaf = Split-Path -Leaf $hdPath
        $hdBuf = New-Object System.IO.StringWriter
        $hdErrBuf = New-Object System.IO.StringWriter
        $hdPipe = ''
        $hdCode = 0
        $hdFault = $null
        try {
            [Console]::SetOut($hdBuf)
            [Console]::SetError($hdErrBuf)
            $global:LASTEXITCODE = 0
            $hdPipe = & $hdPath | Out-String
            $hdCode = [int]$global:LASTEXITCODE
        } catch {
            $hdFault = "hook-dispatch: $hdLeaf 예외 — $($_.Exception.Message)"
            $hdCode = 1
        } finally {
            [Console]::SetOut($hdOut)
            [Console]::SetError($hdErr)
            Set-Location -LiteralPath $hdStart
        }
        $hdErrs.Add([pscustomobject]@{ Code = $hdCode; Text = $hdErrBuf.ToString() })
        if ($hdFault) { $hdErrs.Add([pscustomobject]@{ Code = $null; Text = $hdFault + "`n" }) }
        if ($hdCode -ne 0 -and $hdCode -ne 2) { $hdErrs.Add([pscustomobject]@{ Code = $null; Text = "hook-dispatch: $hdLeaf exit $hdCode`n" }) }
        $hdCodes += $hdCode
        $hdText = (@($hdBuf.ToString(), $hdPipe) | ForEach-Object { $_.Trim("`r", "`n") } | Where-Object { $_ }) -join "`n"
        if (-not $hdText.Trim()) { continue }
        $hdObj = $null
        $hdJsonText = $hdText.Trim()
        if ($hdJsonText.StartsWith('{')) { try { $hdObj = $hdJsonText | ConvertFrom-Json -ErrorAction Stop } catch {} }
        if ($null -ne $hdObj) {
            if ($hdObj.hookSpecificOutput) {
                if (-not $hdFirstEvent -and $hdObj.hookSpecificOutput.hookEventName) { $hdFirstEvent = [string]$hdObj.hookSpecificOutput.hookEventName }
                $hdCtx = [string]$hdObj.hookSpecificOutput.additionalContext
                if ($hdCtx) { $hdContexts.Add($hdCtx) }
            }
        } elseif ($hdPlainEvents -contains $hdEvent) {
            $hdContexts.Add($hdText)
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
foreach ($hdE in $hdErrs) {
    if ($hdE.Text -and ($hdFinal -ne 2 -or $hdE.Code -eq $hdFinal)) { [Console]::Error.Write($hdE.Text) }
}
exit $hdFinal
