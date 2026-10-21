---
name: reflect
description: 현재 세션의 대화 전사를 읽어 karina 스킬·hook 의 개선 후보 표를 내고, 사용자가 고른 것만 Deferred 대장에 올린다. 스킬 파일은 고치지 않는다. 사용자 호출 전용.
disable-model-invocation: true
---

# Reflect

> 출처는 Cursor pstack 의 reflect 다 — 고정 위치 `https://github.com/cursor/plugins/blob/190d28736eff128ec94f502a22c7fe0c4b56cd37/pstack/skills/reflect/SKILL.md`. Copyright (c) 2026 Lauren Tan · MIT(`https://github.com/cursor/plugins/blob/190d28736eff128ec94f502a22c7fe0c4b56cd37/pstack/LICENSE`).
>
> **원문과 다르게 한 것** — ① 리뷰어 셋(judgment·tooling·divergent)과 합성기를 읽기 전용 에이전트 `reflect-reviewer` 하나로 합쳤다 ② 승인된 후보를 스킬 편집으로 적용하지 않고 Deferred 대장에 올리기만 한다 — 스킬 수정은 별도 `karina:plan` 회차가 맡는다(위키 `decisions.md` 2026-10-20 reflect 기각 사유) ③ Backlog 를 승인 없이 트래커에 올리지 않고, 사용자가 고른 후보만 등재한다 ④ 전사 원본 대신 스크립트 요약을 읽힌다.
> **들이지 않은 파일** — `references/judgment-reviewer.md` · `references/tooling-reviewer.md` · `references/divergent-reviewer.md` · `references/synthesizer.md`(쓸모 있는 관점은 `../../agents/reflect-reviewer.md` 에 합쳤다).

사용자가 `/karina:reflect` 로 부를 때만 돈다. 다른 스킬·hook 이 이 스킬을 부르지 않는다 — 작업이 끝날 때 저절로 돌지 않는 것이 이 스킬의 전제다.

## 진행

1. **하니스 루트인가를 가른다** — 작업 디렉터리의 `.claude-plugin/plugin.json` 의 `name` 이 `karina` 이고 `docs/plans/deferred.md` 가 있으면 하니스 루트다. 아니면 플러그인 루트는 이 SKILL.md 의 두 단계 위(설치본)다.
2. **요약을 만든다** — `python "<skill>/scripts/digest_transcript.py" --out <스크래치 경로>/reflect-digest.txt`(`<skill>` 은 이 SKILL.md 의 폴더). 현재 세션은 환경변수 `CLAUDE_CODE_SESSION_ID` 로 정해지고, 그 세션의 서브에이전트 전사까지 읽는다. **exit 2·3 이면 출력 원문을 보고하고 멈춘다** — 2 는 세션 파일을 하나로 정하지 못한 것, 3 은 전사 형식이 바뀌었을 수 있다는 것이다. 다른 세션 파일로 대신하지 않는다.
3. **`reflect-reviewer` 를 이름으로 1회 부른다** — 입력은 요약 경로 · 플러그인 루트 · 대장 경로(`<플러그인 루트>/docs/plans/deferred.md`) · 하니스 루트 여부 · 오늘 날짜다.
4. **표를 그대로 보이고 번호로 고르게 한다** — 리뷰어의 「후보」 표와 「뺀 것」을 고치지 않고 싣는다. 하한선 ✗ 후보도 고를 수 있다 — 등재 하한선은 자동 발견의 문턱이고 사용자가 고른 것은 그 예외다(`../plan/references/deferred-rules.md`「등재 하한선」). **고른 것이 없으면 여기서 끝낸다.**
5. **지운 항목을 이력에서 찾는다(하니스 루트만)** — 고른 후보마다 핵심어로 `git log -S '<핵심어>' --oneline -- docs/plans/` 를 돌린다. 걸린 커밋이 있으면 보이고 그 후보를 그대로 올릴지 다시 묻는다 — 반영·해소로 지운 항목은 대장 파일에 남지 않아 리뷰어가 못 본다.
6. **등재한다**
   - **하니스 루트면** 고른 대장 줄 초안을 스크래치 파일에 한 줄씩 쓰고, 그룹마다 `python "<skill>/scripts/append_deferred.py" --ledger docs/plans/deferred.md --group "<그룹>" --entries <파일>` 로 넣는다. **대장을 Edit 도구로 고치지 않는다** — 파일 전체가 LF 로 바뀌어 정합 검사가 실패한다. exit 2 면 출력 원문을 보이고 그 줄을 고칠지 묻는다.
   - 넣은 뒤 `python evals/check-harness-consistency.py` 를 돈다. **exit 0 이면** `git commit -- docs/plans/deferred.md` 로 로컬 커밋한다 — 제목 `문서: reflect 개선 후보 <N>건 대장 등재`, 본문에 세션 ID 앞 8자와 넣은 요지들, 메시지는 heredoc 으로 넘긴다. **exit ≠ 0 이면 커밋하지 않고** 검사 출력 원문과 `git diff --stat -- docs/plans/deferred.md` 를 보고한다 — 원인이 이번 등재와 무관한 기존 불일치일 수 있어 되돌리기는 사용자가 정한다.
   - **커밋할 때 시크릿 경고가 하나라도 뜨면 커밋하지 않고 보고한다.**
   - **하니스 루트가 아니면 파일을 쓰지 않는다** — 고른 줄을 보고에 그대로 싣고, karina 하니스 레포 세션에서 다시 부르거나 붙여 넣으라고 적는다.
7. **보고한다** — 등재 수와 커밋 SHA, 또는 「미등재 — 하니스 루트 아님」과 대장 줄들. 뺀 것과 고르지 않은 것은 한 줄씩 남긴다.

## 하지 않는 것

- **스킬·hook·에이전트 파일을 고치지 않는다** — 후보가 가리키는 수정은 사용자가 나중에 `karina:plan` 으로 부른다.
- **push 하지 않는다** — 로컬 커밋까지다.
- **다른 세션·다른 프로젝트의 전사를 읽지 않는다** — 그 세션의 개선 후보는 그 세션에서 부른다.
- **사용자가 고르지 않은 후보를 올리지 않는다.**
