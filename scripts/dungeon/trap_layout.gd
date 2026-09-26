class_name TrapLayout
extends RefCounted
## Dove stanno le trappole di un piano: solo dati, come DungeonGenerator (il 3D lo fa DungeonBuilder,
## il comportamento le scene in scripts/traps/). Ha un generatore casuale tutto suo, col seed del piano:
## stesso seed = stesse trappole, e aggiungerle non sposta stanze, oggetti né nemici.
## Ogni trappola ha un innesco che un giocatore attento vede (piastra, filo, fori, campanelli).

const SPIKES := &"spikes"      ## frecce dal pavimento: piastra al centro di una cella piena di forellini
const TRAPDOOR := &"trapdoor"  ## botola sopra una fossa: solo nelle stanze, mai dove chiude un passaggio
const BOULDER := &"boulder"    ## masso che cade dal soffitto e rotola lungo un corridoio: innesco a filo
const VENT := &"vent"          ## soffio che spegne la torcia: piastra e grate nei muri di un corridoio dritto
const CAGE := &"cage"          ## gabbia che crolla dal soffitto: piastra e catene
const DARTS := &"darts"        ## porta a dardi: fori nello stipite
const BELLS := &"bells"        ## campanelli sopra una porta

const FLOOR_KINDS: Array[StringName] = [SPIKES, TRAPDOOR, BOULDER, VENT, CAGE]


## Una trappola sul pavimento.
class Spot:
	var kind: StringName
	var cell: Vector2i            ## cella dell'innesco (piastra, botola, filo)
	var dir := Vector2i.ZERO      ## masso: verso in cui rotola; soffio: asse del corridoio
	var start := Vector2i.ZERO    ## masso: cella dove cade dal soffitto (muro alle spalle)
	var end := Vector2i.ZERO      ## masso: ultima cella del percorso, dove si frantuma


var traps: Array[Spot] = []
var door_traps: Dictionary[Vector2i, StringName] = {}  ## cella della porta -> DARTS o BELLS
var ropes: Array[Vector2i] = []  ## corde a terra: senza, dalle fosse non si esce
var levers: Array[DungeonGenerator.LeverSpot] = []  ## leve murate che disattivano una trappola (anche le porte a dardi)

## Parametri: il builder li imposta dai suoi @export prima di plan().
var first_floor_count := 2   ## trappole sul pavimento al piano 1
var extra_per_floor := 1     ## quante in più a ogni piano
var max_count := 8
## Piano da cui compare ogni tipo: al primo solo quelle che non uccidono.
var min_floor: Dictionary[StringName, int] = {SPIKES: 1, VENT: 1, TRAPDOOR: 2, CAGE: 2, BOULDER: 3}
## Quanto spesso esce ogni tipo, rispetto agli altri disponibili.
var weights: Dictionary[StringName, float] = {SPIKES: 3.0, VENT: 2.0, TRAPDOOR: 2.0, CAGE: 1.5, BOULDER: 1.0}
var door_trap_chance := 0.3   ## probabilità che una porta sia trappolata
var door_trap_min_floor := 2
var ropes_min_floor := 2      ## le corde arrivano insieme alle botole
var ropes_per_floor := 1
var start_margin := 2         ## celle senza trappole attorno alla stanza d'ingresso
var boulder_min_run := 6      ## celle minime del percorso del masso
var boulder_wire_distance := Vector2i(2, 6)  ## celle tra il punto di caduta del masso e il filo
var lever_chance := 0.35           ## probabilità che una trappola abbia la sua leva
var lever_min_floor := 1
var lever_distance := Vector2i(2, 7)  ## passi tra la trappola e la sua leva (min, max)

var _gen: DungeonGenerator
var _rng := RandomNumberGenerator.new()
var _trap_cells: Dictionary[Vector2i, bool] = {}  ## celle degli inneschi (tra due trappole almeno una cella)
var _reserved: Dictionary[Vector2i, bool] = {}    ## percorsi dei massi: niente altre trappole sopra
var _pits: Dictionary[Vector2i, bool] = {}        ## botole: buchi nel pavimento


