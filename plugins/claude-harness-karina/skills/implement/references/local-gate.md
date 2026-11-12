# 로컬 게이트 — push 전 독립 검증과 화면 확인

> 기본 브랜치에 push 하기 직전에 읽는다(`push-flow.md`「기본 브랜치 push」) — `karina:implement` 회차 끝(`final-review.md`「완료 순서」 의 plan 파일 커밋 뒤), `karina:karina-systematic-debugging` 직접 수정 경로(`push-flow.md`「갈래」), `karina:chain-plan` 체인 끝(`../../chain-plan/references/chain-end-push.md`「체인 끝 push」). 「코드를 쓰지 않은 쪽의 판정」 과 「사용자가 본 화면」 없이는 push 하지 않게 하고, 작은 변경은 「경량 면제」 로 검증자를 부르지 않는다.
> 출처는 pstack autopilot-full 4·5단계다 — 고정 위치 `https://github.com/cursor/plugins/blob/ae5650febf4320793844c12c4adaa937f417f8da/pstack/skills/poteto-mode/playbooks/autopilot-full.md`(*"Green CI alone never authorizes a merge."*).
>
> 목차: 회차 끝 게이트(대상과 범위 · 경량 면제 · worktree 와 빌드 캐시 · 본문 파일 · 호출 · FAIL 처리 · 판정 재사용 · 게이트 완화 서명 · 화면 게이트 · push 와 거부 · 보고) · 디버깅 단독 · 체인 끝

## 회차 끝 게이트

**순서는 하나다 — 게이트(FAIL 이면 수정·재검증) → 게이트 완화 서명 → 화면 게이트 → push.** push 하는 HEAD 는 판정을 받은 SHA 와 같아야 한다(아래 「판정 재사용」 만 예외) — 판정 뒤에 붙은 커밋은 아무도 검증하지 않은 코드다. 경량 계획 회차도 같고, 건너뛰는 것은 아래 「경량 면제」 뿐이다. **중계 모드(`karina:chain-plan` 워커)는 이 게이트를 돌지 않는다** — 워커는 push 하지 않고, 체인 끝에 코디네이터가 한 번 돈다(아래 「체인 끝」).

### 대상과 범위

- **push 할 범위가 검증 대상이다 — `origin` 이 있으면 `git fetch origin <기본>` 뒤 `origin/<기본>..HEAD`, 없으면 `plan.md` `> BASE:..HEAD`** — 기본 브랜치 이름은 `push-flow.md`「기본 브랜치 push」 의 git 판정 그대로다. 범위가 비었으면(`git rev-list --count` 0) 게이트·push 모두 `건너뜀(push 할 커밋 없음)` 이다.
- **지금 브랜치가 기본 브랜치가 아니면 게이트도 돌지 않는다 — 「기본 브랜치 미정」(원격 없고 설정·`main`·`master` 도 없음)은 아닌 것으로 치지 않고 게이트를 돌아 판정만 보고한다** — push 하지 않으므로(`push-flow.md`「기본 브랜치 push」) 검증할 공개 대상이 없다. 그 브랜치를 기본 브랜치로 합치는 것은 사용자이고, 병합 뒤 기본 브랜치에서 게이트를 거쳐 push 한다.
- **base SHA 는 범위의 아래 끝이다 — `git merge-base origin/<기본> HEAD`(원격 없으면 `> BASE:` 의 full SHA)** — 검증자가 「이 커밋들이 없는 같은 코드」 와 대조해야 한다. base tip 으로 두면 그 사이 들어온 다른 커밋이 화면 시나리오를 참으로 만든다.

### 경량 면제

