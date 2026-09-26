class_name Items
extends RefCounted
## Catalogo degli oggetti. Un oggetto è identificato da un id (StringName):
## inventario, generatore e scena di raccolta si scambiano solo questo.

const TORCH := &"torch"   ## torcia nuova, di scorta: da accendere quando la tua finisce
const TORCH_LIT := &"torch_lit"      ## torcia in uso, accesa: fa luce solo in mano (slot selezionato), vedi Torches
const TORCH_USED := &"torch_used"    ## torcia in uso spenta (F): non si consuma, l'acciarino la riaccende
const TORCH_BURNT := &"torch_burnt"  ## torcia consumata: legno bruciato, si può solo buttare (G)
const FLINT := &"flint"   ## acciarino: serve per riaccendere una torcia spenta
const ROPE := &"rope"     ## corda: l'unico modo per risalire da una fossa (botola)
const SHIELD := &"shield"                   ## scudo: nell'inventario para 1 danno per colpo
const SHIELD_CRACKED := &"shield_cracked"   ## scudo che ha già parato un colpo: al prossimo si rompe
const BEAR_TRAP := &"bear_trap"             ## tagliola usa e getta: posata con Q, blocca un nemico per qualche secondo

const NAMES := {
	TORCH: "Torcia",
	TORCH_LIT: "Torcia accesa",
	TORCH_USED: "Torcia spenta",
	TORCH_BURNT: "Legno bruciato",
	FLINT: "Acciarino",
	ROPE: "Corda",
	SHIELD: "Scudo",
	SHIELD_CRACKED: "Scudo incrinato",
	BEAR_TRAP: "Tagliola",
}

const DESCRIPTIONS := {
	TORCH: "Una torcia nuova, di scorta. Accendila con l'acciarino (selezionalo e premi Q) o dalla fiamma di quella che hai in mano (Q).",
	TORCH_LIT: "Fa luce solo finché la tieni in mano (slot selezionato). Se prendi un altro oggetto la riponi, ma continua a bruciare finché non si consuma. In mano: F la spegne, Q la butta a terra accesa e accende dalla sua fiamma una di scorta.",
	TORCH_USED: "Una torcia già usata, spenta: così non si consuma. Seleziona l'acciarino e premi Q per riaccenderla.",
	TORCH_BURNT: "Quel che resta di una torcia consumata: non fa più luce e non si riaccende. Occupa un posto: G per buttarlo.",
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


## Modello voxel dell'oggetto ("item_<id>"). Le torce in uso e il legno bruciato usano quello
## della torcia: fiamma e colore annerito li aggiunge chi li disegna (icone, torcia a terra).
static func model(id: StringName) -> StringName:
	if id in [TORCH_LIT, TORCH_USED, TORCH_BURNT]:
		return &"item_torch"
	return StringName("item_" + id)
