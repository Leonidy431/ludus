## Group e of the small acts at the hearts of places (PlaceDeeds; the
## contract is written at the top of place_deeds.gd).  Until its acts
## are written this group owns none, and their hearts keep the old panel.
extends RefCounted


static func ids() -> Array:
	return []


static func start(_id: String) -> Dictionary:
	return {"done": false, "reply": ""}


static func lines(_id: String, _s: Dictionary) -> Array:
	return []


static func options(_id: String, _s: Dictionary) -> Array:
	return []


static func choose(_id: String, s: Dictionary, _c: String) -> Dictionary:
	return s


static func tick(_id: String, s: Dictionary, _dt: float,
		_still: bool) -> Dictionary:
	return s
