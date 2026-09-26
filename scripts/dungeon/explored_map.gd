class_name ExploredMap
extends RefCounted
## Quali celle del piano il giocatore ha visto davvero (solo dati, niente nodi).
## Una cella è vista se è entro il raggio della torcia e nessun muro o porta chiusa la copre.

var gen: DungeonGenerator
var seen := PackedByteArray()
var closed_doors: Dictionary[Vector2i, bool] = {}  ## porte ancora chiuse: si vedono, ma non ci si vede attraverso


func _init(generator: DungeonGenerator) -> void:
	gen = generator
	seen.resize(gen.width * gen.height)  # parte tutto a 0 = non visto
	for c in gen.doors:
		closed_doors[c] = true


func is_seen(c: Vector2i) -> bool:
	return gen.in_bounds(c) and seen[c.y * gen.width + c.x] == 1


## Segna come viste le celle in vista entro `radius` celle da `origin`.
## Restituisce solo quelle nuove, così chi disegna aggiorna il minimo.
func reveal(origin: Vector2i, radius: float) -> Array[Vector2i]:
	var revealed: Array[Vector2i] = []
	if radius <= 0.0 or not gen.in_bounds(origin):
		return revealed
	var r := ceili(radius)
	for y in range(origin.y - r, origin.y + r + 1):
		for x in range(origin.x - r, origin.x + r + 1):
			var c := Vector2i(x, y)
			if is_seen(c) or not gen.in_bounds(c):
				continue
			if Vector2(c - origin).length() > radius:
				continue
			if has_line_of_sight(origin, c):
				seen[y * gen.width + x] = 1
				revealed.append(c)
	return revealed


## Linea retta (Bresenham) da `a` a `b`: le celle in mezzo devono essere pavimento.
## La cella finale può essere un muro o una porta chiusa (si vedono, ma non ci si vede attraverso).
## Un passo in diagonale tra due muri è bloccato: niente sbirciate dagli spigoli.
func has_line_of_sight(a: Vector2i, b: Vector2i) -> bool:
	var x := a.x
	var y := a.y
	var dx := absi(b.x - a.x)
	var dy := -absi(b.y - a.y)
	var sx := 1 if a.x < b.x else -1
	var sy := 1 if a.y < b.y else -1
	var err := dx + dy
	while true:
		var c := Vector2i(x, y)
		if c == b:
			return true
		if c != a and not see_through(c):
			return false
		var e2 := 2 * err
		var nx := x
		var ny := y
		if e2 >= dy:
			err += dy
			nx += sx
		if e2 <= dx:
			err += dx
			ny += sy
		if nx != x and ny != y and not see_through(Vector2i(nx, y)) and not see_through(Vector2i(x, ny)):
			return false
		x = nx
		y = ny
	return false


## Pavimento libero: niente muro e niente porta chiusa (tra le sbarre di un cancello si vede).
func see_through(c: Vector2i) -> bool:
	return gen.is_floor(c) and (not closed_doors.has(c) or gen.door_kinds.get(c) == DungeonGenerator.DOOR_GATE)


## Una porta si è aperta: da ora la vista passa.
func open_door(c: Vector2i) -> void:
	closed_doors.erase(c)


## Una porta si è richiusa: le celle già viste restano viste, ma da ora la vista si ferma qui.
func close_door(c: Vector2i) -> void:
	closed_doors[c] = true
