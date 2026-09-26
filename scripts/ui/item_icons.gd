class_name ItemIcons
extends Node
## Icone degli oggetti: la versione in miniatura del loro modello voxel ("item_<id>"),
## fotografata una volta sola e poi riusata da barra dell'inventario e menu.
## Ogni icona ha un SubViewport: uno "schermo" nascosto che disegna una scena 3D
## in una texture. Con own_world_3d ha un mondo tutto suo: non vede il dungeon.
## Un oggetto nuovo non ha bisogno di un'icona disegnata a mano: basta il suo .vox.

@export var icon_px := 48          ## risoluzione dell'icona (la si ingrandisce a pixel netti)
@export var view_pitch := -30.0    ## gradi: la camera guarda un po' dall'alto
@export var flat_pitch := -60.0    ## gradi: gli oggetti bassi e piatti (acciarino) si guardano più dall'alto
@export var view_yaw := 35.0       ## gradi: vista di tre quarti
@export var tall_tilt := -40.0     ## gradi: gli oggetti lunghi (torcia) si inclinano in diagonale
@export var frame_margin := 0.04   ## spazio attorno al modello (frazione): quanto basta per il bordino
@export var ambient := 1.0
@export var light_energy := 1.6

var _icons: Dictionary[StringName, Texture2D] = {}


## Texture dell'icona di un oggetto (null per uno slot vuoto).
func icon(id: StringName) -> Texture2D:
	if id == &"":
		return null
	if not _icons.has(id):
		_icons[id] = _render(id)
	return _icons[id]


## Mette il modello al centro, lo inquadra con una camera ortogonale e lo disegna una volta.
func _render(id: StringName) -> Texture2D:
	var vp := SubViewport.new()
	vp.size = Vector2i(icon_px, icon_px)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE  # l'oggetto non si muove: basta una foto
	add_child(vp)

	var model := Voxels.instance(StringName("item_" + id))
	var aabb := model.mesh.get_aabb()
	model.position = -aabb.get_center()
	var pivot := Node3D.new()
	if aabb.size.y > maxf(aabb.size.x, aabb.size.z) * 1.5:
		pivot.rotation.z = deg_to_rad(tall_tilt)
	pivot.add_child(model)
	vp.add_child(pivot)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	var flat := aabb.size.y < maxf(aabb.size.x, aabb.size.z) * 0.5
	var pitch := flat_pitch if flat else view_pitch
	cam.basis = Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(view_yaw), 0.0))
	cam.position = cam.basis.z * 4.0
	cam.near = 0.05
	cam.far = 10.0
	cam.size = _fit(aabb, pivot.basis, cam.basis) * (1.0 + frame_margin * 2.0)
	cam.environment = _environment()
	vp.add_child(cam)
	cam.current = true

	var sun := DirectionalLight3D.new()
	sun.basis = Basis.from_euler(Vector3(deg_to_rad(-50.0), deg_to_rad(view_yaw - 40.0), 0.0))
	sun.light_energy = light_energy
	vp.add_child(sun)
	return vp.get_texture()


## Lato del quadrato che contiene il modello visto dalla camera. Il modello è
## centrato nell'origine, quindi i suoi spigoli proiettati sono simmetrici.
func _fit(aabb: AABB, pose: Basis, view: Basis) -> float:
	var half := 0.0
	for i in 8:
		var p := pose * (aabb.get_endpoint(i) - aabb.get_center())
		half = maxf(half, maxf(absf(p.dot(view.x)), absf(p.dot(view.y))))
	return half * 2.0


## Sfondo trasparente e luce ambientale piena: l'icona si legge anche se il dungeon è buio.
func _environment() -> Environment:
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = ambient
	return env
