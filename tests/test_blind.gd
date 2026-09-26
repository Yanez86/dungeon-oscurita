extends SceneTree
## Test del Cieco: il cervello (BlindBrain) e la mappa dei passaggi (DungeonNav). Esegui con:
##   godot --headless -s res://tests/test_blind.gd
## Esce con codice 1 se un test fallisce.

const Gen = preload("res://scripts/dungeon/dungeon_generator.gd")
const Nav = preload("res://scripts/dungeon/dungeon_nav.gd")
const Brain = preload("res://scripts/enemies/blind_brain.gd")

const DOOR := Vector2i(5, 3)

var _failures := 0


func _init() -> void:
	_test_route_and_doors()
	_test_reachable()
	_test_sound_distance()
	_test_hearing()
	_test_wander()
	_test_investigate_and_search()
	_test_scratch()
	_test_recoil()
	_test_trap()
	_test_stuck()
	print("Test Cieco: %s" % ("OK" if _failures == 0 else "%d FALLITI" % _failures))
	quit(1 if _failures > 0 else 0)


## Due stanze 3x5 unite da un corridoio con una porta:
## ############
## #...####...#
## #...####...#
## #....D.....#
## #...####...#
## #...####...#
## ############
func _map() -> Gen:
	var g := Gen.new(12, 7)
	g.grid.resize(g.width * g.height)
	g.grid.fill(Gen.Cell.WALL)
	for y in range(1, 6):
		for x in [1, 2, 3, 8, 9, 10]:
			g.grid[y * g.width + x] = Gen.Cell.FLOOR
	for x in range(4, 8):
		g.grid[3 * g.width + x] = Gen.Cell.FLOOR
	g.doors[DOOR] = true
	return g


func _test_route_and_doors() -> void:
	var g := _map()
	g.decorations[Vector2i(2, 3)] = &"barrel"  # tra la partenza e il corridoio: si gira attorno
	var nav := Nav.new(g)
	_check(nav.is_door_closed(DOOR) and not nav.is_walkable(DOOR), "le porte partono chiuse")
	_check(not nav.is_walkable(Vector2i(2, 3)), "gli arredi non si attraversano")

	var r := nav.route(Vector2i(1, 3), Vector2i(9, 3))
	_check(r.blocked_door and not r.cells.is_empty() and r.cells[-1] == Vector2i(4, 3),
		"porta chiusa: la strada si ferma davanti alla porta (%s)" % [r.cells])
	_check(not r.cells.has(Vector2i(2, 3)), "la strada evita l'arredo")

	var changes := [0]
	nav.passage_changed.connect(func(_c: Vector2i, _open: bool) -> void: changes[0] += 1)
	nav.set_door(DOOR, true)
	nav.set_door(DOOR, true)
	_check(changes[0] == 1, "passage_changed solo quando la porta cambia (%d)" % changes[0])
	r = nav.route(Vector2i(1, 3), Vector2i(9, 3))
	_check(not r.blocked_door and r.cells[-1] == Vector2i(9, 3) and r.cells.has(DOOR), "porta aperta: si passa")
	_check(not r.cells.has(Vector2i(1, 3)), "la cella di partenza non è nella strada")

	r = nav.route(Vector2i(1, 3), Vector2i(1, 3))
	_check(r.cells.is_empty() and not r.blocked_door, "già arrivato: strada vuota")
	r = nav.route(Vector2i(2, 3), Vector2i(1, 1))
	_check(not r.cells.is_empty() and r.cells[-1] == Vector2i(1, 1), "si parte anche da sopra un arredo")
	r = nav.route(Vector2i(1, 1), Vector2i(0, 3))
	_check(not r.cells.is_empty() and r.cells[-1] == nav.nearest_walkable(Vector2i(0, 3)),
		"meta dentro un muro: la cella percorribile più vicina")


