extends SceneTree
## Test della torcia buttata a terra (GroundTorch) e della torcia ripresa in mano. Esegui con:
##   godot --headless -s res://tests/test_ground_torch.gd
## Esce con codice 1 se un test fallisce.

const GROUND_TORCH := preload("res://scenes/ground_torch.tscn")
const STEP := 0.5  ## secondi simulati per ogni chiamata a _process

var _failures := 0


## I test partono al primo frame: solo allora la scena è attiva e _ready dei nodi aggiunti parte subito.
func _init() -> void:
	process_frame.connect(_run_tests, CONNECT_ONE_SHOT)


func _run_tests() -> void:
	_test_burns_out()
	_test_unlit_keeps_fuel()
	_test_hold()
	print("Test torcia a terra: %s" % ("OK" if _failures == 0 else "%d FALLITI" % _failures))
	quit(1 if _failures > 0 else 0)


func _spawn(fuel: float, lit: bool) -> GroundTorch:
	var t: GroundTorch = GROUND_TORCH.instantiate()
	t.fuel = fuel
	t.lit = lit
	root.add_child(t)
	return t


## Simula `seconds` secondi di gioco su tutti i nodi della torcia (anche la sua fiamma).
func _run(t: Node, seconds: float) -> void:
	for i in roundi(seconds / STEP):
		t.propagate_call("_process", [STEP])


func _test_burns_out() -> void:
	var t := _spawn(10.0, true)
	_check(t.is_in_group("pickup") and t.is_lit(), "accesa a terra: si può raccogliere")
	_check(t.display_name() == "Torcia accesa", "a schermo: torcia accesa")
	_run(t, 6.0)
	_check(is_equal_approx(t.remaining_fuel(), 4.0), "a terra continua a bruciare (%.1f s rimasti)" % t.remaining_fuel())
	_run(t, 5.0)
	_check(not t.is_lit() and t.remaining_fuel() == 0.0, "si spegne quando finisce il combustibile")
	_check(not t.is_in_group("pickup"), "consumata: non si raccoglie più")
	t.free()


func _test_unlit_keeps_fuel() -> void:
	var t := _spawn(50.0, false)
	_run(t, 20.0)
	_check(t.is_in_group("pickup") and not t.is_lit(), "spenta a terra: si può raccogliere")
	_check(is_equal_approx(t.remaining_fuel(), 50.0), "spenta a terra non consuma (%.1f s)" % t.remaining_fuel())
	t.free()
	var burnt := _spawn(0.0, true)
	_check(not burnt.is_in_group("pickup") and not burnt.is_lit(), "senza combustibile è subito un moncone")
	burnt.free()


func _test_hold() -> void:
	var torch := Torch.new()
	root.add_child(torch)  # i suoi nodi interni entrano nella scena solo con _ready
	torch.hold(40.0, true)
	_check(torch.lit and torch.fuel == 40.0, "ripresa accesa: resta accesa col suo combustibile")
	torch.hold(40.0, false)
	_check(not torch.lit and torch.fuel == 40.0, "ripresa spenta: resta spenta, combustibile conservato")
	torch.hold(torch.max_fuel + 100.0, true)
	_check(torch.fuel == torch.max_fuel, "mai più combustibile del massimo")
	torch.hold(0.0, true)
	_check(not torch.lit, "senza combustibile non si accende")
	torch.free()


func _check(cond: bool, label: String) -> void:
	if not cond:
		_failures += 1
		printerr("FALLITO: " + label)
