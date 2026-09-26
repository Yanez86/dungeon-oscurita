class_name GoldenDoor
extends Door
## La porta dorata che chiude la nicchia della scala (vedi DungeonGenerator.golden_door): una porta come
## le altre, ma con l'anta dorata e una serratura. Si apre solo con la chiave d'oro nell'inventario (non serve
## selezionarla): la chiave resta nella serratura e da lì in poi la porta si apre e si chiude come le altre.
## Senza chiave la maniglia sbatte (poco rumore) e un messaggio dice cosa serve.

@export var locked_loudness := 0.15  ## la maniglia che sbatte contro la serratura
@export var unlock_loudness := 0.3   ## lo scatto della serratura

var locked := true


func _leaf_model() -> StringName:
	return &"door_leaf_gold"


func prompt() -> String:
	if locked:
		return "E  apri la porta dorata (serve la chiave d'oro)"
	return super.prompt()


func _unlock(opener: Node3D) -> bool:
	if not locked:
		return true
	var at := global_position + Vector3.UP * 1.1
	var p := opener as Player
	if p == null or not p.inventory.remove(Items.KEY_GOLD):
		Sfx.play_at(self, &"door_locked", at)
		NoiseBus.emit_noise(global_position, locked_loudness, opener)
		if p:
			p.message.emit("È chiusa a chiave: serve la chiave d'oro.")
		return false
	locked = false
	Sfx.play_at(self, &"key_unlock", at)
	NoiseBus.emit_noise(global_position, unlock_loudness, opener)
	p.message.emit("La chiave d'oro gira nella serratura.")
	p.note("Aperta la porta dorata: dietro, la scala che scende.")
	return true
