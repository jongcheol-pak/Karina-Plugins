# 기본 브랜치 push

> `karina:implement` 가 **루프 진입 전 1회**와 **회차 끝 1회** 읽고, `karina:karina-systematic-debugging` 이 직접 고칠 때 `../../karina-systematic-debugging/references/commit-push.md` 를 거쳐 읽는다(디버깅에만 걸리는 갈래·커밋 규칙은 그 파일에 있다). 시작과 끝에만 쓰이는 절차라 `../SKILL.md` 본문에 두지 않는다.
>
> 목차: 기본 브랜치 push(push 전 확인)

## 기본 브랜치 push

**브랜치를 바꾸지 않고 worktree 를 만들지 않고 지금 브랜치에 커밋한다** — 혼자 쓰는 하니스라 변경을 받을 리뷰어가 없어 브랜치가 시간만 든다(사용자 결정 2026-11-07). push 전 검증은 아래 「push 전 확인」 하나다. 이 절이 정본이고, 다른 스킬은 이 절을 가리킨다. **경로를 생략하지 않는다** — `karina:chain-plan` 코디네이터는 대상 레포 밖에서 돌 수 있어, 아래 git 명령은 대상 레포가 지금 폴더가 아니면 `git -C "<대상 레포 경로>"` 로 돈다.

- **회차 끝에 지금 브랜치가 기본 브랜치이고 `origin` 이 있으면 아래 「push 전 확인」 을 거쳐 `git push origin <기본>` 을 1회 한다** — 기본 브랜치는 git 만으로 정한다: `git symbolic-ref --short refs/remotes/origin/HEAD` 의 `origin/` 뒤, 실패하면 `git ls-remote --symref origin HEAD` 의 `ref: refs/heads/<이름>`. 원격이 없으면 `git config init.defaultBranch` 값이 로컬 브랜치로 있으면 그것, 없으면 `main` · `master` 순으로 있는 것(`git rev-parse --verify -q refs/heads/<이름>`)이고, 둘 다 없으면 「기본 브랜치 미정」이다 — push 결과는 `건너뜀(기본 브랜치 미정)` 이다(사용자 답 「설정 → main·master」). 원격이 없으면 push 하지 않는다. push 할 범위(`origin/<기본>..HEAD`)가 비었으면 `건너뜀(push 할 커밋 없음)` 이다. **기본 브랜치가 아니면 push 하지 않고, 중계 모드가 아니면 커밋이 기본 브랜치에 없다는 사실을 보고의 「기다리는 것」 에 `기본 브랜치에 없는 커밋 — <브랜치> · <git rev-list --count <기본>..HEAD>개 · 병합은 사용자 · 병합 뒤 기본 브랜치에서 4번 검증을 거쳐 push` 로 싣는다** — 알리지 않으면 그 커밋이 기본 브랜치로 갈 길 없이 남는다.
- **중계 모드(`karina:chain-plan` 워커)면 push 하지 않는다** — 체인 끝에 코디네이터가 한 번 push 한다(`../../chain-plan/references/chain-end-push.md`「체인 끝 push」).
- **보고 `push` 줄은 `push <결과>` 다** — 결과는 `origin/<기본> <sha7>` · `건너뜀(<사유>)` · `보류(<push 전 확인 실패 사유>)` · `거부(<오류 요지>)` 중 하나다.

### push 전 확인

**push 직전 1회 — 작성자가 돌린 전체 빌드·테스트와 clean 판정이 push 의 근거다.** 새 worktree 재빌드·서브에이전트 재검증·사용자 화면 확인 대기는 두지 않는다 — 혼자 쓰는 하니스에서 그것들이 회차마다 25~48분을 들였다(Karina 2026-11-13 · 사용자 답 「바로 push + 스크린샷 보고」 2026-11-14). 화면 스크린샷은 최종 보고 「확인할 것」 표에만 싣고 push 를 기다리게 하지 않는다(`screen-scenarios.md`「확인할 것 — 화면 행」).

- **clean 줄이 근거다 — 회차는 4번(`../SKILL.md`「검증」)이 `AGENTS.md` Build·Test 전체를 통과한 직후 clean 이면 Progress Log 에 `4번 검증: <full SHA> · clean` 을, 디버깅 단독은 `../../karina-systematic-debugging/references/commit-push.md`「커밋」 이 `../../TEMP-FILES.md` 의 `scratch\push-check-<레포 폴더명>.txt` 에 `4-D 검증: <full SHA> · clean` 을 남긴다. clean 은 ⓐ `git status --porcelain --untracked-files=no` 에 `plan.md` 밖 줄이 없고 ⓑ `git ls-files --others --exclude-standard` 에서 착수 스냅숏(`../SKILL.md`「작업 범위」 의 `untracked-start-` 파일 — 디버깅은 `../../karina-systematic-debugging/references/commit-push.md`「갈래」 의 같은 파일) 줄과 `plan.md` 를 뺀 것이 빈 것이다(스냅숏 파일이 없으면 ⓑ 는 `plan.md` 만 뺀다)** — clean 이 아니면 미커밋·untracked 입력으로 통과했을 수 있다. 회차 전부터 있던 untracked 는 뺀다(Karina 2026-11-13 — 빌드 입력이 아닌 사용자 파일 하나로 전체 재검증 48분).
- **push 해도 되는 것은 그 줄의 SHA 가 HEAD 이거나, SHA..HEAD 의 커밋이 전부 plan 파일 커밋(`report-format.md`「plan 파일 커밋」)이나 그 레포 Release 의 버전 파일 집합만 바꾼 커밋이거나, 바뀐 파일이 그 레포 `AGENTS.md` 의 `Gate 재사용 경로` 에 전부 걸리는 커밋일 때다(`git diff --name-only <SHA>..HEAD` 로 잰다 · 선언 경로는 그 `AGENTS.md` 폴더에서 `-- :/ ':(exclude,glob)<g>'` 를 붙여 남는 것이 없는지 본다)** — 그 밖의 커밋은 아무도 빌드·테스트하지 않은 코드다. 선언이 없는 레포는 문서만 바꾼 커밋도 재검증 대상이다 — 문서가 빌드 입력이나 실행 자산인 레포가 있어 확장자로는 빼지 않는다. 검증 매핑이 명령을 거는 경로와 겹치는 glob 은 세지 않는다(겹침 판정은 `../../chain-plan/references/continuation.md`「코디네이터 검증」 의 `git ls-files -- ':(glob)<g>'` 대조).
- **줄이 없거나 위가 거짓이면 그 자리에서 `AGENTS.md` Build·Test 를 다시 돌리고, 통과·clean 이면 회차는 Progress Log 에 `4번 검증: <full SHA> · clean` 줄을 남긴 뒤 push 한다. 실패하면 push 하지 않고 `보류(Build·Test 실패)` 로 출력 원문과 함께 보고한다** — 고치는 것은 그 회차·디버깅의 실패 처리다. 재검증을 끝없이 미루지 않도록 이 확인은 push 한 번에 한 번이다.
- **push 가 거부되면 오류 원문을 보고하고 멈추지 않는다 — `pull --rebase`·rebase·force 로 맞추지 않는다. 보고에 「사용자가 합친 뒤 4번 검증을 다시 돌려 push」 를 적는다** — 미push 커밋 rebase 는 history rewrite 라 별도 승인이고, 맞추기는 사용자다.
