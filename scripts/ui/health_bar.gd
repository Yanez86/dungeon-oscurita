class_name HealthBar
extends PanelContainer
## Barra dell'energia in alto a sinistra, sopra il riquadro della torcia: una tacca per punto.
## Quando si perde energia le tacche perse restano chiare per un attimo;
## con poca energia la barra pulsa. Stesso stile della minimappa e del riquadro della torcia.

@export var background := Color(0, 0, 0, 0.35)
@export var title_color := Color(1.0, 0.85, 0.6, 0.95)
@export var ghost_time := 0.6  ## secondi in cui le tacche appena perse restano visibili
@export var low_hp := 3        ## da qui in giù la barra pulsa
@export var pulse_speed := 5.0

var health: Health:
	set = _set_health

var _pips := Pips.new()
var _ghost_left := 0.0
var _last_hp := 0
var _time := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.set_content_margin_all(8)
	add_theme_stylebox_override("panel", style)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var title := Label.new()
	title.text = "Energia"
	title.modulate = title_color
	box.add_child(title)
	box.add_child(_pips)


func _set_health(h: Health) -> void:
	health = h
	health.changed.connect(_on_changed)
	_pips.count = health.max_hp
	_last_hp = health.hp
	_on_changed()


func _on_changed() -> void:
	if health.hp < _last_hp:
		_pips.ghost = _last_hp
		_ghost_left = ghost_time
	_last_hp = health.hp
	_pips.value = health.hp


func _process(delta: float) -> void:
	if health == null:
		return
	_time += delta
	if _ghost_left > 0.0:
		_ghost_left -= delta
		if _ghost_left <= 0.0:
			_pips.ghost = 0
	var weak := health.hp <= low_hp and not health.is_dead()
	_pips.modulate.a = 0.65 + 0.35 * sin(_time * pulse_speed) if weak else 1.0
