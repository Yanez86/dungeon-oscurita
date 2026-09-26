extends Node3D
## Avvia la partita, genera i piani e gestisce il passaggio da un piano all'altro.

@export var fixed_seed := 0  ## 0 = casuale. Impostalo per riprodurre il piano di una segnalazione.

@onready var dungeon: DungeonBuilder = $Dungeon
@onready var player: Player = $Player
@onready var hud: Hud = $Hud


func _ready() -> void:
	dungeon.exit_reached.connect(_on_exit_reached)
	player.item_dropped.connect(dungeon.spawn_pickup)  # un segnale collegato a una funzione
	player.torch_dropped.connect(dungeon.spawn_ground_torch)
	dungeon.door_opened.connect(hud.minimap.open_door)
	dungeon.door_closed.connect(hud.minimap.close_door)
	hud.player = player
	start_run(fixed_seed if fixed_seed != 0 else randi() % 1000000)


func start_run(run_seed: int) -> void:
	Game.run_seed = run_seed
	Game.floor_number = 1
	player.reset_for_run()
	_load_floor()


## L'inventario e la torcia restano quelli del piano precedente.
func _load_floor() -> void:
	dungeon.build(Game.floor_seed(), Game.floor_number)
	player.global_position = dungeon.cell_to_world(dungeon.gen.start_cell) + Vector3.UP * 0.1
	player.velocity = Vector3.ZERO
	hud.minimap.start_floor(dungeon.gen)  # ogni piano si esplora da zero
	print("Piano %d (seed partita %d)\n%s" % [Game.floor_number, Game.run_seed, dungeon.gen.to_ascii()])


func _on_exit_reached() -> void:
	Game.floor_number += 1
	_load_floor.call_deferred()  # non ricostruire la fisica dentro un suo callback


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("new_run"):
		start_run(randi() % 1000000)
