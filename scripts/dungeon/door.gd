class_name Door
extends Node3D
## Porta in un corridoio: il giocatore la apre e la richiude con E.
## Blocca passaggio e luce finché è chiusa; aprirla cigola, chiuderla fa un tonfo (eventi rumore).
## Cornice e anta sono modelli voxel (door_frame, door_leaf): vano stretto, si passa uno alla volta.
## L'anta ruota attorno a un cardine (Pivot) su uno stipite.

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

## La porta si è aperta (la minimappa smette di considerarla un muro).
signal opened
## La porta si è richiusa: la minimappa già disegnata non cambia, ma la vista torna a fermarsi qui.
signal closed

var is_open := false

var _pivot := Node3D.new()
var _collision := CollisionShape3D.new()
var _tween: Tween


func _ready() -> void:
	add_to_group("door")

	_build_frame()

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
	var leaf := Voxels.instance(&"door_leaf")
	leaf.position.y = -height / 2.0
	body.add_child(leaf)


## Si apre allontanandosi da chi la spinge. Restituisce false se era già aperta.
func open(opener: Node3D) -> bool:
	if is_open:
		return false
	is_open = true
	_collision.set_deferred("disabled", true)  # niente urti col pannello che ruota
	var local := to_local(opener.global_position)
	var angle := PI / 2.0 if local.z > 0.0 else -PI / 2.0  # +90° porta il pannello verso -z
	_swing_to(angle)
	NoiseBus.emit_noise(global_position, open_loudness, opener)
	Sfx.play_at(self, &"door_open", global_position + Vector3.UP * 1.2)
	opened.emit()
	return true


## Vero se `body` è abbastanza fuori dal vano da non finire dentro il pannello.
func can_close(body: Node3D) -> bool:
	return absf(to_local(body.global_position).z) >= clearance


## Richiude la porta. Restituisce false se era già chiusa o se `closer` è nel vano.
func close(closer: Node3D) -> bool:
	if not is_open or not can_close(closer):
		return false
	is_open = false
	_collision.set_deferred("disabled", false)
	_swing_to(0.0)
	NoiseBus.emit_noise(global_position, close_loudness, closer)
	Sfx.play_at(self, &"door_close", global_position + Vector3.UP * 1.2)
	closed.emit()
	return true


## Ruota il pannello (un Tween anima una proprietà nel tempo); un nuovo movimento interrompe il precedente.
func _swing_to(angle: float) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_pivot, "rotation:y", angle, open_time) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
