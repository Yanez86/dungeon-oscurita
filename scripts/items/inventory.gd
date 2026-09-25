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
