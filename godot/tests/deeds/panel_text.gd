## The heart's panel of a place as location.gd builds it, measured with
## its own font (blind spot 15 of docs/BLINDSPOTS_CODE_BREAKTHROUGH_
## 2026-10-01.md; phase S3 of docs/HLD_12_STORIES_HEADSET_2026-10-02.md).
##
## The panel is not described here by hand: panel() builds the real one
## (location.gd _build_ui) and reads its Label3D and its bark, so a
## change of the font size, the wrap width or the bark in location.gd
## moves the limits of the contract with it.  The text is laid out as
## the Label3D lays it out: one paragraph per "\n", wrapped at the
## label's width by whole words (AUTOWRAP_WORD_SMART).
##
## Used by tools/measure_panel_text.gd (the measurement and its report)
## and by tests/test_place_deeds.gd (the contract on every act).
##
## Constitution: ФОРМА (the bark and the size of its letters) → ДЕЙСТВИЕ
## (every step of an act is written to fit it) → ЦЕЛЬ (the player reads
## the step at a glance and keeps the eyes on the place, not the text).
extends RefCounted

const LOCATION := "res://scripts/location.gd"
## Quest 3 at the centre of the lens, about 25 pixels per degree (the
## figure the operator's brief gives; the panel stands at the centre).
const QUEST3_PX_PER_DEG := 25.0
## The prefix the panel puts before a button (RuleCell.choice_lines),
## the widest one: the pointer and a one-digit number.
const PREFIX := "▸ 9. "


## The real panel's sizes: {font, size, pixel, width, distance, bark,
## line_px, ascent_px, cap_px, wrap}.
static func panel() -> Dictionary:
	var node: Node3D = load(LOCATION).new()
	node.camera = XRCamera3D.new()
	node._build_ui()
	var l: Label3D = node.panel
	var bark: QuadMesh = node.panel_bg.mesh
	var font: Font = l.font if l.font != null else default_font()
	var fs: int = l.font_size
	var out := {"font": font, "size": fs, "pixel": l.pixel_size,
		"width": float(l.width), "distance": -l.position.z,
		"bark": bark.size, "bark_distance": -node.panel_bg.position.z,
		"line_px": font.get_height(fs) + l.line_spacing,
		"ascent_px": font.get_ascent(fs),
		"cap_px": _ink_height(font, fs, "Н"),
		"wrap": l.autowrap_mode}
	node.camera.free()
	node.free()
	return out


## The font a Label3D without its own font draws with.
static func default_font() -> Font:
	var t := ThemeDB.get_project_theme()
	if t != null and t.has_default_font():
		return t.default_font
	t = ThemeDB.get_default_theme()
	if t != null and t.has_default_font():
		return t.default_font
	return ThemeDB.fallback_font


## The height in pixels of the ink of one glyph (a capital without
## ascender or descender gives the cap height).
static func _ink_height(font: Font, fs: int, ch: String) -> float:
	var ts := TextServerManager.get_primary_interface()
	var line := TextLine.new()
	line.add_string(ch, font, fs)
	var glyphs: Array = ts.shaped_text_get_glyphs(line.get_rid())
	if glyphs.is_empty():
		return 0.0
	var g: Dictionary = glyphs[0]
	var size: Vector2 = ts.font_get_glyph_size(g.font_rid,
		Vector2i(fs, 0), g.index)
	var off: Vector2 = ts.font_get_glyph_offset(g.font_rid,
		Vector2i(fs, 0), g.index)
	# The glyph's bitmap carries a pixel or two of padding around the
	# ink; the offset is where the ink starts above the baseline.
	return minf(size.y, -off.y) if off.y < 0.0 else size.y


## The width in pixels of one line of text, unwrapped.
static func width_px(p: Dictionary, text: String) -> float:
	return p.font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1,
		p.size).x


## How many lines the label wraps one paragraph (no "\n") into.
static func wrapped(p: Dictionary, text: String) -> int:
	if text == "":
		return 1
	var para := TextParagraph.new()
	para.width = p.width
	para.break_flags = TextServer.BREAK_MANDATORY \
		| TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	para.add_string(text, p.font, p.size)
	return para.get_line_count()


## The lines of the panel's text after wrapping, all paragraphs.
static func wrapped_all(p: Dictionary, text: String) -> int:
	var n := 0
	for para in text.split("\n"):
		n += wrapped(p, para)
	return n


## How many wrapped lines the bark holds, top to bottom.
static func bark_lines(p: Dictionary) -> int:
	return int(floor(p.bark.y / (p.line_px * p.pixel)))


## The angle in degrees a height h in metres covers at distance d.
static func degrees(h: float, d: float) -> float:
	return rad_to_deg(2.0 * atan(h / (2.0 * d)))


## The panel's text for one node of the walk (tests/deeds_graph.gd) as
## LocationHeart.lines and .text compose it for an act: the heart's
## words, the place's teaching, the act's lines, the reply (and "done
## today" once the act is closed), then the buttons with "Отойти", the first one under the pointer.
static func compose(place: Dictionary, node: Dictionary) -> String:
	var body: Array = [str(place.get("heart", "")), "",
		str(place.get("teaching", "")), ""]
	body += node.lines
	if str(node.reply) != "":
		body += ["", str(node.reply)]
	if node.done:
		# A closed act says so on the heart's panel: the tallest case.
		body.append("Сегодня уже сделано.")
	body.append("")
	return "\n".join(body + RuleCell.choice_lines(node.options
		+ [LocationHeart.AWAY], 0))
