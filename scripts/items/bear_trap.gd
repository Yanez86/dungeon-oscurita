class_name BearTrap
extends Node3D
## Tagliola posata dal giocatore (Q con la tagliola selezionata). Si arma dopo un attimo;
## il primo nemico che ci passa sopra resta bloccato `hold_time` secondi, e lo scatto fa molto rumore.
## Usa e getta: scattata resta a terra chiusa e non si raccoglie più.
## Per ora scatta solo sui nemici: i giocatori ci passano sopra.

@export var hold_time := 3.0        ## secondi in cui tiene fermo il nemico
@export var arm_delay := 1.0        ## secondi prima che si armi (il tempo di togliere la mano)
@export var trigger_radius := 0.45  ## metri dal centro: chi ci entra la fa scattare
@export var snap_loudness := 0.8    ## lo scatto si sente lontano e richiama altri nemici

var armed := false
var sprung := false

var _model: MeshInstance3D
var _area := Area3D.new()  ## un'area che segnala quando un corpo ci entra (body_entered)


func _ready() -> void:
	add_to_group("bear_trap")
	_model = Voxels.instance(&"trap_bear_open")
	add_child(_model)
	var shape := CylinderShape3D.new()
	shape.radius = trigger_radius
	shape.height = 1.0
	var col := CollisionShape3D.new()
	col.shape = shape
	col.position.y = 0.5
	_area.add_child(col)
	add_child(_area)
	_area.body_entered.connect(_on_body_entered)
	get_tree().create_timer(arm_delay).timeout.connect(_arm)


## Armata: se nel frattempo qualcuno ci è già sopra, scatta subito.
func _arm() -> void:
	armed = true
	for body in _area.get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node3D) -> void:
	var enemy := body as Blind
	if not armed or sprung or enemy == null:
		return
	sprung = true
	enemy.trap(global_position, hold_time)
	_model.mesh = Voxels.mesh(&"item_bear_trap")  # le ganasce si chiudono
	Sfx.play_at(self, &"trap_snap", global_position + Vector3.UP * 0.2, 4.0)
	NoiseBus.emit_noise(global_position, snap_loudness, self)
