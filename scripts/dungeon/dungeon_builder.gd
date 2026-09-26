class_name DungeonBuilder
extends Node3D
## Costruisce in 3D il piano prodotto da DungeonGenerator.
## Tutta la grafica è fatta di modelli voxel (assets/voxels/, vedi Voxels).
## Le collisioni restano blocchi semplici.

signal exit_reached
## Una porta si è aperta: `cell` è la sua cella nella griglia del generatore.
signal door_opened(cell: Vector2i)
## Una porta si è richiusa.
signal door_closed(cell: Vector2i)

const CELL := 2.0     ## lato di una cella in metri
const WALL_H := 3.0   ## altezza dei muri

@export var map_size := Vector2i(50, 50)

@export_group("Aspetto")
@export var floor_variant_chance := 0.2  ## lastre crepate o col muschio
@export var wall_variant_chance := 0.12  ## muri crepati
@export var shelf_chance := 0.06         ## mensole, solo nelle stanze
@export var pillar_width := 0.5          ## collisione dei pilastri negli angoli (metri)
@export var chunk_cells := 6             ## lato dei blocchi di disegno (celle): più piccoli = più draw call, meno triangoli
@export var view_distance := 40.0        ## metri oltre i quali muri e pavimenti non si disegnano

@export_group("Oggetti per piano")
@export var torches_first_floor := 4  ## torce di scorta al piano 1
@export var floors_per_torch_lost := 2  ## ogni quanti piani c'è una torcia in meno
@export var torches_min := 1
@export var flints_per_floor := 1

@export_group("Struttura")
@export var max_corridor := 12              ## distanza massima tra stanze collegate (celle)
@export var door_chance := 0.35             ## probabilità di una porta a ogni ingresso di stanza
@export var wall_torch_floor_chance := 0.5  ## probabilità che un piano abbia torce a muro
@export var wall_torch_count := Vector2i(2, 5)
@export var start_room_size := Vector2i(3, 4)  ## lato minimo e massimo della stanza d'ingresso
@export var start_wall_torches := 2            ## la stanza d'ingresso è sempre illuminata

const PICKUP_SCENE := preload("res://scenes/pickup.tscn")
const GROUND_TORCH_SCENE := preload("res://scenes/ground_torch.tscn")
const DOOR_SCENE := preload("res://scenes/door.tscn")
const WALL_TORCH_SCENE := preload("res://scenes/wall_torch.tscn")
const FLOOR_T := 0.25  ## spessore dei modelli di pavimento e soffitto
## Il pilastro è un filo più largo del modello: il fusto (±0,25 m) cadrebbe proprio sul confine tra due strati
## dei muri, e nelle fughe incassate le due facce sfarfallerebbero (z-fighting). 2% = 5 mm, non si nota.
const PILLAR_GROW := 1.02

## Modelli voxel: le varianti "normali" si alternano, le altre compaiono con le probabilità in Aspetto.
const ROOM_FLOORS: Array[StringName] = [&"floor_stone_a", &"floor_stone_b", &"floor_stone_c"]
const ROOM_FLOOR_VARIANTS: Array[StringName] = [&"floor_stone_cracked", &"floor_stone_moss"]
const CORRIDOR_FLOORS: Array[StringName] = [&"floor_dirt_a", &"floor_dirt_b", &"floor_dirt_c", &"floor_dirt_d"]
const WALLS: Array[StringName] = [&"wall_a", &"wall_b", &"wall_c"]
## Modelli voxel per ogni tipo d'arredo del generatore.
const DECORATION_MODELS: Dictionary[StringName, Array] = {
	&"barrel": [&"barrel_small", &"barrel_stack", &"barrel_large", &"keg"],
	&"crate": [&"crate_small", &"crate_large", &"crates_stacked", &"crate_decorated"],
	&"trunk": [&"trunk_small_a", &"trunk_small_b", &"trunk_medium_a", &"trunk_medium_b"],
	&"candles": [&"candle_triple", &"candle_melted", &"candle"],
}
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var gen: DungeonGenerator
var _exit_armed := false


