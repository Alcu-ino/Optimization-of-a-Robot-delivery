function [a,b] = TimeWindow(limiti_nodi, nodo)
%TimeWindow(tempi limite consegna nodi (dizionario), nodo)
% restituisce il tempo limite superiore e inferiore per i tempi di consegna
tmp = limiti_nodi(nodo);
a = tmp{1}(1);
b = tmp{1}(2);
end