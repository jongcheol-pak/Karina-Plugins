# 임시 파일 폴더

> karina 스킬·스크립트가 시스템 임시 폴더에 만드는 파일의 자리를 정하는 공용 규칙이다. 경로를 쓰는 문서(plan 인터뷰·초안·삭제 복구, prototype 시안, chain-plan 결정·재개·검증, worktree-cleanup, 검증 스킬 생성·유지, temp-cleanup)가 이 파일을 가리킨다. 임시 폴더 바로 아래 흩어지면 무엇이 karina 것인지 가를 수 없고 정리할 대상도 정해지지 않는다.

## 루트

- **모든 임시 산출물은 `%TEMP%\karina-plugin\` 아래 하위 폴더에 둔다 — 임시 폴더 바로 아래에 파일·폴더를 만들지 않는다.**
- **루트는 Python 이면 `os.path.join(tempfile.gettempdir(), 'karina-plugin')` 이다. PowerShell 은 `TMPDIR`→`TEMP`→`TMP` 순으로 있는 폴더를 찾고, 없을 때만 `[IO.Path]::GetTempPath()` 를 쓴다** — `GetTempPath()` 는 Windows 에서 `TMP` 를 먼저 읽고 Python 은 `TEMP` 를 먼저 읽어, 두 값이 다른 환경에서는 스크립트가 쓰는 폴더와 정리가 보는 폴더가 갈린다.
- **쓰기 전에 하위 폴더를 만든다**(Python `os.makedirs(..., exist_ok=True)` · PowerShell `New-Item -ItemType Directory -Force`). 처음 쓰는 세션에는 폴더가 없다.
- **보고·plan·PR 본문에 싣는 경로는 `%TEMP%\karina-plugin\…` 로 적는다** — 사용자 홈 경로가 공개 PR 과 커밋에 남지 않게 한다.

## 하위 폴더

| 폴더 | 무엇을 두는가 | 이름 |
|---|---|---|
| `chain\` | chain-plan 대기·검증 래퍼의 잠금·상태·시도 로그, 체인 결정 파일 | 스크립트가 정한 접두(`karina-chain-wait-`·`karina-chain-verify-`) · `karina-chain-<Run id>-decisions.md` |
| `plan-variants\` | plan 인터뷰·`karina:prototype` 의 화면 변형 HTML·스크린샷 | `<YYYYMMDD-HHmm>\` 아래 변형마다 파일 |
| `verify\` | 검증 스킬(`verify-<app>`)의 증거·실행 데이터 | `<app>\<실행 id>\` |
| `backup\` | plan.md·초안 백업, 복구 경로 없는 파일을 지우거나 덮기 전 백업 | `<원래 이름>-<레포 폴더명>-<YYYYMMDD-HHmm>.<확장자>` |
| `worktree-backup\` | `karina:worktree-cleanup` 이 지우기 전에 복사한 미추적·ignore 파일 | `<레포 이름>\<worktree 이름>-<시각>\`(스크립트가 정한다) |
| `scratch\` | 실험·실행용 일회성 스크립트 · `karina:prototype` 의 동작·아키텍처 스케치 · `check-plan` 의 Plan check 로그(`check-plan-<시각>.log` — 위반 줄이 파일 이름을 가리킨다) | 자유 — 다시 가리키지 않는 파일만 |

## 누가 지우는가

- **직접 지우지 않는다.** 기한이 지난 것은 아래 두 곳이 지우고, 그 밖은 사용자가 `/karina:temp-cleanup` 으로 고른 것만 지운다.
- **세션 시작 정리** — `scripts/session-context.ps1` 이 `plan-variants\`·`verify\`·`scratch\` 와 `chain\` 의 결정 파일을 기한(값은 그 스크립트의 표가 정본이다)이 지나면 지운다. 화면 변형·증거는 PR merge 전 화면 게이트와 체인 보고가 경로를 다시 보이므로 쓴 직후에 지우지 않는다.
- **체인 스크립트** — `wait-worker.py`·`run-verify.py` 가 시작할 때 `chain\` 의 자기 접두 파일만 기한이 지나면 지운다.
- **백업 두 폴더(`backup\`·`worktree-backup\`)는 자동으로 지우지 않는다** — 원본이 사라진 뒤의 유일한 사본일 수 있다.
