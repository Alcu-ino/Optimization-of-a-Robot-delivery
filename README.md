# Optimization of a Robot delivery

Ottimizzazione del percorso di consegna dei pacchi da parte di un robot autonomo.

Il progetto risolve un problema di instradamento e schedulazione di un robot che, partendo
da un deposito, deve consegnare un insieme di pacchi a clienti sparsi su una rete stradale
reale, rispettando finestre temporali, autonomia della batteria e possibilità di ricarica.
Il problema è modellato su una **rete spazio-temporale (Time-Expanded Network, TEN)** e
risolto come programma lineare intero misto (MILP) con **AMPL + CPLEX**, orchestrato da MATLAB.

---

## Indice

- [Come funziona](#come-funziona)
- [Struttura della repository](#struttura-della-repository)
- [Prerequisiti](#prerequisiti)
- [Configurazione dei path](#configurazione-dei-path)
- [Istruzioni per l'uso](#istruzioni-per-luso)
- [Il modello di ottimizzazione](#il-modello-di-ottimizzazione)
- [Output prodotti](#output-prodotti)
- [Analisi di sensitività e frontiera di Pareto](#analisi-di-sensitività-e-frontiera-di-pareto)
- [Note](#note)

---

## Come funziona

La pipeline è organizzata in **due stadi**, da eseguire in sequenza dentro la stessa
sessione MATLAB (il primo produce variabili di workspace che il secondo consuma):

1. **Grounding** — a partire da un export OpenStreetMap della zona, si costruisce il grafo
   stradale fisico, si associa ogni "entrata" (deposito, clienti, punti notevoli) al nodo
   OSM più vicino e si calcolano gli archi logici tra le entrate tramite cammini minimi.
   Ogni arco viene arricchito con **costo**, **energia** (in % di batteria) e **tempo di
   percorrenza** (in slot da 15 minuti, differenziato per fascia oraria). L'output è la
   struct `archi` e il vettore di nomi `nomi`.

2. **Main** — a partire da `nomi` e `archi`, si genera la TEN completa (nodi
   spazio-temporali + archi di movimento e di attesa), si esporta il file dati `.dat` per
   AMPL, si lancia il solver CPLEX e si leggono i risultati (percorso ottimo, stato di
   carica, log dei caricamenti dei pacchi).

Esistono **due varianti di grounding** ed è previsto se ne esegua **una sola** prima del main:

- `groundingMap.m` — versione **deterministica** (cammino minimo classico).
- `stochasticGroundingMap.m` — versione **robusta** (cammino minimo robusto in stile
  budget-of-uncertainty, con deviazione `beta` sui pesi e budget `Gamma`).

---

## Struttura della repository

```
Optimization-of-a-Robot-delivery/
│
├── groundingMap.m             # STADIO 1 (deterministico): OSM -> grafo -> archi
├── stochasticGroundingMap.m   # STADIO 1 (robusto): variante con incertezza sui pesi
├── robustShortestPath.m       # cammino minimo robusto (budget Gamma) usato dal grounding stocastico
│
├── main.m                     # STADIO 2: costruzione TEN, export .dat, solve CPLEX, risultati
├── Ampl_Main.mod              # modello AMPL (MILP): insiemi, parametri, obiettivo, vincoli
├── archi_temp.dat             # file dati AMPL GENERATO da main.m (non va editato a mano)
│
├── NodiSpaceTime.m            # genera i nodi spazio-temporali "NOME:TEMPO"
├── ArchiSpaceTime.m           # genera gli archi della TEN (movimento + attesa/holding)
├── Periodo.m                  # mappa lo slot temporale in fascia oraria (mattina/pomeriggio/sera)
├── TempoPercorrenzaTau.m      # tempo di percorrenza di un arco nella fascia oraria data
├── TimeWindow.m               # estrae la finestra temporale [a,b] di un nodo
├── amplNode.m                 # converte il separatore ":" in "_" (identificatori legali AMPL)
├── estraiEstremi.m            # ricava i nodi estremi di un arco fisico ("N1@N10")
│
├── graphViewer.py             # visualizzatore opzionale della TEN (Python + networkx)
│
├── analisi/
│   ├── analisi.m              # lancia l'analisi di sensitività / Pareto da MATLAB
│   ├── analisi.run            # script AMPL: sensitività batteria + frontiera di Pareto
│   ├── out_sens_batteria.txt  # output sensitività capacità batteria
│   └── out_pareto_pesi.txt    # output frontiera di Pareto (metodo pesi-somma)
│
└── old+/                      # versioni precedenti di main.m e Ampl_Main.mod (archivio)
```

---

## Prerequisiti

**MATLAB** con:
- **Mapping Toolbox** — usa `wgs84Ellipsoid`, `distance`, `readgeotable`, `geoplot`,
  `geopointshape`, `geobasemap`.
- Funzioni di grafo di base (`graph`, `shortestpath`, `simplify`, `degree`, `digraph`).

**AMPL** con:
- solver **CPLEX**;
- **AMPL API for MATLAB** (interfaccia Java `com.ampl.AMPL` / `com.ampl.Environment`),
  richiamata da `main.m` e da `analisi/analisi.m`.

**File OpenStreetMap**:
- un export `.osm` della zona di interesse (nel codice: `export.osm`), contenente `node` e
  `way`. È la fonte del grafo stradale.

**Python** (solo per `graphViewer.py`, opzionale):
- `networkx`, `matplotlib`.

---

## Configurazione dei path

Gli script contengono **percorsi assoluti** legati alla macchina di sviluppo, che vanno
adattati al proprio ambiente prima di eseguire. In particolare:

| Dove | Variabile / riga | Valore attuale | Da adattare a |
|------|------------------|----------------|----------------|
| `groundingMap.m`, `stochasticGroundingMap.m` | `filename` | `/home/vito/Scrivania/lib/export.osm` | percorso del proprio file `.osm` |
| `main.m`, `analisi/analisi.m` | `AMPL_HOME` | `/home/vito/Scrivania/ampl` | cartella di installazione di AMPL |
| `main.m`, `analisi/analisi.m` | `MOD_FILE`, `DAT_FILE` | `.../Scrivania/optimization/Optimization-of-a-Robot-delivery-1/...` | cartella del progetto |

> Suggerimento: conviene sostituire i percorsi assoluti con percorsi relativi a `pwd` (o a
> una variabile `PROJECT_ROOT` definita una volta sola) per rendere il progetto portabile.

---

## Istruzioni per l'uso

Aprire MATLAB nella cartella del progetto e procedere in ordine.

### 1. Eseguire **uno** dei due grounding

Scegliere la variante desiderata ed eseguirla **per prima**:

```matlab
% variante deterministica
groundingMap

% -- OPPURE --

% variante robusta (incertezza sui pesi degli archi)
stochasticGroundingMap
```

Al termine, nel workspace saranno presenti:
- `nomi`  — array dei nomi dei nodi fisici (`"O"`, `"N1"`, …, `"N20"`);
- `archi` — struct array con i campi `nome` (`"N1@N10"`), `costo`, `energia`, `tempoPercorrenza`.

Entrambi gli script producono anche una **mappa** (rete stradale, incroci rilevanti, entrate)
e una **tabella riepilogativa** `EuristicaGradoEntrate`, che conta per quanti cammini
minimi ciascuna entrata compare come nodo di transito (utile per capire quali entrate sono
punti di passaggio nevralgici).

### 2. Eseguire il main

Con `nomi` e `archi` già in memoria:

```matlab
main
```

`main.m` costruisce la TEN, scrive `archi_temp.dat`, avvia CPLEX e stampa i risultati.
Se `archi` non è definito, uno degli `assert` iniziali interrompe l'esecuzione ricordando di
eseguire prima il grounding.

### 3. (Opzionale) Analisi di sensitività e Pareto

```matlab
cd analisi
analisi
```

---

## Il modello di ottimizzazione

Il modello MILP è definito in `Ampl_Main.mod`.

### Insiemi

| Insieme | Significato |
|---------|-------------|
| `V` | nodi spazio-temporali (es. `O_0`, `N10_12`) |
| `A ⊆ V×V` | archi spazio-temporali (movimento e attesa) |
| `C` | clienti fisici (destinazioni di consegna) |
| `R` | stazioni di ricarica fisiche |
| `P` | pacchi da consegnare |

### Dati principali del caso di test (in `main.m`)

- Orizzonte temporale: `T_MAX = 47`, cioè **48 slot da 15 minuti** (fascia 8:00–20:00).
- Capacità batteria: `CAP_BATTERIA = 1260`.
- Capacità di carico del robot: `CAP_MAX_ROBOT = 10`.
- Consumo aggiuntivo dovuto al peso: `CONSUMO_PESO = 0.003`.
- Penale per mancata consegna: `PENALE_MANCATA = 100000`.
- Pacchi: `pesiPacchi = [4 4 5 4 4 5 5]` (7 pacchi), con destinatari in `pacco_destinatario`.
- Deposito: `O`; clienti: `N1`, `N2`, `N19`; nodi di ricarica: `N1`, `N15`.
- Finestre temporali e orari di apertura gestiti come eccezioni per nodo
  (es. il nodo di ricarica `N1` è disponibile solo in una fascia; il cliente `N2` ha una
  finestra di consegna vincolata).

### Fasce orarie

`Periodo.m` suddivide la giornata in tre fasce (mattina / pomeriggio / sera) e i tempi di
percorrenza degli archi sono **dipendenti dalla fascia oraria** (`tempoPercorrenza` è un
vettore a 3 componenti indicizzato da `Periodo`).

### Rete spazio-temporale

- `NodiSpaceTime.m` genera un nodo `NOME:TEMPO` per ogni istante compatibile con la finestra
  di apertura del nodo.
- `ArchiSpaceTime.m` genera due tipi di archi:
  - **archi di movimento**: da `NOME_p:t` a `NOME_a:(t+τ)`, con `τ` calcolato in base alla fascia oraria;
  - **archi di attesa (holding)**: da `NOME:t` a `NOME:(t+1)`, a costo ed energia nulli, che
    permettono al robot di sostare in un nodo consumando uno slot temporale.
- Nel file `.dat` il separatore `:` viene sostituito con `_` (`amplNode.m`) perché `:` è
  riservato dalla sintassi dei blocchi dati AMPL.

### Funzione obiettivo

Minimizzazione di una **somma pesata e normalizzata** di cinque termini (pesi `w_*` con
default 0.20 ciascuno):

1. costo di percorrenza;
2. energia consumata;
3. tempo di percorrenza;
4. ritardo sulle consegne rispetto alle finestre dei clienti;
5. penale per i pacchi non consegnati.

Ogni termine è diviso per un fattore di scala (`scala_costo`, `scala_energia`, …) così da
renderli confrontabili e i pesi interpretabili.

### Vincoli principali

- **Conservazione del flusso del veicolo**: un solo robot esce dal nodo di partenza e uno
  solo entra nel nodo di arrivo; negli altri nodi il flusso si conserva.
- **Accoppiamento robot–pacco**: un pacco può transitare su un arco solo se il robot percorre
  quell'arco (`carica_pacco[i,j,p] ≤ x[i,j]`).
- **Carico unico dal deposito**: ogni pacco esce dal deposito al più una volta.
- **Conservazione del flusso dei pacchi**: i pacchi "nascono" al deposito e vengono assorbiti
  al cliente di destinazione; nei nodi di transito/ricarica ciò che entra deve uscire.
- **Stato di carica (SOC)** e vincoli energetici, con l'assunzione chiave che il costo
  energetico di una tratta non superi il ~40% della batteria (altrimenti andata e ritorno non
  sarebbero possibili).
- **Finestre temporali** dei clienti (`startline` / `deadline`) e relativi ritardi.

### Variabili di decisione

| Variabile | Tipo | Significato |
|-----------|------|-------------|
| `x[A]` | binaria | il robot percorre l'arco |
| `carica_pacco[A,P]` | binaria | il pacco `p` transita sull'arco |
| `soc[V]` | continua | stato di carica al nodo |
| `peso_trasportato[A]` | continua | peso a bordo lungo l'arco |
| `ritardo[C]` | continua | ritardo di consegna al cliente |
| `consegnato[P]` | binaria | il pacco è stato consegnato |

---

## Output prodotti

Al termine di `main.m` vengono mostrati:

- **Percorso ottimo** sulla TEN: tabella degli archi attivi (`x = 1`) e relativo grafo
  orientato (`digraph`).
- **Stato di carica** (`soc`) nei nodi effettivamente visitati.
- **Log dei caricamenti dei pacchi** (multi-trip): per ogni pacco, gli archi spazio-temporali
  su cui viaggia.
- **Tempo impiegato** dal solver.

---

## Analisi di sensitività e frontiera di Pareto

La cartella `analisi/` contiene uno studio parametrico eseguito direttamente in AMPL e
riletto da MATLAB:

- `analisi.run`
  - **Sensitività sulla capacità della batteria**: risolve il modello per una griglia di
    valori di `cap_batteria` (da 10 a 2200) e registra costo, energia, tempo, ritardo, penale,
    valore obiettivo e numero di pacchi consegnati.
  - **Frontiera di Pareto** (metodo dei pesi-somma) sul trade-off tra gli obiettivi.
- `analisi.m` lancia lo script, legge `out_sens_batteria.txt` e `out_pareto_pesi.txt` e
  produce i grafici (curva capacità–costo e frontiera di Pareto).

---

## Note

- `archi_temp.dat` è un artefatto **generato** da `main.m`: non va modificato manualmente e
  viene sovrascritto a ogni esecuzione.
- La cartella `old+/` conserva versioni precedenti di `main.m` e `Ampl_Main.mod` a scopo di
  archivio; non fa parte della pipeline attiva.
- `graphViewer.py` è un'utilità di supporto: va alimentata incollando l'array `A_T` esportato
  da MATLAB nel campo `input_text`.
- Alcuni parametri (costi degli archi) sono generati in modo pseudo-casuale nel grounding
  (`randi(costoRange)`): per risultati riproducibili fissare il seme con `rng(...)` all'inizio
  dello script di grounding.
