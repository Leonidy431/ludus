## The Brotherhood's chat rules (TABOO 0.031, docs/HLD_BROTHERHOOD_CHAT_
## 2026-10-03.md): channels by role, silence at the holy, a clean text,
## a pause that grows with depth, and a core that touches neither disk
## nor network.
extends RefCounted


func run(t: Object) -> void:
	var d := ChatCore.load_data()
	t._check(d.get("channels", {}).size() == 3, "three channels: artel, "
		+ "circle, pier")
	var ok := {"now_s": 100.0, "last_sent_s": 0.0}
	t._check(ChatCore.can_send(d, "artel", "master", ok).ok,
		"a master speaks in his artel")
	t._check(ChatCore.can_send(d, "circle", "master", ok).why
		== "not_a_member", "the inner circle is for curators only")
	t._check(ChatCore.can_send(d, "circle", "curator", ok).ok,
		"a curator speaks in the inner circle")
	t._check(ChatCore.can_send(d, "artel", "guest", ok).why
		== "not_a_member", "a guest has no artel")
	t._check(ChatCore.can_send(d, "pier", "guest", ok).ok,
		"a guest may speak on the pier")
	t._check(ChatCore.can_send(d, "nowhere", "master", ok).why
		== "no_such_channel", "an unknown channel is named")
	var holy := ok.duplicate()
	holy["holy"] = true
	t._check(ChatCore.can_send(d, "pier", "curator", holy).why
		== "holy_silence", "the chat is silent at the holy")
	t._check(ChatCore.visible({"from": "a", "text": "hi"},
		{"holy": true}) == "", "nothing is shown at the holy")
	t._check(ChatCore.visible({"from": "a", "text": "hi"},
		{"blocked": ["a"]}) == "", "a blocked sender is not shown")
	t._check(ChatCore.visible({"from": "a", "text": "hi"}, {}) == "hi",
		"an ordinary message is shown")
	var mute := ok.duplicate()
	mute["muted"] = true
	t._check(ChatCore.can_send(d, "pier", "master", mute).why == "muted",
		"a muted player is named muted")
	var big := ok.duplicate()
	big["artel_size"] = 257
	t._check(ChatCore.can_send(d, "artel", "master", big).why
		== "artel_over_cap", "an artel is at most 256")
	var soon := {"now_s": 1.0, "last_sent_s": 0.0}
	t._check(ChatCore.can_send(d, "pier", "master", soon).why == "too_soon",
		"not more often than every 1.5 s")
	t._check(ChatCore.pause_s(d, 0.0) == 1.5
		and ChatCore.pause_s(d, 60.0) == 4.5,
		"the pause grows 0.5 s per ten metres of depth: %s %s" % [
			ChatCore.pause_s(d, 0.0), ChatCore.pause_s(d, 60.0)])
	t._check(ChatCore.clean(d, "  Иду   к\tбую \n ") == "Иду к бую",
		"spaces and control characters collapse")
	for bad in ["пиши мне в telegram", "вот http://x.y", "почта a@b.c",
			"звони 89001234567", "мой vk.com/me"]:
		t._check(ChatCore.clean(d, bad) == "",
			"a way out of the game is dropped: %s" % bad)
	t._check(ChatCore.clean(d, "a".repeat(500)).length() == 200,
		"a text is cut to 200 signs")
	t._check(d.get("phrases", []).size() >= 8, "the radio phrases exist")
	for p in d.get("phrases", []):
		t._check(str(p.get("meaning", "")) != "" and p.ru.length() >= 3
			and p.ru.length() <= 30,
			"phrase %s has a meaning and a short text" % p.id)
	t._check(ChatCore.phrase(d, "how").ru == "Как ты?", "'how are you?' is "
		+ "the base phrase of every channel")
	# The core must not reach for a disk or a network (TABOO 0.018, 0.26).
	var src := FileAccess.get_file_as_string("res://scripts/chat_core.gd")
	var code := ""
	for line in src.split("\n"):
		if not line.strip_edges().begins_with("##"):
			code += line + "\n"
	for forbidden in ["FileAccess.open(", "HTTPRequest", "HTTPClient",
			"WebSocket", "StreamPeer", "PacketPeer", "OS.execute",
			"store_", "ConfigFile"]:
		var allowed: bool = forbidden == "FileAccess.open(" \
			and code.count("FileAccess.open(") == 1
		t._check(allowed or not code.contains(forbidden),
			"the chat core does not use %s" % forbidden)
