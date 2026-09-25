class_name Pickup
extends Node3D
## Oggetto a terra che il giocatore può raccogliere (tasto E).
## Non illumina l'ambiente: nel buio lo trovi avvicinando la torcia o passandoci accanto.
## Il bordo brilla quando la luce lo raggiunge o il giocatore è vicino (shader pickup_glow).

const GLOW_SHADER := preload("res://shaders/pickup_glow.gdshader")

@export var item: StringName = Items.TORCH
@export var glow_color := Color(1.0, 0.8, 0.45)
@export var glow_strength := 2.5
@export var glow_rim_power := 5.0  ## facce piatte dei voxel: più alto = brillano solo quelle viste di taglio
@export var glow_near_radius := 1.5  ## entro questa distanza il bordo brilla anche al buio

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	add_to_group("pickup")
	# Modello voxel "item_<id>" (assets/voxels/): un nuovo oggetto ha solo bisogno del suo .vox.
	_mesh.mesh = Voxels.mesh(StringName("item_" + item))
	_mesh.material_override = _material()
	if item == Items.TORCH:
		# Il modello è in piedi (come in mano): lo si corica. Il bastone tocca terra,
		# la testa più larga affonda di un voxel nel pavimento.
		var length := _mesh.mesh.get_aabb().size.y
		_mesh.rotation = Vector3(0.0, 0.0, PI / 2.0)
		_mesh.position = Vector3(length / 2.0, Voxels.ITEM_VOXEL_SIZE / 2.0, 0.0)
	# Rotazione "casuale" ma stabile: dipende solo dalla posizione.
	rotation.y = float(absi(hash(Vector2i(roundi(position.x * 10.0), roundi(position.z * 10.0)))) % 628) / 100.0


func display_name() -> String:
	return Items.display_name(item)


## Il materiale dei voxel più un secondo passaggio: il guscio luminoso sul bordo.
func _material() -> StandardMaterial3D:
	var m := Voxels.material().duplicate() as StandardMaterial3D
	var glow := ShaderMaterial.new()
	glow.shader = GLOW_SHADER
	glow.set_shader_parameter("glow_color", glow_color)
	glow.set_shader_parameter("strength", glow_strength)
	glow.set_shader_parameter("rim_power", glow_rim_power)
	glow.set_shader_parameter("near_radius", glow_near_radius)
	glow.set_shader_parameter("near_fade", glow_near_radius + 1.0)
	m.next_pass = glow
	return m
