class_name DungeonBuilder
extends Node3D
## Costruisce in 3D il piano prodotto da DungeonGenerator.
## Pavimento e muri usano i pezzi KayKit Dungeon Remastered (CC0, Kay Lousberg),
## riscalati sulla cella da 2 m; le collisioni restano blocchi semplici.

signal exit_reached
## Una porta si è aperta: `cell` è la sua cella nella griglia del generatore.
signal door_opened(cell: Vector2i)
## Una porta si è richiusa.
signal door_closed(cell: Vector2i)

const CELL := 2.0     ## lato di una cella in metri
const WALL_H := 3.0   ## altezza dei muri

@export var map_size := Vector2i(50, 50)
@export var ceiling_color := Color(0.22, 0.20, 0.19)

@export_group("Aspetto")
@export var floor_variant_chance := 0.2  ## piastrelle rotte o con erbacce
@export var wall_variant_chance := 0.25  ## muri crepati
@export var shelf_chance := 0.06         ## scaffali, solo nelle stanze

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
const DOOR_SCENE := preload("res://scenes/door.tscn")
const WALL_TORCH_SCENE := preload("res://scenes/wall_torch.tscn")
const KAYKIT_DIR := "res://assets/models/kaykit/"
const KAYKIT_TEXTURE := preload("res://assets/models/kaykit/dungeon_texture.png")
const MODEL_SIZE := 4.0  ## i muri KayKit sono larghi e alti 4 m, spessi 1 m

const ROOM_FLOORS: Array[StringName] = [&"floor_tile_small_broken_A", &"floor_tile_small_broken_B", &"floor_tile_small_weeds_A", &"floor_tile_small_weeds_B"]
const CORRIDOR_FLOORS: Array[StringName] = [&"floor_dirt_small_A", &"floor_dirt_small_B", &"floor_dirt_small_C", &"floor_dirt_small_D"]
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]

var gen: DungeonGenerator
var _exit_armed := false
var _kaykit_material: StandardMaterial3D
var _mesh_cache: Dictionary[StringName, Mesh] = {}


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
	var pieces: Dictionary[StringName, Array] = {}
	_add_floor_pieces(floors, rng, pieces)
	_add_wall_pieces(walls, rng, pieces)
	for model in pieces:
		_add_model_instances(model, pieces[model])
	_add_blocks(Vector3(CELL, 0.2, CELL), floors, WALL_H + 0.1, ceiling_color)  # soffitto
	_add_collision(walls)
	_add_exit()
	for c in gen.items:
		spawn_pickup(gen.items[c], cell_to_world(c))
	_add_doors()
	_add_wall_torches()


## Le torce diventano più rare scendendo (GDD: generazione procedurale).
func torches_for_floor(floor_number: int) -> int:
	var lost := floori(float(floor_number - 1) / maxi(floors_per_torch_lost, 1))
	return maxi(torches_min, torches_first_floor - lost)


## Crea un oggetto a terra. Usato dal generatore e quando il giocatore lascia qualcosa.
## Gli oggetti sono figli del dungeon, così spariscono quando si cambia piano.
func spawn_pickup(item: StringName, world_pos: Vector3) -> Pickup:
	var p: Pickup = PICKUP_SCENE.instantiate()
	p.item = item
	p.position = world_pos
	add_child(p)
	return p


func cell_to_world(c: Vector2i) -> Vector3:
	return Vector3(c.x * CELL, 0.0, c.y * CELL)


## Inverso di cell_to_world: la cella che contiene un punto del mondo.
static func world_to_cell(pos: Vector3) -> Vector2i:
	return Vector2i(roundi(pos.x / CELL), roundi(pos.z / CELL))


