class_name EndScreen
extends Control
## Schermata di fine partita, da morti o usciti vivi dall'ultimo piano: lo schermo si scurisce piano, poi
## compaiono piano raggiunto, tempo nel buio, tesori messi in salvo, causa della morte e seed (per le
## segnalazioni). R avvia una nuova partita (vedi main.gd).

@export var fade_time := 1.5  ## secondi per scurire lo schermo
@export var darkness := 0.8   ## opacità finale del velo nero
@export var death_color := Color(0.75, 0.22, 0.16)
@export var escape_color := Color(0.95, 0.75, 0.3)

var _veil := ColorRect.new()
var _box := VBoxContainer.new()
var _title := UiTheme.label("", death_color, 48)
var _details := UiTheme.label("")
var _score := UiTheme.label("", UiTheme.ACCENT)
var _cause := UiTheme.label("", UiTheme.DIM)
var _seed := UiTheme.label("", UiTheme.DIM, 13)
var _tween: Tween


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.color = Color.BLACK
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)

	_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)
	for l: Label in [_title, _details, _score, _cause, _seed]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(l)
	var hint := UiTheme.label("R  nuova partita", UiTheme.ACCENT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(hint)


## Morte. `cause`: chi ti ha ucciso ("il Cieco"), vuota se non si sa. `lost`: valore dei tesori che avevi addosso.
func appear_dead(cause: String, lost: int) -> void:
	_title.text = "Sei morto"
	_title.add_theme_color_override("font_color", death_color)
	_cause.text = "Ucciso %s." % Player.by_cause(cause) if cause != "" else ""
	if lost > 0:
		_cause.text += ("\n" if cause != "" else "") + "Avevi addosso tesori per %d punti: persi." % lost
	_show()


## Uscito vivo dall'ultimo piano.
func appear_escaped() -> void:
	_title.text = "Sei uscito vivo"
	_title.add_theme_color_override("font_color", escape_color)
	_cause.text = "Hai attraversato tutti i piani del dungeon."
	_show()


func disappear() -> void:
	if _tween:
		_tween.kill()
	visible = false


func _show() -> void:
	var secs := int(Game.run_time)
	_details.text = "Piano %d di %d  ·  %d:%02d nel buio" % [Game.floor_number, Game.last_floor, secs / 60, secs % 60]
	_score.text = "Tesori messi in salvo: %d punti" % Game.score
	_cause.visible = _cause.text != ""
	_seed.text = "seed %d" % Game.run_seed
	visible = true
	_veil.color.a = 0.0
	_box.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_veil, "color:a", darkness, fade_time)
	_tween.tween_property(_box, "modulate:a", 1.0, 0.6)
