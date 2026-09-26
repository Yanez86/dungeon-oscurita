class_name InventoryPage
extends MenuPage
## Inventario: gli slot in grande con le icone (5 per riga: la seconda è quella dello zaino);
## clic (o 1–8) per selezionare, sotto nome e descrizione dell'oggetto selezionato e il pulsante per lasciarlo a terra.
## Le azioni passano da PlayerInput, come i tasti: il menu non tocca l'inventario da solo.

@export var slot_icon_size := 96  ## doppio dell'icona (48 px): pixel netti
@export var slots_per_row := 5    ## quanti ne ha l'inventario iniziale: gli slot dello zaino vanno a capo

var _slots := GridContainer.new()
var _name := UiTheme.label("", UiTheme.ACCENT, 20)
var _description := UiTheme.label("")
var _drop := Button.new()
var _space := UiTheme.label("", UiTheme.DIM)


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var header := HBoxContainer.new()
	box.add_child(header)
	var title := UiTheme.label("Oggetti", UiTheme.ACCENT)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	header.add_child(_space)
	_slots.columns = slots_per_row
	_slots.add_theme_constant_override("h_separation", 10)
	_slots.add_theme_constant_override("v_separation", 10)
	box.add_child(_slots)
	box.add_child(HSeparator.new())

	box.add_child(_name)
	_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_description.custom_minimum_size.y = 48
	box.add_child(_description)
	_drop.text = "Lascia a terra  (G)"
	_drop.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_drop.focus_mode = Control.FOCUS_NONE  # la barra spaziatrice non deve premerlo per sbaglio
	_drop.pressed.connect(func() -> void: player.input.request_drop())
	box.add_child(_drop)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var hint := UiTheme.label("Clic o 1–8: seleziona. Le torce occupano posto come ogni altro oggetto: più luce, meno spazio.", UiTheme.DIM, 13)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(hint)


func _on_setup() -> void:
	player.inventory.changed.connect(refresh)


func refresh() -> void:
	if player == null or not is_inside_tree():
		return
	var inv := player.inventory
	# Gli slot seguono la capienza (lo zaino ne aggiunge).
	while _slots.get_child_count() < inv.capacity():
		var i := _slots.get_child_count()
		var slot := ItemSlot.new()
		slot.icon_size = slot_icon_size
		slot.pressed.connect(player.input.request_slot.bind(i))
		_slots.add_child(slot)
		slot.set_number(i + 1)
	while _slots.get_child_count() > inv.capacity():
		var last := _slots.get_child(_slots.get_child_count() - 1)
		_slots.remove_child(last)
		last.queue_free()
	for i in inv.capacity():
		var slot := _slots.get_child(i) as ItemSlot
		var id := inv.slots[i]
		slot.show_item(icons.icon(id), i == inv.selected)
		slot.tooltip_text = Items.display_name(id) if id != &"" else ""
	_space.text = "%d / %d posti liberi" % [inv.count(&""), inv.capacity()]
	var selected := inv.selected_item()
	if selected == &"":
		_name.text = "Slot %d vuoto" % (inv.selected + 1)
		_description.text = "Raccogli un oggetto (E) per riempirlo."
	else:
		_name.text = Items.display_name(selected)
		_description.text = Items.description(selected)
	_drop.disabled = selected == &""
