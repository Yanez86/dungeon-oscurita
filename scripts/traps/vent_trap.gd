class_name VentTrap
extends Trap
## Soffio: una piastra in un corridoio dritto, con una grata in ciascuno dei due muri ai lati.
## Lo scatto è un clic; dopo warn_time dalle grate esce una folata sibilante che spegne la torcia a chi è
## nella cella o appena prima e dopo. Per riaccenderla serve l'acciarino, e lo scatto si sente (pilastro 1).
## Si riarma.

@export var reach := 1.6            ## metri dal centro della cella, lungo il corridoio, fin dove arriva la folata
@export var gust_loudness := 0.25
@export var grate_height := 1.2     ## altezza del centro delle grate (quella della torcia in mano)

var axis := Vector2i.RIGHT  ## direzione del corridoio (la imposta il builder): le grate stanno sui muri ai lati


func _init() -> void:
	warn_time = 0.4
	rearm_time = 3.0


func _ready() -> void:
	add_plate()
	var side := Vector3(axis.y, 0, axis.x)  # perpendicolare al corridoio
	for s: float in [1.0, -1.0]:
		var grate := Voxels.instance(&"trap_grate")
		var size := grate.mesh.get_aabb().size
		# Il retro della grata appoggia sulla faccia del muro (a mezza cella), il davanti guarda il corridoio.
		grate.position = side * s * (DungeonBuilder.CELL / 2.0 - size.z / 2.0) + Vector3.UP * (grate_height - size.y / 2.0)
		grate.rotation.y = atan2(-side.x * s, -side.z * s)
		add_child(grate)


func _spring() -> void:
	Sfx.play_at(self, &"vent_gust", global_position + Vector3.UP * grate_height)
	NoiseBus.emit_noise(global_position, gust_loudness, self)
	var along := Vector3(axis.x, 0, axis.y)
	for p in players():
		var local := to_local(p.global_position)
		if absf(local.dot(along)) > reach or not is_within(p, 1.0 + reach) or not p.torch.is_shining():
			continue  # la torcia riposta nello zaino non la raggiunge
		p.torch.extinguish()
		p.message.emit("Una folata dalle grate ti spegne la torcia!")
		p.note("Una folata da una grata mi ha spento la torcia.")
	_rearm_later()
