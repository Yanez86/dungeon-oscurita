class_name BlindBrain
extends RefCounted
## Cervello del Cieco, solo dati (come Health): decide cosa fare ma non muove niente.
## Il nodo Blind gli passa i rumori sentiti, gli arrivi, le porte e i contatti,
## e legge stato, meta e velocità. Si prova senza grafica: vedi tests/test_blind.gd.
## Non insegue i giocatori: va sempre verso l'ultimo rumore che ha sentito (GDD, Il Cieco).

enum State {
	WANDER,       ## vaga lento da una cella all'altra, con qualche sosta
	INVESTIGATE,  ## corre verso l'ultimo rumore sentito
	SEARCH,       ## annusa attorno al punto del rumore, poi torna a vagare
	SCRATCH,      ## il rumore è oltre una porta chiusa: gratta, poi rinuncia
	RECOIL,       ## ha appena colpito: si ritrae e per un po' non colpisce
	TRAPPED,      ## preso in una tagliola
}

## Che meta cerca il corpo: nessuna (fermo), un punto preciso, una cella a caso
## (vagando) o una cella vicina al punto da controllare (annusando).
enum Goal { NONE, POINT, WANDER, SEARCH }

const STATE_NAMES := {
	State.WANDER: "vaga", State.INVESTIGATE: "indaga", State.SEARCH: "cerca",
	State.SCRATCH: "gratta", State.RECOIL: "si ritrae", State.TRAPPED: "intrappolato",
}

signal state_changed(from: State, to: State)

# Valori da bilanciare: li copia blind.gd dai suoi @export.
var hearing_range := 20.0  ## metri a cui arriva un rumore di loudness 1
var wander_speed := 1.2
var investigate_speed := 4.5
var search_speed := 1.5
var wander_pause := Vector2(1.0, 3.0)  ## secondi di sosta tra un tratto e l'altro (min, max)
var search_time := 4.0
var search_pause := 0.6  ## sosta per annusare tra un tratto e l'altro della ricerca
var scratch_time := 3.0
var recoil_time := 2.0

var rng := RandomNumberGenerator.new()
var state := State.WANDER
var goal := Goal.NONE
var goal_point := Vector3.ZERO  ## Goal.POINT: dove andare; Goal.SEARCH: il centro della ricerca
var goal_version := 0           ## cambia a ogni nuova meta: il corpo ricalcola il percorso
var position := Vector3.ZERO    ## dove si trova il corpo (lo aggiorna blind.gd)

var _timer := 0.0        ## tempo rimasto nello stato (ricerca, graffi, ritirata, trappola)
var _pause := 0.0        ## sosta prima del prossimo tratto (vagare, annusare)
var _pending := false    ## ha sentito un rumore mentre era bloccato: ci andrà appena può
var _pending_point := Vector3.ZERO


func _init(seed_value: int = 0) -> void:
	rng.seed = seed_value
	_pause = rng.randf_range(wander_pause.x, wander_pause.y)


static func state_name(s: State) -> String:
	return STATE_NAMES.get(s, "?")


## Vero se un rumore di questa intensità si sente da `distance` metri (misurati lungo i corridoi).
func can_hear(loudness: float, distance: float) -> bool:
	return distance >= 0.0 and distance <= loudness * hearing_range


## Un rumore arrivato da `distance` metri. Vero se l'ha sentito.
## Da bloccato (ritirata, trappola) se lo ricorda e ci va appena libero.
func hear(point: Vector3, loudness: float, distance: float) -> bool:
	if not can_hear(loudness, distance):
		return false
	if state == State.RECOIL or state == State.TRAPPED:
		_pending = true
		_pending_point = point
	else:
		_investigate(point)
	return true


## Il corpo è arrivato alla meta.
func arrived() -> void:
	match state:
		State.INVESTIGATE:
			_set_state(State.SEARCH)
			_timer = search_time
			_stop(search_pause)
		State.SEARCH:
			_stop(search_pause)
		State.WANDER:
			_stop(rng.randf_range(wander_pause.x, wander_pause.y))


## La strada verso il rumore finisce contro una porta chiusa: gratta per un po', poi rinuncia.
func blocked_by_door() -> void:
	if state != State.INVESTIGATE:
		arrived()
		return
	_set_state(State.SCRATCH)
	_timer = scratch_time
	_stop(0.0)


## Si è aperta una porta: se stava grattando riprende la strada verso il rumore.
func door_opened() -> void:
	if state == State.SCRATCH:
		_investigate(goal_point)


## Il corpo non riesce ad avanzare (un compagno o un altro nemico in mezzo): cambia meta.
func stuck() -> void:
	if state == State.INVESTIGATE:
		arrived()  # abbastanza vicino: annusa qui
	elif goal != Goal.NONE:
		_set_goal(goal, goal_point)


## Ha toccato un giocatore. Vero se lo colpisce: non colpisce mentre si ritrae o è in trappola.
func touch() -> bool:
	if state == State.RECOIL or state == State.TRAPPED:
		return false
	_pending = false
	_set_state(State.RECOIL)
	_timer = recoil_time
	_stop(0.0)
	return true


## È finito in una tagliola: fermo per `seconds` secondi.
func trap(seconds: float) -> void:
	_set_state(State.TRAPPED)
	_timer = seconds
	_stop(0.0)


## Metri al secondo con cui il corpo deve camminare (0 = fermo).
func speed() -> float:
	if goal == Goal.NONE:
		return 0.0
	match state:
		State.WANDER:
			return wander_speed
		State.INVESTIGATE:
			return investigate_speed
		State.SEARCH:
			return search_speed
	return 0.0


func update(delta: float) -> void:
	match state:
		State.WANDER:
			_count_pause(delta, Goal.WANDER)
		State.SEARCH:
			_timer -= delta
			if _timer <= 0.0:
				_wander()
			else:
				_count_pause(delta, Goal.SEARCH)
		State.SCRATCH:
			_timer -= delta
			if _timer <= 0.0:
				_wander()
		State.RECOIL, State.TRAPPED:
			_timer -= delta
			if _timer <= 0.0:
				_recover()


## Da fermo, finita la sosta parte per un nuovo tratto.
func _count_pause(delta: float, next: Goal) -> void:
	if goal != Goal.NONE:
		return
	_pause -= delta
	if _pause <= 0.0:
		_set_goal(next, goal_point)


## Finita la ritirata o la trappola: va verso il rumore sentito nel frattempo,
## altrimenti annusa dove si trova (lì c'era il giocatore, o la tagliola).
func _recover() -> void:
	if _pending:
		_pending = false
		_investigate(_pending_point)
		return
	_set_state(State.SEARCH)
	_timer = search_time
	goal_point = position
	_stop(search_pause)


func _investigate(point: Vector3) -> void:
	_set_state(State.INVESTIGATE)
	_set_goal(Goal.POINT, point)


func _wander() -> void:
	_set_state(State.WANDER)
	_stop(rng.randf_range(wander_pause.x, wander_pause.y))


## Si ferma per `pause` secondi (poi, se lo stato lo prevede, riparte da solo).
func _stop(pause: float) -> void:
	_pause = pause
	_set_goal(Goal.NONE, goal_point)


func _set_state(s: State) -> void:
	if s == state:
		return
	var old := state
	state = s
	state_changed.emit(old, s)


func _set_goal(g: Goal, point: Vector3) -> void:
	goal = g
	goal_point = point
	goal_version += 1
