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
@export var death_fall_time := 0.8  ## secondi in cui la vista crolla a terra quando si muore
@export var death_head_height := 0.3  ## altezza della vista da morti (metri)
@export var hurt_loudness := 0.6  ## chi viene ferito grida: i nemici lo sentono

@export_group("Fossa")
@export var climb_time := 2.5       ## secondi per risalire con la corda
@export var climb_loudness := 0.3   ## la corda scricchiola, gli stivali raschiano la parete

@export_group("Oggetti")
@export var inventory_slots := 5
@export var start_items: Array[StringName] = [Items.FLINT]
@export var pickup_range := 1.8     ## metri entro cui si può raccogliere
@export var drop_distance := 0.6    ## metri davanti ai piedi dove cade un oggetto lasciato (G)
@export var torch_throw_distance := 1.2  ## metri davanti a sé dove cade la torcia buttata (Q)
@export var pickup_loudness := 0.1
@export var drop_loudness := 0.35   ## lasciare a terra fa rumore (GDD)
@export var flint_loudness := 0.25  ## lo scatto dell'acciarino
@export var bear_trap_distance := 0.9  ## metri davanti ai piedi dove si posa la tagliola (Q)
@export var bear_trap_loudness := 0.35  ## aprire e posare la tagliola fa rumore
@export var backpack_slots := 3        ## slot in più quando si mette lo zaino in spalla (uno solo a testa)
@export var backpack_loudness := 0.15  ## il cuoio e le fibbie si sentono appena
@export var knock_range := 1.4       ## metri: E verso un muro vicino (e niente da raccogliere o aprire) ci bussa
@export var knock_loudness := 0.2    ## bussare si sente: i muri segreti suonano vuoto

## Frase breve da mostrare a schermo (la legge l'HUD).
signal message(text: String)
## Il giocatore ha lasciato un oggetto: main.gd lo fa comparire nel dungeon.
signal item_dropped(item: StringName, world_pos: Vector3)
## Il giocatore ha messo a terra la torcia in uso (accesa o spenta) o del legno bruciato (fuel 0):
## main.gd la fa comparire nel dungeon, dove (se accesa) continua a bruciare.
signal torch_dropped(world_pos: Vector3, fuel: float, max_fuel: float, lit: bool)
## Ha legato una corda per risalire dalla fossa: la botola la mostra appesa, per chi cade dopo.
signal rope_hung
## È arrivato un colpo: `damage` punti tolti, `blocked` parati dallo scudo. L'HUD fa lampeggiare lo schermo.
signal hurt_taken(damage: int, blocked: int)
## Ha posato una tagliola: main.gd la fa comparire nel dungeon, armata.
signal bear_trap_placed(world_pos: Vector3)

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
var death_cause := ""  ## chi ha tolto l'ultimo punto di energia (per la schermata di morte)
var in_pit := false    ## caduto in una fossa (botola aperta): si esce solo con una corda (E)
var pit_rope := false  ## nella fossa c'è già una corda appesa

var _gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
var _step_progress := 0.0
var _death_tween: Tween
var _climb_tween: Tween
var _pit_exit := Vector3.ZERO   ## dove si arriva risalendo (sul bordo)
var _pit_rope := Vector3.ZERO   ## dove pende la corda, sul fondo


func _ready() -> void:
	add_to_group("player")
	inventory = Inventory.new(inventory_slots)
	health = Health.new(max_health)
	health.died.connect(_on_died)
	torch.burned_out.connect(_on_torch_burned_out)
	reset_for_run()


## Inizio partita: energia piena, diario vuoto, mani vuote e inventario iniziale (senza zaino);
## la prima torcia è a terra nella stanza d'ingresso. Tra un piano e l'altro non si chiama.
func reset_for_run() -> void:
	if _death_tween:
		_death_tween.kill()
	if _climb_tween:
		_climb_tween.kill()
	head.position.y = HEAD_STAND
	head.rotation.z = 0.0
	death_cause = ""
	in_pit = false
	pit_rope = false
	health.reset()
	journal.clear()
	inventory.reset(inventory_slots)
	for id in start_items:
		inventory.add(id)
	torch.empty()
	message.emit("Raccogli la torcia a terra (E), seleziona l'acciarino e accendila (Q).")


