class_name DungeonBuilder
extends Node3D
## Costruisce in 3D il piano prodotto da DungeonGenerator.
## Prototipo con blocchi generati da codice: più avanti si passerà a una
## GridMap con i pezzi Kenney o MagicaVoxel, senza toccare il generatore.

signal exit_reached

const CELL := 2.0     ## lato di una cella in metri
const WALL_H := 3.0   ## altezza dei muri

@export var map_size := Vector2i(50, 50)
@export var wall_color := Color(0.45, 0.42, 0.40)
@export var floor_color := Color(0.32, 0.30, 0.28)

@export_group("Oggetti per piano")
@export var torches_first_floor := 4  ## torce di scorta al piano 1
@export var floors_per_torch_lost := 2  ## ogni quanti piani c'è una torcia in meno
@export var torches_min := 1
@export var flints_per_floor := 1

const PICKUP_SCENE := preload("res://scenes/pickup.tscn")

var gen: DungeonGenerator
var _exit_armed := false


func build(seed_value: int, floor_number: int = 1) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()

	gen = DungeonGenerator.new(map_size.x, map_size.y)
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

	var slab := Vector3(CELL, 0.2, CELL)
	_add_blocks(slab, floors, -0.1, floor_color)                     # pavimento
	_add_blocks(slab, floors, WALL_H + 0.1, wall_color)              # soffitto
	_add_blocks(Vector3(CELL, WALL_H, CELL), walls, WALL_H / 2.0, wall_color)
	_add_collision(walls)
	_add_exit()
	for c in gen.items:
		spawn_pickup(gen.items[c], cell_to_world(c))


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
