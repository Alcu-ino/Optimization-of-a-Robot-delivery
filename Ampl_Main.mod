# =======================================================
# SETS / INSIEMI
# =======================================================
set V;                 # Nodi Spacetime (es. O0, A4, B12...)
set A within {V, V};   # Archi Spacetime
set C;                 # Clienti fisici (es. A, B)
set R;                 # Stazioni di ricarica fisiche (es. B)
set P;                 # Insieme dei PACCHI disponibili

# =======================================================
# PARAMETRI
# =======================================================
# Parametri Archi
param costo {A}; 
param energia {A};              
param tempoPercorrenza {A}; 
param tempoNodo {A} >= 0; 

param nome_nodo_partenza {A} symbolic; 
param nome_nodo_arrivo {A} symbolic;   

param nodoPartenza symbolic within V;  
param nodoArrivo symbolic within V;    

# Parametri Finestre, Veicolo e Pacchi
param deadline {C} >= 0;
param startline {C} >= 0;
param cap_batteria >= 0; 
param consumo_peso >= 0;        
param cap_max_robot >= 0;       
param penale_mancata_consegna {P} >= 0; 
param base {k in V} symbolic := substr(k, 1, match(k, "_") - 1);

param pacco_cliente {P} symbolic within C; # Il cliente fisico di destinazione ("A" o "B")
param peso_pacco {P} >= 0;                 

#NORMALIZZAZIIONE OF:
param slot {k in V} := num(substr(k, match(k, "_") + 1));
param nArchiMax     := max {k in V} slot[k];        # lunghezza max di un percorso

param scala_costo   := nArchiMax * max {(i,j) in A} costo[i,j];
param scala_energia := cap_batteria;                # il SOC impedisce di superarla
param scala_tempo   := nArchiMax * max {(i,j) in A} tempoPercorrenza[i,j];
param scala_ritardo := card(C) * (nArchiMax - min {c in C} deadline[c]);
param scala_penale  := sum {p in P} penale_mancata_consegna[p];

param w_costo   >= 0, <= 1 default 0.20;
param w_energia >= 0, <= 1 default 0.20;
param w_tempo   >= 0, <= 1 default 0.20;
param w_ritardo >= 0, <= 1 default 0.20;
param w_penale  >= 0, <= 1 default 0.20;

# =======================================================
# VARIABILI
# =======================================================
var x {A} binary;
var carica_pacco {A, P} binary;  # 1 se il pacco p transita sull'arco (i,j)
var ritardo {C} >= 0;
var soc {V} >= 0;               
var peso_trasportato {A} >= 0;   # Peso effettivo lungo l'arco
var consegnato {P} binary;
# =======================================================
# FUNZIONE OBIETTIVO
# =======================================================
minimize CostoTotale:
      w_costo   * (sum {(i,j) in A} costo[i,j]            * x[i,j]) / scala_costo
    + w_energia * (sum {(i,j) in A} energia[i,j]          * x[i,j]) / scala_energia
    + w_tempo   * (sum {(i,j) in A} tempoPercorrenza[i,j] * x[i,j]) / scala_tempo
    + w_ritardo * (sum {c in C} ritardo[c])                         / scala_ritardo
    + w_penale  * (sum {p in P} penale_mancata_consegna[p] * (1 - consegnato[p]))
                                                                    / scala_penale;

# =======================================================
# VINCOLI
# =======================================================

# -------------------------------------------------------
# 1. CONSERVAZIONE DEL FLUSSO DEL VEICOLO
# -------------------------------------------------------
subject to Conservazione {k in V}:
    sum {(i,k) in A} x[i,k] - sum {(k,j) in A} x[k,j] = 
        if k == nodoPartenza then -1
        else if k == nodoArrivo then 1
        else 0;

# -------------------------------------------------------
# 2. ACCOPPIAMENTO FORTE ROBOT-PACCHI & CONSERVAZIONE FLUSSO
# -------------------------------------------------------

# Un pacco può transitare su un arco SOLO SE il robot percorre quell'arco
subject to Pacco_Segue_Robot {(i,j) in A, p in P}:
    carica_pacco[i,j,p] <= x[i,j];