## Scrive una riga nel diario, sotto il piano corrente.
func note(text: String) -> void:
	journal.add(Game.floor_number, text)


## "da" + la causa, con la preposizione articolata: "il Cieco" → "dal Cieco", "una freccia" → "da una freccia".
static func by_cause(cause: String) -> String:
	for article: String in ["il ", "lo ", "la ", "i ", "gli ", "le "]:
		if cause.begins_with(article):
			return {"il ": "dal ", "lo ": "dallo ", "la ": "dalla ", "i ": "dai ", "gli ": "dagli ", "le ": "dalle "}[article] \
				+ cause.substr(article.length())
	if cause.begins_with("l'"):
		return "dall'" + cause.substr(2)
	return "da " + cause


## Unico ingresso dei danni (trappole, nemici): lo scudo nell'inventario para 1 danno (vedi Shield),
## il resto toglie energia e fa gridare (suono e rumore). Ricorda la causa (con l'articolo: "il Cieco")
## per il diario e la schermata di morte ("Ucciso dal Cieco."). Restituisce l'energia tolta davvero.
func hurt(amount: int, cause: String) -> int:
	if amount <= 0 or health.is_dead():
		return 0
	var shield := Shield.absorb(inventory, amount)
	var blocked := Shield.BLOCK if shield != Shield.Result.NONE else 0
	if shield != Shield.Result.NONE:
		_shield_blocked(shield == Shield.Result.BROKEN)
	death_cause = cause  # prima del danno: se è l'ultimo, _on_died la legge già
	var taken := health.damage(amount - blocked)
	if taken > 0:
		_cry_out()
	hurt_taken.emit(taken, blocked)
	if taken > 0 and not health.is_dead():
		note("Colpito %s: -%d energia." % [by_cause(cause), taken])
	return taken


## Morte certa (schiacciati da un masso, nessuna via d'uscita): niente parate.
func kill(cause: String) -> void:
	if health.is_dead():
		return
	death_cause = cause
	var taken := health.damage(health.hp)
	_cry_out()
	hurt_taken.emit(taken, 0)


func _cry_out() -> void:
	Sfx.play_at(self, &"player_hit", head.global_position)
	NoiseBus.emit_noise(global_position, hurt_loudness, self)


func _shield_blocked(broken: bool) -> void:
	Sfx.play_at(self, &"shield_break" if broken else &"shield_block", head.global_position)
	var text := "Lo scudo si rompe parando il colpo." if broken else "Lo scudo para parte del colpo e si incrina."
	message.emit(text)
	note(text)


## Accovacciati si passa sopra i fili tesi e sotto i dardi (vedi le trappole).
func is_crouching() -> bool:
	return input.crouch and not health.is_dead()


## La torcia sfugge di mano (per esempio cadendo in una fossa) e resta a terra in `pos`, così com'è.
## Falso se non se ne aveva una in mano (quella riposta resta nell'inventario).
func drop_torch(pos: Vector3) -> bool:
	if not Torches.in_hand(inventory):
		return false
	_put_down_torch(pos)
	message.emit("La torcia ti sfugge di mano!")
	return true


## Una botola si è aperta sotto i piedi: si è sul fondo di una fossa. `rope_spot` è dove pende
## (o penderà) la corda, sul fondo; `exit` il punto sul bordo dove si arriva risalendo.
## `rope`: c'è già una corda appesa, lasciata da chi è caduto prima.
func fall_into_pit(rope_spot: Vector3, exit: Vector3, rope: bool) -> void:
	in_pit = true
	pit_rope = rope
	_pit_rope = rope_spot
	_pit_exit = exit


