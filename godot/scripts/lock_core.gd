## Locks opened by a calm match-three board (CLAUDE.md TABOO 0.024):
## safes, code locks, the gateway of the pult and the server of the
## robot's code.  The board is made of the lock's own parts (pins and
## springs, packets and keys), so the puzzle teaches how the lock works.
## docs/HLD_LOCK_MATCH3_2026-10-02.md; godot/data/locks.json.
##
## The genre, not another game: nothing of Homescapes or Gardenscapes
## (names, butler, art, levels) is taken.  And unlike them nothing here
## is random: the board and every tile that falls in come from the
## lock's seed (an xorshift stream), so the same moves give the same
## board every time (Constitution).  No timer, no lives, no money, no
## loss: when no move is left the board turns over by a fixed rule.
class_name LockCore
extends RefCounted

const DATA := "res://data/locks.json"
## Words of the pressure economy that a lock must never carry.
const PRESSURE := ["таймер", "жизн", "энерги", "купить", "платн", "буст",
	"реклам", "лутбокс", "timer", "lives", "energy", "buy", "booster",
	"homescapes", "gardenscapes", "playrix", "остин"]


static func load_data() -> Dictionary:
	var d = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	return d if d is Dictionary else {}


static func lock_of(data: Dictionary, id: String) -> Dictionary:
	for l in data.locks:
		if l.id == id:
			return l
	return {}


## FNV-1a over the lock's id: the same id, the same seed, on every
## device (String.hash is not promised to stay the same across builds).
static func seed_of(id: String) -> int:
	var h := 2166136261
	for b in id.to_utf8_buffer():
		h = ((h ^ b) * 16777619) & 0xFFFFFFFF
	return h if h != 0 else 1


static func _next(st: Dictionary) -> int:
	var x: int = st.rng
	x ^= (x << 13) & 0xFFFFFFFF
	x ^= x >> 17
	x ^= (x << 5) & 0xFFFFFFFF
	x &= 0xFFFFFFFF
	st.rng = x if x != 0 else 1
	return st.rng


static func _tile(st: Dictionary, kinds: int) -> int:
	return _next(st) % kinds


static func start(data: Dictionary, id: String) -> Dictionary:
	var l := lock_of(data, id)
	var w := int(data.width)
	var h := int(data.height)
	var kinds: int = l.tiles.size()
	var st := {"id": id, "w": w, "h": h, "kinds": kinds,
		"rng": seed_of(id), "board": [], "cleared": {}, "moves": 0,
		"open": false, "turns": 0}
	for k in l.tiles:
		st.cleared[k] = 0
	var b: Array = []
	b.resize(w * h)
	for y in h:
		for x in w:
			var t := _tile(st, kinds)
			# No match at the start: step through the kinds until the
			# tile does not make three with its left or upper pair.
			for _i in kinds:
				var row: bool = x >= 2 and b[y * w + x - 1] == t \
					and b[y * w + x - 2] == t
				var col: bool = y >= 2 and b[(y - 1) * w + x] == t \
					and b[(y - 2) * w + x] == t
				if not row and not col:
					break
				t = (t + 1) % kinds
			b[y * w + x] = t
	st.board = b
	if find_move(st).is_empty():
		_turn(st)
	return st


## Cells in a run of three or more, in a row or a column.
static func matches(st: Dictionary) -> Array:
	var w: int = st.w
	var h: int = st.h
	var b: Array = st.board
	var hit := {}
	for y in h:
		var x := 0
		while x < w:
			var e := x
			while e + 1 < w and b[y * w + e + 1] == b[y * w + x] \
					and b[y * w + x] >= 0:
				e += 1
			if e - x >= 2:
				for k in range(x, e + 1):
					hit[y * w + k] = true
			x = e + 1
	for x in w:
		var y := 0
		while y < h:
			var e := y
			while e + 1 < h and b[(e + 1) * w + x] == b[y * w + x] \
					and b[y * w + x] >= 0:
				e += 1
			if e - y >= 2:
				for k in range(y, e + 1):
					hit[k * w + x] = true
			y = e + 1
	var out := hit.keys()
	out.sort()
	return out


