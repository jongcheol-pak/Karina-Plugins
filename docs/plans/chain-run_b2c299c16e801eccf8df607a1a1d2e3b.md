# 계획 체인 인계 — run_b2c299c16e801eccf8df607a1a1d2e3b

## plan 1

- BASE: 301476194123970ea348dbcd6588c9e5e10b8ed4 (intent 커밋)
- intent: `intent/2026-10-17-pstack-autonomy-permissions.md`
- 커밋: b06ed0ec … 9ecb6e73 (T2 b06ed0ec · T3 6846c9f2 · T4 c166e544 · T5 a99d9e20 · 버전 6f9d05b0 · 리뷰 반영 9ecb6e73) — 이 인계 커밋이 끝
- 바꾼 것
  - 글로벌 `~/.claude/CLAUDE.md` 7.14.0(레포 밖 · 백업 `%TEMP%\CLAUDE.md.bak-2026-10-17-pstack-autonomy`): 「스킬·계획 우선」 항상 승인 목록이 `외부·비가역 작업(태그·릴리즈·배포)` 로 줄었다. push·PR 생성·PR 코멘트·PR merge·로컬 병합은 발동된 스킬·승인된 plan 안이면 무승인이고, 일반 작업이면 「Git」 대로 승인이다. 예외 3 을 신설했다 — 자기 `pjc/` 브랜치를 이름으로 지정한 `git push --force-with-lease origin pjc/<이름>` 과 그 브랜치 rebase 는 무승인.
  - `implement/SKILL.md` 「멈추는 넷」 1번 · 커밋 절, `plan/references/plan-template.md` 「승인 필요 항목」 이 같은 기준이다(문구 `push·PR 생성·PR 코멘트·PR merge·로컬 병합` · `자기 \`pjc/\` 브랜치 rebase 제외`).
  - `scripts/rules/external-ops.json`: 항목 필드 `"approval": "context"`(push·merge·`gh pr create`·`gh pr comment`·`gh pr merge`) — 생략하면 always. 문면 키 `contextBody`·`alwaysBody`(옛 `externalBody` 삭제). `guard-bash.ps1` 는 같은 세그먼트 `--help` 를 `--dry-run` 처럼 조회로 본다.
  - `scripts/rules/destructive.json`: `--force(?![-\w])` 차단 + `--force-with-lease` 는 원격 다음 refspec 이 전부 `(<src>:)?(refs/heads/)?pjc/<이름>` 일 때만 통과(끝 리다이렉션 하나 허용 · `--all`·`--mirror`·`--tags`·`HEAD`·혼합·브랜치 생략 차단).
  - 안전 임계 hook 허용 종류에 셋째 「사용자 지시의 범위 축소」(`AGENTS.md` DO NOT · `docs/harness-conventions.md` :38·:66 · `write-gate-rationale.md`).
  - Hook 골든 기준선 1150 · `hook-cases.json` 296건.
- 결정과 근거
  - 무승인은 승인된 plan·발동된 스킬 안으로 한정한다(코디네이터 판정 E 1 — 재진술 결과 첫 문장).
  - 외부 작업 경고는 push·merge·PR 을 목록에 남기고 문구로 가른다(코디네이터 판정 E 2 — hook 은 plan·스킬 맥락을 모른다).
  - 글로벌 예외 1(vault)·2(체인 worktree 병합)는 지우지 않았다 — `llm-wiki/SKILL.md` 가 예외 1 실재로 push 를 판정하고, chain-plan 이 예외 2 를 이름으로 부른다.
- 뒤 계획이 지킬 제약
  - `pjc/` 브랜치 이름 규약은 아직 문서화되지 않았다 — `destructive-rationale.md` 「자기 `pjc/` 브랜치의 force-with-lease」 가 plan 2(implement 브랜치 전환)가 도입한다고 적었다. plan 2 는 에이전트 브랜치 이름을 `pjc/<이름>` 으로 정해야 이 통과와 맞는다.
  - push 명령은 refspec 을 명시해야 `pjc/` force-with-lease 가 통과한다(브랜치 생략·`HEAD` 는 막힌다).
  - 태그·릴리즈·배포는 plan·스킬 안에서도 승인이다 — Release 를 PR 로 바꾸더라도 릴리즈 발행은 승인 대상으로 남는다.
- 미해결
  - 설치본은 1.382.0 이다. 이 회차의 스킬·hook 변경은 push → 릴리즈 → `/plugin update` 전까지 plan 2·3 워커에 적용되지 않는다(글로벌 지침만 즉시 반영). 릴리즈는 사용자 승인 대상이다.
