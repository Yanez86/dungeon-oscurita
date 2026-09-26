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
		count += _save(name, _panel(_wall()))
	count += _save("wall_cracked", _panel(_wall_cracked()))
	count += _save("wall_shelves", _panel(_wall_shelves()))
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
	count += _save("item_torch", _item_torch())
	count += _save("item_flint", _item_flint())
	count += _save("item_shield", _item_shield(false))
	count += _save("item_shield_cracked", _item_shield(true))
	count += _save("item_bear_trap", _bear_trap_closed())
	count += _save("trap_bear_open", _bear_trap_open())
	count += _save("enemy_blind", _blind())
	count += _save("item_rope", _item_rope())
	count += _save("floor_spikes", _floor_spikes())
	count += _save("trap_spikes", _trap_spikes())
	count += _save("trap_plate", _trap_plate())
	count += _save("trap_grate", _trap_grate())
	count += _save("trap_cage", _trap_cage())
	count += _save("trap_chain", _trap_chain())
	count += _save("trap_wire", _trap_wire(false))
	count += _save("trap_wire_cut", _trap_wire(true))
	count += _save("trap_dart", _trap_dart())
	count += _save("trap_bells", _trap_bells())
	count += _save("door_leaf_darts", _door_leaf_darts())
	count += _save("trapdoor_leaf", _trapdoor_leaf())
	count += _save("pit_shaft", _pit_shaft())
	count += _save("pit_rope", _pit_rope())
	count += _save("boulder", _boulder())
	count += _save("boulder_rubble", _boulder_rubble())
	count += _save("boulder_shaft", _boulder_shaft())
	count += _save("ceiling_hole", _ceiling_hole())
	count += _save("item_backpack", _item_backpack())
	count += _save("item_key_gold", _item_key_gold())
	count += _save("item_coins", _item_coins())
	count += _save("item_gem", _item_gem())
	count += _save("item_chalice", _item_chalice())
	count += _save("door_leaf_gold", _door_leaf_gold())
	count += _save("stairs_down", _stairs_down())
	count += _save("wall_secret", _panel(_wall_secret()))
	count += _save("lever_plate", _lever_plate())
	count += _save("lever_handle", _lever_handle())
	count += _save("gate_bars", _gate_bars())
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


## Rifinitura comune dei pannelli: fondazione, poi via gli strati dietro la malta nelle 2 colonne a ogni estremità.
## Negli angoli sporgenti due pannelli si incrociano e la testata di uno cadrebbe sullo stesso piano
## della faccia a vista dell'altro: le due superfici si contendono i pixel e sfarfallano ("z-fighting").
## Così la testata è profonda solo 2 voxel e finisce dentro il pilastro (fusto largo ±2 voxel);
## gli strati tolti restano coperti dallo strato della malta dell'altro pannello.
## Niente numeri casuali: gli altri modelli non cambiano.
func _panel(m: VoxModel) -> VoxModel:
	var out := _footed(m)
	for y in out.size.y:
		for x in [0, 1, CELL - 2, CELL - 1]:
			if not out.has_voxel(Vector3i(x, y, WALL_FRONT - 1)):
				continue  # dietro il buco di un mattone caduto: si vedrebbe il vuoto
			for z in WALL_FRONT - 1:
				out.erase_voxel(Vector3i(x, y, z))
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


# --- Oggetti -----------------------------------------------------------------
# I modelli "item_*" usano voxel da 6,25 cm (Voxels.ITEM_VOXEL_SIZE): metà di quelli del mondo.

const ROPE := Color(0.45, 0.37, 0.24)
const FLINT_STONE := Color(0.24, 0.24, 0.27)

## Torcia 3 x 10 x 3, in piedi come quando la si tiene in mano: bastone, legatura di corda,
## testa di stoffa più larga e annerita in cima. La fiamma la aggiunge torch.gd.
func _item_torch() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(3, 10, 3))
	for y in 6:
		m.paint(Vector3i(1, y, 1), _tone(WOOD, -2 if y == 0 else [0, -1][y % 2]))
	for y in range(6, 10):
		for x in 3:
			for z in 3:
				var corner := x != 1 and z != 1
				if corner and (y == 6 or y == 9):
					continue  # testa arrotondata sopra e sotto
				var c := ROPE if y == 6 else _jitter(_tone(CLOTH, 1 if y == 7 else 0), 0.4)
				if y == 9:
					c = _tone(CLOTH, -4 if x == 1 and z == 1 else -2)
				m.paint(Vector3i(x, y, z), c)
	return m


## Acciarino 5 x 2 x 3: la selce scura dentro l'acciaio a forma di C.
func _item_flint() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(5, 2, 3))
	m.fill_box(Vector3i(0, 0, 0), Vector3i(4, 0, 0), IRON)
	m.paint(Vector3i(0, 0, 1), IRON)
	m.paint(Vector3i(4, 0, 1), IRON)
	m.paint(Vector3i(2, 0, 0), RIVET)
	for x in range(1, 4):
		for z in range(1, 3):
			m.paint(Vector3i(x, 0, z), _tone(FLINT_STONE, -1))
			if not (x == 3 and z == 2):
				m.paint(Vector3i(x, 1, z), _jitter(FLINT_STONE, 0.5))
	m.paint(Vector3i(2, 1, 1), _tone(FLINT_STONE, 3))  # scheggia chiara
	return m


