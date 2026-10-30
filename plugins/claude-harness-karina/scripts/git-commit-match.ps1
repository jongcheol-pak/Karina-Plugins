# git-commit-match.ps1 — git 커밋·add 명령 판정식 (dot-source 전용, hook 아님) — 근거는 `rules/bash-guard-rationale.md` §18
# `guard-bash.ps1`(디스패처)과 커밋 시점 lib 둘(`guard-commit-secrets.ps1`·`guard-stale-docs.ps1`)이 각자 dot-source 한다.
#   lib 는 골든 프로브가 디스패처 없이 단독으로 읽으므로 정의를 디스패처에 둘 수 없다.

# git 전역 옵션 값 — 따옴표로 묶인 공백 경로를 한 토큰으로 받는다.
$script:GitOptValueRx = '(?:"[^"]*"|''[^'']*''|[^\s"'';&|]+)'
# 하위 명령 앞의 전역 옵션 — `-c`/`-C <값>` · 값을 따로 받는 긴 옵션 · 그 밖의 플래그(`--no-pager`·`-P`·`--git-dir=<값>`).
$script:GitGlobalOptsRx = '(?:\s+(?:-[cC]\s+' + $script:GitOptValueRx +
    '|--(?:git-dir|work-tree|namespace|exec-path|config-env|super-prefix)\s+' + $script:GitOptValueRx +
    '|-{1,2}[A-Za-z][\w-]*(?:=' + $script:GitOptValueRx + ')?))*'
# 끝 경계는 `\b` 가 아니라 `(?![\w-])` 다 — `\b` 는 `commit-tree` 의 `-` 앞에서도 성립한다.
$script:GitCommitRx = 'git' + $script:GitGlobalOptsRx + '\s+commit(?![\w-])'
$script:GitAddRx = 'git' + $script:GitGlobalOptsRx + '\s+add(?![\w-])'