func build(seed_value: int, floor_number: int = 1) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	gen = DungeonGenerator.new(map_size.x, map_size.y)
	gen.max_corridor = max_corridor
	gen.door_chance = door_chance
	gen.wall_torch_floor_chance = wall_torch_floor_chance
	gen.wall_torch_count = wall_torch_count
	gen.start_room_size = start_room_size
	gen.start_wall_torches = start_wall_torches
	gen.generate(seed_value)
	gen.place_items(torches_for_floor(floor_number), flints_per_floor)
	gen.place_decorations()

	var floors: Array[Vector2i] = []
	var walls: Array[Vector2i] = []
	for y in gen.height:
		for x in gen.width:
			var c := Vector2i(x, y)
			if gen.is_floor(c):
				floors.append(c)
			elif gen.touches_floor(c):
				walls.append(c)

	# Variazioni estetiche dal seed del piano: stesso seed, stesso aspetto.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var pieces: Dictionary[StringName, Array] = {}  # modello -> trasformazioni
	_add_floor_pieces(floors, rng, pieces)
	_add_wall_pieces(walls, rng, pieces)
	_add_corner_pillars(pieces)
	_add_decorations(rng, pieces)
	for model in pieces:
		_add_model_instances(Voxels.mesh(model), Voxels.material(), pieces[model])
	_add_collision(walls)
	_add_exit()
	for c in gen.items:
		spawn_pickup(gen.items[c], cell_to_world(c))
	_add_doors()
	_add_wall_torches()


## Le torce diventano più rare scendendo (GDD: generazione procedurale).
## Mai meno di una: è quella a terra nella stanza d'ingresso.
func torches_for_floor(floor_number: int) -> int:
	var lost := floori(float(floor_number - 1) / maxi(floors_per_torch_lost, 1))
	return maxi(maxi(torches_min, 1), torches_first_floor - lost)


## Crea un oggetto a terra. Usato dal generatore e quando il giocatore lascia qualcosa.
## Gli oggetti sono figli del dungeon, così spariscono quando si cambia piano.
func spawn_pickup(item: StringName, world_pos: Vector3) -> Pickup:
	var p: Pickup = PICKUP_SCENE.instantiate()
	p.item = item
	p.position = world_pos
	add_child(p)
	return p


## Una torcia usata che il giocatore ha lasciato a terra: se è accesa continua a bruciare.
func spawn_ground_torch(world_pos: Vector3, fuel: float, max_fuel: float, lit: bool) -> GroundTorch:
	var t: GroundTorch = GROUND_TORCH_SCENE.instantiate()
	t.fuel = fuel
	t.max_fuel = max_fuel
	t.lit = lit
	t.position = world_pos
	add_child(t)
	return t


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL, 0.0, c.y * CELL)


## Inverso di cell_to_world: la cella che contiene un punto del mondo.
static func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / CELL), roundi(pos.z / CELL))


## Un modello per cella: lastre di pietra nelle stanze, terra battuta nei corridoi.
## Sopra ogni cella di pavimento c'è una lastra di soffitto.
func _add_floor_pieces(floors: Array[Vector2i], rng: RandomNumberGenerator, pieces: Dictionary[StringName, Array]) -> void:
	for c in floors:
		var model: StringName
		var rot := Basis()
		if not _in_room(c):
			model = _pick(CORRIDOR_FLOORS, rng)
			# La terra non ha fughe: girarla a quarti di giro nasconde le ripetizioni.
			rot = Basis(Vector3.UP, rng.randi_range(0, 3) * PI / 2.0)
		elif rng.randf() < floor_variant_chance:
			model = _pick(ROOM_FLOOR_VARIANTS, rng)
		else:
			model = _pick(ROOM_FLOORS, rng)
		_append_piece(pieces, model, Transform3D(rot, cell_to_world(c) - Vector3(0, FLOOR_T, 0)))
		_append_piece(pieces, &"ceiling", Transform3D(Basis(), cell_to_world(c) + Vector3(0, WALL_H, 0)))


func _pick(models: Array[StringName], rng: RandomNumberGenerator) -> StringName:
	return models[rng.randi_range(0, models.size() - 1)]


