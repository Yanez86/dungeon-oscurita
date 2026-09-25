# Dungeon nell'oscurità

Dungeon crawler cooperativo 3D in **Godot 4.7 / GDScript**. Tema: oscurità, torce a consumo, nemici che sentono il rumore, combattimento raro e letale, voce di prossimità.
Game Design Document: https://claude.ai/code/artifact/3701c974-250d-4751-b4d3-a584451844aa

## Lingua e stile
- Rispondi in italiano, in modo conciso. Commenti e messaggi a schermo in italiano; nomi di variabili, funzioni e file in inglese.
- Lo sviluppatore conosce la programmazione di base ma è nuovo a Godot: quando introduci un concetto di Godot (nodi, segnali, autoload, MultiplayerSynchronizer…) spiegalo in una riga.

## Pilastri di design
Ogni funzionalità deve rafforzarne almeno uno:
1. La luce è vita (le torce si consumano)
2. Il suono è un rischio (tutto fa rumore, i nemici ascoltano)
3. Combattere è l'ultima spiaggia
4. Insieme o morti (coop)

## Regole di architettura (non violarle)
- **Tutto dal seed.** La generazione usa solo un `RandomNumberGenerator` con seed esplicito, mai `randi()`/`randf()` globali. Stesso seed = stesso piano (serve per bug report e coop).
- **Generatore = solo dati.** `DungeonGenerator` non crea nodi; il 3D lo fa `DungeonBuilder`.
- **Input separato.** `player.gd` non legge `Input`: usa le intenzioni di `PlayerInput`. In coop cambierà solo la sorgente.
- **Ogni suono passa da `NoiseBus.emit_noise(pos, loudness, source)`**, loudness 0–1. I nemici ascoltano solo lì.
- **Scene piccole**, una per entità. Valori da bilanciare come `@export`, non costanti sparse.
- Codice tipizzato (`: int`, `:=`); evita errori di inferenza su Variant.

## Struttura
```
scenes/              main.tscn, player.tscn, pickup.tscn
scripts/autoload/    game.gd (seed, piano, comandi), noise_bus.gd
scripts/dungeon/     dungeon_generator.gd (dati, anche posizione oggetti), dungeon_builder.gd (3D)
scripts/player/      player.gd, player_input.gd, torch.gd
scripts/items/       items.gd (catalogo id), inventory.gd (solo dati), pickup.gd (oggetto a terra)
scripts/ui/          hud.gd (slot e messaggi), debug_overlay.gd (F3)
tests/               test headless (generatore, inventario)
```
Nuovi comandi: aggiungili in `Game._setup_input()` e nella tabella del README.

## Comandi (Godot nel PATH come `godot`)
```
godot --headless --import                         # dopo aver aggiunto file o classi
godot --headless -s res://tests/test_generator.gd # test, esce con 1 se fallisce
godot --headless -s res://tests/test_inventory.gd
godot --headless --quit-after 120                 # avvio rapido per scovare errori di script
```
Dopo ogni modifica al codice: lancia test e avvio rapido e verifica che non ci siano `SCRIPT ERROR` o `Parse Error`. Per logica nuova e testabile senza grafica (inventario, IA, generazione) aggiungi un test in `tests/`.

## Flusso di lavoro
- Segui la roadmap del GDD (M3 fatta: torce raccoglibili e inventario; prossima M4: eventi rumore e primo nemico, il Cieco).
- Per funzionalità grandi proponi prima un piano.
- **Solo `main`, nessun branch** (regola fissa): lavora e fai commit direttamente su `main`, niente branch né pull request. Commit piccoli con messaggio in italiano (la CI esegue i test a ogni push).
- Incrementa `config/version` in `project.godot` quando si prepara una build per i tester; le build partono con un tag `vX.Y.Z`.
- Non modificare `.godot/` né `build/` (ignorate da git).
