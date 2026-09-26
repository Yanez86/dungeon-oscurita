extends SceneTree
## Test dell'energia del giocatore. Esegui con:
##   godot --headless -s res://tests/test_health.gd
## Esce con codice 1 se un test fallisce.

const HealthScript = preload("res://scripts/player/health.gd")

var _failures := 0


func _init() -> void:
	_test_damage()
	_test_heal()
	_test_death()
	_test_signals()
	print("Test energia: %s" % ("OK" if _failures == 0 else "%d FALLITI" % _failures))
	quit(1 if _failures > 0 else 0)


func _test_damage() -> void:
	var h := HealthScript.new(10)
	_check(h.hp == 10 and h.max_hp == 10 and h.is_full(), "energia nuova piena")
	_check(h.damage(3) == 3 and h.hp == 7, "un colpo da 3 lascia 7")
	_check(h.damage(0) == 0 and h.damage(-2) == 0 and h.hp == 7, "danni nulli o negativi ignorati")
	_check(h.damage(50) == 7 and h.hp == 0, "il danno non scende sotto zero e dice quanto ha tolto")
	_check(HealthScript.new(0).max_hp == 1, "il massimo è almeno 1")


func _test_heal() -> void:
	var h := HealthScript.new(10)
	h.damage(4)
	_check(h.heal(2) == 2 and h.hp == 8, "cura di 2")
	_check(h.heal(10) == 2 and h.hp == 10 and h.is_full(), "la cura non supera il massimo")
	_check(h.heal(1) == 0, "a energia piena non si cura")
	h.damage(10)
	_check(h.heal(5) == 0 and h.is_dead(), "da morti non si guarisce")
	h.reset()
	_check(h.hp == 10 and not h.is_dead(), "reset riporta l'energia piena")


func _test_death() -> void:
	var h := HealthScript.new(5)
	var deaths := [0]  # array: le lambda non possono modificare variabili locali
	h.died.connect(func() -> void: deaths[0] += 1)
	h.damage(4)
	_check(deaths[0] == 0 and not h.is_dead(), "vivo con 1 punto")
	h.damage(1)
	h.damage(3)
	_check(deaths[0] == 1 and h.is_dead(), "died emesso una volta sola (%d)" % deaths[0])


func _test_signals() -> void:
	var h := HealthScript.new(10)
	var calls := [0]
	h.changed.connect(func() -> void: calls[0] += 1)
	h.damage(2)   # cambia
	h.damage(0)   # niente
	h.heal(2)     # cambia
	h.heal(2)     # già piena: niente
	h.reset()     # cambia (sempre)
	_check(calls[0] == 3, "changed emesso solo quando cambia qualcosa (%d)" % calls[0])


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		printerr("FALLITO: " + label)
