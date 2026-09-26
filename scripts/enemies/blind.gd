class_name Blind
extends CharacterBody3D
## Il Cieco (GDD, M4): sente soltanto. Vaga lento, corre verso l'ultimo rumore sentito, annusa,
## gratta alle porte chiuse. Se tocca un giocatore gli toglie 3 punti di energia e si ritrae.
## Le decisioni le prende BlindBrain (solo dati); qui c'è il corpo: percorso, movimento, contatto e suoni.
## Lo crea DungeonBuilder, che con setup() gli passa la mappa dei passaggi prima di metterlo in scena.

@export var damage := 3
@export var touch_range := 0.9  ## metri in piano tra i centri: più vicino, il Cieco ti ha toccato

@export_group("Udito e movimento")
@export var hearing_range := 20.0  ## metri a cui sente un rumore di loudness 1, lungo i corridoi
@export var wander_speed := 1.2
@export var investigate_speed := 4.5  ## camminando (3 m/s) non gli scappi, correndo (5,5) sì
@export var search_speed := 1.5
@export var turn_speed := 8.0
@export var wander_radius := 10  ## celle: quanto lontano va vagando
@export var search_radius := 2   ## celle attorno al rumore in cui annusa
@export var stuck_time := 2.0    ## secondi fermo mentre vorrebbe camminare: cambia meta
@export var recoil_push := 2.0   ## m/s con cui arretra subito dopo un colpo
@export var recoil_push_time := 0.4

@export_group("Tempi (secondi)")
@export var search_time := 4.0
@export var scratch_time := 3.0
@export var recoil_time := 2.0

@export_group("Rumori che fa (0-1)")
@export var step_length := 1.1  ## metri tra un passo e l'altro
@export var step_loudness := 0.15
@export var scratch_loudness := 0.3
@export var scratch_interval := 0.7
@export var breath_loudness := 0.05

var brain: BlindBrain
var nav: DungeonNav

var _path: Array[Vector3] = []
var _planned_version := -1
var _blocked := false  ## il percorso finisce davanti a una porta chiusa
var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _fx_rng := RandomNumberGenerator.new()  ## solo suoni e animazione: non tocca le scelte del cervello
var _step := 0.0
var _stuck := 0.0
var _last_pos := Vector3.ZERO
var _scratch_left := 0.0
var _breath_left := 2.0
var _push_left := 0.0
var _push_dir := Vector3.ZERO
var _deaf := false  ## vero solo mentre colpisce (vedi _check_touch)
var _anim := 0.0
var _model: MeshInstance3D
var _voice: AudioStreamPlayer3D  ## respiro, verso, graffi
var _feet: AudioStreamPlayer3D


## Da chiamare prima di add_child: stesso seed = stesse scelte a parità di rumori.
func setup(dungeon_nav: DungeonNav, seed_value: int) -> void:
	nav = dungeon_nav
	brain = BlindBrain.new(seed_value)
	_fx_rng.seed = seed_value + 1


func _ready() -> void:
	add_to_group("enemy")
	if brain == null:
		brain = BlindBrain.new()
	brain.hearing_range = hearing_range
	brain.wander_speed = wander_speed
	brain.investigate_speed = investigate_speed
	brain.search_speed = search_speed
	brain.search_time = search_time
	brain.scratch_time = scratch_time
	brain.recoil_time = recoil_time
	brain.state_changed.connect(_on_state_changed)
	NoiseBus.noise_emitted.connect(_on_noise)
	if nav:
		nav.passage_changed.connect(_on_passage_changed)

	_model = Voxels.instance(&"enemy_blind")
	add_child(_model)
	_voice = Sfx.player_3d()
	_voice.position.y = 1.5
	add_child(_voice)
	_feet = Sfx.player_3d(18.0)
	_feet.stream = Sfx.stream(&"blind_step")
	add_child(_feet)
	_last_pos = global_position


## Nome dello stato, per l'overlay di debug.
func state_name() -> String:
	return BlindBrain.state_name(brain.state)


