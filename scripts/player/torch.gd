class_name Torch
extends OmniLight3D
## Torcia a consumo: perde intensità e raggio e sfarfalla sempre di più.
## Nessuna barra: il giocatore capisce che sta finendo guardando la luce.

signal burned_out

@export var max_fuel := 180.0      ## secondi di luce
@export var full_energy := 1.6
@export var full_range := 9.0
@export var min_range := 2.5
@export var burn_color := Color(1.0, 0.62, 0.3)

var fuel := 0.0
var lit := true

var _noise := FastNoiseLite.new()
var _time := 0.0


func _ready() -> void:
	fuel = max_fuel
	light_color = burn_color
	shadow_enabled = true
	_noise.frequency = 1.0


func _process(delta: float) -> void:
	_time += delta
	if lit and fuel > 0.0:
		fuel = maxf(fuel - delta, 0.0)
		if fuel == 0.0:
			lit = false
			burned_out.emit()

	var ratio := fuel / max_fuel
	var flicker_amount := lerpf(0.45, 0.06, ratio)  # più sfarfallio verso la fine
	var flicker := 1.0 + _noise.get_noise_1d(_time * 10.0) * flicker_amount
	var target := full_energy * lerpf(0.3, 1.0, ratio) * flicker if lit else 0.0
	light_energy = lerpf(light_energy, target, minf(20.0 * delta, 1.0))
	omni_range = lerpf(min_range, full_range, ratio)


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


## Sostituisce la torcia in mano con una nuova, accesa e piena.
func refill(amount: float = -1.0) -> void:
	fuel = max_fuel if amount < 0.0 else minf(fuel + amount, max_fuel)
	lit = true
