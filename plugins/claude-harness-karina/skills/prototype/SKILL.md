---
name: prototype
description: 화면(레이아웃·인터랙션·밀도)·동작(타이밍·출력)·전례 없는 아키텍처 결정을 버리는 시안 2~3개로 만들어 보고 증거로 고르게 한다. 고른 방향의 실제 구현·계획은 karina:plan 이다. 사용자 호출 전용.
disable-model-invocation: true
---

# Prototype

**정하는 것은 설계이고 코드가 아니다. 시안은 결정을 내리고 버리는 도구다.** 실제 구현은 고른 방향으로 `karina:plan` 이 맡는다.

> 출처는 Cursor pstack 의 poteto-mode Prototype 플레이북과 원칙 exhaust-the-design-space 다 — 고정 위치 `https://github.com/cursor/plugins/blob/519d36aa98955bf680db01bcde5fdfba686dc901/pstack/skills/poteto-mode/playbooks/prototype.md` 와 같은 커밋의 `pstack/skills/principle-exhaust-the-design-space/SKILL.md`. Copyright (c) 2026 Lauren Tan · MIT(`https://github.com/cursor/plugins/blob/519d36aa98955bf680db01bcde5fdfba686dc901/pstack/LICENSE`).
>
> **원문과 다르게 한 것** — ① 원문의 dev server hot reload 는 들이지 않는다. 패키지를 설치하지 않으려고 `file://` 로 열거나 설치가 필요 없는 `python -m http.server` 로 띄운다 ② 고르는 것은 사용자다. 모델은 권장안만 낸다 ③ 원문의 Feature 플레이북 인계는 `karina:plan` 시작 제안으로 바꿨다 ④ 원문이 구조 설계로 넘기는 `architect` 스킬은 들이지 않았다. 아키텍처 결정은 아래 「시안 만들기」의 스케치로 정한다 ⑤ 원문의 *"Speed over polish … no planning"* 은 그대로다 — 시안 코드의 품질·테스트·추상화는 보지 않는다 ⑥ 임시 폴더 자리는 `../TEMP-FILES.md` 를 따른다.

## 절차

1. **결정 범위를 정한다** — 이 시안으로 무엇을 정하는가: 어떤 레이아웃·인터랙션·밀도인가, 어떤 동작·타이밍·방식인가, 어떤 구조인가. **정할 결정이 없으면 시안을 만들지 않는다** — 만들 것이 정해진 요청이면 `karina:plan` 으로 넘긴다.
2. **방향이 열려 있으면 레퍼런스를 모아 방향을 고르게 한다** — 기존 사례를 찾아 테마·팔레트·레이아웃을 묶어 보이고, 사용자가 방향을 고른 뒤 만든다. 방향이 이미 정해졌으면 건너뛴다.
3. **아래 「시안 만들기」대로 만들고 확인한다.**
4. **아래 「보고」대로 보고한다.**

## 시안 만들기

이 절은 다른 문서(plan 인터뷰·구현 루프)가 그대로 가져다 쓰는 단위라, 사용자에게 묻는 단계를 담지 않는다.

- **운영 소스와 떨어진 임시 폴더에 만든다** — 화면 시안은 `%TEMP%\karina-plugin\plan-variants\<YYYYMMDD-HHmm>\`, 동작·아키텍처 스케치는 `%TEMP%\karina-plugin\scratch\` 다(`../TEMP-FILES.md`). 레포 파일을 쓰지 않는다 — 시안이 운영 코드에 섞이면 버릴 수 없다.
- **결정 종류마다 가장 가벼운 수단을 쓴다**
  - 화면 — vanilla HTML/CSS/JS 로 그 생각을 보이는 만큼만. 라이브러리는 CDN 에서 읽는다.
  - 동작·타이밍 — 그 질문만 돌려 보는 가장 작은 스크립트.
  - 아키텍처 — 전례 없는 구조 결정이면 경쟁안 2~3개를 타입·시그니처·모듈 배치 스케치로 쓴다. 비교 기준은 호출자가 떠안는 복잡도다. 운영 코드는 쓰지 않는다.
- **변형은 2~3개를 만들고, 화면이면 스위처 한 페이지 뒤에 둔다** — 버튼이나 키 입력으로 바꾸고 변형마다 이름표를 단다. 따로 연 파일끼리는 같은 조건으로 견주기 어렵다.
- **결정할 대상을 직접 관측한다** — 화면은 변형마다 인터랙션을 조작하고 스크린샷을 찍는다. 수단은 세션에 있는 브라우저 조작 도구(예: `karina-browser-use`·`claude-in-chrome`), 없으면 headless Edge/Chrome `--screenshot`, 그것도 없으면 HTML 경로를 보이고 사용자가 연다. 동작은 타이밍 로그·출력을 찍어 본다. 이 관측이 시안의 검증이고, assertion 은 쓰지 않는다.
- **패키지 설치·DB·임시 폴더 밖 쓰기를 하지 않는다** — 네트워크는 CDN 읽기만이다. 상태를 바꾸지 않는 읽기라 승인 대상 외부 호출로 보지 않는다.

## 보고

- **변형 · 증거 · 트레이드오프 · 권장안 · 임시 경로를 싣는다** — 증거는 화면이면 스크린샷 경로, 동작이면 관측한 출력·타이밍이다. 경로의 사용자 홈·임시 폴더 앞부분은 `%TEMP%\…` 로 적는다.
- **시안은 버리는 산출물이라고 적는다** — 그대로 운영 코드로 옮길 것이 아니다.
- **고르는 것은 사용자다** — 권장안에 이유 한 구를 붙이되 혼자 확정하지 않는다.
- **끝에 한 줄로 묻는다 — 고른 방향으로 `karina:plan` 을 시작할지.**
- **문장은 `../WRITING.md` 의 한글 문체 규칙을 따른다** — 사용자가 이 보고만 보고 고른다.
