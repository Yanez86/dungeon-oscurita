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
	_test_put()
	_test_shield()
	_test_torches()
	_test_torch_thrown()
	_test_grow_and_reset()
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


## Zaino: gli slot in più arrivano vuoti in fondo, il contenuto resta; una nuova partita torna a 5.
func _test_grow_and_reset() -> void:
	var inv := Inv.new(5)
	inv.add(It.FLINT)
	inv.add(It.BACKPACK)
	inv.select(1)
	var calls := [0]
	inv.changed.connect(func() -> void: calls[0] += 1)
	inv.take(inv.selected)
	inv.grow(3)
	_check(inv.capacity() == 8 and inv.count(&"") == 7, "grow: 3 slot vuoti in più (%d)" % inv.capacity())
	_check(inv.slots[0] == It.FLINT and inv.selected == 1, "grow: contenuto e selezione restano")
	_check(calls[0] == 2, "grow emette changed")
	inv.grow(0)
	_check(inv.capacity() == 8 and calls[0] == 2, "grow(0) non cambia niente")
	inv.select(7)
	inv.add(It.TORCH)
	inv.reset(5)
	_check(inv.capacity() == 5 and inv.count(&"") == 5 and inv.selected == 0, "reset: 5 slot vuoti, selezione sul primo")


func _test_put() -> void:
	var inv := Inv.new(3)
	inv.add(It.FLINT)
	_check(inv.put(2, It.ROPE) and inv.slots[2] == It.ROPE, "put mette l'oggetto nello slot indicato")
	_check(not inv.put(0, It.TORCH) and inv.slots[0] == It.FLINT, "put non sovrascrive uno slot pieno")
	_check(not inv.put(-1, It.TORCH) and not inv.put(3, It.TORCH) and not inv.put(1, &""), "put fuori dai limiti o di niente: falso")


## Torce: nuova → accesa (fa luce solo se selezionata) → spenta e riaccesa → legno bruciato.
func _test_torches() -> void:
	var inv := Inv.new(5)
	inv.add(It.FLINT)
	inv.add(It.TORCH)
	inv.add(It.TORCH)
	_check(Torches.active_slot(inv) == -1 and not Torches.in_hand(inv), "solo torce nuove: nessuna in uso")
	_check(Torches.can_light(inv), "con torce nuove c'è qualcosa da accendere")
	var lit := Torches.light_spare(inv)
	_check(lit == 2 and inv.slots[2] == It.TORCH_LIT and inv.count(It.TORCH) == 1, "si accende l'ultima torcia nuova, nel suo slot")
	_check(Torches.light_spare(inv) == -1 and inv.count(It.TORCH) == 1, "una sola torcia in uso alla volta")
	_check(not Torches.in_hand(inv), "accesa ma con un altro slot selezionato: riposta")
	inv.select(lit)
	_check(Torches.in_hand(inv), "selezionata: in mano")
	_check(Torches.set_lit(inv, false) and inv.slots[lit] == It.TORCH_USED, "spenta: resta in uso, nello stesso slot")
	_check(Torches.active_slot(inv) == lit and Torches.in_hand(inv), "spenta resta in mano")
	Torches.set_lit(inv, true)
	_check(inv.slots[lit] == It.TORCH_LIT, "riaccesa")
	_check(Torches.burn_out(inv) and inv.slots[lit] == It.TORCH_BURNT, "consumata: legno bruciato nello stesso slot")
	_check(Torches.active_slot(inv) == -1 and not Torches.in_hand(inv), "il legno bruciato non è una torcia in uso")
	_check(not Torches.burn_out(inv) and not Torches.set_lit(inv, true), "senza torcia in uso non cambia niente")
	_check(Torches.light_spare(inv) == 1 and inv.count(It.TORCH_BURNT) == 1, "si accende l'altra; il legno bruciato resta finché non lo si butta")

	var burnt := Inv.new(2)
	burnt.add(It.TORCH_BURNT)
	_check(not Torches.can_light(burnt) and Torches.light_spare(burnt) == -1, "col solo legno bruciato non si accende niente")


## Buttata la torcia accesa che si ha in mano, quella accesa dalla sua fiamma prende il suo slot e resta in mano.
func _test_torch_thrown() -> void:
	var inv := Inv.new(5)
	inv.add(It.TORCH)
	inv.add(It.FLINT)
	inv.add(It.TORCH)
	var hand := Torches.light_spare(inv)
	inv.select(hand)
	inv.take(hand)  # buttata a terra
	_check(Torches.light_spare(inv, hand) == hand and inv.slots[hand] == It.TORCH_LIT, "la nuova va nello slot di quella buttata")
	_check(inv.slots[0] == &"" and Torches.in_hand(inv), "lo slot della torcia nuova si libera; la accesa è in mano")


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