## Scudo rotondo 9 x 2 x 9, coricato come quando è a terra: assi di legno, bordo di ferro, umbone al centro.
## `cracked`: una crepa lo attraversa e al bordo manca un pezzo (ha già parato un colpo).
func _item_shield(cracked: bool) -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(9, 2, 9))
	var center := Vector2(4.0, 4.0)
	for x in 9:
		for z in 9:
			var d := Vector2(x, z).distance_to(center)
			if d > 4.6:
				continue
			var c := IRON if d > 3.6 else _jitter(_tone(WOOD_LIGHT, [0, -1, -2][x % 3]), 0.25)
			m.paint(Vector3i(x, 0, z), c)
	m.fill_box(Vector3i(3, 1, 3), Vector3i(5, 1, 5), IRON)  # umbone
	m.paint(Vector3i(4, 1, 4), RIVET)
	for p in [Vector2i(4, 1), Vector2i(4, 7), Vector2i(1, 4), Vector2i(7, 4)]:
		m.paint(Vector3i(p.x, 0, p.y), RIVET)  # chiodi delle assi
	if cracked:
		for i in 5:  # crepa diagonale dal bordo all'umbone
			m.erase_voxel(Vector3i(7 - i, 0, 1 + i))
		for p in [Vector2i(8, 3), Vector2i(8, 4), Vector2i(7, 2)]:
			m.erase_voxel(Vector3i(p.x, 0, p.y))  # pezzo di bordo saltato
		m.paint(Vector3i(5, 1, 3), _tone(IRON, 2))  # umbone ammaccato
	return m


const RUST := Color(0.42, 0.25, 0.15)

## Tagliola chiusa 9 x 4 x 5: le due ganasce ad arco si toccano in alto, i denti incastrati.
## È il modello in inventario, a terra da raccogliere e dopo lo scatto.
func _bear_trap_closed() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(9, 4, 5))
	m.fill_box(Vector3i(0, 0, 2), Vector3i(8, 0, 2), IRON)  # molla
	m.fill_box(Vector3i(3, 0, 1), Vector3i(5, 0, 3), _tone(RUST, -1))  # piastra
	var arc: Array[Vector2i] = [Vector2i(1, 1), Vector2i(2, 2), Vector2i(3, 3), Vector2i(4, 3),
		Vector2i(5, 3), Vector2i(6, 2), Vector2i(7, 1)]
	for z in [1, 3]:
		for p in arc:
			m.paint(Vector3i(p.x, p.y, z), _jitter(IRON, 0.4))
	for x in [2, 4, 6]:
		m.paint(Vector3i(x, 3, 2), RIVET)  # denti incastrati
	m.paint(Vector3i(0, 0, 1), RUST)
	m.paint(Vector3i(8, 0, 3), RUST)
	return m


## Tagliola armata 9 x 2 x 9, coricata: le ganasce aperte formano un anello di denti rivolti in su,
## al centro la piastra che la fa scattare.
func _bear_trap_open() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(9, 2, 9))
	var center := Vector2(4.0, 4.0)
	for x in 9:
		for z in 9:
			var d := Vector2(x, z).distance_to(center)
			if d >= 3.4 and d <= 4.6:
				m.paint(Vector3i(x, 0, z), _jitter(IRON, 0.4))
				if (x + z) % 2 == 0 and d < 4.1:
					m.paint(Vector3i(x, 1, z), RIVET)  # denti
	m.fill_box(Vector3i(3, 0, 3), Vector3i(5, 0, 5), _tone(RUST, -1))
	m.paint(Vector3i(4, 0, 4), RUST)
	m.fill_box(Vector3i(0, 0, 4), Vector3i(2, 0, 4), IRON)  # molle ai lati, sotto le cerniere
	m.fill_box(Vector3i(6, 0, 4), Vector3i(8, 0, 4), IRON)
	return m


# --- Nemici ------------------------------------------------------------------
# I modelli "enemy_*" usano i voxel piccoli degli oggetti (6,25 cm): servono i dettagli.

const SKIN := Color(0.70, 0.66, 0.60)
const RAG := Color(0.24, 0.20, 0.16)
const MOUTH := Color(0.22, 0.05, 0.05)
const TEETH := Color(0.84, 0.80, 0.68)
const CLAW := Color(0.14, 0.12, 0.11)

## Il Cieco 12 x 28 x 8 (0,75 x 1,75 x 0,5 m), guarda verso +z: magro, pallido, curvo in avanti,
## braccia lunghe fino alle ginocchia con artigli scuri. Niente occhi: solo una bocca piena di denti.
func _blind() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(12, 28, 8))
	# Gambe sottili e piedi lunghi.
	for x in [3, 4, 7, 8]:
		m.fill_box(Vector3i(x, 1, 3), Vector3i(x, 10, 4), _jitter(SKIN, 0.3))
	for x0 in [3, 7]:
		m.fill_box(Vector3i(x0, 0, 3), Vector3i(x0 + 1, 0, 6), _tone(SKIN, -2))
		m.paint(Vector3i(x0, 0, 7), CLAW)
		m.paint(Vector3i(x0 + 1, 0, 7), CLAW)
	# Straccio ai fianchi.
	m.fill_box(Vector3i(3, 10, 2), Vector3i(8, 12, 5), _jitter(RAG, 0.4))
	m.paint(Vector3i(4, 9, 5), RAG)
	m.paint(Vector3i(7, 9, 2), RAG)
	# Busto: stretto in basso, spalle larghe e spostate in avanti (la gobba).
	for y in range(13, 21):
		var fwd := 0 if y < 17 else 1
		var half := 3 if y < 19 else 4
		m.fill_box(Vector3i(6 - half, y, 2 + fwd), Vector3i(5 + half, y, 5 + fwd), _jitter(SKIN, 0.35))
	for y in [14, 16, 18]:
		m.fill_box(Vector3i(4, y, 5 + int(y >= 17)), Vector3i(7, y, 5 + int(y >= 17)), _tone(SKIN, -3))  # costole
	m.fill_box(Vector3i(4, 17, 2), Vector3i(7, 20, 2), _tone(SKIN, 1))  # la gobba sporge dietro
	# Collo e testa protesi in avanti.
	m.fill_box(Vector3i(5, 21, 4), Vector3i(6, 21, 6), SKIN)
	m.fill_box(Vector3i(4, 22, 3), Vector3i(7, 26, 7), _jitter(SKIN, 0.25))
	m.fill_box(Vector3i(5, 27, 3), Vector3i(6, 27, 6), _tone(SKIN, -1))
	m.erase_voxel(Vector3i(4, 26, 7))  # testa arrotondata davanti
	m.erase_voxel(Vector3i(7, 26, 7))
	m.paint(Vector3i(4, 25, 7), _tone(SKIN, -2))  # dove dovrebbero esserci gli occhi, pelle liscia
	m.paint(Vector3i(7, 25, 7), _tone(SKIN, -2))
	# Ghigno: una fila di denti sopra la bocca spalancata, due zanne agli angoli.
	m.fill_box(Vector3i(4, 23, 7), Vector3i(7, 23, 7), TEETH)
	m.fill_box(Vector3i(5, 22, 7), Vector3i(6, 22, 7), MOUTH)
	m.paint(Vector3i(4, 22, 7), _tone(TEETH, -1))
	m.paint(Vector3i(7, 22, 7), _tone(TEETH, -1))
	m.paint(Vector3i(5, 22, 6), MOUTH)
	m.paint(Vector3i(6, 22, 6), MOUTH)
	# Braccia lunghe, mani con artigli in avanti.
	for x in [1, 10]:
		m.fill_box(Vector3i(x, 7, 4), Vector3i(x, 19, 4), _jitter(SKIN, 0.3))
		m.paint(Vector3i(x, 19, 5), SKIN)  # spalla
	for x0 in [0, 10]:
		m.fill_box(Vector3i(x0, 4, 4), Vector3i(x0 + 1, 6, 5), _tone(SKIN, -1))
		for x in [x0, x0 + 1]:
			m.paint(Vector3i(x, 4, 6), CLAW)
			m.paint(Vector3i(x, 3, 6), CLAW)
	return m


