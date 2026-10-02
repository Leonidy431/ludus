## The felt answer to a step of a place's act (ActCue).  Called from
## run_hub_tests.gd.  Through every act's own states: a wrong step reads
## as "wrong", a step that moves the act as "right", the closing one as
## "done"; every act has a reachable closing step and every act answers
## some wrong step.  The sounds are the same bytes every time, short,
## under their peak, and none of them is silent.
extends RefCounted


func run(t: Object) -> void:
	t._check(ActCue.kind({"done": false, "reply": "", "step": 0},
		{"done": false, "reply": "Сперва посох.", "step": 0}) == "wrong",
		"only the reply changed: a wrong step")
	t._check(ActCue.kind({"done": false, "reply": "", "step": 0},
		{"done": false, "reply": "Лёд держит.", "step": 1}) == "right",
		"the state moved: a right step")
	t._check(ActCue.kind({"done": false, "step": 1},
		{"done": true, "step": 2}) == "done", "the act closed: done")
	t._check(ActCue.kind({"done": false}, {"done": false}) == "",
		"nothing changed: no cue")
	for id in PlaceDeeds.GROUPS:
		_act(t, id)
	for k in ["right", "wrong", "done"]:
		var w := ActCue.wav(k)
		var again := ActCue.samples(k)
		t._check(again == ActCue.samples(k), k + ": the same samples")
		var n := w.data.size() / 2
		t._check(n > 0 and float(n) / ActCue.RATE <= 0.8,
			"%s: short (%.2f s)" % [k, float(n) / ActCue.RATE])
		var peak := 0
		for i in n:
			peak = maxi(peak, absi(w.data.decode_s16(i * 2)))
		var db := 20.0 * log(maxf(peak, 1) / 32767.0) / log(10.0)
		t._check(db <= ActCue.PEAK_DB + 0.1 and db > ActCue.PEAK_DB - 1.0,
			"%s: peak %.1f dBFS at its level, far under -1 dBTP" % [k, db])
		t._check(ActCue.HAPTIC.has(k) and ActCue.HAPTIC[k][0] <= 0.5,
			k + ": a gentle pulse")


func _act(t: Object, id: String) -> void:
	var kinds := {}
	var seen := {}
	var queue := [PlaceDeeds.start(id)]
	while not queue.is_empty() and seen.size() < 400:
		var cur: Dictionary = queue.pop_front()
		for o in PlaceDeeds.options(id, cur):
			if o.get("disabled", false):
				continue
			var nxt := PlaceDeeds.choose(id, cur, str(o.id))
			kinds[ActCue.kind(cur, nxt)] = true
			var key := var_to_str(nxt)
			if not nxt.get("done", false) and not seen.has(key):
				seen[key] = true
				queue.append(nxt)
		var waited := PlaceDeeds.tick(id, cur, 600.0, true)
		kinds[ActCue.kind(cur, waited)] = true
	t._check(kinds.has("done"), id + ": the closing step reads as done")
	t._check(kinds.has("wrong"), id + ": some wrong step answers as wrong")
