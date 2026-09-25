extends Node
## Bus degli eventi rumore: ogni suono del gioco (passi, voce, oggetti) passa di qui.
## I nemici si collegano a `noise_emitted` e decidono se l'hanno sentito.

signal noise_emitted(position: Vector3, loudness: float, source: Node)

var last_position := Vector3.ZERO
var last_loudness := 0.0


## loudness: 0.0 = silenzio, 1.0 = grido/combattimento.
func emit_noise(position: Vector3, loudness: float, source: Node = null) -> void:
	last_position = position
	last_loudness = loudness
	noise_emitted.emit(position, loudness, source)


func _process(delta: float) -> void:
	last_loudness = move_toward(last_loudness, 0.0, delta)  # per l'overlay di debug
