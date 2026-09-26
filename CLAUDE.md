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
scenes/              main.tscn, player.tscn, pickup.tscn, ground_torch.tscn, door.tscn, wall_torch.tscn, blind.tscn, bear_trap.tscn, una scena per trappola (spike_trap, vent_trap, cage_trap, trapdoor, boulder_trap)
scripts/autoload/    game.gd (seed, piano, tempo, comandi), noise_bus.gd, settings.gd (impostazioni salvate in user://settings.cfg)
scripts/dungeon/     dungeon_generator.gd (dati: stanze, oggetti, porte, torce a muro, arredi, nemici), dungeon_builder.gd (3D), dungeon_nav.gd (percorsi e distanza dei rumori per i nemici, solo dati), trap_layout.gd (dove stanno trappole, porte trappola e corde; solo dati, RNG proprio dal seed), door.gd (anche porte a dardi e coi campanelli), wall_torch.gd
scripts/traps/       trap.gd (base: innesco visibile, scatto udibile, effetto dopo warn_time), spike_trap.gd, vent_trap.gd, cage_trap.gd, trapdoor.gd (fossa e corda), boulder_trap.gd
scripts/enemies/     blind.gd (il Cieco: corpo, movimento, suoni), blind_brain.gd (le sue decisioni, solo dati)
scripts/voxel/       vox_model.gd (file .vox di MagicaVoxel), voxel_mesher.gd (voxel -> mesh), voxels.gd (caricamento modelli)
assets/voxels/       tutti i modelli del gioco in .vox: muri, pavimenti, porte, arredi, torce a muro (1 voxel = 0.125 m)
scripts/audio/       sfx.gd (suoni per nome: <nome>.ogg o varianti <nome>_1, _2…)
assets/audio/        suoni .ogg di Kenney (CC0), un nome fisso per ruolo: per cambiarne uno si sovrascrive il file
tools/               make_voxels.gd (genera i .vox dal seed), voxel_preview.tscn (screenshot di controllo)
scripts/player/      player.gd, player_input.gd, torch.gd, health.gd (energia, solo dati), journal.gd (diario, solo dati)
scripts/items/       items.gd (catalogo id), inventory.gd (solo dati), pickup.gd (oggetto a terra), ground_torch.gd (torcia usata buttata a terra, brucia da sola), shield.gd (regole dello scudo, solo dati), torches.gd (torce nell'inventario: nuova, in uso, legno bruciato; solo dati), bear_trap.gd (tagliola posata)
scripts/ui/          hud.gd (slot e messaggi), item_icons.gd (icone = miniature 3D dei modelli item_*), item_slot.gd, health_bar.gd + pips.gd (barra dell'energia), ui_theme.gd (stile dei menu), end_screen.gd (fine partita: morte o uscita), debug_overlay.gd (F3, F6/F7), psx_filter.gd (filtro retro, F4)
scripts/ui/menu/     game_menu.gd (menu a schede: Tab, I, J, Esc) + una pagina per scheda (menu_page.gd è la base)
shaders/             psx_post.gdshader (post-processing retro PS1), pickup_glow.gdshader (aura degli oggetti a terra), icon_outline.gdshader (bordino delle icone)
tests/               test headless (generatore, inventario, voxel, mappa esplorata, torcia a terra, energia, diario, impostazioni, Cieco, trappole)
```
Nuovi comandi: aggiungili in `Game._setup_input()` e nella tabella del README.

## Comandi
Godot **non** è nel PATH. Per i comandi da terminale usa la versione console, che stampa l'output e restituisce il codice d'uscita:
`C:\Godot\Godot_v4.7.2-stable_win64_console.exe` (in Git Bash: `/c/Godot/Godot_v4.7.2-stable_win64_console.exe`). Qui sotto `godot` sta per questo percorso.
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
