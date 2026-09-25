extends SceneTree
## Test del generatore. Esegui con:
##   godot --headless -s res://tests/test_generator.gd
## Esce con codice 1 se un test fallisce (così la CI di GitHub lo segnala).

const Gen = preload("res://scripts/dungeon/dungeon_generator.gd")

var _failures := 0


func _init() -> void:
	for s in [1, 42, 1234, 99999, 555555]:
		_test_deterministic(s)
		_test_exit_reachable(s)
		_test_border_is_wall(s)
		_test_items(s)
		_test_short_corridors(s)
		_test_doors(s)
		_test_wall_torches(s)
	print("Test generatore: %s" % ("OK" if _failures == 0 else "%d FALLITI" % _failures))
	quit(1 if _failures > 0 else 0)


func _test_deterministic(s: int) -> void:
	var a := Gen.new()
	var b := Gen.new()
	a.generate(s)
	b.generate(s)
	_check(a.grid == b.grid and a.exit_cell == b.exit_cell, "seed %d: stesso seed, stesso piano" % s)


func _test_exit_reachable(s: int) -> void:
	var g := Gen.new()
	g.generate(s)
	var dist := g.distances_from(g.start_cell)
	var d := dist[g.exit_cell.y * g.width + g.exit_cell.x]
	_check(d > 10, "seed %d: uscita raggiungibile e lontana (distanza %d)" % [s, d])
	_check(g.rooms.size() >= 5, "seed %d: almeno 5 stanze (%d)" % [s, g.rooms.size()])


func _test_border_is_wall(s: int) -> void:
	var g := Gen.new()
	g.generate(s)
	var ok := true
	for x in g.width:
		ok = ok and not g.is_floor(Vector2i(x, 0)) and not g.is_floor(Vector2i(x, g.height - 1))
	for y in g.height:
		ok = ok and not g.is_floor(Vector2i(0, y)) and not g.is_floor(Vector2i(g.width - 1, y))
	_check(ok, "seed %d: bordo della mappa chiuso" % s)


func _test_items(s: int) -> void:
	var a := Gen.new()
	var b := Gen.new()
	a.generate(s)
	b.generate(s)
	a.place_items(4, 1)
	b.place_items(4, 1)
	_check(a.items == b.items, "seed %d: stesso seed, stessi oggetti" % s)
	_check(a.items.size() == 5, "seed %d: tutti gli oggetti piazzati (%d)" % [s, a.items.size()])
	_check(a.items.values().count(&"flint") == 1, "seed %d: un acciarino" % s)
	var dist := a.distances_from(a.start_cell)
	var ok := true
	for c: Vector2i in a.items:
		ok = ok and a.is_floor(c) and c != a.exit_cell and not a.rooms[0].has_point(c)
		ok = ok and dist[c.y * a.width + c.x] > 0
	_check(ok, "seed %d: oggetti raggiungibili, fuori dalla stanza d'ingresso e dall'uscita" % s)


func _test_short_corridors(s: int) -> void:
	var g := Gen.new()
	g.generate(s)
	var dist := g.distances_from(g.start_cell)
	var ok := true
	for i in range(1, g.rooms.size()):
		var c := g.rooms[i].get_center()
		ok = ok and dist[c.y * g.width + c.x] > 0  # tutte le stanze raggiungibili
		var near := false
		for j in g.rooms.size():
			var o := g.rooms[j].get_center()
			near = near or (j != i and absi(o.x - c.x) + absi(o.y - c.y) <= g.max_corridor)
		ok = ok and near
	_check(ok, "seed %d: stanze tutte raggiungibili e vicine ad almeno un'altra" % s)


func _test_doors(s: int) -> void:
	var a := Gen.new()
	var b := Gen.new()
	a.door_chance = 1.0
	b.door_chance = 1.0
	a.generate(s)
	b.generate(s)
	_check(a.doors == b.doors, "seed %d: stesso seed, stesse porte" % s)
	_check(not a.doors.is_empty(), "seed %d: con probabilità 1 ci sono porte" % s)
	var ok := true
	for c: Vector2i in a.doors:
		var step := Vector2i.RIGHT if a.doors[c] else Vector2i.DOWN
		var side := Vector2i(step.y, step.x)
		ok = ok and a.is_floor(c) and a.is_floor(c + step) and a.is_floor(c - step)
		ok = ok and not a.is_floor(c + side) and not a.is_floor(c - side)
		ok = ok and not a.doors.has(c + step) and not a.doors.has(c - step)
	_check(ok, "seed %d: porte solo in strozzature, mai attaccate" % s)
	var none := Gen.new()
	none.door_chance = 0.0
	none.generate(s)
	_check(none.doors.is_empty(), "seed %d: con probabilità 0 nessuna porta" % s)


func _test_wall_torches(s: int) -> void:
	var g := Gen.new()
	g.wall_torch_floor_chance = 1.0
	g.wall_torch_count = Vector2i(3, 3)
	g.generate(s)
	_check(g.wall_torches.size() == 3, "seed %d: 3 torce a muro (%d)" % [s, g.wall_torches.size()])
	var ok := true
	for c: Vector2i in g.wall_torches:
		ok = ok and g.is_floor(c) and not g.is_floor(c + g.wall_torches[c])
		ok = ok and not g.rooms[0].has_point(c)
	_check(ok, "seed %d: torce a muro appoggiate a un muro, fuori dalla stanza d'ingresso" % s)
	var none := Gen.new()
	none.wall_torch_floor_chance = 0.0
	none.generate(s)
	_check(none.wall_torches.is_empty(), "seed %d: piano senza torce a muro" % s)


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		printerr("FALLITO: " + label)
