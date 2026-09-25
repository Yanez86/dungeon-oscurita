class_name Door
extends Node3D
## Porta in un corridoio: il giocatore la apre e la richiude con E.
## Blocca passaggio e luce finché è chiusa; aprirla cigola, chiuderla fa un tonfo (eventi rumore).
## Cornice: l'arco in pietra KayKit `wall_doorway`, con un vano stretto (si passa uno alla volta).
## L'anta ruota attorno a un cardine (Pivot) su uno stipite.

@export var width := 2.0           ## larghezza del corridoio (= lato di una cella): la cornice lo chiude tutto
@export var wall_height := 3.0     ## altezza del muro (l'arco è in scala)
@export var opening := 1.0         ## larghezza del vano (metà del modello KayKit)
@export var height := 2.15         ## altezza dell'anta: arriva in cima all'arco, gli angoli finiscono nella pietra
@export var thickness := 0.1
@export var frame_depth := 0.5     ## spessore della cornice
@export var open_time := 0.6       ## secondi per spalancarsi
@export var open_loudness := 0.45  ## il cigolio si sente lontano
@export var close_loudness := 0.4  ## il tonfo della porta che si chiude
@export var clearance := 0.75      ## metri tra chi chiude e il vano (per non restare incastrati)
@export var wood_color := Color(0.30, 0.19, 0.11)
@export var iron_color := Color(0.18, 0.18, 0.19)
@export var planks := 4

## La porta si è aperta (la minimappa smette di considerarla un muro).
signal opened
## La porta si è richiusa: la minimappa già disegnata non cambia, ma la vista torna a fermarsi qui.
signal closed

var is_open := false

var _pivot := Node3D.new()
var _collision := CollisionShape3D.new()
var _tween: Tween


func _ready() -> void:
	add_to_group("door")

	_build_frame()

	# Anta: figlia del cardine, spostata di mezza larghezza.
	_pivot.position.x = -opening / 2.0
	add_child(_pivot)
	var body := StaticBody3D.new()
	body.position = Vector3(opening / 2.0, height / 2.0, 0.0)
	_pivot.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(opening, height, thickness)
	_collision.shape = shape
	body.add_child(_collision)
	_build_leaf(body)


## Arco in pietra, largo quanto il corridoio; stipiti e architrave hanno una collisione.
func _build_frame() -> void:
	var arch := KayKit.instance(&"wall_doorway")
	arch.scale = Vector3(width / 4.0, wall_height / 4.0, frame_depth)  # il modello è 4 x 4 x 1 m
	add_child(arch)
	var frame := StaticBody3D.new()
	add_child(frame)
	var jamb_w := (width - opening) / 2.0
	for side in [-1.0, 1.0]:
		_add_frame_block(frame, Vector3(jamb_w, wall_height, frame_depth),
			Vector3(side * (opening + jamb_w) / 2.0, wall_height / 2.0, 0))
	_add_frame_block(frame, Vector3(opening, wall_height - height, frame_depth),
		Vector3(0, (wall_height + height) / 2.0, 0))


func _add_frame_block(frame: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	frame.add_child(col)


## Assi verticali di tono leggermente diverso, due fasce di ferro e un anello per maniglia.
func _build_leaf(body: StaticBody3D) -> void:
	var plank_w := opening / planks
	for i in planks:
		var shade := 0.85 + 0.15 * float((i * 7) % 3) / 2.0
		var x := -opening / 2.0 + plank_w * (i + 0.5)
		body.add_child(_box(Vector3(plank_w - 0.015, height, thickness), Vector3(x, 0, 0), wood_color * shade))
	for y in [-height * 0.3, height * 0.3]:
		body.add_child(_box(Vector3(opening - 0.02, 0.07, thickness + 0.02), Vector3(0, y, 0), iron_color))
	for z in [-1.0, 1.0]:
		var ring := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = 0.035
		torus.outer_radius = 0.06
		torus.material = _material(iron_color)
		ring.mesh = torus
		ring.rotation.x = PI / 2.0
		ring.position = Vector3(opening * 0.3, -0.1, z * (thickness / 2.0 + 0.02))
		body.add_child(ring)


## Si apre allontanandosi da chi la spinge. Restituisce false se era già aperta.
func open(opener: Node3D) -> bool:
	if is_open:
		return false
	is_open = true
	_collision.set_deferred("disabled", true)  # niente urti col pannello che ruota
	var local := to_local(opener.global_position)
	var angle := PI / 2.0 if local.z > 0.0 else -PI / 2.0  # +90° porta il pannello verso -z
	_swing_to(angle)
	NoiseBus.emit_noise(global_position, open_loudness, opener)
	opened.emit()
	return true


## Vero se `body` è abbastanza fuori dal vano da non finire dentro il pannello.
func can_close(body: Node3D) -> bool:
	return absf(to_local(body.global_position).z) >= clearance


## Richiude la porta. Restituisce false se era già chiusa o se `closer` è nel vano.
func close(closer: Node3D) -> bool:
	if not is_open or not can_close(closer):
		return false
	is_open = false
	_collision.set_deferred("disabled", false)
	_swing_to(0.0)
	NoiseBus.emit_noise(global_position, close_loudness, closer)
	closed.emit()
	return true


## Ruota il pannello (un Tween anima una proprietà nel tempo); un nuovo movimento interrompe il precedente.
func _swing_to(angle: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_pivot, "rotation:y", angle, open_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


func _box(size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = _material(color)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	return mi


func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.9
	return m
