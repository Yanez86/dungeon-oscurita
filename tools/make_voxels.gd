extends SceneTree
## Genera i modelli voxel di base in assets/voxels/ (file .vox, apribili in MagicaVoxel).
## Esegui con:
##   godot --headless -s res://tools/make_voxels.gd
## ATTENZIONE: sovrascrive i file. Se hai ritoccato un modello in MagicaVoxel, salvalo con un altro nome
## o togli la sua riga da _init() qui sotto.
##
## Scala: 1 voxel = 0.125 m (Voxels.VOXEL_SIZE). Cella 2 m = 16 voxel, muro 3 m = 24 voxel.
## Coordinate: x a destra, y in alto, z verso chi guarda. L'origine della mesh è al centro in x e z.

const VoxModelScript = preload("res://scripts/voxel/vox_model.gd")
const OUT := "res://assets/voxels/"
const SEED := 20260925  ## stesso seed = stessi modelli

const CELL := 16
const WALL_H := 24
const FLOOR_T := 2  ## spessore di pavimento e soffitto

# Colori base (sRGB); le sfumature si ottengono con _tone().
const STONE := Color(0.46, 0.43, 0.40)
const STONE_DARK := Color(0.30, 0.29, 0.28)
const DRESSED := Color(0.55, 0.52, 0.47)  ## pietra lavorata di stipiti e architrave
const MORTAR := Color(0.20, 0.18, 0.16)
const DIRT := Color(0.33, 0.25, 0.18)
const PEBBLE := Color(0.45, 0.43, 0.40)
const MOSS := Color(0.24, 0.33, 0.16)
const WOOD := Color(0.36, 0.23, 0.13)
const IRON := Color(0.20, 0.20, 0.21)
const RIVET := Color(0.38, 0.37, 0.36)
const WOOD_LIGHT := Color(0.47, 0.33, 0.20)
const WOOD_RED := Color(0.40, 0.20, 0.13)
const BRASS := Color(0.55, 0.42, 0.18)
const WAX := Color(0.82, 0.77, 0.64)
const WICK := Color(0.10, 0.09, 0.08)
const CLOTH := Color(0.20, 0.13, 0.08)  ## stoffa impregnata di pece della torcia

var rng := RandomNumberGenerator.new()


func _init() -> void:
	rng.seed = SEED
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var count := 0
	for name in ["floor_stone_a", "floor_stone_b", "floor_stone_c"]:
		count += _save(name, _floor_stone(false))
	count += _save("floor_stone_cracked", _floor_cracked())
	count += _save("floor_stone_moss", _floor_moss())
	for name in ["floor_dirt_a", "floor_dirt_b", "floor_dirt_c", "floor_dirt_d"]:
		count += _save(name, _floor_dirt())
	count += _save("ceiling", _ceiling())
	for name in ["wall_a", "wall_b", "wall_c"]:
		count += _save(name, _footed(_wall()))
	count += _save("wall_cracked", _footed(_wall_cracked()))
	count += _save("wall_shelves", _footed(_wall_shelves()))
	count += _save("pillar", _pillar())
	count += _save("door_frame", _door_frame())
	count += _save("door_leaf", _door_leaf())
	# I nuovi modelli vanno in fondo: così quelli sopra ricevono gli stessi numeri casuali e non cambiano.
	count += _save("barrel_small", _barrel(6, 7))
	count += _save("barrel_large", _barrel(8, 10, true))
	count += _save("barrel_stack", _barrel_stack())
	count += _save("keg", _keg())
	count += _save("crate_small", _crate(5, false))
	count += _save("crate_large", _crate(7, false))
	count += _save("crate_decorated", _crate(5, true))
	count += _save("crates_stacked", _crates_stacked())
	count += _save("trunk_small_a", _trunk(Vector3i(7, 5, 5), WOOD, IRON))
	count += _save("trunk_small_b", _trunk(Vector3i(7, 5, 5), WOOD_RED, BRASS))
	count += _save("trunk_medium_a", _trunk(Vector3i(9, 6, 5), WOOD, IRON))
	count += _save("trunk_medium_b", _trunk(Vector3i(9, 6, 5), WOOD_RED, BRASS))
	count += _save("candle", _candle())
	count += _save("candle_triple", _candle_triple())
	count += _save("candle_melted", _candle_melted())
	count += _save("wall_torch", _wall_torch())
	print("Modelli voxel salvati: %d in %s" % [count, OUT])
	quit()


