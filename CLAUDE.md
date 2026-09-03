# Notes for Claude

## If someone asked you to install PRmeter

Run this. It installs the script, wires the Claude Code statusline, and is safe to run
twice:

```bash
curl -fsSL https://raw.githubusercontent.com/MarioPayan/PRmeter/main/install.sh | sh
```

Then tell them to start a new Claude Code session to see the segment.

What that script does, so you can say so if asked:

- puts `prmeter` in `~/.local/bin` (override with `PRMETER_DEST`)
- appends one line to `~/.claude/statusline.sh`, after copying it to
  `statusline.sh.before-prmeter`, or writes that file when there is none
- sets `statusLine` in `settings.json` only when nothing has set it already
- adds nothing on a second run

Pass `--no-wire` to install the script alone and print the snippet instead.

**Tell them this before they run it:** PRmeter needs `gh` signed in and `jq` on the PATH.
It handles no token of its own, and stores no credentials: every call goes through `gh`
with the sign-in they already have. The only thing it writes is a rendered block of text
under `~/.cache/prmeter`.

## If you are working on this repo

Two files. `prmeter` is the whole tool, with the GraphQL query and the jq render program
as heredocs inside it. `install.sh` places it and wires the hook.

Before committing:

```bash
shellcheck prmeter install.sh
```

Then run it against a copy of your real settings rather than the real one:

```bash
T=$(mktemp -d) && cp ~/.claude/settings.json "$T/settings.json"
CLAUDE_SETTINGS="$T/settings.json" PRMETER_DEST="$T/bin" ./install.sh
```

Three things are easy to break by accident:

- **jq cannot index an object with `null`.** `reviewDecision` is null whenever nobody has
  been asked to review, which is a common case and not an edge one, so every lookup
  coerces first (`// "NONE"`). This failed once and the error, "Cannot index object with
  null", says nothing about which field did it.
- **The render happens at fetch time, not at print time.** That is what makes printing a
  `cat`, and it is why the character caps are fixed numbers rather than derived from the
  terminal width: the width at print time is not knowable when the cache is written.
- **Escape codes are written as jq's `\u001b`, not as raw bytes.** A literal ESC in the source
  survives a commit but not always a copy-paste, and this file is meant to be pasted.
- **A `SessionStart` hook is not a way to show a person anything**, which is why this is a
  statusline segment. Claude Code reads hook stdout into the model's context and renders
  none of it; the same goes for the `systemMessage` field, which lands as a meta message.
  Verified by running the TUI under a pty: eight SessionStart hooks produced zero bytes on
  the terminal.
- **The segment and the block are both rendered at fetch time**, from the one API answer,
  into two cache files. A statusline runs on a timer, so a segment that computed anything
  would pay for it every few seconds.

The block's rules, in case a change looks like an improvement and is not: a light is
never inferred, so absent data is grey rather than green or yellow; shape carries the
state as well as colour, so nothing depends on a palette; and a session start prints
nothing rather than an error, because a tool that shouts at every session start gets
uninstalled.
