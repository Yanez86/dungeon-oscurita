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
| Q | Accendere la torcia: al buio serve l'acciarino selezionato (riaccende quella già usata, se è finita ne accende una di scorta); con la torcia accesa ne accende una di scorta dalla fiamma |
| E | Raccogliere l'oggetto vicino / aprire o chiudere una porta (fa rumore) |
| 1–5 | Scegliere lo slot dell'inventario |
| G | Lasciare a terra l'oggetto selezionato (fa rumore) |
| M | Mostrare / nascondere la mappa (si disegna solo ciò che la torcia illumina) |
| R | Nuova partita |
| F3 | Debug |
| F4 | Filtro retro PS1 on/off |
| Esc | Libera il mouse |

Il cerchio blu è l'uscita: porta al piano successivo.
Alcuni corridoi sono chiusi da porte (bloccano anche la luce) che si possono richiudere alle spalle; in certi piani ci sono torce appese ai muri, che non si consumano.
Ogni piano inizia in una piccola stanza illuminata da torce a muro, con una torcia a terra. Si parte a mani vuote, con solo un acciarino: raccogli la torcia (E) e accendila (Q). Le altre torce vanno cercate nelle stanze e diventano più rare scendendo. L'inventario ha 5 slot e si conserva tra un piano e l'altro.

## Struttura

```
scenes/            scene (.tscn)
scripts/
  autoload/        Game (stato, comandi), NoiseBus (eventi rumore)
  dungeon/         generatore (solo dati) e costruttore 3D
  player/          movimento, input separato, torcia
  items/           catalogo oggetti, inventario (solo dati), oggetti a terra
  ui/              HUD minimo, overlay di debug
tests/             test automatici
assets/            modelli, audio, texture
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
```

## Build per i tester

Crea un tag (`git tag v0.1.1 && git push --tags`): GitHub Actions compila Windows e Linux.
Per caricare anche su itch.io, in GitHub > Settings > Secrets and variables > Actions aggiungi:
- segreto `BUTLER_API_KEY` (da itch.io > Settings > API keys)
- variabile `ITCH_GAME` (es. `tuonome/dungeon-oscurita`)

## Seed di un bug

Nel nodo `Main` imposta `fixed_seed` al seed della segnalazione: il gioco rigenera lo stesso dungeon.

## Crediti

- Modelli 3D: [KayKit – Dungeon Remastered](https://kaylousberg.itch.io/kaykit-dungeon-remastered) di Kay Lousberg (www.kaylousberg.com), licenza CC0. In `assets/models/kaykit/` ci sono solo i `.glb` e la texture condivisa; l'import non estrae le texture (tutti i pezzi usano `dungeon_texture.png`). Nel codice si caricano con `KayKit.mesh()` o `KayKit.instance()`.
