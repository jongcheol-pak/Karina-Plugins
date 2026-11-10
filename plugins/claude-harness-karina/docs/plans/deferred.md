# Deferred 대장

> 미처리 Deferred의 추적 대장 — **`## 대기`만 담는다**. 기각 종결은 `deferred-closed.md` 이고, 그 파일은 기각 이동 때만 연다.
> 항목은 `- [등록일] {요지 1줄} (출처) (실해: YYYY-MM-DD {관측 요지})` — **이 형식의 정본은 이 줄이다.** 실해 필드는 필수이고 `check-harness-consistency.py` 의 「등재 근거 실측」 축이 `## 대기` 전건을 잰다.
> **등재 판정 규칙**(등재 하한선·회차 순증 금지·리뷰 지적의 필터 패스)의 정본은 `plan/references/deferred-rules.md` 다.
> **항목 상한은 600자다**(정본은 `skills/BUDGET.md`). **종결은 사유로 갈린다 — 반영·해소·병합은 항목을 지우고 근거를 커밋 본문에 남긴다. 기각만 `deferred-closed.md` 로 `- [등록일 → 종결일] **요지** — 기각: 사유` 1줄로 옮긴다.**
> `karina:plan` Step 1이 계획 때 `## 대기`를 조회하고, `karina:implement`가 완료 때 신규분을, `karina:reflect` 가 사용자가 고른 항목을 append한다.

## 대기

- [2026-10-14] **Bash 도구 10분 캡 동작 서술 재검증** — `golden-runner.md` 「고아 콘솔 프로세스는 자동 회수된다」 불릿·`guard-bash.ps1` 의 `find /` 경고 주석·`rules/bash-guard-rationale.md`·`rules/orphan-cleanup-rationale.md`·`README.md` 「끝나지 않을 검색 경고」가 「캡에 걸리면 셸이 죽어 `find` 가 고아로 남는다」고 서술하나, Claude Code 2.1.299 에서 timeout 600000 전경 실행은 시한에 백그라운드로 넘어가 완주했다. 판·시한 지정·`find /` 경로 차이를 재실측해 맞춘다(고아를 만드는 실험 세션 필요 · `guard-bash` 는 골든 실증) (출처: v1.371.0 회차 T1) (실해: 2026-10-14 golden-runner.md 안에서 「캡에 걸리면 셸이 죽는다」와 새 전경 완주 관측이 갈린다)

**▶ 현행 잔량(기계 대조 대상)**: 대기 14 / 종결 120

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

- [2026-11-07] **세션 시작 버전 점검의 원격 조회 캐시** — `scripts/warn-version-drift.ps1` 가 세션 시작마다 `git show origin/main:…/plugin.json` 과 `git ls-remote --tags origin karina-v<버전>` 을 돌린다. 원격 조회 결과를 짧은 TTL 로 캐시하는 안을 검토한다(체인 run_6150c8ac plan 3 후보 10 — 사용자 답 보류) (실해: 2026-11-07 작업 속도 감사의 후보 라운드에서 세션 시작 지연으로 제기 · 수치는 재지 않았다)

- [2026-11-07] **session-context 골든의 `$env:USERPROFILE` 누수** — `hooks/evals/scenarios/session-context.ps1` 의 앞 케이스(376·658·770행)가 USERPROFILE 을 vault 홈으로 바꾸고 되돌리지 않아, 뒤 블록들(876–880·926·957·978행)이 저마다 저장·복원하고 859–864행 주석이 그 사정을 해명한다. 앞 케이스를 try/finally 로 복원하고 뒤 블록의 보정과 주석을 지운다 (출처: 응답 언어 주기 재주입 회차 주석 정리 MUST KILL) (실해: 2026-10-08 01c09996 — 첫 RED 시도가 이 누수로 무효)

- [2026-11-01] **운영 hook 의 이벤트당 다중 pwsh 기동 통합** — `hooks/hooks.json` 이 도구 호출마다 hook 별로 pwsh 를 띄운다(PreToolUse `Bash|PowerShell` 2 + PostToolUse 2 · `Write|Edit` 2+2 · `Skill` 3). 이벤트·matcher 별 디스패처 하나로 묶되 안전 임계 hook 의 exit 2 합성과 골든 실증이 필요하다. 위키 decisions 2026-10-24 가 문구를 두 곳으로 가르는 안을 기각했으니 문구는 한 곳에 둔다 (출처: hook 골든 in-process 회차 후보 — 사용자 「대장에 등재」) (실해: 2026-11-01 빈 pwsh 기동 약 290ms · guard-bash 단독 약 790ms 가 도구 호출마다 든다 — 사용자 결정 예외)

- [2026-10-23] **chain-plan 코디네이터 검증 명령을 `run-verify.py` 밖에서 띄우면 guard-bash 가 경고** — `continuation.md`「코디네이터 검증」 은 명령마다 래퍼로 띄우라고 하지만 코디네이터가 어기면 감시가 빠진다. 명령줄로 잴 수 있는 것은 「래퍼를 거쳤는가」뿐이다(규칙대로면 `cargo` 는 스크립트 파일 안에 있다). 체인 실행 중 판정·`run_in_background` 판정과 골든 실증이 필요하다 (출처: 2026-10-23 karina-ea 요청 ④ — 사용자 「4는 대장」) (실해: 2026-10-23 run_34c092d3 plan 6 검증이 정리 명령과 검증 셋을 시한 없이 한 백그라운드에 묶어 80분 넘게 섰다)





### 하니스 스킬 (plan · implement · 리뷰어 · 템플릿)