## E nella fossa: con una corda (già appesa o dall'inventario) si risale in `climb_time` secondi.
## La corda legata resta appesa: chi cade dopo può usarla.
func _climb_out() -> void:
	if _is_climbing():
		return
	if not pit_rope:
		if not inventory.remove(Items.ROPE):
			message.emit("Senza una corda non puoi risalire.")
			return
		pit_rope = true
		rope_hung.emit()
		note("Legata una corda per risalire dalla fossa: resta appesa lì.")
	message.emit("Ti arrampichi sulla corda…")
	NoiseBus.emit_noise(global_position, climb_loudness, self)
	velocity = Vector3.ZERO
	var top := Vector3(_pit_rope.x, _pit_exit.y, _pit_rope.z)
	_climb_tween = create_tween()
	_climb_tween.tween_property(self, "global_position", _pit_rope, 0.4)
	_climb_tween.tween_property(self, "global_position", top, climb_time) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_climb_tween.tween_property(self, "global_position", _pit_exit, 0.5)
	_climb_tween.tween_callback(_on_climbed_out)


func _on_climbed_out() -> void:
	in_pit = false
	pit_rope = false
	message.emit("Sei fuori dalla fossa.")


func _is_climbing() -> bool:
	return _climb_tween != null and _climb_tween.is_running()


## In mano o riposta, consumata resta nello slot come legno bruciato.
func _on_torch_burned_out() -> void:
	Torches.burn_out(inventory)
	torch.empty()
	message.emit("La torcia si è consumata: resta il legno bruciato (G per buttarlo).")
	note("La torcia si è consumata.")


## Energia a zero: la vista crolla di lato fino a terra. La schermata di fine la mostra main.gd.
func _on_died() -> void:
	note("Ucciso %s." % by_cause(death_cause) if death_cause != "" else "Sei morto.")
	nearby_pickup = null
	nearby_door = null
	if _climb_tween:
		_climb_tween.kill()  # si ricade giù dalla corda
	if _death_tween:
		_death_tween.kill()
	_death_tween = create_tween().set_parallel().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_death_tween.tween_property(head, "position:y", death_head_height, death_fall_time)
	_death_tween.tween_property(head, "rotation:z", 1.3, death_fall_time)


func _physics_process(delta: float) -> void:
	input.sample()
	_sync_torch()
	if health.is_dead():
		input.consume_look()  # da morti non ci si guarda intorno
		velocity.x = 0.0
		velocity.z = 0.0
		if not is_on_floor():
			velocity.y -= _gravity * delta
		move_and_slide()
		return

	var look := input.consume_look()
	rotate_y(-look.x)
	head.rotation.x = clampf(head.rotation.x - look.y, -1.4, 1.4)
	if _is_climbing():
		return  # la corda porta su da sola (vedi _climb_out)

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
	if input.use_item:
		_use_selected()
	if input.interact:
		if nearby_pickup:
			_pick_up()
		elif nearby_door:
			_use_door(nearby_door)
		elif in_pit:
			_climb_out()
		else:
			_knock()
	if input.drop:
		_drop_selected()
	_sync_torch()


## La torcia in uso fa luce solo in mano (slot selezionato): riposta brucia al buio.
## L'id nello slot segue accesa/spenta, anche quando a spegnerla è altro (una folata dalle grate).
func _sync_torch() -> void:
	torch.stowed = not Torches.in_hand(inventory)
	if torch.fuel > 0.0:
		Torches.set_lit(inventory, torch.lit)


## F: spegne la torcia in mano (è gratis; per riaccenderla serve l'acciarino). Riposta non la si
## spegne: brucia finché non la si riprende in mano o si consuma.
func _extinguish_torch() -> void:
	if torch.lit and Torches.in_hand(inventory):
		torch.extinguish()
	elif torch.lit:
		message.emit("Prendi in mano la torcia (%d) per spegnerla." % (Torches.active_slot(inventory) + 1))
	elif Torches.can_light(inventory):
		_light_hint()


## Q: usa l'oggetto selezionato. Gli oggetti che non si usano (corda, scudo…) dicono come fare luce.
func _use_selected() -> void:
	var id := inventory.selected_item()
	if id == Items.BEAR_TRAP:
		_place_bear_trap()
	elif id == Items.TORCH_LIT:
		_throw_torch()
	elif id == Items.FLINT:
		_strike_flint()
	elif id == Items.BACKPACK:
		_wear_backpack()
	elif id == Items.TORCH_BURNT:
		message.emit("Legno bruciato: non fa più luce. G per buttarlo.")
	else:
		_light_hint()


