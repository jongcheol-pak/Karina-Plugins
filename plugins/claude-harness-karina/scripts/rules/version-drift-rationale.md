# `warn-version-drift` 판정 근거

> `warn-version-drift.ps1`의 주석에서 옮긴 판정 근거다. 스크립트에는 각 자리에 이 문서의 절을 가리키는 1줄만 남겼다.
> **문면을 요약하지 않고 이동만 했다** — 이관은 이동이지 요약이 아니다.
> (v1.225.0 T5 에서 이관 스크립트를 두 번 돌려 이 파일이 비었던 것을 회차 시작 커밋 `6bf0fe1` 의 원문으로 복원했다.)

## §1 warn-version-drift.ps1 — SessionStart: 설치본 ↔ 하네스 레포 버전 드리프트 경고 (비차단)

```
# warn-version-drift.ps1 — SessionStart: 설치본 ↔ 하네스 레포 버전 드리프트 경고 (비차단)
#
# 왜: 하네스 레포에서 plugin.json 버전을 올려도 재설치 전까지 설치 캐시는 구버전으로 동작한다.
#   이 드리프트를 사람이 notes.md로 수동 추적하던 것을(v1.101.0~1.104.0 반복 pain point),
#   세션 시작 시점에 기계가 1줄 경고로 알린다 — "레포에는 고쳤는데 세션은 구 동작" 혼동 제거.
# 어떻게: stdin(SessionStart JSON)의 cwd가 하네스 레포일 때만(cwd 에서 위로 올라가며 하니스 루트를 찾는다 —
#   이름 karina 매니페스트 + 하니스 규약 문서, `harness-root.ps1` · 임의 레포 오탐 방지), 레포 plugin.json 버전과 자기 설치본 버전($env:CLAUDE_PLUGIN_ROOT의
#   plugin.json — 다중 버전 캐시·레거시 레이아웃과 무관하게 자기 자신이 곧 활성 설치본)을 비교한다.
# 안전: 경고 hook이므로 모든 실패 경로는 조용히 exit 0 (fail-open — 세션 시작을 절대 막지 않는다).
#   네트워크를 쓰지 않는다 — origin/main 은 마지막 fetch 의 로컬 ref 다.
#   stdout은 SessionStart 규약상 세션 컨텍스트로 주입된다(exit 0).
```

## §2 미배포 감지 — 설치 커밋 뒤 origin/main 의 런타임 폴더 커밋

**`[karina 미배포]` 는 설치 기록의 설치 커밋 뒤 origin/main 에 하니스 런타임 폴더(`.claude-plugin agents evals hooks scripts skills`) 커밋이 있을 때 낸다**(2026-11-14 — 체인 run_2dae0222 plan 4, 코디네이터 판정 「설치 커밋 기준」). 설치 기록은 `~/.claude/plugins/installed_plugins.json` 의 `plugins."karina@karina-plugins"` 항목이고, 그 `gitCommitSha`·`version` 을 쓴다. 문구는 둘로 갈린다 — origin/main `plugin.json` 버전이 설치 기록 버전과 같으면 「버전을 올리지 않은 채」(버전 커밋을 둬야 설치본에 간다), 다르면 「`/plugin update` 로 반영」.

