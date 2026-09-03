#!/usr/bin/env sh
# PRmeter installer. Puts the script somewhere on your PATH and wires it into your
# Claude Code statusline.
#
# Nothing here overwrites anything. An existing statusline script is backed up before a
# line is appended to it, an existing statusLine setting is left exactly as it is, and
# running this twice does nothing the second time.
#
#   curl -fsSL https://raw.githubusercontent.com/MarioPayan/PRmeter/main/install.sh | sh
#
# Flags:
#   --no-wire   install the script only, and print the snippet to add yourself

set -eu

REPO="${PRMETER_REPO:-MarioPayan/PRmeter}"
BRANCH="${PRMETER_BRANCH:-main}"
DEST="${PRMETER_DEST:-$HOME/.local/bin}"
CLAUDE_DIR="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
SL="$CLAUDE_DIR/statusline.sh"
SETTINGS="${CLAUDE_SETTINGS:-$CLAUDE_DIR/settings.json}"
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
    *) say "note: $DEST is not on your PATH. Add it, or your statusline will not find prmeter." ;;
esac

SNIPPET="s=\$(\"$DEST/prmeter\" line); [ -n \"\$s\" ] && printf '  %s' \"\$s\""

if [ "$WIRE" -eq 0 ]; then
    say ""
    say "Not wiring anything. Add this to the script your statusLine runs:"
    say ""
    say "  $SNIPPET"
    exit 0
fi

# ---------------------------------------------------------------- the statusline script
mkdir -p "$CLAUDE_DIR"

if [ ! -f "$SL" ]; then
    printf '%s\n' '#!/usr/bin/env bash' '# Claude Code statusline.' "$SNIPPET" > "$SL"
    chmod +x "$SL"
    say "wrote $SL"
elif grep -q 'prmeter' "$SL" 2>/dev/null; then
    say "$SL already runs prmeter, left alone"
else
    cp "$SL" "$SL.before-prmeter"
    printf '\n%s\n%s\n' '# PRmeter - appended by its installer' "$SNIPPET" >> "$SL"
    say "appended to $SL (previous copy: $SL.before-prmeter)"
fi

# ---------------------------------------------------------------- settings.json
# Only ever adds statusLine when there is none. Someone who already has one has made a
# choice, and an installer that overrules it is a bug.
if [ -f "$SETTINGS" ] && grep -q '"statusLine"' "$SETTINGS" 2>/dev/null; then
    say "settings.json already sets statusLine, left alone"
elif command -v jq >/dev/null 2>&1; then
    [ -f "$SETTINGS" ] || echo '{}' > "$SETTINGS"
    jq -e . "$SETTINGS" >/dev/null 2>&1 || die "$SETTINGS is not valid JSON - fix it first, nothing was changed"
    cp "$SETTINGS" "$SETTINGS.before-prmeter"
    tmp=$(mktemp)
    jq --arg cmd "bash \"$SL\"" '.statusLine = {type: "command", command: $cmd, refreshInterval: 10}' \
        "$SETTINGS" > "$tmp" || die "could not write statusLine, nothing was changed"
    mv "$tmp" "$SETTINGS"
    say "set statusLine in $SETTINGS (previous copy: $SETTINGS.before-prmeter)"
fi

# ---------------------------------------------------------------- first fill
say ""
if "$DEST/prmeter" fetch >/dev/null 2>&1; then
    printf 'your statusline segment:  '
    "$DEST/prmeter" line
    say ""
    say ""
    say "and \`prmeter\` on its own prints the whole list:"
    say ""
    "$DEST/prmeter"
else
    say "Installed. PRmeter will fill in once gh is signed in."
fi