func _test_reachable() -> void:
	var nav := Nav.new(_map())
	var cells := nav.reachable_cells(Vector2i(2, 3), 0, 99)
	var in_other_room := false
	for c in cells:
		in_other_room = in_other_room or c.x >= 6
	_check(cells.size() == 16 and not in_other_room, "porta chiusa: raggiungibili la stanza e il corridoio fino alla porta (%d)" % cells.size())
	var near := nav.reachable_cells(Vector2i(2, 3), 2, 2)
	var ok := not near.is_empty()
	for c in near:
		ok = ok and absi(c.x - 2) + absi(c.y - 3) == 2
	_check(ok, "reachable_cells rispetta i passi minimi e massimi")

	var a := RandomNumberGenerator.new()
	var b := RandomNumberGenerator.new()
	a.seed = 7
	b.seed = 7
	ok = true
	for i in 20:
		var pick := nav.random_cell(Vector2i(2, 3), a, 1, 10)
		ok = ok and cells.has(pick) and pick == nav.random_cell(Vector2i(2, 3), b, 1, 10)
	_check(ok, "le mete a caso sono raggiungibili e dipendono solo dal seed")


func _test_sound_distance() -> void:
	var nav := Nav.new(_map())
	var closed := nav.sound_distance(Vector2i(2, 3), Vector2i(9, 3))
	nav.set_door(DOOR, true)
	var open := nav.sound_distance(Vector2i(2, 3), Vector2i(9, 3))
	_check(is_equal_approx(open, 7.0), "il suono segue il corridoio (%.1f celle)" % open)
	_check(is_equal_approx(closed, open + nav.door_muffle), "una porta chiusa attutisce (%.1f celle)" % closed)
	_check(nav.sound_distance(Vector2i(2, 1), Vector2i(2, 5)) == 4.0, "nella stessa stanza: distanza diretta")
	nav.set_blocked(Vector2i(6, 3))  # una botola aperta nel corridoio
	nav.set_door(DOOR, false)
	nav.set_door(DOOR, true)
	var r := nav.route(Vector2i(2, 3), Vector2i(9, 3))
	_check(nav.sound_distance(Vector2i(2, 3), Vector2i(9, 3)) == -1.0 and r.cells.is_empty() and not r.blocked_door,
		"una cella bloccata taglia strada e suono, anche riaprendo la porta")


func _test_hearing() -> void:
	var b := Brain.new()
	_check(b.can_hear(0.3, 6.0) and not b.can_hear(0.3, 6.1), "camminare si sente entro 6 m")
	_check(b.can_hear(0.1, 2.0) and not b.can_hear(0.1, 2.5), "accucciati si sente entro 2 m")
	_check(b.can_hear(0.6, 12.0) and not b.can_hear(0.6, 12.5), "correre si sente entro 12 m")
	_check(not b.can_hear(1.0, -1.0), "rumore senza strada: non si sente")
	_check(not b.hear(Vector3(9, 0, 0), 0.1, 9.0) and b.state == Brain.State.WANDER, "un rumore troppo debole non lo sveglia")


func _test_wander() -> void:
	var a := Brain.new(3)
	var b := Brain.new(3)
	_check(a.state == Brain.State.WANDER and a.goal == Brain.Goal.NONE and a.speed() == 0.0, "all'inizio vaga, fermo")
	a.update(3.1)
	_check(a.goal == Brain.Goal.WANDER and is_equal_approx(a.speed(), a.wander_speed), "dopo la sosta parte, lento")
	var v := a.goal_version
	a.arrived()
	_check(a.goal == Brain.Goal.NONE and a.goal_version != v, "arrivato: sosta")
	b.update(3.1)
	b.arrived()
	var ok := true
	for i in 30:
		a.update(0.1)
		b.update(0.1)
		ok = ok and a.goal == b.goal
	_check(ok, "stesso seed, stesse soste")


