# away-precheck 근거

> `scripts/away-precheck.ps1` 의 주석이 가리키는 근거다. 부재 예고를 받은 뒤의 절차 정본은 `skills/AWAY-PRECHECK.md`「부재 사전 확인」 이고, 이 파일은 hook 쪽의 「왜」만 담는다.

## §1 왜 hook 이 부재 예고를 잡는가

사용자가 「잔다·퇴근한다」고 말한 뒤의 무인 실행은 승인 자리(태그·릴리즈·배포·복구 불가 삭제·체인의 사용자 몫 질문)에서 아침까지 선다. 그 자리를 미리 묻는 절차는 `karina:plan` 승인 단계·`karina:chain-plan` 코디네이터·`karina:implement` 루프 셋이 함께 쓰는데, 세 `SKILL.md` 는 12,000자 게이트에 4~819자만 남아 본문에 규칙을 더할 자리가 없다. 코디네이터는 백그라운드 대기 중에 사용자 메시지를 받아, 본문 깊숙한 규칙 한 줄은 그 시점에 잘 떠오르지 않는다. 메시지가 들어오는 순간 기계가 절차 문서를 가리키면 둘 다 풀린다(사용자 답 2026-11-26 「UserPromptSubmit hook」).

## §2 문구 목록과 오탐 비용

한국어(잔다·잘게·자러 간다·자야겠다·퇴근·자리 비움·외출·내일 이어서)와 영어(going to bed/sleep·heading home/out·signing off·afk·good night)를 대소문자 없이 본다. 오탐은 한 줄 주입뿐이다 — 막지 않고, 절차 문서의 첫 단계가 지금이 적용 단계인지 다시 가른다. 그래서 문구는 넓게 잡고 판정은 문서에 둔다. 「잔디」·「sleep 함수」처럼 같은 글자를 품은 다른 말은 골든 음성 케이스가 지킨다.

## §3 판정 불가는 침묵 · 스킬 상태 게이트

stdin 이 JSON 이 아니거나 `session_id` 가 없거나 문구가 맞지 않으면 아무것도 내지 않고 exit 0 이다. 문구가 맞아도 이 세션에 `karina:plan`·`karina:chain-plan` 발동 기록(`record-work-start.ps1` 의 `.state/work-start/<sid>.json`)이나 `karina:implement` 루프 마커(`loop-continue.ps1` 의 `.state/loop-continue/<sid>.active`)가 없으면 침묵한다 — 일반 대화의 「퇴근한다」에 절차를 들이밀지 않는다. 두 경로는 그 두 스크립트의 사본이라, 경로가 바뀌면 골든 상태 갈래 케이스가 잡는다. 계획 인터뷰 단계인지는 hook 이 가를 수 없어 문서 첫 단계가 가른다(사용자 답 「인터뷰는 제외」).

## §4 매 사용자 턴 pwsh 기동

UserPromptSubmit 은 matcher 를 받지 않아(https://code.claude.com/docs/en/hooks 「no matcher support」) 모든 세션의 모든 사용자 턴에 pwsh 가 한 번 뜬다 — 실측 약 0.3초(2026-11-26 `pwsh -NoProfile` 297~334ms). 2026-11-04 「응답 언어 리마인더의 매 사용자 턴 주입」 기각은 규칙 중복과 이 기동 비용을 함께 들었고, 이 hook 은 문구가 맞을 때만 주입해 중복은 없지만 기동 비용은 그대로다. 사용자가 그 비용을 알고 감수했다(2026-11-26 사용자 답 「감수하고 hook 으로」 — `docs/decisions.md`).
