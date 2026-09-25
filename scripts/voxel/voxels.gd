class_name Voxels
extends RefCounted
## Accesso ai modelli voxel di assets/voxels/ (file .vox di MagicaVoxel).
## I .vox si leggono a runtime e diventano mesh una volta sola: basta salvare in MagicaVoxel
## e riavviare il gioco per vedere la modifica. I modelli base li crea tools/make_voxels.gd.

const DIR := "res://assets/voxels/"
const VOXEL_SIZE := 0.125  ## metri per voxel: una cella da 2 m è larga 16 voxel

static var _meshes: Dictionary[StringName, Mesh] = {}
static var _material: StandardMaterial3D


static func mesh(model: StringName) -> Mesh:
	if not _meshes.has(model):
		var vox := VoxModel.load_file(DIR + model + ".vox")
		_meshes[model] = VoxelMesher.build(vox, VOXEL_SIZE) if vox else BoxMesh.new()
	return _meshes[model]


## Un solo materiale per tutti i voxel: il colore arriva dai vertici.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.vertex_color_is_srgb = true  # i colori della palette sono in sRGB
		_material.roughness = 1.0
	return _material


## Un MeshInstance3D pronto da aggiungere alla scena.
static func instance(model: StringName) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh(model)
	mi.material_override = material()
	return mi
