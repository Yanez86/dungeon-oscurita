class_name JournalPage
extends MenuPage
## Diario: le righe scritte da sole durante la partita (vedi journal.gd), divise per piano,
## le più recenti in fondo. RichTextLabel: un'etichetta che capisce il BBCode ([color], [b]…).

var _text := RichTextLabel.new()


func _build() -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)
	_text.bbcode_enabled = true
	_text.scroll_following = true  # resta in fondo, sulle righe nuove
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.focus_mode = Control.FOCUS_NONE
	box.add_child(_text)


func _on_setup() -> void:
	player.journal.changed.connect(refresh)


func refresh() -> void:
	if player == null or not is_inside_tree():
		return
	var entries := player.journal.entries
	if entries.is_empty():
		_text.text = "[color=#%s]Il diario è vuoto.[/color]" % UiTheme.DIM.to_html(false)
		return
	var lines := PackedStringArray()
	var floor_number := -1
	for e in entries:
		if e.floor_number != floor_number:
			floor_number = e.floor_number
			if not lines.is_empty():
				lines.append("")
			lines.append("[color=#%s][b]Piano %d[/b][/color]" % [UiTheme.ACCENT.to_html(false), floor_number])
		var text := e.text.replace("[", "[lb]")  # niente BBCode dentro le frasi
		if e.count > 1:
			text += "  [color=#%s]×%d[/color]" % [UiTheme.DIM.to_html(false), e.count]
		lines.append("·  " + text)
	_text.text = "\n".join(lines)
