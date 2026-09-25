class_name DungeonGenerator
extends RefCounted
## Genera un piano come griglia di dati (niente 3D qui).
## Stesso seed = stesso piano: fondamentale per debug e coop.

enum Cell { WALL, FLOOR }

var width: int
var height: int
var grid := PackedByteArray()
var rooms: Array[Rect2i] = []
var start_cell := Vector2i.ZERO
var exit_cell := Vector2i.ZERO
var items: Dictionary[Vector2i, StringName] = {}  ## cella -> id oggetto (vedi Items)
var doors: Dictionary[Vector2i, bool] = {}  ## cella -> true se il passaggio va lungo x (est-ovest)
var wall_torches: Dictionary[Vector2i, Vector2i] = {}  ## cella di pavimento -> direzione del muro

## Parametri: il builder li imposta dai suoi @export prima di generate().
var max_corridor := 12              ## distanza massima (in celle) tra i centri di stanze collegate
var door_chance := 0.35             ## probabilità che un ingresso di stanza abbia una porta
var wall_torch_floor_chance := 0.5  ## probabilità che il piano abbia torce a muro
var wall_torch_count := Vector2i(2, 5)  ## quante torce a muro (min, max), se ci sono

var _rng := RandomNumberGenerator.new()


func _init(w: int = 50, h: int = 50) -> void:
	width = w
	height = h


func generate(seed_value: int, max_rooms: int = 14) -> void:
	_rng.seed = seed_value
	grid.resize(width * height)
	grid.fill(Cell.WALL)
	rooms.clear()
	items.clear()
	doors.clear()
	wall_torches.clear()

	# Ogni nuova stanza si collega alla più vicina già esistente: corridoi corti.
	# Le stanze troppo lontane da tutte le altre vengono scartate.
	for attempt in max_rooms * 10:
		if rooms.size() >= max_rooms:
			break
		var rw := _rng.randi_range(4, 9)
		var rh := _rng.randi_range(4, 9)
		var room := Rect2i(
			_rng.randi_range(1, width - rw - 2),
			_rng.randi_range(1, height - rh - 2),
			rw, rh)
		if _overlaps_any(room):
			continue
		var nearest := _nearest_room(room.get_center())
		if nearest >= 0 and _manhattan(rooms[nearest].get_center(), room.get_center()) > max_corridor:
			continue
		_carve_room(room)
		if nearest >= 0:
			_carve_corridor(rooms[nearest].get_center(), room.get_center())
		rooms.append(room)

	start_cell = rooms[0].get_center()
	exit_cell = _farthest_room_center(start_cell)
	_place_doors()
	_place_wall_torches()


## Sparge gli oggetti nelle stanze, mai in quella d'ingresso né sull'uscita.
## Va chiamata subito dopo generate(): continua lo stesso generatore casuale,
## quindi stesso seed + stessi conteggi = stessi oggetti negli stessi punti.
func place_items(torch_count: int, flint_count: int) -> void:
	items.clear()
	var to_place: Array[StringName] = []
	for i in torch_count:
		to_place.append(Items.TORCH)
	for i in flint_count:
		to_place.append(Items.FLINT)
	if rooms.size() < 2:
		return
	for id in to_place:
		for attempt in 20:
			var room := rooms[_rng.randi_range(1, rooms.size() - 1)]
			var c := Vector2i(
				_rng.randi_range(room.position.x, room.end.x - 1),
				_rng.randi_range(room.position.y, room.end.y - 1))
			if c != exit_cell and not items.has(c):
				items[c] = id
				break


func is_floor(c: Vector2i) -> bool:
	return in_bounds(c) and grid[c.y * width + c.x] == Cell.FLOOR


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < width and c.y < height


