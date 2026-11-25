# 병렬 그룹 실행 (`karina:implement` — 독립 task 를 worktree 서브에이전트로)

> `../SKILL.md`「작업 범위」 가 이 파일을 연다 — `plan.md` `## 작업 단계` 에 `> 병렬 그룹:` 줄이 있고 루프가 그 그룹의 첫 task 차례에 닿았을 때다. 그룹 조건·서식의 정본은 `../../plan/references/parallel-groups.md` 다. 줄이 없는 plan 은 이 파일을 읽지 않고 순차로 돈다.

## 목차

- 진입
- 띄우기
- 대기
- 병합
- 순차 전환
- 정리·기록
- 기존 장치와의 관계

## 진입

- **먼저 남은 서브에이전트 worktree 를 본다 — `git worktree list --porcelain` 의 `worktree-agent-*` 브랜치마다, 미완 그룹 task 의 것이면 셋 중 하나로 처리한다** — 압축·「계속」 재개 때 체크박스가 아직 `[ ]` 라, 이것을 건너뛰면 서브에이전트가 이미 했거나 하는 중인 task 를 메인이 순차로 다시 돈다.
  - `locked` 줄이 있다 — 서브에이전트가 아직 돈다(실행 중에만 잠기고 끝나면 풀린다 — 실측 2026-11-21). 띄우지 않고 「대기」 로 간다
  - 브랜치에 그 task 완료 커밋(`{유형}: T<N> —`)이 있다 — 보고 대신 그 커밋 본문을 보고로 읽어 「병합」 ⓐ 부터 한다
  - 완료 커밋이 없다 — 브랜치·worktree 를 지우지 않고(미병합 커밋은 복구 경로가 없다) 그 task 를 「순차 전환」 하고, 최종 보고에 경로를 적는다
- **그룹 첫 task 차례에 조건을 다시 잰다 — 하나라도 거짓이면 그룹 전체를 순차로 돌리고 `판정:` 줄에 어느 조건이 거짓이었는지 남긴다** — 계획 뒤에 앞 task 가 파일을 더 고쳤거나 ignored 입력이 생겼을 수 있다. 억지로 띄우면 병합 충돌·통합 검증 실패로 순차보다 느려진다.
  - 주 트리가 깨끗하다 — `git status --porcelain --untracked-files=no` 가 빈 값
  - `git check-ignore -q .claude/worktrees/x` 가 참이다 — 무시되지 않으면 「순차 전환」 때 남기는 worktree 가 `?? .claude/` 로 4번 clean 판정에 잡혀 push 를 세운다. 이 PC 는 전역 gitignore(`core.excludesfile`)가 무시해 줄 뿐, 레포 `.gitignore` 가 보장하지 않는다(실측 2026-11-22)
  - 그룹 앞 task 가 전부 `[x]` 이고 커밋됐다 · 원격이 있으면 `git merge-base --is-ancestor origin/HEAD HEAD` 가 참이다 — 서브에이전트 worktree 는 로컬 HEAD 가 아니라 `origin/HEAD` 에서 갈라져, 프롬프트 0단계가 메인 HEAD 로 fast-forward 한다(실측 2026-11-21 — 로컬 a335de17 · worktree 7667481d). 조상이 아니면 fast-forward 가 안 된다
  - `../../plan/references/parallel-groups.md`「병렬 그룹」 의 넷 — 계획 이후 그룹 task 의 Files 가 앞 task 산출물을 가리키게 됐는지, `git status --ignored --short` 에 그 task 검증이 읽는 경로나 빌드 캐시 폴더(③ 의 이름 목록 — `check-plan` `parallel-cold` 와 같은 판정)가 새로 생겼는지 본다
- **그룹의 시작 시각을 `../scripts/work-clock.ps1` 무인자로 한 번 얻는다** — 「정리·기록」 의 경과 줄이 이 값에서 잰다.

## 띄우기

