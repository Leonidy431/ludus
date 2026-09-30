## The preparation sheet at the corner of repentance on the path of the
## witness: the headset form of public/ludus/ludus-confession.js.
##
## The game does not and cannot perform the sacrament: absolution is
## given only by a priest in church (TABOO 0.26).  What the sheet offers
## is the examination of conscience the Church asks of a penitent, as a
## few questions on birch bark beside the path, at the witness line and
## never past it.
##
## In the headset the sheet has no field at all (TABOO 0.26 point 9):
## the system keyboard of a headset offers voice dictation, which the
## operating system handles and may send to its maker; the game cannot
## switch that off, so it offers no place to write.  The sheet shows the
## questions, says plainly that this is not the sacrament, and advises
## paper or the silence of the heart.
##
## The sheet keeps nothing and tells nothing: it holds no text, opens no
## file, keeps no count, gives no reward, attribute or gate, and leaves
## no mark that it was ever read.  "Сжечь листок" only takes it from the
## eyes; walking away and back brings a clean sheet again.
## godot/tests/test_confession.gd fails the build if this file ever
## reaches for a file, the network, the console or a counter.
## Placed by a small hook in witness.gd.
class_name ConfessionSheet
extends Node3D

## The questions of the web sheet, in the same words (q_ru of QUESTIONS
## in ludus-confession.js): the eight passions of the Ladder of St John
## Climacus.  Prompts for the heart, never a checklist that is scored.
const QUESTIONS := [
	"Не служил ли я чреву прежде людей?",
	"Не блуждали ли мои глаза и помыслы?",
	"Не удержал ли я того, что должен был отдать?",
	"Кого я ранил словом и не простил?",
	"Не скорбел ли я о потерянном, а не о содеянном?",
	"Где я опустил руки и назвал это отдыхом?",
	"Какое добро я сделал, чтобы это видели?",
	"Кого я осудил как худшего себя?",
]
const NOT_SACRAMENT := "Это не таинство. Прощает Бог; разрешительную молитву читает священник в храме. Здесь вы только готовите сердце."
const HEADSET_NOTE := "В шлеме на этом листке писать нельзя: голосовой ввод игра выключить не может. Ответьте на вопросы на бумаге или в тишине сердца."
const BURN := "Сжечь листок"
const REACH_M := 2.6
## Walk this far away and the next approach finds a clean sheet.
const AWAY_M := 5.0
const BARK := Color(0.8, 0.75, 0.64)
const OAK := Color(0.42, 0.29, 0.17)

var at := Vector3.ZERO
var face := 0.0
var burned := false
var was := false
var board: Label3D
var back: MeshInstance3D


## bay: the confession bay of WitnessCore.bays().  The sheet stands at
## the path's edge before the bay, on the walker's side of the line.
static func place(parent: Node3D, bay: Dictionary) -> ConfessionSheet:
	var sheet := ConfessionSheet.new()
	sheet.name = "ConfessionSheet"
	var side: float = bay.side
	sheet.at = Vector3(bay.x - 5.2, 0,
		side * (WitnessCore.PATH_HALF - 0.1))
	# The board faces the path, as the plaques do.
	sheet.face = 0.0 if side < 0.0 else PI
	parent.add_child(sheet)
	sheet._build()
	return sheet


static func text() -> String:
	var lines := ["ЛИСТОК ПОДГОТОВКИ", "", NOT_SACRAMENT, ""]
	for i in QUESTIONS.size():
		lines.append("%d. %s" % [i + 1, QUESTIONS[i]])
	lines += ["", HEADSET_NOTE, "", "(нажми — «%s»)" % BURN]
	return "\n".join(lines)


func _build() -> void:
	var post := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.1, 1.0, 0.1)
	post.mesh = bm
	var oak := StandardMaterial3D.new()
	oak.albedo_color = OAK
	post.material_override = oak
	post.position = at + Vector3(0, 0.5, 0)
	add_child(post)
	back = MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(1.45, 1.35)
	back.mesh = qm
	var bark := StandardMaterial3D.new()
	bark.albedo_color = BARK
	bark.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	back.material_override = bark
	back.position = at + Vector3(0, 1.55, 0)
	back.rotation.y = face
	add_child(back)
	board = Label3D.new()
	board.text = text()
	board.font_size = 26
	board.pixel_size = 0.0017
	board.width = 800
	board.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	board.modulate = Color(0.18, 0.13, 0.09)
	board.outline_size = 0
	board.double_sided = false
	board.position = back.position + Vector3(0, 0, 0.01).rotated(Vector3.UP,
		face)
	board.rotation.y = face
	add_child(board)
	_set_shown(false)


func _set_shown(on: bool) -> void:
	board.visible = on
	back.visible = on


func _pressed() -> bool:
	var down := Input.is_key_pressed(KEY_SPACE) \
		or Input.is_key_pressed(KEY_ENTER)
	var hand = get_parent().get("right_hand")
	if hand is XRController3D:
		down = down or (hand as XRController3D).is_button_pressed(
			"trigger_click")
	return down


func _process(_dt: float) -> void:
	var walker = get_parent().get("pos")
	if not walker is Vector3:
		return
	var d := Vector2(walker.x - at.x, walker.z - at.z).length()
	if d > AWAY_M:
		burned = false
	var near := d <= REACH_M
	var press := _pressed()
	if near and press and not was and board.visible:
		burned = true
	was = press
	_set_shown(near and not burned)
