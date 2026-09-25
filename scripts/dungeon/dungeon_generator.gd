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

	for attempt in max_rooms * 4:
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
		_carve_room(room)
		if not rooms.is_empty():
			_carve_corridor(rooms[-1].get_center(), room.get_center())
		rooms.append(room)

	start_cell = rooms[0].get_center()
	exit_cell = _farthest_room_center(start_cell)


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


## Mappa in testo: # muro, . pavimento, S ingresso, E uscita, T torcia, A acciarino.
func to_ascii() -> String:
	var out := ""
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if c == start_cell: out += "S"
			elif c == exit_cell: out += "E"
			elif items.get(c) == Items.TORCH: out += "T"
			elif items.get(c) == Items.FLINT: out += "A"
			elif is_floor(c): out += "."
			else: out += "#"
		out += "\n"
	return out


func _overlaps_any(room: Rect2i) -> bool:
	for other in rooms:
		if other.grow(1).intersects(room):  # almeno una cella di muro tra le stanze
			return true
	return false


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