# --- Trappole ----------------------------------------------------------------

const HEMP := Color(0.60, 0.48, 0.30)  ## canapa della corda

## Corda arrotolata 12 x 3 x 10, coricata: due giri di spire ritorte, una legatura scura
## e il capo libero che esce dal rotolo.
func _item_rope() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(12, 3, 10))
	var center := Vector2(4.5, 4.5)
	for x in 10:
		for z in 10:
			var d := Vector2(x, z).distance_to(center)
			if d < 2.6 or d > 4.6:
				continue
			var twist := -((x + z) % 3)  # spire ritorte: righe chiare e scure in diagonale
			m.paint(Vector3i(x, 0, z), _tone(HEMP, twist - 1))
			if d > 3.0 and d < 4.3:
				m.paint(Vector3i(x, 1, z), _jitter(_tone(HEMP, twist), 0.3))
	for y in 3:  # legatura che tiene il rotolo
		m.paint(Vector3i(0, y, 4), _tone(HEMP, -4))
		m.paint(Vector3i(0, y, 5), _tone(HEMP, -4))
		m.paint(Vector3i(1, y, 4), _tone(HEMP, -3))
	for p in [Vector2i(9, 5), Vector2i(10, 6), Vector2i(11, 6), Vector2i(11, 7)]:
		m.paint(Vector3i(p.x, 0, p.y), _jitter(HEMP, 0.5))  # capo libero
	return m


# I modelli "trap_*" usano i voxel piccoli (6,25 cm) come gli oggetti; fossa, masso, botola e soffitto
# col buco hanno i voxel normali (12,5 cm) come muri e pavimenti.

const HOLE := Color(0.05, 0.045, 0.04)  ## fori e fessure: quasi nero
const BONE := Color(0.78, 0.74, 0.64)
const SPIKE_HOLES: Array[int] = [1, 3, 5, 10, 12, 14]  ## righe e colonne dei fori delle frecce (voxel normali)


## Lastra di pietra con una griglia di forellini (ci escono le frecce, vedi trap_spikes).
## Al centro resta liscia: lì c'è la piastra (trap_plate). Il fondo dei fori è buio.
func _floor_spikes() -> VoxModel:
	var m := _floor_stone(false)
	for i in SPIKE_HOLES:
		for j in SPIKE_HOLES:
			m.erase_voxel(Vector3i(i, FLOOR_T - 1, j))
			m.paint(Vector3i(i, 0, j), HOLE)
	return m


## Letto di frecce 32 x 6 x 32 (voxel piccoli: la cella intera), una sotto ogni foro di floor_spikes:
## asta di legno chiaro e punta di ferro. Sta sotto il pavimento finché la trappola non scatta.
func _trap_spikes() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(CELL * 2, 6, CELL * 2))
	for i in SPIKE_HOLES:
		for j in SPIKE_HOLES:
			# Il foro i copre i voxel piccoli 2i e 2i+1: si prende quello verso il centro (simmetria).
			var p := Vector2i(2 * i + int(i < 8), 2 * j + int(j < 8))
			m.fill_box(Vector3i(p.x, 0, p.y), Vector3i(p.x, 4, p.y), _jitter(WOOD_LIGHT, 0.4))
			m.paint(Vector3i(p.x, 5, p.y), RIVET)
	return m


## Piastra a pressione 8 x 1 x 8 (voxel piccoli, 50 cm): pietra più chiara del pavimento con un bordo scuro,
## sporge di un voxel. Chi guarda dove mette i piedi la vede.
func _trap_plate() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(8, 1, 8))
	for x in 8:
		for z in 8:
			var edge := x == 0 or z == 0 or x == 7 or z == 7
			var c := _tone(DRESSED, -4) if edge else _jitter(_tone(DRESSED, 2), 0.3)
			if (x == 3 or x == 4) and (z == 3 or z == 4):
				c = _tone(DRESSED, -1)  # segno al centro
			m.paint(Vector3i(x, 0, z), c)
	return m


## Bocchetta 10 x 8 x 5 (voxel piccoli) da murare: una cassetta di ferro che sporge dai mattoni, sbarre
## verticali sul davanti (+z) e buio dentro.
func _trap_grate() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(10, 8, 5))
	m.fill_box(Vector3i(0, 0, 0), Vector3i(9, 7, 0), HOLE)
	for x in 10:
		for y in 8:
			var frame := x == 0 or x == 9 or y == 0 or y == 7
			if frame:
				for z in range(1, 4):
					m.paint(Vector3i(x, y, z), _jitter(_tone(IRON, -1), 0.3))
			if frame or x % 2 == 1:
				m.paint(Vector3i(x, y, 4), _jitter(IRON if frame else _tone(IRON, 2), 0.3))
	return m


