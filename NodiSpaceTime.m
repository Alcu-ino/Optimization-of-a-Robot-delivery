function [V_T] = NodiSpaceTime(N, limiti_nodi)
%NODISPACETIME Genera i nodi spazio-temporali nel formato "NOME:TEMPO".
%   Per ogni nodo crea un nodo spazio-tempo per ogni istante della timegrid
%   compatibile con la finestra temporale del nodo.
%   Ogni unità di tempo rappresenta 15 minuti.

    T_MAX    = 47;
    SEP_NODO = ":";

    N   = string(N(:));
    V_T = strings(0,1);

    for i = 1:numel(N)
        [a, b] = TimeWindow(limiti_nodi, N(i));   % una sola chiamata per nodo

        for t = 0:T_MAX
            if t >= a && t <= b
                V_T(end+1,1) = N(i) + SEP_NODO + string(t); %#ok<AGROW>
            end
        end
    end
end