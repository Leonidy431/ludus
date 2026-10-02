## How much text the heart's panel of a place holds, measured with its
## own font and sizes (blind spot 15 of docs/BLINDSPOTS_CODE_BREAKTHROUGH_
## 2026-10-01.md; phase S3 of docs/HLD_12_STORIES_HEADSET_2026-10-02.md;
## the operator: "measure first, then shorten").
##   godot --headless --path godot -s res://tools/measure_panel_text.gd \
##     -- [--check]
##
## The panel is built as location.gd builds it (tests/deeds/panel_text.gd
## reads its Label3D and its bark), and every text of the 26 acts is
## laid out with the real font: the walk of tests/deeds_graph.gd gives
## every button, every panel line and every reply a player can meet,
## and each of its states is composed as LocationHeart composes the
## panel (the heart's words, the place's teaching, the act's lines, the
## reply, the buttons with "Отойти").
##
## Printed: the panel's sizes; the angle and the headset pixels of a
## letter at the panel's own distance and at 3.2 m (where a thing's tag
## shows, TABOO 0.013 item 4) for Quest 3 at about 25 px per degree; the
## width of a letter in these texts (mean, 95th percentile, widest
## text); the limits in letters that follow from the widest one; the
## limits the contract (tests/test_place_deeds.gd) holds; how many
## buttons and lines pass them; the tallest panel against the bark.
## With --check, a contract limit looser than the measurement, a button
## or a line past its limit, or a panel taller than its bark exits 1.
## The last line printed is "PANEL_TEXT_JSON {...}".
##
## Constitution: ФОРМА (the bark, its letters and the eye's measure) →
## ДЕЙСТВИЕ (the limit is measured, then every step is written within
## it) → ЦЕЛЬ (a step read at a glance keeps the eyes on the work).
extends SceneTree

const CONTRACT := "res://tests/test_place_deeds.gd"
const TAG_M := 3.2

# The helpers live under tests/, which the export leaves out of the
# APK; they are loaded when the tool runs, not preloaded, so this
# script in the APK names nothing it lacks.
var PanelText: Script
var Graph: Script


func _initialize() -> void:
	var check := "--check" in OS.get_cmdline_user_args()
	PanelText = load("res://tests/deeds/panel_text.gd")
	Graph = load("res://tests/deeds_graph.gd")
	var lim: Dictionary = load(CONTRACT).get_script_constant_map()
	var p: Dictionary = PanelText.panel()
	var r := measure(p, lim)
	print("panel: font %d px, pixel %.4f m, wrap width %d px = %.3f m, "
		% [p.size, p.pixel, int(p.width), p.width * p.pixel]
		+ "at %.2f m; bark %.2f x %.2f m; line %.0f px = %.4f m"
		% [p.distance, p.bark.x, p.bark.y, p.line_px,
			p.line_px * p.pixel])
	for d in [p.distance, TAG_M]:
		var em: float = p.size * p.pixel
		var cap: float = p.cap_px * p.pixel
		print("  at %.1f m: em %.4f m = %.2f deg = %.0f headset px; "
			% [d, em, PanelText.degrees(em, d),
				PanelText.degrees(em, d) * PanelText.QUEST3_PX_PER_DEG]
			+ "capital %.0f px = %.4f m = %.2f deg = %.1f headset px"
			% [p.cap_px, cap, PanelText.degrees(cap, d),
				PanelText.degrees(cap, d) * PanelText.QUEST3_PX_PER_DEG])
	print("letter width over the %d texts of the acts: mean %.1f px, "
		% [r.texts, r.mean] + "95th %.1f px, widest text %.2f px/letter"
		% [r.p95, r.widest])
	print("prefix '%s' %.0f px; at the widest letters one line holds %d, "
		% [PanelText.PREFIX, r.prefix_px, r.line_letters]
		+ "a button after its prefix %d (at the 95th: %d and %d)"
		% [r.button_letters, r.line_letters_p95, r.button_letters_p95])
	print("contract: button <= %d letters on one line; panel line <= %d "
		% [lim.BUTTON_MAX, lim.LINE_MAX] + "letters in <= %d lines; "
		% lim.LINE_WRAP_MAX + "a panel <= the bark's %d lines"
		% r.bark_lines)
	print("buttons: %d different, %d over %d letters, %d wrap"
		% [r.buttons, r.buttons_over, lim.BUTTON_MAX, r.buttons_wrap]
		+ "; with their reason %d wrap" % r.reasons_wrap)
	print("panel lines: %d different, %d over %d letters, "
		% [r.lines, r.lines_over, lim.LINE_MAX]
		+ "%d wrap past %d lines, longest %d letters"
		% [r.lines_wrap, lim.LINE_WRAP_MAX, r.line_longest])
	print("panels: %d states, %d taller than the bark; tallest %d lines "
		% [r.panels, r.panels_over, r.tallest]
		+ "(%s); the bark holds %d" % [r.tallest_at, r.bark_lines])
	for b in r.over:
		print("  over: %s" % b)
	if r.panels_over > 0:
		print("  tallest panel:\n" + r.tallest_text)
	var out := r.duplicate()
	out.erase("over")
	out.erase("tallest_text")
	print("PANEL_TEXT_JSON " + JSON.stringify(out))
	var bad: bool = r.buttons_over > 0 or r.buttons_wrap > 0 \
		or r.lines_over > 0 or r.lines_wrap > 0 or r.panels_over > 0 \
		or lim.BUTTON_MAX > r.button_letters \
		or lim.LINE_MAX > lim.LINE_WRAP_MAX * r.line_letters
	quit(1 if check and bad else 0)


