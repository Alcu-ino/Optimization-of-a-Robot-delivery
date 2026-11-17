
# =======================================================
# MODELLO ROBOT DELIVERY SU RETE SPAZIO-TEMPO (versione corretta)
#
# Modifiche rispetto alla versione precedente:
#  [C1] Peso: definizione diretta al posto di Bilancio_Peso_Nodi
#       (il vecchio bilancio ri-sommava i pacchi a ogni nodo).
#  [C2] Big-M batteria: costante per arco M_soc al posto di 200.
#  [C3] Ricarica: arco di ricarica vero sulle attese in stazione;
#       rimossi Ricarica_Nodi_Speciali e Ricarica_Deposito_Chiusura.
#  [C4] Finestre temporali: attivate dalla consegna del pacco,
#       non dal transito del robot; niente Big-M.
#  [C5] Tempo in obiettivo: tempo operativo (tutti gli archi tranne le
#       attese al deposito) al posto della somma dei tempi, che era costante.
#  [C6] Penale: per default ogni pacco non consegnato pesa w_penale intero
#       (scala = penale massima). Con la scala = somma delle penali un pacco
#       pesava w_penale/card(P), meno del costo di un singolo viaggio.
#
# Nuovi parametri opzionali nel .dat:
#   tasso_ricarica    (se assente: ricarica completa in un solo slot di attesa)
#   penale_dominante  (default 1; mettere 0 per tornare alla scala = somma)
# =======================================================

# =======================================================
# SETS / INSIEMI
# =======================================================
set V;                 # Nodi Spacetime (es. O_0, A_4, B_12...)
set A within {V, V};   # Archi Spacetime
set C;                 # Clienti fisici (es. A, B)
set R;                 # Stazioni di ricarica fisiche (es. B; aggiungere "O" per ricaricare al deposito)
set P;                 # Insieme dei PACCHI disponibili

# =======================================================
# PARAMETRI
# =======================================================
# Parametri Archi
param costo {A};
param energia {A};
param tempoPercorrenza {A};
param tempoNodo {A} >= 0;

# Mantenuti per compatibilita' con i .dat esistenti (non piu' usati nei vincoli)
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

param base {k in V} symbolic := substr(k, 1, match(k, "_") - 1);   # nodo fisico
param slot {k in V} := num(substr(k, match(k, "_") + 1));          # istante

param pacco_cliente {P} symbolic within C;   # cliente fisico di destinazione
param peso_pacco {P} >= 0;

# [C3] Energia ricaricata per unita' di tempo di attesa in stazione
param tasso_ricarica >= 0 default cap_batteria;

# [C3] Archi di ricarica = attese in una stazione
set A_ric := {(i,j) in A: base[i] == base[j] and base[j] in R};

# [C2] Big-M valida per la dinamica della batteria:
# con x = 0 lo scarto massimo fra due SOC e' 0.8*cap_batteria, piu' il consumo dell'arco
param M_soc {(i,j) in A} := 0.8 * cap_batteria + max(0, energia[i,j]);

# Controllo di coerenza opzionale (togliere il commento per attivarlo):
# ogni arco deve avanzare esattamente del proprio tempo di percorrenza
# check {(i,j) in A}: tempoPercorrenza[i,j] = slot[j] - slot[i];

# -------------------------------------------------------
# Normalizzazione della funzione obiettivo
# -------------------------------------------------------
param nArchiMax     := max {k in V} slot[k];                        # orizzonte / lunghezza max di un percorso
param scala_costo   := nArchiMax * max {(i,j) in A} costo[i,j];
param scala_energia := nArchiMax * max {(i,j) in A} (energia[i,j] + consumo_peso * cap_max_robot);
param scala_tempo   := nArchiMax * max {(i,j) in A} tempoPercorrenza[i,j];
param scala_tempo_op := max(1, nArchiMax - slot[nodoPartenza]);     # [C5] orizzonte
param scala_ritardo := card(C) * max(1, scala_tempo - min {c in C} deadline[c]);
param penale_dominante binary default 1;                            # [C6]
param scala_penale  :=
    if penale_dominante = 1 then max(1e-9, max {p in P} penale_mancata_consegna[p])
    else                         max(1e-9, sum {p in P} penale_mancata_consegna[p]);

param w_costo   >= 0, <= 1 default 0.20;
param w_energia >= 0, <= 1 default 0.20;
param w_tempo   >= 0, <= 1 default 0.20;
param w_ritardo >= 0, <= 1 default 0.20;
param w_penale  >= 0, <= 1 default 0.20;

# =======================================================
# VARIABILI
# =======================================================
var x {A} binary;
var carica_pacco {A, P} binary;   # 1 se il pacco p transita sull'arco (i,j)
var ritardo {C} >= 0;
var soc {V} >= 0;
var peso_trasportato {A} >= 0;    # Peso effettivo lungo l'arco
var consegnato {P} binary;

