# `hook-event-log` 판정 근거

> `hook-event-log.ps1`의 주석에서 옮긴 판정 근거다. 스크립트에는 각 자리에 이 문서의 절을 가리키는 1줄만 남겼다.
> **문면을 요약하지 않고 이동만 했다** — 이관은 이동이지 요약이 아니다.

## §1 hook-event-log.ps1 — 공유 이벤트 로깅 헬퍼

```
# hook-event-log.ps1 — 공유 이벤트 로깅 헬퍼 (dot-source 전용, hook 아님)
#
# 왜: hook 차단/경고 오탐은 발생 시점에만 데이터가 존재한다 — 회고 검토(v1.98.0, 발견 ~40건 수동 발굴)
#   대신 이벤트를 로컬 jsonl로 적재해 다음 오탐 수정 라운드를 실측 기반으로 만든다.
# 어디에: ~/.claude/.state/hook-events/{YYYY-MM}.jsonl (기존 .state 마커 패턴과 동일 계층,
#   월별 파일 — 90일 초과 파일은 append 시 자동 정리).
# 안전 계약 (절대 불변):
#   ① 이 함수의 어떤 실패도 호출한 hook의 차단/경고 판정에 영향을 주지 않는다 — 전체 try/catch로
#      삼키고, 호출측도 Get-Command 가드 + try/catch로 감싼다(로드 실패 = 로깅만 조용히 생략).
#   ② 로그에 시크릿 평문을 남기지 않는다 — 명령 원문은 secret-patterns.ps1(단일 출처) 검사를
#      통과할 때만 앞 200자를 기록하고, 시크릿 검출·판정 불가 시 cmd 필드 자체를 생략한다
#      (fail-closed — Get-SecretMatches는 라벨만 반환하므로 값 치환 대신 생략이 안전하고 단순하다).
```


## §2 Write-HookSlowEvent — 느린 실행 기록

```powershell
# 왜: 차단 hook 넷은 onFailure: block 이라 timeout 을 넘기면 도구 호출이 통째로 막힌다. 2026-11-03 동시 세션
#   부하에서 guard-bash 가 옛 15초를 넘겨 Bash·PowerShell 이 막혔는데, 평시 소요(1~2초)로는 재현되지 않아
#   timeout 값을 정할 실측이 없었다. 기준을 넘긴 실행을 남겨 다음 처방(timeout 값·pwsh 기동 통합)의 근거로 쓴다.
# 무엇을 재나: 지금 − 현재 프로세스 시작 시각. hook 은 도구 호출마다 새 pwsh 프로세스라 이 값이 pwsh 기동을
#   포함한 hook 소요다(빈 pwsh 기동 379ms 가 guard-bash 평시 884ms 의 43% — hook 안 스톱워치는 그만큼 놓친다).
# 기준: KARINA_HOOK_SLOW_MS(0 이상 정수), 없거나 정수가 아니면 5000ms — 평시 최대 1.7초의 약 3배.
#   검사를 끄지 않으므로 우회 변수가 아니다(우회 변수는 둘 — docs/harness-conventions.md).
# 어디서 부르나: guard-bash·block-destructive 의 정상 종료(차단 exit 2 · 통과 exit 0) 직전. 파싱 실패·빈 명령·
#   규칙 로드 실패의 이른 종료는 부르지 않는다.
# 한계: timeout 으로 강제 종료된 실행은 종료 지점에 닿지 못해 남지 않는다 — 시작 표지를 쓰고 지우는 설계는
#   도구 호출마다 파일 I/O 2회와 남은 표지 정리가 늘어 제외했다(2026-11-03 사용자 답).
# 골든: Windows 골든은 hook 을 러너 프로세스 안(in-process)에서 돌려 시작 시각이 러너의 것이다. 기본 기준이면
#   모든 호출이 slow 를 써서 hooks/evals/eval-common.ps1 머리가 기준을 하루로 두고, slow 케이스만 0 으로 바꾼다.
# 안전 계약 ①: 이 함수의 실패도 전체 try/catch 로 삼켜 차단/통과 판정에 영향을 주지 않는다.
```
