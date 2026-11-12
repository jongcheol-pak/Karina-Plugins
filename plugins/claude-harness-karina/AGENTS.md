# AGENTS.md — Agent Guide

> karina 하니스 플러그인 — 모노레포 jongcheol-pak/Karina-Plugins 의 plugins/claude-harness-karina/ 가 **하니스 루트**다(세션도 이 폴더에서 연다 — 레포 루트에서 열면 하니스 판정 hook 이 꺼진다). 아래 **워킹트리 정적 검증**이 `karina:implement` 의 빌드·테스트 단계다.

## 위키

- **프로젝트 페이지**: 20_projects/personal/claude-harness-karina.md (LLM WIKI vault)
- 프로젝트 성격·기술 스택·구조 개요·기능 목록은 **위키가 정본**이다.
- 작업 함정: 레포 `docs/conventions.md` (규약 `skills/REPO-CONVENTIONS.md`)

## Build & Test

모든 명령은 **하니스 루트(plugins/claude-harness-karina/)에서** 실행한다 — 무엇을 대조하는지·함정·기준선은 `docs/harness-conventions.md` 「검증 명령 상세」.

- **Build (전 ps1 구문 검사)**:
  ```
  pwsh -NoProfile -Command '$f=0; Get-ChildItem -Recurse -Filter *.ps1 | ForEach-Object { $e=$null; $null=[System.Management.Automation.Language.Parser]::ParseFile($_.FullName,[ref]$null,[ref]$e); if($e.Count){$f++; Write-Host ("PARSE FAIL " + $_.Name + ": " + $e.Count)} }; if($f){exit 1}; "parse OK"'
  ```
- **Test (JSON 매니페스트 유효성)**:
  ```
  pwsh -NoProfile -Command '@(".claude-plugin/plugin.json","hooks/hooks.json","../../.claude-plugin/marketplace.json") | ForEach-Object { $c = Get-Content -LiteralPath $_ -Raw -ErrorAction Stop; $null = $c | ConvertFrom-Json; Write-Host ($_ + " OK") }'
  ```
- **Plan check**: `python evals/check-harness-consistency.py --plan` — 계획 단계 검사(`karina:plan` Step 6 의 `check-plan` 이 승인 전에 돌린다)
- **Comment (보존)**: `.` · 경로: `skills/plan/scripts/check-plan.ps1 evals/check-harness-consistency.py evals/run-evals.py skills/llm-wiki/evals/check_consistency.py skills/chain-plan/scripts/run-verify.py skills/chain-plan/scripts/wait-worker.py skills/record-project-fact/scripts/relocate-agents.py skills/temp-cleanup/scripts/temp_cleanup.py skills/worktree-cleanup/scripts/worktree_cleanup.py`
- **조건부 검증**: 변경 파일 패턴별 명령(합집합)과 `[면제 ⑤]` 대상은 `docs/verification-mapping.md` 「검증 매핑 (task 검증 선택)」 — 「줄바꿈 정합」 축은 모든 task. 골든 부분 실행 규칙은 `docs/harness-conventions.md` 「골든 부분 실행의 판정 자격」 절만 읽는다(`sed -n '/^## 골든 부분 실행의 판정 자격/,/^## /p' docs/harness-conventions.md`).
- **통합 검증**: `pwsh ./validate.ps1` — ⚠ **설치 캐시**를 보므로 재설치 후에만 반영된다.
- **Gate 필수 경로**: `scripts/**` · `hooks/**` — 차단 hook·그 규칙·골든은 크기와 관계없이 push 전 검증자를 거친다(`skills/implement/references/local-gate.md`「경량 면제」).
- **Release**: 버전 정본은 `plugin.json`(`README.md` 상단 `**버전**:` 은 파생) · 회차 끝 버전 커밋 → 로컬 게이트 → push → 발행 · 발행 여부는 마지막 `karina-v<버전>` 태그 이후 런타임 폴더(`.claude-plugin agents evals hooks scripts skills`) 변경으로 판정 · **릴리즈 발행은 별도 승인** · ⚠ 태그는 원격에만 생겨 확인은 `gh release list`. 정본은 `docs/harness-conventions.md` 「Release (배포·릴리즈 발행)」.
- **⚠ 검증 배치에 `Remove-Item` 인라인 금지** — 도구 경로 보호가 오차단한다(회피법은 정본).

## 데이터 접근

- 없음 (DB·외부 스토어를 쓰지 않는다).

## 산출물·파일 관리

- 캐시 __pycache__/·`.state` 는 커밋 금지.
- 설치본: `~/.claude/plugins/cache/karina-plugins/` (`validate.ps1` 이 검사하는 대상) — **규약 조회는 레포의 하니스 루트를 읽는다**(설치본은 낡는다)

## Conventions

