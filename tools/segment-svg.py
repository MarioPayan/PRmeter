#!/usr/bin/env python3
"""Generate segment.svg — one annotated diagram of the PRmeter statusline segment.

Same two rules as AImeter's generator, for the same reasons. Direct fill= attributes
rather than a <style> block, because GitHub serves README SVGs through its image proxy
into an <img> and inline attributes are the one thing guaranteed to survive that. And
every token is placed at an explicit x with its own textLength, so character positions
are exact whatever monospace font the viewer has — which is what lets the callout lines
point at the thing they label.

The segment is short, so the callouts name its two ends and the run of lights between
them; the strip underneath carries each glyph. Crowding four leader lines into 120px
would need elbows, and an elbow that has to be traced is not a label.
"""
import pathlib
from xml.sax.saxutils import escape

OUT = pathlib.Path(__file__).resolve().parent.parent / "docs" / "images" / "segment.svg"

MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, 'DejaVu Sans Mono', monospace"
BG, EDGE, HAIR = "#17181c", "#2a2c33", "#3a3d46"
TAG, DIM = "#5f87af", "#808080"
OK, WARN, CRIT = "#5faf5f", "#d7af5f", "#d75f5f"
LABEL, HEAD = "#9aa0aa", "#6c7280"

W, H = 860, 396
SIZE = 20.0
ADV = SIZE * 0.6           # monospace advance, forced by textLength below
BASE = 150.0               # the segment's baseline

out = []

# The segment, as (text, colour) tokens laid end to end.
TOKENS = [
    ("[PRs]", TAG), (" ", DIM), ("✗1", CRIT), (" ", DIM),
    ("◷2", WARN), (" ", DIM), ("✓1", OK), (" ", DIM), ("⊙6", TAG),
]
X0 = (W - sum(len(s) for s, _ in TOKENS) * ADV) / 2


def draw_segment():
    """Place each token at its own x. Returns {token index: (x_start, x_end)}."""
    spans, col = {}, 0
    for i, (s, fill) in enumerate(TOKENS):
        x = X0 + col * ADV
        width = len(s) * ADV
        spans[i] = (x, x + width)
        if s.strip():
            out.append(
                f'<text x="{x:.1f}" y="{BASE}" font-family="{MONO}" font-size="{SIZE}" '
                f'textLength="{width:.1f}" lengthAdjust="spacing" fill="{fill}" '
                f'xml:space="preserve">{escape(s)}</text>'
            )
        col += len(s)
    return spans


def label(x, y, s, size=12, fill=LABEL, anchor="middle"):
    out.append(
        f'<text x="{x:.1f}" y="{y}" font-family="{MONO}" font-size="{size}" '
        f'text-anchor="{anchor}" fill="{fill}" xml:space="preserve">{escape(s)}</text>'
    )


def tick(centre, y_from, y_to):
    """A hairline from a label to the token it names."""
    out.append(
        f'<line x1="{centre:.1f}" y1="{y_from}" x2="{centre:.1f}" y2="{y_to}" '
        f'stroke="{HAIR}" stroke-width="1"/>'
    )


def rule(y):
    out.append(f'<line x1="28" y1="{y}" x2="{W - 28}" y2="{y}" stroke="{EDGE}"/>')


spans = draw_segment()
mid = lambda i: (spans[i][0] + spans[i][1]) / 2          # noqa: E731
span = lambda a, b: (spans[a][0] + spans[b][1]) / 2      # noqa: E731

out.insert(0, f'<rect x="0" y="0" width="{W}" height="{H}" rx="7" fill="{BG}"/>')
out.insert(1, f'<rect x="0.5" y="0.5" width="{W-1}" height="{H-1}" rx="7" fill="none" '
              f'stroke="{EDGE}"/>')

# ── what this line is ────────────────────────────────────────────────────────
label(28, 40, "PRmeter — your open pull requests, in the statusline", 12.5, HEAD, "start")
rule(52)

# ── callouts above: the two ends ─────────────────────────────────────────────
# Both labels sit on one shelf and reach their token with a plain vertical tick.
# They point at opposite ends, so anchoring each away from the middle keeps them
# apart without staggering them to different heights.
SHELF = 106
tick(mid(0), SHELF + 4, BASE - 22)
label(mid(0) - 12, SHELF, "names it, and links to the docs", 12, anchor="end")

tick(mid(8), SHELF + 4, BASE - 22)
label(mid(8) + 12, SHELF, "waiting on your review", 12, anchor="start")

# ── callout below: the run of lights in between ──────────────────────────────
tick(span(2, 6), BASE + 10, 196)
label(span(2, 6), 214, "yours, counted by their worse light", 12)

# ── the strip: every glyph, and what else a line can hold ────────────────────
STRIP = 262
rule(STRIP - 18)
for x, head in ((28, "EACH LIGHT"), (470, "ALSO SEEN")):
    label(x, STRIP, head, 10, HEAD, "start")

for i, (glyph, colour, word, gloss) in enumerate((
    ("✗", CRIT, "needs you", "CI failing, a conflict, or changes requested"),
    ("◷", WARN, "waiting", "CI still running, or nobody has reviewed it"),
    ("✓", OK, "ready", "every check passed, and it is approved"),
    ("·", DIM, "unknown", "no checks in the repo, or nobody asked"),
)):
    y = STRIP + 24 + i * 20
    label(30, y, glyph, 13, colour, "start")
    label(52, y, word, 12, LABEL, "start")
    label(134, y, gloss, 11.5, DIM, "start")

for i, (glyph, meaning) in enumerate((
    ("[PRs]", "on its own: nothing open"),
    ("x ~ + @", "any non-UTF-8 terminal"),
    ("⊙", "asked of you, still open"),
    ("prmeter", "the same list, a row each"),
)):
    y = STRIP + 24 + i * 20
    label(472, y, glyph, 12.5, DIM, "start")
    label(578, y, meaning, 11.5, LABEL, "start")

svg = (
    f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" '
    f'viewBox="0 0 {W} {H}" role="img" aria-label="The PRmeter statusline segment, '
    f'annotated: a label that links to the docs, then your open pull requests counted '
    f'by their worse light — needing you, waiting, ready — and last how many pull '
    f'requests are waiting on your review.">'
    + "".join(out) + "</svg>\n"
)
OUT.write_text(svg)
print(f"wrote {OUT}  {W}x{H}")