## Ha già uno zaino in spalla: l'inventario è più grande di quello iniziale.
func has_backpack() -> bool:
	return inventory.capacity() > inventory_slots


## Q con lo zaino: lo si mette in spalla e l'inventario guadagna `backpack_slots` posti, per tutta la partita.
## Uno solo a testa: un secondo zaino resta un oggetto da lasciare (in coop, a un compagno).
func _wear_backpack() -> void:
	if has_backpack():
		message.emit("Hai già uno zaino in spalla.")
		return
	inventory.take(inventory.selected)
	inventory.grow(backpack_slots)
	Sfx.play_at(self, &"backpack_on", head.global_position)
	NoiseBus.emit_noise(global_position, backpack_loudness, self)
	message.emit("Zaino in spalla: %d posti in più (tasti 1–%d)." % [backpack_slots, inventory.capacity()])
	note("Messo in spalla lo zaino: %d posti nell'inventario." % inventory.capacity())


## Q con la torcia accesa in mano: la butta a terra, dove continua a bruciare. Se ce n'è una
## nuova la accende dalla sua fiamma, e la nuova resta in mano nello stesso slot.
func _throw_torch() -> void:
	var slot := inventory.selected
	var pos := _drop_position(torch_throw_distance)
	_put_down_torch(pos)
	NoiseBus.emit_noise(pos, drop_loudness, self)
	if Torches.light_spare(inventory, slot) != -1:
		torch.refill()
		message.emit("Torcia a terra: ne accendi una nuova dalla sua fiamma.")
		note("Nuova torcia accesa dalla fiamma di quella a terra.")
	else:
		message.emit("Torcia a terra: brucia finché non si consuma. E per riprenderla.")
		note("Torcia accesa lasciata a terra.")


## Q con l'acciarino: riaccende la torcia in uso, se è spenta, altrimenti una nuova,
## e la prende in mano. Lo scatto si sente.
func _strike_flint() -> void:
	if torch.lit or not Torches.can_light(inventory):
		_light_hint()
		return
	NoiseBus.emit_noise(global_position, flint_loudness, self)
	var slot := Torches.active_slot(inventory)
	if slot != -1:
		torch.relight()
		Torches.set_lit(inventory, true)
		message.emit("Torcia riaccesa.")
	else:
		slot = Torches.light_spare(inventory)
		torch.refill()
		message.emit("Nuova torcia accesa.")
		note("Nuova torcia accesa.")
	inventory.select(slot)


## Cosa serve per fare luce, quando Q (o F) non può farla.
func _light_hint() -> void:
	if torch.lit:
		message.emit("Hai già una torcia accesa: selezionala (%d)." % (Torches.active_slot(inventory) + 1))
	elif not Torches.can_light(inventory):
		message.emit("Nessuna torcia da accendere.")
	elif not inventory.has(Items.FLINT):
		message.emit("Serve un acciarino per accenderla.")
	else:
		message.emit("Seleziona l'acciarino (%d) e premi Q." % (inventory.slots.find(Items.FLINT) + 1))


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
	if nearby_pickup.item == Items.TORCH and not torch.lit:
		message.emit("Raccolto: %s. Acciarino e Q per accenderla." % nearby_pickup.display_name())
	elif Treasures.is_treasure(nearby_pickup.item):
		Sfx.play_at(self, &"treasure_pickup", nearby_pickup.global_position)
		message.emit("Raccolto: %s. Vale %d punti se lo porti giù per la scala." % [
			nearby_pickup.display_name(), Items.VALUES[nearby_pickup.item]])
	else:
		message.emit("Raccolto: %s" % nearby_pickup.display_name())
	note("Raccolto: %s." % nearby_pickup.display_name())
	nearby_pickup.queue_free()
	nearby_pickup = null
	NoiseBus.emit_noise(global_position, pickup_loudness, self)


