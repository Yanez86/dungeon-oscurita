class_name Pickup
extends Node3D
## Oggetto a terra che il giocatore può raccogliere (tasto E).
## Non illumina l'ambiente: nel buio lo trovi avvicinando la torcia o passandoci accanto.
## Il bordo brilla quando la luce lo raggiunge o il giocatore è vicino (shader pickup_glow).

const GLOW_SHADER := preload("res://shaders/pickup_glow.gdshader")

@export var item: StringName = Items.TORCH
@export var glow_color := Color(1.0, 0.8, 0.45)
@export var glow_strength := 2.5
@export var glow_near_radius := 1.5  ## entro questa distanza il bordo brilla anche al buio

@onready var _mesh: MeshInstance3D = $Mesh


func _ready() -> void:
	add_to_group("pickup")
	match item:
		Items.TORCH:
			var m := CylinderMesh.new()
			m.top_radius = 0.05
			m.bottom_radius = 0.035
			m.height = 0.55
			m.material = _material(Color(0.42, 0.26, 0.14))
			_mesh.mesh = m
			_mesh.rotation = Vector3(0.0, 0.0, PI / 2.0)  # coricata a terra
			_mesh.position.y = 0.05
		Items.FLINT:
			var m := BoxMesh.new()
			m.size = Vector3(0.14, 0.05, 0.09)
			m.material = _material(Color(0.55, 0.55, 0.6))
			_mesh.mesh = m
			_mesh.position.y = 0.025
	# Rotazione "casuale" ma stabile: dipende solo dalla posizione.
	rotation.y = float(absi(hash(Vector2i(roundi(position.x * 10.0), roundi(position.z * 10.0)))) % 628) / 100.0


func display_name() -> String:
	return Items.display_name(item)


func _material(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	m.specular_mode = BaseMaterial3D.SPECULAR_TOON
	# Secondo passaggio: il guscio luminoso sul bordo.
	var glow := ShaderMaterial.new()
	glow.shader = GLOW_SHADER
	glow.set_shader_parameter("glow_color", glow_color)
	glow.set_shader_parameter("strength", glow_strength)
	glow.set_shader_parameter("near_radius", glow_near_radius)
	glow.set_shader_parameter("near_fade", glow_near_radius + 1.0)
	m.next_pass = glow
	return m
