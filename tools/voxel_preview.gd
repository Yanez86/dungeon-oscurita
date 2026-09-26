extends Node
## Screenshot di controllo dei modelli voxel (serve la grafica: niente --headless).
##   godot res://tools/voxel_preview.tscn -- <cartella_output> [seed]
## Salva gallery.png (muri, pavimenti, porte, scala), props.png (arredi, oggetti, tesori, leve e trappole), enemy.png (il Cieco),
## room.png (stanza d'ingresso), door.png (una porta), exit_door.png e exit_stairs.png (porta dorata, chiusa e aperta sulla scala),
## secret.png e secret_open.png (un muro segreto, chiuso e aperto),
## decoration.png (un arredo), pickup.png (oggetti a terra), ground_torch.png (torcia accesa buttata a terra) e hand.png (prima persona con la torcia in mano).

const MODELS: Array[StringName] = [&"floor_stone_a", &"floor_stone_cracked", &"floor_stone_moss", &"floor_dirt_a",
	&"ceiling", &"wall_a", &"wall_cracked", &"wall_shelves", &"wall_secret", &"pillar", &"door_frame", &"door_leaf",
	&"door_leaf_gold", &"stairs_down"]
const PROPS: Array[StringName] = [&"barrel_small", &"barrel_large", &"barrel_stack", &"keg", &"crate_small", &"crate_large",
	&"crate_decorated", &"crates_stacked", &"trunk_small_a", &"trunk_small_b", &"trunk_medium_a", &"trunk_medium_b",
	&"candle", &"candle_triple", &"candle_melted", &"wall_torch", &"item_torch", &"item_flint",
	&"item_shield", &"item_shield_cracked", &"item_bear_trap", &"trap_bear_open", &"item_backpack", &"item_key_gold",
	&"item_coins", &"item_gem", &"item_chalice", &"lever_plate", &"lever_handle", &"gate_bars"]

var _out := "user://"
var _seed := 12345


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		_out = args[0].trim_suffix("/") + "/"
	if args.size() > 1:
		_seed = int(args[1])
	_run.call_deferred()


