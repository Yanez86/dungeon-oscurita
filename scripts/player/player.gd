class_name Player
extends CharacterBody3D
## Giocatore in prima persona. Non legge mai la tastiera direttamente:
## usa le intenzioni del nodo Input (vedi player_input.gd).

@export var player_name := "Esploratore"  ## in coop sarà il nome scelto nella lobby
@export var walk_speed := 3.0
@export var sprint_speed := 5.5
@export var crouch_speed := 1.5
@export var acceleration := 10.0
@export var step_length := 1.6  ## metri tra un passo e l'altro

@export_group("Rumore dei passi (0-1)")
@export var crouch_loudness := 0.1
@export var walk_loudness := 0.3
@export var sprint_loudness := 0.6

@export_group("Energia")
@export var max_health := 10  ## pochi punti: il combattimento è raro e letale (GDD)

@export_group("Oggetti")
@export var inventory_slots := 5
@export var start_items: Array[StringName] = [Items.FLINT]
@export var pickup_range := 1.8     ## metri entro cui si può raccogliere
@export var drop_distance := 0.6    ## metri davanti ai piedi dove cade un oggetto lasciato (G)
@export var torch_throw_distance := 1.2  ## metri davanti a sé dove cade la torcia buttata (Q)
@export var pickup_loudness := 0.1
@export var drop_loudness := 0.35   ## lasciare a terra fa rumore (GDD)
@export var flint_loudness := 0.25  ## lo scatto dell'acciarino

## Frase breve da mostrare a schermo (la legge l'HUD).
signal message(text: String)
## Il giocatore ha lasciato un oggetto: main.gd lo fa comparire nel dungeon.
signal item_dropped(item: StringName, world_pos: Vector3)
## Il giocatore ha messo a terra la torcia che aveva in mano (accesa o spenta):
## main.gd la fa comparire nel dungeon, dove continua a bruciare.
signal torch_dropped(world_pos: Vector3, fuel: float, max_fuel: float, lit: bool)

const HEAD_STAND := 1.6
const HEAD_CROUCH := 1.0

@onready var input: PlayerInput = $Input
@onready var head: Node3D = $Head
@onready var torch: Torch = $Head/Torch

var inventory: Inventory
var health: Health
var journal := Journal.new()  ## diario della partita (lo mostra il menu)
var nearby_pickup: Pickup = null  ## oggetto raccoglibile più vicino (per l'HUD)
var nearby_door: Door = null      ## porta (aperta o chiusa) a portata di mano (per l'HUD)

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _step_progress := 0.0


func _ready() -> void:
	add_to_group("player")
	inventory = Inventory.new(inventory_slots)
	health = Health.new(max_health)
	torch.burned_out.connect(_on_torch_burned_out)
	reset_for_run()


## Inizio partita: energia piena, diario vuoto, mani vuote e inventario iniziale;
## la prima torcia è a terra nella stanza d'ingresso. Tra un piano e l'altro non si chiama.
func reset_for_run() -> void:
	health.reset()
	journal.clear()
	inventory.clear()
	for id in start_items:
		inventory.add(id)
	torch.empty()
	message.emit("Raccogli la torcia a terra (E), seleziona l'acciarino e accendila (Q).")


## Scrive una riga nel diario, sotto il piano corrente.
func note(text: String) -> void:
	journal.add(Game.floor_number, text)


func _on_torch_burned_out() -> void:
	message.emit("La torcia si è consumata.")
	note("La torcia si è consumata.")


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
		_extinguish_torch()
	if input.new_torch:
		_light_torch()
	if input.interact:
		if nearby_pickup:
			_pick_up()
		elif nearby_door:
			_use_door(nearby_door)
	if input.drop:
		_drop_selected()


## F: spegnere è sempre gratis (per riaccendere: acciarino selezionato + Q).
func _extinguish_torch() -> void:
	if torch.lit:
		torch.extinguish()
	elif torch.fuel > 0.0 or inventory.has(Items.TORCH):
		message.emit("Per accenderla seleziona l'acciarino e premi Q.")


