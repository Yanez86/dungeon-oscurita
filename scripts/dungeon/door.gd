class_name Door
extends Node3D
## Porta in un corridoio: il giocatore la apre e la richiude con E.
## Blocca passaggio e luce finché è chiusa; aprirla cigola, chiuderla fa un tonfo (eventi rumore).
## Cornice e anta sono modelli voxel (door_frame, door_leaf): vano stretto, si passa uno alla volta.
## L'anta ruota attorno a un cardine (Pivot) su uno stipite.
## Alcune porte sono trappole (`trap`, lo sceglie TrapLayout):
## - dardi: quattro fori scuri nell'anta all'altezza del petto. Aprendola si sente un clic, l'anta fa
##   resistenza un attimo e i dardi partono verso chi apre; accovacciati passano sopra. Una volta sola.
## - campanelli: appesi sopra il vano, suonano forte (i nemici li sentono) se la si apre o chiude in piedi;
##   accovacciati li si tiene fermi con la mano.

@export var width := 2.0           ## larghezza del corridoio (= lato di una cella): la cornice lo chiude tutto
@export var wall_height := 3.0     ## altezza del muro
@export var opening := 1.0         ## larghezza del vano (deve combaciare con i modelli voxel)
@export var height := 2.125        ## altezza dell'anta e del vano (17 voxel)
@export var thickness := 0.125
@export var frame_depth := 0.5     ## spessore della cornice
@export var open_time := 0.6       ## secondi per spalancarsi
@export var open_loudness := 0.45  ## il cigolio si sente lontano
@export var close_loudness := 0.4  ## il tonfo della porta che si chiude
@export var clearance := 0.75      ## metri tra chi chiude e il vano (per non restare incastrati)

@export_group("Trappola")
@export var trap: StringName = &""   ## TrapLayout.DARTS, TrapLayout.BELLS o niente (il builder lo imposta)
@export var dart_damage := 3
@export var dart_delay := 0.3        ## secondi tra il clic e i dardi (l'anta resta ferma)
@export var dart_height := 1.3       ## all'altezza del petto: accovacciati passano sopra la testa
@export var dart_range := 3.0        ## metri davanti alla porta che i dardi attraversano
@export var dart_cause := "i dardi di una porta"
@export var bells_loudness := 0.9

## La porta si è aperta (la minimappa smette di considerarla un muro).
signal opened
## La porta si è richiusa: la minimappa già disegnata non cambia, ma la vista torna a fermarsi qui.
signal closed

var is_open := false

var _pivot := Node3D.new()
var _collision := CollisionShape3D.new()
var _tween: Tween
var _darts_armed := false


func _ready() -> void:
	add_to_group("door")
	_darts_armed = trap == TrapLayout.DARTS

	_build_frame()
	if trap == TrapLayout.BELLS:
		_build_bells()

	# Anta: figlia del cardine, spostata di mezza larghezza.
	_pivot.position.x = -opening / 2.0
	add_child(_pivot)
	var body := StaticBody3D.new()
	body.position = Vector3(opening / 2.0, height / 2.0, 0.0)
	_pivot.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(opening, height, thickness)
	_collision.shape = shape
	body.add_child(_collision)
	_build_leaf(body)


## Cornice in pietra (modello voxel), larga quanto il corridoio; stipiti e architrave hanno una collisione.
func _build_frame() -> void:
	add_child(Voxels.instance(&"door_frame"))
	var frame := StaticBody3D.new()
	add_child(frame)
	var jamb_w := (width - opening) / 2.0
	for side in [-1.0, 1.0]:
		_add_frame_block(frame, Vector3(jamb_w, wall_height, frame_depth),
			Vector3(side * (opening + jamb_w) / 2.0, wall_height / 2.0, 0))
	_add_frame_block(frame, Vector3(opening, wall_height - height, frame_depth),
		Vector3(0, (wall_height + height) / 2.0, 0))