- **아키텍처**: 계층 없음 — 실행 단위가 hook 스크립트와 Markdown 지침이라 도메인/UI/인프라로 가를 대상이 없다(글로벌 「단순 스크립트·유틸리티는 대상이 아니다」).
- **인코딩**: `.ps1` 은 **UTF-8 BOM 필수**(PS 5.1 한글 호환), 그 외는 **BOM 없음**.
- **줄바꿈**: 워킹트리 **CRLF**·`core.autocrlf=true`. `Edit` 도구는 CRLF·BOM 을 지킨다. ⚠ **`Write` 도구·`sed -i` 는 파일 전체를 LF 로 바꿔 놓고, python 텍스트 쓰기(`open(p,'w')`)는 실행 플랫폼 줄바꿈으로 쓴다(텍스트 모드로 읽은 내용을 `newline=''`·`'\n'` 으로 쓰거나 LF 플랫폼 python 이면 전면 LF)** — 편집 후 `git ls-files --eol` 로 확인(정본은 `docs/harness-conventions.md` 의 「편집 스크립트 사고」).
- **주석**: 언어는 그 파일의 기존 주석을 따른다(이 레포는 한글) · 무엇을 남기는가는 `skills/implement/references/code-style.md` 「주석」, 근거를 어디로 내리는가는 `skills/BUDGET.md` 「처방 ④의 단서 셋」. **보존 대상**(지우지 않는다): 문서가 정본으로 지정한 스크립트의 모듈 docstring·머리 주석·함수 주석·상수 주석(찾기: `git grep -n -E '모듈 docstring|머리 주석|주석이 정본|상수 주석'`)과 `scripts/*.ps1`·`skills/*/scripts/*` 의 rationale 포인터 주석 — `comment-reviewer` 가 이 줄을 판정 기준으로 읽는다.
- **명령 출력 예산**: 판정용 명령은 **최소 형식**으로 낸다(정본은 `docs/harness-conventions.md` 「명령 출력 예산」).
- **파일 크기**: 상한 표·초과 처방은 `skills/BUDGET.md`「예산 표」, 참조 깊이·목차 규칙은 `skills/BUDGET.md`「나눈 뒤에 지킬 것」이 정본. **처방은 묻지 않고 적용하고, 상한을 올리는 것은 처방이 아니다.**
- **병행 세션의 커밋은 `git commit -- <경로…>` 다** — 순서는 `git commit -m "$(cat <<'MSG' … MSG)" -- <경로…>`(`-m` 을 `--` 뒤에 두면 경로로 읽혀 실패), 명령에 `2>&1`. 근거·주의는 `docs/harness-conventions.md` 「병행 세션의 커밋」.
- **hook 출력 규약**: 경고는 `exit 0` 비차단 + stderr + additionalContext, **차단은 `exit 2` 하나**(hook 넷) · 우회 변수 둘 · `guard-write` 게이트 2종의 정규식 공유 — hook 수정 전 `docs/harness-conventions.md` 「자격증명 취급」·「`guard-write`의 PLAN-EXEMPT 면제 경로」와 `scripts/rules/write-gate-rationale.md` 를 읽는다.
- **⚠ `llm-wiki` 의 절차 이름·번호·쓰기 범위를 바꾸면 글로벌 `~/.claude/CLAUDE.md` 의 vault 예외를 함께 확인**한다(검사기 밖 — 정본 `docs/harness-conventions.md` 「llm-wiki ↔ 글로벌 지침 결합」).
- **SKILL 문서**: 형식은 `skills/AUTHORING.md`, **설계 원칙은 `skills/DESIGN.md` 가 정본**이다.
- **위키 연동**: `skills/WIKI.md` 가 정본.
- **README.md 갱신 규약**: changelog 기재 **금지**(현재 기능 설명만) · 버전 표기는 상단 1곳. 정본은 `docs/harness-conventions.md` 「README.md 갱신 규약」.
- **규약 개정**: hook·스킬·규약 수정 전 `docs/harness-conventions.md` 「개정·개선 전 영향 검토 (3축)」·「규약 개정 요청의 취급」을 따른다.

## DO NOT

- **실제 자격증명을 코드·문서·notes·plan 에 기록** — 환경변수 이름만 적고 값은 `.env` 에 둔다. 종류는 `docs/harness-conventions.md` 「자격증명 취급」.
- **`exit 2` 를 내는 넷의 차단 동작 변경** — `block-destructive.ps1`·`guard-harness.ps1`·`guard-bash.ps1`(**dot-source 하는 `git-commit-match`·`guard-commit-secrets`·`guard-stale-docs`·`guard-commit-comments` 의 커밋 판정과 `python-newcode` 의 판정 포함**)·`guard-write.ps1`. 안전 임계 hook(끌 수 없는 마지막 방어선)이고 차단 대상은 `scripts/rules/` 가 정본이다. **넷 전부에 오탐 수정·미탐 보완·사용자 지시의 범위 축소·사용자 지시의 이름 교체·사용자 지시의 비안전 차단 신설만 허용되며 골든 실증이 붙는다**(`docs/harness-conventions.md` 「안전 임계 hook 의 차단 동작 변경」).
- **검증·테스트 스크립트에 평문 자격증명·창 숨김·과도한 실행정책 완화**(사유는 같은 절).

## Plan Location

- **plan은 루트 `plan.md` 하나**다(덮어쓰기).
- **`plan.md` 는 `.gitignore`** — **영구 기록은 git 커밋**이고 미처리 Deferred 는 **대장 2파일**이 담는다(`docs/plans/deferred.md` 대기 · `deferred-closed.md` 종결 — 둘 다 `docs/plans/` · 연산 규칙은 그 머리말이 정본).
- **PRD는 쓰지 않는다** — 요구는 `plan.md`, 결정은 `docs/decisions.md`, 미착수는 대장이 담는다.

## OS/플랫폼

- Windows 검증 · macOS/Linux 실험적(hooks 는 pwsh 7 cross-platform 의도).
- **Claude Code**: **v2.1.312 이상만 지원한다** — 그 아래 판은 고려하지 않는다. <!-- verified: 2026-10-30 -->
