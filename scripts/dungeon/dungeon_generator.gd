class_name DungeonGenerator
extends RefCounted
## Genera un piano come griglia di dati (niente 3D qui).
## Stesso seed = stesso piano: fondamentale per debug e coop.

enum Cell { WALL, FLOOR }

const SIDES: Array[Vector2i] = [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

## Porte speciali (vedi door_kinds); le altre sono porte di legno.
const DOOR_GOLDEN := &"golden"  ## chiude la nicchia della scala: si apre solo con la chiave d'oro
const DOOR_SECRET := &"secret"  ## muro segreto: sembra un muro della stanza; dietro, una stanzetta coi tesori

var width: int
var height: int
var grid := PackedByteArray()
var rooms: Array[Rect2i] = []
var start_cell := Vector2i.ZERO
var exit_cell := Vector2i.ZERO  ## la scala che scende al piano dopo, in fondo alla nicchia dietro la porta dorata
var exit_dir := Vector2i.ZERO   ## verso in cui si scende: dalla porta dorata alla scala
var golden_door := Vector2i(-1, -1)  ## cella della porta dorata (-1, -1 se il piano non ha la nicchia)
var exit_room := -1  ## indice della stanza da cui si entra nella nicchia
var items: Dictionary[Vector2i, StringName] = {}  ## cella -> id oggetto (vedi Items)
var doors: Dictionary[Vector2i, bool] = {}  ## ogni passaggio che si chiude: cella -> true se va lungo x (est-ovest)
var door_kinds: Dictionary[Vector2i, StringName] = {}  ## cella di una porta speciale -> DOOR_*; assente = porta di legno
var secret_rooms: Array[Rect2i] = []  ## stanzette dietro un muro segreto (non sono in `rooms`: niente nemici, arredi, trappole)
var wall_torches: Dictionary[Vector2i, Vector2i] = {}  ## cella di pavimento -> direzione del muro
var decorations: Dictionary[Vector2i, StringName] = {}  ## cella -> tipo d'arredo (vedi DECORATION_KINDS)
var enemies: Array[Vector2i] = []  ## celle dove nascono i nemici (per ora tutti Ciechi)

## Arredi: il builder sceglie il modello 3D per ogni tipo. Bloccano il passaggio.
const DECORATION_KINDS: Array[StringName] = [&"barrel", &"crate", &"trunk", &"candles"]

## Parametri: il builder li imposta dai suoi @export prima di generate().
var max_corridor := 12              ## distanza massima (in celle) tra i centri di stanze collegate
var door_chance := 0.35             ## probabilità che un ingresso di stanza abbia una porta
var wall_torch_floor_chance := 0.5  ## probabilità che il piano abbia torce a muro
var wall_torch_count := Vector2i(2, 5)  ## quante torce a muro (min, max), se ci sono
var start_room_size := Vector2i(3, 4)   ## lato minimo e massimo della stanza d'ingresso
var start_wall_torches := 2             ## torce a muro nella stanza d'ingresso (sempre illuminata)
var decorations_per_room := Vector2i(0, 3)  ## arredi per stanza (min, max), esclusa quella d'ingresso
var enemy_min_distance := 12  ## passi minimi tra l'ingresso e la stanza di un nemico
var shield_chance := 0.0      ## probabilità che il piano abbia uno scudo a terra
var bear_trap_count := Vector2i.ZERO  ## tagliole a terra (min, max)
var backpack_chance := 0.0    ## probabilità che il piano abbia uno zaino a terra
var key_room_choices := 3     ## la chiave d'oro va in una delle stanze più lontane da ingresso e uscita
var secret_room_count := Vector2i.ZERO  ## stanze segrete (min, max)
var secret_room_size := Vector2i(2, 3)   ## lato minimo e massimo di una stanza segreta
var treasures_per_secret_room := Vector2i(1, 3)
## Quanto spesso esce ogni tesoro, rispetto agli altri.
var treasure_weights: Dictionary[StringName, float] = {Items.COINS: 5.0, Items.GEM: 3.0, Items.CHALICE: 1.0}

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
	door_kinds.clear()
	secret_rooms.clear()
	wall_torches.clear()
	decorations.clear()
	enemies.clear()

	# Ogni nuova stanza si collega alla più vicina già esistente: corridoi corti.
	# Le stanze troppo lontane da tutte le altre vengono scartate.
	# La prima è la stanza d'ingresso: piccola.
	for attempt in max_rooms * 10:
		if rooms.size() >= max_rooms:
			break
		var side_range := start_room_size if rooms.is_empty() else Vector2i(4, 9)
		var rw := _rng.randi_range(side_range.x, side_range.y)
		var rh := _rng.randi_range(side_range.x, side_range.y)
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
	_carve_exit()
	_carve_secret_rooms()
	_place_doors()
	_place_start_torches()
	_place_wall_torches()


## Una torcia a terra nella stanza d'ingresso (mai sotto i piedi del giocatore);
## il resto sparso nelle altre stanze, mai sull'uscita, con le tagliole (`bear_trap_count`) e, con le loro
## probabilità, uno scudo (`shield_chance`) e uno zaino (`backpack_chance`).
## Va chiamata subito dopo generate(): continua lo stesso generatore casuale,
## quindi stesso seed + stessi conteggi = stessi oggetti negli stessi punti.
func place_items(torch_count: int, flint_count: int) -> void:
	items.clear()
	if torch_count > 0:
		# Scelta tra le celle libere, non a tentativi: la torcia d'ingresso c'è sempre.
		var start_room := rooms[0]
		var free: Array[Vector2i] = []
		for y in range(start_room.position.y, start_room.end.y):
			for x in range(start_room.position.x, start_room.end.x):
				if Vector2i(x, y) != start_cell:
					free.append(Vector2i(x, y))
		items[free[_rng.randi_range(0, free.size() - 1)]] = Items.TORCH
	var to_place: Array[StringName] = []
	for i in torch_count - items.size():
		to_place.append(Items.TORCH)
	for i in flint_count:
		to_place.append(Items.FLINT)
	if bear_trap_count.y > 0:
		for i in _rng.randi_range(bear_trap_count.x, bear_trap_count.y):
			to_place.append(Items.BEAR_TRAP)
	if shield_chance > 0.0 and _rng.randf() < shield_chance:
		to_place.append(Items.SHIELD)
	if rooms.size() < 2:
		return
	for id in to_place:
		_place_in_rooms(id)
	# Gli oggetti aggiunti dopo vengono in fondo: quelli sopra restano dove erano.
	if backpack_chance > 0.0 and _rng.randf() < backpack_chance:
		_place_in_rooms(Items.BACKPACK)


## Un oggetto in una cella a caso di una stanza (mai quella d'ingresso), libera e non sull'uscita.
func _place_in_rooms(id: StringName) -> void:
	for attempt in 20:
		var room := rooms[_rng.randi_range(1, rooms.size() - 1)]
		var c := Vector2i(
			_rng.randi_range(room.position.x, room.end.x - 1),
			_rng.randi_range(room.position.y, room.end.y - 1))
		if c != exit_cell and not items.has(c):
			items[c] = id
			return


## La chiave d'oro che apre la porta dell'uscita: una per piano, in una stanza lontana sia dall'ingresso
## sia dalla porta dorata (una a caso tra le `key_room_choices` migliori): il piano va attraversato due volte.
## Mai nella stanza d'ingresso né in quella della nicchia. Va chiamata dopo place_items(): evita gli oggetti
## e continua lo stesso generatore casuale.
func place_key() -> void:
	if golden_door.x < 0 or rooms.size() < 2:
		return
	var from_start := distances_from(start_cell)
	var from_exit := distances_from(golden_door)
	var candidates: Array[int] = []
	for i in range(1, rooms.size()):
		if i != exit_room or rooms.size() == 2:
			candidates.append(i)
	var score := func(i: int) -> int:
		var c := rooms[i].get_center()
		return mini(_cell_distance(from_start, c), _cell_distance(from_exit, c))
	candidates.sort_custom(func(a: int, b: int) -> bool: return score.call(a) > score.call(b))
	var room := rooms[candidates[_rng.randi_range(0, mini(key_room_choices, candidates.size()) - 1)]]
	var free: Array[Vector2i] = []
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			var c := Vector2i(x, y)
			if not items.has(c):
				free.append(c)
	if not free.is_empty():
		items[free[_rng.randi_range(0, free.size() - 1)]] = Items.KEY_GOLD


## Barili, casse, bauli e candele contro i muri delle stanze.
## Va chiamata dopo place_items(): gli arredi evitano gli oggetti e continuano lo stesso generatore casuale.
## Stanza d'ingresso sempre sgombra.
func place_decorations() -> void:
	decorations.clear()
	for i in range(1, rooms.size()):
		var spots := _decoration_spots(rooms[i])
		for n in _rng.randi_range(decorations_per_room.x, decorations_per_room.y):
			# Mai due arredi vicini (nemmeno in diagonale): nessuna cella resta chiusa in un angolo.
			var usable: Array = spots.filter(func(s: Vector2i) -> bool: return not _near_decoration(s))
			if usable.is_empty():
				break
			var cell: Vector2i = usable[_rng.randi_range(0, usable.size() - 1)]
			decorations[cell] =DECORATION_KINDS[_rng.randi_range(0, DECORATION_KINDS.size() - 1)]


## Dove nascono i nemici: stanze ad almeno `enemy_min_distance` passi dall'ingresso (o la più lontana,
## se il piano è piccolo), una diversa per ciascuno finché ce ne sono; mai su oggetti, arredi o uscita.
## Va chiamata dopo place_decorations(): continua lo stesso generatore casuale.
func place_enemies(count: int) -> void:
	enemies.clear()
	if count <= 0 or rooms.size() < 2:
		return
	var dist := distances_from(start_cell)
	var far_rooms: Array[int] = []
	var farthest := 1
	var best := -1
	for i in range(1, rooms.size()):
		var c := rooms[i].get_center()
		var d := dist[c.y * width + c.x]
		if d >= enemy_min_distance:
			far_rooms.append(i)
		if d > best:
			best = d
			farthest = i
	if far_rooms.is_empty():
		far_rooms.append(farthest)
	var unused: Array[int] = far_rooms.duplicate()
	for n in count:
		if unused.is_empty():
			unused = far_rooms.duplicate()  # più nemici che stanze: si ricomincia
		var pick: int = unused.pop_at(_rng.randi_range(0, unused.size() - 1))
		var room := rooms[pick]
		var free: Array[Vector2i] = []
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				var c := Vector2i(x, y)
				if c != exit_cell and not items.has(c) and not decorations.has(c) and not enemies.has(c):
					free.append(c)
		if not free.is_empty():
			enemies.append(free[_rng.randi_range(0, free.size() - 1)])


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


## Mappa in testo: # muro, . pavimento, S ingresso, E uscita (la scala), C Cieco, T torcia, A acciarino, U scudo, X tagliola,
## Z zaino, K chiave d'oro, $ tesoro, G porta dorata, H muro segreto,
## D porta, L torcia a muro.
func to_ascii() -> String:
	var out := ""
	for y in height:
		for x in width:
			var c := Vector2i(x, y)
			if c == start_cell: out += "S"
			elif c == exit_cell: out += "E"
			elif enemies.has(c): out += "C"
			elif items.get(c) == Items.TORCH: out += "T"
			elif items.get(c) == Items.FLINT: out += "A"
			elif items.get(c) == Items.SHIELD: out += "U"
			elif items.get(c) == Items.BEAR_TRAP: out += "X"
			elif items.get(c) == Items.BACKPACK: out += "Z"
			elif items.get(c) == Items.KEY_GOLD: out += "K"
			elif Items.VALUES.has(items.get(c, &"")): out += "$"
			elif door_kinds.get(c) == DOOR_GOLDEN: out += "G"
			elif door_kinds.get(c) == DOOR_SECRET: out += "H"
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
			if not is_floor(c) or _in_any_room(c) or doors.has(c):
				continue  # le porte speciali (la dorata) sono già al loro posto
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


## La stanza d'ingresso è sempre illuminata: torce a muro su lati diversi, se possibile.
func _place_start_torches() -> void:
	var room := rooms[0]
	var used_sides: Array[Vector2i] = []
	for i in start_wall_torches:
		for attempt in 20:
			var dir := SIDES[_rng.randi_range(0, 3)]
			if used_sides.has(dir) and attempt < 10:
				continue
			if _try_wall_torch(room, dir):
				used_sides.append(dir)
				break


## In alcuni piani, qualche torcia appesa ai muri delle altre stanze.
func _place_wall_torches() -> void:
	if rooms.size() < 2 or _rng.randf() >= wall_torch_floor_chance:
		return
	for i in _rng.randi_range(wall_torch_count.x, wall_torch_count.y):
		for attempt in 20:
			var room := rooms[_rng.randi_range(1, rooms.size() - 1)]
			if _try_wall_torch(room, SIDES[_rng.randi_range(0, 3)]):
				break


## Prova ad appendere una torcia al muro della stanza dal lato `dir`.
## Falso se nel punto scelto c'è un'apertura o già un'altra torcia.
func _try_wall_torch(room: Rect2i, dir: Vector2i) -> bool:
	# Cella di pavimento sul bordo della stanza, dal lato scelto.
	var c := Vector2i(
		_rng.randi_range(room.position.x, room.end.x - 1),
		_rng.randi_range(room.position.y, room.end.y - 1))
	if dir == Vector2i.LEFT: c.x = room.position.x
	elif dir == Vector2i.RIGHT: c.x = room.end.x - 1
	elif dir == Vector2i.UP: c.y = room.position.y
	else: c.y = room.end.y - 1
	if is_floor(c + dir) or wall_torches.has(c):
		return false
	wall_torches[c] = dir
	return true


## Celle del bordo della stanza appoggiate a un muro, lontane dagli ingressi,
## libere da oggetti, torce a muro e uscita. Il centro della stanza resta sempre percorribile.
func _decoration_spots(room: Rect2i) -> Array[Vector2i]:
	var spots: Array[Vector2i] = []
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			var c := Vector2i(x, y)
			if c == exit_cell or items.has(c) or wall_torches.has(c):
				continue
			var against_wall := false
			var near_entrance := _is_entrance(c, room)
			for d in SIDES:
				against_wall = against_wall or not is_floor(c + d)
				near_entrance = near_entrance or (room.has_point(c + d) and _is_entrance(c + d, room))
			if against_wall and not near_entrance:
				spots.append(c)
	return spots


## Una cella della stanza da cui si esce: confina con un pavimento fuori dalla stanza.
func _is_entrance(c: Vector2i, room: Rect2i) -> bool:
	for d in SIDES:
		if is_floor(c + d) and not room.has_point(c + d):
			return true
	return false


func _near_decoration(c: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if decorations.has(c + Vector2i(dx, dy)):
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


## L'uscita: dietro la stanza più lontana dall'ingresso si scava una nicchia di due celle nella roccia,
## la porta dorata e la scala che scende. È una strozzatura come quelle delle porte (muro ai lati) e l'unica
## via per la scala. Se la stanza più lontana non ha spazio attorno si prova la successiva; se non ce l'ha
## nessuna (piani minuscoli) l'uscita resta al centro della più lontana, senza porta.
func _carve_exit() -> void:
	var dist := distances_from(start_cell)
	var order: Array[int] = []
	for i in range(1, rooms.size()):
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _cell_distance(dist, rooms[a].get_center()) > _cell_distance(dist, rooms[b].get_center()))
	for i in order:
		var options := _exit_options(rooms[i])
		if options.is_empty():
			continue
		var pick: Array = options[_rng.randi_range(0, options.size() - 1)]
		var door: Vector2i = pick[0]
		exit_dir = pick[1]
		exit_cell = door + exit_dir
		golden_door = door
		exit_room = i
		_set_floor(door)
		_set_floor(exit_cell)
		doors[door] = exit_dir.x != 0
		door_kinds[door] = DOOR_GOLDEN
		return
	exit_room = order[0] if not order.is_empty() else 0
	exit_cell = rooms[exit_room].get_center()


## Dove può partire la nicchia dell'uscita da una stanza: coppie [cella della porta, verso].
## Porta e scala sono roccia piena, circondate da roccia (lontane da altri corridoi) e mai sul bordo della mappa.
func _exit_options(room: Rect2i) -> Array:
	var options := []
	for dir in SIDES:
		var side := Vector2i(dir.y, dir.x)  # lungo il lato
		for y in range(room.position.y, room.end.y):
			for x in range(room.position.x, room.end.x):
				var edge := Vector2i(x, y)
				if room.has_point(edge + dir):
					continue  # non è sul lato `dir` della stanza
				var door := edge + dir
				var stairs := door + dir
				if stairs.x < 1 or stairs.y < 1 or stairs.x > width - 2 or stairs.y > height - 2:
					continue
				var ok := not is_floor(door) and not is_floor(door + side) and not is_floor(door - side)
				for dy in range(-1, 2):
					for dx in range(-1, 2):
						var n := stairs + Vector2i(dx, dy)
						ok = ok and (n == door or not is_floor(n))
				if ok:
					options.append([door, dir])
	return options


func _cell_distance(dist: PackedInt32Array, c: Vector2i) -> int:
	return dist[c.y * width + c.x]


## Stanze segrete (`secret_room_count`): stanzette scavate nella roccia accanto a una stanza (mai quella
## d'ingresso), collegate solo da una cella di passaggio chiusa da un muro segreto. Tutt'attorno roccia piena:
## non toccano altri corridoi, quindi l'unica via è il muro segreto.
func _carve_secret_rooms() -> void:
	if secret_room_count.y <= 0 or rooms.size() < 2:
		return
	for n in _rng.randi_range(secret_room_count.x, secret_room_count.y):
		for attempt in 40:
			var room := rooms[_rng.randi_range(1, rooms.size() - 1)]
			var dir := SIDES[_rng.randi_range(0, 3)]
			var edge := Vector2i(
				_rng.randi_range(room.position.x, room.end.x - 1),
				_rng.randi_range(room.position.y, room.end.y - 1))
			if dir.x != 0:
				edge.x = room.position.x if dir.x < 0 else room.end.x - 1
			else:
				edge.y = room.position.y if dir.y < 0 else room.end.y - 1
			var size := Vector2i(
				_rng.randi_range(secret_room_size.x, secret_room_size.y),
				_rng.randi_range(secret_room_size.x, secret_room_size.y))
			var door := edge + dir
			var first := door + dir  # la prima cella della stanza segreta, subito dietro il muro
			var rect := Rect2i(first, size)
			if dir.x != 0:
				rect.position.x = first.x if dir.x > 0 else first.x - size.x + 1
				rect.position.y = first.y - _rng.randi_range(0, size.y - 1)
			else:
				rect.position.y = first.y if dir.y > 0 else first.y - size.y + 1
				rect.position.x = first.x - _rng.randi_range(0, size.x - 1)
			if _secret_fits(door, dir, rect):
				_carve_room(rect)
				_set_floor(door)
				doors[door] = dir.x != 0
				door_kinds[door] = DOOR_SECRET
				secret_rooms.append(rect)
				break


## La stanza segreta `rect` e il passaggio `door` stanno nella roccia piena: niente pavimento attorno
## (tranne la stanza da cui si entra, davanti al passaggio) e lontani dal bordo della mappa.
func _secret_fits(door: Vector2i, dir: Vector2i, rect: Rect2i) -> bool:
	if rect.position.x < 1 or rect.position.y < 1 or rect.end.x > width - 1 or rect.end.y > height - 1:
		return false
	var side := Vector2i(dir.y, dir.x)
	if is_floor(door) or is_floor(door + side) or is_floor(door - side):
		return false
	var around := rect.grow(1)
	for y in range(around.position.y, around.end.y):
		for x in range(around.position.x, around.end.x):
			var c := Vector2i(x, y)
			if c != door and is_floor(c):
				return false
	return true


## Vero se `c` è dentro una stanza segreta.
func is_secret(c: Vector2i) -> bool:
	for r in secret_rooms:
		if r.has_point(c):
			return true
	return false


## I tesori nelle stanze segrete (`treasures_per_secret_room`), scelti coi pesi di `treasure_weights`.
## Va chiamata dopo place_items() (e place_key()): continua lo stesso generatore casuale.
func place_treasures() -> void:
	for rect in secret_rooms:
		var free: Array[Vector2i] = []
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				free.append(Vector2i(x, y))
		for n in mini(_rng.randi_range(treasures_per_secret_room.x, treasures_per_secret_room.y), free.size()):
			items[free.pop_at(_rng.randi_range(0, free.size() - 1))] = _pick_treasure()


func _pick_treasure() -> StringName:
	var total := 0.0
	for id in treasure_weights:
		total += treasure_weights[id]
	var r := _rng.randf() * total
	for id in treasure_weights:
		r -= treasure_weights[id]
		if r < 0.0:
			return id
	return treasure_weights.keys()[-1]
