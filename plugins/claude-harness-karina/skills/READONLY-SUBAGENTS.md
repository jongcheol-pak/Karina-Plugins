# 읽기 전용 서브에이전트 사후 확인

> 일곱 호출부가 가리키는 공용 규칙이다 — `implement/references/final-review.md`(completion-reviewer) · `no-comments/SKILL.md`(comment-reviewer) · `pr/references/ship.md`(pr-verifier) · `chain-plan/references/stack-mode.md`(pr-verifier — 계획별 검증) · `plan/references/measure-delegation.md`(Explore) · `chain-plan/references/measure.md`(Explore) · `maintain-verification-skill/SKILL.md`(Explore 웨이브). 읽기 전용이라고 정한 서브에이전트가 `Bash` 를 가지면 셸로 파일을 바꿀 수 있어, 그 서브에이전트를 부르기 전후에 이 절을 그대로 거친다.

## 호출 전후 확인

- **브리프에 「파일을 고치지 말 것」 을 적는다 — 에이전트 정의가 이미 읽기 전용을 말하면 생략한다** — 내장 Explore 처럼 편집 도구만 빠지고 `Bash` 는 남은 에이전트는 정의만으로 쓰기를 막지 못한다. Cursor pstack 의 Claude Code 안내 *"It keeps `Bash`, so the brief also says "do not edit files", and you check `git status` afterward."* 를 들였다(`https://github.com/cursor/plugins/blob/8b3326d99fd4b993cb33a24dad8af03175c642c5/pstack/docs/harness/claude-code.md`).
- **잴 작업 트리는 서브에이전트가 쓸 수 있는 사용자 작업 트리다** — 보통 호출한 세션의 작업 트리이고, 서브에이전트가 다른 대상 레포에서 돌면 그 레포의 작업 트리다. 스킬이 검증용으로 따로 만든 worktree 안의 변경은 검증 명령이 남긴 정상분이라 재지 않는다(pr-verifier 는 호출한 세션의 작업 트리를 잰다).
- **호출 직전과 직후에 같은 스냅샷을 잡아 대조한다** — 그 작업 트리 안 어디서든 아래 명령 하나의 출력이 스냅샷이다. 레포 루트로 옮겨 도는 것은 `git ls-files` 가 현재 디렉터리 아래만 현재 디렉터리 기준 경로로 내는데 `hash-object` 는 루트 기준으로 열어, 하위 디렉터리에서 돌면 루트 쪽 변경을 놓치거나 exit 128 로 끝나기 때문이다.

  ```
  ( cd "$(git rev-parse --show-toplevel)" && git rev-parse HEAD && git status --porcelain=v1 -z --untracked-files=all | tr '\0' '\n' && L=$(git ls-files -z -m -o --exclude-standard | tr '\0' '\n' | while IFS= read -r p; do if [ -f "$p" ]; then printf '%s\n' "$p"; fi; done) && { [ -z "$L" ] || printf '%s\n' "$L" | git hash-object --stdin-paths | paste -d ' ' - <(printf '%s\n' "$L"); } )
  ```

  HEAD 가 다르거나, 상태 줄이 다르거나, `<해시> <경로>` 줄이 다르면 그 차이가 바뀐 경로다 — 해시 줄마다 경로를 붙여 어느 파일인지 바로 읽힌다. 상태 줄만 비교하면 이미 미커밋인 파일을 더 고친 경우가 같은 줄로 남아 놓치고, 상태 코드를 빼면 인덱스만 바뀐 경우를, HEAD 를 빼면 깨끗한 트리에서 커밋·체크아웃한 경우를 놓친다. `--untracked-files=all` 이 없으면 untracked 폴더가 한 줄로 접혀 그 안의 새 파일을 놓친다. 해시는 워킹트리에서 바뀐 파일과 untracked 파일 가운데 실재하는 것만 낸다 — 삭제·rename 은 상태 줄로 잡고, 없는 경로를 해시 입력에 넣으면 `hash-object` 가 `fatal: could not open` 으로 끝나 그 뒤 경로의 해시가 빠진다.
- **git 이 무시하는 경로(예: `plan.md`)는 이 스냅샷에 나오지 않는다** — 그 경로의 변경은 이 확인으로 잡지 못한다는 한계를 안고 쓴다.

## 바뀐 경로가 있으면

- **되돌리지 않고 그 경로를 보고에 싣는다** — 병행 세션이 같은 작업 트리에 쓴 변경도 차이로 잡히는데, 서브에이전트가 바꾼 것인지 가를 수 없어 자동으로 되돌리면 남의 작업을 지울 수 있다.
- **싣는 자리는 호출부마다 정해져 있다**
  - `karina:implement`(completion-reviewer) — `## Progress Log` 에 `판정: 서브에이전트 호출 뒤 작업 트리 변경 — <경로> — 되돌리지 않음 — 근거: 없음 — 틀리면: 그 변경이 다음 커밋에 섞인다` 줄. 최종 보고 「판정」 이 이 줄을 그대로 옮긴다.
  - `karina:plan`(measure-delegation, 또는 Step 5 가 띄운 chain-plan measure) — Investigation Log 에 `서브에이전트 작업 트리 변경` 행.
  - `karina:chain-plan` 코디네이터(measure) — 체인 승인 제시에 `작업 트리 변경 — <경로>` 한 줄.
  - `karina:no-comments`·`karina:pr` ship·`karina:maintain-verification-skill` — 그 스킬의 「보고」 에 `작업 트리 변경 — <경로>` 한 줄. `karina:no-comments` 자동 모드는 위 `karina:implement` 줄과 같다.
- **완료 보고의 「남은 이슈」 에는 싣지 않는다** — 그 줄은 판정 마커(`[등재]`·`[다음 회차]`)를 단 항목만 싣는 자리다(`implement/references/report-format.md`「「남은 이슈」의 판정」).