- [2026-11-07] **완료 리뷰 전사 요약 증분 생성** — `implement/references/final-review.md` 「절차」 는 `completion-reviewer` 를 부를 때마다(재호출 포함) `reflect/scripts/digest_transcript.py --audit` 로 세션 전사 전체를 다시 요약한다. 재호출 때 앞 요약 뒤 구간만 더하는 증분 생성을 검토한다(체인 run_6150c8ac plan 3 후보 11 — 사용자 답 보류) (실해: 2026-11-07 작업 속도 감사의 후보 라운드에서 리뷰 재호출 비용으로 제기 · 수치는 재지 않았다)
- [2026-10-15] **chain-plan 후보 라운드에 「설계 결함」 종류가 없다** — `plan/references/interview.md` 「후보 라운드」는 코디네이터도 그 절을 따른다고 하나 `chain-plan/SKILL.md` 후보 라운드 줄·`references/measure.md` 반환 칸에 그 종류가 없다. 코디네이터가 물을지, 워커 몫(`relay-mode.md` 2-3)으로 두고 interview.md 에 예외를 적을지 정해 한쪽 문면을 고친다 (출처: v1.374.0 회차 후보 라운드 ④) (실해: 2026-10-15 prompt-audit 2회차가 interview.md 와 chain-plan 문면이 갈리는 것을 관측)
- [2026-10-18] **디버깅 재현 BASE 대조** — `karina-systematic-debugging` 재현 단계에서 같은 재현 시나리오를 BASE worktree 에서도 돌려 회귀가 이 변경에서 생겼는지 가른다(절차 선례 `implement/references/report-format.md`「화면 시나리오 실행」의 (BASE 대조)) (출처: 계획 체인 run_60c0ebe3 plan 3 후보 라운드 — 사용자 「보류」) (실해: 2026-10-18 사용자 보류 결정(deferred-rules 사용자 결정 예외) — 디버깅 재현은 현재 HEAD 에서만 돌아 회귀 시점을 가르지 못함)
- [2026-10-27] **완료 보고 요구 항목별 결과 줄** — `implement/references/report-format.md` 「보고 형식」에 `> 요구:` 항목마다 `완료 | 미검증 | 실패 | 사용자 대기` 와 도중에 고친 결함을 한 줄씩 싣는 줄을 둔다(pstack ketchup *"one short bullet per thing the user asked for"* — HUMAN-VERIFY·수정 내용과 겹치지 않게) (출처: 완료 보고 확인할 파일 회차 후보 라운드 8 — 사용자 「보류」) (실해: 2026-10-27 사용자 보류 결정(deferred-rules 사용자 결정 예외) — 보고 「수정 내용」 이 서술형이라 요구와 결과를 사용자가 직접 대조하지 못함)
- [2026-10-19] **체인 병렬 그룹의 넘긴 질문 시한 대기** — `chain-plan/scripts/wait-worker.py --answer-by` 는 `--dispatch` 하나에만 받아, 병렬 그룹이 돌 때 사용자에게 넘긴 ②·③ 질문은 상한 없이 기다린다. 병렬 대기와 미답 시한을 함께 재는 갈래를 둔다(`chain-plan/references/user-relay.md`「미답 기본값」·`parallel.md`) (출처: 계획 체인 run_60c0ebe3 plan 6 후보 라운드 — 사용자 「보류」) (실해: 2026-10-19 사용자 보류 결정(deferred-rules 사용자 결정 예외) — 병렬 그룹 중 넘긴 질문은 미답 기본값이 걸리지 않아 체인이 선다)
- [2026-10-19] **체인 실행 시점 승인·기존 것을 깨는 변경 대기의 재알림** — 사용자 몫 ①·④ 로 넘긴 질문은 상한 없이 기다리고 처음 한 번만 `PushNotification` 으로 알린다. 일정 시간(예: 30분)마다 다시 알리는 장치를 둔다(`chain-plan/references/user-relay.md`「사용자에게 넘기기」) (출처: 계획 체인 run_60c0ebe3 plan 6 후보 라운드 — 사용자 「보류」) (실해: 2026-10-19 사용자 보류 결정(deferred-rules 사용자 결정 예외) — 첫 알림을 놓치면 ①·④ 질문이 열린 채 체인이 선다)
- [2026-10-19] **record-project-fact 의 커밋·PR 단계** — `karina:record-project-fact` 가 AGENTS.md 를 고친 뒤 커밋·PR 단계가 없다(`record-project-fact/SKILL.md` 의 커밋 언급은 사본 폴더 주의 2줄뿐). 디버깅 직접 수정 경로처럼 `implement/references/push-flow.md`「디버깅 단독 경로」 의 커밋을 쓸지, 작업 중간 기록이라 커밋을 미룰지 정한다 (출처: 디버깅 커밋·PR 회차 후보 라운드 — 사용자 「보류」) (실해: 2026-10-19 사용자 보류 결정(deferred-rules 사용자 결정 예외) — AGENTS.md 기록이 커밋 없이 작업 트리에만 남는다)
- [2026-11-11] **병렬 그룹 조건 완화** — `chain-plan/references/parallel.md`「병렬 그룹」 의 넷(의존 없음·바뀌는 파일 겹침 없음·검증이 새 체크아웃에서 돈다·동시 상한 2) 중 무엇이 실제 체인에서 그룹을 막는지 먼저 재고, 막는 조건만 완화한다(상한 상향 · ignored 파일 복사 — 시크릿 이동 검토 필요) · 넘기는 셋 ②(규칙 문턱 변경) (출처: 2026-11-11 체인 병목 감사 — 사용자 「대장 등재」) (실해: 2026-11-11 미관측 — 사용자 지시 등재(deferred-rules 사용자 결정 예외) · 전사에서 실제 병렬 그룹 형성 사례 0건이라 체인이 계획 합만큼 직렬로 돈다)

### llm-wiki · vault


### eval · 측정

