extends Node
## Stato globale della partita e configurazione dei comandi.

const SLOT_KEYS := 5  ## tasti numerici per scegliere lo slot dell'inventario

var version: String = ProjectSettings.get_setting("application/config/version", "dev")
var run_seed: int = 0      ## seed della partita (mostrato a schermo)
var floor_number: int = 1  ## piano corrente


func _ready() -> void:
	_setup_input()


## Seed del piano corrente: stesso seed partita + stesso piano = stesso dungeon.
func floor_seed() -> int:
	return run_seed + floor_number * 7919


func _setup_input() -> void:
	_bind("move_forward", [KEY_W])
	_bind("move_back", [KEY_S])
	_bind("move_left", [KEY_A])
	_bind("move_right", [KEY_D])
	_bind("sprint", [KEY_SHIFT])
	_bind("crouch", [KEY_CTRL, KEY_C])
	_bind("torch_toggle", [KEY_F])
	_bind("new_torch", [KEY_Q])
	_bind("interact", [KEY_E])
	_bind("drop", [KEY_G])
	for i in SLOT_KEYS:
		_bind("slot_%d" % (i + 1), [KEY_1 + i])
	_bind("map_toggle", [KEY_M])
	_bind("new_run", [KEY_R])
	_bind("debug_toggle", [KEY_F3])


func _bind(action: StringName, keys: Array) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for k: Key in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k  # posizione fisica: funziona con ogni layout
		InputMap.action_add_event(action, ev)