## Va chiamata dopo che il generatore ha piazzato oggetti, arredi e nemici: li evita tutti.
func plan(gen: DungeonGenerator, seed_value: int, floor_number: int) -> void:
	_gen = gen
	_rng.seed = seed_value + 104729  # seed proprio: le trappole non cambiano il resto del piano
	traps.clear()
	door_traps.clear()
	ropes.clear()
	levers.clear()
	_trap_cells.clear()
	_reserved.clear()
	_pits.clear()

	var kinds: Array[StringName] = []
	for kind in FLOOR_KINDS:
		if floor_number >= min_floor.get(kind, 1) and weights.get(kind, 0.0) > 0.0:
			kinds.append(kind)
	for n in count_for_floor(floor_number):
		for attempt in 8:
			if not kinds.is_empty() and _place(_pick_kind(kinds)):
				break

	if floor_number >= door_trap_min_floor:
		for c in gen.doors:
			if gen.door_kinds.has(c):
				continue  # solo le porte di legno: le speciali (dorata…) hanno già le loro regole
			if not _near_start(c) and _rng.randf() < door_trap_chance:
				door_traps[c] = DARTS if _rng.randf() < 0.5 else BELLS

	if floor_number >= ropes_min_floor:
		_place_ropes()

	if floor_number >= lever_min_floor:
		_place_levers()


## Quante trappole sul pavimento: crescono scendendo, fino a max_count.
func count_for_floor(floor_number: int) -> int:
	return mini(max_count, first_floor_count + extra_per_floor * maxi(floor_number - 1, 0))


## La trappola il cui innesco è in `c`, o null.
func trap_at(c: Vector2i) -> Spot:
	for t in traps:
		if t.cell == c:
			return t
	return null


## Celle delle botole: il builder ci lascia il buco nel pavimento.
func pit_cells() -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	out.assign(_pits.keys())
	return out


## La mappa del generatore con le trappole (la stampa main.gd a ogni piano): f frecce, b botola, o masso (dove cade), w filo,
## v soffio, g gabbia, x porta a dardi, q porta coi campanelli, r corda, y leva di una trappola.
func to_ascii() -> String:
	var lines := _gen.to_ascii().split("\n")
	var marks: Dictionary[Vector2i, String] = {}
	for t in traps:
		match t.kind:
			SPIKES: marks[t.cell] = "f"
			TRAPDOOR: marks[t.cell] = "b"
			VENT: marks[t.cell] = "v"
			CAGE: marks[t.cell] = "g"
			BOULDER:
				marks[t.start] = "o"
				marks[t.cell] = "w"
	for c in door_traps:
		marks[c] = "x" if door_traps[c] == DARTS else "q"
	for c in ropes:
		marks[c] = "r"
	for l in levers:
		marks[l.cell] = "y"
	for c in marks:
		var line := lines[c.y]
		lines[c.y] = line.substr(0, c.x) + marks[c] + line.substr(c.x + 1)
	return "\n".join(lines)


func _pick_kind(kinds: Array[StringName]) -> StringName:
	var total := 0.0
	for k in kinds:
		total += weights[k]
	var r := _rng.randf() * total
	for k in kinds:
		r -= weights[k]
		if r < 0.0:
			return k
	return kinds[-1]


func _place(kind: StringName) -> bool:
	match kind:
		BOULDER:
			return _place_boulder()
		VENT:
			return _place_in(_cells(func(c: Vector2i) -> bool: return _corridor_axis(c) != Vector2i.ZERO), kind)
		TRAPDOOR:
			return _place_pit()
		_:
			return _place_in(_cells(func(_c: Vector2i) -> bool: return true), kind)


## Una trappola di tipo `kind` in una cella a caso tra `cells`.
func _place_in(cells: Array[Vector2i], kind: StringName) -> bool:
	if cells.is_empty():
		return false
	var t := Spot.new()
	t.kind = kind
	t.cell = cells[_rng.randi_range(0, cells.size() - 1)]
	t.dir = _corridor_axis(t.cell)
	_add(t)
	return true


## Botola: in una stanza, e solo se col buco al suo posto tutto il resto del piano resta raggiungibile.
func _place_pit() -> bool:
	var cells := _cells(func(c: Vector2i) -> bool: return _in_room(c))
	while not cells.is_empty():
		var c: Vector2i = cells.pop_at(_rng.randi_range(0, cells.size() - 1))
		_pits[c] = true
		if _all_reachable():
			var t := Spot.new()
			t.kind = TRAPDOOR
			t.cell = c
			_add(t)
			return true
		_pits.erase(c)
	return false


