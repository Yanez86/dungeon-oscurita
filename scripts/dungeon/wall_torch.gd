class_name WallTorch
extends Node3D
## Torcia appesa al muro: luce fissa che non si consuma, un piccolo rifugio nel buio.
## L'origine è sulla faccia del muro; l'asse +z locale punta verso la stanza.

@export var light_energy := 1.2
@export var light_range := 6.0
@export var light_color := Color(1.0, 0.6, 0.28)
@export var flicker_amount := 0.15

var _light := OmniLight3D.new()
var _noise := FastNoiseLite.new()
var _time := 0.0


func _ready() -> void:
	var tilt := 0.5  # radianti: la torcia sporge in avanti, in cima
	var stick_len := 0.45
	var top := Vector3(0.0, cos(tilt), sin(tilt)) * stick_len / 2.0 + Vector3(0, 0, 0.1)

	var stick := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.04
	cyl.bottom_radius = 0.025
	cyl.height = stick_len
	cyl.material = _material(Color(0.35, 0.22, 0.12), false)
	stick.mesh = cyl
	stick.position = Vector3(0, 0, 0.1)
	stick.rotation.x = tilt
	add_child(stick)

	var flame := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.07
	sphere.height = 0.16
	sphere.material = _material(light_color, true)
	flame.mesh = sphere
	flame.position = top + Vector3(0, 0.06, 0)
	add_child(flame)

	_light.light_color = light_color
	_light.omni_range = light_range
	_light.light_energy = light_energy
	_light.shadow_enabled = true  # la luce non passa attraverso i muri
	_light.position = top + Vector3(0, 0.1, 0.2)
	add_child(_light)

	# Sfasamento stabile: ogni torcia sfarfalla a modo suo.
	_noise.seed = hash(Vector2i(roundi(position.x), roundi(position.z)))
	_noise.frequency = 1.0


func _process(delta: float) -> void:
	_time += delta
	_light.light_energy = light_energy * (1.0 + _noise.get_noise_1d(_time * 8.0) * flicker_amount)


func _material(color: Color, glowing: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	if glowing:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.0
	return m
