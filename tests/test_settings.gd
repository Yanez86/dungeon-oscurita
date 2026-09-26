extends SceneTree
## Test delle impostazioni (salvataggio e limiti). Esegui con:
##   godot --headless -s res://tests/test_settings.gd
## Esce con codice 1 se un test fallisce.

const SettingsScript = preload("res://scripts/autoload/settings.gd")
const TEST_FILE := "user://test_settings.cfg"

var _failures := 0


func _init() -> void:
	DirAccess.remove_absolute(TEST_FILE)
	_test_defaults_without_file()
	_test_round_trip()
	_test_limits_and_types()
	DirAccess.remove_absolute(TEST_FILE)
	print("Test impostazioni: %s" % ("OK" if _failures == 0 else "%d FALLITI" % _failures))
	quit(1 if _failures > 0 else 0)


func _make() -> Node:
	var s: Node = SettingsScript.new()
	s.path = TEST_FILE
	return s


func _test_defaults_without_file() -> void:
	var s := _make()
	_check(not s.load_from(TEST_FILE), "senza file load_from dice di no")
	_check(s.mouse_scale == 1.0 and s.master_volume == 1.0 and s.psx_filter and not s.fullscreen, "senza file restano i predefiniti")
	s.free()


func _test_round_trip() -> void:
	var s := _make()
	s.update("mouse_scale", 1.5)
	s.update("master_volume", 0.4)
	s.update("psx_filter", false)
	var t := _make()
	_check(t.load_from(TEST_FILE), "il file salvato si rilegge")
	_check(is_equal_approx(t.mouse_scale, 1.5) and is_equal_approx(t.master_volume, 0.4), "numeri salvati e riletti")
	_check(not t.psx_filter and not t.fullscreen, "interruttori salvati e riletti")
	s.reset_to_defaults()
	t.load_from(TEST_FILE)
	_check(t.mouse_scale == 1.0 and t.psx_filter, "reset_to_defaults salva i predefiniti")
	s.free()
	t.free()


func _test_limits_and_types() -> void:
	var s := _make()
	var calls := [0]  # array: le lambda non possono modificare variabili locali
	s.changed.connect(func() -> void: calls[0] += 1)
	s.update("mouse_scale", 99)
	_check(s.mouse_scale == SettingsScript.MOUSE_MAX, "sensibilità limitata al massimo")
	s.update("master_volume", -3.0)
	_check(s.master_volume == 0.0, "volume limitato a zero")
	s.update("psx_filter", "no")
	_check(s.psx_filter, "un valore del tipo sbagliato non cambia niente")
	s.update("inesistente", 1)
	_check(calls[0] == 2, "changed solo per i valori accettati (%d)" % calls[0])
	s.free()


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		printerr("FALLITO: " + label)
