# Deferred 대장

> 미처리 Deferred의 추적 대장 — **`## 대기`만 담는다** (형식 정본: `plan/references/deferred-rules.md`).
> **v1.198.0에서 둘로 갈렸다**: 기각 종결은 `deferred-closed.md`.
> **등재·조회는 이 파일 하나**이고 종결 대장은 기각 이동 때만 연다 — 분할 전 296KB가 계획 1건마다 통째로 실렸다.
> 항목은 `- [등록일] {요지 1줄} (출처) (실해: YYYY-MM-DD {관측 요지})` — **실해 필드는 필수**이고 `check-harness-consistency.py` 의 「등재 근거 실측」 축이 `## 대기` 전건을 잰다.
> **등재 하한선은 축 둘을 모두 넘어야 한다** — ① **실해**(틀린 출력·차단·유실·오탐이 실제로 일어났다) ② **액션**(그 항목이 지시하는 것이 파일 수정이다). 「현재 오차 0이다」·「조건이 오면 터진다」·「재는 축이 없다」·「관측 경로가 구조적으로 없다」는 ①에서, **교훈·작성법·착수 전 점검 목록·미착수 제안**은 ②에서 떨어진다(정본은 `plan/references/deferred-rules.md`).
> **회차 순증 금지** — 한 회차가 등재하는 수는 종결하는 수를 넘지 않는다. **리뷰 소스의 지적은 `implement/references/final-review.md`「필터 패스」가 먼저 가르고, 거기서 걸러지지 않은 것만 이 문턱을 통과한다.**
> **항목 상한은 600자다** — 대장은 「무엇을 고칠지」의 목록이지 조사 기록이 아니다(정본은 `skills/BUDGET.md`). **종결은 사유로 갈린다 — 반영·해소·병합은 항목을 지우고 근거를 커밋 본문에 남긴다. 기각만 `deferred-closed.md` 로 `- [등록일 → 종결일] **요지** — 기각: 사유` 1줄로 옮긴다** — 기각은 「하지 않기로 했다」는 결론이라 커밋에 근거가 없고, 지우면 다음 계획이 같은 것을 다시 제안한다. 반영된 것은 코드와 커밋이 담아 다시 읽을 기록이 따로 필요 없다.
> `karina:plan` Step 1이 계획 때 `## 대기`를 조회하고, `karina:implement`가 완료 때 신규분을, `karina:reflect` 가 사용자가 고른 항목을 append한다.

## 대기

- [2026-10-14] **Bash 도구 10분 캡 동작 서술 재검증** — `golden-runner.md` 「고아 콘솔 프로세스는 자동 회수된다」 불릿·`guard-bash.ps1` 의 `find /` 경고 주석·`rules/bash-guard-rationale.md`·`rules/orphan-cleanup-rationale.md`·`README.md` 「끝나지 않을 검색 경고」가 「캡에 걸리면 셸이 죽어 `find` 가 고아로 남는다」고 서술하나, Claude Code 2.1.299 에서 timeout 600000 전경 실행은 시한에 백그라운드로 넘어가 완주했다. 판·시한 지정·`find /` 경로 차이를 재실측해 맞춘다(고아를 만드는 실험 세션 필요 · `guard-bash` 는 골든 실증) (출처: v1.371.0 회차 T1) (실해: 2026-10-14 golden-runner.md 안에서 「캡에 걸리면 셸이 죽는다」와 새 전경 완주 관측이 갈린다)

**▶ 현행 잔량(기계 대조 대상)**: 대기 12 / 종결 119

> 이 한 줄만 기계 대조 대상이다 — `evals/check-harness-consistency.py` 가 두 파일을 각각 세어 이 값과 대조한다. 대장을 편집한 task 는 **이 줄만** 갱신한다(절대값 — 증분 로그가 아니다).
>
> **카운트 기준 (두 파일의 표기 형식이 다르다 — 파일마다 자기 패턴을 쓴다)**:
> - **대기** = 이 파일 `## 대기` 구간에서 **`^- \[\d{4}-\d{2}-\d{2}`** — 날짜 **접두**만 본다. `[등록일, **vN에서 부분 해소**]` 처럼 부기가 붙는 형식이 실재하므로 `\]` 로 닫는 패턴을 쓰면 그런 항목이 조용히 누락된다.
> - **종결** = `deferred-closed.md` `## 종결` 구간에서 **`^- \[\d{4}-\d{2}-\d{2} → \d{4}-\d{2}-\d{2}\]`** — `[등록일 → 종결일]` 날짜 범위 형식. 대기 패턴을 여기 쓰면 0건이 나온다.
> - **앵커는 이 파일에만 둔다** — 계수의 정본이 한 곳이어야 파일끼리 갈리지 않는다.
> - **연산 규칙**:
>
>   | 연산 | 갱신 |
>   |---|---|
>   | 등재 | `대기 +1` |
>   | 반영·해소·병합 종결(대기에서 삭제 — 근거는 커밋 본문) | `대기 -1` |
>   | 기각 종결(`deferred-closed.md` 로 1줄 이동 — 형식은 `check-harness-consistency.py` 의 축 ⑨ 가 잰다) | `대기 -1` · `종결 +1` |
>   | 종결→대기 복원(오종결 교정) | `종결 -1` · `대기 +1` |
>
>   요지 수정·재확인 표기 추가·그룹 재배치는 개수를 바꾸지 않는다.