## Gabbia 28 x 40 x 28 (voxel piccoli: 1,75 x 2,5 m): sbarre ogni 3 voxel con la punta in basso,
## tre cerchi orizzontali e una croce di travi in cima. Base in y = 0.
func _trap_cage() -> VoxModel:
	var s := 28
	var h := 40
	var m: VoxModel = VoxModelScript.new(Vector3i(s, h, s))
	for x in s:
		for z in s:
			if not (x == 0 or z == 0 or x == s - 1 or z == s - 1):
				continue
			var bar := (x % 3 == 0 and (z == 0 or z == s - 1)) or (z % 3 == 0 and (x == 0 or x == s - 1))
			for y in range(1, h):
				if bar or y == 1 or y == h / 2 or y == h - 1:
					m.paint(Vector3i(x, y, z), _jitter(IRON, 0.4) if rng.randf() < 0.9 else RUST)
			if bar:
				m.paint(Vector3i(x, 0, z), RIVET)  # punta
	for i in s:
		m.paint(Vector3i(i, h - 1, s / 2), IRON)
		m.paint(Vector3i(s / 2, h - 1, i), IRON)
	return m


## Catena 3 x 12 x 3 (voxel piccoli, 75 cm): maglie alternate, una di taglio e una di piatto.
func _trap_chain() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(3, 12, 3))
	for link in 4:
		var y0 := link * 3
		var sides: Array[Vector3i] = [Vector3i(0, 1, 1), Vector3i(2, 1, 1)]
		if link % 2 == 1:
			sides = [Vector3i(1, 1, 0), Vector3i(1, 1, 2)]
		for p: Vector3i in sides + [Vector3i(1, 0, 1), Vector3i(1, 2, 1)]:
			m.paint(p + Vector3i(0, y0, 0), _jitter(IRON, 0.4))
	return m


## Filo teso 32 x 3 x 1 (voxel piccoli: 2 m, da muro a muro): due picchetti di ferro e la canapa chiara
## a 15 cm da terra, che luccica alla luce della torcia. `cut`: il filo spezzato, i due capi a terra.
func _trap_wire(cut: bool) -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(32, 3, 1))
	for x in [0, 31]:
		m.fill_box(Vector3i(x, 0, 0), Vector3i(x, 2, 0), IRON)
	if not cut:
		m.fill_box(Vector3i(1, 2, 0), Vector3i(30, 2, 0), _tone(HEMP, 3))
		return m
	for side in [1, -1]:
		var x0 := 0 if side == 1 else 31
		m.paint(Vector3i(x0 + side, 2, 0), _tone(HEMP, 2))
		m.paint(Vector3i(x0 + side * 2, 1, 0), _tone(HEMP, 2))
		for i in range(3, 8):
			m.paint(Vector3i(x0 + side * i, 0, 0), _tone(HEMP, 1))
	return m


## Dardo 1 x 1 x 6 (voxel piccoli): punta di ferro verso +z, asta di legno, impennaggio scuro.
func _trap_dart() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(1, 1, 6))
	m.paint(Vector3i(0, 0, 5), RIVET)
	for z in range(1, 5):
		m.paint(Vector3i(0, 0, z), WOOD_LIGHT)
	m.paint(Vector3i(0, 0, 0), CLOTH)
	return m


## Campanelli 9 x 8 x 3 (voxel piccoli): una staffa di ferro e tre campanelli d'ottone appesi a spaghi.
func _trap_bells() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(9, 8, 3))
	m.fill_box(Vector3i(0, 7, 1), Vector3i(8, 7, 1), IRON)
	for i in 3:
		var bx := 1 + i * 3
		var top := 5 if i == 1 else 6  # quello in mezzo pende un po' più giù
		for y in range(top + 1, 7):
			m.paint(Vector3i(bx, y, 1), HEMP)
		m.paint(Vector3i(bx, top, 1), _tone(BRASS, 1))
		m.fill_box(Vector3i(bx - 1, top - 2, 0), Vector3i(bx + 1, top - 1, 2), _tone(BRASS, -1))
		m.paint(Vector3i(bx, top - 1, 1), _tone(BRASS, 2))
		m.paint(Vector3i(bx, top - 3, 1), IRON)  # batacchio
	return m


## Anta della porta a dardi: come door_leaf, con quattro fori scuri all'altezza del petto (si vedono da
## entrambi i lati). Chi apre accovacciato si fa passare i dardi sopra la testa.
func _door_leaf_darts() -> VoxModel:
	var m := _door_leaf()
	for x in [1, 3, 4, 6]:
		m.paint(Vector3i(x, 10, 1), HOLE)
	return m


## Anta della botola 16 x 1 x 8 (2 m x 1 m): assi di legno chiaro, ben diverse dalla pietra attorno;
## due cardini di ferro sul lato z = 0 e una fessura scura dove le due ante si toccano (z = 7).
func _trapdoor_leaf() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(CELL, 1, 8))
	for x in CELL:
		var plank := _tone(WOOD_LIGHT, [0, -1, 1, -2][(x / 2) % 4])
		for z in 8:
			var c := _tone(plank, -3) if x % 2 == 1 and rng.randf() < 0.4 else _jitter(plank, 0.3)
			m.paint(Vector3i(x, 0, z), _tone(WOOD, -2) if z == 7 else c)
	for hx in [2, 12]:
		m.fill_box(Vector3i(hx, 0, 0), Vector3i(hx + 1, 0, 2), IRON)
		m.paint(Vector3i(hx, 0, 1), RIVET)
	return m


