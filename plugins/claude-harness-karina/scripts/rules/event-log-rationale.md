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


**세션 식별자 필드(2026-11-20).** `Write-HookEvent`·`Write-HookSlowEvent` 는 선택 인자 `-SessionId` 를 받아 줄에 `session_id` 로 싣는다 — 값은 `[^\w.-]` 를 `_` 로 바꾸고 64자로 자르며, 비면 필드를 싣지 않는다. 호출부(`block-destructive`·`guard-bash`·`guard-harness`·`guard-comment`·`guard-doc-owner`·`guard-write`·`post-write-checks`)가 자기가 읽은 stdin 의 `session_id` 를 넘긴다 — 헬퍼는 dot-source 되고 stdin 은 hook 이 이미 읽어 헬퍼가 다시 읽지 못한다. 필드가 없던 로그로는 같은 세션에서 같은 차단이 몇 번 이어졌는지 잴 수 없었다(14일 block 568줄 중 0). 전역 변수에 담지 않은 것은 골든의 in-process runspace 가 케이스 사이에 값을 물려받기 때문이다. 정리 이벤트(`session-end-cleanup-lib.ps1` 의 `cleanup`)는 그 함수가 stdin 을 받지 않아 싣지 않는다.

## §2 Write-HookSlowEvent — 느린 실행 기록

```powershell
# 왜: 차단 hook 넷은 onFailure: block 이라 timeout 을 넘기면 도구 호출이 통째로 막힌다. 2026-11-03 동시 세션
#   부하에서 guard-bash 가 옛 15초를 넘겨 Bash·PowerShell 이 막혔는데, 평시 소요(1~2초)로는 재현되지 않아
#   timeout 값을 정할 실측이 없었다. 기준을 넘긴 실행을 남겨 다음 처방(timeout 값·pwsh 기동 통합)의 근거로 쓴다.
# 무엇을 재나: 지금 − 현재 프로세스 시작 시각. hook 은 도구 호출마다 새 pwsh 프로세스라 이 값이 pwsh 기동을
#   포함한 hook 소요다(빈 pwsh 기동 379ms 가 guard-bash 평시 884ms 의 43% — hook 안 스톱워치는 그만큼 놓친다).
#   hook-dispatch 묶음 안에서는 앞 스크립트가 쓴 시간도 들어간다 — timeout 이 묶음 단위라 그 값이 맞다.
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

**지연 분해 필드(2026-11-24).** slow 줄의 `rule` 은 `elapsed_ms=<N> startup_ms=<S>` 로 시작하고, 호출자가 넘긴 `-Detail` 을 뒤에 붙인다. `startup_ms` 는 진입 시각 − 프로세스 시작 시각이다 — 진입 시각은 `hook-dispatch.ps1` 첫 줄이 남긴 `$global:KarinaHookT0`, 없으면(단독 실행) 호출 스크립트 첫 줄의 시각(`-EntryAt`)이다. guard-bash 는 `load_ms=`(진입부터 검사 루프 직전까지 — 라이브러리 dot-source·입력 파싱)와 `checks=<이름:ms,…>`(10ms 이상인 검사만)를, 디스패처는 `scripts=<스크립트:ms,…>` 를 붙인다. slow 줄만 `rule` 을 400자로 자른다(다른 판정은 120자) — 검사별 목록이 120자를 넘는다. 왜: 14일 동안 5초 초과가 4,632건(p50 7초)인데 한가할 때 묶음은 1.3초라, 부하 때 늘어나는 몫이 기동인지 로드인지 검사인지를 갈라야 처방(상주 프로세스·컴파일 실행 파일·무거운 검사 건너뛰기)을 고를 수 있다. 기준 밑이면 쓰지 않으므로 평시 비용은 스톱워치뿐이다.

## §3 Get-HookRepeatNotice — 같은 세션 반복 차단 안내

**같은 세션에서 같은 hook 이 세 번째 막히면 차단 메시지 끝에 「이 세션에서 <hook> 차단 <N>회째 — 같은 수단(다른 셸·스크립트 우회 포함)으로 다시 시도하지 말고 …」 한 줄을 더한다(2026-11-24).** 왜: 한 세션에서 `guard-comment` 가 73번, `block-python-newcode` 가 42번 막혔다 — 차단 메시지가 이미 「같은 명령을 다시 내도 통과하지 않는다」 를 싣는데도 모델이 python·셸 우회로 같은 쓰기를 되풀이했다. 몇 번째인지를 보여 같은 수단을 버리게 한다.

- **세는 법**: 그 달 이벤트 파일을 `ReadAllText` 로 읽어 `"session_id":"<sid>"` 가 든 줄 중 `"hook":"<hook>"`·`"decision":"block"` 을 함께 담은 줄을 센다(`sid` 정리는 `Write-HookEvent` 와 같다). 카운터 파일을 두지 않는다 — 정리할 상태가 생기지 않고, 차단 경로에서만 읽어 통과 경로 비용이 0이다(3.1MB 에 156ms · `Select-String` 은 391ms). 달이 바뀌면 0 부터 센다.
- **자리**: 이벤트 기록 전에 부르고 stderr 마지막 줄로 낸다 — `Write-DispatchEvent` 가 stderr 첫 줄을 `rule` 로 남겨, 안내를 앞에 두면 로그 집계 키가 바뀐다. `guard-comment`·`guard-doc-owner` 는 판정 함수 안에서 이벤트를 먼저 쓰므로 `guard-harness` 가 `-IncludesCurrent` 로 지금 줄을 뺀다. guard-bash 는 막은 검사 이름(`block-plan-write` 등)으로 센다.
- **판정 불변**: 차단 여부·exit 2 를 바꾸지 않는 메시지 추가다. 실패는 빈 값으로 삼킨다(§1 안전 계약 ①). session_id 가 없으면 세지 않는다.