func _save(name: String, m: VoxModel) -> int:
	var err := m.save(OUT + name + ".vox")
	if err != OK:
		push_error("Salvataggio di %s fallito: %s" % [name, error_string(err)])
		return 0
	return 1


## Sfumatura di un colore a passi discreti (pochi colori = palette ordinata in MagicaVoxel).
func _tone(base: Color, step: int) -> Color:
	var k := 1.0 + 0.07 * step
	return Color(clampf(base.r * k, 0, 1), clampf(base.g * k, 0, 1), clampf(base.b * k, 0, 1))


## Piccola variazione casuale per voxel: la superficie non è piatta.
func _jitter(base: Color, chance := 0.3) -> Color:
	if rng.randf() < chance:
		return _tone(base, rng.randi_range(-1, 1))
	return base


# --- Pavimenti ---------------------------------------------------------------

## Lastre 8x8 con fughe incassate. `ceiling` capovolge: le fughe stanno sotto.
func _floor_stone(ceiling: bool, base := STONE) -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(CELL, FLOOR_T, CELL))
	var face_y := 0 if ceiling else FLOOR_T - 1
	var back_y := FLOOR_T - 1 - face_y
	var slab_tone: Dictionary[Vector2i, int] = {}
	for x in CELL:
		for z in CELL:
			var slab := Vector2i(x / 8, z / 8)
			if not slab_tone.has(slab):
				slab_tone[slab] = rng.randi_range(-2, 2)
			var grout := x % 8 == 0 or z % 8 == 0
			m.paint(Vector3i(x, back_y, z), _jitter(MORTAR, 0.2) if grout else _tone(base, slab_tone[slab] - 1))
			if not grout:
				m.paint(Vector3i(x, face_y, z), _jitter(_tone(base, slab_tone[slab])))
	return m


func _floor_cracked() -> VoxModel:
	var m := _floor_stone(false)
	var top := FLOOR_T - 1
	# Una crepa che attraversa la cella.
	var z := rng.randi_range(4, 11)
	for x in CELL:
		z = clampi(z + rng.randi_range(-1, 1), 1, CELL - 1)
		m.erase_voxel(Vector3i(x, top, z))
	# Una lastra spezzata: mancano dei pezzi, sotto si vede la malta.
	var sx := 8 * rng.randi_range(0, 1)
	var sz := 8 * rng.randi_range(0, 1)
	for x in range(sx + 1, sx + 8):
		for zz in range(sz + 1, sz + 8):
			if rng.randf() < 0.45:
				m.erase_voxel(Vector3i(x, top, zz))
	return m


func _floor_moss() -> VoxModel:
	var m := _floor_stone(false)
	var top := FLOOR_T - 1
	var center := Vector2(rng.randf_range(3, 12), rng.randf_range(3, 12))
	for x in CELL:
		for z in CELL:
			var d := center.distance_to(Vector2(x, z))
			if d < 6.0 and rng.randf() < 1.0 - d / 6.0:
				var y := top if m.has_voxel(Vector3i(x, top, z)) else top - 1
				m.paint(Vector3i(x, y, z), _jitter(MOSS, 0.5))
	return m


## Terra battuta con sassi e qualche buca.
func _floor_dirt() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(CELL, FLOOR_T, CELL))
	for x in CELL:
		for z in CELL:
			m.paint(Vector3i(x, 0, z), _tone(DIRT, -2))
			var r := rng.randf()
			if r < 0.06:
				continue  # buca
			var c := _tone(PEBBLE, rng.randi_range(-1, 1)) if r < 0.11 else _jitter(DIRT, 0.5)
			m.paint(Vector3i(x, 1, z), c)
	return m


func _ceiling() -> VoxModel:
	return _floor_stone(true, STONE_DARK)


# --- Muri --------------------------------------------------------------------
# Pannello 16 x 24 x 8 (26 con la fondazione): il muro occupa z 0..3, la faccia a vista è su z = 3 (l'origine).
# Tutto ciò che sporge verso la stanza (mattoni in rilievo, mensole) sta in z 4..7.

const WALL_D := 8
const WALL_FRONT := 3


