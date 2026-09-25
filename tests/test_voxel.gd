extends SceneTree
## Test di VoxModel (file .vox) e VoxelMesher. Esegui con:
##   godot --headless -s res://tests/test_voxel.gd
## Esce con codice 1 se un test fallisce.

const VoxModelScript = preload("res://scripts/voxel/vox_model.gd")
const Mesher = preload("res://scripts/voxel/voxel_mesher.gd")
const TMP := "user://test_roundtrip.vox"

var _failures := 0


func _init() -> void:
	_test_roundtrip()
	_test_mesher_culls_hidden_faces()
	_test_mesher_winding_and_origin()
	_test_assets()
	print("Test voxel: %s" % ("OK" if _failures == 0 else "%d FALLITI" % _failures))
	quit(1 if _failures > 0 else 0)


func _test_roundtrip() -> void:
	var m: VoxModel = VoxModelScript.new(Vector3i(3, 5, 2))
	m.paint(Vector3i(0, 0, 0), Color(1, 0, 0))
	m.paint(Vector3i(2, 4, 1), Color(0, 0.5, 1))
	m.paint(Vector3i(1, 2, 0), Color(1, 0, 0))
	_check(m.get_voxel(Vector3i(0, 0, 0)) == m.get_voxel(Vector3i(1, 2, 0)), "lo stesso colore riusa l'indice")
	_check(m.save(TMP) == OK, "salvataggio .vox")
	var l := VoxModelScript.load_file(TMP) as VoxModel
	_check(l != null and l.size == Vector3i(3, 5, 2), "dimensioni conservate")
	if l == null:
		return
	_check(l.voxels.size() == 3, "numero di voxel conservato")
	_check(l.color_at(Vector3i(2, 4, 1)) == Color8(0, 128, 255), "posizione e colore conservati")
	_check(l.color_at(Vector3i(0, 0, 0)) == Color8(255, 0, 0), "primo voxel conservato")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP))


func _test_mesher_culls_hidden_faces() -> void:
	var m: VoxModel = VoxModelScript.new(Vector3i(3, 1, 1))
	m.paint(Vector3i(0, 0, 0), Color.WHITE)
	_check(_triangles(Mesher.build(m, 1.0)) == 12, "un voxel: 6 facce")
	m.paint(Vector3i(1, 0, 0), Color.RED)
	_check(_triangles(Mesher.build(m, 1.0)) == 20, "due voxel vicini: la faccia in comune sparisce")
	m.paint(Vector3i(1, 0, 0), Color.WHITE)
	m.paint(Vector3i(2, 0, 0), Color.WHITE)
	_check(_triangles(Mesher.build(m, 1.0)) == 12, "tre voxel uguali in fila: le facce si fondono in un parallelepipedo")


## Godot mostra i triangoli visti in senso orario: la loro normale geometrica è opposta alla normale.
func _test_mesher_winding_and_origin() -> void:
	var m: VoxModel = VoxModelScript.new(Vector3i(2, 2, 2))
	m.paint(Vector3i(0, 0, 0), Color.WHITE)
	m.paint(Vector3i(1, 1, 1), Color.WHITE)
	var arrays := Mesher.build(m, 0.5).surface_get_arrays(0)
	var v: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var ok := true
	for i in range(0, idx.size(), 3):
		var cross := (v[idx[i + 1]] - v[idx[i]]).cross(v[idx[i + 2]] - v[idx[i]])
		ok = ok and cross.dot(n[idx[i]]) < 0.0
	_check(ok, "tutte le facce guardano verso l'esterno")
	var aabb := Mesher.build(m, 0.5).get_aabb()
	_check(aabb.position.is_equal_approx(Vector3(-0.5, 0, -0.5)) and aabb.size.is_equal_approx(Vector3.ONE), "origine al centro in x e z, base in y = 0")


## I modelli del gioco esistono e hanno le misure che il builder si aspetta.
func _test_assets() -> void:
	var expected: Dictionary[String, Vector3i] = {
		"floor_stone_a": Vector3i(16, 2, 16), "floor_dirt_a": Vector3i(16, 2, 16), "ceiling": Vector3i(16, 2, 16),
		"wall_a": Vector3i(16, 26, 8), "wall_cracked": Vector3i(16, 26, 8), "wall_shelves": Vector3i(16, 26, 8),
		"pillar": Vector3i(6, 24, 6), "door_frame": Vector3i(16, 24, 4), "door_leaf": Vector3i(8, 17, 3),
		"barrel_small": Vector3i(6, 7, 6), "crate_large": Vector3i(7, 7, 7), "trunk_small_a": Vector3i(7, 5, 5),
		"candle": Vector3i(3, 5, 3), "wall_torch": Vector3i(3, 6, 8),
		"item_torch": Vector3i(3, 10, 3), "item_flint": Vector3i(5, 2, 3),
	}
	for model in expected:
		var m := VoxModelScript.load_file("res://assets/voxels/%s.vox" % model) as VoxModel
		_check(m != null and m.size == expected[model], "modello %s con misure %s" % [model, expected[model]])


func _triangles(mesh: ArrayMesh) -> int:
	return (mesh.surface_get_arrays(0)[Mesh.ARRAY_INDEX] as PackedInt32Array).size() / 3


func _check(cond: bool, what: String) -> void:
	if not cond:
		_failures += 1
		printerr("FALLITO: " + what)