## Fossa 18 x 18 x 18 sotto la botola: pareti di pietra scura (dentro misura 16 voxel, cioè la cella)
## e fondo di terra con le ossa di chi c'è caduto prima. Il builder la mette 2,5 m sotto il pavimento:
## l'ultimo quarto di metro in alto è il bordo delle lastre vicine.
func _pit_shaft() -> VoxModel:
	var n := CELL + 2
	var m: VoxModel = VoxModelScript.new(Vector3i(n, n, n))
	for x in n:
		for z in n:
			m.paint(Vector3i(x, 0, z), _jitter(_tone(DIRT, -1), 0.5))
			if x == 0 or z == 0 or x == n - 1 or z == n - 1:
				for y in range(1, n):
					var joint := y % 4 == 0
					m.paint(Vector3i(x, y, z), MORTAR if joint else _jitter(_tone(STONE_DARK, (x + z + y / 4) % 3 - 1), 0.3))
	# Ossa sul fondo: un teschio e qualche osso lungo.
	m.fill_box(Vector3i(5, 1, 11), Vector3i(6, 2, 12), BONE)
	m.paint(Vector3i(5, 2, 12), HOLE)
	for p in [Vector3i(9, 1, 4), Vector3i(10, 1, 4), Vector3i(11, 1, 5), Vector3i(12, 1, 5), Vector3i(4, 1, 6), Vector3i(4, 1, 7)]:
		m.paint(p, _jitter(BONE, 0.5))
	return m


## Corda appesa 3 x 40 x 2 (voxel piccoli: 2,5 m) dal bordo della fossa al fondo: in cima il nodo attorno
## a un piolo di ferro. Il davanti (+z) guarda il centro della fossa.
func _pit_rope() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(3, 40, 2))
	for y in 37:
		m.paint(Vector3i(1, y, 1), _tone(HEMP, -(y % 3)))
	m.fill_box(Vector3i(0, 37, 1), Vector3i(2, 38, 1), _tone(HEMP, -2))
	m.fill_box(Vector3i(0, 39, 0), Vector3i(2, 39, 1), IRON)
	return m


## Masso 14 x 14 x 14 (1,75 m, quasi quanto un corridoio): pietra scura a chiazze, qualche crepa.
func _boulder() -> VoxModel:
	var n := 14
	var m: VoxModel = VoxModelScript.new(Vector3i(n, n, n))
	var center := Vector3(n / 2.0, n / 2.0, n / 2.0)
	for x in n:
		for y in n:
			for z in n:
				var d := Vector3(x + 0.5, y + 0.5, z + 0.5).distance_to(center)
				if d > n / 2.0 or d < n / 2.0 - 2.0:
					continue  # solo il guscio: l'interno non si vede
				var c := _jitter(_tone(STONE, -1 - (x / 3 + z / 4 + y / 5) % 3), 0.4)
				if rng.randf() < 0.05:
					c = MORTAR  # crepa
				m.paint(Vector3i(x, y, z), c)
	return m


## Frantumi del masso 16 x 4 x 16: sassi di varie misure sparsi nella cella, i più grossi al centro.
func _boulder_rubble() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(CELL, 4, CELL))
	for i in 26:
		var p := Vector2i(rng.randi_range(1, CELL - 3), rng.randi_range(1, CELL - 3))
		var near := Vector2(p).distance_to(Vector2(7, 7)) < 5.0
		var s := rng.randi_range(1, 3 if near else 2)
		var h := rng.randi_range(0, s - 1)
		m.fill_box(Vector3i(p.x, 0, p.y), Vector3i(p.x + s - 1, h, p.y + s - 1), _jitter(_tone(STONE, rng.randi_range(-3, 0)), 0.4))
	return m


## Pozzo 16 x 16 x 16 sopra il buco del soffitto: pareti e cima di pietra scura. Dentro aspetta il masso.
func _boulder_shaft() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(CELL, CELL, CELL))
	for x in CELL:
		for z in CELL:
			m.paint(Vector3i(x, CELL - 1, z), _tone(STONE_DARK, -2))
			if x == 0 or z == 0 or x == CELL - 1 or z == CELL - 1:
				for y in CELL - 1:
					m.paint(Vector3i(x, y, z), _jitter(_tone(STONE_DARK, -1), 0.3))
	return m


## Soffitto col buco tondo (quasi 2 m) da cui cade il masso: da sotto si vede la sua pancia di pietra.
func _ceiling_hole() -> VoxModel:
	var m := _ceiling()
	for x in CELL:
		for z in CELL:
			if Vector2(x + 0.5, z + 0.5).distance_to(Vector2(CELL / 2.0, CELL / 2.0)) < 7.4:
				for y in FLOOR_T:
					m.erase_voxel(Vector3i(x, y, z))
	return m


# --- Tesori ------------------------------------------------------------------
# Oggetti da raccogliere (voxel piccoli, come tutti gli item_*): diventano anche le icone dell'inventario,
# quindi forme semplici e contrasti forti. L'oro deve luccicare anche alla luce di una torcia.

const LEATHER := Color(0.52, 0.30, 0.15)  ## cuoio: più caldo e rossiccio del legno
const GOLD := Color(0.85, 0.64, 0.18)
const RUBY := Color(0.70, 0.07, 0.12)


## Riflesso: il colore schiarito verso il bianco (luccichio dell'oro, lampo di una gemma).
func _shine(base: Color, amount := 0.5) -> Color:
	return base.lerp(Color.WHITE, amount)


