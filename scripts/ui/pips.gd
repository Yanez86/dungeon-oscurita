class_name Pips
extends Control
## Una fila di tacche (energia, rumore): piene fino a `value`, vuote dopo.
## Le tacche tra `value` e `ghost` sono appena state perse: si disegnano chiare per un attimo.
## Si disegna da sola in _draw(), la funzione in cui un Control disegna sé stesso.

@export var count := 10:
	set(v):
		count = maxi(v, 1)
		_resize()
@export var value := 10:
	set(v):
		value = v
		queue_redraw()
@export var pip_size := Vector2(12, 10):
	set(v):
		pip_size = v
		_resize()
@export var gap := 3.0
@export var fill_color := Color(0.78, 0.2, 0.14)
@export var empty_color := Color(0.2, 0.09, 0.07, 0.8)
@export var ghost_color := Color(1.0, 0.88, 0.75)

var ghost := 0:
	set(v):
		ghost = v
		queue_redraw()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_resize()


func _draw() -> void:
	for i in count:
		var color := empty_color
		if i < value:
			color = fill_color
		elif i < ghost:
			color = ghost_color
		draw_rect(Rect2(Vector2(i * (pip_size.x + gap), 0.0), pip_size), color)


func _resize() -> void:
	custom_minimum_size = Vector2(count * pip_size.x + (count - 1) * gap, pip_size.y)
	queue_redraw()
