extends CanvasLayer
## Versione e seed sempre visibili (per le segnalazioni dei tester).
## F3: dettagli di debug.

var _corner := Label.new()
var _details := Label.new()


func _ready() -> void:
	_corner.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT, Control.PRESET_MODE_MINSIZE, 8)
	_corner.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_corner.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_corner.modulate = Color(1, 1, 1, 0.6)
	add_child(_corner)

	_details.position = Vector2(8, 110)  # sotto il riquadro della torcia
	_details.visible = false
	add_child(_details)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_toggle"):
		_details.visible = not _details.visible


func _process(_delta: float) -> void:
	_corner.text = "v%s  seed %d  piano %d" % [Game.version, Game.run_seed, Game.floor_number]
	if not _details.visible:
		return
	var player := get_tree().get_first_node_in_group("player") as Node3D
	var lines := PackedStringArray()
	lines.append("FPS: %d" % Engine.get_frames_per_second())
	if player:
		lines.append("Posizione: %s" % str(player.global_position.snapped(Vector3.ONE * 0.1)))
		var torch := player.get_node_or_null("Head/Torch") as Torch
		if torch:
			lines.append("Torcia: %.0f s %s" % [torch.fuel, "" if torch.lit else "(spenta)"])
	lines.append("Rumore: %s" % "|".repeat(int(NoiseBus.last_loudness * 20.0)))
	lines.append("")
	lines.append("WASD muovi · Shift corri · Ctrl accovacciati")
	lines.append("F spegni torcia · Q accendi (al buio: acciarino selezionato)")
	lines.append("E raccogli · 1-5 scegli slot · G lascia a terra")
	lines.append("R nuova partita · Esc libera il mouse")
	_details.text = "\n".join(lines)