func _run() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.05, 0.05, 0.07)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.5, 0.5, 0.6)
	env.environment.ambient_light_energy = 0.25
	add_child(env)
	var cam := Camera3D.new()
	add_child(cam)

	await _gallery(cam, MODELS, MODELS.size(), "gallery.png")
	await _gallery(cam, PROPS, 10, "props.png")
	await _portrait(cam, &"enemy_blind", "enemy.png")

	# Dungeon: la stanza d'ingresso e una porta, illuminate da una "torcia" sulla camera.
	var dungeon := DungeonBuilder.new()
	add_child(dungeon)
	dungeon.secret_rooms_first_floor = Vector2i(1, 1)  # per fotografare un muro segreto
	dungeon.build(_seed, 1)
	var torch := OmniLight3D.new()
	torch.omni_range = 12.0
	torch.light_energy = 2.0
	torch.light_color = Color(1.0, 0.7, 0.4)
	torch.shadow_enabled = true
	cam.add_child(torch)
	var room := dungeon.gen.rooms[0]
	cam.position = dungeon.cell_to_world(room.position) + Vector3(0, 1.6, 0)
	cam.look_at(dungeon.cell_to_world(room.end - Vector2i.ONE) + Vector3(0, 1.0, 0))
	await _shot("room.png")
	if not dungeon.gen.doors.is_empty():
		var c: Vector2i = dungeon.gen.doors.keys()[0]
		var axis := Vector3(1, 0, 0) if dungeon.gen.doors[c] else Vector3(0, 0, 1)
		var p := dungeon.cell_to_world(c)
		cam.position = p + axis * 2.6 + Vector3(0, 1.5, 0)
		cam.look_at(p + Vector3(0, 1.2, 0))
		await _shot("door.png")
	var gd := dungeon.gen.golden_door
	if gd.x >= 0:
		# L'uscita: la porta dorata vista dalla sua stanza, poi aperta, con la scala che scende.
		var back := -Vector3(dungeon.gen.exit_dir.x, 0, dungeon.gen.exit_dir.y)
		var gp := dungeon.cell_to_world(gd)
		cam.position = gp + back * 3.2 + Vector3(0, 1.6, 0)
		cam.look_at(gp + Vector3(0, 1.1, 0))
		await _shot("exit_door.png")
		for node in get_tree().get_nodes_in_group("door"):
			if node is GoldenDoor:
				(node as GoldenDoor).locked = false
				(node as Door).open(cam)
		cam.position = gp - back * 0.6 + Vector3(0, 1.5, 0)
		cam.look_at(dungeon.cell_to_world(dungeon.gen.exit_cell) - back * 0.5 + Vector3(0, -1.5, 0))
		await _shot("exit_stairs.png")
	for node in get_tree().get_nodes_in_group("door"):
		if node is SecretDoor:
			# Un muro segreto visto dalla sua stanza: chiuso deve sembrare un muro; poi aperto, sui tesori.
			var sd := node as SecretDoor
			var facing := sd.global_basis.z  # verso la stanza
			cam.position = sd.global_position + facing * 3.4 + Vector3(0, 1.6, 0)
			cam.look_at(sd.global_position + facing + Vector3(0, 1.2, 0))
			await _shot("secret.png")
			sd.open(cam)
			await get_tree().create_timer(sd.open_time + 0.3).timeout
			await _shot("secret_open.png")
			break
	if not dungeon.gen.decorations.is_empty():
		# Un arredo visto dal centro della sua cella, un po' indietro.
		var dc: Vector2i = dungeon.gen.decorations.keys()[0]
		var wall_dir := Vector3.ZERO
		for d in DungeonBuilder.DIRS:
			if not dungeon.gen.is_floor(dc + d):
				wall_dir += Vector3(d.x, 0, d.y)
		var dp := dungeon.cell_to_world(dc)
		cam.position = dp - wall_dir.normalized() * 2.2 + Vector3(0, 1.4, 0)
		cam.look_at(dp + wall_dir.normalized() * 0.5 + Vector3(0, 0.4, 0))
		await _shot("decoration.png")

	# Oggetti a terra da vicino: la torcia della stanza d'ingresso e un acciarino accanto.
	var pickups := get_tree().get_nodes_in_group("pickup")
	if not pickups.is_empty():
		var pp: Vector3 = (pickups[0] as Node3D).global_position
		dungeon.spawn_pickup(Items.FLINT, pp + Vector3(0.45, 0, 0.25))
		cam.position = pp + Vector3(0.9, 0.9, 1.0)
		cam.look_at(pp + Vector3(0.2, 0, 0.1))
		await _shot("pickup.png")

	# Una torcia buttata a terra, accesa, in un'altra stanza: è l'unica luce (quella della camera si spegne).
	torch.visible = false
	if dungeon.gen.rooms.size() > 1:
		var gp := dungeon.cell_to_world(dungeon.gen.rooms[1].get_center())
		dungeon.spawn_ground_torch(gp, 150.0, 180.0, true)
		cam.position = gp + Vector3(1.5, 1.6, 1.5)
		cam.look_at(gp)
		await _shot("ground_torch.png")

	# In prima persona, con la torcia accesa in mano.
	var player := (load("res://scenes/player.tscn") as PackedScene).instantiate() as Player
	add_child(player)
	player.global_position = dungeon.cell_to_world(dungeon.gen.start_cell) + Vector3.UP * 0.1
	player.inventory.add(Items.TORCH)
	player.inventory.select(Torches.light_spare(player.inventory))  # in mano: lo slot selezionato
	player.torch.refill()
	player.get_node("Head/Camera3D").make_current()
	await _shot("hand.png")
	get_tree().quit()


func _shot(file: String) -> void:
	for i in 60:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out + file)
	print("Salvato %s  (%d triangoli, %d draw call, %d FPS)" % [_out + file, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Engine.get_frames_per_second()])


## Modelli in file da `per_row`, sotto una luce direzionale; la camera inquadra tutto dall'alto.
func _gallery(cam: Camera3D, models: Array[StringName], per_row: int, file: String) -> void:
	var gallery := Node3D.new()
	add_child(gallery)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	gallery.add_child(sun)
	var width := 0.0
	var x := 0.0
	var z := 0.0
	for i in models.size():
		if i > 0 and i % per_row == 0:
			x = 0.0
			z -= 2.5
		var mi := Voxels.instance(models[i])
		var w := mi.mesh.get_aabb().size.x
		mi.position = Vector3(x + w / 2.0, 0, z)
		gallery.add_child(mi)
		x += w + 0.5
		width = maxf(width, x)
	var center := Vector3(width / 2.0, 0.5, z / 2.0)
	cam.position = center + Vector3(0, width * 0.3, width * 0.55)
	cam.look_at(center)
	cam.fov = 60
	await _shot(file)
	gallery.queue_free()


## Un modello da solo, visto di tre quarti da davanti (i nemici guardano verso +z), sotto una luce direzionale.
func _portrait(cam: Camera3D, model: StringName, file: String) -> void:
	var stage := Node3D.new()
	add_child(stage)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	sun.shadow_enabled = true
	stage.add_child(sun)
	var mi := Voxels.instance(model)
	stage.add_child(mi)
	var h := mi.mesh.get_aabb().size.y
	cam.position = Vector3(h * 0.5, h * 0.75, h * 1.1)
	cam.look_at(Vector3(0, h * 0.5, 0))
	await _shot(file)
	stage.queue_free()