- **그룹 task 수만큼 `Agent` 호출을 한 메시지에 넣는다 — `isolation: "worktree"` · `subagent_type: "general-purpose"` · `description: "T<N> 병렬 실행"`** — 한 메시지여야 동시에 돈다. 서브에이전트는 백그라운드로 돌고 끝나면 알림이 온다.
- **프롬프트는 아래 서식을 task 마다 채운다 — task 블록은 `plan.md` 에서 그 `### T<N>.` 부터 다음 `###` 앞까지를 그대로 싣는다** — 서브에이전트는 이 프롬프트 밖의 맥락을 모른다. **번호 항목은 빼거나 줄이지 않는다 — 공통 지시문 파일을 따로 써도 같다**(2026-11-24 Karina plan 5 — 메인이 쓴 공통 지시문이 4번을 빼 서브에이전트 32개가 원본 레포 git 으로 72회 거부됐다):

  ```
  너는 karina:implement 의 병렬 task 실행자다. 아래 task 하나만 끝까지 하고 보고한다. 사용자에게 묻지 않는다.

  0. 위치: `git rev-parse --show-toplevel` 이 worktree 최상위다. 그 아래 `<메인 cwd 의 레포 상대 경로 | .>` 로 옮겨 모든 명령을 거기서 돌린다. worktree 는 `origin/HEAD` 에서 갈라졌으므로 `git merge --ff-only <메인 HEAD 전체 sha>` 로 맞추고 `git rev-parse HEAD` 가 그 sha 인지 본다. 다르거나 실패하면 정지로 보고한다.
  1. plan: <메인이 고른 갈래 하나만 싣는다>
     - (추적 파일) plan.md 는 0단계로 이미 같은 내용이다 — 사본을 만들지 않고 체크박스만 Edit 한다. 완료 커밋은 `git add <Files 경로…>` 와 경로 한정 커밋으로 plan.md 를 빼고, 커밋 뒤 `git checkout -- plan.md` 로 되돌린다.
     - (ignored) 주 plan.md 를 Read 하지 않고, 아래 두 줄과 `## task` 블록만 위 폴더의 plan.md 에 Write 한다 — `> BASE:` 는 worktree 의 커밋 hook(`guard-task-audit`·주석 게이트)이 읽는다.
       > BASE: <주 plan.md 의 값>
       > 승인: <주 plan.md 의 줄 원문>
     셸로 plan.md 를 쓰지 않는다(hook 이 막는다).
  2. 규약: `<플러그인 루트>/skills/implement/SKILL.md` 의 「자율 루프」 1~4·「검증」·「커밋」 절과 `AGENTS.md` 를 Read 해 이 task 하나에 그대로 따른다 — RED→GREEN · Acceptance·검증 줄 전부 · 체크박스 [x] 는 worktree 의 plan.md 에 · 완료 커밋 제목 `{유형}: T<N> — …` · 본문의 `Acceptance:`·`RED(구현 전):`·`GREEN:`·`검증 결과`.
  3. 하지 않는 것: 다른 task · Files 에 없는 README 갱신 · Progress Log · 회차 끝 단계 · push · 0단계 밖의 병합 · worktree 정리.
  4. git 명령은 한 호출에 하나씩, `;`·`&&` 로 잇지 않는다(worktree 샌드박스가 거부한다). 다른 레포를 읽을 때는 `git -C <경로> …` 한 호출로 하고 `cd` 와 git 을 한 호출에 섞지 않는다 — task 의 원본 파일은 이 방법이 아니라 8번 폴더에서 읽는다.
  5. 멈춤: 2의 SKILL.md 「멈추는 넷」 에 걸리거나 hook 이 안내 경로로 풀리지 않게 막거나, task 에 `**원본**` 줄이 있는데 원본대로 할 수 없다는 명령 출력이 나오면(2의 code-style.md 「원본을 옮길 때」) 그 자리에서 멈추고 보고한다. 우회하지 않고, 원본 대신 다른 안을 혼자 짓지 않는다.
  6. 임시 출력 파일(test-task·빌드·clippy 출력 · 커밋 메시지 파일)은 이름 앞에 `t<N>-` 를 붙인다 — 같은 세션의 다른 서브에이전트와 스크래치 폴더를 함께 쓴다.
  7. 판정 기준: 맨 아래 판정 기준 블록의 줄은 사용자·코디네이터가 이미 정한 것이다. task 블록과 네 판단보다 먼저 따른다.
  8. 원본: <메인이 푼 폴더 `<scratch>\origin-t<N>\` | 없음> — task 의 `**원본**` 파일은 이 폴더 아래 같은 상대 경로에 있다. Read·Grep 으로만 읽고 원본 레포에 git·cd 를 쓰지 않는다. 폴더에 없는 원본 파일이 필요하면 정지로 보고한다.

  보고(마지막 메시지):
  결과: 성공 | 실패 | 정지 — <사유 한 줄>
  브랜치: <git branch --show-current>
  worktree: <git rev-parse --show-toplevel>
  커밋: <sha7 제목> …
  검증: <명령 → 판정 줄 원문> …
  판정: <Progress Log 에 옮길 판정 줄 원문 | 없음>

  ## task
  <plan.md 의 ### T<N>. 블록 원문>

  ## 판정 기준
  <plan.md `## Next Steps` 의 `- 판정 원칙:` 줄과 `## Decisions`·`## Progress Log` 절에서 「코디네이터」 가 든 줄 원문 | 없음>
  ```

  - **프롬프트 끝의 판정 기준 블록은 메인이 띄우기 직전에 `awk '/^## /{s=$0} (s ~ /^## Next Steps/ && /^[[:space:]]*- 판정 원칙:/) || (s ~ /^## (Decisions|Progress Log)$/ && /코디네이터/)' plan.md` 로 얻어 그 줄을 그대로 싣고, 없으면 `없음` 이다 — 절로 좁히지 않으면 요구 인용·Investigation Log·task 문면까지 지시처럼 실린다** — 서브에이전트는 이 프롬프트 밖의 맥락을 몰라, 회차 중 코디네이터가 내린 지시(예: 원본대로 고칠 수 있는 것은 묻지 않고 고친다)가 닿지 않으면 라운드마다 같은 이탈을 다시 짓는다(2026-11-24 Karina plan 5 — 「하위 에이전트가 스스로 다르게 둔 것은 그때마다 재지시」).
  - **`<플러그인 루트>`** 는 `../../READONLY-SUBAGENTS.md`「플러그인 루트」 와 같은 값이다 — 하니스 루트면 레포, 아니면 설치본.
  - **1단계 갈래는 메인이 `git ls-files --error-unmatch plan.md` 로 고른다 — 성공이면 (추적 파일), 실패면 (ignored) 를 싣고 BASE·승인 줄 원문을 채운다** — 추적 레포에서 사본을 Write 해 커밋하면 완료 커밋마다 plan.md 전체가 실려 병합 때 주 plan.md 와 부딪친다(Karina plan 5 — T5·T6 완료 커밋에 plan.md 489줄). ignored 레포에서 전량을 Read·Write 하면 서브에이전트마다 33KB 를 두 번 옮긴다.
  - **8단계 원본은 task 에 `**원본**` 줄이 있고 원본이 다른 레포일 때 메인이 띄우기 전에 푼다 — `git -C <원본 레포> archive --format=zip -o <scratch>\origin-t<N>.zip <커밋> <원본 경로…>` 뒤 `Expand-Archive -LiteralPath <zip> -DestinationPath <scratch>\origin-t<N>`(`<scratch>` 는 `../../TEMP-FILES.md` 의 `scratch\` · 커밋은 `UI 재구현 기준 소스` 문서가 고정한 것, 없으면 원본 레포 `HEAD`), 원본 줄이 없으면 `없음` 이다** — worktree 격리 서브에이전트의 다른 레포 git 은 꼴에 따라 거부되고, 받아들여져도 파일마다 한 호출이다(Karina plan 5 — 거부 72회 · 뒤이은 `git -C … show` 318회). worktree 밖 임시 폴더 Read 는 막히지 않는다(같은 세션 서브에이전트의 `%TEMP%` 지시문 Read). 원본 레포가 bare 여도 `archive` 는 돌고, Git 동봉 `tar` 는 `C:` 경로를 원격 호스트로 읽어 실패하므로 zip 을 쓴다.

## 대기

- **`loop-pacing.md`「검증 대기」 와 같다 — 기다리는 동안 그룹 뒤 task 를 읽기만 하고, 편집·커밋·체크박스는 하지 않는다. 읽을 것이 다하면 turn 을 끝내고 알림을 기다린다** — 서브에이전트가 도는 동안 `loop-continue` 는 turn 종료를 대기로 본다(`../../../scripts/rules/loop-continue-rationale.md`). 주 트리를 고치면 「병합」 ⓐ 가 서지 않는다.
- **그룹 밖 순차 task 를 대기 중에 병행하지 않는다 — 코디네이터·배정문이 병행을 지시해도 같다** — 병행할 수 있는 task 였다면 계획 단계에서 그룹에 들어갔어야 하고, 대기 중 커밋은 「병합」 ⓐ 의 깨끗한 주 트리를 깨고 서브에이전트가 갈라진 HEAD 를 옮긴다(Karina plan 5 — 대기 중 T2·T3·T11 진행).
- **그룹의 모든 서브에이전트 보고가 온 뒤에 병합한다** — 경과는 가장 긴 task 가 정하므로 도착 순 병합으로 줄일 시간이 작고, 번호 순이면 판정이 재현된다.

## 병합

task 번호 순으로 하나씩 한다. 보고가 `성공` 이 아니면 그 task 는 병합하지 않고 「순차 전환」 으로 넘긴다.

- **ⓐ 주 트리가 깨끗하고 현재 브랜치가 루프 시작 브랜치인지 본다** — 아니면 병합하지 않는다. 미커밋 변경이 있으면 `merge --abort` 가 그 변경을 되살리지 못할 수 있다.
  - **미커밋이 추적 `plan.md` 하나뿐이면 `git commit -m "설정: plan 진행" -- plan.md` 로 진행 커밋을 한 뒤 병합한다 — `git stash` 로 비키지 않는다** — 되살리기를 잊거나 충돌하면 plan 편집을 잃는다(Karina plan 5 — stash 두 번, 그중 하나는 목록에서 사라졌다). 「진입」 의 깨끗한 주 트리 조건도 같은 진행 커밋 뒤에 잰다.
- **ⓑ `git merge --no-ff --no-commit <브랜치>` — 충돌(exit ≠ 0)이면 `git merge --abort` 뒤 그 task 를 「순차 전환」** — 두 task 의도를 메인이 혼자 섞지 않는다.
- **ⓒ 그 task 의 `**검증**` 줄을 합친 트리에서 다시 돈다 — 실패하면 `git merge --abort` 뒤 「순차 전환」** — 각자 worktree 에서 통과했어도 합친 결과는 아무도 재지 않았다.
- **ⓓ 경로 없는 `git commit` 으로 끝낸다 — 제목 `설정: 병합 — T<N> <한 줄>`, 본문에 ⓒ 출력 원문 · heredoc `-m` · 끝에 `2>&1`** — 병합 중에는 git 이 경로 한정 커밋을 거부해 레포의 「병행 세션의 커밋」 규약의 예외다. 제목이 `T<N> —` 로 시작하지 않아 완료 커밋 체크박스 검사에 걸리지 않는다 — 완료 커밋은 서브에이전트 커밋이다.
- **ⓔ 주 `plan.md` 의 그 task 하위 항목을 `[x]` 로 Edit 하고, 보고의 `판정:` 줄을 Progress Log 에 옮긴다** — 주 `plan.md` 가 진행 상태의 정본이고, 사본의 체크박스는 worktree 와 함께 사라진다.
- **시크릿 경고가 뜨면 `loop-exceptions.md`「시크릿 경고 오탐」 으로 가른다 — 명백한 오탐이면 판정 줄을 남기고 진행하고, 아니면 다음 병합·커밋 전에 멈춘다** — hook 경고는 비차단이라 읽을 때 병합 커밋이 이미 끝나 있다.

## 순차 전환

- **충돌·검증 실패·`실패`·`정지` 보고의 task 는 그룹의 나머지 병합이 끝난 뒤 주 트리에서 `../SKILL.md`「자율 루프」 1부터 처음 돈다** — 서브에이전트 브랜치를 cherry-pick 해 고치지 않는다. 부분 결과를 섞으면 RED·Acceptance 증거가 어느 트리에서 났는지 갈리지 않는다.
- **`정지` 사유가 「멈추는 넷」 1·3(파괴적·외부 비가역 · 인증정보 신규 외부 서비스)이면 순차로 다시 돌지 않고 그 정지를 그대로 따른다** — 실행 자리만 바뀌었을 뿐 정지 사유는 그대로다. 원본 이탈 정지도 같아, 보고의 출력을 들고 `code-style.md`「원본을 옮길 때」 의 다른 갈래(중계 `ask` · 일반 정지)로 간다.
- **같은 task 가 순차에서도 실패하면 그때부터 평소의 「실패 처리」 카운터다** — 서브에이전트 실패는 세지 않는다.

## 정리·기록

- **병합한 task 는 `git worktree remove "<worktree>"` 뒤 `git branch -d <브랜치>` 로 정리한다** — 서브에이전트가 끝나면 잠금이 풀리고, ignored `plan.md` 사본이 있어도 remove 가 된다(실측 2026-11-21). `-d` 가 미병합으로 거부하면 지우지 않고 보고에 남긴다.
- **순차 전환한 task 의 worktree·브랜치는 지우지 않고 최종 보고에 경로를 적는다** — 커밋되지 않은 시도가 남아 있을 수 있어 복구 경로가 없다.
- **그룹이 끝나면 Progress Log 에 한 줄 남긴다 — `병렬 그룹 T<a>·T<b>: 경과 <분> (가장 긴 task <분>) · 병합 충돌 <n> · 순차 전환 <task|없음>`** — 순차 대비 효과를 다음 회차가 이 줄로 견준다(대장 「독립 task 의 worktree 병렬 실행 효과 비교」).
- **그룹 task 가 기능·UI 를 바꿨는데 Files 에 README 가 없었으면, 메인이 병합 뒤 README 를 갱신해 별도 커밋한다** — 서브에이전트는 Files 밖 README 를 고치지 않는다.

## 기존 장치와의 관계

병렬 실행은 아래 장치의 동작을 바꾸지 않는다. 각 행의 정본이 그 장치의 규칙이다.

| 장치 | 병렬 그룹에서 | 정본 |
|---|---|---|
| 화면 검증 | 화면 줄 task 는 그룹에 들지 않는다(`check-plan` `parallel-task … screen`). 상주 화면 검증 에이전트는 메인만 다루고 서브에이전트는 띄우지도 요청하지도 않는다. 화면 가리기·기준선 촬영도 그룹 밖 순차 task 에서만 일어난다 | `screen-scenarios.md`「화면 시나리오 실행」 · `../../SCREEN-COVER.md`「언제 끄고 켜는가」 |
| 성능 측정 | 성능 줄 task 는 그룹에 들지 않는다 — 동시 부하가 BASE 교대 측정을 오염시킨다 | `../../PERF-MEASUREMENT.md`「성능 수치의 판정」 |
| 회차 끝 증거 대조 | `check-plan -Base` 는 `BASE..HEAD` 를 `--first-parent` 없이 읽어 병합해 들어온 서브에이전트 완료 커밋 본문을 그대로 센다 — 그래서 서브에이전트도 같은 본문 서식을 쓴다 | `final-review.md`「절차」 |
| 4번 검증·clean 줄 | 마지막 병합 커밋 뒤 메인이 평소대로 돈다 | `push-flow.md`「push 전 확인」 |
| 착수 untracked 스냅숏 | 「진입」 이 `.claude/worktrees/` 무시를 조건으로 걸어, worktree 는 스냅숏·clean 판정에 들지 않는다 | `push-flow.md`「push 전 확인」 |
| 완료 리뷰·주석 정리 | 범위가 `BASE..HEAD` 라 병합된 변경을 함께 본다 | `final-review.md`「완료 순서」 |
| 실패 카운터 | 서브에이전트 실패는 세지 않고 순차 전환 뒤부터 센다 | `loop-exceptions.md`「실패 처리」 |
