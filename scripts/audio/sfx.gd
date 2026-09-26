class_name Sfx
extends RefCounted
## Suoni del gioco: file .ogg in assets/audio/, un nome fisso per ogni ruolo (door_open, blind_step…).
## Per cambiare un suono basta sovrascrivere il suo file: il codice non cambia.
## Servono solo alle orecchie del giocatore: i nemici ascoltano NoiseBus, non questi suoni.

const DIR := "res://assets/audio/"

static var _cache: Dictionary[StringName, AudioStream] = {}


## Il suono `sound`: il file <sound>.ogg oppure, se ci sono varianti numerate (<sound>_1, <sound>_2…),
## un AudioStreamRandomizer, una risorsa di Godot che a ogni riproduzione sceglie una variante a caso
## e ne varia un po' l'altezza. Null (con un avviso) se il suono non c'è.
static func stream(sound: StringName) -> AudioStream:
	if not _cache.has(sound):
		_cache[sound] = _load(sound)
	return _cache[sound]


## Un suono singolo in un punto del mondo. Il riproduttore si elimina da solo quando ha finito,
## quindi `parent` deve restare in scena almeno per la durata del suono.
static func play_at(parent: Node, sound: StringName, pos: Vector3, volume_db := 0.0, pitch := 1.0) -> void:
	var s := stream(sound)
	if s == null or not parent.is_inside_tree():
		return
	var p := player_3d()
	p.stream = s
	p.volume_db = volume_db
	p.pitch_scale = pitch
	p.finished.connect(p.queue_free)
	parent.add_child(p)
	p.global_position = pos
	p.play()


## AudioStreamPlayer3D (una sorgente sonora posizionata nel mondo: più forte da vicino)
## con le impostazioni del gioco: si sente bene entro pochi metri e sparisce oltre `max_distance`.
static func player_3d(max_distance := 25.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.unit_size = 3.0
	p.max_distance = max_distance
	return p


static func _load(sound: StringName) -> AudioStream:
	var single := "%s%s.ogg" % [DIR, sound]
	if ResourceLoader.exists(single):
		return load(single) as AudioStream
	var random := AudioStreamRandomizer.new()
	random.random_pitch = 1.08
	var i := 1
	while ResourceLoader.exists("%s%s_%d.ogg" % [DIR, sound, i]):
		random.add_stream(-1, load("%s%s_%d.ogg" % [DIR, sound, i]) as AudioStream)
		i += 1
	if i == 1:
		push_warning("Sfx: manca il suono %s in %s" % [sound, DIR])
		return null
	return random