- **push 범위가 다섯을 모두 채우면 `gate-verifier` 를 부르지 않고 「worktree 와 빌드 캐시」~「판정 재사용」 을 건너뛴다 — ⓐ 파일 3개 이하(`git diff --name-only <base SHA>..HEAD`) ⓑ 변경 30줄 이하(`git diff --numstat <base SHA>..HEAD` 의 추가+삭제 합) ⓒ 화면 변경 없음(아래 「본문 파일」 에 쓸 `## 화면` 절이 없다) ⓓ 그 레포 `AGENTS.md` 의 `Gate 필수 경로` 줄 glob 에 걸리는 파일이 없다(줄이 없으면 참) ⓔ 그 레포 `AGENTS.md` 의 `Verify (앱 조작)` 줄이 없거나 「없음」 이다** — 작성자가 task 검증으로 이미 돌린 명령을 새 worktree 에서 다시 돌려도 작은 변경에서는 새로 잡히는 것이 거의 없고, 게이트 한 번이 분 단위 빌드를 든다(아래 실측). 사용자 답 「경량 면제」. ⓔ 는 ⓒ 가 작성자가 남긴 화면 줄로만 갈려, 화면 줄 없는 task·디버깅 수정이 화면을 간접으로 바꿔도 앱을 한 번도 조작하지 않고 push 되는 것을 막는다.
- **판정은 위 명령 출력으로만 한다 — 버전 커밋도 범위에 들고, 다섯 중 하나라도 재지 못하면 면제하지 않는다** — 모델이 「작다」 고 보고 건너뛰면 게이트를 끄는 쪽이 작성자가 된다.
- **glob 대조는 바뀐 경로마다 `Gate 필수 경로` 의 glob 각각(`**` 는 하위 전체)과 맞춰 본다** — 이 하니스는 `scripts/**`·`hooks/**` 를 선언해, 차단 hook 수정은 크기와 관계없이 검증자를 거친다.
- **면제하면 「게이트 완화 서명」 은 해당 없고 「화면 게이트」 는 ⓒ 로 열리지 않는다 — 남는 것은 push 와 보고이고, 보고 판정은 `건너뜀(경량 — 파일 <N> · 줄 <M>)` 이다** — 검증자 판정이 없는 범위라, 다른 판정 값으로 적으면 검증받은 push 로 읽힌다.

### worktree 와 빌드 캐시

- **만들기 전에 지난 실행의 잔여를 걷는다 — `git worktree prune` 뒤 `git worktree list --porcelain` 에서 `worktree <경로>` 줄의 경로 끝 폴더가 `local-gate`·`local-gate-base` 이고 `detached` 인 항목을 `git worktree remove --force <경로>` 로 지운다** — 세션이 게이트 중간에 끊기면 worktree 가 남고, 스크래치 경로는 세션마다 달라 경로 끝 폴더로 찾는다(porcelain 출력에는 이름 필드가 없다). 브랜치가 체크아웃된 같은 끝 폴더의 worktree 는 이 게이트가 만든 것이 아니라 건드리지 않는다.
- **head 는 `git worktree add --detach <스크래치>/local-gate <HEAD full SHA>`, base 는 `git worktree add --detach <스크래치>/local-gate-base <base SHA>`** — 사용자 체크아웃은 건드리지 않는다. `<스크래치>` 는 `../../TEMP-FILES.md`「하위 폴더」 의 `scratch\`.
- **그 레포 `AGENTS.md` 에 `Build cache` 줄(`<환경변수>=<경로>`)이 있으면 head 에 `<경로>/local/head`, base 에 `<경로>/local/base` 를 넘긴다 — 고정 폴더라 지우지 않고 다음 게이트가 다시 쓴다** — 한 레포의 게이트는 한 번에 하나라 덮어써도 다른 판정을 섞지 않는다. 새 worktree 는 산출물이 없어 매번 처음부터 컴파일한다(실측 — 중앙값 7.3~13.0분).
- **판정이 나면 worktree 둘을 지운다 — 거부되면 경로·SHA 가 위와 같을 때만(경로 끝 `local-gate`·`-base` · `git -C <경로> rev-parse HEAD` 가 위 SHA) `--force` 로 다시 지운다. 그래도 실패하면 「worktree 미삭제 — <경로> · <오류 줄>」 을 보고하고 계속하며, 끝에 `git worktree prune` 을 돈다** — 거부 사유는 검증 명령이 남긴 untracked 파일이고 detached worktree 라 잃을 사용자 작업이 없다. 정리 실패는 판정과 무관해 push 를 막지 않는다.

### 본문 파일

- **`gate-verifier` 에 넘길 본문을 Write 로 스크래치 파일에 쓴다 — 절은 둘이다. `## 검증` 은 실제로 돌린 명령과 결과 1~3개와, plan 의 `**화면**` 줄마다 `화면 시나리오: <시나리오> · 스크린샷 <이름> · 통과 조건 <조건> — <HEAD 판정>[ · BASE <판정>]` 한 줄이다. `## 화면` 은 `**화면**` 줄이 하나라도 있으면 쓰고, 스크린샷마다 `- <이름> — <로컬 경로>`(`(BASE 대조)` 면 `base-` 짝 · 못 찍었으면 `미촬영(HUMAN-VERIFY)`) 한 줄이다** — 검증자는 `화면 시나리오:` 줄로 같은 시나리오를 head 에서(꼬리 `· BASE <판정>` 이면 base 에서도) 다시 돌고, `## 화면` 머리 줄이 아래 「화면 게이트」 의 표지다.
- **화면 줄의 출처는 회차 끝이면 `plan.md` 의 `**화면**` 줄이다** — 디버깅·체인 끝의 출처는 아래 각 절이다.

