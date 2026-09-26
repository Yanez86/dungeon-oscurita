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
		_test_start_room(s)
		_test_decorations(s)
		_test_enemies(s)
		_test_exit_niche(s)
		_test_key(s)
		_test_secret_rooms(s)
		_test_gates(s)
	_test_start_torch_always()
	_test_exit_niche_always()
	_test_secret_rooms_often()
	_test_gates_often()
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
	var in_start: Array[StringName] = []
	for c: Vector2i in a.items:
		ok = ok and a.is_floor(c) and c != a.exit_cell and c != a.start_cell
		ok = ok and dist[c.y * a.width + c.x] > 0
		if a.rooms[0].has_point(c):
			in_start.append(a.items[c])
	_check(ok, "seed %d: oggetti raggiungibili, mai sull'ingresso né sull'uscita" % s)
	_check(in_start == [Items.TORCH], "seed %d: nella stanza d'ingresso solo una torcia a terra (%s)" % [s, in_start])

	# Tagliole e scudo: dopo torce e acciarini, che restano dove erano.
	var c := Gen.new()
	c.bear_trap_count = Vector2i(2, 2)
	c.shield_chance = 1.0
	c.generate(s)
	c.place_items(4, 1)
	var values := c.items.values()
	_check(values.count(Items.BEAR_TRAP) == 2 and values.count(Items.SHIELD) == 1,
		"seed %d: due tagliole e uno scudo (%s)" % [s, values])
	ok = true
	for cell: Vector2i in c.items:
		ok = ok and (a.items.get(cell) == c.items[cell] or not a.items.has(cell))
		if c.items[cell] != Items.TORCH:
			ok = ok and not c.rooms[0].has_point(cell) and cell != c.exit_cell
	_check(ok, "seed %d: tagliole e scudo fuori dalla stanza d'ingresso, torce e acciarino al loro posto" % s)

	# Zaino: c'è se la probabilità è 1, fuori dalla stanza d'ingresso; gli altri oggetti non si spostano.
	var d := Gen.new()
	d.bear_trap_count = Vector2i(2, 2)
	d.shield_chance = 1.0
	d.backpack_chance = 1.0
	d.generate(s)
	d.place_items(4, 1)
	var packs := d.items.keys().filter(func(cell: Vector2i) -> bool: return d.items[cell] == Items.BACKPACK)
	_check(packs.size() == 1 and not d.rooms[0].has_point(packs[0]), "seed %d: uno zaino, fuori dalla stanza d'ingresso" % s)
	ok = true
	for cell: Vector2i in c.items:
		ok = ok and d.items.get(cell) == c.items[cell]
	_check(ok, "seed %d: lo zaino non sposta gli altri oggetti" % s)


## Su tanti seed e con ogni numero di torce: la stanza d'ingresso ha sempre la sua torcia a terra.
## (Il builder chiede sempre almeno una torcia: vedi DungeonBuilder.torches_for_floor.)
func _test_start_torch_always() -> void:
	var missing := 0
	for s in range(1, 301):
		var g := Gen.new()
		g.generate(s)
		for torch_count in range(1, 5):
			g.place_items(torch_count, 1)
			var in_start := 0
			for c: Vector2i in g.items:
				if g.rooms[0].has_point(c) and c != g.start_cell and g.items[c] == Items.TORCH:
					in_start += 1
			missing += int(in_start != 1)
	_check(missing == 0, "300 seed: una torcia nella stanza d'ingresso con 1-4 torce (%d casi senza)" % missing)


func _test_start_room(s: int) -> void:
	var g := Gen.new()
	g.wall_torch_floor_chance = 0.0  # conta solo le torce della stanza d'ingresso
	g.generate(s)
	var r := g.rooms[0]
	_check(r.size.x <= g.start_room_size.y and r.size.y <= g.start_room_size.y,
		"seed %d: stanza d'ingresso piccola (%s)" % [s, r.size])
	var ok: bool = g.wall_torches.size() == g.start_wall_torches
	for c: Vector2i in g.wall_torches:
		ok = ok and r.has_point(c) and not g.is_floor(c + g.wall_torches[c])
	_check(ok, "seed %d: stanza d'ingresso illuminata da %d torce a muro" % [s, g.start_wall_torches])


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
	_check(none.doors.keys() == [none.golden_door], "seed %d: con probabilità 0 solo la porta dorata" % s)


