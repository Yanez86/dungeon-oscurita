class_name CageTrap
extends Trap
## Gabbia: una piastra e quattro catene che pendono dal soffitto, dal quale spuntano le punte delle sbarre.
## Lo scatto fa tintinnare le catene; dopo warn_time la gabbia crolla con un fracasso che i nemici sentono
## da lontano (pilastro 2). Chi è dentro resta chiuso `hold_time` secondi, poi un contrappeso la risolleva.
## Scatta una volta sola.

@export var hold_time := 15.0
@export var drop_time := 0.25
@export var lift_time := 2.5
@export var slam_loudness := 0.8
@export var lift_loudness := 0.3
@export var ceiling_height := 3.0

const PEEK := 0.15     ## metri di sbarre che spuntano dal soffitto quando è armata
const SIZE := 1.75     ## lato della gabbia (modello trap_cage)
const HEIGHT := 2.5
const BAR_T := 0.1     ## spessore delle pareti di collisione

var _cage := Node3D.new()


func _init() -> void:
	warn_time = 0.6
	trigger_sound = &"cage_rattle"
	trigger_loudness = 0.15


func _ready() -> void:
	add_plate()
	_cage.position.y = ceiling_height - PEEK
	add_child(_cage)
	_cage.add_child(Voxels.instance(&"trap_cage"))
	# Quattro pareti sottili: da dentro non si esce, da fuori non si entra. Quando è su stanno sopra le teste.
	var body := StaticBody3D.new()
	_cage.add_child(body)
	for i in 4:
		var along_x := i < 2
		var s := 1.0 if i % 2 == 0 else -1.0
		var shape := BoxShape3D.new()
		shape.size = Vector3(SIZE, HEIGHT, BAR_T) if along_x else Vector3(BAR_T, HEIGHT, SIZE)
		var col := CollisionShape3D.new()
		col.shape = shape
		col.position = Vector3(0, HEIGHT / 2.0, s * SIZE / 2.0) if along_x else Vector3(s * SIZE / 2.0, HEIGHT / 2.0, 0)
		body.add_child(col)
	for corner: Vector2 in [Vector2(1, 1), Vector2(1, -1), Vector2(-1, 1), Vector2(-1, -1)]:
		var chain := Voxels.instance(&"trap_chain")
		var h := chain.mesh.get_aabb().size.y
		chain.position = Vector3(corner.x * 0.75, ceiling_height - h, corner.y * 0.75)
		add_child(chain)


func _spring() -> void:
	var t := create_tween()
	t.tween_property(_cage, "position:y", 0.0, drop_time).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	t.tween_callback(_slam)
	t.tween_interval(hold_time)
	t.tween_callback(_start_lift)
	t.tween_property(_cage, "position:y", ceiling_height - PEEK, lift_time).set_trans(Tween.TRANS_SINE)


func _slam() -> void:
	Sfx.play_at(self, &"cage_slam", global_position + Vector3.UP)
	NoiseBus.emit_noise(global_position, slam_loudness, self)
	for p in players():
		if is_within(p, SIZE / 2.0):
			p.message.emit("La gabbia ti chiude dentro! Il fracasso si è sentito lontano…")
			p.note("Chiuso in una gabbia caduta dal soffitto.")


func _start_lift() -> void:
	Sfx.play_at(self, &"cage_lift", global_position + Vector3.UP * 2.0)
	NoiseBus.emit_noise(global_position, lift_loudness, self)
