function [A_T] = ArchiSpaceTime(V_T,archi) %,TAU_T,p_T
%ArchiSpaceTime(V_T,...) GENERA LA TEN COMPLETA
A_T={};
V_T = string(V_T);
for i=1:length(archi)
    for t=0:1:47
        nodoPartenza = extractBetween(archi(i).nome,1,1);
        nodoArrivo = extractBetween(archi(i).nome,2,2);
        da_nodo = nodoPartenza + string(t);

        if ismember(da_nodo, V_T)
            periodo = Periodo(t);
            tempo_viaggio = ceil(TempoPercorrenzaTau(nodoPartenza, nodoArrivo, periodo,archi));
            tarr = t + tempo_viaggio;
            %+tempo di servizio
            %energia e peso e costo
            a_nodo = nodoArrivo + string(tarr);
            if tarr <=47 && ismember(a_nodo,V_T)
                arco = struct();
                arco.costo              = archi(i).costo;  
                arco.energia            = archi(i).energia(periodo);  
                arco.tempoPercorrenza   = tempo_viaggio;
                arco.nome_nodo_partenza = char(nodoPartenza);
                arco.nome_nodo_arrivo   = char(nodoArrivo);
                arco.da_nodo            = char(da_nodo);
                arco.a_nodo             = char(a_nodo);

                A_T = [A_T; arco];
            end
        end
    end

end
for i=1:length(V_T)
    da_nodo = V_T(i);

    nodoPartenza = extractBefore(da_nodo, 2);
    
    t_str = extractAfter(da_nodo,1);
    t = str2double(t_str);
    tarr = t+1;
    a_nodo = nodoPartenza + string(tarr);

    
    if tarr <=47 && ismember(a_nodo,V_T)
        arco = struct();
        arco.costo              = 0;  
        arco.energia            = 0;  
        arco.tempoPercorrenza   = 1; %0 ma perdo 1 dt
        arco.nome_nodo_partenza = char(nodoPartenza);
        arco.nome_nodo_arrivo   = char(nodoPartenza);
        arco.da_nodo            = char(da_nodo);
        arco.a_nodo             = char(a_nodo);
        %energia e peso e costo
        A_T = [A_T; arco];

    end
end
