function [V_T] = NodiSpaceTime(N, limiti_nodi)
%NodiSpaceTime(insieme dei nodi, tempi limite consegna) 
%Per ogni nodo crea il nodo spazio-tempo se puo esistere rispetto ai 
%criteri di consegna
V_T = [];
for i=1:length(N)
    for t=0:1:47 %timegrid
    [a,b] = TimeWindow(limiti_nodi, N(i));
    if t>=a && t<=b
        V_T= [V_T; N(i)+string(t)]; %OGNI UNITA DI TEMPO RAPPRESENTA 15 minuti
    end
    end
end

end 