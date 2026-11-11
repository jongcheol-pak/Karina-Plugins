# 페이지 템플릿 모음 (llm-wiki)

> `references/procedures-content.md` A-2/E/I에서 참조. 새 페이지 생성 시 해당 타입 템플릿을 복사해 채운다.
> 규칙·예산의 정본은 형제 문서 `wiki-schema.md`다 — 값이 갈리면 그쪽이 이긴다(`SKILL.md` §0-3 에 따라 해당 § 만 부분 Read 한다).

## 목차
- [source-stub](#source-stub)
- [project (허브)](#project-허브)
- [feature](#feature)
- [entity](#entity)
- [concept](#concept)
- [guide](#guide)
- [question](#question)

## source-stub
```markdown
---
type: source-stub
project: 프로젝트명
category: personal | work
repo_path: "전체 경로"
tags: [source, 프로젝트태그]
---

# 소스: 프로젝트명

- **기술 스택**: 프레임워크/라이브러리 이름만 나열 (SDK/패키지 major.minor 버전 숫자 제외 — 스텁은 불변이라 버전이 영구 stale, 버전 진실원천은 코드/csproj. `.NET 10`·`WinUI 3` 같은 제품 라인 major 식별자는 허용)
- **서브프로젝트**: (있으면) 목록
```

## project (허브)
```markdown
---
type: project
index_label: "인덱스 표시 라벨 (index label)"   # 선택 — 인덱스 카탈로그 표기(한/영 병기), schema §3
project: 프로젝트명
category: personal | work
tech_stack: ["기술1", "기술2"]
platform: windows-desktop | web | mobile | cli | cross
status: active
origin: agent-synthesized | human-validated
confidence: high | medium | low
updated: YYYY-MM-DD
synced_commit: <레포 커밋 sha — 선택. 다음 ingest 의 델타 책갈피. 등록(A)·ingest(B) 시 HEAD로 기록. 미설정도 유효. git 아닌 레포면 줄째로 생략 — §2.2>
repo_url: "<remote origin URL — 선택. 프로젝트 식별의 1차 앵커. `git remote get-url origin` 출력 그대로. 등록(A-2 2)·ingest 결측 백필(B-2 0-2) 시 기록. 미설정도 유효. git 아니거나 remote 없으면 줄째로 생략 — §2.2>"
tags: [project, 카테고리, 프로젝트태그]
---

# 프로젝트명

한 줄 요약.

## 구현정보
- **언어**: {개발 언어}
- **프레임워크·주요 라이브러리**: {이름}
- **실행 환경**: {플랫폼·배포 형태}
- **구조 개요**: {구성 요소와 그 관계 — 몇 줄}

## 레포 정보
- **경로**: `전체 경로`
- **정본 문서**: 존재하는 문서 파일 목록
- **소스**: [[10_sources/{카테고리}/src-{태그}|소스 스텁]]

## 서브프로젝트
| 모듈 | 기술 | 역할 |
|------|------|------|

## 기능 목록
| 기능 | 한 줄 설명 | 상세 |
|------|-----------|------|
| 기능명 | 설명 | [[20_projects/{카테고리}/{프로젝트}/feat-{기능}\|상세]] |

## 관련 위키 지식
- [[30_knowledge/tech/해당기술|표시이름]] — 간단 설명

## 프로젝트 간 공유 패턴
- **패턴명**: 어떤 프로젝트와 어떻게 공유하는지

<!-- 작업 규약·함정은 이 허브가 아니라 레포 docs/conventions.md 에 둔다(schema-types §2.2 「기록 대상 경계」). -->

## 최근 주요 변경
<!-- 3~5개 유지. 초과분은 압축하지 않고 가장 오래된 것부터
     90_archive/20_projects/{카테고리}/{프로젝트}/changes.md 로 롤오버(append) 후
     아래 "## 아카이브" 포인터 1줄을 갱신한다(§2.2·§8 — 포인터 정합은 lint §7-30ⓐ).
     설계·동작이 바뀐 것만 — 버전 bump·카운트 현행화·changelog 나열은 등재 금지(§5). -->
- [YYYY-MM-DD] 변경 내용 한 줄

## 아카이브
<!-- 롤오버가 한 번이라도 있었을 때만 둔다(없으면 이 섹션 자체를 생략). -->
- 이전 이력: 90_archive/20_projects/{카테고리}/{프로젝트}/changes.md (YYYY-MM-DD~YYYY-MM-DD, N건)
```

## feature
```markdown
---
type: feature
index_label: "인덱스 표시 라벨 (index label)"   # 선택 — 인덱스 카탈로그 표기(한/영 병기), schema §3
project: 프로젝트명
category: personal | work
feature_name: "기능명"
platform: windows-desktop | web | mobile | cli | cross
status: active   # 코드에서 제거 시 deprecated: YYYY-MM-DD 추가 (폐기 보존, schema-types §2.3)
origin: agent-synthesized | human-validated
confidence: high | medium | low
updated: YYYY-MM-DD
tags: [feature, 기능태그, 프로젝트태그]
---

# 기능명

> 기능 개요만 담는다 — 코드가 답하는 「어떻게」(사용법·구현 흐름·화면 구성)·파일 경로·코드 식별자·출처 각주·작업 함정은 쓰지 않는다(schema-types §2.3 · 폐지 절은 lint §7-38). 함정은 레포 `docs/conventions.md`, 기각한 대안은 레포 `docs/decisions.md` 몫이다.

## 개요
- {기능이 무엇이고 왜 있는가 — 한 줄씩, 몇 줄}
- {오독을 막는 성립 조건·적용 범위가 있으면 한 줄}
- 관련: [[30_knowledge/tech/기술|표시이름]]
<!-- 섹션이 길어지면 `### ` 소제목으로 구역화한다(§2.3·§7-32) — 6,000자를 초과하면서 소제목이
     하나도 없으면 lint이 INFO로 알린다. 처방은 분리가 아니라 **소제목 추가**다. -->
```

## entity
```markdown
---
type: entity
index_label: "인덱스 표시 라벨 (index label)"   # 선택 — 인덱스 카탈로그 표기(한/영 병기), schema §3
entity_name: "기술명"
origin: agent-synthesized | human-validated
confidence: high | medium | low
updated: YYYY-MM-DD
used_by: [프로젝트1, 프로젝트2]
tags: [entity, 기술태그]
---

# 기술명

## 핵심
- 요약/특징

## 사용 프로젝트
| 프로젝트 | 특이점 |
|----------|--------|

## 공유 패턴 메모
- ...
```

## concept
```markdown
---
type: concept
index_label: "인덱스 표시 라벨 (index label)"   # 선택 — 인덱스 카탈로그 표기(한/영 병기), schema §3
concept_name: "패턴명"
origin: agent-synthesized | human-validated
confidence: high | medium | low
updated: YYYY-MM-DD
related_projects: [프로젝트1, 프로젝트2]
tags: [concept, 패턴태그]
# budget_split: none            # (선택) 나눌 하위 주제가 없을 때만 — wiki-schema §3 · schema-budget §4
# budget_split_chars: 0         #   lint 예산 판정과 같은 기준의 문자 수(=임박 메시지의 {현재} 값,
#                               #   ui-ux·platform-bootstrap guide는 펜스 제외). 부착 후 재측정해 수렴
# budget_split_reason: ""       #   왜 나눌 수 없는가 ("작아서"는 사유가 아니다)
---

# 패턴명

## 개요
패턴이 무엇이고 왜 쓰는지.

## 적용 방법
핵심 기법·주의점.

## 프로젝트 사례
- [[20_projects/.../프로젝트|이름]] — 어떻게 적용했는지
```

## guide
```markdown
---
type: guide
index_label: "인덱스 표시 라벨 (index label)"   # 선택 — 인덱스 카탈로그 표기(한/영 병기), schema §3
guide_kind: platform-bootstrap | ui-ux | recipe
platform: windows-desktop | web | mobile | cli | cross
origin: agent-synthesized | human-validated
confidence: high | medium | low
updated: YYYY-MM-DD
related_projects: [프로젝트1]
tags: [guide, recipe, 플랫폼태그]
# budget_split: none            # (선택) 단일 레시피처럼 나눌 하위가 없을 때만 — wiki-schema §3 · schema-budget §4
# budget_split_chars: 0         #   lint 예산 판정과 같은 기준의 문자 수(=임박 메시지의 {현재} 값,
#                               #   ui-ux·platform-bootstrap guide는 펜스 제외). 부착 후 재측정해 수렴
# budget_split_reason: ""       #   왜 나눌 수 없는가 ("작아서"는 사유가 아니다)
---

# 제목

(platform-bootstrap) ## 대상 플랫폼 / ## 기본 프로젝트 생성 / ## 권장 구조 / ## 필수 의존성 / ## UI/UX 기본 / ## 체크리스트
(ui-ux) UI/UX 규칙 섹션들
(recipe) ## 목적 / ## 적용 플랫폼 / ## 단계 / ## 코드 스니펫 / ## 사용 프로젝트 사례 / ## 주의점 / 함정(선택 — 함정형 recipe 권장, schema-types §2.6)
```

## question
```markdown
---
type: question
index_label: "인덱스 표시 라벨 (index label)"   # 선택 — 인덱스 카탈로그 표기(한/영 병기), schema §3
status: open | investigating | resolved
related_pages: ["[[경로|이름]]"]
updated: YYYY-MM-DD
tags: [question, 관련태그]
---

# 질문/모순 요약

- **상황**: 무엇이 충돌/미해결인가
- **관련 페이지**: [[...]]
- **현재 판단**: (잠정)
```
