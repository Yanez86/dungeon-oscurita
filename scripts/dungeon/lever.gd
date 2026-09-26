class_name Lever
extends Node3D
## Leva murata (modelli lever_plate e lever_handle): E la tira. Comanda un cancello, su e giù quante volte
## vuoi, oppure disattiva una trappola per sempre (`one_shot`: resta giù). Chi comanda cosa lo decidono
## il generatore e TrapLayout; il builder collega `pulled` al cancello o alla trappola.
## Tirarla fa rumore: il clang del ferro si sente, e i nemici lo sentono.
## L'origine è sulla faccia del muro, a terra; +z verso chi la guarda.

## È stata tirata: `down` vero se ora è abbassata.
signal pulled(down: bool)

@export var one_shot := false        ## trappole: una volta giù resta giù
@export var plate_height := 1.0      ## metri da terra del fondo della piastra
@export var wall_gap := 0.07        ## metri tra la faccia del muro e la piastra: i mattoni sporgono un po'
@export var swing := 0.6             ## radianti di inclinazione della maniglia, su e giù
@export var pull_time := 0.25        ## secondi per abbassarla o alzarla
@export var pull_loudness := 0.3

var is_down := false

var _pivot := Node3D.new()
var _tween: Tween


func _ready() -> void:
	add_to_group("lever")
	var plate := Voxels.instance(&"lever_plate")
	var size := plate.mesh.get_aabb().size
	plate.position = Vector3(0.0, plate_height, wall_gap + size.z / 2.0)  # il retro appoggiato ai mattoni
	add_child(plate)
	_pivot.position = Vector3(0.0, plate_height + size.y / 2.0, wall_gap + size.z)  # il perno al centro della piastra
	_pivot.rotation.x = swing  # su: la maniglia punta in alto, verso chi guarda
	add_child(_pivot)
	_pivot.add_child(Voxels.instance(&"lever_handle"))


## Cosa suggerisce l'HUD quando il giocatore è a portata ("" = niente).
func prompt() -> String:
	if one_shot and is_down:
		return ""
	return "E  alza la leva" if is_down else "E  tira la leva"


## E sulla leva. Falso se era una leva da trappola già tirata (bloccata giù).
func pull(who: Node3D) -> bool:
	if one_shot and is_down:
		var p := who as Player
		if p:
			p.message.emit("La leva è bloccata giù.")
		return false
	is_down = not is_down
	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_pivot, "rotation:x", PI - swing if is_down else swing, pull_time) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	Sfx.play_at(self, &"lever_pull", _pivot.global_position)
	NoiseBus.emit_noise(global_position, pull_loudness, who)
	pulled.emit(is_down)
	return true
