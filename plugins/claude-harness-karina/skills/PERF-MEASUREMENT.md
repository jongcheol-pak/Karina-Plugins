# 성능 측정 규율

> 세 스킬과 완료 리뷰가 가리키는 공용 규율이다 — `karina-systematic-debugging/SKILL.md` 1-B(성능 증상일 때) · `plan/references/plan-template.md`「작업 단계」(성능 task 의 `**성능**` 줄) · `implement/SKILL.md`「검증」(그 줄이 있는 task 의 판정) · 완료 리뷰 `../agents/completion-reviewer.md`(그 줄이 있는 task 의 대조 — 이 문서 끝 절). 성능 수치로 원인을 판정하거나 수정·task 의 효과를 주장하기 전에 이 절을 그대로 거친다.

## 성능 수치의 판정

- **바꾸기 전에 같은 조건으로 기준선을 먼저 잰다** — 기준선 없이 잰 수정 후 수치는 비교할 상대가 없어, 좋아졌는지 원래 그랬는지 갈리지 않는다.
- **각 쪽을 교대로(A·B·A·B) 5회 이상 돌려 중앙값과 범위를 적고, 실행 간 편차보다 작은 차이는 차이로 보지 않는다 — 교대 없이 잰 수치는 판정에 쓰지 않고 다시 잰다** — 한쪽을 몰아 돌리면 예열·지연 초기화·캐시·드리프트가 그쪽에만 유리하게 쌓이고, 1회 차이는 잡음과 갈리지 않는다.
- **수치마다 그것을 막는 병목(CPU·I/O 대기·락·할당·네트워크)을 지목한다 — 지목하지 못하면 판정은 「결론 불가」다** — 병목을 모르는 개선 수치는 무엇이 빨라졌는지 설명하지 못해, 다른 조건에서 재현될지도 말할 수 없다. 프로파일러는 측정을 느리게 하므로 보고하지 않는 별도 실행에서 쓴다. 프로파일 캡처로 병목을 지목할 때는 `karina-systematic-debugging/references/investigation-log.md`「덤프·프로파일·트레이스 판독 (1-A)」 대로 읽는다.
- **양쪽을 운영과 같은 조건(릴리즈 빌드·설정·데이터 크기·캐시 상태·버전)으로 돌린다** — 한쪽만 디버그 빌드거나 데이터가 작으면 그 차이는 수정이 아니라 조건이 만든 것이다.
- **물리 한계 산술을 한다 — 초당 바이트를 디스크·네트워크 대역폭과, 초당 연산×연산 비용을 코어 수와, 절약한 시간을 바뀐 조각이 쓰던 시간과 대조한다** — 10% 조각을 통째로 없애도 전체는 약 11% 빨라질 뿐이고, 한계를 넘는 수치는 캐시·no-op 처럼 작업이 아닌 것을 잰 것이다.
- **측정한 작업이 실제로 일어났는지 확인한다 — 오류·빈 결과·캐시 적중·실행되지 않은 지연 코드를 센다** — 거절·조기 반환은 빠르게 끝나서, 실패한 실행이 「빨라진 실행」으로 보인다.
- **한 변경에 한 측정만 하고, 이기지 못한 변경은 되돌린다** — 여러 변경을 쌓은 뒤 재면 어느 것이 효과였는지 갈리지 않고, 효과 없는 변경이 복잡도만 남긴다.
- **부분 개선은 전체 실행에서 차지하는 비중으로 상한을 잰다** — 마이크로 수치만 보고하면 사용자가 기다리는 전체 경로에서의 효과를 부풀린다.

**병목을 지목하지 못했거나 · 한쪽만 튜닝됐거나(운영 조건 불일치) · 오류·실행 확인을 못 했으면 판정은 「결론 불가」로 적고 무엇이 비었는지를 함께 적는다** — 확인함으로 적으면 그 수치가 다음 결정의 근거로 쓰인다.

## BASE worktree

> 기준선을 작업 트리를 건드리지 않고 재려고 임시 `git worktree add` 를 쓸 때 읽는다(`plan/references/plan-template.md`「작업 단계」 의 측정 방법).

