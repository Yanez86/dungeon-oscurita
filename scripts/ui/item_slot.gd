class_name ItemSlot
extends PanelContainer
## Uno slot dell'inventario: l'icona in miniatura dell'oggetto e, nell'angolo, il tasto che lo seleziona.
## Lo usano la barra in basso (piccolo, non cliccabile) e il menu (grande, cliccabile).
## L'icona ha un bordino caldo (shader icon_outline): un oggetto scuro si legge anche al buio.

const OUTLINE_SHADER := preload("res://shaders/icon_outline.gdshader")

## Clic sinistro sullo slot (solo se mouse_filter non è IGNORE).
signal pressed

@export var icon_size := 48  ## lato dell'icona sullo schermo (multiplo di ItemIcons.icon_px: pixel netti)
@export var background := Color(0, 0, 0, 0.35)       ## come minimappa e riquadro della torcia
@export var border_color := Color(1, 1, 1, 0.12)
@export var selected_color := Color(1.0, 0.85, 0.6, 0.95)
@export var number_color := Color(1, 1, 1, 0.55)

var _icon := TextureRect.new()
var _number := Label.new()
var _style := StyleBoxFlat.new()


func _ready() -> void:
	_style.bg_color = background
	_style.set_border_width_all(2)
	_style.set_content_margin_all(4)
	add_theme_stylebox_override("panel", _style)

	var area := Control.new()  # icona e numero sovrapposti
	area.custom_minimum_size = Vector2(icon_size, icon_size)
	area.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(area)
	_icon.set_anchors_preset(Control.PRESET_FULL_RECT)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel netti, niente sfocatura
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var outline := ShaderMaterial.new()
	outline.shader = OUTLINE_SHADER
	_icon.material = outline
	area.add_child(_icon)
	_number.position = Vector2(-2, -6)
	_number.add_theme_font_size_override("font_size", 12)
	_number.modulate = number_color
	_number.mouse_filter = Control.MOUSE_FILTER_IGNORE
	area.add_child(_number)
	if mouse_filter != Control.MOUSE_FILTER_IGNORE:
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


## Numero del tasto (1–5) mostrato nell'angolo.
func set_number(n: int) -> void:
	_number.text = str(n)


## Icona dell'oggetto (null = slot vuoto) e bordo acceso se è lo slot selezionato.
func show_item(icon: Texture2D, selected: bool) -> void:
	_icon.texture = icon
	_style.border_color = selected_color if selected else border_color


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit()
		accept_event()
