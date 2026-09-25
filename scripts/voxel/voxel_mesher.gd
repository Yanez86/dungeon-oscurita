class_name VoxelMesher
extends RefCounted
## Trasforma un VoxModel in una mesh: solo le facce che danno sul vuoto, un colore per vertice
## e un'occlusione ambientale per vertice (gli spigoli rientranti si scuriscono).
## Facce vicine con lo stesso colore e la stessa ombra si fondono in un rettangolo solo
## ("greedy meshing"): molti meno triangoli, stesso aspetto.
## Origine: centro del modello in x e z, base in y = 0.

## Per ogni direzione: normale, assi u e v della faccia. u × v punta sempre lungo +normale.
const FACES: Array[Array] = [
	[Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)],
	[Vector3i(-1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)],
	[Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0)],
	[Vector3i(0, -1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0)],
	[Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 1, 0)],
	[Vector3i(0, 0, -1), Vector3i(1, 0, 0), Vector3i(0, 1, 0)],
]
## Angoli della faccia in (u, v). Godot vede davanti i triangoli in senso orario:
## per le normali positive si gira al contrario rispetto alle negative.
const CORNERS_POS: Array[Vector2i] = [Vector2i(0, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(1, 0)]
const CORNERS_NEG: Array[Vector2i] = [Vector2i(0, 0), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1)]


## Array della mesh in costruzione (una classe: i Packed*Array dentro un Dictionary si copierebbero).
class _Out:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()


## `ao_strength`: quanto si scurisce un angolo completamente chiuso (0 = niente occlusione).
static func build(model: VoxModel, voxel_size: float, ao_strength := 0.45) -> ArrayMesh:
	var out := _Out.new()
	var offset := Vector3(model.size.x / 2.0, 0.0, model.size.z / 2.0)

	for face in FACES:
		var n: Vector3i = face[0]
		var u: Vector3i = face[1]
		var v: Vector3i = face[2]
		var a := _axis(n)
		var ua := _axis(u)
		var va := _axis(v)
		var w: int = model.size[ua]
		var h: int = model.size[va]
		for s in model.size[a]:
			# Maschera della fetta: per ogni faccia visibile, colore e occlusione dei 4 angoli.
			var mask := PackedInt32Array()
			mask.resize(w * h)
			mask.fill(-1)
			for j in h:
				for i in w:
					var p := Vector3i.ZERO
					p[a] = s
					p[ua] = i
					p[va] = j
					if not model.has_voxel(p) or model.has_voxel(p + n):
						continue
					var key := model.get_voxel(p)
					for k in 4:
						key |= _ao(model, p + n, u, v, CORNERS_NEG[k]) << (8 + 2 * k)
					mask[i + j * w] = key
			_greedy(model, mask, w, h, s, a, ua, va, n, u, v, offset, voxel_size, ao_strength, out)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = out.verts
	arrays[Mesh.ARRAY_NORMAL] = out.normals
	arrays[Mesh.ARRAY_COLOR] = out.colors
	arrays[Mesh.ARRAY_INDEX] = out.indices
	var mesh := ArrayMesh.new()
	if not out.verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Copre la maschera con rettangoli: si allarga lungo u finché la chiave è uguale, poi lungo v.
## Le facce con occlusione non uniforme restano da sole (l'ombra sfumata va sui loro angoli).
static func _greedy(model: VoxModel, mask: PackedInt32Array, w: int, h: int, s: int, a: int, ua: int, va: int,
		n: Vector3i, u: Vector3i, v: Vector3i, offset: Vector3, voxel_size: float, ao_strength: float, out: _Out) -> void:
	for j in h:
		var i := 0
		while i < w:
			var key := mask[i + j * w]
			if key == -1:
				i += 1
				continue
			var qw := 1
			var qh := 1
			if _uniform_ao(key):
				while i + qw < w and mask[i + qw + j * w] == key:
					qw += 1
				var grow := true
				while grow and j + qh < h:
					for k in qw:
						if mask[i + k + (j + qh) * w] != key:
							grow = false
							break
					if grow:
						qh += 1
			for y in range(j, j + qh):
				for x in range(i, i + qw):
					mask[x + y * w] = -1
			var p := Vector3i.ZERO
			p[a] = s
			p[ua] = i
			p[va] = j
			_emit_quad(model, key, p, qw, qh, n, u, v, offset, voxel_size, ao_strength, out)
			i += qw


static func _emit_quad(model: VoxModel, key: int, p: Vector3i, qw: int, qh: int, n: Vector3i, u: Vector3i, v: Vector3i,
		offset: Vector3, voxel_size: float, ao_strength: float, out: _Out) -> void:
	var color := model.palette[key & 0xFF]
	var positive := n.x + n.y + n.z > 0
	var base := p + (n if positive else Vector3i.ZERO)
	var corners := CORNERS_POS if positive else CORNERS_NEG

	var start := out.verts.size()
	var shades: Array[float] = []
	for c in corners:
		var corner := base + u * (c.x * qw) + v * (c.y * qh)
		out.verts.append((Vector3(corner) - offset) * voxel_size)
		out.normals.append(Vector3(n))
		var ao := (key >> (8 + 2 * CORNERS_NEG.find(c))) & 3
		var shade := 1.0 - ao_strength * (1.0 - ao / 3.0)
		shades.append(shade)
		out.colors.append(Color(color.r * shade, color.g * shade, color.b * shade))
	# La diagonale segue gli angoli più chiari: l'ombra non fa "strisce" storte.
	if shades[0] + shades[2] >= shades[1] + shades[3]:
		out.indices.append_array([start, start + 1, start + 2, start, start + 2, start + 3])
	else:
		out.indices.append_array([start + 1, start + 2, start + 3, start + 1, start + 3, start])


static func _uniform_ao(key: int) -> bool:
	var ao := key >> 8
	return ao == 0 or ao == 0x55 or ao == 0xAA or ao == 0xFF


static func _axis(d: Vector3i) -> int:
	return 0 if d.x != 0 else (1 if d.y != 0 else 2)


## Occlusione di un angolo: 3 = libero, 0 = chiuso da due voxel laterali.
static func _ao(model: VoxModel, outer: Vector3i, u: Vector3i, v: Vector3i, c: Vector2i) -> int:
	var du := u * (1 if c.x == 1 else -1)
	var dv := v * (1 if c.y == 1 else -1)
	var side1 := model.has_voxel(outer + du)
	var side2 := model.has_voxel(outer + dv)
	if side1 and side2:
		return 0
	return 3 - int(side1) - int(side2) - int(model.has_voxel(outer + du + dv))
