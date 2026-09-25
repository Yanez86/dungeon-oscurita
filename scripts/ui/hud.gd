class_name Hud
extends CanvasLayer
## Interfaccia minima (GDD): nessuna barra della torcia, solo gli slot
## dell'inventario in basso, poco visibili, e brevi messaggi che svaniscono.
## Un CanvasLayer disegna i suoi nodi sopra la scena 3D.

@export var message_time := 2.5  ## secondi prima che un messaggio sparisca

var player: Player:
	set = _set_player

var minimap := Minimap.new()

var _slots := HBoxContainer.new()
var _prompt := Label.new()
var _message := Label.new()
var _message_left := 0.0


func _ready() -> void:
	_slots.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 16)
	_slots.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_slots.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_slots.add_theme_constant_override("separation", 18)
	add_child(_slots)

	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position.y += 60
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.modulate = Color(1, 1, 1, 0.8)
	add_child(_prompt)

	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.position.y -= 70
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message)

	add_child(minimap)


func _set_player(p: Player) -> void:
	player = p
	minimap.player = p
	player.message.connect(_show_message)
	player.inventory.changed.connect(_refresh_slots)
	_refresh_slots()


func _process(delta: float) -> void:
	if player == null:
		return
	var p := player.nearby_pickup
	_prompt.text = "E  raccogli %s" % p.display_name().to_lower() if p else ""

	_message_left = maxf(_message_left - delta, 0.0)
	_message.modulate.a = clampf(_message_left, 0.0, 1.0)  # dissolvenza nell'ultimo secondo


func _show_message(text: String) -> void:
	_message.text = text
	_message_left = message_time


func _refresh_slots() -> void:
	for child in _slots.get_children():
		child.queue_free()
	var inv := player.inventory
	for i in inv.capacity():
		var label := Label.new()
		var id := inv.slots[i]
		label.text = "%d %s" % [i + 1, Items.display_name(id) if id != &"" else "·"]
		label.modulate = Color(1, 0.85, 0.6, 0.85) if i == inv.selected else Color(1, 1, 1, 0.35)
		_slots.add_child(label)