## Masso: cade dal soffitto in una cella con un muro alle spalle (fondo di un corridoio o lato di una
## stanza) e rotola dritto finché trova un muro, una porta o un arredo. Il filo è qualche cella più
## avanti, sempre in un corridoio: lì il masso lo riempie da muro a muro e non si schiva di lato.
func _place_boulder() -> bool:
	var options: Array[Spot] = []
	for y in _gen.height:
		for x in _gen.width:
			var s := Vector2i(x, y)
			if not _gen.is_floor(s) or _gen.doors.has(s) or _gen.decorations.has(s):
				continue
			for d in DungeonGenerator.SIDES:
				if not _gen.is_floor(s - d):
					var t := _boulder_path(s, d)
					if t:
						options.append(t)
	if options.is_empty():
		return false
	var t := options[_rng.randi_range(0, options.size() - 1)]
	var wires := _boulder_wires(t)
	t.cell = wires[_rng.randi_range(0, wires.size() - 1)]
	var c := t.start
	while true:
		_reserved[c] = true
		if c == t.end:
			break
		c += t.dir
	_add(t)
	return true


## Il percorso del masso da `s` verso `d`, o null se non va bene.
func _boulder_path(s: Vector2i, d: Vector2i) -> Spot:
	var end := s
	var length := 1
	while _gen.is_floor(end + d) and not _gen.doors.has(end + d) and not _gen.decorations.has(end + d):
		end += d
		length += 1
	if length < boulder_min_run:
		return null
	var c := s
	while true:
		if _trap_cells.has(c) or _reserved.has(c) or _near_start(c):
			return null
		if c == end:
			break
		c += d
	var t := Spot.new()
	t.kind = BOULDER
	t.start = s
	t.dir = d
	t.end = end
	return t if not _boulder_wires(t).is_empty() else null


## Dove può stare il filo del masso: in un corridoio, tra boulder_wire_distance.x e .y celle dalla caduta
## (e prima della fine del percorso).
func _boulder_wires(t: Spot) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for k in range(boulder_wire_distance.x, boulder_wire_distance.y + 1):
		var c := t.start + t.dir * k
		if (c - t.start).length() >= (t.end - t.start).length():
			break
		if not _in_room(c) and _usable(c):
			out.append(c)
	return out


## Leve delle trappole: alcune trappole (`lever_chance`, porte a dardi comprese) hanno una leva su un muro a
## `lever_distance` passi, raggiungibile senza passare dall'innesco e prima di arrivarci, venendo dall'ingresso.
## Tirarla la disattiva per sempre (vedi Trap.disarm).
func _place_levers() -> void:
	var targets: Array[Vector2i] = []
	for t in traps:
		targets.append(t.cell)
	for c in door_traps:
		if door_traps[c] == DARTS:
			targets.append(c)
	var from_start := _gen.distances_from(_gen.start_cell)
	for target in targets:
		if _rng.randf() >= lever_chance:
			continue
		var reach := _reach_avoiding(target)
		var near := _gen.distances_from(target)
		var spots: Array[Vector2i] = []
		for y in _gen.height:
			for x in _gen.width:
				var c := Vector2i(x, y)
				var i := y * _gen.width + x
				if near[i] < lever_distance.x or near[i] > lever_distance.y or from_start[i] > from_start[target.y * _gen.width + target.x]:
					continue
				if reach.has(c) and _lever_spot(c):
					spots.append(c)
		if spots.is_empty():
			continue
		var lever := DungeonGenerator.LeverSpot.new()
		lever.cell = spots[_rng.randi_range(0, spots.size() - 1)]
		var walls := DungeonGenerator.SIDES.filter(func(d: Vector2i) -> bool: return not _gen.is_floor(lever.cell + d))
		lever.wall = walls[_rng.randi_range(0, walls.size() - 1)]
		lever.target = target
		levers.append(lever)


## Dove si può murare una leva: pavimento libero con un muro accanto, lontano da porte, inneschi, fosse,
## percorsi dei massi, torce a muro e altre leve.
func _lever_spot(c: Vector2i) -> bool:
	if not _free_spot(c) or _near_start(c) or _trap_cells.has(c) or _pits.has(c) or _reserved.has(c):
		return false
	if _gen.wall_torches.has(c) or levers.any(func(l: DungeonGenerator.LeverSpot) -> bool: return l.cell == c):
		return false
	var wall := false
	for d in DungeonGenerator.SIDES:
		if _gen.doors.has(c + d):
			return false  # la cornice di una porta non è un muro dove murarla
		wall = wall or not _gen.is_floor(c + d)
	return wall