static func _adjacent(st: Dictionary, a: int, c: int) -> bool:
	var w: int = st.w
	if a < 0 or c < 0 or a >= st.board.size() or c >= st.board.size():
		return false
	var dx := absi(a % w - c % w)
	var dy := absi(a / w - c / w)
	return dx + dy == 1


## The first swap (in board order) that makes a match, or [].
static func find_move(st: Dictionary) -> Array:
	var w: int = st.w
	var n: int = st.board.size()
	for a in n:
		for c in [a + 1, a + w]:
			if c >= n or not _adjacent(st, a, c):
				continue
			var t := st.duplicate(true)
			var tmp = t.board[a]
			t.board[a] = t.board[c]
			t.board[c] = tmp
			if not matches(t).is_empty():
				return [a, c]
	return []


## The board turns over by a fixed rule when no move is left: rotated a
## quarter, then re-coloured one step, until a move exists.  No charge.
static func _turn(st: Dictionary) -> void:
	for _i in 8:
		var w: int = st.w
		var h: int = st.h
		var nb: Array = []
		nb.resize(w * h)
		for y in h:
			for x in w:
				nb[x * w + (w - 1 - y)] = (int(st.board[y * w + x]) + 1) \
					% int(st.kinds)
		st.board = nb
		st.turns = int(st.turns) + 1
		if matches(st).is_empty() and not find_move(st).is_empty():
			return


## A swap of two neighbours.  If it makes no match nothing changes (no
## move is spent).  Else the runs clear, count toward the goal, tiles
## fall and new ones come from the lock's stream, cascades resolve.
static func swap(data: Dictionary, st: Dictionary, a: int, c: int) \
		-> Dictionary:
	var s := st.duplicate(true)
	if s.open or not _adjacent(s, a, c):
		return s
	var tmp = s.board[a]
	s.board[a] = s.board[c]
	s.board[c] = tmp
	if matches(s).is_empty():
		return st.duplicate(true)
	s.moves = int(s.moves) + 1
	var l := lock_of(data, s.id)
	var w: int = s.w
	var h: int = s.h
	var guard := 0
	while guard < 50:
		guard += 1
		var hit := matches(s)
		if hit.is_empty():
			break
		for i in hit:
			var k: String = l.tiles[int(s.board[i])]
			s.cleared[k] = int(s.cleared[k]) + 1
			s.board[i] = -1
		for x in w:
			var col: Array = []
			for y in range(h - 1, -1, -1):
				if int(s.board[y * w + x]) >= 0:
					col.append(s.board[y * w + x])
			for y in range(h - 1, -1, -1):
				var idx := h - 1 - y
				s.board[y * w + x] = col[idx] if idx < col.size() \
					else _tile(s, int(s.kinds))
	var done := true
	for k in l.goal:
		if int(s.cleared[k]) < int(l.goal[k]):
			done = false
	s.open = done
	if not s.open and find_move(s).is_empty():
		_turn(s)
	return s


static func check(data: Dictionary) -> Array:
	var bad := []
	for l in data.get("locks", []):
		# What the player reads: no pressure economy, no foreign brand.
		var text := " ".join([str(l.name_ru), " ".join(l.tiles_ru),
			str(l.teaches_ru), str(l.opens_ru), str(l.whose_ru)]).to_lower()
		for w in PRESSURE:
			if w in text:
				bad.append("%s: «%s» in what the player reads" % [l.id, w])
		if l.get("holy", true):
			bad.append("%s: the holy is never a lock" % l.id)
		if l.tiles.size() < 4 or l.tiles.size() != l.tiles_ru.size():
			bad.append("%s: tiles" % l.id)
		for k in l.goal:
			if not k in l.tiles:
				bad.append("%s: goal %s is not a tile" % [l.id, k])
		for f in ["teaches_ru", "opens_ru", "whose_ru"]:
			if str(l.get(f, "")) == "":
				bad.append("%s: no %s" % [l.id, f])
	return bad
