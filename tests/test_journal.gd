extends SceneTree
## Test del diario. Esegui con:
##   godot --headless -s res://tests/test_journal.gd
## Esce con codice 1 se un test fallisce.

const JournalScript = preload("res://scripts/player/journal.gd")

var _failures := 0


func _init() -> void:
	_test_add_and_group()
	_test_repeats()
	_test_limit()
	_test_signals()
	print("Test diario: %s" % ("OK" if _failures == 0 else "%d FALLITI" % _failures))
	quit(1 if _failures > 0 else 0)


func _test_add_and_group() -> void:
	var j := JournalScript.new()
	j.add(1, "Entri nel dungeon.")
	j.add(1, "Raccolto: Torcia.")
	j.add(2, "Scendi al piano 2.")
	j.add(2, "")
	_check(j.entries.size() == 3, "tre righe, quella vuota ignorata (%d)" % j.entries.size())
	_check(j.entries[0].floor_number == 1 and j.entries[2].floor_number == 2, "ogni riga ricorda il suo piano")
	_check(j.entries[1].text == "Raccolto: Torcia.", "il testo resta com'è")
	j.clear()
	_check(j.entries.is_empty(), "clear svuota il diario")


func _test_repeats() -> void:
	var j := JournalScript.new()
	j.add(1, "Raccolto: Torcia.")
	j.add(1, "Raccolto: Torcia.")
	_check(j.entries.size() == 1 and j.entries[0].count == 2, "due righe uguali di seguito diventano una con ×2")
	j.add(2, "Raccolto: Torcia.")
	_check(j.entries.size() == 2 and j.entries[1].count == 1, "la stessa frase su un altro piano è una riga nuova")
	j.add(2, "Nuova torcia accesa.")
	j.add(2, "Raccolto: Torcia.")
	_check(j.entries.size() == 4, "non di seguito: righe separate")


func _test_limit() -> void:
	var j := JournalScript.new()
	j.max_entries = 5
	for i in 8:
		j.add(1, "Riga %d" % i)
	_check(j.entries.size() == 5, "il diario non supera max_entries")
	_check(j.entries[0].text == "Riga 3" and j.entries[-1].text == "Riga 7", "si perdono le righe più vecchie")


func _test_signals() -> void:
	var j := JournalScript.new()
	var calls := [0]  # array: le lambda non possono modificare variabili locali
	j.changed.connect(func() -> void: calls[0] += 1)
	j.add(1, "A")
	j.add(1, "A")  # contatore: cambia comunque
	j.add(1, "")   # niente
	j.clear()
	_check(calls[0] == 3, "changed emesso a ogni cambiamento (%d)" % calls[0])


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		printerr("FALLITO: " + label)
