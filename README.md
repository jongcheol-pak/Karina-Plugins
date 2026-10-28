# Karina-Plugins

Claude Code 플러그인 마켓플레이스 `karina-plugins` 와, Karina 앱이 읽는 에이전트 스킬을 함께 담은 레포입니다.

## 플러그인

| 플러그인 | 설명 | 문서 |
|---|---|---|
| `karina` | Claude Code 가 계획을 세우고 검증하며 일하게 하는 코딩 하니스 — 계획·자율 구현·디버깅·PR 운영 스킬, 검토 서브에이전트, 위험 명령을 막는 hook | [plugins/claude-harness-karina/README.md](plugins/claude-harness-karina/README.md) |

### 설치

```powershell
claude plugin marketplace add jongcheol-pak/Karina-Plugins
claude plugin install karina@karina-plugins
claude plugin enable karina@karina-plugins
```

설치한 뒤 Claude Code 를 다시 시작합니다. 업데이트·제거 명령과 사용법은 [하니스 README](plugins/claude-harness-karina/README.md) 에 있습니다.

## Karina 앱 스킬

`skills/` 아래 스킬 4개는 플러그인으로 설치하지 않습니다. Windows 용 Karina 앱이 이 레포의 `skills/<폴더>/SKILL.md` 를 직접 읽어 앱 안의 에이전트에게 줍니다.

| 스킬 | 하는 일 | 문서 |
|---|---|---|
| `karina-browser-use` | Karina 앱 안의 브라우저 탭을 열고, 페이지를 읽고, 요소를 조작한다 | [skills/browser-use/SKILL.md](skills/browser-use/SKILL.md) |
| `karina-computer-use` | Karina 밖의 Windows 앱 창을 접근성 트리·클릭·입력·스크린샷으로 조작한다 | [skills/computer-use/SKILL.md](skills/computer-use/SKILL.md) |
| `karina-orchestration` | 여러 에이전트 터미널 사이의 메시지·작업 의존 관계·워커 배정을 관리한다 | [skills/orchestration/SKILL.md](skills/orchestration/SKILL.md) |
| `karina-workspace` | Karina 가 관리하는 레포·worktree·터미널을 `karina-cli` 로 다룬다 | [skills/workspace/SKILL.md](skills/workspace/SKILL.md) |
