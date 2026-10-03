## The Brotherhood's chat rules (docs/HLD_BROTHERHOOD_CHAT_2026-10-03.md,
## TABOO 0.031): a team chat, like the one in Counter-Strike, for the
## players of one organisation.  Short words and ready radio phrases;
## no outside messengers, no voice, no rewards for talking.
##
## This is the rules only, with no network and no disk: the core decides
## who may speak in which channel, cleans what is said and says what the
## player sees.  It never writes a file or opens a socket, and a test
## reads this very script to prove it.  A transport (phase C2) hands it
## messages; the server (C3) is a module of its own.
##
## Constitution: FORM (a role in the Brotherhood and the circle he stands
## in) -> ACTION (say a short word to his own, or press a ready phrase)
## -> GOAL (VI.5 local nodes of trust, VI.11 "how are you?": people in
## one work hear each other, and the holy stays a silence).
class_name ChatCore
extends RefCounted

const PATH := "res://data/brotherhood-chat.json"


## The chat data, or an empty Dictionary if the file is missing.
static func load_data(path := PATH) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var data = JSON.parse_string(f.get_as_text())
	return data if data is Dictionary else {}


## May `role` speak in `channel` now?  `ctx` carries `holy` (the player
## stands at the kayrak or a sacrament: the chat is silent), `muted`,
## `last_sent_s` and `now_s` (seconds), `depth_m` and `artel_size`.
## Returns {"ok": bool, "why": String}; the reason is always named.
static func can_send(data: Dictionary, channel: String, role: String,
		ctx: Dictionary) -> Dictionary:
	var ch: Dictionary = data.get("channels", {}).get(channel, {})
	if ch.is_empty():
		return _no("no_such_channel")
	if ctx.get("holy", false):
		return _no("holy_silence")
	if ctx.get("muted", false):
		return _no("muted")
	if not role in ch.get("who", []):
		return _no("not_a_member")
	if channel == "artel" and int(ctx.get("artel_size", 0)) \
			> int(data.limits.artel_cap):
		return _no("artel_over_cap")
	var gap := pause_s(data, float(ctx.get("depth_m", 0.0)))
	if float(ctx.get("now_s", 0.0)) - float(ctx.get("last_sent_s", -1000.0)) \
			< gap:
		return _no("too_soon")
	return {"ok": true, "why": ""}


## The pause between two messages: the base interval, longer the deeper
## he is (VI.1: under water the low frequencies carry only short, rare
## words).  Deterministic, no randomness.
static func pause_s(data: Dictionary, depth_m: float) -> float:
	var lim: Dictionary = data.limits
	return float(lim.min_interval_s) + floorf(maxf(depth_m, 0.0) / 10.0) \
		* float(lim.depth_pause_per_10m_s)


## What is left of a free text once it is safe to send: control
## characters gone, spaces collapsed, cut to the limit, and an empty
## string if it carries a way out of the game (a link, an address, a
## messenger's name, a phone number).
static func clean(data: Dictionary, text: String) -> String:
	var t := ""
	for i in text.length():
		var c := text.unicode_at(i)
		t += " " if c < 32 or c == 127 else text[i]
	t = " ".join(t.split(" ", false)).strip_edges()
	var low := t.to_lower()
	for p in data.get("contact_patterns", []):
		if low.contains(str(p)):
			return ""
	var run := 0
	for i in t.length():
		var c := t.unicode_at(i)
		run = run + 1 if c >= 48 and c <= 57 else 0
		if run >= 7:
			return ""
	return t.substr(0, int(data.limits.max_len))


## The ready phrase `id`: {"id", "ru", "en", "meaning"} or empty.
static func phrase(data: Dictionary, id: String) -> Dictionary:
	for p in data.get("phrases", []):
		if p.id == id:
			return p
	return {}


## What the receiver sees of a message: nothing if he stands at the holy
## or has blocked the sender, otherwise the text.
static func visible(msg: Dictionary, receiver: Dictionary) -> String:
	if receiver.get("holy", false):
		return ""
	if msg.get("from", "") in receiver.get("blocked", []):
		return ""
	return str(msg.get("text", ""))


## A refusal that always names its reason.
static func _no(why: String) -> Dictionary:
	return {"ok": false, "why": why}
