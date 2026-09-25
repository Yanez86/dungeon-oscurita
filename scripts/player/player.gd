class_name Player
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

@export_group("Oggetti")
@export var inventory_slots := 5
@export var start_items: Array[StringName] = [Items.FLINT]
@export var pickup_range := 1.8     ## metri entro cui si può raccogliere
@export var pickup_loudness := 0.1
@export var drop_loudness := 0.35   ## lasciare a terra fa rumore (GDD)
@export var flint_loudness := 0.25  ## lo scatto dell'acciarino

## Frase breve da mostrare a schermo (la legge l'HUD).
signal message(text: String)
## Il giocatore ha lasciato un oggetto: main.gd lo fa comparire nel dungeon.
signal item_dropped(item: StringName, world_pos: Vector3)

const HEAD_STAND := 1.6
const HEAD_CROUCH := 1.0

@onready var input: PlayerInput = $Input
@onready var head: Node3D = $Head
@onready var torch: Torch = $Head/Torch

var inventory: Inventory
var nearby_pickup: Pickup = null  ## oggetto raccoglibile più vicino (per l'HUD)
var nearby_door: Door = null      ## porta chiusa a portata di mano (per l'HUD)

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _step_progress := 0.0


func _ready() -> void:
	add_to_group("player")
	inventory = Inventory.new(inventory_slots)
	torch.burned_out.connect(func() -> void: message.emit("La torcia si è consumata."))
	reset_for_run()


## Inizio partita: torcia nuova e inventario iniziale. Tra un piano e l'altro non si chiama.
func reset_for_run() -> void:
	inventory.clear()
	for id in start_items:
		inventory.add(id)
	torch.refill()


func _physics_process(delta: float) -> void:
	input.sample()

	var look := input.consume_look()
	rotate_y(-look.x)
	head.rotation.x = clampf(head.rotation.x - look.y, -1.4, 1.4)

	_handle_items()

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


func _handle_items() -> void:
	nearby_pickup = _find_nearby_pickup()
	nearby_door = null if nearby_pickup else _find_nearby_door()
	if input.select_slot >= 0:
		inventory.select(input.select_slot)
	if input.torch_toggle:
		_toggle_torch()
	if input.new_torch:
		_light_spare_torch()
	if input.interact:
		if nearby_pickup:
			_pick_up()
		elif nearby_door:
			nearby_door.open(self)
			nearby_door = null
	if input.drop:
		_drop_selected()


## F: spegnere è gratis, riaccendere richiede l'acciarino.
func _toggle_torch() -> void:
	if torch.lit:
		torch.extinguish()
	elif torch.fuel <= 0.0:
		message.emit("La torcia è consumata: Q per accenderne un'altra.")
	elif not inventory.has(Items.FLINT):
		message.emit("Serve un acciarino per riaccenderla.")
	else:
		torch.relight()
		NoiseBus.emit_noise(global_position, flint_loudness, self)


## Q: accende una torcia di scorta al posto di quella in mano (che si butta).
## Se quella in mano è accesa si usa la sua fiamma, altrimenti serve l'acciarino.
func _light_spare_torch() -> void:
	if not inventory.has(Items.TORCH):
		message.emit("Nessuna torcia di scorta.")
		return
	if not torch.lit:
		if not inventory.has(Items.FLINT):
			message.emit("Serve un acciarino per accenderla.")
			return
		NoiseBus.emit_noise(global_position, flint_loudness, self)
	inventory.remove(Items.TORCH)
	torch.refill()
	message.emit("Nuova torcia accesa.")


## E: raccoglie l'oggetto più vicino, se c'è posto.
func _pick_up() -> void:
	if nearby_pickup == null:
		return
	if not inventory.add(nearby_pickup.item):
		message.emit("Inventario pieno: G per lasciare qualcosa.")
		return
	message.emit("Raccolto: %s" % nearby_pickup.display_name())
	nearby_pickup.queue_free()
	nearby_pickup = null
	NoiseBus.emit_noise(global_position, pickup_loudness, self)


## G: lascia l'oggetto dello slot selezionato davanti ai piedi.
func _drop_selected() -> void:
	var id := inventory.take(inventory.selected)
	if id == &"":
		return
	var pos := global_position - global_transform.basis.z * 0.6
	pos.y = 0.0
	item_dropped.emit(id, pos)
	NoiseBus.emit_noise(global_position, drop_loudness, self)


func _find_nearby_pickup() -> Pickup:
	var best: Pickup = null
	var best_d := pickup_range
	for node in get_tree().get_nodes_in_group("pickup"):
		var p := node as Pickup
		if p == null or p.is_queued_for_deletion():
			continue
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if d < best_d:
			best_d = d
			best = p
	return best


## La porta chiusa più vicina entro `pickup_range` (le aperte non contano).
func _find_nearby_door() -> Door:
	var best: Door = null
	var best_d := pickup_range
	for node in get_tree().get_nodes_in_group("door"):
		var door := node as Door
		if door == null or door.is_open or door.is_queued_for_deletion():
			continue
		var d := Vector2(door.global_position.x - global_position.x, door.global_position.z - global_position.z).length()
		if d < best_d:
			best_d = d
			best = door
	return best


## Ogni `step_length` metri percorsi genera un evento rumore.
func _update_footsteps(delta: float, loudness: float) -> void:
	var ground_speed := Vector2(velocity.x, velocity.z).length()
	if not is_on_floor() or ground_speed < 0.2:
		return
	_step_progress += ground_speed * delta
	if _step_progress >= step_length:
		_step_progress = 0.0
		NoiseBus.emit_noise(global_position, loudness, self)