- **왜 설치 커밋인가** — 이 경고가 생긴 실해는 「플러그인을 고쳤는데 버전을 올리지 않은 채 push 된 변경」 이다(2026-09-19 — 위키·docs 만 고친 회차가 이어져 앞 회차의 런타임 변경이 미배포로 남았다). 옛 판정은 그 기준점을 릴리즈 태그 커밋으로 잡았는데, 릴리즈 발행을 없애(혼자 쓰는 하니스 — 사용자 답 「버전 커밋만 유지」) 태그가 더 생기지 않는다. 버전 비교만으로는 버전이 같을 때 이 경우를 놓치고, 마지막 `plugin.json` 변경 커밋을 기준으로 삼으면 버전 커밋 뒤에 붙는 완료 리뷰 수정 커밋을 다음 버전까지 매 세션 미배포로 센다. 설치 커밋은 실제로 설치된 내용이라 둘 다 없다.
- **설치 기록 형식에 기댄다** — 그 파일은 Claude Code 가 쓰는 내부 기록이다. 파일·키·`gitCommitSha` 가 없거나, 그 sha 가 로컬 git 에 없거나(fetch 전), origin/main ref 가 없으면 판정을 건너뛴다(fail-open). 형식이 바뀌면 이 경고는 조용히 꺼진다 — 그때는 이 절과 골든 픽스처를 함께 고친다.
- **네트워크를 쓰지 않는다** — 옛 판정은 태그를 `git ls-remote` 로 원격에 물어 세션마다 540~646ms(무응답 원격이면 상한 5초)를 썼다. 지금은 로컬 ref 만 읽는다. 그 대가로 origin/main 은 마지막 fetch 시점 값이다.
- **origin/main 기준이다** — 미push 커밋은 작업 중이라 세지 않는다. 회차 끝의 버전 판정은 `docs/harness-conventions.md` 「판정 시점」 의 명령으로 한다.
- **배치는 설치본 버전 판정보다 앞이다** — 두 검사는 독립인데 뒤에 두면 `CLAUDE_PLUGIN_ROOT` 부재(설치본 없이 레포만 연 세션 등)에서 조기 exit 에 막혀 도달하지 못한다(구현 중 실측). 설치 버전도 `CLAUDE_PLUGIN_ROOT` 가 아니라 설치 기록에서 읽는다.
- **홈은 `USERPROFILE`, 없으면 `HOME`** — 골든이 격리 홈으로 바꿔 넣어 실제 설치 기록을 읽지 않게 한다.
- ⚠ 출력 문구의 변수는 `${pushedVer}`처럼 **중괄호 필수** — 한글 조사가 붙으면(`v$pushedVer가`) PowerShell이 `$pushedVer가`를 변수명으로 해석해 빈 값이 된다(v1.158.0 구현 중 실제로 밟았다).

## §3 `-join` 필수 — git show는 **줄 배열**을 반환한다

```
            # `-join` 필수: git show는 **줄 배열**을 반환하는데, 배열을 그대로 ConvertFrom-Json에
            #   파이프하면 PowerShell 5.1(AGENTS.md가 명시한 폴백 런타임)에서 줄마다 개별 JSON으로
            #   파싱을 시도해 실패한다(7은 누적 처리라 통과 — 런타임에 따라 결과가 갈리는 형태다).
```

## 모노레포 이전 (2.0.0 — 미탐 보완)

하니스가 `jongcheol-pak/Karina-Plugins` 의 `plugins/claude-harness-karina/` 로 옮겨 「git 루트 = 하니스 루트」 가정이 깨졌다. 옛 마커(cwd 아래 옛 플러그인 폴더의 매니페스트 + `<cwd>/.claude-plugin/marketplace.json`)로는 새 배치에서 판정이 조용히 꺼진다 — 그 미탐을 막는다.

- **하니스 루트는 `harness-root.ps1` 이 찾는다** — cwd 에서 git 루트까지 올라가며 「이름이 karina 인 `.claude-plugin/plugin.json` + `docs/harness-conventions.md`」 폴더. 이름만 보면 같은 레포의 다른 플러그인이, 규약 문서만 보면 사용자 프로젝트가 걸린다. marketplace.json 은 git 루트에만 있어 마커에서 뺐다.
- **origin/main 의 버전은 `git rev-parse --show-prefix` 로 얻은 하니스 위치에서 읽는다** — 하니스 루트 = git 루트인 배치에서는 접두가 빈 값이라 같은 코드가 돈다.
- **미배포는 하니스 런타임 폴더(`.claude-plugin agents evals hooks scripts skills`)의 커밋만 센다** — 다른 플러그인 폴더의 커밋과 문서는 세지 않는다. 골든 `scenarios/warn-version-drift.ps1` 의 「모노레포」 케이스가 양성과 음성 짝을 잰다.
