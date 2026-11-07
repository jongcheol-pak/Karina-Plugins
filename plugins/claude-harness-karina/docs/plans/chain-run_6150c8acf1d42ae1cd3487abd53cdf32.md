# 체인 인계 — run_6150c8acf1d42ae1cd3487abd53cdf32

## plan 1

- BASE: bbd30c6e · 커밋 df2103d5…773cde0e (T1 df2103d5 · T2 59ee38da · T3 146d7942 · T4 871adfa3 · T5 ccfea1a6 · 주석 정리 773cde0e)
- 바꾼 파일: `scripts/rules/destructive.json`(force-with-lease 패턴 — 브랜치 무관 차단 · 사유 「브랜치와 무관하게 차단(lease 도 원격 히스토리를 덮어쓴다)」) · `scripts/guard-bash.ps1`(`Test-PlanTarget` 이 `(^|[\\/])plan\.md$` · 따옴표 리다이렉션 대상 · pathlib 탐지 `pathlib` 히트) · `hooks/evals/hook-cases.json`(333건) · `hooks/evals/scenarios/guard-bash.ps1`(bpw 29건) · 골든 기준선 1530(`run-hook-evals.ps1:484` · `docs/golden-runner.md:35` · `docs/harness-conventions.md:50`) · `scripts/rules/destructive-rationale.md` · `scripts/rules/bash-guard-rationale.md` §10 · `README.md` · `docs/harness-conventions.md`(:76 ③④ 선례 · :320) · `skills/implement/SKILL.md` · `skills/implement/references/{push-flow,local-gate,report-format,code-style}.md` · `skills/plan/references/plan-template.md` · `skills/prototype/SKILL.md` · `skills/no-comments/SKILL.md` · `skills/chain-plan/references/run-verify-rationale.md` · `skills/create-verification-skill/references/feature-map-example/README.md` · `skills/{create,maintain}-formal-verification-skill/SKILL.md` · `skills/karina-systematic-debugging/references/investigation-log.md` · `agents/comment-reviewer.md`
- 레포 밖: 글로벌 `~/.claude/CLAUDE.md` 7.27.0 — 예외 3 삭제(예외는 1·2만) · 백업 `%TEMP%\karina-plugin\backup\CLAUDE.md.20261107-1120`
- 새 심볼·API: 없음
- 내린 결정: karina/ force-with-lease 면제 폐지(사용자 지시) · plan.md 대상은 경로 구분자 뒤 plan.md 로 끝나는 인자 · pathlib 변수 경유는 한계 · no-comments 동작 유지(문구만 「원문보다 보수적」) · pstack 출처는 고정 커밋 ae5650fe URL
- 뒤 계획이 지킬 제약: 골든 케이스를 더하거나 빼면 기준선 세 자리를 함께 고친다(`harness-conventions.md:50` 은 `--fix` 대상이 아니다) · force-with-lease 면제를 다시 말하는 문면을 넣지 않는다 · 버전은 올리지 않았다(체인 마지막 계획 몫)
- 미해결: 없음

## plan 2

- BASE: 58a312ba · 커밋 baedfed2…8da4369c (T1 baedfed2 · T2 6e0ac226 · T3 996da010 · T4 e9447600 · T5 610fa8fd · T6 9cff2bad · T7 e1fba3a7 · T8 b2284ded · T9 0eb0d9ef · T10 f6e96023 · T11 8da4369c)
- 바꾼 파일: `skills/chain-plan/SKILL.md`(:81 wait-worker `--repo "<작업 폴더 경로>"` · :85 `<작업 폴더 경로>` 정의 · :90 병렬 탭 닫기 예외) · `skills/chain-plan/references/{spec-format,parallel,release,report,continuation,resume,chain-decisions,chain-end-push}.md` · `skills/plan/references/{relay-mode,review-rounds}.md` · `skills/implement/references/{push-flow,local-gate,final-review}.md` · `skills/implement/SKILL.md`(:21 — 11223자) · `skills/plan-draft/SKILL.md` · `skills/reflect/SKILL.md` · `docs/harness-conventions.md`(:80 · 조건부 참조 표 57,794)
- 새 심볼·API: spec 서식 키 `작업 폴더:` · 문서 경로 이름 `<작업 폴더 경로>`(= `<대상 레포 경로>/<작업 폴더>` — plan.md·AGENTS.md·인계·검증 cwd 자리만, 그 밖은 `<대상 레포 경로>` 최상위)
- 내린 결정: 체인 버전은 한 번(마지막 계획이 병렬 그룹원이면 그 그룹 마지막 워커) · 체인 끝 FAIL 이어받기는 `git show <정리 커밋>^:./<인계>` 로 읽고 인계 절 안 씀 · 원격 없으면 기본 브랜치 init.defaultBranch → main → master, 미정이면 게이트는 돌고 판정만 보고·push 안 함(코디네이터 판정) · 비기본 브랜치·작업 폴더 ≠ . 이면 병렬 없음 · 재개는 M ≥ N 부모 줄을 옮기지 않음 · plan 1 부모 줄 없으면 체인 끝 push 보류 · digest·check-plan 은 비0 종료 전부를 실패 갈래로
- 뒤 계획이 지킬 제약: `docs/harness-conventions.md` 를 고치면 `python evals/check-harness-consistency.py --fix` 로 조건부 참조 표를 같은 task 에서 갱신 · implement/SKILL.md 여유 777자(12000 상한) · 절 이름(「버전」·「닫기」·「멈춤」·「체인 끝」 등)은 바꾸지 않았다 · 버전은 올리지 않았다(체인 마지막 계획 몫)
- 미해결: 없음
