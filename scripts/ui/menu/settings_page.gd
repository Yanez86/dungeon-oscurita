class_name SettingsPage
extends MenuPage
## Impostazioni: ogni controllo scrive in Settings, che applica e salva da solo.

var _mouse := HSlider.new()
var _mouse_value := UiTheme.label("")
var _volume := HSlider.new()
var _volume_value := UiTheme.label("")
var _psx := CheckButton.new()
var _fullscreen := CheckButton.new()


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	add_child(box)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 20)
	grid.add_theme_constant_override("v_separation", 14)
	box.add_child(grid)

	_slider(grid, "Sensibilità del mouse", _mouse, _mouse_value, Settings.MOUSE_MIN, Settings.MOUSE_MAX, 0.05)
	_mouse.value_changed.connect(func(v: float) -> void: Settings.update("mouse_scale", v))
	_slider(grid, "Volume generale", _volume, _volume_value, 0.0, 1.0, 0.05)
	_volume.value_changed.connect(func(v: float) -> void: Settings.update("master_volume", v))
	_toggle(grid, "Filtro retro PS1  (F4)", _psx)
	_psx.toggled.connect(func(on: bool) -> void: Settings.update("psx_filter", on))
	_toggle(grid, "Schermo intero", _fullscreen)
	_fullscreen.toggled.connect(func(on: bool) -> void: Settings.update("fullscreen", on))

	box.add_child(HSeparator.new())
	var reset := Button.new()
	reset.text = "Ripristina i valori predefiniti"
	reset.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	reset.focus_mode = Control.FOCUS_NONE
	reset.pressed.connect(Settings.reset_to_defaults)
	box.add_child(reset)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	box.add_child(UiTheme.label("Le impostazioni si salvano da sole.  Versione %s" % Game.version, UiTheme.DIM, 13))
	Settings.changed.connect(refresh)
	refresh()


## Rilegge i valori da Settings (senza far ripartire i segnali dei controlli).
func refresh() -> void:
	_mouse.set_value_no_signal(Settings.mouse_scale)
	_mouse_value.text = "%.2f×" % Settings.mouse_scale
	_volume.set_value_no_signal(Settings.master_volume)
	_volume_value.text = "%d%%" % roundi(Settings.master_volume * 100.0)
	_psx.set_pressed_no_signal(Settings.psx_filter)
	_fullscreen.set_pressed_no_signal(Settings.fullscreen)


func _slider(grid: GridContainer, title: String, slider: HSlider, value_label: Label,
		low: float, high: float, step: float) -> void:
	grid.add_child(_title(title))
	slider.min_value = low
	slider.max_value = high
	slider.step = step
	slider.custom_minimum_size.x = 260
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	grid.add_child(slider)
	value_label.custom_minimum_size.x = 60
	grid.add_child(value_label)


func _toggle(grid: GridContainer, title: String, button: CheckButton) -> void:
	grid.add_child(_title(title))
	button.focus_mode = Control.FOCUS_NONE
	button.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	grid.add_child(button)
	grid.add_child(Control.new())  # terza colonna vuota


func _title(text: String) -> Label:
	var l := UiTheme.label(text, UiTheme.DIM)
	l.custom_minimum_size.x = 200
	return l
