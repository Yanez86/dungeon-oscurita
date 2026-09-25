extends CharacterBody3D
## Giocatore in prima persona. Non legge mai la tastiera direttamente:
## usa le intenzioni del nodo Input (vedi player_input.gd).

@export var walk_speed := 3.0
@export var sprint_speed := 5.5
@export var crouch_speed := 1.5
@export var acceleration := 10.0
@export var step_length := 1.6  ## metri tra un passo e l'altro

@export_group("Rumore dei passi (0-1)")
@export var crouch_loudness := 0.1
@export var walk_loudness := 0.3
@export var sprint_loudness := 0.6

const HEAD_STAND := 1.6
const HEAD_CROUCH := 1.0

@onready var input: PlayerInput = $Input
@onready var head: Node3D = $Head
@onready var torch: Torch = $Head/Torch

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _step_progress := 0.0


func _ready() -> void:
	add_to_group("player")


func _physics_process(delta: float) -> void:
	input.sample()

	var look := input.consume_look()
	rotate_y(-look.x)
	head.rotation.x = clampf(head.rotation.x - look.y, -1.4, 1.4)

	if input.torch_toggle:
		torch.toggle()

	var speed := walk_speed
	var loudness := walk_loudness
	if input.crouch:
		speed = crouch_speed
		loudness = crouch_loudness
	elif input.sprint:
		speed = sprint_speed
		loudness = sprint_loudness
	var head_y := HEAD_CROUCH if input.crouch else HEAD_STAND
	head.position.y = lerpf(head.position.y, head_y, 10.0 * delta)

	var dir := (transform.basis * Vector3(input.move.x, 0.0, input.move.y)).normalized()
	var target := dir * speed
	velocity.x = lerpf(velocity.x, target.x, acceleration * delta)
	velocity.z = lerpf(velocity.z, target.z, acceleration * delta)
	if not is_on_floor():
		velocity.y -= _gravity * delta
	move_and_slide()

	_update_footsteps(delta, loudness)


## Ogni `step_length` metri percorsi genera un evento rumore.
func _update_footsteps(delta: float, loudness: float) -> void:
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or ground_speed < 0.2:
		return
	_step_progress += ground_speed * delta
	if _step_progress >= step_length:
		_step_progress = 0.0
		NoiseBus.emit_noise(global_position, loudness, self)
