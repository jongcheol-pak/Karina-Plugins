# warn-screen-busy 근거

> `scripts/warn-screen-busy.ps1` 과 `skills/implement/scripts/screen-wait.ps1` 의 주석이 가리키는 근거다. 조항↔hook 대응은 `skills/DESIGN.md` 「5. hook이 강제하는 것」 E25 행이다.

## §1 왜 경고하는가

`karina:implement` 는 검증을 기다리는 동안 다음 task 를 읽기만 한다(`skills/implement/references/loop-pacing.md`「검증 대기」). 화면 검증 에이전트(`karina:screen-verifier`)가 앱을 빌드·조작하는 동안 메인이 같은 레포 파일을 고치면, 에이전트가 판정 중에 더러운 작업 트리를 빌드하고 다음 task 변경과 결함 수정이 한 빌드·커밋에 섞인다.

**재발이다(2026-11-26)** — Karina 세션 1518c748 의 implement 루프가 검증 에이전트 실행 중 3구간 넘게 소스·`plan.md` 를 Write·Edit 했다(전사 요약 854→864~903 Write 10건 · 1221 검증 에이전트 실행 → 1297 Edit 외 5건 · 4279 에이전트가 판정 중 dirty 트리 보고). 그때 「검증 대기」 첫 불릿은 골든 러너·60초 이상 명령만 지목해 검증 에이전트 요청이 문면 밖이었다. 문면을 넓히는 것과 함께 편집 순간에 경고를 싣는다.

- **경고다 — 차단이 아니다(요구 원문)** — `exit 0` 에 stderr 와 `additionalContext` 로 같은 안내를 싣는다. 편집은 되돌릴 수 있고, 표지 판정을 hook 이 틀리면 정당한 편집이 막힌다.
- **쓰기 디스패처의 권고 구간(`advisory:` 뒤)에서 돈다** — 차단 구간에 두면 경로 탐색이 멈출 때 묶음 timeout 과 `onFailure: block` 으로 정당한 Write 가 막힌다. 권고 구간은 별도 runspace·마감으로 보호되고, 앞의 차단 스크립트가 막은 편집에는 경고할 까닭이 없다(`hook-dispatch-rationale.md` §7 · 2026-11-26 완료 리뷰).

## §2 표지 — 누가 쓰고 언제 무효가 되는가

표지는 `<임시 루트>/karina-plugin/screen-busy/<PID>.json`(`pid`·`root`·`started`)이다. 임시 루트는 공용 `Get-KarinaTempRoot`(TMPDIR→TEMP→TMP)다.

- **모델이 직접 쓰고 지우지 않는다** — 「완료 알림에서 지운다」 를 모델에 맡기면 규칙을 어긴 그 모델이 지우기도 빠뜨린다. 대신 검증 에이전트 요청마다 이미 띄우던 시한 타이머(`sleep 1200` 백그라운드 셸)를 `screen-wait.ps1` 로 바꿨다(`skills/implement/references/screen-scenarios.md`「화면 시나리오 실행」). 그 스크립트가 표지를 쓰고 sleep 하며 끝나면 지운다.
- **응답이 오면 메인이 그 셸을 `TaskStop` 으로 끈다 — 지금까지와 같다.** `TaskStop` 은 셸의 pwsh 자식까지 끝낸다(2026-11-26 실측 — 백그라운드 `pwsh … Start-Sleep 300` 을 TaskStop 한 뒤 `Get-Process -Id` 가 DEAD). 그래서 표지는 **그 PID 가 살아 있을 때만** 유효하고, 지우지 못하고 남은 표지는 hook 이 PID 를 보고 걸러 지운다.
- **`started` 가 1,500초를 넘으면 PID 와 무관하게 무효다** — 타이머 1,200초에 여유를 둔 값이다. PID 재사용으로 남은 표지가 살아 보이는 경우를 막는다.
- **레포 해시 파일명을 쓰지 않는다** — 쓰는 쪽과 읽는 쪽에 해시 규칙이 갈라 앉는다. 표지는 많아야 몇 개라 읽는 쪽이 폴더를 훑는다.

## §3 언제 경고하는가

넷이 모두 참일 때만이다. 판정할 수 없으면 침묵한다.

- **입력에 `agent_id` 가 없다** — 서브에이전트 안의 편집은 메인 루프가 아니다(`worktree-delegation-rationale.md` §2 와 같은 거름).
- **표지 폴더가 있다** — 없으면 즉시 끝난다. Write·Edit 마다 도는 hook 이라 이 검사 하나가 평소 비용의 전부다.
- **살아 있는 표지가 있다** — §2 의 PID·시한 판정.
- **대상 경로의 레포 루트가 표지의 `root` 와 같다** — 루트는 대상 폴더에서 위로 올라가 처음 만나는 `.git` 폴더 또는 worktree `.git` 파일(`Test-WorktreeGitFile` — `write-gate-rationale.md` §25)의 폴더다. 병렬 그룹 서브에이전트의 worktree 는 다른 루트라 경고하지 않고, 서브모듈 `.git` 파일은 경계로 보지 않는다. 프로세스를 띄우지 않고 파일시스템만 본다. 비교는 경로 구분자를 `\` 로 맞추고 대소문자를 무시한다.