## Un pannello di muro su ogni faccia che dà sul pavimento, col lato a vista (+z) verso l'interno.
## L'origine del pannello è sulla sua faccia a vista: la si mette sul bordo della cella.
## I muri hanno una fondazione alta quanto il pavimento: si abbassano di FLOOR_T.
func _add_wall_pieces(walls: Array[Vector2i], rng: RandomNumberGenerator, pieces: Dictionary[StringName, Array]) -> void:
	for c in walls:
		for d in DIRS:
			var f := c + d
			if not gen.is_floor(f):
				continue
			var model := _pick(WALLS, rng)
			if _in_room(f) and not gen.wall_torches.has(f) and rng.randf() < shelf_chance:
				model = &"wall_shelves"
			elif rng.randf() < wall_variant_chance:
				model = &"wall_cracked"
			var rot := Basis(Vector3.UP, atan2(float(d.x), float(d.y)))
			var pos := cell_to_world(c) + Vector3(d.x, 0, d.y) * (CELL / 2.0) - Vector3(0, FLOOR_T, 0)
			_append_piece(pieces, model, Transform3D(rot, pos))


## Pilastri negli angoli dei muri (rientranti e sporgenti): coprono le giunture tra i pannelli.
## Un angolo è un vertice della griglia con 1 o 3 celle di pavimento attorno (o 2 in diagonale).
func _add_corner_pillars(pieces: Dictionary[StringName, Array]) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(pillar_width, WALL_H, pillar_width)
	for y in range(1, gen.height):
		for x in range(1, gen.width):
			# Le quattro celle attorno al vertice tra (x-1, y-1) e (x, y).
			var around: Array[Vector2i] = [Vector2i(x - 1, y - 1), Vector2i(x, y - 1), Vector2i(x - 1, y), Vector2i(x, y)]
			var floors := 0
			for c in around:
				floors += int(gen.is_floor(c))
			var diagonal := floors == 2 and gen.is_floor(around[0]) == gen.is_floor(around[3])
			if not (floors == 1 or floors == 3 or diagonal):
				continue
			var pos := cell_to_world(Vector2i(x, y)) - Vector3(CELL / 2.0, 0, CELL / 2.0)
			_append_piece(pieces, &"pillar", Transform3D(Basis().scaled(Vector3(PILLAR_GROW, 1.0, PILLAR_GROW)), pos))
			var col := CollisionShape3D.new()
			col.shape = shape
			col.position = pos + Vector3(0, WALL_H / 2.0, 0)
			body.add_child(col)


func _append_piece(pieces: Dictionary[StringName, Array], model: StringName, t: Transform3D) -> void:
	if not pieces.has(model):
		pieces[model] = []
	pieces[model].append(t)


func _in_room(c: Vector2i) -> bool:
	for r in gen.rooms:
		if r.has_point(c):
			return true
	return false


## Arredi contro il muro, girati verso la stanza; il modello varia col seed.
## La collisione è un blocco della misura del modello (le candele si scavalcano).
func _add_decorations(rng: RandomNumberGenerator, pieces: Dictionary[StringName, Array]) -> void:
	var body := StaticBody3D.new()
	add_child(body)
	for c in gen.decorations:
		var kind := gen.decorations[c]
		var models: Array = DECORATION_MODELS[kind]
		var model: StringName = models[rng.randi_range(0, models.size() - 1)]
		# Spinto verso i muri che toccano la cella (due, in un angolo).
		var push := Vector3.ZERO
		var facing := Vector2i.ZERO
		for d in DIRS:
			if not gen.is_floor(c + d):
				push += Vector3(d.x, 0, d.y)
				facing = -d
		var aabb := Voxels.mesh(model).get_aabb()
		var half := maxf(aabb.size.x, aabb.size.z) / 2.0
		var pos := cell_to_world(c) + push * maxf(CELL / 2.0 - half - 0.1, 0.0)
		var yaw := Basis(Vector3.UP, atan2(float(facing.x), float(facing.y)) + rng.randf_range(-0.3, 0.3))
		var t := Transform3D(yaw, pos)
		_append_piece(pieces, model, t)
		if kind == &"candles":
			continue
		var shape := BoxShape3D.new()
		shape.size = aabb.size
		var col := CollisionShape3D.new()
		col.shape = shape
		col.transform = Transform3D(yaw, t * aabb.get_center())
		body.add_child(col)


