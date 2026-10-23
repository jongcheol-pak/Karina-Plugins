# 검증 래퍼 근거 (`scripts/run-verify.py`)

> 코디네이터는 이 파일을 읽지 않는다 — `continuation.md`「코디네이터 검증」 은 래퍼를 띄우고 `RESULT:` 줄로 판정할 뿐이다. 이 파일은 래퍼를 고칠 때 연다. 출력 갈래와 인자는 `run-verify.py` 모듈 docstring 이 정본이고, 여기는 판정이 왜 그런 모양인지를 담는다.

## 왜 따로 두는가

2026-10-23 Karina 레포 체인 run_34c092d3 plan 6 의 코디네이터 검증이 프로세스 정리 명령과 검증 셋을 시한 없이 한 백그라운드에 묶어 80분 넘게 출력 0바이트로 섰다. 규칙(명령마다 `timeout 40m`)이 있었는데 모델이 지키지 않았다 — 감시를 문면이 아니라 스크립트가 맡으면 코디네이터가 규칙을 어겨도 감시가 빠지지 않는다. 대기 스크립트(`wait-worker.py`)와 하는 일이 달라(워커 화면 대기 ↔ 명령 실행·감시) 모드를 더하지 않고 따로 둔다.

## 진행 판정

- **벽시계로 끊지 않고 진행으로 멈춤을 가른다** — 빌드·테스트는 어떤 시한보다도 오래 걸릴 수 있어, 시한으로 끊으면 정상 작업이 미검증이 된다(사용자 요구 「멈춘 것을 확인해서 다시 실행하는 것」). 외부 선례도 같다 — pstack `poteto-mode/playbooks/multi-phase-plan.md` *"judge progress by side effects only"*.
- **진행 신호는 둘이다 — 출력 파일이 늘었거나, 직전 진행 이후 Job 누적 CPU 가 `--cpu-sec` 이상 늘었다** — run_34c092d3 의 정지는 출력 0바이트 고정 · 자식 없음이었다(karina-ea 관측).
- **CPU 는 「0 초과」 가 아니라 문턱(기본 30초)을 넘어야 진행이다** — 정지 상태 pwsh 도 타이머·GC 로 60초에 234ms 를 썼다(2026-10-23 실측 — 10분 환산 약 2.3초). 「0 초과」 면 그런 정지가 영영 안 잡힌다. 30초/10분(한 코어 5%)은 그 열 배 넘게 위다.
- **창은 고정 구간이 아니라 마지막 진행 시점 기준이다** — 고정 구간이면 멈춘 시점에 따라 감지가 두 배까지 늦어진다. 감지 지연은 최대 `--stall-sec` + `--poll-sec`.
- **누적 CPU 는 Job 회계(`JOBOBJECT_BASIC_ACCOUNTING_INFORMATION`)에서 읽는다** — 살아 있는 자손의 합이 아니라 끝난 자손의 몫까지 담아, 폴링 사이에 떴다 사라지는 컴파일러 프로세스도 진행으로 잡힌다. Windows 밖에서는 이 회계가 없어 출력 증가만 진행으로 본다(하니스는 Windows 검증 · 그 밖 실험적).

## 재실행

- **멈춤에만 1회 다시 돌린다 — `fail`·`unrunnable`·`deadline`·`overtime` 은 다시 돌리지 않는다** — 실제 실패를 다시 돌리면 같은 실패를 한 번 더 기다린다(pstack `references/bugbot-triage.md` *"binary is not installed" is a different situation from "the command ran and failed"*). 무한 루프는 다시 돌려도 같은 루프다.
- **횟수는 1회다** — 멈춤마다 10분 넘게 쓰므로 2회면 체인이 30분 넘게 선다. 같은 멈춤이 두 번이면 일시적 현상이 아니다(pstack `babysit.md` *"One retry only. An identical second failure means it was never flake"*).

## 프로세스 정리

