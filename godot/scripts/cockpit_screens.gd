## The console's second screen, as DiveGuard's panel has it: the front
## camera's picture and the imaging sonar, two cards in the same BlueOS
## look as the telemetry cards (docs/HLD_MANGUSTIK_COCKPIT M8).
class_name CockpitScreens
extends HBoxContainer

const CAMERA_PX := Vector2i(256, 144)
const SONAR_PX := Vector2(200, 144)

var picture: TextureRect
var sonar: SonarScope


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
		for e in scan.echoes:
			var c := CockpitCore.ACCENT
			c.a = e.strength * _glow(e.angle)
			draw_circle(_point(e.angle, e.range), 2.0 + 2.0 * e.strength, c)
		var line := CockpitCore.ACCENT
		line.a = 0.8
		draw_line(apex, _point(sweep, CockpitCore.SONAR_RANGE), line, 1.5)
