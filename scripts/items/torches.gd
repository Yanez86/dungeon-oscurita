class_name Torches
extends RefCounted
## Regole delle torce nell'inventario, solo dati. Ogni torcia occupa uno slot e il suo stato sta
## nell'id: nuova (Items.TORCH) → in uso, accesa o spenta (TORCH_LIT, TORCH_USED) → consumata,
## legno bruciato (TORCH_BURNT) che si può solo buttare. In uso ce n'è al massimo una:
## il suo combustibile lo tiene il nodo Torch del giocatore.
## Fa luce solo in mano, cioè nello slot selezionato; riposta, se è accesa, brucia lo stesso.

const IN_USE: Array[StringName] = [Items.TORCH_LIT, Items.TORCH_USED]


## Slot della torcia in uso (accesa o spenta), -1 se non ce n'è.
static func active_slot(inv: Inventory) -> int:
	for i in inv.capacity():
		if inv.slots[i] in IN_USE:
			return i
	return -1


## La torcia in uso è nello slot selezionato: la si tiene in mano.
static func in_hand(inv: Inventory) -> bool:
	var slot := active_slot(inv)
	return slot != -1 and slot == inv.selected


## C'è qualcosa da accendere: la torcia in uso spenta o una nuova.
static func can_light(inv: Inventory) -> bool:
	return inv.has(Items.TORCH_USED) or inv.has(Items.TORCH)


## La torcia in uso si è accesa o spenta: l'id nello slot la segue. Falso se non ce n'è una.
static func set_lit(inv: Inventory, lit: bool) -> bool:
	var slot := active_slot(inv)
	if slot == -1:
		return false
	var id := Items.TORCH_LIT if lit else Items.TORCH_USED
	if inv.slots[slot] != id:
		inv.replace(inv.slots[slot], id)
	return true


## Accende una torcia nuova, che diventa quella in uso. Con `into` (uno slot vuoto) la si sposta lì:
## accesa dalla fiamma di quella appena buttata, resta in mano al suo posto.
## Restituisce lo slot della torcia accesa, -1 se non ce ne sono di nuove o ce n'è già una in uso.
static func light_spare(inv: Inventory, into: int = -1) -> int:
	if active_slot(inv) != -1:
		return -1
	var spare := inv.slots.rfind(Items.TORCH)
	if spare == -1:
		return -1
	if into >= 0 and into < inv.capacity() and inv.slots[into] == &"":
		inv.take(spare)
		inv.put(into, Items.TORCH_LIT)
		return into
	inv.replace(Items.TORCH, Items.TORCH_LIT)  # replace, come rfind, prende l'ultima copia: lo stesso slot
	return spare


## La torcia in uso si è consumata: nello stesso slot resta il legno bruciato. Falso se non ce n'era una.
static func burn_out(inv: Inventory) -> bool:
	var slot := active_slot(inv)
	if slot == -1:
		return false
	inv.replace(inv.slots[slot], Items.TORCH_BURNT)
	return true
