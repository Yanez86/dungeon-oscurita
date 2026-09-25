extends Node3D
## Avvia la partita, genera i piani e gestisce il passaggio da un piano all'altro.

@export var fixed_seed := 0  ## 0 = casuale. Impostalo per riprodurre il piano di una segnalazione.

@onready var dungeon: DungeonBuilder = $Dungeon
@onready var player: CharacterBody3D = $Player


func _ready() -> void:
	dungeon.exit_reached.connect(_on_exit_reached)
	start_run(fixed_seed if fixed_seed != 0 else randi() % 1000000)


func start_run(run_seed: int) -> void:
	Game.run_seed = run_seed
	Game.floor_number = 1
	_load_floor()


func _load_floor() -> void:
	dungeon.build(Game.floor_seed())
	player.global_position = dungeon.cell_to_world(dungeon.gen.start_cell) + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	print("Piano %d (seed partita %d)\n%s" % [Game.floor_number, Game.run_seed, dungeon.gen.to_ascii()])


func _on_exit_reached() -> void:
	Game.floor_number += 1
	_load_floor.call_deferred()  # non ricostruire la fisica dentro un suo callback


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("new_run"):
		start_run(randi() % 1000000)
