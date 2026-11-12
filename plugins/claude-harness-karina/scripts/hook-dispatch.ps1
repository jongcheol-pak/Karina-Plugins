# hook-dispatch.ps1 — 같은 이벤트·matcher 의 hook 스크립트를 한 프로세스에서 차례로 부른다 — 근거는 `rules/hook-dispatch-rationale.md` §1

param(
    [switch]$Blocking,
    [int]$AdvisoryBudgetMs = 20000,
    [int]$AdvisoryDeadlineMs = 45000,
    [Parameter(Position = 0, ValueFromRemainingArguments = $true)][string[]]$Scripts
)

$hdClock = [System.Diagnostics.Stopwatch]::StartNew()
$ErrorActionPreference = 'Continue'
try { [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

# 권고 스크립트 구간 — 근거는 `rules/hook-dispatch-rationale.md` §7
$hdArgs = @($Scripts | Where-Object { $_ })
$hdSplit = @(for ($hdI = 0; $hdI -lt $hdArgs.Count; $hdI++) { if ($hdArgs[$hdI] -ceq 'advisory:') { $hdI } })
$hdNames = $hdArgs
$hdAdvNames = @()
if ($hdSplit.Count -gt 1) {
    [Console]::Error.WriteLine('hook-dispatch: 구분 토큰 advisory: 가 두 번 이상입니다')
    exit 1
}
if ($hdSplit.Count -eq 1) {
    $hdNames = @($hdArgs | Select-Object -First $hdSplit[0])
    $hdAdvNames = @($hdArgs | Select-Object -Skip ($hdSplit[0] + 1))
    if ($hdAdvNames.Count -eq 0) {
        [Console]::Error.WriteLine('hook-dispatch: 구분 토큰 advisory: 뒤에 스크립트가 없습니다')
        exit 1
    }
}
if ($hdNames.Count -eq 0) {
    [Console]::Error.WriteLine('hook-dispatch: 부를 스크립트가 없습니다')
    exit 1
}
$hdSelf = Split-Path -Leaf $PSCommandPath
function Resolve-HdScriptPaths([string[]]$Names) {
    $paths = @()
    foreach ($name in $Names) {
        $path = Join-Path $PSScriptRoot $name
        if ($name -cnotmatch '^[a-z0-9-]+\.ps1$' -or $name -eq $hdSelf -or -not (Test-Path -LiteralPath $path -PathType Leaf)) {
            [Console]::Error.WriteLine("hook-dispatch: 부를 수 없는 스크립트 인자 — $name")
            exit 1
        }
        $paths += $path
    }
    return $paths
}
$hdPaths = @(Resolve-HdScriptPaths $hdNames)
$hdAdvPaths = @(Resolve-HdScriptPaths $hdAdvNames)

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
$hdRuns = @($hdPaths | ForEach-Object { [pscustomobject]@{ Path = $_; Advisory = $false } }) + @($hdAdvPaths | ForEach-Object { [pscustomobject]@{ Path = $_; Advisory = $true } })
$hdRs = $null
$hdTimedOut = $false
$hdAdvScript = 'param($p, $loc) Set-Location -LiteralPath $loc; $global:LASTEXITCODE = 0; try { $o = & $p | Out-String; [pscustomobject]@{ Pipe = $o; Code = [int]$global:LASTEXITCODE; Fault = $null } } catch { [pscustomobject]@{ Pipe = ''''; Code = 1; Fault = $_.Exception.Message } }'
try {
    foreach ($hdRun in $hdRuns) {
        $hdPath = $hdRun.Path
        $hdAdv = $hdRun.Advisory
        if ($hdAdv -and (@($hdCodes | Where-Object { $_ -ne 0 }).Count -gt 0 -or $hdClock.ElapsedMilliseconds -ge $AdvisoryBudgetMs)) { break }
        $hdLeaf = Split-Path -Leaf $hdPath
        $hdBuf = New-Object System.IO.StringWriter
        $hdErrBuf = New-Object System.IO.StringWriter
        $hdPipe = ''
        $hdCode = 0
        $hdFault = $null
        try {
            [Console]::SetOut($hdBuf)
            [Console]::SetError($hdErrBuf)
            if ($hdAdv) {
                if (-not $hdRs) {
                    $hdRs = [runspacefactory]::CreateRunspace()
                    $hdRs.Open()
                    $hdRs.SessionStateProxy.SetVariable('KarinaHookStdin', $global:KarinaHookStdin)
                }
                $hdPs = [powershell]::Create()
                $hdPs.Runspace = $hdRs
                $null = $hdPs.AddScript($hdAdvScript).AddArgument($hdPath).AddArgument($hdStart)
                $hdHandle = $hdPs.BeginInvoke()
                if (-not $hdHandle.AsyncWaitHandle.WaitOne([int][Math]::Max(0, $AdvisoryDeadlineMs - $hdClock.ElapsedMilliseconds))) {
                    $hdTimedOut = $true
                } else {
                    $hdRes = @($hdPs.EndInvoke($hdHandle))[-1]
                    $hdPipe = [string]$hdRes.Pipe
                    $hdCode = [int]$hdRes.Code
                    if ($hdRes.Fault) { $hdFault = "hook-dispatch: $hdLeaf 예외 — $($hdRes.Fault)" }
                    $hdPs.Dispose()
                }
            } else {
                $global:LASTEXITCODE = 0
                $hdPipe = & $hdPath | Out-String
                $hdCode = [int]$global:LASTEXITCODE
            }
        } catch {
            $hdFault = "hook-dispatch: $hdLeaf 예외 — $($_.Exception.Message)"
            $hdCode = 1
        } finally {
            [Console]::SetOut($hdOut)
            [Console]::SetError($hdErr)
            Set-Location -LiteralPath $hdStart
        }
        if ($hdTimedOut) {
            $hdErrs.Add([pscustomobject]@{ Code = $null; Text = "hook-dispatch: $hdLeaf 마감 초과 — 권고를 버리고 묶음을 끝냅니다`n" })
            break
        }
        $hdErrs.Add([pscustomobject]@{ Code = $(if ($hdAdv) { $null } else { $hdCode }); Text = $hdErrBuf.ToString() })
        if ($hdFault) { $hdErrs.Add([pscustomobject]@{ Code = $null; Text = $hdFault + "`n" }) }
        if ($hdCode -ne 0 -and ($hdAdv -or $hdCode -ne 2)) { $hdErrs.Add([pscustomobject]@{ Code = $null; Text = "hook-dispatch: $hdLeaf exit $hdCode`n" }) }
        if (-not $hdAdv) { $hdCodes += $hdCode }
        $hdText = (@($hdBuf.ToString(), $hdPipe) | ForEach-Object { $_.Trim("`r", "`n") } | Where-Object { $_ }) -join "`n"
        if (-not $hdText.Trim()) { continue }
        $hdObj = $null
        $hdJsonText = $hdText.Trim()
        if ($hdJsonText.StartsWith('{')) { try { $hdObj = $hdJsonText | ConvertFrom-Json -ErrorAction Stop } catch {} }
        if ($null -ne $hdObj) {
            $hdDropped = @($hdObj.PSObject.Properties.Name | Where-Object { $_ -ne 'hookSpecificOutput' })
            if ($hdObj.hookSpecificOutput -is [System.Management.Automation.PSCustomObject]) {
                $hdDropped += @($hdObj.hookSpecificOutput.PSObject.Properties.Name | Where-Object { $_ -notin @('hookEventName', 'additionalContext') })
            }
            if ($hdDropped.Count -gt 0) {
                $hdErrs.Add([pscustomobject]@{ Code = $null; Text = "hook-dispatch: $hdLeaf 이 묶음이 전하지 못하는 JSON 필드를 냈습니다 — $($hdDropped -join ', ')`n" })
                if ($Blocking -and -not $hdAdv -and $hdCodes[-1] -eq 0) { $hdCodes[-1] = 1 }
            }
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
if ($hdTimedOut) {
    [Console]::Out.Flush()
    [Console]::Error.Flush()
    [Environment]::Exit($hdFinal)
}
if ($hdRs) { $hdRs.Dispose() }
exit $hdFinal
