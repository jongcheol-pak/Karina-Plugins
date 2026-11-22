# 디버깅 단독 경로 — 커밋·push

> `karina:karina-systematic-debugging` 이 Phase 4 에서 직접 고칠 때 읽는다 — 첫 편집 전(「갈래」)과 4-D 뒤(「커밋」). push 와 push 전 확인의 정본은 `../../implement/references/push-flow.md`「기본 브랜치 push」 이고 여기는 디버깅에만 걸리는 갈래와 커밋 규칙을 둔다 — `karina:implement` 가 루프마다 읽는 그 파일에서 갈라 냈다. `karina:implement` 루프 안에서 그 스킬 절차를 읽는 경우는 대상이 아니다 — 루프가 task 커밋과 회차 push 를 맡는다.

## 갈래

**첫 편집 전 1회. 브랜치를 그대로 둔 채 「커밋」 뒤 `../../implement/references/push-flow.md`「push 전 확인」 을 거쳐 `../../implement/references/push-flow.md`「기본 브랜치 push」 의 push 를 한다.** 단 진행 중 `plan.md`(미완료 `[ ]`·`[/]`·`[-]`·`[~]` task)가 있으면 push 하지 않고 push 결과를 `건너뜀(진행 중 회차「<plan 제목>」 끝에 함께 push)` 로 적는다 — 회차 중간에 push 하면 끝나지 않은 task 커밋이 기본 브랜치에 먼저 공개된다.

- **디버깅을 시작할 때 HEAD 의 sha7 을 기억해 둔다 — 아래 스냅숏 파일 이름에 쓴다.** 디버깅에는 자기 `plan.md` 가 없다.
- **같은 때 `git ls-files --others --exclude-standard` 를 `../../TEMP-FILES.md` 의 `scratch\untracked-start-<레포 폴더명>-<시작 HEAD sha7>.txt` 에 쓴다(있으면 덮지 않는다)** — 아래 「커밋」 의 clean 판정이 디버깅 전부터 있던 untracked 를 뺀다(회차 끝과 같은 스냅숏 — `../../implement/SKILL.md`「작업 범위」).

## 커밋

**4-D 뒤 1회 — 재실행이 통과했든 `미검증` 이든 한다.** RED 를 본 시점에 따로 커밋하지 않는다 — Halt·Phase 4.5 로 끝나면 빨간 커밋만 브랜치에 남는다.

1. **회귀 테스트 파일을 먼저 커밋한다** — 제목 `수정: <증상> — 재현 테스트`. 테스트만 담은 이 커밋은 BASE 위에서 실패하므로, 수정보다 먼저 들어간 실패 재현이 이력에 남는다.
2. **수정 파일을 커밋한다** — 제목 `수정: <증상> — <원인 한 구>`. 본문에 근본 원인 · RED·GREEN·원래 재현의 판정 줄 · 4-B 에서 지운 주석의 이유를 적는다.
   - **UI 재현이면 본문에 `화면: HEAD <참|거짓> · 스크린샷 <이름> · 시나리오 <조작 순서> · 통과 조건 <조건> · BASE <거짓|참>` 줄을 더한다 — 시나리오는 1-B 재현 시나리오이고, BASE 는 커밋이 아니라 1-B 수정 전 화면이다. 검증 스킬 없이 수동으로 재현했으면 `화면: 미촬영(HUMAN-VERIFY) · 스크린샷 <이름> · 시나리오 <조작 순서> · 통과 조건 <조건>`(칸 서식 `../../implement/references/screen-scenarios.md`「화면 시나리오 실행」)** — 체인 보고와 다음 세션이 `git log` 에서 이 줄로 화면 변경과 시나리오를 찾는다. 짝을 남기는 법은 `investigation-log.md`「화면 증거 (UI 재현)」.

