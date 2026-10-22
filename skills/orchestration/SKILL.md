---
name: karina-orchestration
description: >-
  Use Karina orchestration for structured multi-agent coordination on Windows:
  persistent threaded messages between agent terminals, blocking ask/reply
  flows, task DAGs with dependencies, dispatching work to supervised worker
  tabs, waiting for worker_done or escalation, decision gates, and coordinator
  loops. Use whenever work is split across agent terminals and someone must
  track which task runs where and who reported what. Use plain terminal
  commands for ordinary shell work that needs no coordination state.
version: 1.2.0
---

# Inter-Agent Orchestration (Windows)

This file is a discovery stub, not the usage guide. The full, version-matched orchestration
reference is served by the `karina-cli` binary itself — kept out of this file on purpose so it
can never drift from the binary that will actually run your commands.

Engage Karina's orchestration surface whenever **coordination state matters** — when someone
has to know which task is running where, who reported what, and whether a message was
acknowledged. It covers persistent threaded messages between agent terminals, blocking
ask/reply flows, task DAGs with dependencies, dispatching work to supervised worker tabs,
waiting for `worker_done` or escalation, decision gates, and coordinator loops.

Use plain terminal commands for ordinary shell work that needs no coordination state.

This provider is **Windows-only**.

## This surface talks to the running app

Unlike `karina-computer-use`, these commands do not act alone — Runs, tasks, dispatches, and
the message inbox live inside the Karina app, and the CLI reaches it over a named pipe. **The
app must be running.** If it is not, every command answers with a JSON error saying so; the
CLI will not launch the app for you, because that would tie the app's lifetime to a single
command.

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
KARINA skills get karina-orchestration
```

That prints the complete, version-matched guide for the exact binary that will handle your
next commands — the six domains, every command and flag, the message contract, and the
error codes. Read it first, then run the specific command you need.

Don't guess subcommands or flags from memory or from a cached copy of this stub. They may
change between Karina releases, and this file deliberately does not list them. Prefer
`--json` for agent-driven calls; **every response is JSON, including errors**.

**Drain stdout while the command runs — never wait for exit and read afterwards.** This
very command prints about 13 KB, more than a pipe's default buffer holds, so a caller that
blocks on process exit before reading will deadlock: the CLI is blocked on a write nobody
is reading, and neither side moves. The same applies to stderr if you capture it —
`check --wait` writes a keepalive line there every 15 seconds for up to an hour. Use a call
that reads and waits together (`subprocess.run(..., capture_output=True)`,
`Command::output()`, `execFile`), not `wait()` followed by `read()`. This applies to every
Karina command, not just this one.

## Orientation commands

These three are read-only and safe to run before you have read the guide:

```text
KARINA orchestration run-current --json
KARINA orchestration run-list --json
KARINA orchestration worker-list --json
```

Beyond these, read the guide rather than guessing a command surface. In particular, do not
invent a polling loop: the guide documents a blocking wait, and a timeout there is a
checkpoint, not a failure.

## Why the name starts with `karina-`

`~/.agents/skills/` is a shared directory that several tools install into, so a skill whose
name collides with another tool's gets overwritten by whichever was installed last. That is
why this skill is named `karina-orchestration` and drives `karina-cli orchestration ...`.

Karina coordinates **on this PC only**. There is no remote-host or relay-routing axis here
(`--to <host>` and friends); do not carry those flags over from elsewhere.