## Una piastrella per cella: pietra nelle stanze, terra battuta nei corridoi.
func _add_floor_pieces(floors: Array[Vector2i], rng: RandomNumberGenerator, pieces: Dictionary[StringName, Array]) -> void:
	for c in floors:
		var model := &"floor_tile_small"
		if not _in_room(c):
			model = CORRIDOR_FLOORS[rng.randi_range(0, CORRIDOR_FLOORS.size() - 1)]
		elif rng.randf() < floor_variant_chance:
			model = ROOM_FLOORS[rng.randi_range(0, ROOM_FLOORS.size() - 1)]
		# Rotazione a quarti di giro: le piastrelle uguali non sembrano ripetute.
		var rot := Basis(Vector3.UP, rng.randi_range(0, 3) * PI / 2.0)
		_append_piece(pieces, model, Transform3D(rot, cell_to_world(c) + Vector3(0, -0.05, 0)))


## Un pannello di muro su ogni faccia che dà sul pavimento, col lato decorato (+z) verso l'interno.
func _add_wall_pieces(walls: Array[Vector2i], rng: RandomNumberGenerator, pieces: Dictionary[StringName, Array]) -> void:
	var size := Vector3(CELL / MODEL_SIZE, WALL_H / MODEL_SIZE, 0.5)
	for c in walls:
		for d in DIRS:
			var f := c + d
			if not gen.is_floor(f):
				continue
			var model := &"wall"
			if _in_room(f) and not gen.wall_torches.has(f) and rng.randf() < shelf_chance:
				model = &"wall_shelves"
			elif rng.randf() < wall_variant_chance:
				model = &"wall_cracked"
			var rot := Basis(Vector3.UP, atan2(float(d.x), float(d.y))).scaled_local(size)
			# Il pannello (spesso 0.5 m dopo la scala) sta dentro la cella del muro, a filo col bordo.
			var pos := cell_to_world(c) + Vector3(d.x, 0, d.y) * (CELL / 2.0 - 0.25)
			_append_piece(pieces, model, Transform3D(rot, pos))


func _append_piece(pieces: Dictionary[StringName, Array], model: StringName, t: Transform3D) -> void:
	if not pieces.has(model):
		pieces[model] = []
	pieces[model].append(t)


func _in_room(c: Vector2i) -> bool:
	for r in gen.rooms:
		if r.has_point(c):
			return true
	return false


## Tutte le copie di un modello KayKit in un'unica MultiMesh.
func _add_model_instances(model: StringName, transforms: Array) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _kaykit_mesh(model)
	mm.instance_count = transforms.size()
	for i in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = _shared_kaykit_material()
	add_child(mmi)


## La mesh dentro il file .glb (una scena con un solo MeshInstance3D), caricata una volta sola.
func _kaykit_mesh(model: StringName) -> Mesh:
	if not _mesh_cache.has(model):
		var path := KAYKIT_DIR + model + ".gltf.glb"
		if not ResourceLoader.exists(path):
			path = KAYKIT_DIR + model + ".glb"
		var scene: Node = (load(path) as PackedScene).instantiate()
		var mi := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		_mesh_cache[model] = mi.mesh
		scene.free()
	return _mesh_cache[model]


## Tutti i pezzi KayKit condividono la stessa texture a palette: un solo materiale.
func _shared_kaykit_material() -> StandardMaterial3D:
	if _kaykit_material == null:
		_kaykit_material = StandardMaterial3D.new()
		_kaykit_material.albedo_texture = KAYKIT_TEXTURE
	return _kaykit_material


## Tutti i blocchi uguali in un'unica MultiMesh: veloce anche con migliaia di celle.
func _add_blocks(size: Vector3, cells: Array[Vector2i], y: float, color: Color) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _toon_material(color)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = cells.size()
	for i in cells.size():
		mm.set_instance_transform(i, Transform3D(Basis(), cell_to_world(cells[i]) + Vector3(0, y, 0)))
		# Leggera variazione di tono per blocco: aiuta a leggere la profondità.
		var shade := 0.82 + 0.18 * float(absi(hash(cells[i] + Vector2i(int(y * 10), 0))) % 100) / 100.0
		mm.set_instance_color(i, Color(shade, shade, shade))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
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
		t.position = cell_to_world(c) + Vector3(dir.x, 0, dir.y) * (CELL / 2.0) + Vector3(0, 1.9, 0)
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


func _toon_material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.vertex_color_use_as_albedo = true  # usa la variazione di tono della MultiMesh
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON   # cel shading di base
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	return m
