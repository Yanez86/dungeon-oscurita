extends Node
## Screenshot di controllo dei modelli voxel (serve la grafica: niente --headless).
##   godot res://tools/voxel_preview.tscn -- <cartella_output> [seed]
## Salva gallery.png (tutti i modelli), room.png (stanza d'ingresso) e door.png (una porta).

const MODELS: Array[StringName] = [&"floor_stone_a", &"floor_stone_cracked", &"floor_stone_moss", &"floor_dirt_a",
	&"ceiling", &"wall_a", &"wall_cracked", &"wall_shelves", &"pillar", &"door_frame", &"door_leaf"]

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

	# Galleria: modelli in fila sotto una luce direzionale.
	var gallery := Node3D.new()
	add_child(gallery)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	gallery.add_child(sun)
	var x := 0.0
	for m in MODELS:
		var mi := Voxels.instance(m)
		var w := mi.mesh.get_aabb().size.x
		mi.position = Vector3(x + w / 2.0, 0, 0)
		gallery.add_child(mi)
		x += w + 0.5
	cam.position = Vector3(x / 2.0, 3.5, 11.0)
	cam.look_at(Vector3(x / 2.0, 1.0, 0))
	cam.fov = 60
	await _shot("gallery.png")
	gallery.queue_free()

	# Dungeon: la stanza d'ingresso e una porta, illuminate da una "torcia" sulla camera.
	var dungeon := DungeonBuilder.new()
	add_child(dungeon)
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
	get_tree().quit()


func _shot(file: String) -> void:
	for i in 60:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(_out + file)
	print("Salvato %s  (%d triangoli, %d draw call, %d FPS)" % [_out + file, Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Engine.get_frames_per_second()])