### 호출

- **`gate-verifier` 를 부른다 — 입력은 head full SHA · 기본 브랜치와 base SHA · worktree 둘의 경로 · `AGENTS.md` 경로 · 빌드 캐시(없으면 「없음」) · 본문 파일 경로다** — 정의는 `../../../agents/gate-verifier.md`「입력」.
- **호출 전후 작업 트리 확인은 `../../READONLY-SUBAGENTS.md`「호출 전후 확인」 대로이고, 호출 전에 화면 가리기를 걷고 돌아온 뒤(판정 없이 끝난 경우 포함) 다시 덮는다(`../../SCREEN-COVER.md`「언제 끄고 켜는가」 · 보유자 `local-gate:<head worktree 경로>`)** — 검증자가 head·base 에서 앱을 조작한다.
- **판정 줄 없이 끝나면(오류·중단) worktree 를 지우고 push 를 보류한 채 「판정 없음」 으로 보고한다** — 판정이 없으면 push 근거가 없다.
- **판정이 나면(PASS·PASS+NOTES·FAIL 모두) `gate-verifier` 출력 전문을 스크래치 파일(`local-gate-<head sha7>.txt`)로 Write 한다 — 판정 기록의 `출력 <파일>` 칸이 이 파일이다(체인 끝도 같다)** — 재사용으로 push 하는 회차의 화면 확인 블록이 `스크린샷:` 칸 경로를 거기서 읽는다.

### FAIL 처리

- **막는 것은 `gate-verifier` 의 `FAIL` 하나다 — 그 실패 사유는 사용자가 겪을 버그(조작·화면 시나리오가 기대와 다름)와 실패한 게이트(명령 실패·형식 검사 새 위반·체크 끄기)뿐이고, `NOTES` 는 고치지 않고 `## Deferred / Follow-up` 으로 보낸다** — 그 밖의 지적까지 막으면 push 가 끝없이 밀린다(*"Only a bug a user would hit, a failed gate, or a wrong shipped doc blocks, and everything else goes in a follow-up."*). 「변경이 틀리게 만든 문서 줄」 은 FAIL 사유가 아니다(`docs/decisions.md` 2026-10-29 보류).
- **증명된 실패를 전부 한 수정으로 모아 고치고 커밋한 뒤 게이트를 다시 돈다 — 수정은 이 세션(작성자)이 하고, 판정은 다시 부른 `gate-verifier` 가 한다. 최대 2회다** — 사용자 답 「자동 수정 후 재검증」. 지적을 하나씩 고치면 재검증이 그만큼 더 돈다. 다시 부를 때 직전 `gate-verifier` 출력(`출력 요지:` 앞까지)을 스크래치 파일로 Write 해 「직전 판정」 입력으로 넘긴다 — 수정이 문서만 바꿨으면 직전에 통과한 명령을 다시 돌지 않는다(`../../../agents/gate-verifier.md`「할 일」 2번). 수정 커밋 제목은 `수정: 로컬 게이트 지적 — <요지>` 이고 본문에 고친 실패 사유 줄과 재검증 판정을 적는다.
- **수정 커밋은 완료 리뷰 뒤에 생긴다 — `completion-reviewer` 를 다시 부르지 않고 보고에 `게이트 수정 커밋 <sha7> — 완료 리뷰 뒤` 를 싣는다** — 그 커밋은 재검증이 작성자 아닌 쪽의 판정으로 덮는다.
- **2회 뒤에도 FAIL 이거나, FAIL 사유가 `미완료`·`head 불일치`·`base 불일치` 처럼 코드 수정으로 풀리지 않는 것이면 push 를 보류하고 보고한다** — 판정불가형은 1회만 다시 돌리고, 같으면 보류다. 고칠 수 없는 것을 고치는 시늉으로 횟수를 쓰지 않는다.