## Everything the report prints, from the panel and the walk.
func measure(p: Dictionary, lim: Dictionary) -> Dictionary:
	var g: Dictionary = Graph.build()
	var buttons := {}
	var reasons := {}
	var lines := {}
	var r := {"panels": 0, "panels_over": 0, "tallest": 0,
		"tallest_at": "", "tallest_text": "", "tallest_by_act": {},
		"bark_lines": PanelText.bark_lines(p)}
	for id in g.acts:
		var place: Dictionary = g.acts[id].place
		for n in g.acts[id].nodes:
			for l in n.lines + [n.reply]:
				if str(l) != "":
					lines[str(l)] = true
			for o in n.options:
				buttons[str(o.text)] = true
				if o.disabled and o.reason != "":
					reasons["%s  (%s)" % [o.text, o.reason]] = true
			var text: String = PanelText.compose(place, n)
			var h: int = PanelText.wrapped_all(p, text)
			r.panels += 1
			if h > r.bark_lines:
				r.panels_over += 1
			r.tallest_by_act[id] = maxi(r.tallest_by_act.get(id, 0), h)
			if h > r.tallest:
				r.tallest = h
				r.tallest_at = id
				r.tallest_text = text
	var per: Array = []
	for tx in buttons.keys() + lines.keys():
		if tx.length() >= 10:
			per.append(PanelText.width_px(p, tx) / tx.length())
	per.sort()
	var mean := 0.0
	for v in per:
		mean += v
	mean /= maxf(1.0, per.size())
	var p95: float = per[int(floor(0.95 * (per.size() - 1)))]
	var prefix_px: float = PanelText.width_px(p, PanelText.PREFIX)
	r.merge({"texts": per.size(), "mean": mean, "p95": p95,
		"widest": per[-1], "prefix_px": prefix_px,
		"line_letters": int(floor(p.width / per[-1])),
		"button_letters": int(floor((p.width - prefix_px) / per[-1])),
		"line_letters_p95": int(floor(p.width / p95)),
		"button_letters_p95": int(floor((p.width - prefix_px) / p95)),
		"buttons": buttons.size(), "buttons_over": 0, "buttons_wrap": 0,
		"reasons_wrap": 0, "lines": lines.size(), "lines_over": 0,
		"lines_wrap": 0, "line_longest": 0,
		"em_deg_panel": PanelText.degrees(p.size * p.pixel, p.distance),
		"em_deg_tag": PanelText.degrees(p.size * p.pixel, TAG_M),
		"cap_px_headset_panel": PanelText.degrees(p.cap_px * p.pixel,
			p.distance) * PanelText.QUEST3_PX_PER_DEG,
		"cap_px_headset_tag": PanelText.degrees(p.cap_px * p.pixel, TAG_M)
			* PanelText.QUEST3_PX_PER_DEG,
		"over": []})
	for b in buttons:
		var wraps: bool = PanelText.wrapped(p, PanelText.PREFIX + b) > 1
		if b.length() > lim.BUTTON_MAX:
			r.buttons_over += 1
		if wraps:
			r.buttons_wrap += 1
		if b.length() > lim.BUTTON_MAX or wraps:
			r.over.append("button %d %s" % [b.length(), b])
	for b in reasons:
		if PanelText.wrapped(p, PanelText.PREFIX + b) > 1:
			r.reasons_wrap += 1
	for l in lines:
		r.line_longest = maxi(r.line_longest, l.length())
		var wraps: bool = PanelText.wrapped(p, l) > lim.LINE_WRAP_MAX
		if l.length() > lim.LINE_MAX:
			r.lines_over += 1
		if wraps:
			r.lines_wrap += 1
		if l.length() > lim.LINE_MAX or wraps:
			r.over.append("line %d %s" % [l.length(), l])
	return r
