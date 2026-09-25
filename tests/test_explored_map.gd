extends SceneTree
## Test della mappa esplorata. Esegui con:
##   godot --headless -s res://tests/test_explored_map.gd
## Esce con codice 1 se un test fallisce.

const Gen = preload("res://scripts/dungeon/dungeon_generator.gd")
const Explored = preload("res://scripts/dungeon/explored_map.gd")

var _failures := 0


func _init() -> void:
	_test_wall_blocks_sight()
	_test_corner_blocks_diagonal()
	_test_no_light_no_map()
	_test_closed_door_blocks_sight()
	for s in [1, 42, 1234]:
		_test_real_floor(s)
	print("Test mappa esplorata: %s" % ("OK" if _failures == 0 else "%d FALLITI" % _failures))
	quit(1 if _failures > 0 else 0)


## Piano fatto a mano: 1 = pavimento, tutto il resto muro.
func _make(rows: Array[String]) -> Gen:
	var g := Gen.new(rows[0].length(), rows.size())
	g.grid.resize(g.width * g.height)
	g.grid.fill(Gen.Cell.WALL)
	for y in rows.size():
		for x in rows[y].length():
			if rows[y][x] == "1":
				g.grid[y * g.width + x] = Gen.Cell.FLOOR
	return g


## Due stanze divise da un muro pieno: dall'una non si vede l'altra.
func _test_wall_blocks_sight() -> void:
	var g := _make([
		"000000000",
		"011101110",
		"011101110",
		"011101110",
		"000000000",
	])
	var m := Explored.new(g)
	m.reveal(Vector2i(2, 2), 8.0)
	_check(m.is_seen(Vector2i(2, 2)), "la propria cella è vista")
	_check(m.is_seen(Vector2i(3, 2)), "il pavimento vicino è visto")
	_check(m.is_seen(Vector2i(4, 2)), "il muro che separa è visto")
	_check(not m.is_seen(Vector2i(6, 2)), "la stanza dietro il muro non è vista")


## Due muri in diagonale formano uno spigolo: non ci si vede attraverso.
func _test_corner_blocks_diagonal() -> void:
	var g := _make([
		"0000",
		"0100",
		"0010",
		"0000",
	])
	var m := Explored.new(g)
	_check(not m.has_line_of_sight(Vector2i(1, 1), Vector2i(3, 3)), "niente vista tra due muri in diagonale")


## Due stanze unite da un corridoio con una porta: chiusa ferma la vista, aperta no.
func _test_closed_door_blocks_sight() -> void:
	var g := _make([
		"000000000",
		"011101110",
		"011111110",
		"011101110",
		"000000000",
	])
	var door := Vector2i(4, 2)
	g.doors[door] = true
	var m := Explored.new(g)
	m.reveal(Vector2i(2, 2), 8.0)
	_check(m.is_seen(door), "la porta chiusa si vede")
	_check(not m.is_seen(Vector2i(6, 2)), "oltre la porta chiusa non si vede")
	m.open_door(door)
	m.reveal(Vector2i(2, 2), 8.0)
	_check(m.is_seen(Vector2i(6, 2)), "aperta la porta, si vede oltre")
	m.close_door(door)
	_check(m.is_seen(Vector2i(6, 2)), "richiusa la porta, ciò che si era visto resta sulla mappa")
	_check(not m.has_line_of_sight(Vector2i(2, 2), Vector2i(6, 2)), "richiusa la porta, la vista si ferma di nuovo")


## Torcia spenta: raggio 0, non si scopre niente.
func _test_no_light_no_map() -> void:
	var g := Gen.new()
	g.generate(7)
	var m := Explored.new(g)
	_check(m.reveal(g.start_cell, 0.0).is_empty(), "al buio non si scopre nulla")


## Piano vero: tutto ciò che si scopre è entro il raggio, e una seconda
## chiamata dallo stesso punto non restituisce celle nuove.
func _test_real_floor(s: int) -> void:
	var g := Gen.new()
	g.generate(s)
	var m := Explored.new(g)
	var radius := 4.5
	var first := m.reveal(g.start_cell, radius)
	var ok := not first.is_empty()
	for c in first:
		ok = ok and Vector2(c - g.start_cell).length() <= radius
	_check(ok, "seed %d: celle scoperte entro il raggio (%d)" % [s, first.size()])
	_check(m.reveal(g.start_cell, radius).is_empty(), "seed %d: nessuna cella scoperta due volte" % s)
	_check(not m.is_seen(g.exit_cell), "seed %d: l'uscita lontana non è vista all'inizio" % s)


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		printerr("FALLITO: " + label)
