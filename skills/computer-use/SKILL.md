---
name: karina-computer-use
description: >-
  Drives the GUI of a visible local Windows app window through `karina-cli computer`:
  accessibility tree, clicks, typing, menus, dialogs, and screenshots in native apps
  and external browser windows (Chrome, Edge) or webviews. Prefer a programmatic path
  (shell, filesystem, git, HTTP, existing CLIs) whenever it can complete the task.
  Use only when a visible window needs GUI control those cannot reach. Do not use
  for Karina's browser tabs (`karina-browser-use`).
version: 1.3.3
---

# Computer Use (Windows)

This file is a discovery stub, not the usage guide. The full, version-matched computer-use
reference is served by the `karina-cli` binary itself — kept out of this file on purpose so it
can never drift from the binary that will actually run your commands.

Engage Karina's computer-use surface to drive a visible app window — reading its accessibility
tree, taking screenshots, or performing safe UI actions (click controls, type, press keys,
scroll, drag, set values). Prefer a programmatic path (shell, filesystem, git, HTTP, existing
CLIs) whenever it can complete the task; use this surface only when a visible window needs GUI
control those cannot reach. Do not use it for Karina's browser tabs (`karina-browser-use`).

This provider is **Windows-only**. It talks to UI Automation and Win32 directly — there is
no sidecar process and no PowerShell dependency.

## Resolve the CLI for this session

Choose the executable once and reuse it for every later command:

- If the `KARINA_CLI_COMMAND` environment variable is set, use its value.
- Otherwise, use the one already on `PATH`: `karina-cli` for the release build,
  `karina-dev-cli` for the dev build (Settings → AI 기능 → **Karina CLI** puts
  whichever build you are running there, and each name reaches its own app).
- Otherwise, use the full path of the installed binary.

**It is the CLI binary, not the app binary.** Karina ships two executables that are built
together: the app opens the workspace window and has no console, so it does not answer
these commands; the CLI (`karina-cli.exe`, or `karina-dev-cli.exe` in a dev build) is the
one that reads them and writes JSON to stdout.

Below, `KARINA` is a placeholder for the executable you resolved. Substitute it before
running anything; do not create a shell variable or run `KARINA` literally. This works the
same way in PowerShell, cmd.exe, and POSIX shells.

If the selected executable cannot run, report its exact error and stop. Do not fall through
to another executable, which could silently target a different Karina build.

## Load the full guide before running Karina commands

```text
KARINA skills get karina-computer-use
```

That prints the complete, version-matched guide for the exact binary that will handle your
next commands — listing apps/windows, reading UI, and driving clicks, typing, and other
accessibility actions. Read it first, then run the specific command you need.

Don't guess subcommands or flags from memory or from a cached copy of this stub. They may
change between Karina releases, and this file deliberately does not list them. Prefer
`--json` for agent-driven calls; **every response is JSON, including errors**.

**Drain stdout while the command runs — never wait for exit and read afterwards.** This
very command prints about 14 KB, more than a pipe's default buffer holds, so a caller that
blocks on process exit before reading will deadlock: the CLI is blocked on a write nobody
is reading, and neither side moves. Use a call that reads and waits together
(`subprocess.run(..., capture_output=True)`, `Command::output()`, `execFile`), not `wait()`
followed by `read()`. This applies to every Karina command, not just this one.

## Orientation commands

These three are stable and safe to run before you have read the guide:

```text
KARINA computer capabilities --json
KARINA computer list-apps --json
KARINA computer list-windows --app <name> --json
```

Beyond these, read the guide rather than guessing a command surface.

## Why the name starts with `karina-`

`~/.agents/skills/` is a shared directory that several tools install into, so a skill whose
name collides with another tool's gets overwritten by whichever was installed last. That is
why this skill is named `karina-computer-use` and drives `karina-cli computer ...`.
