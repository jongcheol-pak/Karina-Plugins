# `session-ledger-signal` 판정 근거

> `session-ledger-signal.ps1`의 주석에서 옮긴 판정 근거다. 스크립트에는 각 자리에 이 문서의 절을 가리키는 1줄만 남겼다.
> **문면을 요약하지 않고 이동만 했다** — 이관은 이동이지 요약이 아니다.

## §1 session-ledger-signal.ps1 — 세션 시작 주입의 Deferred 대장 최고령 신호 (dot-source 전용, hook 아님)

```
# session-ledger-signal.ps1 — 세션 시작 주입의 Deferred 대장 최고령 신호 (dot-source 전용, hook 아님)
#
# `session-context.ps1`이 dot-source해 호출한다. 별도 파일인 이유는 이 신호만 **대장 3파일을 파싱**하기
#   때문이다 — 항목별 날짜 부기를 형식으로 인식하고 미래 날짜를 배제하는 판정이라 다른 신호와 입력이 다르다.
#
# 반환: 주입할 1줄 또는 $null. 호출부가 그 줄을 넣고 `$cwdBaseCount`를 올린다.
# 근거는 `rules/session-context-rationale.md`의 대장 관련 절들.
```


## §2 하니스 루트 판정 (모노레포 이전)

대장은 하니스 루트의 `docs/plans/deferred.md` 다. 하니스가 모노레포의 플러그인 폴더로 옮겨, 옛 판정(cwd 아래 옛 플러그인 폴더의 매니페스트)으로는 신호가 꺼진다. 하니스 루트는 `harness-root.ps1` 의 `Find-HarnessRoot` 가 cwd 에서 위로 찾는다(판정 조건은 `warn-version-drift`·`guard-stale-docs` 와 같다). 골든은 `scenarios/session-context.ps1` 의 SC44mono 다.
