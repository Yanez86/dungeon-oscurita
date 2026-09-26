class_name SheetPage
extends MenuPage
## Scheda del giocatore: energia, torcia, piano, tempo nel buio e quanto rumore fa muoversi.
## Si aggiorna ogni frame mentre è aperta (la torcia brucia anche col menu aperto).

var _name := UiTheme.label("", UiTheme.ACCENT, 24)
var _subtitle := UiTheme.label("", UiTheme.DIM)
var _health_pips := Pips.new()
var _health_text := UiTheme.label("")
var _torch := UiTheme.label("")
var _spares := UiTheme.label("")
var _shield := UiTheme.label("")
var _space := UiTheme.label("")
var _treasure := UiTheme.label("")
var _noise_pips: Array[Pips] = []


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	box.add_child(_name)
	box.add_child(_subtitle)
	box.add_child(HSeparator.new())

	var grid := _grid()
	box.add_child(grid)
	var health_row := HBoxContainer.new()
	health_row.add_theme_constant_override("separation", 12)
	health_row.add_child(_health_pips)
	health_row.add_child(_health_text)
	_row(grid, "Energia", health_row)
	_row(grid, "Torcia in uso", _torch)
	_row(grid, "Torce di scorta", _spares)
	_row(grid, "Scudo", _shield)
	_row(grid, "Inventario", _space)
	_row(grid, "Tesori", _treasure)

	box.add_child(HSeparator.new())
	box.add_child(UiTheme.label("Rumore dei passi", UiTheme.ACCENT))
	var noise := _grid()
	box.add_child(noise)
	for gait: String in ["Accovacciato", "Camminando", "Correndo"]:
		var pips := Pips.new()
		pips.pip_size = Vector2(10, 8)
		pips.fill_color = UiTheme.ACCENT.darkened(0.2)
		pips.empty_color = Color(1, 1, 1, 0.08)
		_noise_pips.append(pips)
		_row(noise, gait, pips)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var motto := UiTheme.label("Tutto fa rumore e i nemici ascoltano: combattere è l'ultima spiaggia.", UiTheme.DIM, 13)
	box.add_child(motto)


func refresh() -> void:
	if player == null:
		return
	_name.text = player.player_name
	var secs := int(Game.run_time)
	_subtitle.text = "Piano %d  ·  %d:%02d nel buio" % [Game.floor_number, secs / 60, secs % 60]

	var h := player.health
	_health_pips.count = h.max_hp
	_health_pips.value = h.hp
	_health_text.text = "%d / %d  %s" % [h.hp, h.max_hp, _health_word(h)]

	var t := player.torch
	if t.is_shining():
		_torch.text = "Accesa, in mano"
	elif t.lit:
		_torch.text = "Accesa ma riposta: brucia senza far luce"
	elif t.fuel > 0.0:
		_torch.text = "Spenta (si può riaccendere)"
	else:
		_torch.text = "Nessuna"
	var spares := player.inventory.count(Items.TORCH)
	_spares.text = str(spares) if spares > 0 else "Nessuna"
	if player.inventory.has(Items.SHIELD):
		_shield.text = "Integro: para 1 danno per colpo, ancora 2 volte"
	elif player.inventory.has(Items.SHIELD_CRACKED):
		_shield.text = "Incrinato: para 1 danno ancora una volta"
	else:
		_shield.text = "Nessuno"
	var inv := player.inventory
	_space.text = "%d / %d posti liberi" % [inv.count(&""), inv.capacity()]
	var carried := Treasures.carried_value(inv)
	_treasure.text = "%d punti in salvo" % Game.score
	if carried > 0:
		_treasure.text += "  ·  %d addosso (contano quando scendi la scala)" % carried

	var loudness: Array[float] = [player.crouch_loudness, player.walk_loudness, player.sprint_loudness]
	for i in _noise_pips.size():
		_noise_pips[i].value = roundi(loudness[i] * _noise_pips[i].count)


func _process(_delta: float) -> void:
	if is_visible_in_tree():
		refresh()


## Parola vaga sullo stato di salute (la scheda può permettersi anche il numero).
func _health_word(h: Health) -> String:
	if h.is_dead():
		return "· a terra"
	if h.is_full():
		return "· illeso"
	var ratio := float(h.hp) / float(h.max_hp)
	if ratio > 0.6:
		return "· ferito"
	if ratio > 0.3:
		return "· ferito gravemente"
	return "· allo stremo"


func _grid() -> GridContainer:
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 8)
	return grid


func _row(grid: GridContainer, title: String, value: Control) -> void:
	var l := UiTheme.label(title, UiTheme.DIM)
	l.custom_minimum_size.x = 150
	grid.add_child(l)
	value.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(value)
