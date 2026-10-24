# 게이트 완화 서명 (`karina:chain-plan`)

> `../SKILL.md`「답하는 기준」 이 `[게이트 완화 서명]` 질문을 받을 때와 `stack-mode.md`「착지」 의 ship 이 게이트 완화 게이트에 닿을 때(`../../pr/references/ship.md` 7번 ⓒ) 이 파일을 연다. 출처는 Cursor pstack 의 autopilot-full 6단계다 — 고정 위치 `https://github.com/cursor/plugins/blob/f713f14203cd6420cec13cd7c55c32d598dbab68/pstack/skills/poteto-mode/playbooks/autopilot-full.md`. 상한 인상·화이트리스트·면제 추가는 green 을 원하는 작성자(워커)가 스스로 받아들일 수 없어, 코드를 쓰지 않은 코디네이터가 서명한다(*"needs a verifier's proof and then your fresh countersign, because the owner is the one who wants green"*). 체인 승인 `P`·`T` 가 그 위임이다(*"Under a grant that covers approvals, that countersign is the approval"*).

## 서명 요청

워커의 ship(7번 ⓑ)이 배정문 진행 2 의 `ask` 로 보내는 본문이다.

```
Q: [게이트 완화 서명] PR <URL> · head <검증한 head full SHA>
게이트 완화: <pr-verifier `게이트 완화:` 칸 원문>
근거 출력: <pr-verifier `출력 요지` 가운데 완화가 필요한 근거 줄(예: 상한을 넘긴 파일의 크기 출력) | 없음>
목표: <그 계획 spec 재진술의 결과 한 줄>
GUESS: <서명 | 거부> — <근거>
```

## 판정 기준

- **판정 재료는 요청 본문과 이 세션이 가진 그 계획의 기록(사용자 원문·`판정 원칙:`·재진술)뿐이다** — 본문 밖의 짐작으로 서명하면 검증자의 증명 없이 서명한 것이 된다.
- **서명은 둘 중 하나일 때만이다 — 원문·`판정 원칙:`·재진술 목표가 그 완화를 지목하거나, `근거 출력` 이 완화 없이는 목표가 서지 않음을 보인다** — 어느 쪽도 아니면 완화는 green 을 만들려는 수단일 뿐이라 거부한다.
- **대상 레포 규약이 그 완화를 금하면 거부한다** — 예: 그 레포가 「상한을 올리는 것은 처방이 아니다」 를 두었다.
- **완화가 사용자 원문 답에서 온 제약을 넘으면 사용자 몫 ② 다 — `user-relay.md`「사용자에게 넘기기」 로 넘긴다**(`user-relay.md`「사용자 몫」). 그 밖은 사용자 몫 다섯 밖이라 코디네이터가 판정한다.
- **체크를 끄거나 soft-fail 로 바꾼 줄은 서명 대상이 아니다** — pr-verifier 가 이미 FAIL 로 낸다(*"A disabled or soft-failed check always comes out"*).
- **forge 가 강제하는 승인(브랜치 보호의 필수 리뷰 등)은 서명으로 대신하지 않는다**(*"Never give or bypass an approval the forge enforces"*).
- **서명은 head SHA 마다 새로 판정한다 — `prior-answers.md`「앞선 답」 으로 앞 답을 재사용하지 않는다** — 옛 SHA 의 서명은 ship 이 서명으로 치지 않아(7번), 재사용하면 같은 질문이 되풀이된다.

## 답 서식

```
서명 <검증한 head full SHA> (코디네이터 판정 — <근거>)
거부 — <사유> (코디네이터 판정 — <근거>)
```

- **사용자 몫 ② 로 넘겼으면 사용자 답을 이 두 형식으로 감싸 보낸다** — `서명 <SHA> (사용자 답 — 「<원문>」)` / `거부 — <사유> (사용자 답 — 「<원문>」)`. ship 은 두 형식 밖의 답을 거부로 쳐서, 원문을 그대로 옮기면 사용자가 서명했어도 거부가 된다.
- **② 의 미답 기본값은 `거부 — 미답` 이다** — 확인 없는 merge 보다 완화를 되돌리는 수정이 되돌리기 쉽다.

## 기록

- **답한 뒤 `chain-decisions.md`「결정 기록」 의 한 줄을 남긴다 — `대상: PR <URL> · 축: 게이트 완화 서명 · 답: 「<보낸 답 원문>」`** — 압축 뒤에도 서명이 어느 head 에 있었는지 남는다.
- **코디네이터 판정이면 `report.md`「보고 서식」 의 `코디네이터 판정:` 줄에도 싣는다** — 사용자가 체인 끝에 서명을 보고 뒤집을 수 있어야 한다.

## 스택 착지

- **착지 ship 은 이 세션(코디네이터)에서 돌므로 ship 7번 ⓒ 가 위 「판정 기준」 으로 직접 판정하고 「기록」 대로 남긴다 — `ask` 도 ship 재호출도 없다** — 재료는 ship 4번 pr-verifier 의 `게이트 완화:`·`출력 요지` 칸과 그 plan 의 spec 재진술 목표다. 다시 부르면 새 요청이라 worktree·pr-verifier 가 한 번 더 돈다(ship 7번 「같은 세션의 답」).
- **거부면 ship 이 「게이트 완화 서명 거부」 로 멈추고 착지도 멈춘다(`stack-mode.md`「착지」).**
- **사용자 몫 ② 면 ship 이 「게이트 완화 확인 대기」 로 멈추고 착지도 멈춘다 — 사용자가 「PR <n> 게이트 완화 확인함」 으로 답하면 ship 7번부터 다시 가고, 그 PR 이 merge 되면 `stack-mode.md`「착지」 의 다음 불릿(위 PR base 변경 → ship)으로 잇는다.**
