# 재사용 범위 판정 — 두 커밋 사이 변경이 검증을 다시 돌 필요가 있는가

> 앞서 검증한 커밋에서 HEAD 가 움직였을 때 그 검증을 재사용할 수 있는지 가르는 정본이다. 가리키는 자리 — `local-gate.md`「판정 재사용」 ⓐ·「중간 단계」·「디버깅 단독」 · `gate-verifier-conditional.md`「직전 판정 재사용」·「중간 단계」. 각 자리는 이 판정의 결과만 쓰고, 결과마다 무엇을 다시 도는지는 그 자리가 정한다.

## 재사용 범위 판정

- **`<A>..<B>` 의 바뀐 파일(`git diff --name-only --no-renames <A>..<B>`)이 전부 문서(`.md`·`.txt`)이고 그중에 `AGENTS.md`·검증 매핑 문서가 없고 그 레포 검증 매핑(`AGENTS.md` 또는 그것이 지목한 문서)이 그 경로에 명령을 걸지 않고, 바뀐 각 파일의 이름이 `.md`·`.txt` 밖 추적 파일에 따옴표 바로 앞 문자열로 나오지 않으면(`git grep -l -F -e '<이름>"' -e "<이름>'" -- . ':!*.md' ':!*.txt'` 이 비었다 — 레포 최상위에서) 판정은 「문서뿐」 이다. 하나라도 거짓이면 거짓이다** — 문구만 바뀐 변경을 다시 검증하면 같은 판정을 두 번 산다(*"a wording-only change gets none"*). 매핑 문서를 고친 변경은 문구가 아니라 어느 검사가 도는지를 바꿔 재사용하지 않는다(원문 autopilot-full *"a change to which checks run"* — `https://github.com/cursor/plugins/blob/ae5650febf4320793844c12c4adaa937f417f8da/pstack/skills/poteto-mode/playbooks/autopilot-full.md`). 검증 매핑이 `*.md` 에 명령을 거는 레포(이 하니스)는 늘 거짓이다. 이름 대조는 빌드가 읽는 문서를 거른다 — Karina 는 `include_str!` 로 `SKILL.md`·`fixtures/*.txt` 를 빌드에 넣어(2026-11-11 실측), 확장자만 보면 그 파일만 고친 수정 커밋이 재검증 없이 push 된다.
