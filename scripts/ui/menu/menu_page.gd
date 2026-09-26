class_name MenuPage
extends MarginContainer
## Base delle pagine del menu (una scheda ciascuna). La pagina costruisce i suoi nodi
## in _ready(), riceve giocatore e icone con setup() e si ridisegna con refresh()
## quando la si apre. Nuova pagina: estendi questa classe e aggiungila in game_menu.gd.

var player: Player
var icons: ItemIcons


func _ready() -> void:
	add_theme_constant_override("margin_left", 18)
	add_theme_constant_override("margin_right", 18)
	add_theme_constant_override("margin_top", 16)
	add_theme_constant_override("margin_bottom", 8)
	_build()


func setup(p: Player, item_icons: ItemIcons) -> void:
	player = p
	icons = item_icons
	_on_setup()


## Crea i nodi della pagina (una volta sola).
func _build() -> void:
	pass


## Il giocatore è arrivato: collega i segnali che servono.
func _on_setup() -> void:
	pass


## Aggiorna i contenuti (la pagina è appena stata aperta).
func refresh() -> void:
	pass