# Un pacco non può uscire dal deposito totale più di una volta (evita rigenerazioni fittizie)
subject to Carica_Massimo_Una_Volta {p in P}:
    sum {(i,j) in A: base[i] == "O" and base[j] != "O"} carica_pacco[i,j,p] <= 1;

# Conservazione del flusso condizionata dal tipo di nodo fisico
subject to Conservazione_Flusso_Pacco {p in P, k in V}:
    sum {(i,k) in A} carica_pacco[i,k,p] - sum {(k,j) in A} carica_pacco[k,j,p] =
        if base[k] == "O" then
            # Al deposito i pacchi possono nascere (quindi le uscite superano le entrate)
            - (sum {(k,j) in A: base[j] != "O"} carica_pacco[k,j,p])
        else if base[k] == pacco_cliente[p] then
            # Al cliente il pacco viene assorbito (le entrate superano le uscite)
            (sum {(i,k) in A} carica_pacco[i,k,p])
        else
            # Nei nodi di transito o ricarica (es. "B"), ciò che entra deve uscire
            0;
subject to Def_Consegnato {p in P}:
    consegnato[p] =
        sum {(i,j) in A: base[j] == pacco_cliente[p] and base[i] != pacco_cliente[p]}
            carica_pacco[i,j,p];
# -------------------------------------------------------
# 3. DINAMICA E BILANCIO DEL PESO (Multi-Trip)
# -------------------------------------------------------
subject to Bilancio_Peso_Nodi {k in V}:
    sum {(k,j) in A} peso_trasportato[k,j] - sum {(i,k) in A} peso_trasportato[i,k] =
        (sum {(k,j) in A, p in P} peso_pacco[p] * carica_pacco[k,j,p])  
        - sum {(i,k) in A, p in P: nome_nodo_arrivo[i,k] == pacco_cliente[p] and nome_nodo_partenza[i,k] != pacco_cliente[p]} (peso_pacco[p] * carica_pacco[i,k,p]);

subject to Limite_Capacita_Carico {(i,j) in A}:
    peso_trasportato[i,j] <= cap_max_robot * x[i,j];

# -------------------------------------------------------
# 4. GESTIONE ENERGIA & STATO DI CARICA (SOC)
# -------------------------------------------------------
subject to Batteria_MinSicurezza {v in V}:
    soc[v] >= 0.20 * cap_batteria;

subject to Capacita_Massima_Batteria {i in V}:
    soc[i] <= cap_batteria;

subject to Carica_Iniziale:
    soc[nodoPartenza] = cap_batteria;

# Vincoli dinamici corretti con Big-M isolata a 200 per evitare infeasibility sui nodi inattivi
subject to Dinamica_Scarica_Superiore {(i,j) in A}:
    soc[j] <= soc[i] - (energia[i,j] + consumo_peso * peso_trasportato[i,j]) + 200 * (1 - x[i,j]);

subject to Dinamica_Scarica_Inferiore {(i,j) in A}:
    soc[j] >= soc[i] - (energia[i,j] + consumo_peso * peso_trasportato[i,j]) - 200 * (1 - x[i,j]);

# Ricarica se ti fermi in una stazione di ricarica R
subject to Ricarica_Nodi_Speciali {(i,j) in A: nome_nodo_arrivo[i,j] in R and nome_nodo_partenza[i,j] == nome_nodo_arrivo[i,j]}:
    soc[j] >= cap_batteria - cap_batteria * (1 - x[i,j]);

# Ricarica se ritorni al deposito finale di chiusura
subject to Ricarica_Deposito_Chiusura {(i,j) in A: nome_nodo_arrivo[i,j] == nodoArrivo}:
    soc[j] >= cap_batteria - cap_batteria * (1 - x[i,j]);

# -------------------------------------------------------
# 5. GESTIONE TEMPO E FINESTRE DI CONSEGNA
# -------------------------------------------------------
subject to Consegna_in_finestra_minima {c in C, (i,j) in A: nome_nodo_arrivo[i,j] == c and nome_nodo_partenza[i,j] != c}:
    tempoNodo[i,j] >= startline[c] - 100000 * (1 - x[i,j]);

subject to Ritardi {c in C, (i,j) in A: nome_nodo_arrivo[i,j] == c and nome_nodo_partenza[i,j] != c}:
    ritardo[c] >= tempoNodo[i,j] - deadline[c] - 100000 * (1 - x[i,j]);