## Zaino di cuoio 8 x 9 x 5, in piedi col davanti verso +z: corpo con gli spigoli smussati, patta che copre
## la cima e ricade sul davanti, tasca frontale e due cinghie scure con le fibbie d'ottone.
func _item_backpack() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(8, 9, 5))
	for x in 8:
		for y in 8:
			if (x == 0 or x == 7) and (y == 0 or y == 7):
				continue  # spigoli smussati
			for z in 3:
				m.paint(Vector3i(x, y, z), _jitter(_tone(LEATHER, -1 if z == 0 or x == 0 or x == 7 else 0), 0.3))
	# Patta: sopra e sul davanti, più scura, con l'orlo cucito.
	var flap := _tone(LEATHER, -2)
	m.fill_box(Vector3i(1, 8, 0), Vector3i(6, 8, 2), flap)
	m.fill_box(Vector3i(1, 5, 3), Vector3i(6, 7, 3), flap)
	m.fill_box(Vector3i(1, 5, 3), Vector3i(6, 5, 3), _tone(LEATHER, -4))
	# Tasca frontale, più chiara, con la cucitura in alto.
	m.fill_box(Vector3i(2, 1, 3), Vector3i(5, 3, 3), _tone(LEATHER, 1))
	m.fill_box(Vector3i(2, 3, 3), Vector3i(5, 3, 3), _tone(LEATHER, -1))
	# Cinghie: dalla cima della patta giù fino alla tasca; le fibbie sotto l'orlo della patta.
	for x in [2, 5]:
		m.fill_box(Vector3i(x, 2, 4), Vector3i(x, 7, 4), _tone(LEATHER, -6))
		m.paint(Vector3i(x, 4, 3), _tone(LEATHER, -6))
		m.paint(Vector3i(x, 4, 4), BRASS)
		m.paint(Vector3i(x, 3, 4), _tone(BRASS, 2))
	return m


## Chiave d'oro 9 x 2 x 4, coricata: occhio ad anello, fusto con un collarino, mappa a tre denti in fondo.
## Grande e lucida, con qualche voxel più chiaro dove prende la luce.
func _item_key_gold() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(9, 2, 4))
	for x in 4:
		for z in 4:
			var corner := (x == 0 or x == 3) and (z == 0 or z == 3)
			var hole := (x == 1 or x == 2) and (z == 1 or z == 2)
			if corner or hole:
				continue
			m.paint(Vector3i(x, 0, z), _tone(GOLD, -3))
			m.paint(Vector3i(x, 1, z), GOLD)
	m.fill_box(Vector3i(4, 0, 1), Vector3i(8, 0, 1), _tone(GOLD, -1))  # fusto
	m.fill_box(Vector3i(4, 0, 0), Vector3i(4, 0, 2), _tone(GOLD, -2))  # collarino
	m.paint(Vector3i(4, 1, 1), GOLD)
	for p in [Vector2i(6, 2), Vector2i(6, 3), Vector2i(7, 2), Vector2i(8, 2), Vector2i(8, 3)]:
		m.paint(Vector3i(p.x, 0, p.y), GOLD)  # mappa: tre denti
	m.paint(Vector3i(1, 1, 0), _shine(GOLD))
	m.paint(Vector3i(0, 1, 1), _shine(GOLD, 0.3))
	m.paint(Vector3i(6, 0, 1), _shine(GOLD, 0.3))
	return m


## Pila di monete: dischetti `s` x `s` senza gli angoli (tondi, per quanto può un voxel), uno per strato,
## ognuno spostato di `shifts[i]` (x, z) da `corner`: la pila è un po' storta e si vede l'orlo di ogni moneta.
## Strati alternati chiari e scuri; quella in cima ha l'orlo più scuro e un luccichio.
func _coin_stack(m: VoxModel, corner: Vector3i, s: int, shifts: Array[Vector2i]) -> void:
	for layer in shifts.size():
		var top := layer == shifts.size() - 1
		var at := corner + Vector3i(shifts[layer].x, layer, shifts[layer].y)
		for x in s:
			for z in s:
				if (x == 0 or x == s - 1) and (z == 0 or z == s - 1):
					continue
				var rim := x == 0 or z == 0 or x == s - 1 or z == s - 1
				var col := _tone(GOLD, -1 if layer % 2 == 0 else -6)
				if top:
					col = _tone(GOLD, -4) if rim else _tone(GOLD, 1)
				m.paint(at + Vector3i(x, 0, z), col)
		if top:
			m.paint(at + Vector3i(1, 0, s - 2), _shine(GOLD, 0.45))


## Monete d'oro 8 x 4 x 7: una pila alta e una bassa (un po' storte), una moneta coricata,
## una in piedi di taglio e una sparsa.
func _item_coins() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(8, 4, 7))
	_coin_stack(m, Vector3i(0, 0, 0), 4, [Vector2i(0, 0), Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1)])
	_coin_stack(m, Vector3i(4, 0, 2), 4, [Vector2i(0, 1), Vector2i(0, 0)])
	_coin_stack(m, Vector3i(0, 0, 4), 3, [Vector2i.ZERO])
	for p in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1), Vector2i(1, 2)]:
		m.paint(Vector3i(7, p.y, p.x), _tone(GOLD, 1 if p.y == 2 else -1))  # in piedi, di taglio
	m.paint(Vector3i(5, 0, 0), _tone(GOLD, -2))
	return m


## Rubino 5 x 5 x 5 a taglio di brillante, come un diamante disegnato: tavola piatta in cima, cintura larga,
## padiglione a punta sotto. Le facce in alto sono più chiare, quelle sotto in ombra, e qualche voxel
## schiarito fa da riflesso.
func _item_gem() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(5, 5, 5))
	var radius: Array[int] = [0, 1, 2, 2, 1]  # mezza larghezza di ogni strato, dal basso
	var light: Array[int] = [-7, -6, -3, 1, 3]
	for y in 5:
		var r := radius[y]
		for x in range(2 - r, 3 + r):
			for z in range(2 - r, 3 + r):
				var d := Vector2i(x - 2, z - 2)
				if r == 2 and absi(d.x) == r and absi(d.y) == r:
					continue  # cintura senza angoli: la gemma è tonda
				var side := -signi(d.x) + signi(d.y)  # luce da sinistra e dal davanti
				m.paint(Vector3i(x, y, z), _tone(RUBY, light[y] + side))
	m.paint(Vector3i(1, 4, 3), _shine(RUBY, 0.6))  # riflessi sulla tavola e sulla corona
	m.paint(Vector3i(2, 4, 2), _shine(RUBY, 0.3))
	m.paint(Vector3i(0, 3, 2), _shine(RUBY, 0.35))
	m.paint(Vector3i(2, 1, 3), _tone(RUBY, 1))  # luce che rimbalza dentro
	return m