### 판정 재사용

- **판정 뒤 HEAD 가 움직였으면 두 경우에만 다시 돌지 않는다 — ⓐ 판정 SHA..HEAD 의 바뀐 파일(`git diff --name-only --no-renames`)이 전부 문서(`.md`·`.txt`)이고 그중에 `AGENTS.md`·검증 매핑 문서가 없고 그 레포 검증 매핑(`AGENTS.md` 또는 그것이 지목한 문서)이 그 경로에 명령을 걸지 않고, 바뀐 각 파일의 이름이 `.md`·`.txt` 밖 추적 파일에 따옴표 바로 앞 문자열로 나오지 않는다(`git grep -l -F -e '<이름>"' -e "<이름>'" -- . ':!*.md' ':!*.txt'` 이 비었다 — 레포 최상위에서) ⓑ `git diff <base SHA>..<판정 SHA> | git patch-id --stable` 과 `git diff <새 base>..HEAD | git patch-id --stable` 이 같다(같은 패치가 다른 base 위로 옮겨졌다) — 그리고 base 범위 `<base SHA>..<새 base>` 와 이 범위 `<새 base>..HEAD` 로 아래 「push 와 거부」 의 영향 ①②③ 을 잰 결과가 모두 거짓이다(그 절의 `<base SHA>..HEAD` 를 `<새 base>..HEAD` 로, `<base SHA>..origin/<기본>` 을 `<base SHA>..<새 base>` 로 읽는다)** — 문구만 바뀐 변경을 다시 검증하면 같은 판정을 두 번 산다(*"a wording-only change gets none"*). 같은 패치라도 base 가 호출부·검증 문서·의존을 바꿨으면 검증이 돈 조합이 아니다(autopilot-full 5단계 *"When trunk changed a caller of the patch…"*). 매핑 문서를 고친 변경은 문구가 아니라 어느 검사가 도는지를 바꿔 재사용하지 않는다(원문 autopilot-full *"a change to which checks run"* — `https://github.com/cursor/plugins/blob/ae5650febf4320793844c12c4adaa937f417f8da/pstack/skills/poteto-mode/playbooks/autopilot-full.md`). 검증 매핑이 `*.md` 에 명령을 거는 레포(이 하니스)는 ⓐ 가 늘 거짓이다. 이름 대조는 빌드가 읽는 문서를 거른다 — Karina 는 `include_str!` 로 `SKILL.md`·`fixtures/*.txt` 를 빌드에 넣어(2026-11-11 실측), 확장자만 보면 그 파일만 고친 수정 커밋이 재검증 없이 push 된다.
- **판정 기록은 `plan.md` 의 Progress Log 한 줄이다 — `로컬 게이트: <판정> · head <full SHA> · base <full SHA> · patch-id <값> · 출력 <파일>`** — 재사용 판정이 이 줄을 대조한다. 체인 끝은 아래 「체인 끝」 의 결정 파일이다. `<파일>` 은 위 「호출」 이 Write 한 출력 파일이고 `%TEMP%\…` 표기로 적는다 — 재사용으로 push 하는 회차의 화면 확인 블록이 `스크린샷:` 칸 경로를 거기서 읽는다(`screen-scenarios.md`「화면 확인 블록」).

