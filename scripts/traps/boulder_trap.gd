class_name BoulderTrap
extends Trap
## Masso: un filo teso alla caviglia attraversa un corridoio; qualche cella più in là, nel soffitto,
## un buco tondo da cui si vede la pancia di un masso. Chi urta il filo in piedi lo spezza
## (accovacciati lo si scavalca): scatto, boato dall'alto, e dopo warn_time il masso cade e rotola
## lungo il corridoio, schiacciando chiunque trovi. Rotola poco meno veloce di chi corre: bisogna
## scappare subito, in una stanza o in un corridoio laterale. In fondo si frantuma. Una volta sola.
## L'origine è la cella dove cade il masso (il builder la mette lì); `wire` e `run` in celle da qui.

@export var roll_speed := 4.5        ## m/s: un po' meno della corsa (5,5)
@export var roll_accel := 5.0        ## m/s²: parte piano, poi non si ferma più
@export var fall_time := 0.35
@export var land_loudness := 0.6
@export var roll_loudness := 0.5     ## ogni mezzo secondo mentre rotola
@export var crash_loudness := 0.9
@export var cause := "un masso rotolante"
@export var ceiling_height := 3.0

const RADIUS := 0.875    ## modello boulder: 14 voxel
const HIDDEN_DROP := 0.1 ## metri di masso che sporgono sotto il soffitto quando aspetta

var dir := Vector2i.RIGHT  ## verso in cui rotola
var wire := 3              ## celle tra la caduta e il filo
var run := 6               ## celle tra la caduta e dove si frantuma

var _ball := Node3D.new()   ## centro del masso: si sposta
var _spin := Node3D.new()   ## figlio del centro: gira
var _wire: MeshInstance3D
var _wire_cut: MeshInstance3D
var _rolling := false
var _speed := 0.0
var _traveled := 0.0
var _sound_timer := 0.0
var _warned: Array[Player] = []  ## chi ha già scavalcato il filo (messaggio una volta sola)


func _init() -> void:
	warn_time = 0.8
	trigger_sound = &"trap_snap"
	trigger_loudness = 0.2


func _ready() -> void:
	var shaft := Voxels.instance(&"boulder_shaft")
	shaft.position.y = ceiling_height + Voxels.VOXEL_SIZE * 2.0  # sopra la lastra del soffitto
	add_child(shaft)
	_ball.position.y = ceiling_height - HIDDEN_DROP + RADIUS
	add_child(_ball)
	_ball.add_child(_spin)
	var rock := Voxels.instance(&"boulder")
	rock.position.y = -RADIUS
	_spin.add_child(rock)
	_wire = _add_wire(&"trap_wire")
	_wire_cut = _add_wire(&"trap_wire_cut")
	_wire_cut.visible = false


## Il filo attraversa il corridoio da muro a muro (il modello è lungo x): lo si gira se il corridoio va lungo x.
func _add_wire(model: StringName) -> MeshInstance3D:
	var w := Voxels.instance(model)
	w.position = _forward() * wire * DungeonBuilder.CELL
	w.rotation.y = PI / 2.0 if dir.x != 0 else 0.0
	add_child(w)
	return w


func _forward() -> Vector3:
	return Vector3(dir.x, 0, dir.y)


## Si urta il filo passandoci sopra in piedi.
func _steps_on(p: Player) -> bool:
	var local := to_local(p.global_position) - _wire.position
	var near := absf(local.dot(_forward())) < 0.25 and local.length() < DungeonBuilder.CELL and absf(local.y) < 0.6
	if near and p.is_crouching():
		if not _warned.has(p):
			_warned.append(p)
			p.message.emit("Scavalchi con cautela un filo teso.")
		return false
	return near


func _trigger_position() -> Vector3:
	return _wire.global_position


func _on_trigger(p: Player) -> void:
	_wire.visible = false
	_wire_cut.visible = true
	Sfx.play_at(self, &"boulder_roll", _ball.global_position, 0.0, 0.6)  # il boato dall'alto
	p.message.emit("Il filo si spezza… un boato sopra la tua testa!")


func _spring() -> void:
	var t := create_tween()
	t.tween_property(_ball, "position:y", RADIUS, fall_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_land)


func _land() -> void:
	Sfx.play_at(self, &"boulder_land", _ball.global_position)
	NoiseBus.emit_noise(_ball.global_position, land_loudness, self)
	_crush()
	_rolling = true


func _physics_process(delta: float) -> void:
	super(delta)
	if not _rolling:
		return
	_speed = move_toward(_speed, roll_speed, roll_accel * delta)
	var step := minf(_speed * delta, run * DungeonBuilder.CELL - _traveled)
	_traveled += step
	_ball.position = _forward() * _traveled + Vector3.UP * RADIUS
	_spin.rotate(Vector3.UP.cross(_forward()), step / RADIUS)
	_crush()
	_sound_timer -= delta
	if _sound_timer <= 0.0:
		_sound_timer = 0.5
		Sfx.play_at(self, &"boulder_roll", _ball.global_position, 0.0, 0.7)
		NoiseBus.emit_noise(_ball.global_position, roll_loudness, self)
	if _traveled >= run * DungeonBuilder.CELL:
		_shatter()


## Chi è sotto il masso muore: non c'è parata che tenga.
func _crush() -> void:
	for p in players():
		var d := p.global_position - _ball.global_position
		if Vector2(d.x, d.z).length() < RADIUS + 0.3 and absf(p.global_position.y - global_position.y) < 1.0:
			p.kill(cause)


## Contro il muro in fondo il masso va in pezzi: restano i frantumi, che si scavalcano.
func _shatter() -> void:
	_rolling = false
	_ball.visible = false
	var rubble := Voxels.instance(&"boulder_rubble")
	rubble.position = Vector3(_ball.position.x, 0.0, _ball.position.z)
	add_child(rubble)
	Sfx.play_at(self, &"boulder_crash", _ball.global_position)
	NoiseBus.emit_noise(_ball.global_position, crash_loudness, self)


## Bloccata dalla leva: il filo si allenta e cade a terra, il masso resta nel soffitto.
func _on_disarm() -> void:
	_wire.visible = false
	_wire_cut.visible = true
