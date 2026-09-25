class_name TorchBuff
extends PanelContainer
## Riquadro "buff" a sinistra, con lo stesso stile della minimappa: compare solo
## con la torcia accesa e dice a occhio quanto durerà (niente numeri, GDD).
## Il tempo esatto si vede solo nelle build di debug, per i test.
## PanelContainer: un contenitore che disegna uno sfondo (StyleBox) dietro ai figli.

@export var margin := 16
@export var background := Color(0, 0, 0, 0.35)       ## come la minimappa
@export var title_color := Color(1.0, 0.85, 0.6, 0.95)
@export var state_color := Color(0.62, 0.55, 0.45, 0.9)
@export var show_exact_time := true  ## solo se la build è di debug (editor)
@export_group("Soglie (frazione di combustibile)")
@export var strong_above := 0.6   ## sopra: "Brucia bene"
@export var weak_above := 0.25    ## sopra: "Si affievolisce"; sotto: "Sta per spegnersi"

var torch: Torch

var _title := Label.new()
var _state := Label.new()
var _time := Label.new()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)
	set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT, Control.PRESET_MODE_MINSIZE, margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 0)
	add_child(box)
	_title.text = "Torcia accesa"
	_title.modulate = title_color
	box.add_child(_title)
	_state.modulate = state_color
	box.add_child(_state)
	_time.modulate = state_color
	_time.add_theme_font_size_override("font_size", 12)
	_time.visible = show_exact_time and OS.is_debug_build()
	box.add_child(_time)
	visible = false


func _process(_delta: float) -> void:
	visible = torch != null and torch.lit
	if not visible:
		return
	_state.text = describe(torch.fuel / torch.max_fuel)
	if _time.visible:
		var secs := ceili(torch.fuel)
		_time.text = "%d:%02d" % [secs / 60, secs % 60]


## Indicazione vaga della durata residua.
func describe(ratio: float) -> String:
	if ratio > strong_above:
		return "Brucia bene"
	if ratio > weak_above:
		return "Si affievolisce"
	return "Sta per spegnersi"