## E su una torcia usata a terra: torna nell'inventario così com'è, accesa o spenta, e in mano.
## Se ce n'era già una in uso, resta a terra al suo posto (scambio) e la nuova prende il suo slot.
func _take_ground_torch(ground: GroundTorch) -> void:
	var slot := Torches.active_slot(inventory)
	var swap := slot != -1
	if swap:
		_put_down_torch(ground.global_position)
	else:
		slot = inventory.slots.find(&"")
		if slot == -1:
			message.emit("Inventario pieno: G per lasciare qualcosa.")
			return
	inventory.put(slot, Items.TORCH_LIT if ground.is_lit() else Items.TORCH_USED)
	inventory.select(slot)
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


## Mette a terra la torcia in uso, così com'è (accesa o spenta): il suo slot si libera.
func _put_down_torch(pos: Vector3) -> void:
	inventory.take(Torches.active_slot(inventory))
	torch_dropped.emit(pos, torch.fuel, torch.max_fuel, torch.lit)
	torch.empty()


## G: lascia l'oggetto dello slot selezionato davanti ai piedi. Le torce in uso restano a terra
## come sono (una accesa continua a bruciare); il legno bruciato diventa un moncone che non si raccoglie.
func _drop_selected() -> void:
	var id := inventory.selected_item()
	if id == &"":
		return
	var pos := _drop_position(drop_distance)
	if id in Torches.IN_USE:
		_put_down_torch(pos)
	else:
		inventory.take(inventory.selected)
		if id == Items.TORCH_BURNT:
			torch_dropped.emit(pos, 0.0, torch.max_fuel, false)
		else:
			item_dropped.emit(id, pos)
	NoiseBus.emit_noise(global_position, drop_loudness, self)
	note("Lasciato a terra: %s." % Items.display_name(id))


## Q con la tagliola selezionata: la posa davanti ai piedi, aperta. Usa e getta (vedi BearTrap).
func _place_bear_trap() -> void:
	if inventory.take(inventory.selected) != Items.BEAR_TRAP:
		return
	var pos := _drop_position(bear_trap_distance)
	bear_trap_placed.emit(pos)
	Sfx.play_at(self, &"trap_set", pos + Vector3.UP * 0.2)
	NoiseBus.emit_noise(pos, bear_trap_loudness, self)
	message.emit("Tagliola posata: tra un attimo è armata.")
	note("Tagliola posata.")


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
	return Vector3(to.x, global_position.y, to.z)  # all'altezza dei piedi: anche sul fondo di una fossa


func _find_nearby_pickup() -> Pickup:
	var best: Pickup = null
	var best_d := pickup_range
	for node in get_tree().get_nodes_in_group("pickup"):
		var p := node as Pickup
		if p == null or p.is_queued_for_deletion():
			continue
		if absf(p.global_position.y - global_position.y) > 1.0:
			continue  # sul fondo di una fossa (o sopra, dal bordo): fuori portata
		var d := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if d < best_d:
			best_d = d
			best = p
	return best


## E verso un muro vicino: ci bussa (fa un po' di rumore). La pietra piena suona sorda; un muro segreto
## suona vuoto, e da lì E lo spinge (vedi SecretDoor). Pavimento, soffitto e aria non si bussano.
func _knock() -> void:
	var from := head.global_position
	var to := from - head.global_transform.basis.z * knock_range
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.5:
		return
	var at: Vector3 = hit["position"]
	var node := hit["collider"] as Node
	while node and not node is SecretDoor:
		node = node.get_parent()
	if node:
		(node as SecretDoor).knock(self, at)
	else:
		Sfx.play_at(self, &"wall_knock", at)
		NoiseBus.emit_noise(at, knock_loudness, self)


## E su una porta: se è chiusa la apre, se è aperta la richiude (non se nel vano c'è qualcuno).
func _use_door(door: Door) -> void:
	if not door.is_open:
		door.open(self)
	elif not door.close(self):
		if not door.can_close(self):
			message.emit("Esci dal vano per chiudere la porta.")
		else:
			message.emit("Qualcosa è nel vano: la porta non si chiude.")


## La porta più vicina entro `pickup_range`, aperta o chiusa.
func _find_nearby_door() -> Door:
	var best: Door = null
	var best_d := pickup_range
	for node in get_tree().get_nodes_in_group("door"):
		var door := node as Door
		if door == null or door.is_queued_for_deletion() or not door.can_interact():
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