## Q: con la torcia in mano accesa la si butta a terra, dove continua a bruciare;
## se c'è una torcia di scorta la si accende dalla sua fiamma. Al buio serve
## l'acciarino selezionato: si riaccende prima la torcia già usata e, se è
## consumata, una di scorta.
func _light_torch() -> void:
	if torch.lit:
		var pos := _drop_position(torch_throw_distance)
		_put_down_torch(pos)
		NoiseBus.emit_noise(pos, drop_loudness, self)
		if inventory.remove(Items.TORCH):
			torch.refill()
			message.emit("Torcia a terra: ne accendi una nuova dalla sua fiamma.")
			note("Nuova torcia accesa dalla fiamma di quella a terra.")
		else:
			message.emit("Torcia a terra: brucia finché non si consuma. E per riprenderla.")
			note("Torcia accesa lasciata a terra.")
		return

	var relight := torch.fuel > 0.0
	if not relight and not inventory.has(Items.TORCH):
		message.emit("Nessuna torcia da accendere.")
		return
	if inventory.selected_item() != Items.FLINT:
		var slot := inventory.slots.find(Items.FLINT)
		if slot == -1:
			message.emit("Serve un acciarino per accenderla.")
		else:
			message.emit("Seleziona l'acciarino (%d) e premi Q." % (slot + 1))
		return
	NoiseBus.emit_noise(global_position, flint_loudness, self)
	if relight:
		torch.relight()
		message.emit("Torcia riaccesa.")
	else:
		inventory.remove(Items.TORCH)
		torch.refill()
		message.emit("Nuova torcia accesa.")
		note("Nuova torcia accesa.")


## E: raccoglie l'oggetto più vicino, se c'è posto.
func _pick_up() -> void:
	if nearby_pickup == null:
		return
	if nearby_pickup is GroundTorch:
		_take_ground_torch(nearby_pickup as GroundTorch)
		return
	if not inventory.add(nearby_pickup.item):
		message.emit("Inventario pieno: G per lasciare qualcosa.")
		return
	if nearby_pickup.item == Items.TORCH and torch.fuel <= 0.0:
		message.emit("Raccolto: %s. Q per accenderla." % nearby_pickup.display_name())
	else:
		message.emit("Raccolto: %s" % nearby_pickup.display_name())
	note("Raccolto: %s." % nearby_pickup.display_name())
	nearby_pickup.queue_free()
	nearby_pickup = null
	NoiseBus.emit_noise(global_position, pickup_loudness, self)


## E su una torcia usata a terra: torna in mano così com'è, accesa o spenta.
## Se in mano ce n'era un'altra, resta a terra al suo posto (scambio).
func _take_ground_torch(ground: GroundTorch) -> void:
	var swap := torch.fuel > 0.0
	if swap:
		_put_down_torch(ground.global_position)
	torch.hold(ground.remaining_fuel(), ground.is_lit())
	ground.queue_free()
	nearby_pickup = null
	if swap:
		message.emit("Torce scambiate.")
	elif torch.lit:
		message.emit("Hai ripreso la torcia accesa.")
	else:
		message.emit("Hai ripreso la torcia: acciarino e Q per accenderla.")
	NoiseBus.emit_noise(global_position, pickup_loudness, self)


## Mette a terra la torcia che si ha in mano, così com'è: si resta a mani vuote.
func _put_down_torch(pos: Vector3) -> void:
	torch_dropped.emit(pos, torch.fuel, torch.max_fuel, torch.lit)
	torch.empty()


## G: lascia l'oggetto dello slot selezionato davanti ai piedi.
func _drop_selected() -> void:
	var id := inventory.take(inventory.selected)
	if id == &"":
		return
	item_dropped.emit(id, _drop_position(drop_distance))
	NoiseBus.emit_noise(global_position, drop_loudness, self)
	note("Lasciato a terra: %s." % Items.display_name(id))


## Punto del pavimento `distance` metri davanti a sé, fermandosi prima di muri,
## porte e arredi: un oggetto (o una fiamma) non deve finire dentro un muro.
func _drop_position(distance: float) -> Vector3:
	var from := global_position + Vector3.UP * 0.3
	var forward := -global_transform.basis.z
	var to := from + forward * distance
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty():
		var wall_distance := from.distance_to(hit["position"] as Vector3)
		to = from + forward * maxf(wall_distance - 0.25, 0.0)
	return Vector3(to.x, 0.0, to.z)


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


## E su una porta: se è chiusa la apre, se è aperta la richiude (non da dentro il vano).
func _use_door(door: Door) -> void:
	if not door.is_open:
		door.open(self)
	elif not door.close(self):
		message.emit("Esci dal vano per chiudere la porta.")


## La porta più vicina entro `pickup_range`, aperta o chiusa.
func _find_nearby_door() -> Door:
	var best: Door = null
	var best_d := pickup_range
	for node in get_tree().get_nodes_in_group("door"):
		var door := node as Door
		if door == null or door.is_queued_for_deletion():
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
