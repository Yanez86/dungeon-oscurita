class_name DungeonNav
extends RefCounted
## Mappa dei passaggi per i nemici, solo dati: dove si cammina, come arrivare a una meta
## e quanto è lontano un rumore. Lavora in celle della griglia del generatore.
## Le porte chiuse contano come muri (i nemici non le aprono): le mete a caso sono sempre
## raggiungibili, quindi un nemico non resta mai incastrato davanti a una porta.
## I percorsi li calcola AStarGrid2D, la classe di Godot che trova il percorso più breve su una griglia.

## Una cella si è aperta o chiusa al passaggio (una porta, una botola): chi sta camminando ricalcola il percorso.
signal passage_changed(cell: Vector2i, open: bool)

var cell_size := 2.0     ## metri per cella (lo imposta il builder)
var door_muffle := 3.0   ## celle in più che una porta chiusa aggiunge alla distanza di un rumore

var _gen: DungeonGenerator
var _astar := AStarGrid2D.new()
var _closed: Dictionary[Vector2i, bool] = {}   ## porte chiuse
var _blocked: Dictionary[Vector2i, bool] = {}  ## celle chiuse per sempre dopo la generazione (botole aperte)


## Strada verso una meta: le celle da percorrere (quella di partenza esclusa).
## `blocked_door` è vero se la meta sta oltre una porta chiusa: la strada si ferma davanti alla porta.
class Route:
	var cells: Array[Vector2i] = []
	var blocked_door := false


## Le porte partono chiuse, come nel gioco (vedi Door).
func _init(gen: DungeonGenerator) -> void:
	_gen = gen
	_astar.region = Rect2i(0, 0, gen.width, gen.height)
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in gen.height:
		for x in gen.width:
			var c := Vector2i(x, y)
			if not gen.is_floor(c) or gen.decorations.has(c):
				_astar.set_point_solid(c)
	for c in gen.doors:
		_closed[c] = true
		_astar.set_point_solid(c)


## Cella che contiene un punto del mondo (come DungeonBuilder.world_to_cell).
func to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / cell_size), roundi(pos.z / cell_size))


## Centro di una cella, a livello del pavimento.
func to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x * cell_size, 0.0, c.y * cell_size)


## Si può camminare nella cella: pavimento, niente arredi, niente porte chiuse.
func is_walkable(c: Vector2i) -> bool:
	return _astar.is_in_boundsv(c) and not _astar.is_point_solid(c)


func is_door_closed(c: Vector2i) -> bool:
	return _closed.has(c)


func set_door(c: Vector2i, open: bool) -> void:
	if not _gen.doors.has(c) or open != _closed.has(c):
		return
	if open:
		_closed.erase(c)
	else:
		_closed[c] = true
	_astar.set_point_solid(c, not open or _blocked.has(c))
	passage_changed.emit(c, open)


## Una cella che non si può più attraversare (per esempio una botola aperta), né a piedi né col suono.
func set_blocked(c: Vector2i) -> void:
	if not _astar.is_in_boundsv(c) or _blocked.has(c):
		return
	_blocked[c] = true
	_astar.set_point_solid(c)
	passage_changed.emit(c, false)


## Strada da `from` a `to`. Se l'unica strada passa da una porta chiusa, porta fin davanti alla porta.
## Vuota (e non bloccata) se si è già arrivati o se `to` è irraggiungibile.
func route(from: Vector2i, to: Vector2i) -> Route:
	var r := Route.new()
	to = nearest_walkable(to)
	if to == from:
		return r
	var path := _find(from, to, false)
	if path.is_empty():
		path = _find(from, to, true)
		for i in path.size():
			if _closed.has(path[i]):
				r.blocked_door = true
				path = path.slice(0, i)
				break
	if not path.is_empty() and path[0] == from:
		path = path.slice(1)
	r.cells.assign(path)
	return r


## Le celle raggiungibili a piedi da `from` (senza attraversare porte chiuse)
## che distano da `min_steps` a `max_steps` passi.
func reachable_cells(from: Vector2i, min_steps: int, max_steps: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var steps: Dictionary[Vector2i, int] = {from: 0}
	var queue: Array[Vector2i] = [from]
	var head := 0
	while head < queue.size():
		var c := queue[head]
		head += 1
		var d := steps[c]
		if d >= min_steps:
			found.append(c)
		if d == max_steps:
			continue
		for side in DungeonGenerator.SIDES:
			var n := c + side
			if is_walkable(n) and not steps.has(n):
				steps[n] = d + 1
				queue.append(n)
	return found


## Una meta a caso tra le celle raggiungibili (vedi reachable_cells); `from` se non ce n'è nessuna.
func random_cell(from: Vector2i, rng: RandomNumberGenerator, min_steps: int, max_steps: int) -> Vector2i:
	var cells := reachable_cells(from, min_steps, max_steps)
	if cells.is_empty():
		cells = reachable_cells(from, 1, max_steps)
	if cells.is_empty():
		return from
	return cells[rng.randi_range(0, cells.size() - 1)]


## Quanto è lontano un rumore, in celle, seguendo i corridoi: il suono non passa dai muri.
## Le porte chiuse lo attutiscono (door_muffle celle in più l'una). -1 se non c'è strada.
func sound_distance(from: Vector2i, to: Vector2i) -> float:
	from = nearest_walkable(from)
	to = nearest_walkable(to)
	if from == to:
		return 0.0
	var path := _find(from, to, true)
	if path.is_empty():
		return -1.0
	var d := 0.0
	for i in range(1, path.size()):
		d += Vector2(path[i] - path[i - 1]).length()
		if _closed.has(path[i]):
			d += door_muffle
	return d


## La cella stessa se ci si cammina, altrimenti la più vicina percorribile (entro 2 celle);
## serve per rumori che nascono vicino a un arredo o a una porta chiusa.
func nearest_walkable(c: Vector2i) -> Vector2i:
	if is_walkable(c):
		return c
	for radius: int in [1, 2]:
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var n := c + Vector2i(dx, dy)
				if is_walkable(n):
					return n
	return c


## Percorso di celle da `from` a `to` (compresi). Con `through_doors` le porte chiuse si attraversano:
## serve per sapere quale porta blocca e per il suono. `from` vale anche se non ci si cammina
## (un corpo può essere a cavallo di un arredo): AStarGrid2D non parte da una cella solida.
func _find(from: Vector2i, to: Vector2i, through_doors: bool) -> Array[Vector2i]:
	if not _astar.is_in_boundsv(from) or not _astar.is_in_boundsv(to):
		return []
	var opened: Array[Vector2i] = []
	if through_doors:
		for c in _closed:
			if not _blocked.has(c):
				opened.append(c)
	if _astar.is_point_solid(from) and not opened.has(from):
		opened.append(from)
	for c in opened:
		_astar.set_point_solid(c, false)
	var path := _astar.get_id_path(from, to)
	for c in opened:
		_astar.set_point_solid(c, true)
	return path
