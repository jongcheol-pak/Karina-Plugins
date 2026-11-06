# 병행 세션 감지

> `push-flow.md`「브랜치」 가 지금 브랜치가 기본 브랜치일 때 표대로 바꾸기 전에 읽는다. 중계 모드(`karina:chain-plan` 워커)에서는 읽지 않는다 — 워커는 사용자에게 물을 수 없고 같은 폴더의 코디네이터가 잡힌다.

**같은 체크아웃의 병행 세션을 찾는다 — `python "<skill>/../worktree-cleanup/scripts/worktree_cleanup.py" sessions --path <git rev-parse --show-toplevel 출력>`(`<skill>` 은 `../SKILL.md` 의 폴더 · 출력 줄의 뜻은 그 스크립트 모듈 docstring)** — 다른 세션이 같은 폴더에서 일하는 중에 브랜치를 바꾸면 그 세션의 미커밋 편집이 회차 브랜치로 따라오고, 그 세션도 바뀐 브랜치 위에서 계속 커밋한다(2026-11-05 Karina 회차 — 다른 세션의 `orchestration_host.rs` 편집이 섞여 회차가 멈췄다).

- **`OTHER` 줄이 하나라도 있으면 브랜치를 바꾸지 않고 멈춰 묻는다** — 질문에 `OTHER` 줄의 폴더 이름과 경과 분을 싣고 선택지 셋을 낸다: 「그 세션이 끝날 때까지 대기」 · 「worktree 로 옮김 — 무시 대상 파일(`.env`·빌드 캐시)은 따라오지 않아 새로 빌드한다」 · 「그대로 진행 — 같은 폴더의 직전 자기 세션이거나 형제 폴더(`<레포>-…`)의 세션이면 이것」. 루프 진입 전이라 `../SKILL.md`「멈추는 넷」 밖의 막힘형 질문이다.
  - **대기** — 사용자가 「계속」 하면 `sessions` 를 다시 돌려 처음부터 가른다.
  - **worktree 로 옮김** — `git fetch origin <기본>` → `git worktree add <레포 부모>/<레포 이름>-<슬러그 끝> -b karina/<슬러그> origin/<기본>` → 세션 폴더의 `plan.md` 를 추적 여부와 관계없이 그 worktree 루트에 복사 → 복사본의 `> BASE:` 를 `git -C <worktree> rev-parse --short HEAD` 로, `## Next Steps` 에 슬러그와 worktree 경로를 적는다. 그 뒤 ⓐ 「그 폴더에서 새 세션을 열어 `/karina:implement` 계속」 ⓑ 따라오지 않은 무시 대상 파일 ⓒ worktree 로 옮기지 않은 로컬 선행 커밋 수(`git rev-list --count origin/<기본>..<기본>`) ⓓ 「원래 폴더의 `plan.md` 는 이제 worktree 쪽이 정본 — 원래 폴더 정리는 사용자」 를 보고하고 이 회차를 멈춘다.
    - **세션 폴더의 `plan.md` 는 건드리지 않는다** — hook·증거 대조·리뷰·push 는 세션 폴더를 작업 레포로 보므로 새 세션이어야 맞고, 되돌리면 병행 세션의 변경까지 날린다.
  - **그대로 진행** — `push-flow.md`「브랜치」 표대로 간다.
- **`UNKNOWN`(비 ASCII 경로)이면 그대로 진행하고 그 줄을 최종 보고에 싣는다** — 슬러그 규칙을 몰라 판정할 수 없다는 사실을 남긴다.
- **`NONE` 이면 그대로 진행한다** — 30분 안에 같은 폴더를 쓴 다른 세션이 없어 브랜치를 바꿔도 남의 편집이 섞이지 않는다.
