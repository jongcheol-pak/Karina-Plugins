# 체인 인계 — run_dc17831bee9d0a704fe7906ff6b16ee9

## plan 1

- BASE: ba645be4 · 커밋 2cc9830a…9e4eb1ed (14커밋 — T1~T9 · 주석 정리 · 회차 끝 기록 · 완료 리뷰 수정 2)
- 바꾼 파일·새 심볼·API:
  - 새 파일 `scripts/plan-round.ps1` — `Find-SinglePlanUpwards`·`Test-WorktreeGitFile`(guard-bash 에서 옮김) · `Test-ActivePlanRound($PlanFile, $Now)`(`> 승인:` 날짜가 있고 `> 완료:` 가 없거나 오늘이면 참). `harness-hooks.json` names 에 `plan-round` 추가. guard-bash 는 상시 dot-source(없으면 커밋 명령 차단), guard-write·post-write-checks 는 `try` dot-source(없으면 「진행 중 아님」).
  - `scripts/git-commit-match.ps1` — `Invoke-CommitGit -Check <검사>`(캐시 · 호출당 상한 `KARINA_COMMIT_GIT_TIMEOUT_MS` 기본 20000 · 한 hook 안 첫 시간 초과를 모든 검사가 공유) · `Test-CommitGitTimedOut` · `Get-CommitGitTimeoutLines`. 네 커밋 라이브러리의 git 호출이 전부 이것을 거친다. `scripts/timed-git.ps1` 결과에 `TimedOut` 필드 추가.
  - `scripts/guard-bash.ps1` — 커밋 라이브러리 로드 조건 `$script:GitCommitRx` · 캐시 래퍼 `Get-TopLevelSegments`·`Get-HeredocSinkStripped` · require-task-checkbox 하위 ID(`T4-1`) 판정과 차단 안내(「Edit 로 [x] → 별도 호출로 commit」 — `CLAUDE_HARNESS_QUICK` 안내 줄 삭제, 변수 동작은 유지) · warn-external-ops 가 회차 진행 중 `approval: context` 군 경고 생략.
  - `scripts/guard-write.ps1` G4 · `scripts/post-write-checks.ps1` EOL(autocrlf=true·index LF 면 무경고)·IMPACT(바뀌거나 사라진 선언만)·hook 리마인더(회차 중 생략).
  - `skills/no-comments/scripts/comment-scope.ps1` — git 대기 상한 `KARINA_SCOPE_GIT_TIMEOUT_MS`(기본 60000) · 넘기면 exit 2.
  - `evals/check-harness-consistency.py` 축 ⑧ — autocrlf=true·index `i/lf` 파일은 bare CR 만 · `evals/run-evals.py` 케이스 필드 `git_config`(기본 `core.autocrlf false`).
  - `AGENTS.md` 「줄바꿈」 — CRLF 요구 완화(bare CR 만 금지).
- 내린 결정과 근거: plan 1 이 `docs/decisions.md` 에 쓴 2026-11-14 hook 속도·오탐·소음 수정 줄 · 커밋 본문.
- 뒤 계획이 지킬 제약:
  - 스킬 문서가 require-task-checkbox 를 서술하는 자리(`skills/implement/SKILL.md`·`skills/implement/references/final-review.md`「절차」 등)는 이제 하위 ID 완료 커밋이 그 줄만 보고, 차단 안내가 「Edit 로 [x] → 별도 호출로 commit」 이다 — plan 2 가 그 문면을 맞출 때 이 동작을 기준으로 한다.
  - 회차 진행 중 판정(`Test-ActivePlanRound`)은 plan.md 의 `> 승인:`·`> 완료:` 줄 서식에 기댄다 — 그 서식을 바꾸면 이 함수와 골든(`hooks/evals/scenarios/guard-bash.ps1`·`guard-write.ps1`·`post-write-checks.ps1` 의 plan-round 케이스)을 함께 고친다.
  - 버전은 올리지 않았다(체인 마지막 계획 몫). 골든 기준선 1910 · eval 166.
- 미해결 사항: 커밋 판정 콜드 시간은 줄지 않았다(BASE 1200 · HEAD 1248ms, 범위 겹침 — 호출당 `Process.Start` 비용). 대장 2026-11-14 「차단 로그에 막은 줄 미리보기」(사용자 보류).
