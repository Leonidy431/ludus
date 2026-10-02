## The video of the operator's instruments (CLAUDE.md TABOO 0.022): what
## a sonar, a magnetometer, a hydrophone or a range finder shows on the
## screen of the robot or of the surface, drawn by code from the game's
## own telemetry, frame by frame.  Nothing is recorded or shipped: the
## picture is honest because it is computed from the same depth, range
## and field the scene uses, and it weighs nothing in the APK.
##
## Each kind draws into a small Image; the scene puts it on a quad.  The
## drawing is pure (same input, same pixels) so a test can check it.
class_name ScreenFeed
extends RefCounted

const KINDS := ["sonar", "curve", "spectrogram", "range", "status",
	"camera"]
const W := 192
const H := 120
## The instrument palette: cyan of the instrument class (TABOO 0.38).
const INK := Color(0.45, 0.92, 1.0)
const DIM := Color(0.10, 0.30, 0.36)
const BG := Color(0.02, 0.05, 0.06)
const WARN := Color(1.0, 0.72, 0.35)


static func blank() -> Image:
	var img := Image.create(W, H, false, Image.FORMAT_RGB8)
	img.fill(BG)
	return img


## A sonar fan from the bottom middle: `ranges` are echo distances in
## metres for beams spread over 120 degrees, `max_m` the screen's reach,
## `sweep` the beam being painted now (0..1).  Echoes brighter where
## they are near; the sweep line leads.
static func sonar(img: Image, ranges: Array, max_m: float,
		sweep: float) -> void:
	var cx := W / 2
	var cy := H - 2
	var n := ranges.size()
	for i in n:
		var a := deg_to_rad(-60.0 + 120.0 * (float(i) + 0.5) / float(n))
		var r := clampf(float(ranges[i]) / max_m, 0.0, 1.0)
		var px := cx + int(sin(a) * r * float(H - 6))
		var py := cy - int(cos(a) * r * float(H - 6))
		var c := INK.lerp(DIM, r)
		for d in 3:
			_put(img, px + d - 1, py, c)
			_put(img, px, py + d - 1, c)
	for k in [0.33, 0.66, 1.0]:
		for s in 60:
			var a := deg_to_rad(-60.0 + 2.0 * float(s))
			_put(img, cx + int(sin(a) * k * float(H - 6)),
				cy - int(cos(a) * k * float(H - 6)), DIM)
	var sa := deg_to_rad(-60.0 + 120.0 * sweep)
	for t in H - 6:
		_put(img, cx + int(sin(sa) * float(t)), cy - int(cos(sa) * float(t)),
			INK.darkened(0.3))


## A curve over time, newest on the right: the magnetometer in nT, the
## depth in metres.  `lo` and `hi` are the scale; a value past `alarm`
## is drawn warm (an anomaly: iron in the silt, node 22).
static func curve(img: Image, values: Array, lo: float, hi: float,
		alarm := INF) -> void:
	for y in [H / 4, H / 2, 3 * H / 4]:
		for x in range(0, W, 4):
			_put(img, x, y, DIM)
	var n := values.size()
	var prev := -1
	for i in n:
		var x := W - n + i
		var k := clampf((float(values[i]) - lo) / maxf(hi - lo, 0.001),
			0.0, 1.0)
		var y := H - 4 - int(k * float(H - 8))
		var c := WARN if float(values[i]) >= alarm else INK
		if prev >= 0:
			for yy in range(mini(prev, y), maxi(prev, y) + 1):
				_put(img, x, yy, c)
		_put(img, x, y, c)
		prev = y


## A spectrogram column by column, newest on the right: each column is
## band energies 0..1 from low (bottom) to high (top), as a hydrophone
## hears the water (the sonar's ping, the motor, the room tone).
static func spectrogram(img: Image, columns: Array) -> void:
	var n := columns.size()
	for i in n:
		var col: Array = columns[i]
		var x := W - n + i
		var bands := col.size()
		for b in bands:
			var e := clampf(float(col[b]), 0.0, 1.0)
			var y0 := H - 1 - int(float(b) * float(H) / float(bands))
			var y1 := H - 1 - int(float(b + 1) * float(H) / float(bands))
			var c := BG.lerp(INK, e)
			for y in range(y1 + 1, y0 + 1):
				_put(img, x, y, c)


## A range finder: a bar and its number of centimetres as ticks, the
## distance from the robot to what is ahead (a lidar or an echo sounder).
static func range_bar(img: Image, metres: float, max_m: float) -> void:
	var k := clampf(metres / max_m, 0.0, 1.0)
	var x1 := 8 + int(k * float(W - 16))
	for y in range(H / 2 - 6, H / 2 + 6):
		for x in range(8, x1):
			_put(img, x, y, INK if metres > 0.5 else WARN)
	for i in 11:
		var x := 8 + int(float(i) / 10.0 * float(W - 16))
		for y in range(H / 2 + 8, H / 2 + 14):
			_put(img, x, y, DIM)


static func _put(img: Image, x: int, y: int, c: Color) -> void:
	if x >= 0 and y >= 0 and x < W and y < H:
		img.set_pixel(x, y, c)


## The total field over a point, in nT: the Earth's field of the lake
## (about 55 000 nT at 42 N) plus a dipole-like bump near iron; depth of
## the robot and the iron's position from the scene.  An honest shape:
## the anomaly falls with the cube of distance.
static func field_nt(robot: Vector3, iron: Array, base := 55000.0) -> float:
	var f := base
	for p in iron:
		var d := maxf(robot.distance_to(p.at), 0.5)
		f += float(p.moment) / (d * d * d)
	return f
