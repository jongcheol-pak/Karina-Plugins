---
name: worktree-cleanup
description: 병합이 끝난 git worktree 를 정리한다 — worktree 마다 병합 여부·미커밋 수정·PR·최근 세션을 감사 표로 보이고, 승인한 것만 미추적 파일을 백업한 뒤 지운다(브랜치는 남긴다). 한국어(worktree 정리/머지된 worktree 지워줘/worktree 가 디스크를 차지해)와 영어(clean up worktrees/prune merged worktrees)에 발동한다. worktree 만들기·브랜치 삭제에는 발동하지 않는다.
---

# Worktree 정리

병합된 worktree 폴더를 **백업한 뒤** 지운다. 판정과 삭제는 `scripts/worktree_cleanup.py` 가 하고, 이 문서는 사용자 게이트를 맡는다. 출력 열·버킷·종료 코드·주입 인자의 정본은 그 스크립트의 모듈 docstring 이다.

## 절차

1. **감사** — 대상 레포 루트에서 `python "<이 SKILL.md 의 폴더>/scripts/worktree_cleanup.py" audit --repo <레포>` 를 돌린다. 전사 폴더가 커서 느리면 `run_in_background` 로 돌린다. base 를 원격 최신으로 보려면 먼저 `git fetch origin` 한다 — 스크립트는 fetch 하지 않는다.
2. **표를 보인다** — 버킷별로 묶어 낸다. `safe` 를 기본 후보로 제시하고, `review`·`hold-recent` 는 사용자가 경로나 이름으로 지목하면 넣을 수 있다고 알린다. `current`·`hold-*`(recent 제외)는 스크립트가 거부하므로 후보에 넣지 않는다 — 각 버킷이 왜 막히는지 한 구씩 붙인다(`hold-chain` 은 chain-plan 재개가 그 안의 `plan.md` 를 읽는다).
3. **삭제 계획을 보이고 한 번 승인받는다** — 고른 경로로 `remove --dry-run <경로>...` 를 돌려 `BACKUP`·`SKIP` 줄을 그대로 보인다. `SKIP`(상한을 넘어 백업하지 않는 ignore 폴더)은 지운 뒤 되살릴 수 없으니 항목마다 이름과 크기를 보인다. 승인 없이 4번으로 가지 않는다 — 미추적·ignore 파일은 git 이력에 없어 백업 밖의 것은 복구 경로가 없다.
4. **삭제** — 승인받은 경로 그대로 `remove <경로>...` 를 돌린다. 경로를 바꾸거나 늘리려면 3번으로 돌아간다.
5. **보고** — `RESULT` 줄, 지운 경로와 백업 위치, `REFUSED`·`FAILED` 경로와 사유, 건너뛴 ignore 폴더. 백업은 `%TEMP%\karina-plugin\worktree-backup\`(`../TEMP-FILES.md`)에 남고 자동으로 지우지 않는다 — 지우려면 `/karina:temp-cleanup` 이고, OS 의 임시 폴더 정리에는 지워질 수 있다고 한 줄 붙인다.

## 하지 않는 것

- **브랜치를 지우지 않는다** — 커밋은 브랜치 ref 에 남아 worktree 폴더를 지워도 잃지 않는다. 브랜치 정리는 이 스킬 밖이다.
- **`git worktree remove`·`rm` 을 직접 치지 않는다** — 백업과 거부 판정은 스크립트 안에만 있어, 직접 지우면 `plan.md` 를 백업 없이 잃는다.
- **`FAILED` 를 다른 수단으로 재시도하지 않는다** — Karina 앱이 꺼져 있으면(`runtime_unavailable`) 앱을 켠 뒤 다시 돌리라고 보고한다. git 으로 지우면 앱의 worktree 카드와 터미널이 남는다.
