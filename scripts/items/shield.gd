class_name Shield
extends RefCounted
## Regole dello scudo, solo dati: basta averlo nell'inventario, para 1 danno di ogni colpo
## e dopo due colpi parati si rompe. Lo stato sta tutto nell'id dell'oggetto
## (Items.SHIELD → Items.SHIELD_CRACKED → sparito): lasciato a terra e ripreso resta com'era.

enum Result { NONE, CRACKED, BROKEN }  ## cosa è successo allo scudo parando

const BLOCK := 1  ## danni parati per colpo


## Para un colpo da `damage` punti: usa prima lo scudo incrinato (così un integro resta integro).
## Restituisce cosa è successo allo scudo; i danni parati sono BLOCK, se il risultato non è NONE.
static func absorb(inv: Inventory, damage: int) -> Result:
	if damage <= 0:
		return Result.NONE
	if inv.remove(Items.SHIELD_CRACKED):
		return Result.BROKEN
	if inv.replace(Items.SHIELD, Items.SHIELD_CRACKED):
		return Result.CRACKED
	return Result.NONE
