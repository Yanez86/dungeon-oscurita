# Dungeon nell'oscurità

Dungeon crawler cooperativo in 3D: torce che si consumano, mostri che sentono tutto, combattimento come ultima spiaggia.

**Motore:** Godot 4.7 · **Stato:** prototipo (M0–M3)

## Avvio

1. Installa [Godot 4.7](https://godotengine.org/download) (versione standard, non .NET).
2. Godot > Importa > seleziona `project.godot`.
3. F5 per giocare.

## Comandi

| Tasto | Azione |
| --- | --- |
| WASD + mouse | Muoversi / guardarsi intorno |
| Shift | Correre (più rumore) |
| Ctrl o C | Accovacciarsi (meno rumore) |
| F | Spegnere la torcia |
| Q | Accendere la torcia: al buio serve l'acciarino selezionato (riaccende quella già usata, se è finita ne accende una di scorta). Con la torcia accesa la butta a terra (fa rumore), dove continua a bruciare, e se ne hai una di scorta la accende dalla sua fiamma |
| E | Raccogliere l'oggetto vicino (una torcia buttata torna in mano) / aprire o chiudere una porta (fa rumore) |
| 1–5 | Scegliere lo slot dell'inventario |
| G | Lasciare a terra l'oggetto selezionato (fa rumore) |
| M | Mostrare / nascondere la mappa (si disegna solo ciò che la torcia illumina) |
| R | Nuova partita |
| F3 | Debug (anche lo stato di ogni Cieco e la sua distanza) |
| F4 | Filtro retro PS1 on/off |
| F6 / F7 | Solo build di debug: togliere / ridare un punto di energia |
| Tab | Menu: scheda del giocatore (energia, torcia, rumore dei passi). Il gioco non si ferma: la torcia continua a bruciare |
| I | Menu: inventario (clic su uno slot per selezionarlo, pulsante per lasciarlo a terra) |
| J | Menu: diario (cosa è successo, piano per piano) |
| Esc | Menu: impostazioni (sensibilità del mouse, volume, filtro PS1, schermo intero; si salvano da sole). Libera il mouse; se il menu è aperto lo chiude |

Il cerchio blu è l'uscita: porta al piano successivo.
Alcuni corridoi sono chiusi da porte (bloccano anche la luce) che si possono richiudere alle spalle; in certi piani ci sono torce appese ai muri, che non si consumano.
Ogni piano inizia in una piccola stanza illuminata da torce a muro, con una torcia a terra. Si parte a mani vuote, con solo un acciarino: raccogli la torcia (E) e accendila (Q). Le altre torce vanno cercate nelle stanze e diventano più rare scendendo. L'inventario ha 5 slot e si conserva tra un piano e l'altro.
Una torcia buttata a terra con Q resta accesa e fa luce finché ha combustibile: con E la riprendi in mano (se ne tieni già una, si scambiano); consumata, resta un moncone annerito che non si può più raccogliere.
In alto a sinistra la barra dell'energia (10 punti: pochi colpi bastano) e, sotto, il riquadro della torcia accesa; in basso gli slot dell'inventario con le icone degli oggetti.
L'energia non si recupera e passa da un piano all'altro. A zero si muore: la partita finisce con una schermata che riassume piano, tempo, causa e seed; R ne avvia una nuova.
**Il Cieco** (un Cieco al piano 1, uno in più ogni due piani, fino a 4) sente soltanto. Vaga lento e respira forte: al buio lo senti prima di vederlo. Se sente un rumore corre dove l'ha sentito (4,5 m/s: camminando non gli scappi, correndo sì), annusa qualche secondo e se ne va. Non ti insegue: va sempre verso l'ultimo rumore, quindi fermarsi o accucciarsi (i passi accucciati si sentono solo entro 2 m) lo lascia a mani vuote. Il suono segue i corridoi e le porte chiuse lo attutiscono. Le porte non le apre: se il rumore viene da dietro una porta chiusa gratta per qualche secondo e rinuncia; una porta non si chiude se nel vano c'è qualcuno. Se ti tocca ti toglie 3 punti di energia e si ritrae per 2 secondi: è il momento di allontanarsi in silenzio.
**Scudo** (a volte a terra in un piano): basta averlo nell'inventario, para 1 danno di ogni colpo. Al primo colpo diventa "scudo incrinato", al secondo si rompe. Lo stato si vede nella scheda del giocatore (Tab).
Il menu (Tab, I, J, Esc) è un prototipo con quattro schede: scheda del giocatore, inventario, diario (si scrive da solo: piani, oggetti raccolti e lasciati, torce accese e consumate) e impostazioni. Col menu aperto il personaggio sta fermo ma il tempo scorre: in coop non si può mettere in pausa.
Gli oggetti a terra hanno un'aura (bordo luminoso e alone sul pavimento) che si vede solo quando la luce li raggiunge o quando ci passi accanto.

## Struttura

```
scenes/            scene (.tscn)
scripts/
  autoload/        Game (stato, comandi), NoiseBus (eventi rumore), Settings (impostazioni salvate)
  dungeon/         generatore (solo dati), costruttore 3D, mappa dei passaggi per i nemici
  enemies/         il Cieco: corpo (blind.gd) e cervello a stati (blind_brain.gd, solo dati)
  voxel/           file .vox di MagicaVoxel e loro conversione in mesh
  player/          movimento, input separato, torcia
  items/           catalogo oggetti, inventario (solo dati), oggetti a terra
  ui/              HUD minimo, menu (ui/menu/), overlay di debug
tests/             test automatici
tools/             generatore dei modelli voxel e anteprima
assets/            modelli (voxel/ in .vox), suoni (audio/ in .ogg), texture
```

## Regole del progetto

- **Tutto dal seed.** La generazione usa solo il seed: stesso seed, stesso piano. Serve per bug e coop.
- **Input separato.** `player.gd` non legge la tastiera, usa `PlayerInput`. In coop cambierà solo la sorgente.
- **Ogni suono passa da `NoiseBus`.** Passi, voce, oggetti: i nemici ascoltano solo lì.
- **Scene piccole.** Un file per cosa, così due persone non modificano la stessa scena.
- **Pull request** per ogni modifica; i test partono da soli.

## Test

```
godot --headless -s res://tests/test_generator.gd
godot --headless -s res://tests/test_inventory.gd
godot --headless -s res://tests/test_voxel.gd
godot --headless -s res://tests/test_ground_torch.gd
godot --headless -s res://tests/test_health.gd
godot --headless -s res://tests/test_journal.gd
godot --headless -s res://tests/test_settings.gd
godot --headless -s res://tests/test_blind.gd
```

## Build per i tester

Crea un tag (`git tag v0.1.1 && git push --tags`): GitHub Actions compila Windows e Linux.
Per caricare anche su itch.io, in GitHub > Settings > Secrets and variables > Actions aggiungi:
- segreto `BUTLER_API_KEY` (da itch.io > Settings > API keys)
- variabile `ITCH_GAME` (es. `tuonome/dungeon-oscurita`)

## Seed di un bug

Nel nodo `Main` imposta `fixed_seed` al seed della segnalazione: il gioco rigenera lo stesso dungeon.

## Crediti

- Tutti i modelli sono voxel creati per il gioco (`assets/voxels/`, generati da `tools/make_voxels.gd`): nessun asset di terzi.
- Suoni: pacchetti [RPG Audio](https://kenney.nl/assets/rpg-audio), [Impact Sounds](https://kenney.nl/assets/impact-sounds) e [Sci-fi Sounds](https://kenney.nl/assets/sci-fi-sounds) di [Kenney](https://kenney.nl), licenza CC0 (`assets/audio/LICENSE-kenney.txt`). Ogni file ha il nome del suo ruolo nel gioco (es. `blind_step_1.ogg`, `door_open.ogg`): per cambiare un suono basta sovrascrivere il file. Respiro e verso del Cieco sono provvisori (Kenney non ha versi di creature).

## Grafica voxel

Tutta la grafica (muri, pavimenti, soffitto, pilastri, porte, arredi, torce a muro, oggetti e torcia in mano) è fatta di modelli voxel in `assets/voxels/` (formato `.vox` di [MagicaVoxel](https://ephtracy.github.io/)). Scala: 1 voxel = 12,5 cm, quindi una cella da 2 m è larga 16 voxel e un muro è alto 24.
Il gioco legge i `.vox` all'avvio e li trasforma in mesh (`Voxels.mesh()` / `Voxels.instance()`): basta modificarli in MagicaVoxel, salvare e riavviare.

- `godot --headless -s res://tools/make_voxels.gd` rigenera i modelli di base dal seed (**sovrascrive** i `.vox`: se ne hai ritoccato uno, toglilo prima dall'elenco nello script).
- `godot res://tools/voxel_preview.tscn -- <cartella> [seed]` salva gli screenshot di controllo (galleria dei modelli e degli arredi, stanza d'ingresso, una porta, un arredo, oggetti a terra, prima persona con la torcia).

Regole dei modelli: origine al centro in x e z, base in basso. Gli oggetti che si raccolgono si chiamano `item_<id>` (es. `item_torch`, `item_flint`) e usano voxel da 6,25 cm, metà di quelli del mondo: per un oggetto nuovo basta il suo `.vox`. Gli stessi voxel piccoli valgono per le trappole piazzate (`trap_*`) e i nemici (`enemy_*`, guardano verso +z). Nei muri (16×26×8: 24 di parete più 2 di fondazione sotto il pavimento) la parete occupa la metà posteriore e la faccia a vista sta a metà profondità; ciò che sporge (mensole, mattoni) va nella metà anteriore. La torcia a muro segue la stessa convenzione. Le misure che il gioco si aspetta sono controllate in `tests/test_voxel.gd`.