func _test_wall_torches(s: int) -> void:
	var g := Gen.new()
	g.wall_torch_floor_chance = 1.0
	g.wall_torch_count = Vector2i(3, 3)
	g.generate(s)
	var others := 0
	var ok := true
	for c: Vector2i in g.wall_torches:
		ok = ok and g.is_floor(c) and not g.is_floor(c + g.wall_torches[c])
		if not g.rooms[0].has_point(c):
			others += 1
	_check(others == 3, "seed %d: 3 torce a muro fuori dalla stanza d'ingresso (%d)" % [s, others])
	_check(ok, "seed %d: torce a muro appoggiate a un muro" % s)
	var none := Gen.new()
	none.wall_torch_floor_chance = 0.0
	none.start_wall_torches = 0
	none.generate(s)
	_check(none.wall_torches.is_empty(), "seed %d: piano senza torce a muro" % s)


func _test_decorations(s: int) -> void:
	var a := Gen.new()
	var b := Gen.new()
	for g: Gen in [a, b]:
		g.decorations_per_room = Vector2i(3, 6)  # tanti arredi: il caso peggiore per i passaggi
		g.generate(s)
		g.place_items(4, 1)
		g.place_decorations()
	_check(a.decorations == b.decorations, "seed %d: stesso seed, stessi arredi" % s)
	_check(a.decorations.size() >= a.rooms.size(), "seed %d: arredi piazzati (%d)" % [s, a.decorations.size()])
	var ok := true
	for c: Vector2i in a.decorations:
		ok = ok and a.is_floor(c) and not a.rooms[0].has_point(c)
		ok = ok and c != a.exit_cell and not a.items.has(c) and not a.wall_torches.has(c)
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				ok = ok and (Vector2i(dx, dy) == Vector2i.ZERO or not a.decorations.has(c + Vector2i(dx, dy)))
	_check(ok, "seed %d: arredi sul pavimento, distanziati, lontani da oggetti, torce, uscita e ingresso" % s)

	# Con gli arredi come ostacoli, ogni altra cella di pavimento resta raggiungibile.
	var seen := {a.start_cell: true}
	var queue: Array[Vector2i] = [a.start_cell]
	while not queue.is_empty():
		var c: Vector2i = queue.pop_back()
		for d: Vector2i in Gen.SIDES:
			var n := c + d
			if a.is_floor(n) and not a.decorations.has(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	var floors := 0
	for i in a.grid.size():
		floors += int(a.grid[i] == Gen.Cell.FLOOR)
	_check(seen.size() == floors - a.decorations.size(),
		"seed %d: gli arredi non bloccano nessun passaggio (%d/%d)" % [s, seen.size(), floors - a.decorations.size()])


func _test_enemies(s: int) -> void:
	var a := Gen.new()
	var b := Gen.new()
	for g: Gen in [a, b]:
		g.generate(s)
		g.place_items(4, 1)
		g.place_decorations()
		g.place_enemies(3)
	_check(a.enemies == b.enemies, "seed %d: stesso seed, stessi nemici" % s)
	_check(a.enemies.size() == 3, "seed %d: tre nemici piazzati (%d)" % [s, a.enemies.size()])
	var dist := a.distances_from(a.start_cell)
	var ok := true
	var rooms_used := {}
	for c in a.enemies:
		ok = ok and a.is_floor(c) and not a.rooms[0].has_point(c) and c != a.exit_cell
		ok = ok and not a.items.has(c) and not a.decorations.has(c) and a.enemies.count(c) == 1
		for i in a.rooms.size():
			if a.rooms[i].has_point(c):
				rooms_used[i] = true
				ok = ok and dist[a.rooms[i].get_center().y * a.width + a.rooms[i].get_center().x] >= a.enemy_min_distance
	_check(ok, "seed %d: nemici in stanze lontane dall'ingresso, mai su oggetti, arredi o uscita" % s)
	_check(rooms_used.size() == 3, "seed %d: un nemico per stanza finché ce ne sono (%d stanze)" % [s, rooms_used.size()])
	a.place_enemies(0)
	_check(a.enemies.is_empty(), "seed %d: zero nemici" % s)


## Uscita: nicchia di due celle dietro una stanza, porta dorata e poi la scala, che si raggiunge solo da lì.
func _test_exit_niche(s: int) -> void:
	var g := Gen.new()
	g.generate(s)
	var door := g.golden_door
	_check(door.x >= 0 and g.door_kinds.get(door) == Gen.DOOR_GOLDEN, "seed %d: c'è la porta dorata" % s)
	_check(g.exit_cell == door + g.exit_dir and g.doors.get(door) == (g.exit_dir.x != 0),
		"seed %d: la scala è subito dietro la porta dorata" % s)
	var side := Vector2i(g.exit_dir.y, g.exit_dir.x)
	_check(not g.is_floor(door + side) and not g.is_floor(door - side) and g.rooms[g.exit_room].has_point(door - g.exit_dir),
		"seed %d: la porta dorata è una strozzatura all'uscita di una stanza" % s)
	var only_door := true
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := g.exit_cell + Vector2i(dx, dy)
			only_door = only_door and (n == g.exit_cell or n == door or not g.is_floor(n))
	_check(only_door, "seed %d: attorno alla scala solo roccia e la porta dorata" % s)
	var open := _reachable(g, [door])
	_check(not open.has(g.exit_cell) and open.size() == _floor_count(g) - 2,
		"seed %d: senza la porta dorata si arriva ovunque tranne che alla scala" % s)


func _test_exit_niche_always() -> void:
	var missing := 0
	for s in range(1, 301):
		var g := Gen.new()
		g.generate(s)
		missing += int(g.golden_door.x < 0)
	_check(missing == 0, "300 seed: la porta dorata c'è sempre (%d piani senza)" % missing)


## Chiave d'oro: una sola, raggiungibile senza passare dalla porta dorata, mai nella stanza d'ingresso
## né in quella della nicchia, lontana dall'ingresso. Gli altri oggetti non si spostano.
func _test_key(s: int) -> void:
	var g := Gen.new()
	g.generate(s)
	g.place_items(4, 1)
	var before := g.items.duplicate()
	g.place_key()
	var keys := g.items.keys().filter(func(c: Vector2i) -> bool: return g.items[c] == Items.KEY_GOLD)
	_check(keys.size() == 1, "seed %d: una chiave d'oro (%d)" % [s, keys.size()])
	if keys.size() != 1:
		return
	var key: Vector2i = keys[0]
	var ok := true
	for c: Vector2i in before:
		ok = ok and g.items[c] == before[c]
	_check(ok, "seed %d: la chiave non sposta gli altri oggetti" % s)
	_check(_reachable(g, [g.golden_door]).has(key), "seed %d: chiave raggiungibile senza la porta dorata" % s)
	_check(not g.rooms[0].has_point(key) and not g.rooms[g.exit_room].has_point(key),
		"seed %d: chiave fuori dalla stanza d'ingresso e da quella della nicchia" % s)
	var dist := g.distances_from(g.start_cell)
	_check(dist[key.y * g.width + key.x] >= 10, "seed %d: chiave lontana dall'ingresso (%d)" % [s, dist[key.y * g.width + key.x]])


## Stanze segrete: dietro un muro segreto accanto a una stanza, raggiungibili solo da lì; dentro 1-3 tesori,
## e tesori solo lì.
func _test_secret_rooms(s: int) -> void:
	var g := _full(s)
	var secret_doors := g.door_kinds.keys().filter(func(c: Vector2i) -> bool: return g.door_kinds[c] == Gen.DOOR_SECRET)
	_check(not g.secret_rooms.is_empty() and secret_doors.size() == g.secret_rooms.size(),
		"seed %d: stanze segrete, ognuna col suo muro (%d, %d)" % [s, g.secret_rooms.size(), secret_doors.size()])
	var shut := _reachable(g, [g.golden_door] + secret_doors)
	var all := _reachable(g, [g.golden_door])
	var ok := true
	for r in g.secret_rooms:
		for y in range(r.position.y, r.end.y):
			for x in range(r.position.x, r.end.x):
				var c := Vector2i(x, y)
				ok = ok and g.is_floor(c) and not shut.has(c) and all.has(c)
				for room in g.rooms:
					ok = ok and not room.has_point(c)
	_check(ok, "seed %d: le stanze segrete si raggiungono solo dal muro segreto" % s)
	ok = true
	for d: Vector2i in secret_doors:
		var step := Vector2i.RIGHT if g.doors[d] else Vector2i.DOWN
		var side := Vector2i(step.y, step.x)
		var ends := [d + step, d - step]
		var in_room := ends.filter(func(c: Vector2i) -> bool: return g.rooms.any(func(r: Rect2i) -> bool: return r.has_point(c)))
		ok = ok and not g.is_floor(d + side) and not g.is_floor(d - side)
		ok = ok and in_room.size() == 1 and (g.is_secret(ends[0]) or g.is_secret(ends[1]))
		ok = ok and not g.decorations.has(d + step) and not g.decorations.has(d - step)
	_check(ok, "seed %d: il muro segreto sta tra una stanza e la sua stanza segreta, sgombro" % s)
	var counts: Array[int] = []
	counts.resize(g.secret_rooms.size())
	ok = true
	for c: Vector2i in g.items:
		if not Items.VALUES.has(g.items[c]):
			continue
		var i := g.secret_rooms.find_custom(func(r: Rect2i) -> bool: return r.has_point(c))
		ok = ok and i >= 0
		if i >= 0:
			counts[i] += 1
	_check(ok and counts.all(func(n: int) -> bool: return n >= 1 and n <= 3),
		"seed %d: 1-3 tesori in ogni stanza segreta, e solo lì (%s)" % [s, counts])
	var again := _full(s)
	_check(again.secret_rooms == g.secret_rooms and again.items == g.items, "seed %d: stesso seed, stessi segreti" % s)


## Un piano con tutto, come lo prepara il builder dal piano 2.
func _full(s: int) -> Gen:
	var g := Gen.new()
	g.secret_room_count = Vector2i(1, 2)
	g.generate(s)
	g.place_items(4, 1)
	g.place_key()
	g.place_treasures()
	g.place_decorations()
	g.place_enemies(2)
	return g


func _test_secret_rooms_often() -> void:
	var found := 0
	for s in range(1, 201):
		var g := Gen.new()
		g.secret_room_count = Vector2i(1, 1)
		g.generate(s)
		found += int(g.secret_rooms.size() == 1)
	_check(found >= 190, "200 seed: una stanza segreta quando la si chiede (%d)" % found)


## Cancelli a leva: chiudono un vicolo cieco con almeno una stanza (mai la nicchia d'uscita), la leva è
## raggiungibile coi cancelli chiusi, lontana dal cancello, su un muro di una stanza, fuori dagli arredi.
## Con key_behind_gate_chance 1 la chiave sta dietro il cancello.
func _test_gates(s: int) -> void:
	var g := Gen.new()
	g.gate_count = 1
	g.key_behind_gate_chance = 1.0
	g.generate(s)
	g.place_items(4, 1)
	g.place_key()
	g.place_decorations()
	var gates := g.door_kinds.keys().filter(func(c: Vector2i) -> bool: return g.door_kinds[c] == Gen.DOOR_GATE)
	_check(gates.size() == 1 and g.levers.size() == 1, "seed %d: un cancello con la sua leva (%d, %d)" % [s, gates.size(), g.levers.size()])
	if gates.size() != 1 or g.levers.size() != 1:
		return
	var gate: Vector2i = gates[0]
	var lever := g.levers[0]
	var shut := _reachable(g, g.door_kinds.keys())
	var open := _reachable(g, [g.golden_door])
	var ok := not g.gated.is_empty()
	for c: Vector2i in g.gated:
		ok = ok and not shut.has(c) and open.has(c)
	_check(ok, "seed %d: dietro il cancello si arriva solo alzandolo" % s)
	_check(not g.gated.has(g.rooms[g.exit_room].get_center()) and not g.gated.has(g.golden_door - g.exit_dir),
		"seed %d: il cancello non chiude la strada per l'uscita" % s)
	var dist := g.distances_from(gate)
	_check(lever.target == gate and shut.has(lever.cell) and not g.gated.has(lever.cell)
		and dist[lever.cell.y * g.width + lever.cell.x] >= g.lever_min_distance,
		"seed %d: leva raggiungibile a cancello chiuso e lontana da lui" % s)
	_check(g.rooms.any(func(r: Rect2i) -> bool: return r.has_point(lever.cell)) and not g.is_floor(lever.cell + lever.wall)
		and not g.decorations.has(lever.cell) and not g.wall_torches.has(lever.cell),
		"seed %d: leva su un muro di una stanza, niente arredi né torce davanti" % s)
	var keys := g.items.keys().filter(func(c: Vector2i) -> bool: return g.items[c] == Items.KEY_GOLD)
	_check(keys.size() == 1 and g.gated.has(keys[0]), "seed %d: la chiave dietro il cancello" % s)
	var plain := Gen.new()
	plain.gate_count = 1
	plain.generate(s)
	plain.place_items(4, 1)
	plain.place_key()
	keys = plain.items.keys().filter(func(c: Vector2i) -> bool: return plain.items[c] == Items.KEY_GOLD)
	_check(keys.size() == 1 and not plain.gated.has(keys[0]), "seed %d: di solito la chiave è fuori dal cancello" % s)


func _test_gates_often() -> void:
	var found := 0
	for s in range(1, 201):
		var g := Gen.new()
		g.gate_count = 1
		g.generate(s)
		found += int(g.levers.size() == 1)
	_check(found >= 190, "200 seed: un cancello quando lo si chiede (%d)" % found)


## Celle raggiungibili dall'ingresso senza attraversare `blocked`.
func _reachable(g: Gen, blocked: Array) -> Dictionary:
	var seen := {g.start_cell: true}
	var queue: Array[Vector2i] = [g.start_cell]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in Gen.SIDES:
			var n := c + d
			if g.is_floor(n) and not seen.has(n) and not blocked.has(n):
				seen[n] = true
				queue.append(n)
	return seen


func _floor_count(g: Gen) -> int:
	var n := 0
	for y in g.height:
		for x in g.width:
			n += int(g.is_floor(Vector2i(x, y)))
	return n


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		printerr("FALLITO: " + label)
