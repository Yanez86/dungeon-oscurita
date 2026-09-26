class_name Trapdoor
extends Trap
## Botola: un quadrato di assi chiare nel pavimento di pietra di una stanza, sopra una fossa profonda.
## Calpestata scricchiola; dopo warn_time le ante si spalancano verso il basso e chi è ancora sopra
## precipita: la torcia gli sfugge di mano e cade sul fondo. Si risale solo con una corda (E, vedi
## Player._climb_out), che poi resta appesa per chi cade dopo. Senza corda non se ne esce: da soli si
## muore dopo `despair_time` secondi; se ci sono altri giocatori il tempo è `coop_despair_time`, perché
## un compagno possa calare una corda (hang_rope). La botola resta aperta.

## Le ante si sono spalancate: da ora la cella è un buco (il builder lo segna nella mappa dei nemici).
signal opened

@export var depth := 2.5              ## metri dal pavimento al fondo della fossa (modello pit_shaft)
@export var fall_damage := 1
@export var despair_time := 10.0      ## da soli, senza corda: secondi prima della fine
@export var coop_despair_time := 60.0 ## con altri giocatori vivi: il tempo perché qualcuno cali una corda
@export var swing_time := 0.35        ## secondi per spalancare le ante
@export var open_loudness := 0.5      ## le ante che sbattono contro le pareti della fossa
@export var land_loudness := 0.4      ## il tonfo di chi cade
@export var cause := "la fossa"

var exit_dir := Vector2i.RIGHT  ## lato da cui si risale, verso una cella libera (lo imposta il builder)

var _pivots: Array[Node3D] = []
var _lid := CollisionShape3D.new()  ## le ante chiuse reggono chi ci cammina sopra
var _rope: MeshInstance3D
var _has_rope := false
var _inside: Dictionary[Player, float] = {}  ## giocatori nella fossa -> secondi passati senza via d'uscita
var _landed: Dictionary[Player, bool] = {}


func _init() -> void:
	warn_time = 0.6
	trigger_sound = &"trap_creak"
	trigger_loudness = 0.15
	plate_half_size = 0.75  # la botola è quasi tutta la cella


func _ready() -> void:
	var shaft := Voxels.instance(&"pit_shaft")
	shaft.position.y = -depth
	add_child(shaft)
	_add_collision()
	# Due ante incernierate sui lati opposti (z = -1 e z = +1): si incontrano al centro.
	for s: float in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position.z = s * DungeonBuilder.CELL / 2.0
		pivot.rotation.y = 0.0 if s < 0.0 else PI  # +z locale verso il centro della botola
		add_child(pivot)
		var leaf := Voxels.instance(&"trapdoor_leaf")
		var size := leaf.mesh.get_aabb().size
		leaf.position = Vector3(0, -size.y, size.z / 2.0)
		pivot.add_child(leaf)
		_pivots.append(pivot)
	_rope = Voxels.instance(&"pit_rope")
	var side := Vector3(exit_dir.x, 0, exit_dir.y)
	var rope_d := _rope.mesh.get_aabb().size.z
	_rope.position = side * (DungeonBuilder.CELL / 2.0 - rope_d / 2.0) + Vector3.UP * (_bottom_y() - 0.1)
	_rope.rotation.y = atan2(-side.x, -side.z)
	_rope.visible = false
	add_child(_rope)


## Pareti e fondo della fossa, più il coperchio (le ante chiuse) a filo del pavimento.
func _add_collision() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	var half := DungeonBuilder.CELL / 2.0
	var bottom := BoxShape3D.new()
	bottom.size = Vector3(DungeonBuilder.CELL + 0.4, 0.2, DungeonBuilder.CELL + 0.4)
	_add_shape(body, bottom, Vector3(0, _bottom_y() - 0.1, 0))
	for i in 4:
		var along_x := i < 2
		var s := 1.0 if i % 2 == 0 else -1.0
		var wall := BoxShape3D.new()
		wall.size = Vector3(DungeonBuilder.CELL + 0.4, depth, 0.2) if along_x else Vector3(0.2, depth, DungeonBuilder.CELL + 0.4)
		_add_shape(body, wall, Vector3(0, -depth / 2.0, s * (half + 0.1)) if along_x else Vector3(s * (half + 0.1), -depth / 2.0, 0))
	var lid := BoxShape3D.new()
	lid.size = Vector3(DungeonBuilder.CELL, 0.2, DungeonBuilder.CELL)
	_lid.shape = lid
	_lid.position.y = -0.1
	body.add_child(_lid)