### 게이트 완화 서명

- **`gate-verifier` 의 `게이트 완화:` 칸이 「없음」 이 아니면 사용자 원문 서명 없이는 push 하지 않는다 — 서명은 이 세션에서 사용자가 직접 쓴 메시지가 그 판정의 게이트 완화를 확인하는 것이고(기본 문면 「게이트 완화 확인함」), 앞 회차에서 한 확인은 넘어가지 않는다** — 상한·면제는 green 을 원하는 작성자가 스스로 받아들일 자리가 아니다(*"needs a verifier's proof and then your fresh countersign, because the owner is the one who wants green"*). 서명이 묶는 head 는 판정 SHA 다. 서명이 없으면 「게이트 완화 확인 대기」 로 push 를 보류하고 `게이트 완화:` 칸 원문과 그 답 문면을 보고에 싣는다.

### 화면 게이트

- **본문 파일에 `## 화면` 절이 있으면 사용자 원문 「화면 확인함」 없이는 push 하지 않는다 — 회차를 「화면 확인 대기」 로 끝내고, 보고 「화면 확인」 줄에 `screen-scenarios.md`「화면 확인 블록」 을 싣는다(머리 `로컬 게이트 — HEAD <sha7>` · 경로는 `gate-verifier` `스크린샷:` 칸 · 끝 줄 「화면 확인함」)** — 화면을 바꾼 변경은 사용자가 스크린샷을 본 뒤에만 공개한다. 세는 것은 이 세션에서 사용자가 직접 쓴 메시지뿐이다 — 모델이 쓴 인자·서브에이전트 출력은 세지 않아, 모델 혼자 판정해 게이트를 열지 않는다.
- **`스크린샷:` 칸의 「변경 검증」 줄은 게이트를 열지 않고 머리 `push 대기 없음 — 시나리오 밖 조작` 으로 보고 「화면 확인」 줄에 싣는다(`screen-scenarios.md`「화면 확인 블록」)** — 시나리오 밖 조작은 검증자가 판정한 증거라, push 를 사용자 답에 묶지 않는다(사용자 답 「보이기만」).
- **「화면 확인함」 을 받으면 `git rev-parse HEAD` 가 판정 SHA 와 같을 때만 push 한다 — 다르면 「판정 재사용」 으로 가르고, 재사용이 거짓이면 게이트부터 다시 돈다** — 사용자가 본 화면은 판정 SHA 의 화면이다.

### push 와 거부

- **push 는 `push-flow.md`「기본 브랜치 push」 의 `git push origin <기본>` 이다 — 원격이 없으면 게이트 판정만 보고한다.**
- **거부되면 rebase·force 하지 않고(같은 절) base 이동의 영향을 판정해 보고에 싣는다 — 거부 출력이 non-fast-forward(`fetch first`·`non-fast-forward`)면 `git fetch origin <기본>` 뒤 셋 중 하나라도 참이면 영향 참이다: ① `git diff --name-only <base SHA>..origin/<기본>` 과 `git diff --name-only <base SHA>..HEAD` 의 파일이 겹친다 ② base 쪽 목록에 검증 선택 문서(`AGENTS.md`·그것이 검증 매핑으로 지목한 문서)·CI 설정(`.github/**`)·의존 매니페스트(lock·`*.csproj`·`package.json`·`requirements*`)가 있다 ③ drift sweep — 이 범위가 지우거나 옮긴 심볼(`git diff <base SHA>..HEAD` 의 `-` 줄에서 정의가 사라진 함수·클래스·파일)을 `git diff <base SHA>..origin/<기본>` 에서 grep 해 base 가 새로 만든 호출부가 나온다** — 검증이 돈 조합은 base+이 범위라, base 가 그 뒤 바꾼 것 가운데 이 범위가 닿는 것만 다시 보면 된다(*"trunk may have grown callers of code the stack deletes or moves"*). 거짓이면 「사용자가 합친 뒤 patch-id 가 같으면 재검증 없이 push 가능」, 참이면 「합친 뒤 게이트 재실행 필요」 를 적는다. 합치기는 사용자다(기본 브랜치의 미push 커밋 rebase 는 history rewrite).