# =======================================================
# FUNZIONE OBIETTIVO
# =======================================================
minimize CostoTotale:
      w_costo   * (sum {(i,j) in A} costo[i,j]   * x[i,j]) / scala_costo
    + w_energia * (sum {(i,j) in A} (energia[i,j] * x[i,j]+ consumo_peso * peso_trasportato[i,j])) / scala_energia
    + w_tempo   * (sum {(i,j) in A: base[i] != "O" or base[j] != "O"}
                       tempoPercorrenza[i,j] * x[i,j])     / scala_tempo_op
    + w_ritardo * (sum {c in C} ritardo[c])                / scala_ritardo
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
# 2. ACCOPPIAMENTO ROBOT-PACCHI & CONSERVAZIONE FLUSSO PACCHI
# -------------------------------------------------------
# Un pacco puo' transitare su un arco solo se il robot lo percorre
subject to Pacco_Segue_Robot {(i,j) in A, p in P}:
    carica_pacco[i,j,p] <= x[i,j];

# Un pacco esce dal deposito al massimo una volta
subject to Carica_Massimo_Una_Volta {p in P}:
    sum {(i,j) in A: base[i] == "O" and base[j] != "O"} carica_pacco[i,j,p] <= 1;

subject to Conservazione_Flusso_Pacco {p in P, k in V}:
    sum {(i,k) in A} carica_pacco[i,k,p] - sum {(k,j) in A} carica_pacco[k,j,p] =
        if base[k] == "O" then
            # Al deposito i pacchi possono nascere
            - (sum {(k,j) in A: base[j] != "O"} carica_pacco[k,j,p])
        else if base[k] == pacco_cliente[p] then
            # Al cliente il pacco viene assorbito
            (sum {(i,k) in A} carica_pacco[i,k,p])
        else
            # Nei nodi di transito cio' che entra deve uscire
            0;

subject to Def_Consegnato {p in P}:
    consegnato[p] =
        sum {(i,j) in A: base[j] == pacco_cliente[p] and base[i] != pacco_cliente[p]}
            carica_pacco[i,j,p];

# -------------------------------------------------------
# 3. PESO TRASPORTATO                                  [C1]
# -------------------------------------------------------
# Il peso su un arco e' la somma dei pacchi che vi transitano
subject to Def_Peso {(i,j) in A}:
    peso_trasportato[i,j] = sum {p in P} peso_pacco[p] * carica_pacco[i,j,p];

subject to Limite_Capacita_Carico {(i,j) in A}:
    peso_trasportato[i,j] <= cap_max_robot * x[i,j];

# -------------------------------------------------------
# 4. ENERGIA & STATO DI CARICA (SOC)                   [C2][C3]
# -------------------------------------------------------
subject to Batteria_MinSicurezza {v in V}:
    soc[v] >= 0.20 * cap_batteria;

subject to Capacita_Massima_Batteria {i in V}:
    soc[i] <= cap_batteria;

subject to Carica_Iniziale:
    soc[nodoPartenza] = cap_batteria;

# Scarica sugli archi normali (tutti tranne le attese in stazione)
subject to Dinamica_Scarica_Superiore {(i,j) in A diff A_ric}:
    soc[j] <= soc[i] - (energia[i,j] + consumo_peso * peso_trasportato[i,j])
              + M_soc[i,j] * (1 - x[i,j]);

subject to Dinamica_Scarica_Inferiore {(i,j) in A diff A_ric}:
    soc[j] >= soc[i] - (energia[i,j] + consumo_peso * peso_trasportato[i,j])
              - M_soc[i,j] * (1 - x[i,j]);

# Ricarica sulle attese in stazione: la SOC non scende e puo' salire
# al massimo di tasso_ricarica per unita' di tempo (il tetto e' cap_batteria)
subject to Ricarica_Min {(i,j) in A_ric}:
    soc[j] >= soc[i] - M_soc[i,j] * (1 - x[i,j]);

subject to Ricarica_Max {(i,j) in A_ric}:
    soc[j] <= soc[i] + tasso_ricarica * tempoPercorrenza[i,j]
              + M_soc[i,j] * (1 - x[i,j]);

# -------------------------------------------------------
# 5. FINESTRE DI CONSEGNA                              [C4]
# -------------------------------------------------------
# Nessuna consegna prima dell'apertura della finestra del cliente
subject to Consegna_in_finestra_minima {p in P, (i,j) in A:
        base[j] == pacco_cliente[p] and base[i] != pacco_cliente[p]
        and tempoNodo[i,j] < startline[pacco_cliente[p]]}:
    carica_pacco[i,j,p] = 0;

# Ritardo del cliente = ritardo della sua consegna piu' tardiva
subject to Ritardi {p in P, (i,j) in A:
        base[j] == pacco_cliente[p] and base[i] != pacco_cliente[p]}:
    ritardo[pacco_cliente[p]] >=
        (tempoNodo[i,j] - deadline[pacco_cliente[p]]) * carica_pacco[i,j,p];
