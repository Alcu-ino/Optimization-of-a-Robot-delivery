set V;                 #nodi Spacetime
set A within {V, V};   #archi Spacetime
set C;                 #clienti

param costo {A}; #PEDAGGIO
param energia {A}; #ENERGIA CONSUMATA NEL TRAGITTO
param tempoPercorrenza{A}; #TEMPO DI PERCORRENZA DEL TRAGITTO
param nodoPartenza symbolic within V; #DEPOSITO
param nodoArrivo symbolic within V; #DEPOSITO A CHIUSURA
param nome_nodo_arrivo {A} symbolic;  
param nome_nodo_partenza {A} symbolic;
param deadline {C} >= 0;#DA ESFILTRARE
param startline {C} >=0 ;#DA ESFILTRARE
param cap_batteria >= 0; #SECONDO ME NON SERVE E' UNA COSTANTE (100)
param tempoNodo {A} >= 0; #tempo di arrivo al nodo, usato per calcolare il ritardo BISOGNA ESFILTRARLO

var x {A} binary;
var ritardo {C} >= 0;
var soc {V} >= 0;
var ricarica {A} binary; #elenco staioni di ricarica come C?
#normalizzazione grandezze
minimize CostoTotale:#DEVE MINIMIZZARE, IL RITARDO OLTRE  IL TEMPO DI PERCORRENZA E L'ENERGIA CONSUMATA, QUINDI OK!
    sum {(i,j) in A} (costo[i,j] + energia[i,j] + tempoPercorrenza[i,j])* x[i,j] + sum {c in C} ritardo[c];

#CONSERVAZIONE FLUSSO
subject to Conservazione {k in V}:
    sum {(i,k) in A} x[i,k] - sum {(k,j) in A} x[k,j]  
    = 
    if k == nodoPartenza then -1 #robot esce dal deposito=-1
    else if k == nodoArrivo then 1 #robot arriva al nodo cliente=1
    else 0;

subject to Visita_Unica_Cliente {c in C}:
    sum {(i,j) in A: nome_nodo_arrivo[i,j] == c and nome_nodo_partenza[i,j]!= c} x[i,j] == 1;

#ENERGIA
subject to Booleano_Ricarica {(i,j) in A: nome_nodo_arrivo[i,j] != nodoPartenza or nome_nodo_partenza[i,j] != nodoArrivo}:
    ricarica[i,j]<= 0  
;
subject to Limite_Batteria{(i,j) in A}:
    soc[j] <= soc[i]- energia[i,j]*x[i,j] + cap_batteria*2*(ricarica[i,j])+cap_batteria*2*(1-x[i,j])
;
subject to Batteria_MinSicurezza {v in V}:
    soc[v] >= 0.20 * cap_batteria;
subject to capacita_Batteria {i in V}:
    soc[i] <= cap_batteria
;
subject to Ricarica_Deposito {(i,j) in A: nome_nodo_arrivo[i,j] == nodoPartenza and nome_nodo_partenza[i,j] == nodoArrivo}:
    soc[j] = cap_batteria
;
subject to CaricaIniziale:
    soc[nodoPartenza] = cap_batteria
;
# TEMPO
subject to Consegna_in_finestra_minima{c in C, (i,j) in A: nome_nodo_arrivo[i,j] == c and nome_nodo_partenza[i,j]!=c }:
    tempoNodo[i,j]*x[i,j] >= startline[c]*x[i,j];
subject to Ritardi {c in C, (i,j) in A: nome_nodo_arrivo[i,j] == c and nome_nodo_partenza[i,j] != c}:
     ritardo[c] >= x[i,j]*tempoNodo[i,j] - deadline[c]*x[i,j];