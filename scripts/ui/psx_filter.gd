class_name PsxFilter
extends CanvasLayer
## Filtro retro PS1 a tutto schermo (F4 lo accende e spegne).
## Sta sul layer -1: sopra il mondo 3D ma sotto l'HUD, che resta leggibile.

const SHADER := preload("res://shaders/psx_post.gdshader")

@export var enabled := true
@export var target_height := 240.0   ## righe verticali "retro"
@export var color_levels := 24.0     ## livelli per canale di colore
@export var dither_strength := 1.0
@export var grain := 0.04
@export var vignette := 0.45

var _rect := ColorRect.new()


func _ready() -> void:
	layer = -1
	var mat := ShaderMaterial.new()
	mat.shader = SHADER
	mat.set_shader_parameter("target_height", target_height)
	mat.set_shader_parameter("color_levels", color_levels)
	mat.set_shader_parameter("dither_strength", dither_strength)
	mat.set_shader_parameter("grain", grain)
	mat.set_shader_parameter("vignette", vignette)
	_rect.material = mat
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)
	visible = enabled


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("psx_toggle"):
		enabled = not enabled
		visible = enabled
