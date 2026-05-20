function [Ttot] = TempoPercorrenzaTau(i,j,labelPeriodo,TAU)
%TempoPercorrenzaTau(start,end,mat/pom/sera) restituisce il tempo totale per
%andare da nodo i a nodo j in quell'istante di tempo

p = TAU(string(i)+string(j));
Ttot = p{1}(labelPeriodo);
end