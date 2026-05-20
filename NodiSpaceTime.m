function [V_T] = NodiSpaceTime(N, limiti_nodi)
%NodiSpaceTime(insieme dei nodi, tempi limite consegna, Tfin?) 
%Per ogni nodo crea il nodo spazio-tempo se puo esistere rispetto ai 
%criteri di consegna
V_T = {};
for i=1:length(N)
    for t=0:1:47%timegrid
    [a,b] = TimeWindow(limiti_nodi, N(i));
    if t>=a && t<=b
        V_T{end+1} = N(i)+string(t); %il tempo rappresenta? minuti ore secondi !!
    end
    end
end

end 