## Calice d'oro 5 x 7 x 5: piede largo, stelo sottile con un nodo, coppa cava in cima (il fondo è scuro)
## con tre gemmine incastonate: una davanti e una per lato.
func _item_chalice() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(5, 7, 5))
	for x in 5:
		for z in 5:
			var corner := (x == 0 or x == 4) and (z == 0 or z == 4)
			var inner := x >= 1 and x <= 3 and z >= 1 and z <= 3
			if not corner:
				m.paint(Vector3i(x, 0, z), _tone(GOLD, -2 if inner else -3))  # piede
				if not inner:
					m.paint(Vector3i(x, 5, z), _tone(GOLD, -1))  # pareti della coppa
					m.paint(Vector3i(x, 6, z), GOLD)
			if inner:
				m.paint(Vector3i(x, 4, z), _tone(GOLD, -1))  # fondo della coppa
				m.paint(Vector3i(x, 5, z), _tone(GOLD, -8))  # dentro: ombra
	m.paint(Vector3i(2, 1, 2), _tone(GOLD, -1))  # stelo
	m.paint(Vector3i(2, 2, 2), _tone(GOLD, -1))
	for d: Vector3i in [Vector3i.ZERO, Vector3i(1, 0, 0), Vector3i(-1, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 0, -1)]:
		m.paint(Vector3i(2, 3, 2) + d, GOLD)  # nodo
	m.paint(Vector3i(2, 5, 4), RUBY)
	m.paint(Vector3i(0, 5, 2), _tone(RUBY, 2))
	m.paint(Vector3i(4, 5, 2), _tone(RUBY, 2))
	m.paint(Vector3i(1, 6, 4), _shine(GOLD))  # riflessi sull'orlo
	m.paint(Vector3i(0, 6, 1), _shine(GOLD, 0.3))
	return m


# --- Porta dorata, scala, passaggio segreto ----------------------------------

const WOOD_RICH := Color(0.28, 0.14, 0.08)  ## legno scuro e pregiato della porta dorata


## Anta dorata 8 x 17 x 3, come door_leaf (assi al centro in z = 1, rilievi sulle due facce) ma di legno
## scuro con bordo, fasce e borchie d'oro, e una grande piastra della serratura col buco della chiave nero
## dal lato della maniglia (il cardine è in x = 0). Il buco è incassato: si vede anche di sbieco.
func _door_leaf_gold() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(DOOR_W, DOOR_H, 3))
	for x in DOOR_W:
		var plank := _tone(WOOD_RICH, [0, -1, 1, -1][x / 2])
		for y in DOOR_H:
			var c := _tone(plank, -2) if x % 2 == 1 and rng.randf() < 0.5 else _jitter(plank, 0.35)
			m.paint(Vector3i(x, y, 1), c)
	var top := DOOR_H - 1
	for z in [0, 2]:
		for y in DOOR_H:
			m.paint(Vector3i(0, y, z), _tone(GOLD, -3))
			m.paint(Vector3i(DOOR_W - 1, y, z), _tone(GOLD, -3))
		m.fill_box(Vector3i(0, 0, z), Vector3i(DOOR_W - 1, 0, z), _tone(GOLD, -3))
		m.fill_box(Vector3i(0, top, z), Vector3i(DOOR_W - 1, top, z), _tone(GOLD, -3))
		for band_y in [3, 12]:
			m.fill_box(Vector3i(0, band_y, z), Vector3i(DOOR_W - 1, band_y + 1, z), GOLD)
			for bx in [2, DOOR_W - 3]:
				m.paint(Vector3i(bx, band_y, z), _shine(GOLD, 0.45))  # borchie
		for p in [Vector2i(0, 0), Vector2i(DOOR_W - 1, 0), Vector2i(0, top), Vector2i(DOOR_W - 1, top)]:
			m.paint(Vector3i(p.x, p.y, z), _shine(GOLD, 0.3))  # borchie agli angoli
		# Piastra della serratura: bordo più scuro, borchie agli angoli, buco della chiave al centro.
		m.fill_box(Vector3i(4, 6, z), Vector3i(6, 10, z), _tone(GOLD, 1))
		for p in [Vector2i(4, 6), Vector2i(6, 6), Vector2i(4, 10), Vector2i(6, 10)]:
			m.paint(Vector3i(p.x, p.y, z), _tone(GOLD, -2))
		m.paint(Vector3i(5, 10, z), _shine(GOLD, 0.45))
		m.erase_voxel(Vector3i(5, 8, z))
		m.erase_voxel(Vector3i(5, 7, z))
	m.paint(Vector3i(5, 8, 1), HOLE)
	m.paint(Vector3i(5, 7, 1), HOLE)
	return m


## Scala 16 x 14 x 16 che scende nel buio verso +z e occupa una cella. Il builder la mette con la cima
## (y = 14) a livello del pavimento: pianerottolo in cima (z 0..1), sei gradini di pietra lavorata alti
## 2 voxel (x 1..14) con lo spigolo scuro, in fondo solo buio. Pareti di pietra scura a filari ai lati
## e in fondo. Più si scende più i colori si scuriscono: il buio sale dalle profondità.
func _stairs_down() -> VoxModel:
	var h := 14
	var m: VoxModel = VoxModelScript.new(Vector3i(CELL, h, CELL))
	# Pianerottolo (k = -1) e gradini (k = 0..5): blocchi pieni fino alla loro superficie.
	for k in range(-1, 6):
		var z0 := 2 + 2 * k if k >= 0 else 0
		var top := 11 - 2 * k if k >= 0 else h - 1
		var dark := -(k + 1)
		var seam := 5 + (k + 1) % 3 * 2  # fuga tra due lastre del gradino, ogni volta in un punto diverso
		for x in range(1, CELL - 1):
			for z in range(z0, z0 + 2):
				for y in top + 1:
					var c: Color
					var edge := z == z0 + 1
					if y == top:
						c = _tone(DRESSED, dark - 3) if edge else _jitter(_tone(DRESSED, dark), 0.3)
						if x == seam and not edge:
							c = _tone(DRESSED, dark - 2)
					elif edge:
						c = _jitter(_tone(DRESSED, dark - 1), 0.3)  # alzata verso il gradino sotto
					else:
						c = _tone(DRESSED, dark - 2)  # dentro: non si vede
					m.paint(Vector3i(x, y, z), c)
	m.fill_box(Vector3i(1, 0, CELL - 2), Vector3i(CELL - 2, 0, CELL - 2), HOLE)
	# Pareti: filari di blocchi 4 x 4 (malta compresa) sfalsati, il filare in cima intero a filo del pavimento.
	for x in CELL:
		for z in CELL:
			var side := x == 0 or x == CELL - 1
			if not side and z != CELL - 1:
				continue
			var along := z if side else x
			for y in h:
				var course := (h - 1 - y) / 4
				var run := along + (course % 2) * 2
				var dark := -(h - 1 - y) / 3
				var joint := (h - 1 - y) % 4 == 3 or run % 4 == 3
				var block := (run / 4 * 5 + course * 3) % 3 - 1
				m.paint(Vector3i(x, y, z), _tone(MORTAR, dark) if joint else _jitter(_tone(STONE_DARK, block + dark), 0.3))
	return m


