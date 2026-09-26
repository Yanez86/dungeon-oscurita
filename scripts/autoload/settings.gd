extends Node
## Impostazioni del giocatore, salvate da sole in user://settings.cfg
## (ConfigFile: un file di testo a sezioni, come un .ini).
## È un autoload: Godot lo crea all'avvio e ogni script lo raggiunge col nome `Settings`.
## Chi dipende da un'impostazione ascolta il segnale `changed`.

signal changed

const FILE := "user://settings.cfg"
const SECTION := "gioco"
const MOUSE_MIN := 0.25
const MOUSE_MAX := 3.0

var mouse_scale := 1.0     ## moltiplica la sensibilità del mouse di PlayerInput
var master_volume := 1.0   ## 0–1, volume generale
var psx_filter := true     ## filtro retro PS1 (anche F4)
var fullscreen := false

var path := FILE  ## i test usano un altro file


func _ready() -> void:
	load_from(path)
	apply()


## Cambia un'impostazione, la applica, la salva e avvisa chi ascolta.
func update(key: String, value: Variant) -> void:
	if not _set_value(key, value):
		push_warning("Impostazione non valida: %s = %s" % [key, value])
		return
	apply()
	save_to(path)
	changed.emit()


func reset_to_defaults() -> void:
	mouse_scale = 1.0
	master_volume = 1.0
	psx_filter = true
	fullscreen = false
	apply()
	save_to(path)
	changed.emit()


## Porta le impostazioni nel motore (audio e finestra); il resto lo leggono i nodi interessati.
func apply() -> void:
	AudioServer.set_bus_volume_db(0, linear_to_db(maxf(master_volume, 0.0001)))
	AudioServer.set_bus_mute(0, master_volume <= 0.0)
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen else DisplayServer.WINDOW_MODE_WINDOWED
	if DisplayServer.window_get_mode() != mode:
		DisplayServer.window_set_mode(mode)


## Legge il file; i valori mancanti o sbagliati restano come sono. Falso se il file non c'è.
func load_from(file: String) -> bool:
	var cfg := ConfigFile.new()
	if cfg.load(file) != OK:
		return false
	if not cfg.has_section(SECTION):
		return true
	for key in cfg.get_section_keys(SECTION):
		_set_value(key, cfg.get_value(SECTION, key))
	return true


func save_to(file: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value(SECTION, "mouse_scale", mouse_scale)
	cfg.set_value(SECTION, "master_volume", master_volume)
	cfg.set_value(SECTION, "psx_filter", psx_filter)
	cfg.set_value(SECTION, "fullscreen", fullscreen)
	cfg.save(file)


## Imposta un valore controllando tipo e limiti. Falso (e nessun cambiamento)
## se la chiave non esiste o il valore è del tipo sbagliato.
func _set_value(key: String, value: Variant) -> bool:
	var is_number := value is float or value is int
	match key:
		"mouse_scale" when is_number:
			mouse_scale = clampf(float(value), MOUSE_MIN, MOUSE_MAX)
		"master_volume" when is_number:
			master_volume = clampf(float(value), 0.0, 1.0)
		"psx_filter" when value is bool:
			psx_filter = value
		"fullscreen" when value is bool:
			fullscreen = value
		_:
			return false
	return true
