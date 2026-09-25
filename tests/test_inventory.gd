extends SceneTree
## Test dell'inventario. Esegui con:
##   godot --headless -s res://tests/test_inventory.gd
## Esce con codice 1 se un test fallisce.

const Inv = preload("res://scripts/items/inventory.gd")
const It = preload("res://scripts/items/items.gd")

var _failures := 0


func _init() -> void:
	_test_add_until_full()
	_test_remove_and_count()
	_test_take_and_select()
	_test_changed_signal()
	print("Test inventario: %s" % ("OK" if _failures == 0 else "%d FALLITI" % _failures))
	quit(1 if _failures > 0 else 0)


func _test_add_until_full() -> void:
	var inv := Inv.new(3)
	_check(inv.capacity() == 3 and not inv.is_full(), "inventario nuovo vuoto")
	_check(inv.add(It.TORCH) and inv.add(It.TORCH) and inv.add(It.FLINT), "tre oggetti entrano in tre slot")
	_check(inv.is_full(), "pieno dopo tre oggetti")
	_check(not inv.add(It.TORCH), "il quarto oggetto viene rifiutato")
	_check(inv.count(It.TORCH) == 2, "il rifiuto non cambia il contenuto")


func _test_remove_and_count() -> void:
	var inv := Inv.new(4)
	inv.add(It.FLINT)
	inv.add(It.TORCH)
	inv.add(It.TORCH)
	_check(inv.remove(It.TORCH) and inv.count(It.TORCH) == 1, "remove toglie una sola torcia")
	_check(inv.slots[0] == It.FLINT and inv.slots[1] == It.TORCH, "remove toglie l'ultima copia, i primi slot restano")
	_check(inv.remove(It.TORCH) and not inv.has(It.TORCH), "seconda torcia tolta")
	_check(not inv.remove(It.TORCH), "remove di un oggetto assente fallisce")
	inv.add(It.TORCH)
	_check(inv.slots[1] == It.TORCH, "add riempie il primo slot libero")


func _test_take_and_select() -> void:
	var inv := Inv.new(3)
	inv.add(It.TORCH)
	inv.add(It.FLINT)
	inv.select(1)
	_check(inv.selected == 1, "select cambia lo slot selezionato")
	inv.select(7)
	_check(inv.selected == 1, "select fuori dai limiti ignorato")
	_check(inv.take(inv.selected) == It.FLINT and not inv.has(It.FLINT), "take svuota lo slot selezionato")
	_check(inv.take(1) == &"", "take di uno slot vuoto restituisce vuoto")
	_check(inv.take(-1) == &"" and inv.take(99) == &"", "take fuori dai limiti restituisce vuoto")
	inv.clear()
	_check(inv.count(&"") == 3 and inv.selected == 0, "clear svuota tutto")


func _test_changed_signal() -> void:
	var inv := Inv.new(2)
	var calls := [0]  # array: le lambda non possono modificare variabili locali
	inv.changed.connect(func() -> void: calls[0] += 1)
	inv.add(It.TORCH)
	inv.remove(It.FLINT)  # assente: nessun segnale
	inv.take(1)           # vuoto: nessun segnale
	inv.remove(It.TORCH)
	_check(calls[0] == 2, "changed emesso solo quando cambia qualcosa (%d)" % calls[0])


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		printerr("FALLITO: " + label)
