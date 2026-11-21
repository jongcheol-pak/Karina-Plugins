# 넘김 사유 없는 Deferred 항목 판정 — 근거는 `rules/loop-continue-rationale.md` §9
function Get-UnhandedDeferred([string]$PlanText) {
    $found = New-Object System.Collections.Generic.List[object]
    $items = New-Object System.Collections.Generic.List[object]
    $allowed = 0
    $fence = $null
    $inDeferred = $false
    $n = 0
    foreach ($t in ($PlanText -split "`r?`n")) {
        $n++
        $f = [regex]::Match($t, '^ {0,3}(`{3,}|~{3,})')
        if ($fence) { if ($f.Success -and $f.Groups[1].Value[0] -eq $fence) { $fence = $null }; continue }
        if ($f.Success) { $fence = $f.Groups[1].Value[0]; continue }
        if ($t -match '^> 승인: [0-9]{4}-') {
            $c = [regex]::Match($t, '다음 회차 (\d+)')
            if ($c.Success) { $allowed = [int]$c.Groups[1].Value }
            continue
        }
        if ($t -match '^## ') { $inDeferred = $t -match '^## Deferred / Follow-up'; continue }
        if (-not $inDeferred) { continue }
        if ($t -match '^- ') { $items.Add([pscustomobject]@{ N = $n; Text = $t }) }
        elseif ($t -match '^\s+\S' -and $items.Count) { $items[-1].Text += "`n" + $t }
    }
    $next = 0
    foreach ($it in $items) {
        if ($it.Text -match '^- 없음\s*$') { continue }
        $m = [regex]::Match($it.Text, '^- `?\[(등재|미판정|다음 회차|1회 실패|미등재:[^\]]+)\]')
        $kind = $null
        if (-not $m.Success) { $kind = 'no-marker' }
        else {
            $marker = $m.Groups[1].Value
            if ($marker -eq '미판정') { $kind = 'unjudged' }
            elseif ($marker -eq '등재' -or $marker -eq '미등재:대장 없음') {
                if ($it.Text -notmatch '넘김 사유:? ?(①|②|다른 종류의 세션)') { $kind = 'no-reason' }
            } elseif ($marker -eq '다음 회차') {
                $next++
                if (-not $it.Text.Contains('(근거:')) { $kind = 'no-basis' }
                elseif ($next -gt $allowed) { $kind = 'over-approved' }
            }
        }
        if ($kind) { $found.Add([pscustomobject]@{ N = $it.N; Kind = $kind; Text = ($it.Text -split "`n")[0] }) }
    }
    return $found
}
