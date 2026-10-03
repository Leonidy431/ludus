## The fallback font for the few symbols the built-in OpenSans lacks
## (arrows, the skip gauge's bars): godot/fonts/ludus-fallback.ttf, a
## subset of DejaVu Sans made by scripts/godot/check_glyphs.py --build,
## which also fails CI if any character the game shows has no glyph.
## Without it those characters are empty boxes ("tofu") in the Web
## build, which has no system fallback, and perhaps in Quest.
##
## Constitution: FORM (each letter the player reads) -> ACTION (the
## default font learns the missing symbols once, at the first scene) ->
## GOAL (no word of the game is broken into boxes).
class_name Glyphs
extends RefCounted

const FALLBACK := "res://fonts/ludus-fallback.ttf"


## Add the fallback to the engine's default font, once a run; returns
## whether it is there.  Label3D and Control both draw with that font.
static func install() -> bool:
	var base := ThemeDB.fallback_font
	if base == null or not ResourceLoader.exists(FALLBACK):
		return false
	var fb: Array[Font] = base.fallbacks
	for f in fb:
		if f.resource_path == FALLBACK:
			return true
	fb.append(load(FALLBACK))
	base.fallbacks = fb
	return true