- **자리는 `TEMP-FILES.md` 의 `scratch\base-<레포 폴더명>-<YYYYMMDD-HHmm>` 이다** — `%TEMP%\karina-plugin\` 바로 아래에 두면 세션 시작 정리가 보지 않아, 지우지 못한 사본이 기한 없이 남는다.
- **측정이 끝나면 아래 명령을 Write 로 `.ps1` 파일에 담아 `pwsh -NoProfile -File <파일>` 로 돌리고(삭제 명령을 PowerShell 도구에 인라인으로 넣으면 도구의 경로 보호가 다른 따옴표 경로를 집어 막을 수 있다) 마지막 줄이 `남음: False` 인지 본다 — `True` 면 그 경로를 보고의 남은 이슈에 적는다** — 폴더 안 파일을 연 프로세스가 하나라도 살아 있으면 `git worktree remove --force` 가 `Invalid argument` 로 실패하고 등록만 풀린 채 폴더가 남는다(2026-11-18 실측 — BASE 에디터만 끄고 그 자식 `AssetImportWorker` 를 남겼다). 그래서 명령줄에 폴더 이름이 든 프로세스를 자식까지 빼지 않고 끝내되, 같은 이름을 명령줄에 담은 이 명령의 셸과 그 조상만 뺀다.

```powershell
$repo = '<레포>'; $w = '<worktree 경로>'; $leaf = Split-Path $w -Leaf
$mine = @(); $p = $PID; while ($p -and $p -notin $mine) { $mine += [int]$p; $p = (Get-CimInstance Win32_Process -Filter "ProcessId=$p").ParentProcessId }
Get-CimInstance Win32_Process | Where-Object { $_.CommandLine -like "*$leaf*" -and [int]$_.ProcessId -notin $mine } | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue; Wait-Process -Id $_.ProcessId -Timeout 30 -ErrorAction SilentlyContinue }
git -C $repo worktree remove --force $w
if (Test-Path -LiteralPath $w) { cmd /c rd /s /q "$w" }
git -C $repo worktree prune
"남음: $(Test-Path -LiteralPath $w)"
```

## 측정 빌드 중 편집

> 측정용 빌드(릴리즈 변형 빌드 등)를 백그라운드로 띄운 채 같은 작업 트리에서 편집을 이어 갈 때 읽는다.

- **빌드 대상을 작업 트리가 아니라 `git worktree add <scratch> HEAD` 로 만든 HEAD 스냅숏에 둔다 — 자리와 지우기는 위 「BASE worktree」 절 그대로다(이름만 `snap-…`)** — 빌드는 수 분~수십 분 동안 소스를 읽어, 그 사이 편집한 파일(다음 task 의 스텁 등)이 측정 대상에 섞이거나 컴파일을 깨뜨린다(2026-11-20 Karina plan 11 — release 변형 빌드 A 가 같은 동안 편집한 스텁 때문에 실패해 HEAD worktree 에서 다시 빌드했다 · 재빌드 A 1146초·B 2287초). 측정하려는 판이 커밋돼 있어야 스냅숏이 그 판이 되므로, 띄우기 전에 커밋한다.

## 구현 루프의 결론 불가

> `karina:implement`「검증」 이 `**성능**` 줄이 있는 task 를 잴 때 읽는다.

- **「결론 불가」 가 측정 수단 결함(틀린 측정 스크립트·명령·BASE 준비 절차) 때문이면 수단을 고쳐 다시 잰다 — `implement/references/loop-exceptions.md`「검증 수단 결함」** — 고칠 수 있는 측정을 미검증으로 닫으면 성능 주장이 잰 적 없이 남는다.
- **수단이 멀쩡한데 판정이 「결론 불가」면 다른 검증이 통과했을 때 `[x]` 로 닫되 커밋 본문과 최종 보고 미검증에 `성능 — 결론 불가(미검증)` 를 적고 다음 task 로 간다** — 결론 불가는 실패가 아니라 측정이 빈 것이라 루프를 세울 이유가 없고, 미검증으로 적어야 통과로 읽히지 않는다.

## 완료 리뷰 대조

> `completion-reviewer` 가 `**성능**` 줄이 있는 task 를 볼 때 읽는다. 그 줄이 있는 task 에서만 쓰이는 대조라 리뷰어 정의가 아니라 성능 규율의 정본 곁에 둔다.

- **`**성능**` 줄이 있는 task 는 plan 에 착수 기준값이 있는지, 커밋 본문에 교대 반복 횟수·중앙값·범위와 실패 수치 대비 판정이 있는지 보고, 없으면 지적한다. 「결론 불가」인데 `결론 불가(미검증)` 표기 없이 확인함으로 적혔으면 BLOCKER 다 — 표기가 있는 `[x]` 는 정상이다** — 1회 수치나 결론 불가가 확인함으로 남으면 다음 결정이 그 수치를 근거로 쓴다.
