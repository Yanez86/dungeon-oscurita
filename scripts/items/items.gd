class_name Items
extends RefCounted
## Catalogo degli oggetti. Un oggetto è identificato da un id (StringName):
## inventario, generatore e scena di raccolta si scambiano solo questo.

const TORCH := &"torch"   ## torcia di scorta, da accendere quando la tua finisce
const FLINT := &"flint"   ## acciarino: serve per riaccendere una torcia spenta
const ROPE := &"rope"     ## corda: l'unico modo per risalire da una fossa (botola)

const NAMES := {
	TORCH: "Torcia",
	FLINT: "Acciarino",
	ROPE: "Corda",
}

const DESCRIPTIONS := {
	TORCH: "Una torcia di scorta. Quando la tua si consuma, accendila con l'acciarino o dalla fiamma di quella che hai in mano (Q).",
	FLINT: "Acciarino e selce. Selezionalo e premi Q per accendere una torcia al buio. Lo scatto si sente.",
	ROPE: "Una corda robusta. Se cadi in una fossa, E per legarla e risalire. Resta appesa: servirà a chi cade dopo di te.",
}


static func display_name(id: StringName) -> String:
	return NAMES.get(id, String(id))


static func description(id: StringName) -> String:
	return DESCRIPTIONS.get(id, "")
