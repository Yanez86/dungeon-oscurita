class_name Pickup
extends Node3D
## Oggetto a terra che il giocatore può raccogliere (tasto E).
## Non illumina l'ambiente: nel buio lo trovi avvicinando la torcia o passandoci accanto.
## L'aura (shader pickup_glow) brilla quando la luce lo raggiunge o il giocatore è vicino:
## un bordo luminoso attorno al modello e un alone sul pavimento sotto di lui.

const GLOW_SHADER := preload("res://shaders/pickup_glow.gdshader")

@export var item: StringName = Items.TORCH
@export var glow_color := Color(1.0, 0.8, 0.45)
@export var glow_near_radius := 2.0  ## entro questa distanza l'aura brilla anche al buio
@export_group("Bordo")
@export var glow_strength := 4.0
@export var glow_rim_power := 2.5  ## facce piatte dei voxel: più alto = brillano solo quelle viste di taglio
@export var glow_grow := 0.02      ## metri di cui il bordo sporge dal modello
@export_group("Alone a terra")
@export var halo_strength := 1.2
@export var halo_margin := 0.3     ## metri di alone oltre il bordo del modello
@export var halo_falloff := 1.5    ## più alto = alone più concentrato attorno all'oggetto

@onready var _mesh: MeshInstance3D = $Mesh

var _glow: ShaderMaterial
var _halo := MeshInstance3D.new()


func _ready() -> void:
	add_to_group("pickup")
	# Modello voxel "item_<id>" (assets/voxels/): un nuovo oggetto ha solo bisogno del suo .vox.
	_mesh.mesh = Voxels.mesh(Items.model(item))
	_mesh.material_override = _material()
	if item == Items.TORCH:
		# Il modello è in piedi (come in mano): lo si corica. Il bastone tocca terra,
		# la testa più larga affonda di un voxel nel pavimento.
		var length := _mesh.mesh.get_aabb().size.y
		_mesh.rotation = Vector3(0.0, 0.0, PI / 2.0)
		_mesh.position = Vector3(length / 2.0, Voxels.ITEM_VOXEL_SIZE / 2.0, 0.0)
	_add_halo()
	# Rotazione "casuale" ma stabile: dipende solo dalla posizione.
	rotation.y = float(absi(hash(Vector2i(roundi(position.x * 10.0), roundi(position.z * 10.0)))) % 628) / 100.0


func display_name() -> String:
	return Items.display_name(item)


## Accende o spegne l'aura (bordo e alone).
func set_glow(on: bool) -> void:
	(_mesh.material_override as StandardMaterial3D).next_pass = _glow if on else null
	_halo.visible = on


## Il materiale dei voxel più un secondo passaggio: il guscio luminoso sul bordo.
func _material() -> StandardMaterial3D:
	var m := Voxels.material().duplicate() as StandardMaterial3D
	_glow = _glow_material(false)
	_glow.set_shader_parameter("strength", glow_strength)
	_glow.set_shader_parameter("rim_power", glow_rim_power)
	_glow.set_shader_parameter("grow", glow_grow)
	m.next_pass = _glow
	return m


## Alone: un disco (ovale, se l'oggetto è lungo) appena sopra il pavimento,
## largo quanto il modello più `halo_margin` per lato.
func _add_halo() -> void:
	var box := _mesh.transform * _mesh.mesh.get_aabb()
	var plane := PlaneMesh.new()  # orizzontale, con la faccia verso l'alto
	plane.size = Vector2(box.size.x, box.size.z) + Vector2.ONE * halo_margin * 2.0
	var mat := _glow_material(true)
	mat.set_shader_parameter("strength", halo_strength)
	mat.set_shader_parameter("halo_falloff", halo_falloff)
	mat.set_shader_parameter("grow", 0.01)  # appena sopra il pavimento, niente sfarfallio
	plane.material = mat
	_halo.mesh = plane
	_halo.position = Vector3(box.get_center().x, 0.0, box.get_center().z)
	_halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_halo)


func _glow_material(halo: bool) -> ShaderMaterial:
	var glow := ShaderMaterial.new()
	glow.shader = GLOW_SHADER
	glow.set_shader_parameter("halo", halo)
	glow.set_shader_parameter("glow_color", glow_color)
	glow.set_shader_parameter("near_radius", glow_near_radius)
	glow.set_shader_parameter("near_fade", glow_near_radius + 1.0)
	return glow
