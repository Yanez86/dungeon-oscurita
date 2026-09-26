class_name GroundTorch
extends Pickup
## Torcia usata lasciata a terra dal giocatore (Q o G, vedi player.gd).
## Se è accesa continua a bruciare e a fare luce finché ha combustibile; consumata (o buttata
## già consumata: legno bruciato) resta un moncone annerito che non si può più raccogliere.
## Raccolta (E) torna nell'inventario così com'è, accesa o spenta, e in mano (vedi Torches).

@export var burnt_tint := Color(0.22, 0.19, 0.17)  ## colore del moncone consumato
@export var flame_inset := 0.08  ## metri dalla punta della testa alla fiamma
@export var flame_lift := 0.08   ## metri della fiamma sopra la testa coricata

## Stato con cui la si lascia a terra: lo imposta chi la crea, prima di aggiungerla alla scena.
## Poi vale quello della fiamma (remaining_fuel(), is_lit()).
var fuel := 0.0
var max_fuel := 180.0
var lit := true

var _flame := Torch.new()  ## la stessa luce della torcia in mano, senza modello


func _ready() -> void:
	item = Items.TORCH
	super()
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF  # la fiamma è attaccata alla testa
	# La fiamma sta sopra la testa della torcia coricata (l'estremità verso -x, vedi Pickup).
	var box := _mesh.transform * _mesh.mesh.get_aabb()
	_flame.held = false
	_flame.max_fuel = max_fuel
	_flame.position = Vector3(box.position.x + flame_inset, box.end.y + flame_lift, 0.0)
	add_child(_flame)
	_flame.hold(fuel, lit)  # dopo il suo _ready, che la riempie
	_flame.burned_out.connect(_burn_out)
	if _flame.lit:
		set_glow(false)  # la fiamma basta a farla notare
	else:
		_flame.visible = false  # spenta: nessuna luce da calcolare
		if _flame.fuel <= 0.0:
			_burn_out()


func display_name() -> String:
	return Items.display_name(Items.TORCH_LIT if is_lit() else Items.TORCH_USED)


func is_lit() -> bool:
	return _flame.lit


## Secondi di luce rimasti.
func remaining_fuel() -> float:
	return _flame.fuel


## Consumata: la luce si spegne piano (vedi Torch) e non si raccoglie più.
func _burn_out() -> void:
	remove_from_group("pickup")
	set_glow(false)
	(_mesh.material_override as StandardMaterial3D).albedo_color = burnt_tint
	create_tween().tween_callback(_flame.hide).set_delay(1.0)
