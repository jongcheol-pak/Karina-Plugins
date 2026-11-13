# 체인 인계 — run_7c21af27d9eb29ae8c266b240164fbf4

## plan 1

- **BASE**: fd7718cf · **커밋**: 10a61416…2ebea3ad (8개)
- **바꾼 파일·새 심볼·API**
  - `scripts/guard-bash.ps1` — 새 검사 `Invoke-BlockInstalledAssetWrite`(rule `block-installed-write`, `$checks` 에서 `block-plan-write` 바로 뒤) · 쓰기 구문 탐지 공유 함수 `Get-ShellWriteHits($cmd, [scriptblock]$IsTarget)`(`Invoke-BlockPlanWrite` 도 이것을 씀, `[IO.File]` 짧은 형 포함) · `Test-InstalledAssetPath` · 리터럴 `$installedWtRx`·`$installedAssetRx` · 체크박스 검사 불릿 `$planBulletRx` 사본 · 검사 계수 11종→12종
  - `scripts/guard-harness.ps1` — 경로 축을 리터럴 `$installedWtRx`·`$installedAssetRx` 로(동작 보존)
  - `scripts/rules/destructive.json` — 설치본 자산 6행 동사에 `mv|Move-Item|mi|move|Rename-Item|rni|ren|rename` · `.claude[\\/]` 뒤 `(?!worktrees[\\/])` · why 「삭제·이동」
  - `scripts/guard-stale-docs.ps1` `Get-StagedPaths` — `git diff HEAD --name-only --relative` → `--cached` → `$null`
  - `scripts/guard-commit-secrets.ps1` — `.env` 이름 판정을 `git diff HEAD --name-only`(→ `--cached`) · 커밋 세그먼트 ` -- ` 뒤 경로를 `Get-DiffHeadAdded -PathArgs` 로 내용 스캔
  - `scripts/comment-lines.ps1` — `$script:TaskAuditLineRx`·`Get-TaskAuditRules` 가 여기로 옮겨옴(guard-task-audit dot-source 제거) · `scripts/guard-task-audit.ps1` 은 `Invoke-WarnTaskAudit` 안에서 없을 때만 comment-lines 를 부르고 실패 시 경고 후 통과
  - 축 ⑯ `COPY_SYNC_GROUPS` 묶음 5→8(불릿 정규식에 guard-bash 추가 · 설치본 worktree 정규식 · 설치본 자산 경로 정규식 · `Test-WorktreeGitFile`) — 복제 사본 동기 13→20항목 · 정합 픽스처 `evals/fixtures/minimal-repo/scripts/guard-harness.ps1` 신설
  - rationale: `bash-guard-rationale.md` §15 문면·§1/§2 계수·새 §23 · `destructive-rationale.md`「설치본 하니스 자산 삭제 차단」 · `stale-docs-rationale.md` §6 · `commit-secrets-rationale.md` 새 §18 · `task-audit-rationale.md` 새 §6 · `comment-gate-rationale.md` §3 · `session-context-rationale.md` §5 · `harness-guard-rationale.md` §8 · `skills/DESIGN.md` E4
- **기준선(뒤 계획이 대조할 현재값)**: hook 골든 1848케이스(`run-hook-evals.ps1` · `harness-conventions.md` · `golden-runner.md`) · `hook-cases.json` 380건 · evals 골든 164케이스 · 복제 사본 동기 20항목
- **내린 결정과 근거**: 설치본 셸 쓰기는 guard-bash 새 검사(갈림 1) · 파서 이동(갈림 2) · 커밋 대상 `git diff HEAD`(갈림 3, 미스테이징 과경고 수용 — task-audit 선례) · 서브모듈 경계는 기록만(갈림 4, `docs/decisions.md` 2026-11-13) · `-- <경로>` 시크릿 내용 스캔 추가(판정 원칙 — 미탐 보완)
- **뒤 계획이 지킬 제약**
  - plan 2 몫: `bash-guard-rationale.md` §2 의 차단 경로 수 문단(`Block = $true` 를 내는 경로는 다섯 · 10검사 중 4종 · 경고 전용 6종)은 낡았다 — 이 계획이 `block-installed-write` 차단 경로 1개를 더했다(현재 guard-bash 안 차단 검사: require-task-checkbox · block-plan-write · block-installed-write · bash-backslash · block-python-newcode, `check-block-coverage.py` 의 「guard-bash 경로 5」). 경로 수는 `python hooks/evals/check-block-coverage.py` 로 다시 잰다
  - guard-bash 무상태 골든 케이스는 dispatch 에코로 1건이 2로 센다 — hook-cases 에 guard-bash 케이스를 더하면 기준선은 2배로 는다
  - 설치본 판정 리터럴을 바꾸면 guard-harness·guard-bash·정합 픽스처 셋을 함께 바꾼다(축 ⑯)
