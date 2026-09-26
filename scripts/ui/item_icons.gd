class_name ItemIcons
extends Node
## Icone degli oggetti: la versione in miniatura del loro modello voxel ("item_<id>"),
## fotografata una volta sola e poi riusata da barra dell'inventario e menu.
## Ogni icona ha un SubViewport: uno "schermo" nascosto che disegna una scena 3D
## in una texture. Con own_world_3d ha un mondo tutto suo: non vede il dungeon.
## Un oggetto nuovo non ha bisogno di un'icona disegnata a mano: basta il suo .vox.
## Le torce in uso e il legno bruciato riusano il modello della torcia (Items.model): cambiano fiamma e colore.

@export var icon_px := 48          ## risoluzione dell'icona (la si ingrandisce a pixel netti)
@export var view_pitch := -30.0    ## gradi: la camera guarda un po' dall'alto
@export var flat_pitch := -60.0    ## gradi: gli oggetti bassi e piatti (acciarino) si guardano più dall'alto
@export var view_yaw := 35.0       ## gradi: vista di tre quarti
@export var tall_tilt := -40.0     ## gradi: gli oggetti lunghi (torcia) si inclinano in diagonale
@export var frame_margin := 0.04   ## spazio attorno al modello (frazione): quanto basta per il bordino
@export var ambient := 1.0
@export var light_energy := 1.6
@export_group("Torce")
@export var flame_base := Vector3(2.0, 2.0, 2.0)  ## voxel: la fiammella in cima alla torcia accesa, larga sotto…
@export var flame_tip := Vector3(1.0, 2.0, 1.0)   ## …e a punta sopra
@export var flame_color := Color(1.0, 0.78, 0.35)
@export var flame_tip_color := Color(1.0, 0.5, 0.15)
@export var used_tint := Color(0.7, 0.66, 0.62)   ## torcia spenta: un po' annerita dall'uso
@export var burnt_tint := Color(0.3, 0.26, 0.23)  ## legno bruciato, come il moncone a terra (GroundTorch)

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

	var model := Voxels.instance(Items.model(id))
	var aabb := _dress_torch(id, model)
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


## Le torce hanno tutte lo stesso modello: quella accesa ha la fiammella in cima, spenta e
## bruciata sono più scure. Restituisce l'ingombro del modello, fiamma compresa, per inquadrarlo.
func _dress_torch(id: StringName, model: MeshInstance3D) -> AABB:
	var aabb := model.mesh.get_aabb()
	if id == Items.TORCH_USED or id == Items.TORCH_BURNT:
		var tinted := (model.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
		tinted.albedo_color = used_tint if id == Items.TORCH_USED else burnt_tint
		model.material_override = tinted
	elif id == Items.TORCH_LIT:
		var v := Voxels.ITEM_VOXEL_SIZE
		var bottom := aabb.end.y - v  # affonda un voxel nella testa
		for part: Array in [[flame_base, flame_color], [flame_tip, flame_tip_color]]:
			var size: Vector3 = part[0] * v
			var flame := _flame_box(size, part[1])
			flame.position = Vector3(aabb.get_center().x, bottom + size.y / 2.0, aabb.get_center().z)
			model.add_child(flame)
			aabb = aabb.merge(AABB(flame.position - size / 2.0, size))
			bottom += size.y
	return aabb


func _flame_box(size: Vector3, color: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED  # la fiamma è luce: niente ombre
	mat.albedo_color = color
	box.material = mat
	var flame := MeshInstance3D.new()
	flame.mesh = box
	return flame


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