### 보고

- **4번이 「게이트 대기」 로 둔 Goal 기준(`../SKILL.md`「검증」)은 게이트가 닫는다 — `PASS`·`PASS+NOTES` 면 그 명령 출력으로 참·거짓을 적고, `FAIL` 이면 위 「FAIL 처리」 대로 고친다. `건너뜀`·`판정 없음` 으로 끝나 남은 게이트 대기는 그 명령을 이 세션이 그 자리에서 돌려 닫는다** — 대기가 열린 채 보고하면 그 기준을 아무도 재지 않는다.
- **보고 `push` 줄은 `게이트 <판정> · push <결과>` 다** — 판정은 `PASS`·`PASS+NOTES`·`FAIL`·`판정 없음`·`재사용(<ⓐ|ⓑ>)`·`건너뜀(<사유>)`(경량 면제는 `건너뜀(경량 — 파일 <N> · 줄 <M>)`), 결과는 `push-flow.md`「기본 브랜치 push」 의 셋에 `보류(<FAIL|화면 확인 대기|게이트 완화 확인 대기>)` 를 더한 것이다. `NOTES` 는 「남은 이슈」 에, 수정 커밋은 「판정」 줄에 싣는다.
- **push 가 성공했고 그 레포 Release 가 릴리즈 발행을 지목하면 「승인 필요 항목」 에 `승인 필요 — gh release create <태그> --target <push 한 HEAD full SHA>` 를 싣는다(태그 형식·발행 판정은 그 Release)** — 릴리즈는 외부·비가역이라 스킬 안에서도 별도 승인이고, 버전 커밋 뒤에도 리뷰·게이트 수정 커밋이 붙을 수 있어 대상은 버전 커밋이 아니라 push 한 HEAD 다. 이 줄이 없으면 발행이 다음 세션의 `[karina 릴리즈 누락]` 경고에야 드러난다.
- **회차 끝이면 게이트 소요를 싣는다 — 「호출」 직전에 `report-format.md`「소요 기록」 의 호출형을 `-Since` 없이 불러 게이트 시작 시각을 얻고, 보고 직전 `-Since <그 시각>` 으로 잰 값을 `- **소요**:` 줄 끝 ` · 게이트 소요 <N시간 M분>` 으로 붙인다** — `plan.md` 의 `> 완료:` 는 게이트 앞에서 찍혀 게이트(빌드·재검증 최대 2회)가 소요에서 빠진다. `> 완료:` 를 게이트 뒤로 옮기면 추적 레포에서 검증받지 않은 plan 파일 커밋이 push 된다.

## 디버깅 단독

`push-flow.md`「갈래」 에서 진행 중 회차가 없을 때 「커밋」 뒤, push 앞에 위 게이트를 그대로 돈다 — 네 자리만 다르다.

- **그 레포 `AGENTS.md` Release 가 버전 커밋을 지목하고 그 Release 의 발행 판정이 참이면(이 하니스는 `docs/harness-conventions.md`「Release」 의 「판정 시점」 명령) 「커밋」 뒤 게이트 앞에 버전만 올린 커밋을 1개 만든다 — 제목·버전 자리는 그 Release 형식이고, 버전 자리 편집이 plan 게이트에 막히면 건너뛰고 그 사실을 보고한다. 커밋 뒤 `git diff --name-only HEAD~1..HEAD` 가 그 Release 의 버전 파일 집합과 같은지 보고, 다른 변경이 섞였으면 그 커밋을 `git reset --soft HEAD~1` 로 풀어 보고한다** — 회차는 plan 마지막 task 가 버전을 올리지만 디버깅에는 plan 이 없어, 이 자리가 없으면 런타임 변경이 버전 없이 push 돼 설치본 사용자에게 가지 않는다. 게이트 앞에 두어 독립 검증이 버전 커밋까지 덮는다.