func _test_investigate_and_search() -> void:
	var b := Brain.new()
	var changes: Array = []
	b.state_changed.connect(func(from: Brain.State, to: Brain.State) -> void: changes.append([from, to]))
	var noise := Vector3(4, 0, 2)
	_check(b.hear(noise, 0.3, 5.0), "sente i passi a 5 m")
	_check(b.state == Brain.State.INVESTIGATE and b.goal == Brain.Goal.POINT and b.goal_point == noise, "corre verso il rumore")
	_check(is_equal_approx(b.speed(), b.investigate_speed), "velocissimo quando indaga")
	_check(changes == [[Brain.State.WANDER, Brain.State.INVESTIGATE]], "state_changed da vaga a indaga")
	var noise2 := Vector3(6, 0, 2)
	b.hear(noise2, 0.3, 5.0)
	_check(b.goal_point == noise2 and changes.size() == 1, "un nuovo rumore cambia meta, non stato")

	b.arrived()
	_check(b.state == Brain.State.SEARCH and b.speed() == 0.0 and b.goal_point == noise2, "arrivato: annusa sul posto")
	b.update(b.search_pause + 0.05)
	_check(b.goal == Brain.Goal.SEARCH and is_equal_approx(b.speed(), b.search_speed), "poi gira lì attorno")
	b.arrived()
	b.update(0.1)
	_check(b.state == Brain.State.SEARCH, "la ricerca dura un po'")
	b.update(b.search_time)
	_check(b.state == Brain.State.WANDER, "finita la ricerca torna a vagare")

	b.hear(noise, 0.3, 5.0)
	b.arrived()
	b.hear(noise2, 0.6, 10.0)
	_check(b.state == Brain.State.INVESTIGATE and b.goal_point == noise2, "mentre annusa, un rumore lo rimanda a indagare")


func _test_scratch() -> void:
	var b := Brain.new()
	var noise := Vector3(18, 0, 6)
	b.hear(noise, 0.6, 10.0)
	b.blocked_by_door()
	_check(b.state == Brain.State.SCRATCH and b.speed() == 0.0, "porta chiusa sulla strada: gratta")
	b.door_opened()
	_check(b.state == Brain.State.INVESTIGATE and b.goal_point == noise, "la porta si apre: riprende la strada")
	b.blocked_by_door()
	b.update(b.scratch_time - 0.1)
	_check(b.state == Brain.State.SCRATCH, "gratta per qualche secondo")
	b.update(0.2)
	_check(b.state == Brain.State.WANDER, "poi rinuncia e torna a vagare")
	b.update(3.1)
	b.blocked_by_door()
	_check(b.state == Brain.State.WANDER, "vagando non gratta mai (le mete sono raggiungibili)")


func _test_recoil() -> void:
	var b := Brain.new()
	b.hear(Vector3(2, 0, 0), 0.3, 2.0)
	_check(b.touch(), "il primo contatto colpisce")
	_check(b.state == Brain.State.RECOIL and b.speed() == 0.0, "dopo il colpo si ritrae")
	_check(not b.touch(), "mentre si ritrae non colpisce di nuovo")
	var scream := Vector3(3, 0, 1)
	_check(b.hear(scream, 0.8, 1.0) and b.state == Brain.State.RECOIL, "sente il grido ma resta fermo")
	b.update(b.recoil_time + 0.05)
	_check(b.state == Brain.State.INVESTIGATE and b.goal_point == scream, "poi va dove ha sentito gridare")

	var quiet := Brain.new()
	quiet.position = Vector3(5, 0, 5)
	quiet.touch()
	quiet.update(quiet.recoil_time + 0.05)
	_check(quiet.state == Brain.State.SEARCH and quiet.goal_point == Vector3(5, 0, 5), "senza rumori annusa dove ha colpito")
	_check(quiet.touch(), "finita la ritirata può colpire di nuovo")


func _test_trap() -> void:
	var b := Brain.new()
	b.hear(Vector3(2, 0, 0), 0.3, 2.0)
	b.trap(3.0)
	_check(b.state == Brain.State.TRAPPED and b.speed() == 0.0, "nella tagliola sta fermo")
	_check(not b.touch(), "intrappolato non colpisce")
	b.update(2.9)
	_check(b.state == Brain.State.TRAPPED, "resta preso 3 secondi")
	b.update(0.2)
	_check(b.state == Brain.State.SEARCH, "liberato, annusa lì attorno")


func _test_stuck() -> void:
	var b := Brain.new()
	b.hear(Vector3(2, 0, 0), 0.3, 2.0)
	b.stuck()
	_check(b.state == Brain.State.SEARCH, "bloccato mentre indaga: annusa dove è arrivato")
	var w := Brain.new()
	w.update(3.1)
	var v := w.goal_version
	w.stuck()
	_check(w.goal == Brain.Goal.WANDER and w.goal_version == v + 1, "bloccato mentre vaga: nuova meta")


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		printerr("FALLITO: " + label)