## È finito in una tagliola: resta fermo lì per `seconds` secondi.
func trap(at: Vector3, seconds: float) -> void:
	global_position = Vector3(at.x, global_position.y, at.z)
	velocity = Vector3.ZERO
	_path.clear()
	brain.trap(seconds)


func _physics_process(delta: float) -> void:
	brain.position = global_position
	brain.update(delta)
	if brain.goal_version != _planned_version:
		_plan()

	var move := _desired_move()
	velocity.x = move.x
	velocity.z = move.z
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()

	_turn(move, delta)
	_animate(delta, move.length())
	_footsteps()
	_check_stuck(delta, move)
	_scratch(delta)
	_breathe(delta)
	_check_touch()
	_last_pos = global_position


## Dove vuole andare in questo passo di fisica (velocità in piano).
func _desired_move() -> Vector3:
	if brain.state == BlindBrain.State.RECOIL and _push_left > 0.0:
		_push_left -= get_physics_process_delta_time()
		return _push_dir * recoil_push
	var speed := brain.speed()
	while speed > 0.0 and not _path.is_empty():
		var to := _path[0] - global_position
		to.y = 0.0
		if to.length() > 0.2:
			return to.normalized() * speed
		_path.pop_front()
		if _path.is_empty():
			_end_of_path()
	return Vector3.ZERO


## Trasforma la meta del cervello in una fila di punti da raggiungere.
func _plan() -> void:
	_planned_version = brain.goal_version
	_path.clear()
	_blocked = false
	_stuck = 0.0
	if nav == null or brain.goal == BlindBrain.Goal.NONE:
		return
	var here := nav.to_cell(global_position)
	var target := here
	match brain.goal:
		BlindBrain.Goal.POINT:
			target = nav.to_cell(brain.goal_point)
		BlindBrain.Goal.WANDER:
			target = nav.random_cell(here, brain.rng, 3, wander_radius)
		BlindBrain.Goal.SEARCH:
			target = nav.random_cell(nav.to_cell(brain.goal_point), brain.rng, 1, search_radius)
	var route := nav.route(here, target)
	_blocked = route.blocked_door
	for c in route.cells:
		_path.append(nav.to_world(c))
	if brain.goal == BlindBrain.Goal.POINT and not _blocked and nav.to_cell(brain.goal_point) == nav.nearest_walkable(target):
		# L'ultimo tratto va dritto sul punto del rumore, non al centro della cella.
		if not _path.is_empty():
			_path.pop_back()
		_path.append(Vector3(brain.goal_point.x, 0.0, brain.goal_point.z))
	if _path.is_empty():
		_end_of_path()  # già lì, davanti alla porta o meta irraggiungibile


func _end_of_path() -> void:
	if _blocked:
		brain.blocked_by_door()
	else:
		brain.arrived()


func _on_state_changed(from: BlindBrain.State, to: BlindBrain.State) -> void:
	match to:
		BlindBrain.State.INVESTIGATE:
			if from != BlindBrain.State.INVESTIGATE:
				_say(&"blind_alert", 2.0, 0.55)  # l'ha sentito: un lamento, poi corre
		BlindBrain.State.SCRATCH:
			_scratch_left = 0.0
		BlindBrain.State.RECOIL:
			_push_left = recoil_push_time


## Ogni rumore del gioco passa di qui (NoiseBus): quelli degli altri nemici non gli interessano.
func _on_noise(pos: Vector3, loudness: float, source: Node) -> void:
	if nav == null or _deaf or (is_instance_valid(source) and source.is_in_group("enemy")):
		return
	if global_position.distance_to(pos) > loudness * hearing_range:
		return  # troppo lontano anche in linea d'aria: inutile cercare la strada
	var cells := nav.sound_distance(nav.to_cell(global_position), nav.to_cell(pos))
	if cells >= 0.0:
		brain.hear(pos, loudness, cells * nav.cell_size)


## Una porta si è aperta o chiusa: se stava grattando riparte, se camminava ricalcola.
func _on_passage_changed(_cell: Vector2i, open: bool) -> void:
	if open and brain.state == BlindBrain.State.SCRATCH:
		brain.door_opened()
	elif brain.goal != BlindBrain.Goal.NONE:
		_planned_version = -1