## Fondazione: il pannello scende di FLOOR_T voxel sotto il pavimento (il builder lo abbassa di tanto).
## Senza, dalle fughe incassate lungo il muro si vedrebbe il vuoto sotto la parete.
## Colore pieno, niente numeri casuali: aggiungerla non cambia gli altri modelli.
func _footed(m: VoxModel) -> VoxModel:
	var out: VoxModel = VoxModelScript.new(m.size + Vector3i(0, FLOOR_T, 0))
	for p in m.voxels:
		out.paint(p + Vector3i(0, FLOOR_T, 0), m.color_at(p))
	out.fill_box(Vector3i(0, 0, 0), Vector3i(m.size.x - 1, FLOOR_T - 1, WALL_FRONT), _tone(STONE_DARK, -2))
	return out


## Filari di mattoni 8 x 4 (malta compresa), sfalsati di mezzo mattone: il motivo si ripete ogni 16 voxel,
## quindi i pannelli vicini combaciano.
func _wall() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(CELL, WALL_H, WALL_D))
	var brick_tone: Dictionary[Vector2i, int] = {}
	var brick_out: Dictionary[Vector2i, bool] = {}
	for y in WALL_H:
		var course := y / 4
		var offset := 4 if course % 2 == 1 else 0
		for x in CELL:
			var key := Vector2i(course, ((x + offset) / 8) % 2)
			if not brick_tone.has(key):
				brick_tone[key] = rng.randi_range(-2, 1)
				brick_out[key] = rng.randf() < 0.12
			var mortar := y % 4 == 3 or (x + offset) % 8 == 7
			# Sporco in basso, fuliggine in alto.
			var grime := -1 if y < 3 or y >= WALL_H - 3 else 0
			for z in range(0, WALL_FRONT):
				m.paint(Vector3i(x, y, z), _tone(STONE_DARK, grime))
			if mortar:
				m.paint(Vector3i(x, y, WALL_FRONT - 1), _jitter(MORTAR, 0.2))
				continue
			var c := _jitter(_tone(STONE, brick_tone[key] + grime))
			m.paint(Vector3i(x, y, WALL_FRONT), c)
			if brick_out[key]:
				m.paint(Vector3i(x, y, WALL_FRONT + 1), c)
	return m


func _wall_cracked() -> VoxModel:
	var m := _wall()
	# Crepa dall'alto verso il basso.
	var x := rng.randi_range(4, 11)
	for y in range(WALL_H - 1, 4, -1):
		x = clampi(x + rng.randi_range(-1, 1), 0, CELL - 1)
		for z in range(WALL_FRONT, WALL_D):
			m.erase_voxel(Vector3i(x, y, z))
		m.paint(Vector3i(x, y, WALL_FRONT - 1), _tone(MORTAR, -2))
	# Un mattone caduto: resta il buco, e i cocci sono per terra.
	var bx := rng.randi_range(1, 8)
	var by := 4 * rng.randi_range(1, 3)
	for xx in range(bx, bx + 6):
		for yy in range(by, by + 3):
			for z in range(WALL_FRONT - 1, WALL_D):
				m.erase_voxel(Vector3i(xx, yy, z))
	for i in 5:
		m.paint(Vector3i(rng.randi_range(bx - 1, bx + 6), 0, rng.randi_range(WALL_FRONT + 1, WALL_D - 2)), _jitter(STONE))
	return m


## Muro con due mensole di legno, vasetti e libri.
func _wall_shelves() -> VoxModel:
	var m := _wall()
	for shelf_y in [7, 15]:
		m.fill_box(Vector3i(2, shelf_y, WALL_FRONT + 1), Vector3i(13, shelf_y, WALL_D - 2), _tone(WOOD, 1))
		for bx in [3, 12]:
			m.fill_box(Vector3i(bx, shelf_y - 2, WALL_FRONT + 1), Vector3i(bx, shelf_y - 1, WALL_FRONT + 1), _tone(WOOD, -1))
		var x := 3
		while x < 13:
			var r := rng.randf()
			if r < 0.35:  # vasetto
				var c := [Color(0.45, 0.30, 0.20), Color(0.30, 0.35, 0.40), Color(0.35, 0.40, 0.28)][rng.randi_range(0, 2)] as Color
				m.fill_box(Vector3i(x, shelf_y + 1, WALL_FRONT + 1), Vector3i(x + 1, shelf_y + 2, WALL_FRONT + 2), c)
				m.paint(Vector3i(x, shelf_y + 3, WALL_FRONT + 1), _tone(c, -2))
				x += 3
			elif r < 0.7:  # libri in piedi
				for i in rng.randi_range(2, 4):
					if x >= 13:
						break
					var book := [Color(0.40, 0.12, 0.10), Color(0.15, 0.22, 0.35), Color(0.20, 0.30, 0.15), Color(0.45, 0.38, 0.22)][rng.randi_range(0, 3)] as Color
					m.fill_box(Vector3i(x, shelf_y + 1, WALL_FRONT + 1), Vector3i(x, shelf_y + rng.randi_range(3, 4), WALL_FRONT + 2), book)
					x += 1
				x += 1
			else:
				x += 2
	return m


