class_name Hud
extends CanvasLayer
## Interfaccia minima (GDD): nessuna barra della torcia, solo gli slot
## dell'inventario in basso (icone in miniatura degli oggetti, poco visibili),
## brevi messaggi che svaniscono e, a sinistra, un riquadro vago sulla torcia accesa (vedi torch_buff.gd).
## Un CanvasLayer disegna i suoi nodi sopra la scena 3D.

@export var message_time := 2.5  ## secondi prima che un messaggio sparisca
@export var slot_alpha := 0.45     ## slot non selezionati: si vedono appena

var player: Player:
	set = _set_player

var minimap := Minimap.new()
var torch_buff := TorchBuff.new()
var icons := ItemIcons.new()  ## icone degli oggetti, condivise con il menu

var _slots := HBoxContainer.new()
var _prompt := Label.new()
var _message := Label.new()
var _message_left := 0.0


func _ready() -> void:
	_slots.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE, 16)
	_slots.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_slots.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_slots.add_theme_constant_override("separation", 6)
	_slots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_slots)

	_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_prompt.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_prompt.position.y += 60
	_prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt.modulate = Color(1, 1, 1, 0.8)
	add_child(_prompt)

	_message.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	_message.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message.position.y -= 105  # sopra la barra degli slot
	_message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_message)

	add_child(minimap)
	add_child(torch_buff)
	add_child(icons)


func _set_player(p: Player) -> void:
	player = p
	minimap.player = p
	torch_buff.torch = p.torch
	player.message.connect(_show_message)
	player.inventory.changed.connect(_refresh_slots)
	for i in player.inventory.capacity():
		var slot := ItemSlot.new()
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_slots.add_child(slot)
		slot.set_number(i + 1)
	_refresh_slots()


func _process(delta: float) -> void:
	if player == null:
		return
	var p := player.nearby_pickup
	if p:
		_prompt.text = "E  raccogli %s" % p.display_name().to_lower()
	elif player.nearby_door:
		_prompt.text = "E  chiudi la porta" if player.nearby_door.is_open else "E  apri la porta"
	else:
		_prompt.text = ""

	_message_left = maxf(_message_left - delta, 0.0)
	_message.modulate.a = clampf(_message_left, 0.0, 1.0)  # dissolvenza nell'ultimo secondo


func _show_message(text: String) -> void:
	_message.text = text
	_message_left = message_time


## Un'icona per slot; quello selezionato ha il bordo acceso ed è più visibile.
func _refresh_slots() -> void:
	var inv := player.inventory
	for i in inv.capacity():
		var slot := _slots.get_child(i) as ItemSlot
		slot.show_item(icons.icon(inv.slots[i]), i == inv.selected)
		slot.modulate.a = 1.0 if i == inv.selected else slot_alpha