## Muro col passaggio segreto: da lontano identico agli altri. Da vicino, con la torcia, si nota il contorno
## di una porta (9 x 20 voxel, dal pavimento): fessure più profonde e più scure della malta, e dentro
## mattoni un tono più chiari, a filo del muro (nessuno sporge). Il contorno segue le fughe dove può
## (in cima un filare di malta, ai lati le fughe verticali dei filari dispari): taglia solo metà dei mattoni.
## Coordinate di _wall(), senza fondazione.
func _wall_secret() -> VoxModel:
	var m := _wall()
	var lo := 3
	var hi := 11
	var top := 19
	for x in range(lo + 1, hi):
		for y in top:
			var p := Vector3i(x, y, WALL_FRONT)
			if m.has_voxel(p):
				m.paint(p, _tone(m.color_at(p), 1))
			m.erase_voxel(p + Vector3i(0, 0, 1))
	var slit: Array[Vector2i] = []
	for y in top + 1:
		slit.append(Vector2i(lo, y))
		slit.append(Vector2i(hi, y))
	for x in range(lo + 1, hi):
		slit.append(Vector2i(x, top))
	for s in slit:
		for z in range(WALL_FRONT - 1, WALL_D):
			m.erase_voxel(Vector3i(s.x, s.y, z))
		m.paint(Vector3i(s.x, s.y, WALL_FRONT - 2), HOLE)
	return m


# --- Leve e saracinesche -----------------------------------------------------
# I modelli "lever_*" e "gate_*" usano i voxel piccoli (6,25 cm).

## Piastra della leva 8 x 12 x 2 da murare: retro contro il muro (z = 0), faccia verso +z. Ferro col bordo
## più scuro, un rivetto per angolo, qualche macchia di ruggine, la fessura buia verticale in cui scorre
## la leva e il perno al centro (y = 6), chiaro dentro il buio della fessura.
func _lever_plate() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(8, 12, 2))
	for x in 8:
		for y in 12:
			var slot := (x == 3 or x == 4) and y >= 2 and y <= 9
			m.paint(Vector3i(x, y, 0), HOLE if slot else _tone(IRON, -2))
			if slot:
				continue
			var edge := x == 0 or x == 7 or y == 0 or y == 11
			var c := _tone(IRON, -1) if edge else _jitter(_tone(IRON, 3), 0.4)
			if not edge and rng.randf() < 0.1:
				c = _tone(RUST, rng.randi_range(-1, 0))
			m.paint(Vector3i(x, y, 1), c)
	for p in [Vector2i(1, 1), Vector2i(6, 1), Vector2i(1, 10), Vector2i(6, 10)]:
		m.paint(Vector3i(p.x, p.y, 1), RIVET)
	m.fill_box(Vector3i(3, 6, 1), Vector3i(4, 6, 1), _tone(RIVET, 2))  # perno
	return m


## Leva 2 x 10 x 2: asta di ferro dal perno (la base, y = 0) in su, impugnatura di legno negli ultimi
## 3 voxel e pomello più scuro in punta. Il codice la ruota attorno all'asse x, alla base.
func _lever_handle() -> VoxModel:
	var m: VoxModel = VoxModelScript.new(Vector3i(2, 10, 2))
	for y in 10:
		for x in 2:
			for z in 2:
				var c: Color
				if y == 9:
					c = _tone(WOOD, -3)  # pomello
				elif y >= 7:
					c = _tone(WOOD_LIGHT, -((x + z + y) % 2))
				elif y == 0:
					c = RIVET  # collare sul perno
				else:
					c = _jitter(_tone(RIVET, -3), 0.3)  # più chiara della piastra: si stacca
				m.paint(Vector3i(x, y, z), c)
	return m


## Saracinesca 16 x 34 x 2 (1 x 2,125 m: riempie il vano della porta): sbarre verticali di ferro ogni 3 voxel
## con la punta chiara in basso, tre traverse (in basso, a metà, in cima) chiodate dove incrociano le sbarre,
## qualche macchia di ruggine. Tra le sbarre ci si vede attraverso.
func _gate_bars() -> VoxModel:
	var w := CELL
	var h := 34
	var m: VoxModel = VoxModelScript.new(Vector3i(w, h, 2))
	var rails: Array[int] = [3, h / 2 - 1, h - 2]  # riga più bassa di ogni traversa (alta 2)
	for x in w:
		var bar := x % 3 == 0
		for y in h:
			var rail := false
			for r in rails:
				rail = rail or (y >= r and y <= r + 1)
			if not (bar or rail):
				continue
			for z in 2:
				var c := _jitter(IRON, 0.4) if rng.randf() < 0.93 else _tone(RUST, rng.randi_range(-1, 0))
				if bar and y == 0:
					c = RIVET  # punta
				elif bar and rail and y in rails:
					c = _tone(RIVET, -1)  # chiodo
				m.paint(Vector3i(x, y, z), c)
	return m
