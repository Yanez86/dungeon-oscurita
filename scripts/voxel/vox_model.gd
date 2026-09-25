class_name VoxModel
extends RefCounted
## Modello voxel in memoria, leggibile e scrivibile nel formato .vox di MagicaVoxel.
## Coordinate come in Godot: x a destra, y in alto, z verso chi guarda (il "davanti").
## MagicaVoxel ha z in alto: la conversione avviene solo quando si legge o scrive il file.

const VERSION := 150

var size: Vector3i
## posizione -> indice di palette (1-255; 0 è "vuoto")
var voxels: Dictionary[Vector3i, int] = {}
## 256 colori, indice come in MagicaVoxel (l'elemento 0 non si usa)
var palette := PackedColorArray()

var _used_colors := 0


func _init(model_size := Vector3i.ONE) -> void:
	size = model_size
	palette.resize(256)
	palette.fill(Color(0.5, 0.5, 0.5))


func has_point(p: Vector3i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.z >= 0 and p.x < size.x and p.y < size.y and p.z < size.z


func set_voxel(p: Vector3i, index: int) -> void:
	if has_point(p):
		voxels[p] = index


func erase_voxel(p: Vector3i) -> void:
	voxels.erase(p)


func get_voxel(p: Vector3i) -> int:
	return voxels.get(p, 0)


func has_voxel(p: Vector3i) -> bool:
	return voxels.has(p)


func color_at(p: Vector3i) -> Color:
	return palette[get_voxel(p)]


## Indice di palette per un colore: lo riusa se c'è già, altrimenti lo aggiunge (massimo 255).
func color_index(c: Color) -> int:
	var c8 := Color8(c.r8, c.g8, c.b8)
	for i in range(1, _used_colors + 1):
		if palette[i] == c8:
			return i
	if _used_colors >= 255:
		push_warning("VoxModel: palette piena, colore approssimato")
		return _nearest_index(c8)
	_used_colors += 1
	palette[_used_colors] = c8
	return _used_colors


## Colora un voxel con un colore qualsiasi (la palette si riempie da sola).
func paint(p: Vector3i, c: Color) -> void:
	set_voxel(p, color_index(c))


func fill_box(from: Vector3i, to: Vector3i, c: Color) -> void:
	var idx := color_index(c)
	for x in range(from.x, to.x + 1):
		for y in range(from.y, to.y + 1):
			for z in range(from.z, to.z + 1):
				set_voxel(Vector3i(x, y, z), idx)


func _nearest_index(c: Color) -> int:
	var best := 1
	var best_d := INF
	for i in range(1, 256):
		var p := palette[i]
		var d := Vector3(p.r - c.r, p.g - c.g, p.b - c.b).length_squared()
		if d < best_d:
			best_d = d
			best = i
	return best


# --- File .vox -------------------------------------------------------------
# Struttura: "VOX " + versione, poi il chunk MAIN che contiene SIZE, XYZI e RGBA.
# Ogni chunk: id (4 byte), dimensione contenuto, dimensione figli, contenuto.

## Da Godot (y in alto, z verso chi guarda) a MagicaVoxel (z in alto, y verso il fondo).
func _to_vox(p: Vector3i) -> Vector3i:
	return Vector3i(p.x, size.z - 1 - p.z, p.y)


func save(path: String) -> Error:
	var body := StreamPeerBuffer.new()
	var vox_size := Vector3i(size.x, size.z, size.y)
	_write_chunk(body, "SIZE", _ints([vox_size.x, vox_size.y, vox_size.z]))

	var xyzi := StreamPeerBuffer.new()
	xyzi.put_32(voxels.size())
	for p in voxels:
		var v := _to_vox(p)
		xyzi.put_u8(v.x)
		xyzi.put_u8(v.y)
		xyzi.put_u8(v.z)
		xyzi.put_u8(voxels[p])
	_write_chunk(body, "XYZI", xyzi.data_array)

	# RGBA: l'elemento i del file è il colore dell'indice i + 1.
	var rgba := PackedByteArray()
	for i in range(1, 257):
		var c := palette[i % 256]
		rgba.append_array(PackedByteArray([c.r8, c.g8, c.b8, 255]))
	_write_chunk(body, "RGBA", rgba)

	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer("VOX ".to_ascii_buffer())
	f.store_32(VERSION)
	f.store_buffer("MAIN".to_ascii_buffer())
	f.store_32(0)
	f.store_32(body.data_array.size())
	f.store_buffer(body.data_array)
	return OK


## Carica un .vox (il primo modello del file). Restituisce null se il file non è valido.
static func load_file(path: String) -> VoxModel:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_buffer(4).get_string_from_ascii() != "VOX ":
		push_error("VoxModel: impossibile leggere %s" % path)
		return null
	f.get_32()  # versione
	if f.get_buffer(4).get_string_from_ascii() != "MAIN":
		push_error("VoxModel: chunk MAIN mancante in %s" % path)
		return null
	f.get_32()  # MAIN non ha contenuto proprio...
	f.get_32()  # ...e i figli sono i chunk che seguono

	var model: VoxModel = null
	var raw: Array[Vector4i] = []
	var got_palette := false
	var colors := PackedColorArray()
	while f.get_position() + 12 <= f.get_length():
		var id := f.get_buffer(4).get_string_from_ascii()
		var content := f.get_32()
		var children := f.get_32()
		var next := f.get_position() + content + children
		if id == "SIZE" and model == null:
			var sx := f.get_32()
			var sy := f.get_32()
			var sz := f.get_32()
			model = VoxModel.new(Vector3i(sx, sz, sy))
		elif id == "XYZI" and raw.is_empty():
			for i in f.get_32():
				var b := f.get_buffer(4)
				raw.append(Vector4i(b[0], b[1], b[2], b[3]))
		elif id == "RGBA":
			got_palette = true
			colors.resize(256)
			for i in 256:
				var b := f.get_buffer(4)
				colors[(i + 1) % 256] = Color8(b[0], b[1], b[2])
		f.seek(next)

	if model == null:
		push_error("VoxModel: nessun modello in %s" % path)
		return null
	if got_palette:
		model.palette = colors
		model._used_colors = 255
	for r in raw:
		# Da MagicaVoxel a Godot: l'inverso di _to_vox.
		model.voxels[Vector3i(r.x, r.z, model.size.z - 1 - r.y)] = r.w
	return model


static func _ints(values: Array[int]) -> PackedByteArray:
	var s := StreamPeerBuffer.new()
	for v in values:
		s.put_32(v)
	return s.data_array


static func _write_chunk(out: StreamPeerBuffer, id: String, content: PackedByteArray) -> void:
	out.put_data(id.to_ascii_buffer())
	out.put_32(content.size())
	out.put_32(0)
	out.put_data(content)
