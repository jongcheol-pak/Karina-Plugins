# 기본 브랜치 push

> `karina:implement` 가 **루프 진입 전 1회**와 **회차 끝 1회** 읽고, `karina:karina-systematic-debugging` 이 직접 고칠 때(「디버깅 단독 경로」) 읽는다. 시작과 끝에만 쓰이는 절차라 `../SKILL.md` 본문에 두지 않는다.
>
> 목차: 기본 브랜치 push · 디버깅 단독 경로(갈래 · 커밋)

## 기본 브랜치 push

**브랜치를 바꾸지 않고 worktree 를 만들지 않고 지금 브랜치에 커밋한다 — PR 은 열지 않는다** — 혼자 쓰는 하니스라 변경을 받을 리뷰어가 없어 브랜치가 시간만 든다(사용자 결정 2026-11-07). push 전 검증은 `local-gate.md` 가 맡는다. 이 절이 정본이고, 다른 스킬은 이 절을 가리킨다. **경로를 생략하지 않는다** — `karina:chain-plan` 코디네이터는 대상 레포 밖에서 돌 수 있어, 아래 git 명령은 대상 레포가 지금 폴더가 아니면 `git -C "<대상 레포 경로>"` 로 돈다.

- **회차 끝에 지금 브랜치가 기본 브랜치이고 `origin` 이 있으면 `local-gate.md`「회차 끝 게이트」 를 거쳐 `git push origin <기본>` 을 1회 한다** — 기본 브랜치는 git 만으로 정한다: `git symbolic-ref --short refs/remotes/origin/HEAD` 의 `origin/` 뒤, 실패하면 `git ls-remote --symref origin HEAD` 의 `ref: refs/heads/<이름>`. 원격이 없으면 `git config init.defaultBranch` 값이 로컬 브랜치로 있으면 그것, 없으면 `main` · `master` 순으로 있는 것(`git rev-parse --verify -q refs/heads/<이름>`)이고, 둘 다 없으면 「기본 브랜치 미정」이다 — 게이트는 돌아 판정만 보고하고 push 결과는 `건너뜀(기본 브랜치 미정)` 이다(사용자 답 「설정 → main·master」). 원격이 없으면 push 하지 않는다. **기본 브랜치가 아니면 push 하지 않고, 중계 모드가 아니면 커밋이 기본 브랜치에 없다는 사실을 보고의 「기다리는 것」 에 `기본 브랜치에 없는 커밋 — <브랜치> · <git rev-list --count <기본>..HEAD>개 · 병합은 사용자 · 병합 뒤 기본 브랜치에서 게이트를 거쳐 push` 로 싣는다** — 알리지 않으면 그 커밋이 기본 브랜치로 갈 길 없이 남는다.
- **push 가 거부되면 오류 원문을 보고하고 멈추지 않는다 — `pull --rebase`·rebase·force 로 맞추지 않는다** — 미push 커밋 rebase 는 history rewrite 라 별도 승인이고, 맞추기는 사용자다.
- **중계 모드(`karina:chain-plan` 워커)면 push 하지 않는다** — 체인 끝에 코디네이터가 한 번 push 한다(`../../chain-plan/references/chain-end-push.md`「체인 끝 push」).
- **보고 `push` 줄은 `게이트 <판정> · push <결과>` 다(판정 값은 `local-gate.md`「보고」)** — 결과는 `origin/<기본> <sha7>` · `건너뜀(<사유>)` · `거부(<오류 요지>)` 중 하나다.

## 디버깅 단독 경로

> `karina:karina-systematic-debugging` 이 Phase 4 에서 직접 고칠 때 읽는다 — 첫 편집 전(「갈래」)과 4-D 뒤(「커밋」). `karina:implement` 루프 안에서 그 스킬 절차를 읽는 경우는 대상이 아니다 — 루프가 task 커밋과 회차 push 를 맡는다.

### 갈래