## Pilastro 6 x 24 x 6: fusto 4 x 4 a blocchi, base e capitello più larghi.
func _pillar() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(6, WALL_H, 6))
	for y in WALL_H:
		var wide := y < 2 or y >= WALL_H - 2
		var lo := 0 if wide else 1
		var hi := 5 if wide else 4
		var block_tone := [0, -1, 1, -2, 0, 1][(y / 4) % 6] as int
		for x in range(lo, hi + 1):
			for z in range(lo, hi + 1):
				var c := _tone(DRESSED, -1) if wide else _tone(STONE, block_tone)
				if not wide and y % 4 == 3:
					c = MORTAR
				m.paint(Vector3i(x, y, z), _jitter(c, 0.2))
	return m


# --- Porta -------------------------------------------------------------------
# Cornice 16 x 24 x 4 centrata sulla porta, vano 8 x 17 (1 m x 2.125 m) al centro.
# Anta 8 x 17 x 3: assi al centro (z = 1), fasce di ferro in rilievo sulle due facce.

const DOOR_W := 8
const DOOR_H := 17


func _door_frame() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(CELL, WALL_H, 4))
	var wall := _wall()
	var lo := (CELL - DOOR_W) / 2
	var hi := lo + DOOR_W - 1
	for x in CELL:
		for y in WALL_H:
			if x >= lo and x <= hi and y < DOOR_H:
				continue  # vano
			var jamb := (x == lo - 1 or x == lo - 2 or x == hi + 1 or x == hi + 2) and y < DOOR_H
			var lintel := y >= DOOR_H and y < DOOR_H + 3 and x >= lo - 2 and x <= hi + 2
			var keystone := y == DOOR_H + 3 and x >= lo + 3 and x <= hi - 3
			var c: Color
			var joint := false
			if jamb:
				joint = y % 4 == 3
				c = _tone(DRESSED, (y / 4) % 2 - 1)
			elif lintel or keystone:
				joint = x == lo + 2 or x == hi - 2
				c = _tone(DRESSED, 1 if (keystone or (x > lo + 2 and x < hi - 2)) else 0)
			else:
				# Il resto è muro: gli stessi mattoni, visti da entrambi i lati.
				var front := wall.get_voxel(Vector3i(x, y, WALL_FRONT))
				joint = front == 0
				c = wall.palette[front] if front != 0 else MORTAR
			for z in 4:
				var face := z == 0 or z == 3
				if face and joint:
					continue
				m.paint(Vector3i(x, y, z), _jitter(MORTAR if joint else c, 0.25 if face else 0.0))
	return m


func _door_leaf() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(DOOR_W, DOOR_H, 3))
	for x in DOOR_W:
		var plank := _tone(WOOD, [0, -1, 1, -1][x / 2])
		for y in DOOR_H:
			var c := _tone(plank, -2) if x % 2 == 1 and rng.randf() < 0.5 else _jitter(plank, 0.35)
			m.paint(Vector3i(x, y, 1), c)
	for band_y in [3, 12]:
		for z in [0, 2]:
			m.fill_box(Vector3i(0, band_y, z), Vector3i(DOOR_W - 1, band_y + 1, z), IRON)
			for rx in [1, DOOR_W - 2]:
				m.paint(Vector3i(rx, band_y, z), RIVET)
	# Anello della maniglia, dalla parte opposta al cardine.
	for z in [0, 2]:
		for p in [Vector2i(5, 8), Vector2i(6, 8), Vector2i(5, 6), Vector2i(6, 6), Vector2i(4, 7), Vector2i(7, 7)]:
			m.paint(Vector3i(p.x, p.y, z), IRON)
	return m


