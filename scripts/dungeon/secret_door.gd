class_name SecretDoor
extends Door
## Muro segreto (vedi DungeonGenerator.DOOR_SECRET): da lontano è un muro come gli altri, dietro c'è una
## stanzetta coi tesori. Da vicino, con la luce, si nota il contorno di una porta nei mattoni (modello
## wall_secret); bussando (E verso il muro) suona vuoto. Una volta scoperto, E lo spinge: sprofonda nel
## pavimento strisciando sulla pietra (rumore). Si può richiudere, anche da dentro: ci si nasconde.
## Il builder lo gira con +z verso la stanza: il pannello sta sul bordo della cella, dal lato della stanza.

@export var knock_loudness := 0.2  ## bussare si sente (lo stesso di un muro pieno)
@export var sink_depth := 3.2      ## metri di cui sprofonda aperto: tutto sotto il pavimento
@export var panel_depth := 0.5     ## spessore della parete (metà posteriore del modello del muro)

const FLOOR_T := 0.25  ## i muri scendono sotto il pavimento di tanto (fondazione), come in DungeonBuilder

var discovered := false  ## ha già suonato vuoto: da ora E lo spinge

var _panel := Node3D.new()


## Il pannello di muro sul lato della stanza, con la collisione della parete. Niente cornice né anta.
func _build() -> void:
	_panel.position = Vector3(0.0, -FLOOR_T, width / 2.0)
	add_child(_panel)
	_panel.add_child(Voxels.instance(&"wall_secret"))
	var body := StaticBody3D.new()
	_panel.add_child(body)
	var shape := BoxShape3D.new()
	shape.size = Vector3(width, wall_height, panel_depth)
	_collision.shape = shape
	_collision.position = Vector3(0.0, FLOOR_T + wall_height / 2.0, -panel_depth / 2.0)
	body.add_child(_collision)


func can_interact() -> bool:
	return discovered or is_open


func prompt() -> String:
	return "E  richiudi il passaggio" if is_open else "E  spingi il muro"


## Il vano è davanti al pannello, non al centro della cella: lì non ci si deve trovare quando risale.
func can_close(body: Node3D) -> bool:
	return absf(to_local(body.global_position).z - width / 2.0) >= clearance


## E verso il pannello chiuso: suona vuoto. Da ora si sa che è un passaggio.
func knock(who: Player, at: Vector3) -> void:
	Sfx.play_at(self, &"wall_knock_hollow", at)
	NoiseBus.emit_noise(at, knock_loudness, who)
	if discovered:
		return
	discovered = true
	who.message.emit("Suona vuoto… E per spingere il muro.")
	who.note("Un muro che suona vuoto: un passaggio segreto.")


## Sprofonda (aperto, angolo diverso da zero) o risale (chiuso). Il pannello scorre nel pavimento.
func _swing_to(angle: float, delay := 0.0) -> void:
	discovered = true
	if _tween:
		_tween.kill()
	_tween = create_tween()
	if delay > 0.0:
		_tween.tween_interval(delay)
	var y := -FLOOR_T if angle == 0.0 else -FLOOR_T - sink_depth
	_tween.tween_property(_panel, "position:y", y, open_time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