- **범위의 아래 끝은 원격이 없으면 디버깅을 시작할 때의 HEAD 다** — 디버깅에는 자기 `plan.md` 가 없다(`push-flow.md`「갈래」 아래 불릿). 판정 기록도 `plan.md` 가 아니라 보고에 싣는다.
- **화면 줄의 출처는 수정 커밋 본문의 `화면:` 줄이다(`push-flow.md`「커밋」 2번) — 그 줄의 시나리오·스크린샷·통과 조건·BASE 로 `## 검증` 의 `화면 시나리오:` 줄을 만들고, 미촬영 줄은 판정 칸을 `— 미촬영(HUMAN-VERIFY)` 로 옮긴다** — 시나리오는 1-B 의 재현 시나리오다. 디버깅에는 `plan.md` 가 없어 이 줄이 검증자가 다시 돌 시나리오의 유일한 출처다.
- **FAIL 을 고치는 것은 그 디버깅 세션이다 — Phase 4 와 같은 절차(원인 → 수정 → 재실행)로 고쳐 「커밋」 형식으로 커밋하고 게이트를 다시 돈다(최대 2회)** — `karina:implement` 루프가 없다.

## 체인 끝

`karina:chain-plan` 코디네이터가 체인 끝 push 직전에 1회 돈다 — 사용자 답 「체인 끝 1회」. 코디네이터는 대상 레포 밖에서 돌 수 있어 git 명령은 모두 `git -C "<대상 레포 경로>"` 로 돈다. 다른 자리는 넷이다.

- **범위의 아래 끝은 원격이 없으면 체인 결정 파일(`../../chain-plan/references/chain-decisions.md`「결정 기록」)의 `- plan 1 · 부모 <sha>` 다 — 그 줄이 없으면(결정 파일 중간 유실 · 재개가 이어받지 못함) 범위를 짐작하지 않고 `push: 게이트 건너뜀 · push 보류(범위 아래 끝 없음)` 로 보고한다** — 코디네이터는 워커의 `plan.md` 를 읽지 않는다. 짐작한 아래 끝은 검증하지 않은 커밋을 범위 밖에 남긴다(사용자 답 「push 보류」).
- **화면 줄의 출처는 `git log --format=%B <범위>` 의 `화면: ` 으로 시작하는 줄이다 — `화면 시나리오:` 줄은 위 「디버깅 단독」 과 같이 만들고, `· 변형:` 이하 마디(`../../chain-plan/references/chain-decisions.md`「결정 기록」)는 그 줄에 싣지 않는다** — 체인 끝 push 가 게이트 본문 파일의 화면 절을 채우는 자리와 같다(`../../chain-plan/references/chain-end-push.md`「체인 끝 push」).
- **게이트 완화 서명과 화면 확인은 코디네이터가 사용자에게 직접 받는다 — 위 「화면 게이트」 의 사용자 원문 기준 그대로다** — 코디네이터 판정·위임 답은 서명이 아니다.
- **FAIL 이면 코디네이터가 고치지 않는다 — `../../chain-plan/references/continuation.md`「체인 끝 게이트 FAIL」 대로 실패 파일이 속한 계획의 이어받기 워커가 고치고, 끝나면 직전 판정을 넘겨 게이트를 다시 돈다(최대 2회)** — 코디네이터는 파일을 고치지 않는다(`../../chain-plan/SKILL.md`「하지 않는 것」). 판정 기록은 결정 파일에 `- 체인 끝 게이트 · <판정> · head <full SHA> · base <full SHA> · patch-id <값> · 출력 <파일>` 줄로 남긴다 — 레포 밖 파일을 코디네이터가 직접 써 작성자를 안다.
