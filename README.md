# Dungeon nell'oscurità

Dungeon crawler cooperativo in 3D: torce che si consumano, mostri che sentono tutto, combattimento come ultima spiaggia.

**Motore:** Godot 4.7 · **Stato:** prototipo (M0–M2)

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
| F | Accendere/spegnere la torcia |
| R | Nuova partita |
| F3 | Debug |
| Esc | Libera il mouse |

Il cerchio blu è l'uscita: porta al piano successivo.

## Struttura

```
scenes/            scene (.tscn)
scripts/
  autoload/        Game (stato, comandi), NoiseBus (eventi rumore)
  dungeon/         generatore (solo dati) e costruttore 3D
  player/          movimento, input separato, torcia
  ui/              overlay di debug
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
```

## Build per i tester

Crea un tag (`git tag v0.1.1 && git push --tags`): GitHub Actions compila Windows e Linux.
Per caricare anche su itch.io, in GitHub > Settings > Secrets and variables > Actions aggiungi:
- segreto `BUTLER_API_KEY` (da itch.io > Settings > API keys)
- variabile `ITCH_GAME` (es. `tuonome/dungeon-oscurita`)

## Seed di un bug

Nel nodo `Main` imposta `fixed_seed` al seed della segnalazione: il gioco rigenera lo stesso dungeon.
