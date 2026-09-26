class_name Items
extends RefCounted
## Catalogo degli oggetti. Un oggetto è identificato da un id (StringName):
## inventario, generatore e scena di raccolta si scambiano solo questo.

const TORCH := &"torch"   ## torcia di scorta, da accendere quando la tua finisce
const FLINT := &"flint"   ## acciarino: serve per riaccendere una torcia spenta
const ROPE := &"rope"     ## corda: l'unico modo per risalire da una fossa (botola)
const SHIELD := &"shield"                   ## scudo: nell'inventario para 1 danno per colpo
const SHIELD_CRACKED := &"shield_cracked"   ## scudo che ha già parato un colpo: al prossimo si rompe
const BEAR_TRAP := &"bear_trap"             ## tagliola usa e getta: posata con Q, blocca un nemico per qualche secondo

const NAMES := {
	TORCH: "Torcia",
	FLINT: "Acciarino",
	ROPE: "Corda",
	SHIELD: "Scudo",
	SHIELD_CRACKED: "Scudo incrinato",
	BEAR_TRAP: "Tagliola",
}

const DESCRIPTIONS := {
	TORCH: "Una torcia di scorta. Quando la tua si consuma, accendila con l'acciarino o dalla fiamma di quella che hai in mano (Q).",
	FLINT: "Acciarino e selce. Selezionalo e premi Q per accendere una torcia al buio. Lo scatto si sente.",
	ROPE: "Una corda robusta. Se cadi in una fossa, E per legarla e risalire. Resta appesa: servirà a chi cade dopo di te.",
	SHIELD: "Uno scudo rotondo di legno cerchiato di ferro. Basta averlo con sé: para 1 danno di ogni colpo. Dopo due colpi si rompe.",
	SHIELD_CRACKED: "Lo scudo ha già parato un colpo ed è incrinato: para 1 danno ancora una volta, poi si rompe.",
	BEAR_TRAP: "Una tagliola di ferro. Selezionala e premi Q per posarla davanti ai piedi (fa rumore). Il Cieco non la vede: ci finisce dentro e resta bloccato 3 secondi, e lo scatto si sente lontano. Si usa una volta sola.",
}


static func display_name(id: StringName) -> String:
	return NAMES.get(id, String(id))


static func description(id: StringName) -> String:
	return DESCRIPTIONS.get(id, "")
