# 체인 끝 push (`karina:chain-plan`)

> `report.md`「인계 파일 정리」 의 정리 커밋 뒤, 보고 전에 이 파일을 연다.

## 체인 끝 push

**체인이 끝까지 성공했을 때(`report.md`「인계 파일 정리」 의 성공 조건과 같다) 그 정리 커밋 뒤, 보고 전에 1회 한다.** 워커는 push 하지 않아(`../../implement/references/push-flow.md`「기본 브랜치 push」 의 중계 모드) 이 단계가 없으면 체인 커밋이 로컬에만 남는다(2026-10-18 체인 커밋을 그 뒤 손으로 올려 제목 유형이 빠진 채 main 커밋이 됐다).

- **계획마다의 대상 레포 가운데 둘이 참인 레포마다 한다** — 대상 레포 경로가 세션 시작 때 주입된 위키 vault 경로와 같지 않다(vault 는 `karina:llm-wiki` 가 직접 push 한다) · 기본 브랜치에 없는 커밋이 있다(`git -C "<대상 레포 경로>" rev-list --count origin/<기본 브랜치>..HEAD` 가 0 이 아니다 — 원격이 없으면 참으로 치고 게이트 판정만 보고한다 — 기본 브랜치는 `../../implement/references/push-flow.md`「기본 브랜치 push」 판정이고, 기본 브랜치 미정이어도 게이트 판정만 보고한다(`push 건너뜀(기본 브랜치 미정)`)). 거짓인 레포는 보고의 `push:` 줄에 `건너뜀 — <거짓인 조건>` 으로 싣는다. 체인 브랜치가 기본 브랜치가 아니면 게이트·push 모두 하지 않고 `건너뜀 — 비기본 브랜치 · 병합 뒤 기본 브랜치에서 게이트를 거쳐 push` 다(`../../implement/references/local-gate.md`「대상과 범위」).
- **`../../implement/references/local-gate.md`「체인 끝」 게이트를 거쳐 `push-flow.md`「기본 브랜치 push」 의 push 를 하고 `push:` 줄에 `게이트 <판정> · push <결과>` 를 싣는다** — 체인 끝 push 가 그 레포의 회차 끝 push 다. git 명령은 모두 `git -C "<대상 레포 경로>"` 로 돈다(`push-flow.md`「기본 브랜치 push」 의 경로 규칙). 게이트 `FAIL` 은 `continuation.md`「체인 끝 게이트 FAIL」 이 받는다.
- **게이트 범위의 `git log --format=%B` 에 `화면: ` 으로 시작하는 줄(미촬영 줄 포함 — `../../implement/references/screen-scenarios.md`「화면 시나리오 실행」)이 있으면 게이트 본문 파일에 `## 화면` 절을 싣는다** — 이 세션은 워커의 `plan.md` 를 읽지 않아 커밋 본문이 화면 task 를 찾는 유일한 자리이고, 이 절이 있어야 게이트의 화면 확인이 걸린다.
- **어느 단계든 실패하면 오류 원문을 보고의 `push:` 줄에 싣고 멈추지 않는다** — 체인은 이미 끝났고, 커밋은 로컬 기본 브랜치에 그대로 있다.
