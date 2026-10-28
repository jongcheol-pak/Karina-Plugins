# 앱 검증 중 화면 가리기

> 일곱 자리가 가리키는 공용 규칙이다 — `implement/references/report-format.md`·`implement/references/loop-exceptions.md`·`implement/references/final-review.md`(`karina:implement`) · `pr/references/ship.md`(ship 의 `pr-verifier` 호출) · `karina-systematic-debugging/SKILL.md` · `create-verification-skill/SKILL.md` · `maintain-verification-skill/SKILL.md`. Karina 앱의 화면 가리기(cover)가 켜진 모니터는 마우스 입력이 막혀(`karina-cli skills get karina-workspace` 「Screen Cover」) 검증 스킬의 조작이 그 모니터에서 실패한다.

## 대상

- **`AGENTS.md` 의 `Verify (앱 조작)` 검증 스킬로 앱을 조작하는 단계면 조작 방식과 관계없이 쓴다** — 생성·유지 스킬의 증명 단계도 같다. 웹·CLI 조작만 하는 스킬도 걷는다. 화면을 쓰는지 가르는 신호가 스킬에 없고, 걷은 시간은 그 단계 안으로 한정된다.
- **Karina 앱 밖(CLI 가 없는 PC)에서는 스크립트가 `skip no-cli` 로 끝난다** — 그때는 아무것도 하지 않고 검증을 계속한다.

## 호출

`<스크립트>` 는 `"<skill>/../implement/scripts/screen-cover.ps1"` 이다(`<skill>` 은 부르는 스킬의 SKILL.md 폴더 — `karina:implement` 는 `"<skill>/scripts/screen-cover.ps1"`). 호출형은 work-clock 과 같다(`implement/references/report-format.md`「소요 기록」).

```
Bash:       "$(command -v pwsh || echo powershell)" -NoProfile -File "<스크립트>" -Action <pause|resume> -Holder '<보유자>'
PowerShell: & "<스크립트>" -Action <pause|resume> -Holder '<보유자>'
```

- **보유자는 `<호출자>:<레포 루트 또는 worktree 절대경로>` 다** — 예 `implement:D:/repo` · `ship:<head worktree>`. 병렬 체인 워커는 worktree 가 달라 보유자가 갈리고, 스크립트는 마지막 보유자가 resume 할 때만 다시 덮는다. 같은 단계의 pause 와 resume 은 같은 보유자를 쓴다.
- **판정은 출력의 `karina-cover ` 줄 하나다** — `paused`·`held`·`restored`·`skip` 은 exit 0 이고 그대로 계속한다. `ERROR <사유>` 는 exit 1 이지만 검증을 멈추지 않고, 그 단계의 보고 「기계로 확인 못 한 항목」(없으면 보고 끝)에 `화면 가리기 — <줄 원문>` 으로 싣는다. 화면 가리기는 검증 대상이 아니라 환경이다.

## 언제 끄고 켜는가

- **pause 는 검증 스킬의 Launch 앞마다 부른다 — 같은 보유자가 여러 번 불러도 된다** — 다시 부르면 그 사이 사용자가 다시 켠 모니터도 걷는다. 원래 꺼져 있던 모니터는 기록되지 않아 resume 이 켜지 않는다.
- **resume 은 테스트 단계가 끝날 때 한 번 부른다 — 단계 중간의 코드 수정·재실행 사이에는 부르지 않는다** — 고치고 다시 돌리는 사이에 덮으면 다음 조작이 다시 막힌다.

| 호출부 | resume 자리 |
|---|---|
| `karina:implement` | 회차 끝의 완료 시각 기록 직전(`report-format.md`「소요 기록」) — 그리고 회차가 끝나기 전에 멈추는 모든 보고 직전(멈추는 넷 · 시크릿 경고 · plan 밖 변경 · 같은 지적 3회 · 사용자 중단) |
| `karina:pr` ship | 4번 `pr-verifier` 가 돌아온 뒤 — 판정 없이 끝난 경우도 |
| `karina-systematic-debugging` | 최종 보고 직전 — `karina:implement` 루프 안이면 그 루프의 자리를 따른다 |
| `create-verification-skill` | 4단계 증명이 끝난 뒤 — 성공이든 초안이든 |
| `maintain-verification-skill` | 5번 재증명까지 포함한 이번 실행의 마지막 조작 뒤, 6번 전 |

- **pause 를 부른 세션은 turn 을 끝내는 보고를 내기 전에 resume 한다** — 위 표에 없는 정지도 같다. 덮지 않고 끝내면 다음 검증의 resume 이 올 때까지 사용자 화면이 걷힌 채 남는다.
- **resume 때 앱이 꺼져 있으면 스크립트가 기록을 지운다(`skip app-off`)** — 덮개는 앱 창이라 사용자가 앱을 종료하면 함께 사라진다. 그 뒤에 다시 덮으면 사용자가 없앤 덮개를 되살린다. 꺼짐은 `status` 의 `appRunning` 하나로 가르고, 그 밖의 CLI 실패는 기록을 지우지 않고 `ERROR` 로 끝나 다음 resume 이 다시 덮는다.
- **상태 파일 `%TEMP%\karina-plugin\cover\` 는 보유 중에 지우지 않는다** — 지우면 걷은 모니터를 다시 덮지 못한다(`TEMP-FILES.md`).
