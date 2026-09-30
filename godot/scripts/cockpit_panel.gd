## The pilot's console drawn as the operator's BlueOS panels: a row of
## dark cards with a muted title, a large value in the state colour and
## a muted line under it (third_party/mangustik/panels/yacht-blueos
## vessel-dashboard, diveguard ThreatIndicator).  The words and states
## come from CockpitCore; this node only draws them.
class_name CockpitPanel
extends HBoxContainer

const CARD_SIZE := Vector2(168, 104)

var _cards: Array = []


func _init() -> void:
	add_theme_constant_override("separation", 8)
	for i in 7:
		_cards.append(_make_card())


func _make_card() -> Dictionary:
	var box := PanelContainer.new()
	box.custom_minimum_size = CARD_SIZE
	var style := StyleBoxFlat.new()
	style.bg_color = CockpitCore.CARD
	style.border_color = CockpitCore.BORDER
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	box.add_theme_stylebox_override("panel", style)
	add_child(box)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	box.add_child(column)
	var labels := {}
	for part in ["title", "value", "sub"]:
		var l := Label.new()
		l.add_theme_font_size_override("font_size",
			30 if part == "value" else 15)
		l.add_theme_color_override("font_color", CockpitCore.MUTED)
		l.clip_text = true
		column.add_child(l)
		labels[part] = l
	return {"style": style, "labels": labels}


## Show the cards from CockpitCore.cards().
func show_cards(cards: Array) -> void:
	for i in mini(cards.size(), _cards.size()):
		var c: Dictionary = cards[i]
		var view: Dictionary = _cards[i]
		view.labels.title.text = c.title
		view.labels.value.text = c.value
		view.labels.sub.text = c.sub
		var colour: Color = CockpitCore.STATE_COLOUR[c.state]
		view.labels.value.add_theme_color_override("font_color", colour)
		# A warning also colours the card's frame, as the BlueOS alert
		# cards do; a calm card keeps the quiet border.
		view.style.border_color = colour if c.state in ["warn",
			"critical"] else CockpitCore.BORDER
