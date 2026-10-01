## The console's second screen, as DiveGuard's panel has it: the front
## camera's picture and the imaging sonar, two cards in the same BlueOS
## look as the telemetry cards (docs/HLD_MANGUSTIK_COCKPIT M8), and the
## hydrophone from the operator's posoh repo as a third card
## (docs/HLD_POSOH_HYDROPHONE_2026-09-30.md).
class_name CockpitScreens
extends HBoxContainer

const CAMERA_PX := Vector2i(256, 144)
const SONAR_PX := Vector2(200, 144)
const HYDRO_PX := Vector2(196, 144)

var picture: TextureRect
var sonar: SonarScope
var hydro: HydroScope


func _init() -> void:
	add_theme_constant_override("separation", 8)
	picture = TextureRect.new()
	picture.custom_minimum_size = Vector2(CAMERA_PX)
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_card("КАМЕРА", picture)
	sonar = SonarScope.new()
	sonar.custom_minimum_size = SONAR_PX
	_card("СОНАР %d м" % roundi(CockpitCore.SONAR_RANGE), sonar)
	hydro = HydroScope.new()
	hydro.custom_minimum_size = HYDRO_PX
	_card("ГИДРОФОН 0–%d кГц" % roundi(PosohCore.nyquist_hz() / 1000.0),
		hydro)


func _card(title: String, content: Control) -> void:
	var box := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = CockpitCore.CARD
	style.border_color = CockpitCore.BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 6
	style.content_margin_bottom = 8
	box.add_theme_stylebox_override("panel", style)
	add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 4)
	box.add_child(column)
	var l := Label.new()
	l.text = title
	l.add_theme_font_size_override("font_size", 15)
	l.add_theme_color_override("font_color", CockpitCore.MUTED)
	column.add_child(l)
	column.add_child(content)


## The sonar fan: apex at the bottom centre, range rings every 10 m,
## the floor's return as a line of cells, things as bright blips, and
## the sweep that brightens what it has just passed.
class SonarScope:
	extends Control

	var scan := {"floor": [], "echoes": []}
	var sweep := 0.0

	func show_scan(s: Dictionary, t: float) -> void:
		scan = s
		sweep = CockpitCore.sonar_sweep(t)
		queue_redraw()

	func _point(angle: float, r: float) -> Vector2:
		var apex := Vector2(size.x / 2.0, size.y - 4.0)
		var k := (size.y - 10.0) / CockpitCore.SONAR_RANGE
		return apex + Vector2(sin(angle), -cos(angle)) * r * k

	## Echoes glow brightest just after the sweep passes them and fade
	## over one sweep, like a real scope's persistence.
	func _glow(angle: float) -> float:
		var behind := absf(angle - sweep)
		return clampf(1.0 - behind / CockpitCore.SONAR_FAN, 0.25, 1.0)

	func _draw() -> void:
		var half := CockpitCore.SONAR_FAN / 2.0
		var grid := CockpitCore.MUTED
		grid.a = 0.35
		var apex := _point(0.0, 0.0)
		for r in [10.0, 20.0, 30.0]:
			var pts := PackedVector2Array()
			for i in 17:
				pts.append(_point(-half + CockpitCore.SONAR_FAN * i / 16.0,
					r))
			draw_polyline(pts, grid, 1.0)
		draw_line(apex, _point(-half, CockpitCore.SONAR_RANGE), grid, 1.0)
		draw_line(apex, _point(half, CockpitCore.SONAR_RANGE), grid, 1.0)
		var floor: Array = scan.floor
		var n := floor.size()
		for b in n:
			var r: float = floor[b]
			if r < 0.0:
				continue
			var a := -half + CockpitCore.SONAR_FAN * b / maxf(1.0, n - 1.0)
			var c := CockpitCore.STATE_COLOUR.warn
			c.a = 0.35 + 0.5 * _glow(a)
			# The floor answers from its first return to the range end.
			draw_line(_point(a, r), _point(a, minf(CockpitCore.SONAR_RANGE,
				r + 2.5)), c, 3.0)
		var layer: float = scan.get("layer", -1.0)
		if layer > 0.0:
			# The thermocline: a faint, even arc across the whole fan.
			var band := CockpitCore.ACCENT
			band.a = 0.28
			var pts := PackedVector2Array()
			for i in 17:
				pts.append(_point(-half + CockpitCore.SONAR_FAN * i / 16.0,
					layer))
			draw_polyline(pts, band, 4.0)
		for e in scan.echoes:
			var c := CockpitCore.ACCENT
			c.a = e.strength * _glow(e.angle)
			draw_circle(_point(e.angle, e.range), 2.0 + 2.0 * e.strength, c)
		var line := CockpitCore.ACCENT
		line.a = 0.8
		draw_line(apex, _point(sweep, CockpitCore.SONAR_RANGE), line, 1.5)


## The hydrophone's card: two level bars (the lake and the ROV's own
## thrusters, as a difference, since the instrument is uncalibrated),
## how far a vehicle like this one would be heard, and the water's
## sound speed with the wavelength at the top of the band.  Instrument
## cyan for the reading; amber only when the thrusters drown the lake.
class HydroScope:
	extends Control

	var r := {}
	var card := {}

	func show_reading(depth: float, thrust: float) -> void:
		r = PosohCore.reading(depth, thrust)
		card = PosohCore.card(depth, thrust)
		queue_redraw()

	func _text(at: Vector2, text: String, colour: Color,
			font_size := 13) -> void:
		draw_string(get_theme_default_font(), at, text,
			HORIZONTAL_ALIGNMENT_LEFT, size.x - at.x, font_size, colour)

	func _bar(y: float, fill: float, colour: Color) -> void:
		var track := CockpitCore.MUTED
		track.a = 0.25
		draw_rect(Rect2(0, y, size.x, 8), track)
		draw_rect(Rect2(0, y, size.x * clampf(fill, 0.0, 1.0), 8), colour)

	func _draw() -> void:
		if r.is_empty():
			return
		var cyan := CockpitCore.ACCENT
		var muted := CockpitCore.MUTED
		var loud: Color = CockpitCore.STATE_COLOUR[card.state]
		_text(Vector2(0, 16), card.value, loud, 17)
		# Both bars on one 90 dB scale that starts 30 dB under the lake,
		# so the lake fills a third and the thrusters show how far they
		# rise over it; stopped thrusters leave their bar empty.
		var floor_db: float = r.ambient_db - 30.0
		_text(Vector2(0, 38), "озеро", muted)
		_bar(44, (r.ambient_db - floor_db) / 90.0, cyan)
		_text(Vector2(0, 68), "свои винты", muted)
		var own: float = r.self_db
		_bar(74, 0.0 if own == -INF else (own - floor_db) / 90.0,
			loud if r.masked else cyan)
		_text(Vector2(0, 100), card.sub, cyan)
		_text(Vector2(0, 118), "c %d м/с · λ %.1f см" % [
			roundi(r.sound_speed), r.wavelength_cm], muted)
		_text(Vector2(0, 136), "пьезо 20 мм · слышит кругом" if r.omni
			else "пьезо 20 мм", muted)
