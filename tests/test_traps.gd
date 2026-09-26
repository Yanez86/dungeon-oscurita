extends SceneTree
## Test della disposizione delle trappole (TrapLayout, solo dati). Esegui con:
##   godot --headless -s res://tests/test_traps.gd
## Esce con codice 1 se un test fallisce.

const Gen = preload("res://scripts/dungeon/dungeon_generator.gd")
const Layout = preload("res://scripts/dungeon/trap_layout.gd")

var _failures := 0


func _init() -> void:
	for s in [1, 42, 1234, 99999, 555555]:
		_test_deterministic(s)
		for floor_number in [1, 3, 6]:
			_test_rules(s, floor_number)
	_test_counts_and_kinds()
	_test_boulders_exist()
	print("Test trappole: %s" % ("OK" if _failures == 0 else "%d FALLITI" % _failures))
	quit(1 if _failures > 0 else 0)


## Un piano completo come lo prepara il builder, con le trappole del piano `floor_number`.
func _layout(s: int, floor_number: int) -> Layout:
	var g := Gen.new()
	g.generate(s)
	g.place_items(4, 1)
	g.place_decorations()
	g.place_enemies(2)
	var l := Layout.new()
	l.plan(g, s, floor_number)
	return l


func _describe(l: Layout) -> String:
	var out := ""
	for t in l.traps:
		out += "%s%s%s%s " % [t.kind, t.cell, t.start, t.end]
	return out + str(l.door_traps) + str(l.ropes)


func _test_deterministic(s: int) -> void:
	var a := _layout(s, 5)
	var b := _layout(s, 5)
	_check(_describe(a) == _describe(b), "seed %d: stesso seed, stesse trappole" % s)
	var g := Gen.new()
	g.generate(s)
	var before := g.grid.duplicate()
	var l := Layout.new()
	l.plan(g, s, 5)
	_check(g.grid == before, "seed %d: le trappole non cambiano la mappa" % s)


func _test_rules(s: int, floor_number: int) -> void:
	var l := _layout(s, floor_number)
	var g := l._gen
	var start_zone := g.rooms[0].grow(l.start_margin)
	var ok := true
	var spaced := true
	for t in l.traps:
		var c := t.cell
		ok = ok and g.is_floor(c) and not start_zone.has_point(c) and c != g.exit_cell
		ok = ok and not g.items.has(c) and not g.decorations.has(c) and not g.doors.has(c) and not g.enemies.has(c)
		ok = ok and floor_number >= l.min_floor[t.kind]
		for o in l.traps:
			if o != t and absi(o.cell.x - c.x) <= 1 and absi(o.cell.y - c.y) <= 1:
				spaced = false
	_check(ok, "seed %d piano %d: inneschi su pavimento libero, lontani dall'ingresso" % [s, floor_number])
	_check(spaced, "seed %d piano %d: mai due trappole attaccate" % [s, floor_number])

	for t in l.traps:
		match t.kind:
			Layout.TRAPDOOR:
				_check(_in_room(g, t.cell), "seed %d piano %d: botola in una stanza %s" % [s, floor_number, t.cell])
			Layout.VENT:
				var side := Vector2i(t.dir.y, t.dir.x)
				_check(t.dir != Vector2i.ZERO and g.is_floor(t.cell + t.dir) and g.is_floor(t.cell - t.dir)
					and not g.is_floor(t.cell + side) and not g.is_floor(t.cell - side),
					"seed %d piano %d: soffio in un corridoio dritto, grate nei muri %s" % [s, floor_number, t.cell])
			Layout.BOULDER:
				_check_boulder(l, t, "seed %d piano %d" % [s, floor_number])

	# Con le botole aperte e gli arredi come ostacoli, tutto il resto resta raggiungibile.
	var pits := l.pit_cells()
	var seen := {g.start_cell: true}
	var queue: Array[Vector2i] = [g.start_cell]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in Gen.SIDES:
			var n := c + d
			if g.is_floor(n) and not g.decorations.has(n) and not pits.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	var open := 0
	for y in g.height:
		for x in g.width:
			var c := Vector2i(x, y)
			open += int(g.is_floor(c) and not g.decorations.has(c) and not pits.has(c))
	_check(seen.size() == open, "seed %d piano %d: le botole non chiudono passaggi (%d/%d)" % [s, floor_number, seen.size(), open])

	for c in l.door_traps:
		_check(g.doors.has(c) and floor_number >= l.door_trap_min_floor,
			"seed %d piano %d: trappole solo sulle porte, dal piano %d" % [s, floor_number, l.door_trap_min_floor])
	var ropes_ok := l.ropes.size() == (l.ropes_per_floor if floor_number >= l.ropes_min_floor else 0)
	for c in l.ropes:
		ropes_ok = ropes_ok and g.is_floor(c) and not g.items.has(c) and not g.decorations.has(c) \
			and not pits.has(c) and l.trap_at(c) == null and not g.rooms[0].has_point(c)
	_check(ropes_ok, "seed %d piano %d: corde a terra dal piano %d, su celle libere" % [s, floor_number, l.ropes_min_floor])


