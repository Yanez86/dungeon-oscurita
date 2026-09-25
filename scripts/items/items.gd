class_name Items
extends RefCounted
## Catalogo degli oggetti. Un oggetto è identificato da un id (StringName):
## inventario, generatore e scena di raccolta si scambiano solo questo.

const TORCH := &"torch"   ## torcia di scorta, da accendere quando la tua finisce
const FLINT := &"flint"   ## acciarino: serve per riaccendere una torcia spenta

const NAMES := {
	TORCH: "Torcia",
	FLINT: "Acciarino",
}


static func display_name(id: StringName) -> String:
	return NAMES.get(id, String(id))
