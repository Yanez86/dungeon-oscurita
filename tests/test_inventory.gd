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
	_test_replace()
	_test_shield()
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
	_check(inv.selected_item() == It.TORCH, "selected_item legge lo slot 0 all'inizio")
	inv.select(1)
	_check(inv.selected == 1, "select cambia lo slot selezionato")
	_check(inv.selected_item() == It.FLINT, "selected_item segue la selezione")
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


func _test_replace() -> void:
	var inv := Inv.new(3)
	inv.add(It.TORCH)
	inv.add(It.SHIELD)
	_check(inv.replace(It.SHIELD, It.SHIELD_CRACKED) and inv.slots[1] == It.SHIELD_CRACKED, "replace resta nello stesso slot")
	_check(not inv.replace(It.FLINT, It.TORCH), "replace di un oggetto assente: falso")
	_check(not inv.replace(It.TORCH, &"") and inv.slots[0] == It.TORCH, "replace non svuota uno slot")


## Lo scudo para 1 danno per colpo: integro → incrinato → rotto (sparisce).
func _test_shield() -> void:
	var inv := Inv.new(5)
	inv.add(It.FLINT)
	inv.add(It.SHIELD)
	_check(Shield.absorb(inv, 3) == Shield.Result.CRACKED and inv.slots[1] == It.SHIELD_CRACKED, "primo colpo: lo scudo si incrina")
	_check(Shield.absorb(inv, 3) == Shield.Result.BROKEN and not inv.has(It.SHIELD_CRACKED), "secondo colpo: lo scudo si rompe")
	_check(Shield.absorb(inv, 3) == Shield.Result.NONE and inv.count(&"") == 4, "senza scudo non para niente")
	_check(Shield.absorb(inv, 0) == Shield.Result.NONE, "nessun danno, nessuna parata")

	var two := Inv.new(5)
	two.add(It.SHIELD)
	two.add(It.SHIELD_CRACKED)
	_check(Shield.absorb(two, 3) == Shield.Result.BROKEN and two.slots[0] == It.SHIELD, "si consuma prima lo scudo incrinato")
	var hp := 10
	var shield := Inv.new(5)
	shield.add(It.SHIELD)
	for hit in 4:
		hp -= 3 - (Shield.BLOCK if Shield.absorb(shield, 3) != Shield.Result.NONE else 0)
	_check(hp == 0, "con uno scudo quattro colpi del Cieco tolgono 2+2+3+3 = 10 punti (%d)" % hp)


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		printerr("FALLITO: " + label)
