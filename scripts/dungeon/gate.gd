class_name Gate
extends Door
## Cancello a leva (vedi DungeonGenerator.DOOR_GATE): una saracinesca di sbarre di ferro nella cornice di
## una porta. A mano non si alza: lo comanda una leva altrove nel piano (vedi Lever), che lo alza e lo
## riabbassa. Ci si vede attraverso (anche la minimappa), ma non si passa, e il Cieco nemmeno: un cancello
## richiuso alle spalle lo tiene fuori. Si muove con un gran rumore di catene; ricadendo sbatte.
## Non ricade addosso a qualcuno: aspetta che il vano sia libero.

@export var raise_time := 1.4        ## secondi per alzarsi (le catene tirano piano)
@export var drop_time := 0.25        ## ricade di colpo
@export var move_loudness := 0.6     ## catene e ferro
@export var slam_loudness := 0.7     ## le sbarre che battono a terra
@export var rattle_loudness := 0.15  ## chi prova ad alzarlo a mano

var _bars := Node3D.new()
var _want_open := false


func _build() -> void:
	_build_frame()
	add_child(_bars)
	_bars.add_child(Voxels.instance(&"gate_bars"))
	var body := StaticBody3D.new()
	_bars.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(opening, height, thickness)
	_collision.shape = shape
	_collision.position.y = height / 2.0
	body.add_child(_collision)


func can_interact() -> bool:
	return not is_open


func prompt() -> String:
	return "" if is_open else "Il cancello si alza con una leva"


## A mano no: le sbarre sbattono appena.
func _unlock(opener: Node3D) -> bool:
	Sfx.play_at(self, &"door_locked", global_position + Vector3.UP * 1.1, 0.0, 0.7)
	NoiseBus.emit_noise(global_position, rattle_loudness, opener)
	var p := opener as Player
	if p:
		p.message.emit("Il cancello non si alza a mano: cerca una leva.")
	return false


## Dalla leva: su (`up`) o giù. Giù aspetta che nel vano non ci sia nessuno.
func set_raised(up: bool) -> void:
	_want_open = up


func _physics_process(_delta: float) -> void:
	if _want_open == is_open:
		return
	if _want_open:
		_raise()
	elif blocker() == null:
		_drop()


func _raise() -> void:
	is_open = true
	_collision.set_deferred("disabled", true)
	_move_bars(height - 0.15, raise_time, Tween.EASE_IN_OUT)
	Sfx.play_at(self, &"gate_move", global_position + Vector3.UP * height)
	NoiseBus.emit_noise(global_position, move_loudness, self)
	opened.emit()


func _drop() -> void:
	is_open = false
	_collision.set_deferred("disabled", false)
	_move_bars(0.0, drop_time, Tween.EASE_IN)
	_tween.tween_callback(func() -> void: Sfx.play_at(self, &"gate_slam", global_position + Vector3.UP * 0.3))
	NoiseBus.emit_noise(global_position, slam_loudness, self)
	closed.emit()


func _move_bars(y: float, time: float, easing: Tween.EaseType) -> void:
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_bars, "position:y", y, time).set_trans(Tween.TRANS_QUAD).set_ease(easing)
