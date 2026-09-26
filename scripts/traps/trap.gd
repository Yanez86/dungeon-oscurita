class_name Trap
extends Node3D
## Base delle trappole sul pavimento: una scena per tipo, le piazza DungeonBuilder dove dice TrapLayout.
## Regole comuni (GDD): l'innesco si vede sempre; quando scatta fa un suono breve (Sfx + evento rumore
## basso) e l'effetto arriva `warn_time` secondi dopo, così chi reagisce subito si salva.
## Scattano solo sui giocatori vivi (gruppo "player"). Alcune hanno una leva che le disattiva per sempre (disarm).
## L'origine è al centro della cella, a filo del pavimento.

## È scattata.
signal triggered

@export var warn_time := 0.5              ## secondi tra lo scatto e l'effetto
@export var trigger_loudness := 0.1       ## lo scatto: i nemici lo sentono solo da vicino
@export var trigger_sound: StringName = &"trap_click"
@export var plate_half_size := 0.3        ## metri: si scatta col centro del corpo entro questa distanza dalla piastra
@export var rearm_time := -1.0            ## secondi dopo l'effetto per tornare armata (< 0: una volta sola)
@export var disarm_loudness := 0.25       ## il meccanismo che si blocca quando si tira la sua leva

const PLATE_UP := 0.0      ## la piastra sporge di un voxel piccolo dal pavimento...
const PLATE_DOWN := -0.05  ## ...e premuta scende quasi a filo

var armed := true
var disarmed := false  ## bloccata da una leva: non scatta più

var _plate: MeshInstance3D  ## piastra a pressione, per le trappole che ne hanno una (add_plate)


func _physics_process(_delta: float) -> void:
	if not armed:
		return
	for p in players():
		if _steps_on(p):
			_trigger(p)
			return


## I giocatori vivi.
func players() -> Array[Player]:
	var out: Array[Player] = []
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p and not p.health.is_dead():
			out.append(p)
	return out


## Vero se `p` è nel quadrato di lato 2 * `half` attorno al centro della cella, all'altezza del pavimento.
func is_within(p: Node3D, half: float) -> bool:
	var local := to_local(p.global_position)
	return absf(local.x) <= half and absf(local.z) <= half and absf(local.y) < 0.6


## Piastra a pressione al centro della cella (modello trap_plate).
func add_plate() -> void:
	_plate = Voxels.instance(&"trap_plate")
	_plate.position.y = PLATE_UP
	add_child(_plate)


## Vero se il giocatore sta facendo scattare l'innesco. Di base: è sulla piastra.
func _steps_on(p: Player) -> bool:
	return is_within(p, plate_half_size)


func _trigger(p: Player) -> void:
	armed = false
	if _plate:
		_plate.position.y = PLATE_DOWN
	var at := _trigger_position()
	Sfx.play_at(self, trigger_sound, at + Vector3.UP * 0.3)
	NoiseBus.emit_noise(at, trigger_loudness, self)
	triggered.emit()
	_on_trigger(p)
	var t := create_tween()
	t.tween_interval(warn_time)
	t.tween_callback(_spring)


## Dove si sente lo scatto: di base il centro della cella.
func _trigger_position() -> Vector3:
	return global_position


## Subito dopo lo scatto, durante l'avviso.
func _on_trigger(_p: Player) -> void:
	pass


## L'effetto, `warn_time` secondi dopo lo scatto. Chi si riarma chiama _rearm_later() quando ha finito.
func _spring() -> void:
	pass


func _rearm_later() -> void:
	if rearm_time < 0.0:
		return
	var t := create_tween()
	t.tween_interval(rearm_time)
	t.tween_callback(_rearm)


func _rearm() -> void:
	if disarmed:
		return
	armed = true
	if _plate:
		_plate.position.y = PLATE_UP


## La sua leva è stata tirata (vedi Lever): non scatta più. Dal punto dell'innesco si sente un colpo secco,
## così chi ha tirato la leva capisce quale trappola ha fermato; la piastra resta giù, bloccata.
func disarm() -> void:
	if disarmed:
		return
	disarmed = true
	armed = false
	if _plate:
		_plate.position.y = PLATE_DOWN
	var at := _trigger_position()
	Sfx.play_at(self, &"trap_disarm", at + Vector3.UP * 0.3)
	NoiseBus.emit_noise(at, disarm_loudness, self)
	_on_disarm()


## Cosa cambia a vista quando la si disattiva (oltre alla piastra).
func _on_disarm() -> void:
	pass
