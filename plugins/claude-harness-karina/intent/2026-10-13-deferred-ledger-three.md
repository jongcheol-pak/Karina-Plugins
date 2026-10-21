# Intent: Deferred 대장 대기 3건 처리
Author: 사용자(jongcheol-pak). Status: approved.

## Problem
원문 요청: 「남은작업은」 → 「계획작성」(대장 대기 3건 셋 다 — 사용자 답). ① [2026-09-20] 하니스 레포 `[DECISION]` 4건이 vault 큐에 들어가 있다는 항목 — 실측하니 지금 큐에 하니스 `[DECISION]` 은 0건이다(42건 전부 Karina · 2026-09-18 이후 큐 이력에도 없음). ② [2026-10-08] `guard-bash` 의 require-task-checkbox 가 `-F <파일>`·`-F -`·`-m $변수` 커밋의 제목을 읽지 못해 체크박스 검사를 조용히 건너뛴다. ③ [2026-10-13] 정합 검사기의 제외 규칙이 흩어져 있다 — 「기록 문서(날짜 이름 회차 문서·아카이브·plan/notes)」 판정이 같은 꼴로 세 곳에 복제돼 있다. 후보 라운드에서 하나를 더했다: `block-plan-write` 의 리다이렉션 검사가 heredoc 본문을 걷기 전 원문을 훑어, `cat > a.txt <<'EOF'` 본문 속 `> plan.md` 문자열까지 막는다(2026-10-12 실해 1건 · 재현 rc=2).

## Proposed outcome
① 대장 항목을 「기각(대상 소멸)」으로 종결한다 — K 5-2 의 하니스 예외는 유지한다(사용자 답). ② `-F <파일>` 은 cwd 기준 파일 첫 줄, `-F -` 는 같은 명령의 heredoc(Bash)·here-string(PowerShell) 본문 첫 줄을 제목으로 읽어 지금과 같은 차단 판정을 하고, 끝내 못 읽으면(변수 `-m`·없는 파일) 차단하지 않고 「제목을 읽지 못해 체크박스 검사를 건너뛴다」 경고를 낸다 — plan 파일이 있을 때만(사용자 답). 커밋 규약 서술 세 자리(`-F` 는 검사를 건너뛴다)를 새 동작에 맞춘다. ③ 복제된 기록 문서 판정 세 곳을 술어 하나로 묶고, 축마다 뜻이 다른 셋(대장 파일 면제·포인터 쌍 면제·`--fix` 금지 파일)은 합치지 않고 정의를 한 블록에 모은다(사용자 답). 추가: `block-plan-write` 의 리다이렉션 검사를 데이터 싱크 heredoc 본문을 걷은 명령에 돌린다 — `open('plan.md','w')`·`[System.IO.File]` 검사는 원문에 두어 차단 범위를 줄이지 않는다. 추가(계획 리뷰 중 실해 — 사용자 답 「포함」): `block-plan-write` 가 `sed -i … plan.md 2>&1 | head` 처럼 뒤에 리다이렉션이 붙으면 대상을 못 보는 미탐을 막는다. 정상 경로에서 차단되던 것은 계속 차단된다. 대장 대기는 0 이 된다.

## Affected users and systems
모든 Bash/PowerShell 커밋 호출(`guard-bash`), 하니스 레포를 고치는 세션(정합 검사기). `plugins/pjc/scripts/guard-bash.ps1`·`rules/bash-guard-rationale.md`, `plugins/pjc/hooks/evals/scenarios/guard-bash.ps1`·`run-hook-evals.ps1`, `plugins/pjc/evals/check-harness-consistency.py`·rationale·`cases.json`·fixtures, `AGENTS.md`·`docs/harness-conventions.md`·`docs/golden-runner.md`·`plugins/pjc/skills/implement/SKILL.md`, `docs/plans/deferred.md`·`deferred-closed.md`.

## Constraints
차단 hook 변경은 오탐 수정·미탐 보완만 허용되고 골든 실증이 붙는다(AGENTS.md DO NOT). 끝내 못 읽는 제목은 차단하지 않는다(오차단 금지). ③ 은 판정 불변이다. CRLF·`.ps1` BOM 규약 · 파일 예산.

## Open questions
없음