- **자식을 `CREATE_SUSPENDED` 로 띄워 Job 에 넣은 뒤 `NtResumeProcess` 로 재개한다** — 재개 전에는 자손이 생기지 않아 전부 Job 에 든다. `subprocess.Popen` 은 스레드 핸들을 닫고 tid 를 남기지 않아(`Lib/subprocess.py` 의 `_winapi.CloseHandle(ht)`) `ResumeThread` 를 부를 수 없고, `NtResumeProcess` 는 프로세스 핸들 하나로 끝난다.
- **어느 갈래로 끝나든 `TerminateJobObject` 로 Job 을 비운다** — `taskkill /T` 는 부모 사슬로만 자손을 찾아, 중간 부모가 먼저 끝난 고아(테스트 바이너리·debug 앱)를 놓친다. 그 고아가 다음 빌드를 `os error 5` 로 막는다(karina-ea 관측). `pass`·`fail` 뒤에도 메인보다 오래 사는 자손(빌드 서버·테스트 호스트)이 남으므로 정상 종료도 대상이다.
- **Job 에 `JOB_OBJECT_LIMIT_KILL_ON_JOB_CLOSE` 를 건다** — 래퍼가 끊겨도(메모리 부족 때 쉬는 세션의 백그라운드 셸이 끊긴다 — `docs/conventions.md` 의 백그라운드 생존 실측) 핸들이 닫히며 자손이 함께 끝난다.
- **래퍼 자신은 Job 에 넣지 않는다** — 넣으면 래퍼의 폴링 CPU 가 진행으로 섞이고, Job 을 비울 때 래퍼도 끝난다.
- **실행 파일은 `shutil.which` 로 PATH 순서대로 찾는다** — Windows `CreateProcess` 는 PATH 보다 System32 를 먼저 찾아, `bash` 가 Git Bash 가 아니라 WSL 의 `bash.exe` 로 풀릴 수 있다.

## 안전 상한과 사전 단계

- **본체에는 진행과 무관한 안전 상한(`--max-sec`, 기본 3시간)을 둔다** — CPU 를 계속 쓰거나 출력을 계속 내는 무한 루프는 진행 판정으로 정상 빌드와 갈리지 않아, 상한이 없으면 체인이 영영 선다(사용자 답 2026-10-23). 3시간은 정상 빌드·테스트가 넘지 않는 값으로 잡았다.
- **사전 단계(`--deadline-sec`)는 진행 판정 없이 벽시계만 잰다** — 프로세스 정리 같은 준비 명령은 짧게 끝나야 정상이라 진행 여부와 무관하게 시한이 맞다.
- **둘을 함께 주면 인자 오류다** — 사전 단계에 3시간 상한이 겹치면 어느 갈래로 끝났는지가 흐려진다.
- **벽시계 시한이 없는 것은 백그라운드 완료 알림이 긴 실행에도 온다는 실측에 기댄다** — 45분(2,700초)까지는 2026-10-06 에 쟀고(`docs/conventions.md` 의 백그라운드 생존 실측), 3시간에 닿는 실행의 알림은 미측정이다.

## 레포별 잠금

- **`--cwd` 마다 잠금 파일 하나를 쥐고, 같은 레포의 새 래퍼가 덮어쓰면 앞 래퍼는 Job 을 비우고 `superseded` 로 물러난다** — 사용자가 멈춤을 보고 다시 실행하라고 할 때 앞 래퍼는 판정 전(최대 10분)이거나 바쁜 루프(최대 3시간)라 살아 있을 수 있다. 두 실행이 같은 빌드 폴더를 쓰면 잠금 실패가 나고, 앞 실행의 늦은 `RESULT:` 가 새 실행의 결과로 읽힌다. 방식은 `wait-worker.py` 의 `FileLock` 과 같다(사본 두 곳 — 공통화 기준 3회에 닿지 않는다).
- **병렬 그룹은 워크트리가 달라 `--cwd` 가 갈리므로 서로 물러나지 않는다.**

## 출력

- **진행 중 `STEP` 줄을 먼저 찍고 `RESULT:` 는 끝에 한 줄이다 — 「첫 줄」 이 아니라 「`RESULT:` 로 시작하는 줄」 이 판정이다** — 백그라운드 출력 파일을 사용자가 열었을 때 어느 명령의 몇 번째 시도에서 서 있는지가 보여야 한다(karina-ea 요청 ③). `wait-worker.py` 는 진행 줄을 깨움 때만 실어 첫 줄 계약을 지키지만, 이 래퍼는 깨우는 일이 끝날 때 한 번뿐이다.
- **stdout 은 UTF-8 로 다시 열고 로그 꼬리는 `errors='replace'` 로 읽는다** — 백그라운드 python 의 stdout 은 cp949 라 `—` 에서 죽고(`docs/conventions.md` 의 cp949 항목), 명령 출력에는 UTF-8 이 아닌 바이트가 섞인다.