**첫 편집 전 1회. 브랜치를 그대로 둔 채 「커밋」 뒤 `local-gate.md`「디버깅 단독」 게이트를 거쳐 위 「기본 브랜치 push」 의 push 를 한다.** 단 진행 중 `plan.md`(미완료 `[ ]`·`[/]`·`[-]`·`[~]` task)가 있으면 push 하지 않고 push 결과를 `건너뜀(진행 중 회차「<plan 제목>」 끝에 함께 push)` 로 적는다 — 회차 중간에 push 하면 끝나지 않은 task 커밋이 기본 브랜치에 먼저 공개된다.

- **디버깅을 시작할 때의 HEAD 를 기억해 둔다** — 원격이 없을 때 게이트가 그것을 범위의 아래 끝으로 쓴다(`local-gate.md`「디버깅 단독」). 디버깅에는 자기 `plan.md` 가 없다.

### 커밋

**4-D 뒤 1회 — 재실행이 통과했든 `미검증` 이든 한다.** RED 를 본 시점에 따로 커밋하지 않는다 — Halt·Phase 4.5 로 끝나면 빨간 커밋만 브랜치에 남는다.

1. **회귀 테스트 파일을 먼저 커밋한다** — 제목 `수정: <증상> — 재현 테스트`. 테스트만 담은 이 커밋은 BASE 위에서 실패하므로, 수정보다 먼저 들어간 실패 재현이 이력에 남는다.
2. **수정 파일을 커밋한다** — 제목 `수정: <증상> — <원인 한 구>`. 본문에 근본 원인 · RED·GREEN·원래 재현의 판정 줄 · 4-B 에서 지운 주석의 이유를 적는다.
   - **UI 재현이면 본문에 `화면: HEAD <참|거짓> · 스크린샷 <이름> · 시나리오 <조작 순서> · 통과 조건 <조건> · BASE <거짓|참>` 줄을 더한다 — 시나리오는 1-B 재현 시나리오이고, BASE 는 커밋이 아니라 1-B 수정 전 화면이다. 검증 스킬 없이 수동으로 재현했으면 `화면: 미촬영(HUMAN-VERIFY) · 스크린샷 <이름> · 시나리오 <조작 순서> · 통과 조건 <조건>`(칸 서식 `screen-scenarios.md`「화면 시나리오 실행」)** — 로컬 게이트와 체인 끝 게이트가 이 줄로 화면 변경을 찾는다(`local-gate.md`「디버깅 단독」·`../../chain-plan/references/chain-end-push.md`「체인 끝 게이트」). 짝을 남기는 법은 `../../karina-systematic-debugging/references/investigation-log.md`「화면 증거 (UI 재현)」.

- **한 커밋으로 끝내는 경우는 셋이다** — 빌드 실패 버그(RED 예외) · 자동 신호가 없는 재현(테스트 파일이 없다) · 회귀 테스트와 수정이 같은 파일. 제목은 2번 형식이고, 본문에 한 커밋인 사유를 적는다.
- **새로 만든 파일은 `git add -- <경로>` 를 먼저 한다** — 추적하지 않는 파일에 `git commit -- <경로>` 를 쓰면 `pathspec … did not match any file(s) known to git` 으로 실패한다(실측).
- **커밋은 `git commit -- <경로…>` 로 고친 파일만 담는다** — 작업 트리의 다른 변경을 함께 커밋하지 않는다.
- **메시지는 Bash 면 heredoc(`git commit -m "$(cat <<'MSG'` … `MSG` `)"`), PowerShell 이면 작은따옴표 문자열로 넘긴다** — 판정 줄의 백틱·`$` 가 `-m "…"` 에서 치환돼 사라진다.
- **제목에 `T<N>` 을 넣지 않는다** — `guard-bash` 는 `{유형}: T<N> — …` 제목을 task 완료 커밋으로 읽어 plan 체크박스를 검사한다. 커밋 메시지 형식은 그 레포 규약이 우선한다.
- **시크릿 경고가 하나라도 뜨면 커밋하지 않고 push 도 건너뛴 채(`push: 건너뜀(시크릿 경고)`) 보고한다** — 커밋 안 된 변경은 게이트가 검증할 대상이 아니고, 넘길지는 사용자가 정한다.
