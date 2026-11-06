# 체인 끝 PR (`karina:chain-plan`)

> `report.md`「인계 파일 정리」 의 정리 커밋 뒤, 보고 전에 이 파일을 연다 — `Y` 로 승인한 체인은 「Y 체인 끝 PR」, `P` 는 「P 체인 끝 PR」 을 따른다. 계획 사이의 PR 운영은 `pr-mode.md` 다.

## Y 체인 끝 PR

**`Y` 로 승인한 체인이 끝까지 성공했을 때(`report.md`「인계 파일 정리」 의 성공 조건과 같다) 그 정리 커밋 뒤, 보고 전에 1회 한다.** pstack 은 모든 playbook 끝에 PR 을 연다(*"Invoked at the end of every other playbook."* — `https://github.com/cursor/plugins/blob/ae5650febf4320793844c12c4adaa937f417f8da/pstack/skills/poteto-mode/playbooks/opening-a-pr.md`). 끝 PR 이 없으면 체인 커밋이 로컬에만 남는다(2026-10-18 PR #3 이 그 뒤 손으로 열려 제목 유형이 빠진 채 main 커밋이 됐다).

- **계획마다의 대상 레포 가운데 아래 셋이 참인 레포마다 한다** — 대상 레포 경로가 세션 시작 때 주입된 위키 vault 경로와 같지 않다(vault 는 `karina:llm-wiki` 가 직접 push 한다) · `../../implement/references/pr-flow.md`「적용 판정」 의 앞 두 조건(GitHub 원격 · `gh auth status` exit 0)이 참이다 · `git -C "<대상 레포 경로>" rev-list --count origin/<기본 브랜치>..HEAD` 가 0 이 아니다. 거짓인 레포는 보고의 `PR:` 줄에 `건너뜀 — <거짓인 조건>` 으로 싣는다.
- **main 직행 레포는 위 셋을 보지 않고 PR 대신 `../../implement/references/local-gate.md`「체인 끝」 게이트를 거쳐 `pr-flow.md`「main 직행」 의 push 를 하고 `PR:` 줄에 `건너뜀 — main 직행 · 게이트 <판정> · push <결과>` 를 싣는다** — 체인 끝 push 가 그 레포의 회차 끝 push 다. git 명령은 모두 `git -C "<대상 레포 경로>"` 로 돈다(`pr-flow.md`「main 직행」 의 경로 규칙).
- **`pr-flow.md`「브랜치」 의 표와 「merge 된 브랜치에서 시작할 때」 를 체인 브랜치에 그대로 적용한 뒤 「PR 열기」 1~4 를 따른다** — 같은 절차를 두 곳에 두면 한쪽만 고쳐진다. 그 절차가 `plan.md` 에 적게 한 것(슬러그·`> BASE:` 이동)은 이 세션이 `plan.md` 를 쓰지 않으므로 보고에 싣는다.
  - **슬러그는 `chain-<Run id 의 run_ 뒤 앞 8자>` 다** — 끝 PR 은 체인 끝에 1회만 열리고, 압축 뒤에도 `run-current` 로 같은 id 를 얻는다.
  - **제목은 `<유형>: <계획 제목들을 · 로 이은 한 줄>` 이다** — 유형은 `git log --format=%s origin/<기본 브랜치>..HEAD` 의 유형 접두 중 가장 많은 것이고 같으면 `기능` 이다. 길면 앞 계획부터 줄인다.
  - **본문 `## 범위` 에 plan 번호와 제목 목록을 싣는다** — 나머지 절은 「PR 열기」 의 본문 규칙 그대로다.
  - **`git log --format=%B origin/<기본 브랜치>..HEAD` 에 `화면: ` 으로 시작하는 줄(미촬영 줄 포함 — `../../implement/references/report-format.md`「화면 시나리오 실행」)이 있으면 본문에 `## 화면` 절을 싣는다** — 그 줄을 옮기고, 스크린샷 위치는 검증 스킬의 Evidence 위치를 환경변수 표기로 적는다. 이 세션은 워커의 `plan.md` 를 읽지 않아 커밋 본문이 화면 task 를 찾는 유일한 자리이고, 이 절이 있어야 사용자가 나중에 부르는 ship 의 화면 게이트가 걸린다.
- **babysit·merge 는 하지 않는다 — URL 을 보고하고 끝낸다** — merge 는 사용자가 `karina:pr` 로 요청할 때다(*"Opening a PR does not start a babysit."*). 그 ship 은 직접 경로라 게이트 완화가 있으면 「PR <n> 게이트 완화 확인함」 이 필요하다(「P 체인 끝 PR」 도 같다) — 계획 PR 에서 한 코디네이터 서명은 `chain-decisions.md` 에 있다(`gate-countersign.md`「기록」).
- **어느 단계든 실패하면 오류 원문을 보고의 `PR:` 줄에 싣고 멈추지 않는다** — 체인은 이미 끝났고, 커밋은 로컬 체인 브랜치에 그대로 있다.

## P 체인 끝 PR

**`P` 로 승인한 체인이 끝까지 성공했을 때(`report.md`「인계 파일 정리」 의 성공 조건) 그 정리 커밋 뒤, 보고 전에 1회 체인 브랜치 → 기본 브랜치 PR 을 연다.** 계획 PR 들은 `pr-mode.md`「켜기」 가 만든 체인 브랜치로 merge 돼, 이 PR 이 없으면 체인의 변경이 기본 브랜치로 가는 길이 없다(사용자 답 「체인 끝 main PR 하나」).

- **대상 레포가 「Y 체인 끝 PR」 의 셋째 조건(`rev-list --count origin/<기본 브랜치>..HEAD` 가 0 이 아님)을 채울 때만 한다 — 앞의 두 조건은 `P` 를 고를 때 `pr-mode.md`「켜기」 가 이미 쟀다.** 0 이면 보고의 `PR:` 줄에 `체인 끝 PR: 건너뜀 — 기본 브랜치에 없는 커밋 0` 을 싣는다.
- **`../../implement/references/pr-flow.md`「PR 열기」 1~4 를 체인 브랜치에 그대로 적용한다 — 1번 push 가 정리 커밋과 쌓인 미push 인계 커밋(`pr-mode.md`「워커」 의 화면 줄 task 직렬 예외)을 원격 체인 브랜치로 올린다** — 체인 브랜치는 이미 `karina/` 브랜치라 「브랜치」 표는 건너뛰고, 3번의 `--base` 는 기본 브랜치·`--head` 는 체인 브랜치다.
  - **제목·`## 범위`·`## 화면` 은 「Y 체인 끝 PR」 의 하위 불릿 셋을 따른다(슬러그 불릿은 빼고)** — 같은 체인 끝 PR 이라 규칙을 두 곳에 두지 않는다.
- **화면 확인 대기 PR 이 남아 있어도 연다 — 보고의 `화면 확인 대기:` 의 「화면 확인 블록」 들 아래에 「그 PR 들을 먼저 merge 한 뒤 체인 끝 PR 을 merge」 를 싣는다** — 이 PR 의 head 가 체인 브랜치라, 화면 대기 PR 이 나중에 체인 브랜치로 merge 되면 그 변경이 이 PR 에 함께 실린다.
- **babysit·merge 는 하지 않고 URL 을 보고하고 끝낸다(게이트 완화 확인은 「Y 체인 끝 PR」 과 같다) — 버전은 사용자가 이 PR 을 `karina:pr` ship 으로 merge 할 때 「merge 뒤 버전 커밋」 이 한 번 올린다** — 계획 PR 의 ship 은 그 절을 건너뛰었다(`pr-mode.md`「워커」).
- **실패하면 오류 원문을 `PR:` 줄의 `체인 끝 PR:` 칸에 싣고 멈추지 않는다** — 계획 PR 들은 이미 원격 체인 브랜치에 merge 돼 있어 잃는 것은 정리 커밋 하나다.