## Le copie di un modello in poche MultiMesh, una per blocco di chunk_cells x chunk_cells celle.
## Una MultiMesh si disegna tutta o niente: a blocchi, Godot salta quelli fuori vista
## e quelli fuori dalla portata delle luci quando calcola le ombre.
func _add_model_instances(mesh: Mesh, material: Material, transforms: Array) -> void:
	var chunks: Dictionary[Vector2i, Array] = {}
	for t: Transform3D in transforms:
		var key := Vector2i(floori(t.origin.x / (CELL * chunk_cells)), floori(t.origin.z / (CELL * chunk_cells)))
		if not chunks.has(key):
			chunks[key] = []
		chunks[key].append(t)
	for key in chunks:
		var list: Array = chunks[key]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.visibility_range_end = view_distance  # oltre, la nebbia nasconde comunque tutto
		add_child(mmi)


func _add_collision(walls: Array[Vector2i]) -> void:
	var body := StaticBody3D.new()
	add_child(body)

	var floor_shape := BoxShape3D.new()
	floor_shape.size = Vector3(gen.width * CELL, 0.2, gen.height * CELL)
	var floor_col := CollisionShape3D.new()
	floor_col.shape = floor_shape
	floor_col.position = Vector3((gen.width - 1) * CELL / 2.0, -0.1, (gen.height - 1) * CELL / 2.0)
	body.add_child(floor_col)

	var wall_shape := BoxShape3D.new()
	wall_shape.size = Vector3(CELL, WALL_H, CELL)
	for c in walls:
		var col := CollisionShape3D.new()
		col.shape = wall_shape
		col.position = cell_to_world(c) + Vector3(0, WALL_H / 2.0, 0)
		body.add_child(col)


## Il pannello della porta sta lungo x: se il passaggio va lungo x lo si ruota di 90°.
func _add_doors() -> void:
	for c in gen.doors:
		var door: Door = DOOR_SCENE.instantiate()
		door.width = CELL
		door.wall_height = WALL_H
		door.position = cell_to_world(c)
		if gen.doors[c]:
			door.rotation.y = PI / 2.0
		add_child(door)
		door.opened.connect(door_opened.emit.bind(c))
		door.closed.connect(door_closed.emit.bind(c))


## Torce appese alla faccia del muro, rivolte verso la stanza.
func _add_wall_torches() -> void:
	for c in gen.wall_torches:
		var dir := gen.wall_torches[c]
		var t: WallTorch = WALL_TORCH_SCENE.instantiate()
		t.position = cell_to_world(c) + Vector3(dir.x, 0, dir.y) * (CELL / 2.0) + Vector3(0, 1.65, 0)
		t.rotation.y = atan2(float(-dir.x), float(-dir.y))  # +z locale verso la stanza
		add_child(t)


## Uscita: un segnale luminoso e un'area che porta al piano successivo.
func _add_exit() -> void:
	var pos := cell_to_world(gen.exit_cell)

	var marker := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = 0.6
	mesh.bottom_radius = 0.6
	mesh.height = 0.05
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.6, 1.0)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 0.6, 1.0)
	mesh.material = mat
	marker.mesh = mesh
	marker.position = pos + Vector3(0, 0.03, 0)
	add_child(marker)

	var area := Area3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(CELL * 0.8, 2.0, CELL * 0.8)
	var col := CollisionShape3D.new()
	col.shape = shape
	area.add_child(col)
	area.position = pos + Vector3(0, 1.0, 0)
	area.body_entered.connect(_on_exit_body_entered)
	add_child(area)
	_exit_armed = true


func _on_exit_body_entered(body: Node3D) -> void:
	if _exit_armed and body.is_in_group("player"):
		_exit_armed = false
		exit_reached.emit()
