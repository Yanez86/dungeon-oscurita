class_name Door
extends Node3D
## Porta chiusa in un corridoio: il giocatore la apre con E.
## Blocca passaggio e luce finché è chiusa; aprirla cigola (evento rumore).
## Il pannello ruota attorno a un cardine (Pivot) su un lato del corridoio.

@export var width := 2.0           ## larghezza del passaggio (= lato di una cella)
@export var height := 2.4          ## altezza del pannello
@export var wall_height := 3.0     ## sopra il pannello, un architrave fino al soffitto
@export var thickness := 0.12
@export var open_time := 0.6       ## secondi per spalancarsi
@export var open_loudness := 0.45  ## il cigolio si sente lontano
@export var wood_color := Color(0.30, 0.19, 0.11)

var is_open := false

var _pivot := Node3D.new()
var _collision := CollisionShape3D.new()


func _ready() -> void:
	add_to_group("door")

	# Pannello: figlio del cardine, spostato di mezza larghezza.
	_pivot.position.x = -width / 2.0
	add_child(_pivot)
	var body := StaticBody3D.new()
	body.position = Vector3(width / 2.0, height / 2.0, 0.0)
	_pivot.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, height, thickness)
	_collision.shape = shape
	body.add_child(_collision)
	body.add_child(_box(Vector3(width - 0.04, height, thickness), Vector3.ZERO))

	# Architrave: chiude lo spazio tra la porta e il soffitto.
	var lintel_h := wall_height - height
	add_child(_box(Vector3(width, lintel_h, thickness * 2.0), Vector3(0, height + lintel_h / 2.0, 0)))


## Si apre allontanandosi da chi la spinge. Restituisce false se era già aperta.
func open(opener: Node3D) -> bool:
	if is_open:
		return false
	is_open = true
	_collision.set_deferred("disabled", true)  # niente urti col pannello che ruota
	var local := to_local(opener.global_position)
	var angle := PI / 2.0 if local.z > 0.0 else -PI / 2.0  # +90° porta il pannello verso -z
	create_tween().tween_property(_pivot, "rotation:y", angle, open_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	NoiseBus.emit_noise(global_position, open_loudness, opener)
	return true


func _box(size: Vector3, pos: Vector3) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var m := StandardMaterial3D.new()
	m.albedo_color = wood_color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	mesh.material = m
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	return mi