func _add_frame_block(frame: StaticBody3D, size: Vector3, pos: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = pos
	frame.add_child(col)


## Anta ad assi con fasce di ferro (modello voxel). La mesh ha la base in y = 0: la si abbassa
## di mezza altezza perché il corpo fisico è centrato sull'anta.
func _build_leaf(body: StaticBody3D) -> void:
	var leaf := Voxels.instance(&"door_leaf_darts" if trap == TrapLayout.DARTS else &"door_leaf")
	leaf.position.y = -height / 2.0
	body.add_child(leaf)


## Campanelli appesi all'architrave, sui due lati della porta.
func _build_bells() -> void:
	for s: float in [1.0, -1.0]:
		var bells := Voxels.instance(&"trap_bells")
		bells.position = Vector3(opening / 4.0 * s, height, s * (frame_depth / 2.0 + 0.1))
		bells.rotation.y = 0.0 if s > 0.0 else PI
		add_child(bells)


## Si apre allontanandosi da chi la spinge. Restituisce false se era già aperta.
func open(opener: Node3D) -> bool:
	if is_open:
		return false
	is_open = true
	_collision.set_deferred("disabled", true)  # niente urti col pannello che ruota
	var local := to_local(opener.global_position)
	var angle := PI / 2.0 if local.z > 0.0 else -PI / 2.0  # +90° porta il pannello verso -z
	var delay := 0.0
	if _darts_armed:
		delay = dart_delay
		_spring_darts(signf(local.z))
	_swing_to(angle, delay)
	NoiseBus.emit_noise(global_position, open_loudness, opener)
	Sfx.play_at(self, &"door_open", global_position + Vector3.UP * 1.2)
	_ring_bells(opener)
	opened.emit()
	return true


## Vero se `body` è abbastanza fuori dal vano da non finire dentro il pannello.
func can_close(body: Node3D) -> bool:
	return absf(to_local(body.global_position).z) >= clearance


## Un giocatore o un nemico (diverso da `closer`) fermo nel vano, o null: la porta non gli si chiude addosso,
## altrimenti resterebbe incastrato nell'anta.
func blocker(closer: Node3D = null) -> Node3D:
	for group: StringName in [&"player", &"enemy"]:
		for node in get_tree().get_nodes_in_group(group):
			var body := node as Node3D
			if body == null or body == closer:
				continue
			if absf(to_local(body.global_position).x) < width / 2.0 and not can_close(body):
				return body
	return null


## Richiude la porta. Restituisce false se era già chiusa o se nel vano c'è `closer` o qualcun altro.
func close(closer: Node3D) -> bool:
	if not is_open or not can_close(closer) or blocker(closer) != null:
		return false
	is_open = false
	_collision.set_deferred("disabled", false)
	_swing_to(0.0)
	NoiseBus.emit_noise(global_position, close_loudness, closer)
	Sfx.play_at(self, &"door_close", global_position + Vector3.UP * 1.2)
	_ring_bells(closer)
	closed.emit()
	return true


## Ruota il pannello (un Tween anima una proprietà nel tempo); un nuovo movimento interrompe il precedente.
## `delay`: secondi di attesa prima di muoversi (la porta a dardi fa resistenza).
func _swing_to(angle: float, delay := 0.0) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	_tween.tween_property(_pivot, "rotation:y", angle, open_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)


## Porta a dardi: il clic subito, i dardi dopo `dart_delay` verso il lato `side` (+1 o -1 lungo z), dove sta chi apre.
func _spring_darts(side: float) -> void:
	_darts_armed = false
	Sfx.play_at(self, &"trap_click", global_position + Vector3.UP * dart_height)
	NoiseBus.emit_noise(global_position, 0.1, self)
	var t := create_tween()
	t.tween_interval(dart_delay)
	t.tween_callback(_shoot_darts.bind(side))


## I dardi escono dai fori dell'anta all'altezza del petto e volano per `dart_range` metri: colpiscono chi
## è davanti alla porta in piedi. Accovacciati passano sopra la testa.
func _shoot_darts(side: float) -> void:
	Sfx.play_at(self, &"darts_fly", global_position + Vector3.UP * dart_height)
	for x: float in [-0.3, -0.1, 0.1, 0.3]:
		var dart := Voxels.instance(&"trap_dart")
		dart.position = Vector3(x, dart_height, 0.0)
		dart.rotation.y = 0.0 if side > 0.0 else PI  # la punta (+z del modello) verso chi apre
		add_child(dart)
		var t := dart.create_tween()
		t.tween_property(dart, "position:z", side * dart_range, 0.18)
		t.tween_callback(dart.queue_free)
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p == null or p.health.is_dead():
			continue
		var local := to_local(p.global_position)
		if local.z * side <= 0.0 or absf(local.z) > dart_range or absf(local.x) > opening:
			continue
		if p.is_crouching():
			p.message.emit("Dei dardi ti sibilano sopra la testa!")
		elif p.hurt(dart_damage, dart_cause) > 0:
			p.message.emit("Dardi dalla porta! C'erano dei fori nell'anta…")


## Campanelli: in piedi suonano forte e i nemici li sentono; accovacciati li si tiene fermi con la mano.
func _ring_bells(who: Node3D) -> void:
	if trap != TrapLayout.BELLS:
		return
	var p := who as Player
	if p and p.is_crouching():
		p.message.emit("Tieni fermi i campanelli con la mano.")
		return
	var at := global_position + Vector3.UP * height
	var t := create_tween()
	for pitch: float in [1.0, 1.25, 0.9]:
		t.tween_callback(func() -> void: Sfx.play_at(self, &"door_bells", at, 0.0, pitch))
		t.tween_interval(0.12)
	NoiseBus.emit_noise(global_position, bells_loudness, who)
	if p:
		p.message.emit("Dei campanelli suonano sopra la porta!")
