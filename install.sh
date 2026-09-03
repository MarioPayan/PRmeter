#!/usr/bin/env sh
# PRmeter installer. Puts the script somewhere on your PATH and wires it to run when a
# Claude Code session starts.
#
# Safe to run twice: it backs up your settings before touching them, and it will not add
# a second hook if one is already there.
#
#   curl -fsSL https://raw.githubusercontent.com/MarioPayan/PRmeter/main/install.sh | sh
#
# Flags:
#   --no-wire   install the script only, and print the hook to add yourself

set -eu

REPO="${PRMETER_REPO:-MarioPayan/PRmeter}"
BRANCH="${PRMETER_BRANCH:-main}"
DEST="${PRMETER_DEST:-$HOME/.local/bin}"
SETTINGS="${CLAUDE_SETTINGS:-$HOME/.claude/settings.json}"
WIRE=1

for arg in "$@"; do
    case "$arg" in
        --no-wire) WIRE=0 ;;
        -h | --help) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "install.sh: unknown flag $arg" >&2; exit 2 ;;
    esac
done

say() { printf '%s\n' "$*"; }
die() { printf 'install.sh: %s\n' "$*" >&2; exit 1; }

command -v gh >/dev/null 2>&1 || die "needs gh (https://cli.github.com), which PRmeter uses to reach GitHub"
command -v jq >/dev/null 2>&1 || die "needs jq (https://jqlang.github.io/jq)"
gh auth status >/dev/null 2>&1 || say "note: gh is not signed in yet. Run 'gh auth login' or PRmeter will stay quiet."

# ---------------------------------------------------------------- the script itself
here=$(unset CDPATH; cd -- "$(dirname -- "$0")" && pwd)
mkdir -p "$DEST"

if [ -f "$here/prmeter" ]; then
    cp "$here/prmeter" "$DEST/prmeter"
    say "installed $DEST/prmeter (from this checkout)"
else
    url="https://raw.githubusercontent.com/$REPO/$BRANCH/prmeter"
    curl -fsSL "$url" -o "$DEST/prmeter.tmp" || die "could not download $url"
    mv "$DEST/prmeter.tmp" "$DEST/prmeter"
    say "installed $DEST/prmeter"
fi
chmod +x "$DEST/prmeter"

case ":$PATH:" in
    *":$DEST:"*) ;;
    *) say "note: $DEST is not on your PATH. Add it, or the hook below will not find prmeter." ;;
esac

HOOK_CMD="$DEST/prmeter"

if [ "$WIRE" -eq 0 ]; then
    say ""
    say "Not wiring anything. To do it yourself, add this to \"hooks\" in $SETTINGS:"
    say ""
    say '  "SessionStart": [ { "hooks": [ { "type": "command", "command": "'"$HOOK_CMD"'" } ] } ]'
    exit 0
fi

# ---------------------------------------------------------------- the session hook
mkdir -p "$(dirname "$SETTINGS")"
[ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"

jq -e . "$SETTINGS" >/dev/null 2>&1 || die "$SETTINGS is not valid JSON - fix it first, nothing was changed"

# Already wired? Then this is a re-run, and a second hook would print the block twice.
if jq -e --arg c "prmeter" '
      (.hooks.SessionStart // []) | any(.hooks // [] | any(.command // "" | contains($c)))
    ' "$SETTINGS" >/dev/null; then
    say "session hook already present in $SETTINGS, left alone"
else
    cp "$SETTINGS" "$SETTINGS.before-prmeter"
    tmp=$(mktemp)
    jq --arg cmd "$HOOK_CMD" '
        .hooks //= {}
        | .hooks.SessionStart //= []
        | .hooks.SessionStart += [ { hooks: [ { type: "command", command: $cmd, timeout: 10 } ] } ]
      ' "$SETTINGS" > "$tmp" || die "could not write the hook, nothing was changed"
    mv "$tmp" "$SETTINGS"
    say "wired the session hook into $SETTINGS (previous copy: $SETTINGS.before-prmeter)"
fi

# ---------------------------------------------------------------- your own eyes
# The hook hands the block to Claude. It does not put it on your screen: Claude Code
# reads SessionStart stdout into the model's context and prints none of it. Seeing it
# yourself means printing it yourself, from the shell, just before Claude starts.
say ""
say "The hook above feeds the block to Claude. To put it on YOUR screen, add this to"
say "your shell rc (~/.zshrc, ~/.bashrc):"
say ""
say '  claude() { command -v prmeter >/dev/null && prmeter; command claude "$@"; }'
say ""
say "Already wrap claude yourself? Put the line 'prmeter' inside the wrapper you have,"
say "rather than pasting this over it."

# ---------------------------------------------------------------- first fill
say ""
if "$DEST/prmeter" fetch >/dev/null 2>&1; then
    "$DEST/prmeter"
else
    say "Installed. PRmeter will fill in once gh is signed in."
fi
