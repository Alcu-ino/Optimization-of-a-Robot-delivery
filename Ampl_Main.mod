set V;                 #nodi Spacetime
set A within {V, V};   #archi Spacetime
set C; #clienti escluso O

param costo {A};
param energia {A};
param tempoPercorrenza{A};
param nodoPartenza symbolic within V; #nodo+orario, scalare
param nodoArrivo symbolic within V;
param nome_nodo_arrivo {A} symbolic;  #matrice
param nome_nodo_partenza {A} symbolic;
#nodoP.. e nome_.. sono diversi perche assicuriamo che il nodo venga visitato 1 volta 
#e che la sosta non venga considerata come una seconda visita

param cap_batteria >= 0;

var x {A} binary;     

#funzione obiettivo e vincoli
minimize CostoTotale:
    sum {(i,j) in A} (costo[i,j] + energia[i,j] + tempoPercorrenza[i,j])* x[i,j];

#conservazione del flusso
subject to Conservazione {k in V}:
    sum {(i,k) in A} x[i,k] - sum {(k,j) in A} x[k,j]  
    = 
    if k == nodoPartenza then -1 #robot esce dal deposito=-1
    else if k == nodoArrivo then 1 #robot arriva al nodo cliente=1
    else 0;

#vincolo batteria (non far scendere la batteria sotto il 20%)
subject to Limite_Batteria:
    sum {(i,j) in A} energia[i,j] * x[i,j] <= 0.80 *cap_batteria;

#vincolo visita singola per ogni cliente
subject to Visita_Unica {c in C}:
    sum {(i,j) in A: nome_nodo_arrivo[i,j] == c and nome_nodo_partenza[i,j]!= c} x[i,j] == 1;
#conta solo gli archi che arrivano, non conta quelli che partono già dal nodo visitato (=non conta le soste come seconda visita)