func _add_shape(body: StaticBody3D, shape: Shape3D, pos: Vector3) -> void:
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	body.add_child(col)


## Il fondo della fossa (sopra lo strato di terra del modello).
func _bottom_y() -> float:
	return -depth + Voxels.VOXEL_SIZE


## Le ante si spalancano verso il basso: il coperchio non regge più.
func _spring() -> void:
	_lid.set_deferred("disabled", true)
	var t := create_tween().set_parallel()
	for pivot in _pivots:
		t.tween_property(pivot, "rotation:x", PI / 2.0, swing_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	Sfx.play_at(self, &"trapdoor_drop", global_position + Vector3.DOWN * 0.5)
	NoiseBus.emit_noise(global_position, open_loudness, self)
	opened.emit()


## Da un compagno sul bordo (coop, M6): una corda calata nella fossa. Resta appesa.
func hang_rope() -> void:
	_has_rope = true
	_rope.visible = true
	for p in _inside:
		p.pit_rope = true


func _physics_process(delta: float) -> void:
	super(delta)
	for p in players():
		var local := to_local(p.global_position)
		var in_shaft := absf(local.x) < DungeonBuilder.CELL / 2.0 and absf(local.z) < DungeonBuilder.CELL / 2.0
		if not _inside.has(p):
			if in_shaft and local.y < -0.3:
				_on_fall(p)
			continue
		if not p.in_pit and local.y > -0.3:
			_on_climbed_out(p)
		elif not _landed.has(p) and p.is_on_floor():
			_on_land(p)
		elif _landed.has(p) and p.in_pit:
			_despair(p, delta)
	for p: Player in _inside.keys():
		if not is_instance_valid(p) or p.health.is_dead():
			_inside.erase(p)  # morto nella fossa: niente più conti


## Si precipita: la torcia sfugge di mano e cade sul fondo, dalla parte opposta alla corda.
func _on_fall(p: Player) -> void:
	_inside[p] = 0.0
	var side := Vector3(exit_dir.x, 0, exit_dir.y)
	p.drop_torch(to_global(-side * 0.5 + Vector3.UP * _bottom_y()))
	var rope_spot := to_global(side * 0.55 + Vector3.UP * _bottom_y())
	var exit := to_global(side * DungeonBuilder.CELL + Vector3.UP * 0.05)
	p.fall_into_pit(rope_spot, exit, _has_rope)
	if not p.rope_hung.is_connected(_on_rope_hung):
		p.rope_hung.connect(_on_rope_hung)
	p.note("Precipitato in una fossa sotto una botola.")


func _on_land(p: Player) -> void:
	_landed[p] = true
	Sfx.play_at(self, &"pit_land", p.global_position)
	NoiseBus.emit_noise(p.global_position, land_loudness, p)
	p.hurt(fall_damage, cause)
	if _has_rope:
		p.message.emit("Sei in fondo a una fossa. Dal bordo pende una corda: E per risalire.")
	elif p.inventory.has(Items.ROPE):
		p.message.emit("Sei in fondo a una fossa. E per legare la corda e risalire.")
	else:
		p.message.emit("Sei in fondo a una fossa. Senza una corda non ne uscirai…")


## Senza corda (né in mano né appesa) il tempo scorre: da soli poco, in coop abbastanza per un soccorso.
func _despair(p: Player, delta: float) -> void:
	if _has_rope or p.inventory.has(Items.ROPE):
		_inside[p] = 0.0
		return
	var limit := despair_time if players().size() <= 1 else coop_despair_time
	var before := _inside[p]
	_inside[p] = before + delta
	if before < limit / 2.0 and _inside[p] >= limit / 2.0:
		p.message.emit("Le pareti sono lisce: non c'è un appiglio.")
	if _inside[p] >= limit:
		_inside.erase(p)
		p.kill(cause)


func _on_climbed_out(p: Player) -> void:
	_inside.erase(p)
	_landed.erase(p)
	if p.rope_hung.is_connected(_on_rope_hung):
		p.rope_hung.disconnect(_on_rope_hung)


func _on_rope_hung() -> void:
	_has_rope = true
	_rope.visible = true
