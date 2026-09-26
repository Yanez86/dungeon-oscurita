class_name Torch
extends OmniLight3D
## Torcia a consumo: perde intensità e raggio e sfarfalla sempre di più.
## Nessuna barra: il giocatore capisce che sta finendo guardando la luce e la fiamma che si rimpicciolisce.
## Il nodo è la luce e sta nella fiamma; il modello voxel della torcia pende sotto.
## Senza modello (held = false) fa da luce e fiamma a una torcia buttata a terra (GroundTorch).
## Riposta (stowed: il giocatore tiene in mano un altro oggetto) non fa luce ma, se è accesa, si consuma lo stesso.

signal burned_out

@export var max_fuel := 180.0      ## secondi di luce
@export var full_energy := 1.6
@export var full_range := 9.0
@export var min_range := 2.5
@export var burn_color := Color(1.0, 0.62, 0.3)
@export var gust_amount := 0.12    ## variazione lenta, come una corrente d'aria
@export var sway := 0.03           ## metri: la fiamma ondeggia e le ombre danzano

@export_group("Modello in mano")
@export var held := true  ## falso per una torcia a terra: niente modello in mano, solo luce e fiamma
@export var hand_lean := Vector3(-0.3, 0.0, 0.35)  ## inclinazione della torcia (radianti): la cima verso il centro dello schermo
@export var flame_min_scale := 0.35  ## grandezza della fiamma quando la torcia sta per finire

var fuel := 0.0
var lit := true
var stowed := false  ## riposta: niente luce, fiamma né modello in mano (lo decide il giocatore, vedi Torches)

var _noise := FastNoiseLite.new()
var _time := 0.0
var _base_position := Vector3.ZERO
var _hand := Node3D.new()  ## perno in cima alla testa della torcia: il modello pende sotto
var _hand_base := Vector3.ZERO
var _flame := MeshInstance3D.new()


func _ready() -> void:
	fuel = max_fuel
	light_color = burn_color
	shadow_enabled = true
	_noise.frequency = 1.0
	_base_position = position
	_build_model()


func _process(delta: float) -> void:
	_time += delta
	if lit and fuel > 0.0:
		fuel = maxf(fuel - delta, 0.0)
		if fuel == 0.0:
			lit = false
			burned_out.emit()

	var ratio := fuel / max_fuel
	var flicker_amount := lerpf(0.45, 0.06, ratio)  # più sfarfallio verso la fine
	var gust := _noise.get_noise_1d(_time * 1.5 + 100.0) * gust_amount
	var flicker := 1.0 + _noise.get_noise_1d(_time * 10.0) * flicker_amount + gust
	position = _base_position + Vector3(
		_noise.get_noise_1d(_time * 6.0 + 200.0),
		_noise.get_noise_1d(_time * 6.0 + 300.0),
		0.0) * sway
	var target := full_energy * lerpf(0.3, 1.0, ratio) * flicker if is_shining() else 0.0
	light_energy = lerpf(light_energy, target, minf(20.0 * delta, 1.0))
	omni_range = lerpf(min_range, full_range, ratio)

	# La torcia resta ferma in mano: ondeggiano solo luce e fiamma.
	_hand.position = _hand_base - (position - _base_position)
	_hand.visible = not stowed and fuel > 0.0  # a mani vuote non si tiene niente
	_flame.visible = is_shining()
	_flame.scale = Vector3(1.0, maxf(flicker, 0.3), 1.0) * lerpf(flame_min_scale, 1.0, ratio)


## Fa luce: accesa e non riposta.
func is_shining() -> bool:
	return lit and not stowed


## Spegnere è sempre gratis; per riaccendere serve un acciarino (lo controlla il giocatore).
func extinguish() -> void:
	lit = false


## Riaccende la torcia in mano, se ha ancora combustibile.
func relight() -> bool:
	if fuel <= 0.0:
		return false
	lit = true
	return true


## Mani vuote: nessuna torcia da accendere finché non se ne prende una.
func empty() -> void:
	fuel = 0.0
	lit = false


## Prende una torcia già usata (raccolta da terra) così com'è, accesa o spenta.
func hold(amount: float, burning: bool) -> void:
	fuel = clampf(amount, 0.0, max_fuel)
	lit = burning and fuel > 0.0


## Sostituisce la torcia in mano con una nuova, accesa e piena.
func refill(amount: float = -1.0) -> void:
	fuel = max_fuel if amount < 0.0 else minf(fuel + amount, max_fuel)
	lit = true


## Modello voxel della torcia con la fiamma in cima. Niente ombre dal modello:
## sta attaccato alla luce e oscurerebbe mezza stanza.
func _build_model() -> void:
	var flame_size := Vector3(1.5, 2.5, 1.5) * Voxels.ITEM_VOXEL_SIZE
	_hand_base = Vector3(0.0, -flame_size.y / 2.0, 0.0)
	_hand.position = _hand_base
	_hand.rotation = hand_lean
	add_child(_hand)
	if held:
		var model := Voxels.instance(&"item_torch")
		model.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.position.y = -model.mesh.get_aabb().size.y
		_hand.add_child(model)

	var box := BoxMesh.new()
	box.size = flame_size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = burn_color
	mat.emission_enabled = true
	mat.emission = burn_color
	mat.emission_energy_multiplier = 2.0
	box.material = mat
	_flame.mesh = box
	_flame.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_flame)