### 대장 운영

- [2026-10-22] **세션 시작 대장 신호의 「축 ② 임계 30일」 문구 정리** — `scripts/session-ledger-signal.ps1` 이 대장 최고령을 「축 ② 임계 30일」 과 함께 주입하는데, 그 임계는 소진 batch 착수 조건이고 batch 절차와 batch 회고 대장은 이제 없다. 문구를 현행 용도로 고치거나 신호를 걷고 `scripts/rules/session-context-rationale-plan.md` §12 와 hook 골든 SC44 계열을 함께 맞춘다 (출처: batch 회고 대장 삭제 회차 후보 라운드 — 사용자 보류) (실해: 2026-10-22 세션 시작 주입 「최고령 8일 — 축 ② 임계 30일」 이 없어진 절차의 임계를 안내)

### hook · 안전망 (차단·경고·골든 러너)

- [2026-11-01] **운영 hook 의 이벤트당 다중 pwsh 기동 통합** — `hooks/hooks.json` 이 도구 호출마다 hook 별로 pwsh 를 띄운다(PreToolUse `Bash|PowerShell` 2 + PostToolUse 1 · `Write|Edit` 2+1 · `Skill` 3). 이벤트·matcher 별 디스패처 하나로 묶되 안전 임계 hook 의 exit 2 합성과 골든 실증이 필요하다. 위키 decisions 2026-10-24 가 문구를 두 곳으로 가르는 안을 기각했으니 문구는 한 곳에 둔다 (출처: hook 골든 in-process 회차 후보 — 사용자 「대장에 등재」) (실해: 2026-11-01 빈 pwsh 기동 약 290ms · guard-bash 단독 약 790ms 가 도구 호출마다 든다 — 사용자 결정 예외)

- [2026-10-23] **chain-plan 코디네이터 검증 명령을 `run-verify.py` 밖에서 띄우면 guard-bash 가 경고** — `continuation.md`「코디네이터 검증」 은 명령마다 래퍼로 띄우라고 하지만 코디네이터가 어기면 감시가 빠진다. 명령줄로 잴 수 있는 것은 「래퍼를 거쳤는가」뿐이다(규칙대로면 `cargo` 는 스크립트 파일 안에 있다). 체인 실행 중 판정·`run_in_background` 판정과 골든 실증이 필요하다 (출처: 2026-10-23 karina-ea 요청 ④ — 사용자 「4는 대장」) (실해: 2026-10-23 run_34c092d3 plan 6 검증이 정리 명령과 검증 셋을 시한 없이 한 백그라운드에 묶어 80분 넘게 섰다)





### 하니스 스킬 (plan · implement · 리뷰어 · 템플릿)

