class_name SpikeTrap
extends Trap
## Frecce dal pavimento: una piastra al centro di una cella di pietra piena di forellini (floor_spikes,
## lo mette il builder; nei corridoi di terra battuta spicca ancora di più). Lo scatto è un clic quasi muto;
## dopo warn_time le frecce escono dai fori e poi rientrano, senza un rumore. Chi è sulla cella in quel
## momento viene ferito, e lui sì che grida (vedi Player.hurt). Poi la trappola si riarma.

@export var damage := 3
@export var up_time := 1.0       ## secondi con le frecce fuori
@export var rise_time := 0.06
@export var retract_time := 0.4
@export var cause := "le frecce del pavimento"

const HIDDEN_Y := -0.45  ## punte appena sotto la superficie: nei fori si intravede il ferro
const RAISED_Y := -0.05

var _spikes: MeshInstance3D
var _up := false
var _hit: Array[Player] = []  ## già feriti in questo scatto


func _init() -> void:
	rearm_time = 1.5


func _ready() -> void:
	add_plate()
	_spikes = Voxels.instance(&"trap_spikes")
	_spikes.position.y = HIDDEN_Y
	add_child(_spikes)


func _physics_process(delta: float) -> void:
	super(delta)
	if not _up:
		return
	for p in players():
		if not _hit.has(p) and is_within(p, 0.95):
			_hit.append(p)
			if p.hurt(damage, cause) > 0:
				p.message.emit("Frecce dal pavimento! Guarda dove metti i piedi.")


func _spring() -> void:
	_hit.clear()
	var t := create_tween()
	t.tween_property(_spikes, "position:y", RAISED_Y, rise_time)
	t.tween_callback(func() -> void: _up = true)
	t.tween_interval(up_time)
	t.tween_callback(func() -> void: _up = false)
	t.tween_property(_spikes, "position:y", HIDDEN_Y, retract_time)
	t.tween_callback(_rearm_later)
