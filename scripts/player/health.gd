class_name Health
extends RefCounted
## Energia del giocatore, solo dati (come Inventory): testabile senza grafica
## e facile da sincronizzare in coop. Combattimento raro e letale (GDD):
## pochi colpi bastano, quindi i punti sono pochi e interi.

signal changed
signal died  ## l'energia è arrivata a zero

var max_hp := 10
var hp := 10


func _init(maximum: int = 10) -> void:
	max_hp = maxi(maximum, 1)
	hp = max_hp


func is_dead() -> bool:
	return hp <= 0


func is_full() -> bool:
	return hp >= max_hp


## Toglie energia; restituisce quanta ne ha tolta davvero.
func damage(amount: int) -> int:
	if amount <= 0 or is_dead():
		return 0
	var taken := mini(amount, hp)
	hp -= taken
	changed.emit()
	if hp == 0:
		died.emit()
	return taken


## Ridà energia fino al massimo; restituisce quanta ne ha data davvero.
## Da morti non si guarisce (la rianimazione dei compagni è da decidere, GDD).
func heal(amount: int) -> int:
	if amount <= 0 or is_dead():
		return 0
	var healed := mini(amount, max_hp - hp)
	if healed > 0:
		hp += healed
		changed.emit()
	return healed


## Inizio partita: energia piena.
func reset() -> void:
	hp = max_hp
	changed.emit()