- **미해결**: `git commit <경로>`(`--` 없이) 의 시크릿 내용 스캔 — 보류(`docs/decisions.md` 2026-11-13 ②)

## plan 2

- **BASE**: a85b0fca · **커밋**: 750caff2…e8be387e (12개)
- **바꾼 파일·새 심볼·API**
  - `scripts/post-write-checks.ps1` — 영문 주석 경고 문구(「이 파일의 기존 주석 언어(영문)를 따르세요」) · :132 주석을 `post-write-rationale.md` §16 포인터로
  - `skills/plan/scripts/check-plan.ps1` — B3 하위 항목 마커 `[ /xX~-]`(완료 판정 :162 와 같음)
  - `skills/temp-cleanup/scripts/temp_cleanup.py` — `remove` 가 상대경로를 `--root` 기준으로 읽음 · eval `Fixture.run(cwd=)`
  - 문서: bash-guard·hook-dispatch·post-write rationale · gate-verifier-conditional(이름-따옴표 조건) · local-gate(입력 직전 판정·출력 파일 단일) · continuation · completion-reviewer(게이트 대기 입력·전사 대조 포인터) · plan 스킬(G·S·C·경량 셈법·재호출 조건 포인터 · Open Questions 「리뷰(check-plan) 전까지」 · rare-paths 「승인 답 갈래」 절 삭제) · no-comments · create(-formal)-verification-skill · relocate-agents 안내 · TEMP-FILES scratch 지목 4곳
- **기준선(뒤 계획이 대조할 현재값)**: hook 골든 1851케이스 · 트리거 eval 84케이스 · temp-cleanup 13케이스 · Deferred 대장 대기 18 / 종결 120 · 문서 예산 임박 9건(plan/SKILL 여유 952 · plan-template 여유 477 · completion-reviewer 여유 249 · interview 여유 636)
- **내린 결정과 근거**: 영문 주석 경고는 발동 조건 불변·문구만(새·기존 주석 판정 신설은 동작 변경) · 중복 정본은 앞선 정본을 남기고 사본을 포인터로 · 게이트 출력 파일은 local-gate「호출」 의 것 하나 · block-python-newcode 오탐은 미검증 보고 + 대장 등재(코디네이터 판정 A)
- **뒤 계획이 지킬 제약**
  - plan 3 이 재측정할 local-gate·review-rounds·interview 는 이 계획이 고쳤다 — local-gate「호출」 입력·「FAIL 처리」 문장, review-rounds:14, plan-template「경량 plan」·Open Questions
  - `python` 으로 픽스처 문자열을 쓰는 eval(run_verify_evals·test_exit_code·trigger_eval)은 Bash 도구에서 block-python-newcode 에 막힌다 — 우회 금지, 미검증 보고(`docs/conventions.md` 2026-11-13)
  - 골든 케이스를 더하면 기준선 셋(`run-hook-evals.ps1` `$GoldenTotalBaseline`·`golden-runner.md`·`harness-conventions.md`)을 함께 바꾼다
- **미해결**: block-python-newcode 오탐(대장 등재) — 이 계획의 미검증 3건(run_verify_evals.py · test_exit_code.py · trigger_eval.py rec-neg-5)
