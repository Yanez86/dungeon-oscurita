class_name PlayerInput
extends Node
## Legge tastiera e mouse e li traduce in "intenzioni".
## player.gd usa solo queste intenzioni: in coop, i giocatori remoti
## avranno un'altra sorgente di intenzioni e il movimento non cambierà.
## Anche il menu passa da qui (request_slot, request_drop): non tocca mai il giocatore direttamente.

@export var mouse_sensitivity := 0.0025  ## moltiplicata per Settings.mouse_scale

var move := Vector2.ZERO     ## x = destra/sinistra, y = avanti/indietro
var sprint := false
var crouch := false
var torch_toggle := false
var use_item := false     ## Q: usa l'oggetto selezionato (acciarino, torcia accesa, tagliola)
var interact := false     ## raccogli l'oggetto vicino
var drop := false         ## lascia a terra l'oggetto selezionato
var select_slot := -1     ## slot scelto con i tasti numerici (-1 = nessuno)

## Menu aperto: niente movimento, torcia né interazioni. Slot (1–8) e G funzionano ancora.
var in_menu := false

var _look := Vector2.ZERO
var _requested_slot := -1
var _requested_drop := false


## Chiamato dal giocatore a ogni passo di fisica.
func sample() -> void:
	select_slot = _requested_slot
	drop = _requested_drop or Input.is_action_just_pressed("drop")
	_requested_slot = -1
	_requested_drop = false
	for i in Game.SLOT_KEYS:
		if Input.is_action_just_pressed("slot_%d" % (i + 1)):
			select_slot = i
	if in_menu:
		move = Vector2.ZERO
		sprint = false
		crouch = false
		torch_toggle = false
		use_item = false
		interact = false
		return
	move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	sprint = Input.is_action_pressed("sprint")
	crouch = Input.is_action_pressed("crouch")
	torch_toggle = Input.is_action_just_pressed("torch_toggle")
	use_item = Input.is_action_just_pressed("use_item")
	interact = Input.is_action_just_pressed("interact")


## Dal menu: seleziona uno slot al prossimo passo di fisica.
func request_slot(slot: int) -> void:
	_requested_slot = slot


## Dal menu: lascia a terra l'oggetto selezionato al prossimo passo di fisica.
func request_drop() -> void:
	_requested_drop = true


## Movimento del mouse accumulato dall'ultima lettura.
func consume_look() -> Vector2:
	var d := _look
	_look = Vector2.ZERO
	return d


## Il mouse si cattura con un clic e si libera aprendo il menu (Esc, Tab…).
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look += (event as InputEventMouseMotion).relative * mouse_sensitivity * Settings.mouse_scale
	elif event is InputEventMouseButton and event.is_pressed() and not in_menu:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
