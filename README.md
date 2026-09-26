# Dungeon nell'oscurità

Dungeon crawler cooperativo in 3D: torce che si consumano, mostri che sentono tutto, combattimento come ultima spiaggia.

**Motore:** Godot 4.7 · **Stato:** prototipo (M0–M5)

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
| F | Spegnere la torcia (solo quella in mano: riposta continua a bruciare) |
| Q | Usare l'oggetto selezionato. Acciarino: accende la torcia (riaccende quella in uso se è spenta, altrimenti una nuova) e la prende in mano; lo scatto si sente. Torcia accesa: la butta a terra (fa rumore), dove continua a bruciare, e se ne hai una nuova la accende dalla sua fiamma. Tagliola: la posa davanti ai piedi (fa rumore). Zaino: lo metti in spalla, 3 posti in più |
| E | Raccogliere l'oggetto vicino (una torcia buttata torna nell'inventario e in mano) / aprire o chiudere una porta (fa rumore; la porta dorata solo con la chiave d'oro) / tirare una leva (fa rumore) / se non c'è niente a portata, bussare sul muro davanti (fa un po' di rumore) |
| 1–8 | Scegliere lo slot dell'inventario: l'oggetto selezionato è quello in mano (6–8 solo con lo zaino) |
| G | Lasciare a terra l'oggetto selezionato (fa rumore; il legno bruciato si può solo buttare) |
| M | Mostrare / nascondere la mappa (si disegna solo ciò che la torcia illumina) |
| R | Nuova partita |
| F3 | Debug (anche lo stato di ogni Cieco e la sua distanza) |
| F4 | Filtro retro PS1 on/off |
| F6 / F7 | Solo build di debug: togliere / ridare un punto di energia |
| Tab | Menu: scheda del giocatore (energia, torcia, tesori, rumore dei passi). Il gioco non si ferma: la torcia continua a bruciare |
| I | Menu: inventario (clic su uno slot per selezionarlo, pulsante per lasciarlo a terra) |
| J | Menu: diario (cosa è successo, piano per piano) |
| Esc | Menu: impostazioni (sensibilità del mouse, volume, filtro PS1, schermo intero; si salvano da sole). Libera il mouse; se il menu è aperto lo chiude |

**Uscita**: dietro la stanza più lontana dall'ingresso c'è una porta dorata, e dietro la porta la scala che scende al piano successivo. La porta si apre solo con la **chiave d'oro**: una per piano, in una delle stanze più lontane sia dall'ingresso sia dalla porta, quindi il piano va attraversato due volte. Basta averla nell'inventario (anche non selezionata) e premere E sulla porta: la chiave resta nella serratura e da lì la porta si apre e si chiude come le altre. Senza chiave la maniglia sbatte (un po' di rumore). Sulla mappa la porta dorata è color oro.
Alcuni corridoi sono chiusi da porte (bloccano anche la luce) che si possono richiudere alle spalle; in certi piani ci sono torce appese ai muri, che non si consumano.
Ogni piano inizia in una piccola stanza illuminata da torce a muro, con una torcia a terra. Si parte a mani vuote, con solo un acciarino: raccogli la torcia (E) e accendila (Q). Le altre torce vanno cercate nelle stanze e diventano più rare scendendo. L'inventario ha 5 slot (8 con lo zaino) e si conserva tra un piano e l'altro.
Ogni torcia occupa uno slot: nuova, accesa (l'icona ha la fiamma), spenta o legno bruciato. La torcia accesa fa luce solo finché è lo slot selezionato: se prendi in mano un altro oggetto la riponi e resti al buio, ma continua a bruciare finché non si consuma. Consumata, nello slot resta il legno bruciato: non serve più e occupa posto finché non lo butti (G). In uso c'è una torcia alla volta.
Una torcia buttata a terra con Q resta accesa e fa luce finché ha combustibile: con E la riprendi (se ne hai già una in uso, si scambiano); consumata, resta un moncone annerito che non si può più raccogliere.
In alto a sinistra la barra dell'energia (10 punti: pochi colpi bastano) e, sotto, il riquadro della torcia accesa; in basso gli slot dell'inventario con le icone degli oggetti.
L'energia non si recupera e passa da un piano all'altro. A zero si muore: la partita finisce con una schermata che riassume piano, tempo, tesori messi in salvo, causa e seed; R ne avvia una nuova.
**Fine della discesa**: i piani sono 6 (`floors` nel nodo `Main`). La scala dell'ultimo piano porta fuori: si esce vivi, i tesori che hai addosso vanno nel punteggio e compare la schermata "Sei uscito vivo". R avvia una nuova partita.
**Il Cieco** (un Cieco al piano 1, uno in più ogni due piani, fino a 4) sente soltanto. Vaga lento e respira forte: al buio lo senti prima di vederlo. Se sente un rumore corre dove l'ha sentito (4,5 m/s: camminando non gli scappi, correndo sì), annusa qualche secondo e se ne va. Non ti insegue: va sempre verso l'ultimo rumore, quindi fermarsi o accucciarsi (i passi accucciati si sentono solo entro 2 m) lo lascia a mani vuote. Il suono segue i corridoi e le porte chiuse lo attutiscono. Le porte non le apre: se il rumore viene da dietro una porta chiusa gratta per qualche secondo e rinuncia; una porta non si chiude se nel vano c'è qualcuno. Se ti tocca ti toglie 3 punti di energia e si ritrae per 2 secondi: è il momento di allontanarsi in silenzio.
**Scudo** (a volte a terra in un piano): basta averlo nell'inventario, para 1 danno di ogni colpo. Al primo colpo diventa "scudo incrinato", al secondo si rompe. Lo stato si vede nella scheda del giocatore (Tab).
**Tagliola** (1–2 a terra per piano): selezionala e premi Q per posarla davanti ai piedi. Si arma dopo un secondo; il Cieco non la vede, ci finisce dentro e resta bloccato 3 secondi. Lo scatto si sente lontano e può richiamare altri Ciechi. Usa e getta; per ora non scatta sui giocatori.
**Zaino** (sempre al piano 1, a volte più in basso): selezionalo e premi Q per metterlo in spalla. L'inventario passa da 5 a 8 posti per il resto della partita (tasti 6–8). Se ne porta uno solo; una nuova partita riparte senza.
**Muri segreti e tesori** (0–1 stanze segrete al piano 1, 1–2 dal piano 2): accanto a qualche stanza c'è una stanzetta nascosta dietro un muro identico agli altri. Da vicino, con la torcia, si nota il contorno di una porta nelle fughe dei mattoni; bussando (E verso il muro) la pietra piena suona sorda, il muro segreto suona vuoto. Da lì E lo spinge: sprofonda nel pavimento strisciando (rumore) e si può richiudere, anche da dentro. Sulla mappa finché è chiuso è un muro. Dentro ci sono 1–3 **tesori**: monete d'oro (10 punti), rubino (25), calice d'oro (50). Occupano uno slot come ogni oggetto e valgono punti solo quando li porti giù per la scala: lì escono dall'inventario e vanno nel punteggio. Se muori, quelli che hai addosso sono persi. Il punteggio si vede nella scheda del giocatore (Tab) e nella schermata di fine.
**Leve** (ferro murato con una maniglia, E per tirarla; il clang si sente):
- **Cancelli** (uno a volte dal piano 2): una saracinesca di sbarre all'ingresso di un vicolo cieco. A mano non si alza; ci si vede attraverso (anche sulla mappa), ma non si passa, e il Cieco nemmeno. La sua leva è in un'altra stanza, lontana e sempre raggiungibile: tirata, il cancello si alza con un gran rumore di catene; riabbassata, ricade (non addosso a qualcuno). Dietro a volte c'è la chiave d'oro. Un cancello richiuso alle spalle tiene fuori il Cieco.
- **Trappole** (circa una su tre, porte a dardi comprese): una leva sul muro a pochi passi, dal lato da cui arrivi. Tirata resta giù: dalla trappola arriva un colpo secco (così capisci quale), la piastra resta bloccata, il filo del masso si allenta.
**Trappole** (2 al piano 1, una in più a ogni piano, fino a 8; mai vicino all'ingresso). Ognuna ha un innesco che si vede, se guardi dove metti i piedi; quando scatta fa un suono breve e l'effetto arriva un attimo dopo: chi reagisce subito si salva. Chi viene ferito grida, e il Cieco lo sente.

| Trappola | Cosa si vede | Cosa fa | Come evitarla | Dal piano |
| --- | --- | --- | --- | --- |
| Frecce dal pavimento | piastra al centro di una lastra piena di forellini | clic quasi muto, poi le frecce escono e rientrano in silenzio: 3 danni a chi è sulla cella. Si riarma | aggira la piastra, o esci subito dalla cella | 1 |
| Soffio | piastra in un corridoio, due grate nei muri | una folata spegne la torcia in mano (per riaccenderla serve l'acciarino, che si sente). Si riarma | aggira la piastra | 1 |
| Gabbia | piastra, catene e punte di sbarre che spuntano dal soffitto | la gabbia crolla con un fracasso che si sente lontano: chi è dentro resta chiuso 15 s | aggira la piastra, o esci in tempo | 2 |
| Botola | quadrato di assi chiare nel pavimento di pietra di una stanza | scricchiola, poi si spalanca: si cade in una fossa (1 danno) e la torcia sfugge di mano. Si risale solo con una **corda** (E), che resta appesa per chi cade dopo; senza, da soli si muore dopo 10 s | non calpestarla | 2 |
| Porta a dardi | quattro fori scuri nell'anta, all'altezza del petto | aprendola: clic, e i dardi partono verso chi apre (3 danni) | aprila accovacciato: passano sopra la testa | 2 |
| Porta coi campanelli | campanelli sopra il vano | in piedi, aprirla o chiuderla fa un gran rumore | accovacciato li tieni fermi con la mano | 2 |
| Masso | filo teso alla caviglia in un corridoio; poco più in là, nel soffitto, un buco tondo con la pancia di un masso | il filo si spezza, un boato, e il masso cade e rotola lungo il corridoio schiacciando chiunque trovi (poco meno veloce di chi corre) | scavalca il filo accovacciato; se scatta, corri in una stanza o in un corridoio laterale | 3 |

**Corda** (una per piano, dal piano 2): l'unico modo per risalire da una fossa.
Il menu (Tab, I, J, Esc) è un prototipo con quattro schede: scheda del giocatore, inventario, diario (si scrive da solo: piani, oggetti raccolti e lasciati, torce accese e consumate) e impostazioni. Col menu aperto il personaggio sta fermo ma il tempo scorre: in coop non si può mettere in pausa.
Gli oggetti a terra hanno un'aura (bordo luminoso e alone sul pavimento) che si vede solo quando la luce li raggiunge o quando ci passi accanto.

## Struttura

```
scenes/            scene (.tscn)
scripts/
  autoload/        Game (stato, comandi), NoiseBus (eventi rumore), Settings (impostazioni salvate)
  dungeon/         generatore (solo dati), disposizione delle trappole (solo dati), costruttore 3D, mappa dei passaggi per i nemici
  enemies/         il Cieco: corpo (blind.gd) e cervello a stati (blind_brain.gd, solo dati)
  traps/           trappole sul pavimento: base comune (trap.gd) e una scena per tipo
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
godot --headless -s res://tests/test_traps.gd
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
- Suoni: pacchetti [RPG Audio](https://kenney.nl/assets/rpg-audio), [Impact Sounds](https://kenney.nl/assets/impact-sounds), [Sci-fi Sounds](https://kenney.nl/assets/sci-fi-sounds), [Casino Audio](https://kenney.nl/assets/casino-audio) di [Kenney](https://kenney.nl), licenza CC0 (`assets/audio/LICENSE-kenney.txt`). Ogni file ha il nome del suo ruolo nel gioco (es. `blind_step_1.ogg`, `door_open.ogg`): per cambiare un suono basta sovrascrivere il file. Respiro e verso del Cieco sono provvisori (Kenney non ha versi di creature).

## Grafica voxel

Tutta la grafica (muri, pavimenti, soffitto, pilastri, porte, arredi, torce a muro, oggetti e torcia in mano) è fatta di modelli voxel in `assets/voxels/` (formato `.vox` di [MagicaVoxel](https://ephtracy.github.io/)). Scala: 1 voxel = 12,5 cm, quindi una cella da 2 m è larga 16 voxel e un muro è alto 24.
Il gioco legge i `.vox` all'avvio e li trasforma in mesh (`Voxels.mesh()` / `Voxels.instance()`): basta modificarli in MagicaVoxel, salvare e riavviare.

- `godot --headless -s res://tools/make_voxels.gd` rigenera i modelli di base dal seed (**sovrascrive** i `.vox`: se ne hai ritoccato uno, toglilo prima dall'elenco nello script).
- `godot res://tools/voxel_preview.tscn -- <cartella> [seed]` salva gli screenshot di controllo (galleria dei modelli e degli arredi, stanza d'ingresso, una porta, un arredo, oggetti a terra, prima persona con la torcia).

Regole dei modelli: origine al centro in x e z, base in basso. Gli oggetti che si raccolgono si chiamano `item_<id>` (es. `item_torch`, `item_flint`) e usano voxel da 6,25 cm, metà di quelli del mondo: per un oggetto nuovo basta il suo `.vox`. Gli stessi voxel piccoli valgono per le trappole piazzate (`trap_*`) e i nemici (`enemy_*`, guardano verso +z). Nei muri (16×26×8: 24 di parete più 2 di fondazione sotto il pavimento) la parete occupa la metà posteriore e la faccia a vista sta a metà profondità; ciò che sporge (mensole, mattoni) va nella metà anteriore. La torcia a muro segue la stessa convenzione. Le misure che il gioco si aspetta sono controllate in `tests/test_voxel.gd`.
