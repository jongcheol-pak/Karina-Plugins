---
name: karina-workspace
description: >-
  Operate Karina-managed repos, worktrees, and terminals on Windows through the
  `karina-cli` repo, worktree, and terminal commands: list and register repos,
  create, inspect, update, and remove worktrees, start a coding agent in a new
  worktree, and list, read, wait on, send to, create, split, rename, focus, or
  close Karina terminals. Use for full handoffs ("hand off", "handover", "give
  this to another agent", "another worktree", "spawn claude/codex in a
  worktree"), for reading or waiting on another agent's terminal, for keeping a
  worktree's status comment current, and for searching what agents said in
  earlier sessions. Prefer it over raw git worktree or ad hoc terminals when
  Karina state is involved. Use karina-orchestration for supervised multi-agent
  coordination, karina-browser-use for Karina's browser tabs, and
  karina-computer-use only when a visible window needs GUI control.
version: 1.0.2
---

# Karina Workspace (Windows)

This file is a discovery stub, not the usage guide. The full, version-matched reference is
served by the `karina-cli` binary itself — kept out of this file on purpose so it can never
drift from the binary that will actually run your commands.

Engage it whenever **Karina's repos, worktrees, or terminals** matter: registering a repo,
creating or removing a worktree, starting a coding agent in a new worktree, handing work off
to another agent, reading, waiting on, or sending to another terminal, keeping a worktree's
status comment current, and searching what agents said in earlier sessions.

Use plain shell tools when Karina state does not matter. This provider is **Windows-only**.

## This surface talks to the running app

The repo, worktree, and terminal commands are RPC calls to the Karina app over a named pipe.
**The app must be running.** If it is not, every command answers with a JSON error saying so;
the CLI will not launch the app for you.

## Resolve the CLI for this session

Choose the executable once and reuse it for every later command:

- If the `KARINA_CLI_COMMAND` environment variable is set, use its value. Terminals that
  Karina opens already set it.
- Otherwise, use the one already on `PATH`: `karina-cli` for the release build,
  `karina-dev-cli` for the dev build (Settings → AI 기능 → **Karina CLI** puts whichever
  build you are running there, and each name reaches its own app).
- Otherwise, use the full path of the installed binary.

**It is the CLI binary, not the app binary.** The app has no console and does not answer
these commands; the CLI writes JSON to stdout.

Below, `KARINA` is a placeholder for the executable you resolved. Substitute it before
running anything; do not create a shell variable or run `KARINA` literally.

If the selected executable cannot run, report its exact error and stop. Do not fall through
to another executable, which could silently target a different Karina build.

## Load the full guide before running Karina commands

```text
KARINA skills get karina-workspace
```

That prints the complete, version-matched guide for the exact binary that will handle your
next commands — every command and flag, the handoff rules, the result fields, and the error
codes. Read it first, then run the specific command you need.

Don't guess subcommands or flags from memory or from a cached copy of this stub. Prefer
`--json` for agent-driven calls; **every response is JSON, including errors**.

**Drain stdout while the command runs — never wait for exit and read afterwards.** The guide
is larger than a pipe's default buffer, so a caller that blocks on process exit before
reading will deadlock. Use a call that reads and waits together
(`subprocess.run(..., capture_output=True)`, `Command::output()`, `execFile`).

## Orientation commands

These three are read-only and safe to run before you have read the guide:

```text
KARINA repo list --json
KARINA worktree current --json
KARINA terminal list --json
```

## Why the name starts with `karina-`

`~/.agents/skills/` is a shared directory that several tools install into, so a skill whose
name collides with another tool's gets overwritten by whichever was installed last. That is
why this skill is named `karina-workspace` and drives `karina-cli repo|worktree|terminal ...`.