## Masso: muro alle spalle, percorso dritto su pavimento senza porte, arredi né altre trappole,
## filo in un corridoio a poche celle dalla caduta.
func _check_boulder(l: Layout, t: Layout.Spot, label: String) -> void:
	var g := l._gen
	var ok := not g.is_floor(t.start - t.dir)
	var cells := 1
	var c := t.start
	var wire_on_path := false
	while c != t.end and cells < 100:
		ok = ok and g.is_floor(c) and not g.doors.has(c) and not g.decorations.has(c)
		for o in l.traps:
			ok = ok and (o == t or o.cell != c)
		wire_on_path = wire_on_path or c == t.cell
		c += t.dir
		cells += 1
	var after := t.end + t.dir
	ok = ok and (not g.is_floor(after) or g.doors.has(after) or g.decorations.has(after))
	var k := (t.cell - t.start).length()
	_check(ok and wire_on_path and cells >= l.boulder_min_run
		and k >= l.boulder_wire_distance.x and k <= l.boulder_wire_distance.y and not _in_room(g, t.cell),
		"%s: percorso del masso valido (%s -> %s, filo %s)" % [label, t.start, t.end, t.cell])


func _test_counts_and_kinds() -> void:
	var l := Layout.new()
	_check(l.count_for_floor(1) == 2 and l.count_for_floor(3) == 4 and l.count_for_floor(20) == l.max_count,
		"numero di trappole: 2 al piano 1, una in più a piano, al massimo %d" % l.max_count)
	var placed := 0
	var asked := 0
	var first_floor_deadly := 0
	for s in range(1, 41):
		for floor_number in [1, 4]:
			var lay := _layout(s, floor_number)
			placed += lay.traps.size()
			asked += lay.count_for_floor(floor_number)
			if floor_number == 1:
				for t in lay.traps:
					first_floor_deadly += int(t.kind in [Layout.TRAPDOOR, Layout.BOULDER, Layout.CAGE])
				first_floor_deadly += lay.door_traps.size()
	_check(placed >= asked * 0.9, "40 seed: piazzate quasi tutte le trappole richieste (%d/%d)" % [placed, asked])
	_check(first_floor_deadly == 0, "piano 1: solo frecce e soffio, niente porte trappolate (%d)" % first_floor_deadly)


## Su tanti piani profondi il masso trova posto spesso (servono corridoi dritti).
func _test_boulders_exist() -> void:
	var with_boulder := 0
	for s in range(1, 31):
		var l := Layout.new()
		var g := Gen.new()
		g.generate(s)
		g.place_items(4, 1)
		g.place_decorations()
		l.weights = {Layout.BOULDER: 1.0}
		l.plan(g, s, 6)
		for t in l.traps:
			if t.kind == Layout.BOULDER:
				with_boulder += 1
				_check_boulder(l, t, "seed %d solo massi" % s)
				break
	_check(with_boulder >= 20, "30 seed: il masso trova un corridoio dritto quasi sempre (%d)" % with_boulder)


func _in_room(g: Gen, c: Vector2i) -> bool:
	for r in g.rooms:
		if r.has_point(c):
			return true
	return false


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		printerr("FALLITO: " + label)
