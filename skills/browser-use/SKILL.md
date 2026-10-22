---
name: karina-browser-use
description: >-
  Use Karina's browser CLI to drive the browser tabs inside the Karina app on
  Windows: open, list, switch, create, or close tabs, navigate, go back and
  forward, reload, and wait for a page to load; read the page (an ARIA snapshot,
  a JavaScript expression, an element property, or a yes/no about its state);
  act on elements (click, fill, select, check, hover, type, press a key, and
  similar); and drive the mouse (move, press, release, wheel, drag). Use for
  any request about a page open in Karina's own browser tabs — reading it,
  acting on it, or using the login the user already has there.
  Use karina-computer-use only when a visible window outside Karina needs GUI
  control that a CLI, filesystem, or API cannot do, and use karina-orchestration
  for coordinating work between agent terminals.
version: 1.13.5
---

# Karina Browser Use (Windows)

This file is a discovery stub, not the usage guide. The full, version-matched browser
reference is served by the Karina CLI binary itself — kept out of this file on purpose so it
can never drift from the binary that will actually run your commands.

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
KARINA skills get karina-browser-use
```

Engage Karina's browser surface when the target is a **browser tab inside the Karina app** —
tabs that sit beside the terminal tabs in the same window. Because they are the user's own
tabs, pages opened here keep the logins the user already has in that browser profile.

Use `karina-computer-use` only when a visible window outside Karina — a browser *window*
(Chrome, Edge, Firefox) or another desktop application — needs GUI control that a CLI,
filesystem, or API cannot do, and `karina-orchestration` for coordinating work between agent
terminals.

This provider is **Windows-only**.

## This surface talks to the running app

Like `karina-orchestration` and unlike `karina-computer-use`, these commands do not act alone —
the tabs live inside the Karina app and the CLI reaches it over a named pipe. **The app must
be running and "Agent 브라우저 사용" must be on** (Settings → Browser). If it is not, every
command answers with a JSON error saying so; the CLI will not launch the app for you,
because that would tie the app's lifetime to a single command.

## Two contracts worth knowing before you read the guide

- **Nothing is created implicitly.** With no browser tab open, commands refuse rather than
  opening one for you, so that choosing `tab create` stays your decision.
- **Element references expire.** Reading the page hands you `[ref=eN]` tags; navigating or
  reloading throws the whole set away and a later use of one answers with a dedicated code
  meaning "take a fresh snapshot" — not "the element is gone".

## Orientation commands

These are stable and safe to run before you have read the guide:

```text
KARINA browser tab list --json
KARINA browser tab current --json
KARINA browser snapshot --json
```

Beyond these, read the guide rather than guessing a command surface. Every command answers
with JSON on stdout — **errors too**, carrying a machine-readable code.

**Drain stdout while the command runs — never wait for exit and read afterwards.** A caller
that blocks on process exit before reading can deadlock: the CLI is blocked on a write
nobody is reading, and neither side moves. Use a call that reads and waits together
(`subprocess.run(..., capture_output=True)`, `Command::output()`, `execFile`).
