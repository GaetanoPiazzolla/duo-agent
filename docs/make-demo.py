# Draws docs/duo.svg: python3 docs/make-demo.py docs/duo.svg
import sys
from html import escape

T = 20.0  # loop length in seconds
W, H = 860, 470
BG, PANE, FG, DIM = "#0d1117", "#161b22", "#e6edf3", "#7d8590"
CL, AG, OK, WARN = "#e8875f", "#6ea8fe", "#3fb950", "#d29922"
FONT = "ui-monospace,SFMono-Regular,Menlo,Consolas,monospace"

LX, RX = 36, 446      # text x of left / right pane
Y0, LH = 152, 22      # first line y, line height

# (time, pane, line, text, color)
events = [
    (2.2, "L", 0, "reading the code…", DIM),
    (2.2, "R", 0, "reading the code…", DIM),
    (3.4, "L", 1, "✓ draft written", OK),
    (3.9, "R", 1, "✓ draft written", OK),
    (5.0, "S", 0, "phase 2 · they read each other's draft and argue", DIM),
    (5.6, "R", 3, "1. /export has no limit at all", FG),
    (6.3, "R", 4, "2. per-IP breaks behind the LB", FG),
    (7.4, "L", 3, "ACCEPT 1", OK),
    (8.0, "L", 4, "COUNTER 2: key by API token", WARN),
    (8.8, "L", 5, "3. you forgot Retry-After", FG),
    (9.5, "L", 6, "4. Redis is overkill here", FG),
    (10.6, "R", 6, "ACCEPT 2, ACCEPT 3", OK),
    (11.3, "R", 7, "REJECT 4: we run 3 replicas", "#f85149"),
    (12.4, "L", 8, "still think in-memory is fine", FG),
    (13.2, "S", 0, "phase 3 · one plan", DIM),
    (13.8, "L", 10, "FINAL READY", CL),
    (14.6, "R", 10, "APPROVED", OK),
]

css, body = [], []


def window(i, t_in, t_out=T * 0.96, fade=0.25):
    a, b = t_in / T * 100, (t_in + fade) / T * 100
    c, d = t_out / T * 100, min(t_out + fade, T) / T * 100
    css.append(
        f"@keyframes k{i}{{0%,{a:.2f}%{{opacity:0}}{b:.2f}%,{c:.2f}%{{opacity:1}}{d:.2f}%,100%{{opacity:0}}}}"
        f".e{i}{{opacity:0;animation:k{i} {T}s linear infinite}}"
    )


def text(x, y, s, color, size=14, weight="normal", cls="", anchor="start"):
    c = f' class="{cls}"' if cls else ""
    return (f'<text x="{x}" y="{y}" fill="{color}" font-size="{size}" font-weight="{weight}"'
            f' text-anchor="{anchor}"{c}>{escape(s)}</text>')


# window
body.append(f'<rect width="{W}" height="{H}" rx="12" fill="{BG}"/>')
for k, col in enumerate(["#ff5f57", "#febc2e", "#28c840"]):
    body.append(f'<circle cx="{24 + k * 20}" cy="22" r="6" fill="{col}"/>')
body.append(text(W / 2, 27, "herdr · my-api", DIM, 13, anchor="middle"))

# command line, typed
cmd = "/duo-plan add rate limiting to the public API"
body.append(text(24, 70, "❯", OK, 15, "bold"))
body.append(f'<g clip-path="url(#type)">{text(44, 70, cmd, FG, 15)}</g>')
t0, t1 = 0.3, 1.7
css.append(
    f"@keyframes type{{0%,{t0 / T * 100:.2f}%{{width:0}}{t1 / T * 100:.2f}%,100%{{width:{W}px}}}}"
    f"#typerect{{animation:type {T}s steps(46,end) infinite}}"
)

# panes
for x, name, role, col in [(20, "claude", "scribe", CL), (430, "antigravity", "reviewer", AG)]:
    body.append(f'<rect x="{x}" y="96" width="410" height="300" rx="8" fill="{PANE}"'
                f' stroke="{col}" stroke-opacity=".45"/>')
    body.append(f'<circle cx="{x + 18}" cy="119" r="5" fill="{col}"/>')
    body.append(text(x + 30, 124, name, col, 14, "bold"))
    body.append(text(x + 30 + len(name) * 8.6 + 8, 124, role, DIM, 13))

RESULT_AT = 15.6
status_times = [t for t, p, *_ in events if p == "S"] + [RESULT_AT]
for i, (t, pane, line, s, col) in enumerate(events):
    if pane == "S":
        window(i, t, status_times[status_times.index(t) + 1])
        body.append(text(W / 2, 428, s, col, 13, cls=f"e{i}", anchor="middle"))
    else:
        window(i, t)
        x = LX if pane == "L" else RX
        body.append(text(x, Y0 + line * LH, s, col, 14, cls=f"e{i}"))
i = len(events)

# result banner
i_res = i
window(i_res, RESULT_AT, fade=0.4)
body.append(
    f'<g class="e{i_res}">'
    f'<rect x="20" y="408" width="{W - 40}" height="40" rx="8" fill="#12261a" stroke="{OK}" stroke-opacity=".6"/>'
    + text(W / 2, 433, "✓ rate-limiting-plan.md   ·   1 open disagreement for you: Redis vs in-memory", FG, 14, anchor="middle")
    + "</g>"
)

svg = f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" font-family="{FONT}">
<style>{"".join(css)}</style>
<defs><clipPath id="type"><rect id="typerect" x="44" y="50" width="0" height="30"/></clipPath></defs>
{chr(10).join(body)}
</svg>
'''
open(sys.argv[1], "w").write(svg)
