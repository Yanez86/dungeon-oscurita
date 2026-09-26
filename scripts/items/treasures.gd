class_name Treasures
extends RefCounted
## Regole dei tesori, solo dati. Un tesoro (monete, gemma, calice: vedi Items.VALUES) occupa uno slot
## come ogni altro oggetto e vale punti solo quando lo porti giù per la scala: lì lo "metti in salvo",
## esce dall'inventario e il suo valore va nel punteggio della partita (Game.score).
## Chi muore perde i tesori che ha addosso; quelli già messi in salvo restano.


static func is_treasure(id: StringName) -> bool:
	return Items.VALUES.has(id)


## Quanto valgono i tesori che hai addosso, non ancora messi in salvo.
static func carried_value(inv: Inventory) -> int:
	var total := 0
	for id in inv.slots:
		total += Items.VALUES.get(id, 0)
	return total


## Mette in salvo i tesori: li toglie dall'inventario (gli slot si liberano) e restituisce quanto valgono.
static func bank(inv: Inventory) -> int:
	var total := 0
	for i in inv.capacity():
		if is_treasure(inv.slots[i]):
			total += Items.VALUES[inv.take(i)]
	return total
