class_name WallTorch
extends Node3D
## Torcia appesa al muro: luce fissa che non si consuma, un piccolo rifugio nel buio.
## L'origine è sulla faccia del muro; l'asse +z locale punta verso la stanza.

@export var light_energy := 1.2
@export var light_range := 6.0
@export var light_color := Color(1.0, 0.6, 0.28)
@export var flicker_amount := 0.15
@export var gust_amount := 0.1
@export var sway := 0.03  ## metri: la fiamma ondeggia e le ombre danzano

const HEAD := Vector3(0.0, 0.75, 0.1875)  ## cima della testa della torcia nel modello voxel

var _light := OmniLight3D.new()
var _flame := MeshInstance3D.new()
var _noise := FastNoiseLite.new()
var _time := 0.0
var _light_base := Vector3.ZERO


func _ready() -> void:
	# Modello voxel: l'origine è sulla faccia del muro, la torcia sporge lungo +z.
	add_child(Voxels.instance(&"wall_torch"))
	var top := HEAD

	# Fiamma: un voxel luminoso poco più alto che largo.
	var box := BoxMesh.new()
	box.size = Vector3(Voxels.VOXEL_SIZE, Voxels.VOXEL_SIZE * 1.5, Voxels.VOXEL_SIZE)
	box.material = _material(light_color, true)
	_flame.mesh = box
	_flame.position = top + Vector3(0, box.size.y / 2.0, 0)
	add_child(_flame)

	_light.light_color = light_color
	_light.omni_range = light_range
	_light.light_energy = light_energy
	_light.shadow_enabled = true  # la luce non passa attraverso i muri
	_light_base = top + Vector3(0, 0.1, 0.2)
	_light.position = _light_base
	add_child(_light)

	# Sfasamento stabile: ogni torcia sfarfalla a modo suo.
	_noise.seed = hash(Vector2i(roundi(position.x), roundi(position.z)))
	_noise.frequency = 1.0


func _process(delta: float) -> void:
	_time += delta
	var fast := _noise.get_noise_1d(_time * 8.0) * flicker_amount
	var gust := _noise.get_noise_1d(_time * 1.5 + 100.0) * gust_amount
	_light.light_energy = light_energy * (1.0 + fast + gust)
	_light.position = _light_base + Vector3(
		_noise.get_noise_1d(_time * 6.0 + 200.0),
		_noise.get_noise_1d(_time * 6.0 + 300.0),
		0.0) * sway
	# La fiamma si allunga e si accorcia insieme alla luce.
	_flame.scale = Vector3(1.0 - fast * 0.5, 1.0 + fast * 1.5 + gust, 1.0 - fast * 0.5)


func _material(color: Color, glowing: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	if glowing:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = 2.0
	return m
