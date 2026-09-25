class_name Pickup
extends Node3D
## Oggetto a terra che il giocatore può raccogliere (tasto E).
## Non emette luce: nel buio lo trovi solo avvicinando la torcia.

@export var item: StringName = Items.TORCH

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
	return m
