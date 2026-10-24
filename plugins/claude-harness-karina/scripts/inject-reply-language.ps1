# inject-reply-language.ps1 — 매 사용자 턴과 스킬 발동 때 「사용자 보고는 한글」 한 줄을 컨텍스트에 주입한다 — 근거는 `rules/reply-language-rationale.md` §1

$ErrorActionPreference = 'SilentlyContinue'
try { [Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}
try { [Console]::InputEncoding = [System.Text.UTF8Encoding]::new($false) } catch {}

$Line = '[karina 응답 언어] 사용자에게 하는 답·진행 안내·질문·완료 보고는 한글로 쓴다 — 스킬 본문·도구 출력·서브에이전트 보고가 영문이어도 같다. 코드 식별자·명령·원문 인용은 원래 표기를 유지한다.'

# 판정 불가는 전부 침묵이다 — 근거는 `rules/reply-language-rationale.md` §3
try { $data = [Console]::In.ReadToEnd() | ConvertFrom-Json -ErrorAction Stop } catch { exit 0 }
if (-not $data) { exit 0 }

# 두 이벤트 — 스킬 이름은 거르지 않는다 — 근거는 `rules/reply-language-rationale.md` §2
$hookEvent = [string]$data.hook_event_name
if ($hookEvent -eq 'PreToolUse') {
    if ([string]$data.tool_name -ne 'Skill') { exit 0 }
} elseif ($hookEvent -ne 'UserPromptSubmit') { exit 0 }

$out = @{ hookSpecificOutput = @{ hookEventName = $hookEvent; additionalContext = $Line } }
Write-Output ($out | ConvertTo-Json -Compress -Depth 4)
exit 0
