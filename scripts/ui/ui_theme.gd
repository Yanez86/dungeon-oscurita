class_name UiTheme
extends RefCounted
## Stile dei menu: pannelli quasi neri con bordo color bronzo e testo caldo, come la luce della torcia.
## Un Theme è una risorsa di colori e stili: assegnata a un Control vale anche per tutti i suoi figli.

const TEXT := Color(0.86, 0.8, 0.7)
const DIM := Color(0.62, 0.55, 0.45)
const ACCENT := Color(1.0, 0.85, 0.6)
const PANEL := Color(0.05, 0.045, 0.04, 0.97)
const BORDER := Color(0.36, 0.27, 0.17)
const BUTTON := Color(0.12, 0.1, 0.08)
const HOVER := Color(0.2, 0.15, 0.1)


static func make() -> Theme:
	var t := Theme.new()
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", box(PANEL, BORDER, 2, 14))

	t.set_stylebox("normal", "Button", box(BUTTON, BORDER, 1, 8))
	t.set_stylebox("hover", "Button", box(HOVER, ACCENT.darkened(0.3), 1, 8))
	t.set_stylebox("pressed", "Button", box(HOVER, ACCENT, 1, 8))
	t.set_stylebox("disabled", "Button", box(BUTTON.darkened(0.3), BORDER.darkened(0.4), 1, 8))
	t.set_stylebox("focus", "Button", box(Color(0, 0, 0, 0), ACCENT.darkened(0.2), 1, 8))
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", ACCENT)
	t.set_color("font_pressed_color", "Button", ACCENT)
	t.set_color("font_disabled_color", "Button", DIM.darkened(0.3))
	t.set_color("font_color", "CheckButton", TEXT)
	t.set_color("font_hover_color", "CheckButton", ACCENT)
	t.set_color("font_pressed_color", "CheckButton", TEXT)

	var empty := StyleBoxEmpty.new()
	for s: String in ["normal", "hover", "pressed", "focus", "hover_pressed"]:
		t.set_stylebox(s, "CheckButton", empty)

	t.set_stylebox("panel", "TabContainer", box(Color(0, 0, 0, 0), BORDER, 0, 0))
	t.set_stylebox("tab_selected", "TabContainer", _tab(ACCENT, 2))
	t.set_stylebox("tab_unselected", "TabContainer", _tab(Color(0, 0, 0, 0), 2))
	t.set_stylebox("tab_hovered", "TabContainer", _tab(ACCENT.darkened(0.5), 2))
	t.set_stylebox("tab_focus", "TabContainer", empty)
	t.set_stylebox("tabbar_background", "TabContainer", _tab(BORDER, 1))
	t.set_color("font_selected_color", "TabContainer", ACCENT)
	t.set_color("font_unselected_color", "TabContainer", DIM)
	t.set_color("font_hovered_color", "TabContainer", TEXT)

	t.set_color("default_color", "RichTextLabel", TEXT)
	t.set_stylebox("separator", "HSeparator", _line(BORDER))
	t.set_constant("separation", "HSeparator", 12)
	return t


## Riquadro pieno con bordo e margine interno.
static func box(bg: Color, border: Color, border_width: int, margin: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(border_width)
	s.set_content_margin_all(margin)
	return s


## Etichetta già colorata (e più grande, se `size` > 0).
static func label(text: String, color: Color = TEXT, size: int = 0) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", color)
	if size > 0:
		l.add_theme_font_size_override("font_size", size)
	return l


## Linguetta di una scheda: solo una riga sotto il titolo.
static func _tab(line: Color, width: int) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = Color(0, 0, 0, 0)
	s.border_color = line
	s.border_width_bottom = width
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 8
	return s


static func _line(color: Color) -> StyleBoxLine:
	var s := StyleBoxLine.new()
	s.color = color
	s.thickness = 1
	return s