# --- Arredi ------------------------------------------------------------------
# Base in y = 0, il davanti (+z) guarda la stanza. Il builder li appoggia al muro.

## Botte verticale dentro `m` a partire da `origin`: doghe, bombata al centro, due cerchi di ferro.
func _barrel_into(m: VoxModel, origin: Vector3i, diameter: int, height: int, wood: Color) -> void:
	var center := Vector2(diameter / 2.0, diameter / 2.0)
	var hoops: Array[int] = [1, height - 2]
	for y in height:
		var r := diameter / 2.0 - (0.45 if y == 0 or y == height - 1 else 0.0)
		for x in diameter:
			for z in diameter:
				var off := Vector2(x + 0.5, z + 0.5) - center
				if off.length() > r:
					continue
				var c: Color
				if y in hoops:
					c = IRON
				elif y == height - 1 and off.length() < r - 1.0:
					c = _tone(wood, -2)  # coperchio
				else:
					var stave := int((off.angle() + PI) / TAU * 12.0) % 3  # doghe attorno all'asse
					c = _tone(wood, [0, -1, 1][stave])
				m.paint(origin + Vector3i(x, y, z), _jitter(c, 0.2))


## `tap`: rubinetto d'ottone sul davanti (il modello è un voxel più profondo).
func _barrel(diameter: int, height: int, tap := false) -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(diameter, height, diameter + (1 if tap else 0)))
	_barrel_into(m, Vector3i.ZERO, diameter, height, WOOD_LIGHT)
	if tap:
		var x := diameter / 2
		m.fill_box(Vector3i(x - 1, 2, diameter), Vector3i(x, 2, diameter), BRASS)
		m.paint(Vector3i(x, 1, diameter), BRASS)
	return m


func _barrel_stack() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(12, 14, 6))
	_barrel_into(m, Vector3i(0, 0, 0), 6, 7, WOOD_LIGHT)
	_barrel_into(m, Vector3i(6, 0, 0), 6, 7, _tone(WOOD_LIGHT, -1))
	_barrel_into(m, Vector3i(3, 7, 0), 6, 7, WOOD)
	return m


## Barilotto coricato su due culle, con il fondo e il rubinetto verso la stanza.
func _keg() -> VoxModel:
	var d := 5
	var length := 7
	var m: VoxModel = VoxModelScript.new(Vector3i(d, d + 2, length + 1))
	for z in [1, length - 2]:
		m.fill_box(Vector3i(0, 0, z), Vector3i(d - 1, 1, z), _tone(WOOD, -2))
	var center := Vector2(d / 2.0, d / 2.0)
	for z in length:
		var end := z == 0 or z == length - 1
		var r := d / 2.0 - (0.45 if end else 0.0)
		for x in d:
			for y in d:
				var off := Vector2(x + 0.5, y + 0.5) - center
				if off.length() > r:
					continue
				var c := IRON if z == 1 or z == length - 2 else _tone(WOOD_LIGHT, [0, -1, 1][int((off.angle() + PI) / TAU * 12.0) % 3])
				if end and off.length() < r - 1.0:
					c = _tone(WOOD_LIGHT, -2)
				m.paint(Vector3i(x, y + 2, z), _jitter(c, 0.2))
	m.paint(Vector3i(d / 2, 3, length), BRASS)
	m.paint(Vector3i(d / 2, 2, length), BRASS)
	return m


## Cassa: spigoli di legno scuro (o ferro), assi orizzontali e una diagonale di rinforzo sui lati.
func _crate_into(m: VoxModel, origin: Vector3i, s: int, decorated: bool) -> void:
	var frame := _tone(WOOD, -1)
	for x in s:
		for y in s:
			for z in s:
				var on := [x == 0 or x == s - 1, y == 0 or y == s - 1, z == 0 or z == s - 1]
				var edges := int(on[0]) + int(on[1]) + int(on[2])
				if edges == 0:
					continue  # interno: non si vede
				var c: Color
				if edges >= 2:
					c = IRON if decorated else frame
					if decorated and edges == 3:
						c = RIVET
				elif on[1]:
					c = _tone(WOOD_LIGHT, [0, -1][z % 2])  # coperchio ad assi
				else:
					var a := z if on[0] else x
					c = frame if a == y or a == s - 1 - y else _tone(WOOD_LIGHT, [0, -1][(y + 1) / 2 % 2])
				m.paint(origin + Vector3i(x, y, z), _jitter(c, 0.2))


