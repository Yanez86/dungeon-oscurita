class_name Minimap
extends Control
## Minimappa in alto a destra: mostra solo ciò che la torcia ha illuminato.
## Un'immagine con un pixel per cella, ingrandita senza sfocatura; sopra,
## in _draw(), la freccia del giocatore. Nord sempre in alto. M la nasconde.

@export var cell_px := 4                 ## pixel sullo schermo per cella
@export var margin := 16
@export var reveal_scale := 1.0          ## quanto del raggio della torcia "vede" il giocatore
@export var dim_when_dark := true        ## al buio la mappa quasi non si legge
@export var dark_alpha := 0.15
@export var floor_color := Color(0.62, 0.55, 0.45, 0.55)
@export var wall_color := Color(0.28, 0.25, 0.22, 0.85)
@export var exit_color := Color(1.0, 0.75, 0.35, 0.9)
@export var door_color := Color(0.55, 0.33, 0.16, 0.9)  ## porta chiusa
@export var golden_door_color := Color(0.95, 0.75, 0.25, 0.95)  ## la porta dorata della scala, chiusa
@export var gate_color := Color(0.42, 0.42, 0.45, 0.9)  ## cancello abbassato
@export var player_color := Color(1.0, 0.85, 0.6, 0.95)
@export var background := Color(0, 0, 0, 0.35)

var player: Player
var explored: ExploredMap

var _image: Image
var _texture: ImageTexture
var _last_cell := Vector2i(-1, -1)
var _last_radius := -1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST  # pixel netti, niente sfocatura


## Nuovo piano: mappa vuota, grande quanto la griglia del generatore.
func start_floor(gen: DungeonGenerator) -> void:
	explored = ExploredMap.new(gen)
	_image = Image.create_empty(gen.width, gen.height, false, Image.FORMAT_RGBA8)
	_texture = ImageTexture.create_from_image(_image)
	_last_cell = Vector2i(-1, -1)
	_last_radius = -1.0
	size = Vector2(gen.width, gen.height) * cell_px
	set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_KEEP_SIZE, margin)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("map_toggle"):
		visible = not visible


func _process(_delta: float) -> void:
	if player == null or explored == null:
		return
	_update_explored()
	var torch := player.torch
	modulate.a = 1.0 if torch.is_shining() or not dim_when_dark else dark_alpha
	queue_redraw()


## Rivela solo quando il giocatore cambia cella o la luce cambia davvero.
func _update_explored() -> void:
	var torch := player.torch
	var radius := torch.omni_range / DungeonBuilder.CELL * reveal_scale if torch.is_shining() else 0.0
	var cell := DungeonBuilder.world_to_cell(player.global_position)
	if cell == _last_cell and absf(radius - _last_radius) < 0.25:
		return
	_last_cell = cell
	_last_radius = radius
	var revealed := explored.reveal(cell, radius)
	if revealed.is_empty():
		return
	for c in revealed:
		_image.set_pixelv(c, _cell_color(c))
	_texture.update(_image)


## Una porta si è aperta: la si ridisegna come pavimento e si ricalcola
## la vista subito, perché ora si vede cosa c'è oltre.
func open_door(c: Vector2i) -> void:
	if explored == null:
		return
	explored.open_door(c)
	if explored.is_seen(c):
		_image.set_pixelv(c, _cell_color(c))
		_texture.update(_image)
	_last_cell = Vector2i(-1, -1)


## Una porta si è richiusa: ciò che è già disegnato resta com'è (anche la porta,
## che resta del colore del pavimento); cambia solo la vista da qui in avanti.
func close_door(c: Vector2i) -> void:
	if explored:
		explored.close_door(c)


func _cell_color(c: Vector2i) -> Color:
	var gen := explored.gen
	if c == gen.exit_cell:
		return exit_color
	if explored.closed_doors.has(c):
		match gen.door_kinds.get(c, &""):
			DungeonGenerator.DOOR_GOLDEN:
				return golden_door_color
			DungeonGenerator.DOOR_SECRET:
				return wall_color  # finché è chiuso è un muro come gli altri
			DungeonGenerator.DOOR_GATE:
				return gate_color
		return door_color
	return floor_color if gen.is_floor(c) else wall_color


func _draw() -> void:
	if _texture == null:
		return
	draw_rect(Rect2(Vector2.ZERO, size), background)
	draw_texture_rect(_texture, Rect2(Vector2.ZERO, size), false)
	if player == null:
		return
	# Freccia del giocatore: la cella (x, y) corrisponde al mondo (x, z).
	var pos := Vector2(player.global_position.x, player.global_position.z) / DungeonBuilder.CELL
	var center := (pos + Vector2(0.5, 0.5)) * cell_px
	var fwd3 := -player.global_transform.basis.z
	var fwd := Vector2(fwd3.x, fwd3.z).normalized()
	var side := Vector2(-fwd.y, fwd.x)
	var s := float(cell_px) * 1.2
	draw_colored_polygon(PackedVector2Array([
		center + fwd * s * 1.4,
		center - fwd * s * 0.8 + side * s * 0.9,
		center - fwd * s * 0.8 - side * s * 0.9,
	]), player_color)