- [2026-10-15] **chain-plan 후보 라운드에 「설계 결함」 종류가 없다** — `plan/references/interview.md` 「후보 라운드」는 코디네이터도 그 절을 따른다고 하나 `chain-plan/SKILL.md` 후보 라운드 줄·`references/measure.md` 반환 칸에 그 종류가 없다. 코디네이터가 물을지, 워커 몫(`relay-mode.md` 2-3)으로 두고 interview.md 에 예외를 적을지 정해 한쪽 문면을 고친다 (출처: v1.374.0 회차 후보 라운드 ④) (실해: 2026-10-15 prompt-audit 2회차가 interview.md 와 chain-plan 문면이 갈리는 것을 관측)
- [2026-10-18] **디버깅 재현 BASE 대조** — `karina-systematic-debugging` 재현 단계에서 같은 재현 시나리오를 BASE worktree 에서도 돌려 회귀가 이 변경에서 생겼는지 가른다(절차 선례 `implement/references/report-format.md`「화면 시나리오 실행」의 (BASE 대조)) (출처: 계획 체인 run_60c0ebe3 plan 3 후보 라운드 — 사용자 「보류」) (실해: 2026-10-18 사용자 보류 결정(deferred-rules 사용자 결정 예외) — 디버깅 재현은 현재 HEAD 에서만 돌아 회귀 시점을 가르지 못함)
- [2026-10-27] **완료 보고 요구 항목별 결과 줄** — `implement/references/report-format.md` 「보고 형식」에 `> 요구:` 항목마다 `완료 | 미검증 | 실패 | 사용자 대기` 와 도중에 고친 결함을 한 줄씩 싣는 줄을 둔다(pstack ketchup *"one short bullet per thing the user asked for"* — HUMAN-VERIFY·수정 내용과 겹치지 않게) (출처: 완료 보고 확인할 파일 회차 후보 라운드 8 — 사용자 「보류」) (실해: 2026-10-27 사용자 보류 결정(deferred-rules 사용자 결정 예외) — 보고 「수정 내용」 이 서술형이라 요구와 결과를 사용자가 직접 대조하지 못함)
- [2026-10-19] **체인 병렬 그룹의 넘긴 질문 시한 대기** — `chain-plan/scripts/wait-worker.py --answer-by` 는 `--dispatch` 하나에만 받아, 병렬 그룹이 돌 때 사용자에게 넘긴 ②·③ 질문은 상한 없이 기다린다. 병렬 대기와 미답 시한을 함께 재는 갈래를 둔다(`chain-plan/references/user-relay.md`「미답 기본값」·`parallel.md`) (출처: 계획 체인 run_60c0ebe3 plan 6 후보 라운드 — 사용자 「보류」) (실해: 2026-10-19 사용자 보류 결정(deferred-rules 사용자 결정 예외) — 병렬 그룹 중 넘긴 질문은 미답 기본값이 걸리지 않아 체인이 선다)
- [2026-10-19] **체인 실행 시점 승인·기존 것을 깨는 변경 대기의 재알림** — 사용자 몫 ①·④ 로 넘긴 질문은 상한 없이 기다리고 처음 한 번만 `PushNotification` 으로 알린다. 일정 시간(예: 30분)마다 다시 알리는 장치를 둔다(`chain-plan/references/user-relay.md`「사용자에게 넘기기」) (출처: 계획 체인 run_60c0ebe3 plan 6 후보 라운드 — 사용자 「보류」) (실해: 2026-10-19 사용자 보류 결정(deferred-rules 사용자 결정 예외) — 첫 알림을 놓치면 ①·④ 질문이 열린 채 체인이 선다)
- [2026-10-19] **Y 체인 끝 PR 의 merge 된 비 karina 기능 브랜치** — `Y` 체인을 이미 merge 된 `karina/` 아닌 기능 브랜치에서 시작하면 「Y 체인 끝 PR」 이 `pr-flow.md`「브랜치」 표의 「그 밖」 행으로 그 브랜치에서 PR 을 연다. merge 된 브랜치 판정을 비 `karina` 브랜치로 넓힐지 정한다(`chain-plan/references/pr-mode.md`「Y 체인 끝 PR」·`implement/references/pr-flow.md`「브랜치」) (출처: 계획 체인 run_60c0ebe3 plan 8 후보 라운드 — 사용자 「보류」) (실해: 2026-10-19 사용자 보류 결정(deferred-rules 사용자 결정 예외) — 끝 PR 이 merge 된 옛 브랜치 위에서 열려 diff 에 merge 된 변경이 섞인다)
- [2026-10-19] **record-project-fact 의 커밋·PR 단계** — `karina:record-project-fact` 가 AGENTS.md 를 고친 뒤 커밋·PR 단계가 없다(`record-project-fact/SKILL.md` 의 커밋 언급은 사본 폴더 주의 2줄뿐). 디버깅 직접 수정 경로처럼 `implement/references/pr-flow.md` 를 쓸지, 작업 중간 기록이라 PR 을 열지 않을지 정한다 (출처: 디버깅 커밋·PR 회차 후보 라운드 — 사용자 「보류」) (실해: 2026-10-19 사용자 보류 결정(deferred-rules 사용자 결정 예외) — AGENTS.md 기록이 커밋 없이 작업 트리에만 남는다)
- [2026-10-29] **멈춤 보고에 백그라운드 셸 상한 초과 표시** — `chain-plan/scripts/wait-worker.py` 의 stall 이 `BUSY_SAME_MAX` 초과(백그라운드 셸·CI pending 대기)로 났으면 RESULT·멈춤 보고(`report.md`)에 「오판일 수 있다」를 싣는다 (출처: chain-plan stall 뒤 감시 회차 후보 라운드 — 사용자 「보류」) (실해: 2026-10-29 Karina 체인 plan 10 이 경계 감사 백그라운드 대기 중 stall 로 멈췄다 — 사용자 보류 결정(deferred-rules 사용자 결정 예외))

### llm-wiki · vault


### eval · 측정


---

> **분리된 종결 대장** — 이 대장은 `## 대기`만 담는다(v1.198.0 분할).
> - **종결 항목**: `docs/plans/deferred-closed.md` — 기각 종결분. 계수는 위 앵커가 정본이다.
