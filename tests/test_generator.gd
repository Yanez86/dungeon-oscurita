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


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		printerr("FALLITO: " + label)