## Le celle raggiungibili dall'ingresso senza passare da `avoid`, dalle fosse, dagli arredi e dalle porte
## speciali (dorata, muri segreti, cancelli): quelle che non si aprono da sole.
func _reach_avoiding(avoid: Vector2i) -> Dictionary[Vector2i, bool]:
	var seen: Dictionary[Vector2i, bool] = {_gen.start_cell: true}
	var queue: Array[Vector2i] = [_gen.start_cell]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in DungeonGenerator.SIDES:
			var n := c + d
			if _gen.is_floor(n) and not seen.has(n) and n != avoid and not _blocked(n) and not _gen.door_kinds.has(n):
				seen[n] = true
				queue.append(n)
	return seen


## Corde a terra nelle stanze (mai in quella d'ingresso), su celle libere.
func _place_ropes() -> void:
	if _gen.rooms.size() < 2:
		return
	for n in ropes_per_floor:
		for attempt in 20:
			var room := _gen.rooms[_rng.randi_range(1, _gen.rooms.size() - 1)]
			var c := Vector2i(
				_rng.randi_range(room.position.x, room.end.x - 1),
				_rng.randi_range(room.position.y, room.end.y - 1))
			if _free_spot(c) and not _trap_cells.has(c) and not _pits.has(c) and not ropes.has(c):
				ropes.append(c)
				break


func _add(t: Spot) -> void:
	traps.append(t)
	_trap_cells[t.cell] = true


## Celle dove può andare un innesco e che soddisfano `extra`, in ordine di lettura (stabile col seed).
func _cells(extra: Callable) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for y in _gen.height:
		for x in _gen.width:
			var c := Vector2i(x, y)
			if _usable(c) and extra.call(c):
				out.append(c)
	return out


## Una cella libera per un innesco: lontana dall'ingresso, dalle porte e dalle altre trappole,
## mai su oggetti, arredi, uscita, nemici o sul percorso di un masso.
func _usable(c: Vector2i) -> bool:
	if not _free_spot(c) or _near_start(c) or _reserved.has(c) or _gen.enemies.has(c):
		return false
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			var n := c + Vector2i(dx, dy)
			if _trap_cells.has(n):
				return false
			if (dx == 0 or dy == 0) and _gen.doors.has(n):
				return false  # né sulle porte né appena davanti
	return true


## Pavimento senza oggetti, arredi, porte, uscita e ingresso, fuori dalle stanze segrete e senza la leva di un cancello.
func _free_spot(c: Vector2i) -> bool:
	return _gen.is_floor(c) and c != _gen.exit_cell and c != _gen.start_cell \
		and not _gen.items.has(c) and not _gen.decorations.has(c) and not _gen.doors.has(c) \
		and not _gen.is_secret(c) and not _gen.lever_at(c)


func _near_start(c: Vector2i) -> bool:
	return _gen.rooms[0].grow(start_margin).has_point(c)


func _in_room(c: Vector2i) -> bool:
	for r in _gen.rooms:
		if r.has_point(c):
			return true
	return false


## Direzione di un corridoio dritto in `c` (muri ai due lati): RIGHT se va lungo x, DOWN lungo y, ZERO altrimenti.
func _corridor_axis(c: Vector2i) -> Vector2i:
	if _in_room(c):
		return Vector2i.ZERO
	var fl := func(d: Vector2i) -> bool: return _gen.is_floor(c + d)
	if fl.call(Vector2i.LEFT) and fl.call(Vector2i.RIGHT) and not fl.call(Vector2i.UP) and not fl.call(Vector2i.DOWN):
		return Vector2i.RIGHT
	if fl.call(Vector2i.UP) and fl.call(Vector2i.DOWN) and not fl.call(Vector2i.LEFT) and not fl.call(Vector2i.RIGHT):
		return Vector2i.DOWN
	return Vector2i.ZERO


## Con arredi e botole come ostacoli, ogni altra cella di pavimento si raggiunge dall'ingresso.
func _all_reachable() -> bool:
	var seen: Dictionary[Vector2i, bool] = {_gen.start_cell: true}
	var queue: Array[Vector2i] = [_gen.start_cell]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d in DungeonGenerator.SIDES:
			var n := c + d
			if _gen.is_floor(n) and not _blocked(n) and not seen.has(n):
				seen[n] = true
				queue.append(n)
	var open := 0
	for y in _gen.height:
		for x in _gen.width:
			var c := Vector2i(x, y)
			open += int(_gen.is_floor(c) and not _blocked(c))
	return seen.size() == open


func _blocked(c: Vector2i) -> bool:
	return _gen.decorations.has(c) or _pits.has(c)