- **한 커밋으로 끝내는 경우는 셋이다** — 빌드 실패 버그(RED 예외) · 자동 신호가 없는 재현(테스트 파일이 없다) · 회귀 테스트와 수정이 같은 파일. 제목은 2번 형식이고, 본문에 한 커밋인 사유를 적는다.
- **새로 만든 파일은 `git add -- <경로>` 를 먼저 한다** — 추적하지 않는 파일에 `git commit -- <경로>` 를 쓰면 `pathspec … did not match any file(s) known to git` 으로 실패한다(실측).
- **커밋은 `git commit -- <경로…>` 로 고친 파일만 담는다** — 작업 트리의 다른 변경을 함께 커밋하지 않는다.
- **메시지는 Bash 면 heredoc(`git commit -m "$(cat <<'MSG'` … `MSG` `)"`), PowerShell 이면 작은따옴표 문자열로 넘긴다 — 본문에 역슬래시가 들면 Write 로 만든 파일을 `git commit -F <파일>` 로 넘긴다(Bash 도구가 역슬래시 둘을 하나로 줄이고 `guard-bash` 가 그 heredoc 을 막는다)** — 판정 줄의 백틱·`$` 가 `-m "…"` 에서 치환돼 사라진다.
- **제목에 `T<N>` 을 넣지 않는다** — `guard-bash` 는 `{유형}: T<N> — …` 제목을 task 완료 커밋으로 읽어 plan 체크박스를 검사한다. 커밋 메시지 형식은 그 레포 규약이 우선한다.
- **커밋 전 자기 검사에서 시크릿이 걸리면 커밋하지 않고, 커밋 명령의 hook 시크릿 경고가 뜨면(비차단이라 커밋은 이미 끝나 있다) `../../implement/references/loop-exceptions.md`「시크릿 경고 오탐」 의 명백한 오탐이 아닌 한 다음 커밋을 멈추고 — 어느 쪽이든 push 도 건너뛴 채(`push: 건너뜀(시크릿 경고)`) 커밋 SHA·걸린 줄과 함께 보고한다** — 경고 걸린 커밋은 push 할 대상이 아니고, 넘길지·되돌릴지(`git reset --soft HEAD~1`)는 사용자가 정한다.
- **그 레포 `AGENTS.md` Release 가 버전 커밋을 지목하고 그 Release 의 버전 판정이 참이면(이 하니스는 `docs/harness-conventions.md`「Release」 의 「판정 시점」 명령) 위 커밋 뒤 버전만 올린 커밋을 1개 만든다 — 제목·버전 자리는 그 Release 형식이고, 버전 자리 편집이 plan 게이트에 막히면 건너뛰고 그 사실을 보고한다. 커밋 뒤 `git diff --name-only HEAD~1..HEAD` 가 그 Release 의 버전 파일 집합과 같은지 보고, 다른 변경이 섞였으면 그 커밋을 `git reset --soft HEAD~1` 로 풀어 보고한다** — 회차는 plan 마지막 task 가 버전을 올리지만 디버깅에는 plan 이 없어, 이 자리가 없으면 런타임 변경이 버전 없이 push 돼 설치본 사용자에게 가지 않는다. 버전 파일만 바꾼 커밋은 `../../implement/references/push-flow.md`「push 전 확인」 이 재검증 대상으로 세지 않는다.
- **4-D 가 `AGENTS.md` 「Build & Test」 의 빌드·테스트 전체를 통과했으면 커밋 뒤 push 전 확인의 clean 줄을 남긴다 — ⓐ 4-D 통과 직후(4-C 의 원래 재현 수단 정리 뒤) 작업 트리 해시를 잰다: 임시 인덱스 파일 `<t>` 로 `GIT_INDEX_FILE=<t> git read-tree HEAD` → `GIT_INDEX_FILE=<t> git add -A` → `GIT_INDEX_FILE=<t> git write-tree` ⓑ 커밋 뒤 같은 해시를 다시 재 ⓐ 와 같고 ⓒ clean(`git status --porcelain --untracked-files=no` 가 비고, `git ls-files --others --exclude-standard` 에서 「갈래」 스냅숏 줄을 뺀 것이 빈다)이면 `../../TEMP-FILES.md` 의 `scratch\push-check-<레포 폴더명>.txt` 에 `4-D 검증: <HEAD full SHA> · clean` 한 줄을 덧붙인다. 하나라도 거짓이면 줄을 남기지 않고, `../../implement/references/push-flow.md`「push 전 확인」 이 push 직전에 Build·Test 를 다시 돈다. 4-D 재현이 `미검증` 이어도 Build·Test 가 통과하면 push 하고 미검증을 보고에 싣는다** — 4-D 는 수정이 커밋되기 전 트리에서 돌아, 해시가 같고 tracked 미커밋이 없어야 HEAD 트리가 4-D 가 잰 트리이고 untracked 가 스냅숏뿐이어야 커밋 밖 입력으로 통과하지 않았다(사용자 답 「4-D 전체 검증 시 적용」 — 미커밋 변경 없는 트리로 Build·Test 전체 통과).
