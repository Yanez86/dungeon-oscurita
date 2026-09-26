class_name Journal
extends RefCounted
## Diario della partita, solo dati: frasi brevi scritte da sole (piano raggiunto,
## oggetti trovati, torce accese e consumate), raggruppate per piano.
## Due frasi uguali di seguito diventano una sola con un contatore ("×2").

signal changed

## Una riga del diario.
class Entry:
	var floor_number := 1
	var text := ""
	var count := 1  ## quante volte è successo di fila

	func _init(f: int, t: String) -> void:
		floor_number = f
		text = t


var max_entries := 200  ## le righe più vecchie si perdono: il diario non cresce all'infinito
var entries: Array[Entry] = []


func add(floor_number: int, text: String) -> void:
	if text.is_empty():
		return
	if not entries.is_empty():
		var last := entries[-1]
		if last.floor_number == floor_number and last.text == text:
			last.count += 1
			changed.emit()
			return
	entries.append(Entry.new(floor_number, text))
	while entries.size() > max_entries:
		entries.pop_front()
	changed.emit()


func clear() -> void:
	entries.clear()
	changed.emit()
