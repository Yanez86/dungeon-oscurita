class_name KayKit
extends RefCounted
## Accesso ai modelli KayKit Dungeon Remastered (CC0, Kay Lousberg) in assets/models/kaykit/.
## Ogni .glb è una scena con un solo MeshInstance3D: qui se ne prende la mesh, una volta sola.
## L'import scarta le texture incorporate: tutti i pezzi usano lo stesso materiale.

const DIR := "res://assets/models/kaykit/"
const TEXTURE := preload("res://assets/models/kaykit/dungeon_texture.png")
const WORLD_SCALE := 0.75  ## i muri KayKit sono alti 4 m, i nostri 3 m: oggetti in proporzione

static var _meshes: Dictionary[StringName, Mesh] = {}
static var _material: StandardMaterial3D


static func mesh(model: StringName) -> Mesh:
	if not _meshes.has(model):
		var path := DIR + model + ".gltf.glb"
		if not ResourceLoader.exists(path):
			path = DIR + model + ".glb"
		var scene: Node = (load(path) as PackedScene).instantiate()
		var mi := scene.find_children("*", "MeshInstance3D", true, false)[0] as MeshInstance3D
		_meshes[model] = mi.mesh
		scene.free()
	return _meshes[model]


static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.albedo_texture = TEXTURE
	return _material


## Un MeshInstance3D pronto da aggiungere alla scena.
static func instance(model: StringName) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(model)
	mi.material_override = material()
	return mi