func _turn(move: Vector3, delta: float) -> void:
	if move.length() < 0.1 or brain.state == BlindBrain.State.RECOIL:
		return
	rotation.y = lerp_angle(rotation.y, atan2(move.x, move.z), clampf(turn_speed * delta, 0.0, 1.0))


## Dondola camminando, si dimena nella tagliola, si piega in avanti quando annusa.
func _animate(delta: float, speed: float) -> void:
	_anim += delta * (2.0 + speed * 2.5)
	var lean := 0.0
	var roll := sin(_anim * 0.5) * 0.04
	match brain.state:
		BlindBrain.State.TRAPPED:
			roll = sin(_anim * 12.0) * 0.12
		BlindBrain.State.SEARCH, BlindBrain.State.SCRATCH:
			lean = 0.2
		BlindBrain.State.RECOIL:
			lean = -0.2
	_model.rotation.x = lerpf(_model.rotation.x, lean, 6.0 * delta)
	_model.rotation.z = roll
	_model.position.y = absf(sin(_anim)) * 0.04 if speed > 0.1 else 0.0


## Ogni step_length metri un passo: si sente (suono) e fa rumore (NoiseBus).
func _footsteps() -> void:
	var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
	_step += moved
	if _step < step_length:
		return
	_step = 0.0
	var running := brain.state == BlindBrain.State.INVESTIGATE
	_feet.volume_db = 0.0 if running else -6.0
	_feet.pitch_scale = 0.8 if running else 0.7
	_feet.play()
	NoiseBus.emit_noise(global_position, step_loudness, self)


## Vorrebbe camminare ma non avanza (un compagno o un altro nemico in mezzo): il cervello cambia meta.
func _check_stuck(delta: float, move: Vector3) -> void:
	var moved := Vector2(global_position.x - _last_pos.x, global_position.z - _last_pos.z).length()
	if move.length() > 0.1 and moved < move.length() * delta * 0.25:
		_stuck += delta
	else:
		_stuck = maxf(_stuck - delta, 0.0)
	if _stuck > stuck_time:
		_stuck = 0.0
		brain.stuck()


func _scratch(delta: float) -> void:
	if brain.state != BlindBrain.State.SCRATCH:
		return
	_scratch_left -= delta
	if _scratch_left <= 0.0:
		_scratch_left = scratch_interval * _fx_rng.randf_range(0.7, 1.3)
		_say(&"blind_scratch", 0.0, 0.8)
		NoiseBus.emit_noise(global_position, scratch_loudness, self)


## Respira e annusa: più spesso quando cerca. È il modo per sentirlo arrivare al buio.
func _breathe(delta: float) -> void:
	_breath_left -= delta
	if _breath_left > 0.0 or _voice.playing:
		return
	var sniffing := brain.state == BlindBrain.State.SEARCH
	_breath_left = _fx_rng.randf_range(0.8, 1.5) if sniffing else _fx_rng.randf_range(3.0, 6.0)
	_say(&"blind_breath", -4.0 if sniffing else -8.0, _fx_rng.randf_range(0.55, 0.7))
	NoiseBus.emit_noise(global_position, breath_loudness, self)


func _say(sound: StringName, volume_db: float, pitch: float) -> void:
	_voice.stream = Sfx.stream(sound)
	_voice.volume_db = volume_db
	_voice.pitch_scale = pitch
	_voice.play()


## Contatto con un giocatore vivo: 3 danni, poi si ritrae (il cervello decide se può colpire).
func _check_touch() -> void:
	for node in get_tree().get_nodes_in_group("player"):
		var p := node as Player
		if p == null or p.health.is_dead():
			continue
		var flat := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z)
		if flat.length() > touch_range or absf(p.global_position.y - global_position.y) > 1.5:
			continue
		if brain.touch():
			_push_dir = -Vector3(flat.x, 0.0, flat.y).normalized()
			# Il grido del colpito non lo richiama (gli altri Ciechi lo sentono): finita la ritirata
			# annusa lì attorno, e chi resta fermo e zitto ha una possibilità.
			_deaf = true
			p.hurt(damage, "il Cieco")
			_deaf = false
		return
