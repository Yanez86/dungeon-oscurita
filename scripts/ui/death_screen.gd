class_name DeathScreen
extends Control
## Schermata di fine partita: lo schermo si scurisce piano, poi compaiono piano raggiunto,
## tempo nel buio, causa e seed (per le segnalazioni). R avvia una nuova partita (vedi main.gd).

@export var fade_time := 1.5  ## secondi per scurire lo schermo
@export var darkness := 0.8   ## opacità finale del velo nero

var _veil := ColorRect.new()
var _box := VBoxContainer.new()
var _details := UiTheme.label("")
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
	var title := UiTheme.label("Sei morto", Color(0.75, 0.22, 0.16), 48)
	for l: Label in [title, _details, _cause, _seed]:
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_box.add_child(l)
	var hint := UiTheme.label("R  nuova partita", UiTheme.ACCENT)
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_box.add_child(hint)


## `cause`: chi ti ha ucciso ("il Cieco"), vuota se non si sa.
func appear(cause: String) -> void:
	var secs := int(Game.run_time)
	_details.text = "Piano %d  ·  %d:%02d nel buio" % [Game.floor_number, secs / 60, secs % 60]
	_cause.text = "Ucciso da %s." % cause if cause != "" else ""
	_cause.visible = cause != ""
	_seed.text = "seed %d" % Game.run_seed
	visible = true
	_veil.color.a = 0.0
	_box.modulate.a = 0.0
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_veil, "color:a", darkness, fade_time)
	_tween.tween_property(_box, "modulate:a", 1.0, 0.6)


func disappear() -> void:
	if _tween:
		_tween.kill()
	visible = false