## Vero per i muri che confinano con un pavimento (gli unici da costruire in 3D).
func touches_floor(c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if is_floor(c + Vector2i(dx, dy)):
				return true
	return false


## Distanza a passi da `from` verso ogni cella (-1 = irraggiungibile).
func distances_from(from: Vector2i) -> PackedInt32Array:
	var dist := PackedInt32Array()
	dist.resize(width * height)
	dist.fill(-1)
	dist[from.y * width + from.x] = 0
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		for d: Vector2i in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var n := c + d
			if is_floor(n) and dist[n.y * width + n.x] == -1:
				dist[n.y * width + n.x] = dist[c.y * width + c.x] + 1
				queue.append(n)
	return dist


## Mappa in testo: # muro, . pavimento, S ingresso, E uscita, T torcia, A acciarino,
## D porta, L torcia a muro.
func to_ascii() -> String:
	var out := ""
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if c == start_cell: out += "S"
			elif c == exit_cell: out += "E"
			elif items.get(c) == Items.TORCH: out += "T"
			elif items.get(c) == Items.FLINT: out += "A"
			elif doors.has(c): out += "D"
			elif wall_torches.has(c): out += "L"
			elif is_floor(c): out += "."
			else: out += "#"
		out += "\n"
	return out


func _overlaps_any(room: Rect2i) -> bool:
	for other in rooms:
		if other.grow(1).intersects(room):  # almeno una cella di muro tra le stanze
			return true
	return false


## Indice della stanza col centro più vicino a `c` (-1 se non ce ne sono).
func _nearest_room(c: Vector2i) -> int:
	var best := -1
	var best_d := 1 << 30
	for i in rooms.size():
		var d := _manhattan(rooms[i].get_center(), c)
		if d < best_d:
			best_d = d
			best = i
	return best


func _manhattan(a: Vector2i, b: Vector2i) -> int:
	return absi(a.x - b.x) + absi(a.y - b.y)


func _in_any_room(c: Vector2i) -> bool:
	for r in rooms:
		if r.has_point(c):
			return true
	return false


## Porte nelle strozzature di corridoio subito fuori da una stanza:
## muro ai due lati, pavimento davanti e dietro. Mai due porte attaccate.
func _place_doors() -> void:
	for y in range(1, height - 1):
		for x in range(1, width - 1):
			var c := Vector2i(x, y)
			if not is_floor(c) or _in_any_room(c):
				continue
			var along_x := is_floor(c + Vector2i.LEFT) and is_floor(c + Vector2i.RIGHT) \
				and not is_floor(c + Vector2i.UP) and not is_floor(c + Vector2i.DOWN)
			var along_y := is_floor(c + Vector2i.UP) and is_floor(c + Vector2i.DOWN) \
				and not is_floor(c + Vector2i.LEFT) and not is_floor(c + Vector2i.RIGHT)
			if not (along_x or along_y):
				continue
			var a := c + (Vector2i.LEFT if along_x else Vector2i.UP)
			var b := c + (Vector2i.RIGHT if along_x else Vector2i.DOWN)
			if not (_in_any_room(a) or _in_any_room(b)):
				continue  # solo all'ingresso di una stanza
			if doors.has(a) or doors.has(b):
				continue
			if _rng.randf() < door_chance:
				doors[c] = along_x


## In alcuni piani, qualche torcia appesa ai muri delle stanze (mai in quella d'ingresso).
func _place_wall_torches() -> void:
	if rooms.size() < 2 or _rng.randf() >= wall_torch_floor_chance:
		return
	var sides: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]
	for i in _rng.randi_range(wall_torch_count.x, wall_torch_count.y):
		for attempt in 20:
			var room := rooms[_rng.randi_range(1, rooms.size() - 1)]
			var dir := sides[_rng.randi_range(0, 3)]
			# Cella di pavimento sul bordo della stanza, dal lato scelto.
			var c := Vector2i(
				_rng.randi_range(room.position.x, room.end.x - 1),
				_rng.randi_range(room.position.y, room.end.y - 1))
			if dir == Vector2i.LEFT: c.x = room.position.x
			elif dir == Vector2i.RIGHT: c.x = room.end.x - 1
			elif dir == Vector2i.UP: c.y = room.position.y
			else: c.y = room.end.y - 1
			if is_floor(c + dir) or wall_torches.has(c):
				continue  # lì c'è un'apertura, non un muro
			wall_torches[c] = dir
			break


func _carve_room(r: Rect2i) -> void:
	for y in range(r.position.y, r.end.y):
		for x in range(r.position.x, r.end.x):
			_set_floor(Vector2i(x, y))


## Corridoio a L tra due punti, con l'angolo scelto a caso.
func _carve_corridor(a: Vector2i, b: Vector2i) -> void:
	var corner := Vector2i(b.x, a.y) if _rng.randf() < 0.5 else Vector2i(a.x, b.y)
	_carve_line(a, corner)
	_carve_line(corner, b)


func _carve_line(a: Vector2i, b: Vector2i) -> void:
	var step := Vector2i(signi(b.x - a.x), signi(b.y - a.y))
	var p := a
	_set_floor(p)
	while p != b:
		p += step
		_set_floor(p)


func _set_floor(c: Vector2i) -> void:
	grid[c.y * width + c.x] = Cell.FLOOR


func _farthest_room_center(from: Vector2i) -> Vector2i:
	var dist := distances_from(from)
	var best := from
	var best_d := -1
	for r in rooms:
		var c := r.get_center()
		var d := dist[c.y * width + c.x]
		if d > best_d:
			best_d = d
			best = c
	return best
