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

## plan 2

- BASE: 2463cef272865342843f604a98c239835e98149b (intent 커밋)
- intent: `intent/2026-10-17-pr-flow.md`
- 커밋: dd2563b4 … ed6f85fe (T1 dd2563b4 · T2 10130d36 · T6 d2284102 · T4 6d2ec01a · T5 096c5a0c · T3 dccb9ea7 · 버전 2a385e0b · 리뷰 반영 ed6f85fe) — 이 인계 커밋이 끝
- 바꾼 것
  - 새 `implement/references/pr-flow.md`: 「적용 판정」(GitHub 원격 · `gh auth status` · **중계 모드면 spec 에 `PR 모드: 켬` 줄**) · 「브랜치」(기본 브랜치 판정 `git symbolic-ref` → `gh repo view` 폴백 · 기본 브랜치면 `git switch -c pjc/<intent 슬러그>` 뒤 `git branch -f <기본> origin/<기본>` · MERGED 된 `pjc/*` 에서 시작하면 원격 기본에서 갈라 cherry-pick, 충돌이면 PR 건너뜀) · 「PR 열기」(`git push -u origin <브랜치>` refspec 명시 · OPEN PR 있으면 push 만 · `gh pr create --body-file` ready · `gh pr view` 로 확인).
  - `implement/SKILL.md`: 루프 진입 전 pr-flow.md Read · 완료 순서 「… → plan 파일 커밋(`report-format.md`「plan 파일 커밋」) → PR 열기 → 최종 보고」. plan 추적 커밋 불릿은 `report-format.md` 「plan 파일 커밋」 으로 옮겼다(11,841자). 보고 블록에 `- **PR**:` 줄.
  - 새 스킬 `pjc:pr`(`skills/pr/` — SKILL·references/babysit.md·ship.md) · 새 에이전트 `agents/pr-verifier.md`(Read·Grep·Glob·Bash). ship 은 매번 PR head 를 fetch 해 worktree 에서 pr-verifier 를 돌리고 `gh pr merge --squash --match-head-commit <sha> --subject --body-file` 로 merge, merged 를 다시 읽는다. merge 뒤 버전 전용 PR 을 잇는다(릴리즈는 승인 항목).
  - Release 정본(`docs/harness-conventions.md`): 버전 전용 PR. ⓐ PR 모드 회차는 회차 plan 에 버전 task 를 두지 않고 ship 이 `pjc/release-v<버전>` PR 을 잇는다 ⓑ PR 모드가 꺼진 회차(체인 로컬 병합)는 버전만 올린 별도 커밋. `warn-version-drift` 문구 · Hook 골든 기준선 1151 · 트리거 케이스 79(`--filter pr`) · CI push 는 main 만.
- 결정과 근거
  - 판정 코멘트는 merge 근거로 쓰지 않고 ship 마다 다시 검증한다(계획 리뷰 BLOCKER — 코멘트 작성자를 믿을 수 없다).
  - babysit 은 rebase·force push 를 하지 않고 충돌을 보고만 한다(pstack babysit 4). 고친·기각한 스레드는 `resolveReviewThread`.
- 뒤 계획이 지킬 제약
  - **implement 가 읽는 PR 모드 계약은 spec 의 `PR 모드: 켬` 줄 하나다** — plan 3 이 spec 서식(`chain-plan/references/spec-format.md`)에 이 줄을 넣어야 워커가 브랜치 전환·PR 을 한다. 이름을 바꾸면 `pr-flow.md` 「적용 판정」 도 함께 고친다.
  - **중계 + PR 모드에서 인계 절 커밋과 PR 열기의 순서가 아직 정해지지 않았다** — `relay-mode.md` 는 인계 절 커밋을 「최종 보고 직전」, `pr-flow.md` 는 push 를 「plan 파일 커밋 뒤·최종 보고 전」 에 둔다. 인계 커밋이 push 뒤에 오면 PR 에 실리지 않는다. plan 3 이 순서를 정한다(인계 커밋 → push 권장).
  - PR 모드 회차의 버전 커밋은 회차 PR 에 넣지 않는다(Release ⓐ). 브랜치 이름은 `pjc/<intent 슬러그>`.
- 미해결
  - v1.385.0 릴리즈는 사용자 승인 대상이다. 리뷰 반영 커밋 ed6f85fe 가 버전 커밋 뒤에 `plugins/` 를 고쳤으므로 릴리즈 대상은 이 회차 마지막 커밋이 맞다.
  - 실제 GitHub 에서의 PR 생성·babysit·ship·CI 1회 실행은 재설치 뒤 HUMAN-VERIFY 다.
