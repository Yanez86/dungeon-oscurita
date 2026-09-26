class_name Inventory
extends RefCounted
## Inventario a slot, solo dati (niente nodi): testabile senza grafica
## e facile da sincronizzare in coop. Ogni slot contiene un id oggetto o &"" se vuoto.

signal changed

var slots: Array[StringName] = []
var selected := 0  ## slot selezionato (per lasciare a terra)


func _init(capacity: int = 5) -> void:
	slots.resize(capacity)
	slots.fill(&"")


func capacity() -> int:
	return slots.size()


func is_full() -> bool:
	return not slots.has(&"")


func count(id: StringName) -> int:
	return slots.count(id)


func has(id: StringName) -> bool:
	return slots.has(id)


## Mette l'oggetto nel primo slot libero. Falso se l'inventario è pieno.
func add(id: StringName) -> bool:
	var i := slots.find(&"")
	if i == -1:
		return false
	slots[i] = id
	changed.emit()
	return true


## Toglie una copia dell'oggetto (l'ultima, così i primi slot restano stabili).
func remove(id: StringName) -> bool:
	var i := slots.rfind(id)
	if i == -1:
		return false
	slots[i] = &""
	changed.emit()
	return true


## Sostituisce una copia di `old` con `new` nello stesso slot (per esempio lo scudo che si incrina).
## Falso se `old` non c'è.
func replace(old: StringName, new: StringName) -> bool:
	var i := slots.rfind(old)
	if i == -1 or new == &"":
		return false
	slots[i] = new
	changed.emit()
	return true


## Mette l'oggetto in uno slot preciso, se è vuoto (per esempio la torcia nuova al posto di quella buttata).
func put(slot: int, id: StringName) -> bool:
	if slot < 0 or slot >= slots.size() or slots[slot] != &"" or id == &"":
		return false
	slots[slot] = id
	changed.emit()
	return true


## Svuota lo slot indicato e restituisce cosa conteneva (&"" se era vuoto).
func take(slot: int) -> StringName:
	if slot < 0 or slot >= slots.size():
		return &""
	var id := slots[slot]
	if id != &"":
		slots[slot] = &""
		changed.emit()
	return id


## Id dell'oggetto nello slot selezionato (&"" se vuoto).
func selected_item() -> StringName:
	return slots[selected]


func select(slot: int) -> void:
	if slot >= 0 and slot < slots.size() and slot != selected:
		selected = slot
		changed.emit()


func clear() -> void:
	slots.fill(&"")
	selected = 0
	changed.emit()


## Aggiunge `extra` slot vuoti in fondo (lo zaino). Chi mostra gli slot deve seguire capacity().
func grow(extra: int) -> void:
	if extra <= 0:
		return
	slots.resize(slots.size() + extra)
	for i in range(slots.size() - extra, slots.size()):
		slots[i] = &""
	changed.emit()


## Svuota tutto e torna a `size` slot (nuova partita: lo zaino non c'è più).
func reset(size: int) -> void:
	slots.resize(size)
	clear()
