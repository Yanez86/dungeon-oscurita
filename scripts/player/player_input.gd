class_name PlayerInput
extends Node
## Legge tastiera e mouse e li traduce in "intenzioni".
## player.gd usa solo queste intenzioni: in coop, i giocatori remoti
## avranno un'altra sorgente di intenzioni e il movimento non cambierà.

@export var mouse_sensitivity := 0.0025

var move := Vector2.ZERO     ## x = destra/sinistra, y = avanti/indietro
var sprint := false
var crouch := false
var torch_toggle := false

var _look := Vector2.ZERO


## Chiamato dal giocatore a ogni passo di fisica.
func sample() -> void:
	move = Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	sprint = Input.is_action_pressed("sprint")
	crouch = Input.is_action_pressed("crouch")
	torch_toggle = Input.is_action_just_pressed("torch_toggle")


## Movimento del mouse accumulato dall'ultima lettura.
func consume_look() -> Vector2:
	var d := _look
	_look = Vector2.ZERO
	return d


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look += (event as InputEventMouseMotion).relative * mouse_sensitivity
	elif event is InputEventMouseButton and event.is_pressed():
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
