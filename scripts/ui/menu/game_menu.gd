class_name GameMenu
extends CanvasLayer
## Menu del giocatore (prototipo) a schede: scheda, inventario, diario, impostazioni.
## Tab lo apre e chiude; I e J portano a inventario e diario; Esc alle impostazioni (o chiude).
## Il gioco NON si ferma (in coop non si può mettere in pausa): la torcia continua
## a bruciare e i nemici continuano ad ascoltare. Col menu aperto il giocatore sta fermo.
## TabContainer: mostra un figlio alla volta, con una linguetta per ciascuno.

enum Tab { SHEET, INVENTORY, JOURNAL, SETTINGS }

@export var dim_color := Color(0, 0, 0, 0.6)
@export var panel_size := Vector2(800, 540)  ## fisso: il pannello non cambia misura tra una scheda e l'altra

var player: Player:
	set = _set_player
var icons: ItemIcons
var is_open := false

var _root := Control.new()
var _tabs := TabContainer.new()
var _pages: Array[MenuPage] = []


func _ready() -> void:
	layer = 10  # sopra HUD e overlay di debug
	visible = false
	_root.theme = UiTheme.make()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()  # scurisce il gioco e ferma i clic sul mondo
	dim.color = dim_color
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = panel_size
	center.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)

	_tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_tabs.tab_focus_mode = Control.FOCUS_NONE
	_tabs.tab_changed.connect(func(_i: int) -> void: _refresh_current())
	box.add_child(_tabs)
	_add_page(SheetPage.new(), "Scheda  [Tab]")
	_add_page(InventoryPage.new(), "Inventario  [I]")
	_add_page(JournalPage.new(), "Diario  [J]")
	_add_page(SettingsPage.new(), "Impostazioni  [Esc]")

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 8)
	box.add_child(footer)
	var note := UiTheme.label("Il tempo non si ferma: la torcia continua a bruciare.", UiTheme.DIM, 13)
	note.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(note)
	footer.add_child(_button("Riprendi", close))
	footer.add_child(_button("Esci dal gioco", func() -> void: get_tree().quit()))


func _set_player(p: Player) -> void:
	player = p
	for page in _pages:
		page.setup(p, icons)


func open(tab: Tab) -> void:
	_tabs.current_tab = tab
	is_open = true
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if player:
		player.input.in_menu = true
	_refresh_current()


func close() -> void:
	is_open = false
	visible = false
	get_viewport().gui_release_focus()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	if player:
		player.input.in_menu = false


## _input arriva prima dell'interfaccia: Tab non finisce a spostare il focus tra i controlli.
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("menu"):
		if is_open:
			close()
		else:
			open(_tabs.current_tab as Tab)
	elif event.is_action_pressed("menu_inventory"):
		_toggle(Tab.INVENTORY)
	elif event.is_action_pressed("menu_journal"):
		_toggle(Tab.JOURNAL)
	elif event.is_action_pressed("ui_cancel"):
		if is_open:
			close()
		else:
			open(Tab.SETTINGS)
	else:
		return
	get_viewport().set_input_as_handled()


## Apre sulla scheda chiesta; se è già aperta proprio lì, chiude.
func _toggle(tab: Tab) -> void:
	if is_open and _tabs.current_tab == tab:
		close()
	else:
		open(tab)


func _add_page(page: MenuPage, title: String) -> void:
	_tabs.add_child(page)
	_tabs.set_tab_title(_tabs.get_tab_count() - 1, title)
	_pages.append(page)


func _refresh_current() -> void:
	if is_open:
		_pages[_tabs.current_tab].refresh()


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE
	b.pressed.connect(action)
	return b