func _crate(s: int, decorated: bool) -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(s, s, s))
	_crate_into(m, Vector3i.ZERO, s, decorated)
	return m


func _crates_stacked() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(7, 12, 7))
	_crate_into(m, Vector3i.ZERO, 7, false)
	_crate_into(m, Vector3i(2, 7, 1), 5, false)
	return m


## Baule: coperchio arrotondato, due fasce di metallo, serratura sul davanti.
func _trunk(size: Vector3i, wood: Color, band: Color) -> VoxModel:
	var m: VoxModel = VoxModelScript.new(size)
	var seam := size.y - 3  # ultima fila della cassa, sopra c'è il coperchio
	for x in size.x:
		for y in size.y:
			for z in size.z:
				if y == size.y - 1 and (z == 0 or z == size.z - 1):
					continue  # coperchio bombato
				var c := _tone(wood, 1 if y > seam else [0, -1][y % 2])
				if y == seam:
					c = _tone(wood, -3)
				if x == 1 or x == size.x - 2:
					c = band
				m.paint(Vector3i(x, y, z), _jitter(c, 0.2))
	var lx := size.x / 2
	m.fill_box(Vector3i(lx, seam - 1, size.z - 1), Vector3i(lx, seam + 1, size.z - 1), BRASS)
	m.paint(Vector3i(lx, seam, size.z - 1), WICK)  # buco della serratura
	return m


# Candele spente: nel buio non c'è luce regalata.

func _candle() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(3, 5, 3))
	m.fill_box(Vector3i(0, 0, 0), Vector3i(2, 0, 2), IRON)
	m.fill_box(Vector3i(1, 1, 1), Vector3i(1, 3, 1), WAX)
	m.paint(Vector3i(1, 4, 1), WICK)
	return m


func _candle_triple() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(5, 6, 3))
	m.fill_box(Vector3i(0, 0, 0), Vector3i(4, 0, 2), _tone(IRON, 1))
	var heights: Array[int] = [4, 3, 2]
	for i in 3:
		var x := i * 2
		m.fill_box(Vector3i(x, 1, 1), Vector3i(x, heights[i], 1), _tone(WAX, -i))
		m.paint(Vector3i(x, heights[i] + 1, 1), WICK)
	m.paint(Vector3i(1, 1, 1), _tone(WAX, -2))  # colature
	m.paint(Vector3i(3, 1, 2), _tone(WAX, -2))
	return m


func _candle_melted() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(3, 3, 3))
	for x in 3:
		for z in 3:
			if rng.randf() < 0.8 or (x == 1 and z == 1):
				m.paint(Vector3i(x, 0, z), _tone(WAX, -rng.randi_range(1, 2)))
	m.paint(Vector3i(1, 1, 1), WAX)
	m.paint(Vector3i(1, 2, 1), WICK)
	return m


## Torcia a muro 3 x 6 x 8, stessa convenzione dei muri: la faccia del muro è a metà profondità (z = 4),
## la torcia sporge verso +z. Piastra di ferro, anello, bastone e testa di stoffa annerita.
## La fiamma non è nel modello: la anima wall_torch.gd.
func _wall_torch() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(3, 6, WALL_D))
	m.fill_box(Vector3i(0, 0, 4), Vector3i(2, 2, 4), IRON)
	for p in [Vector2i(0, 0), Vector2i(2, 0), Vector2i(0, 2), Vector2i(2, 2)]:
		m.paint(Vector3i(p.x, p.y, 4), RIVET)
	m.fill_box(Vector3i(1, 0, 5), Vector3i(1, 3, 5), WOOD)
	m.paint(Vector3i(0, 2, 5), IRON)
	m.paint(Vector3i(2, 2, 5), IRON)
	m.paint(Vector3i(1, 2, 6), IRON)
	m.paint(Vector3i(1, 4, 5), CLOTH)
	m.paint(Vector3i(1, 5, 5), _tone(CLOTH, -4))
	return m
