function [A_T] = ArchiSpaceTime(V_T,archi,TAU) %,TAU_T,p_T
%ArchiSpaceTime(V_T,...) GENERA LA TEN COMPLETA
A_T={}
V_T = string(V_T)
for i=1:length(archi)
    for t=0:1:47
        nodoPartenza = extractBetween(archi(i),1,1);
        nodoArrivo = extractBetween(archi(i),2,2);
        if ismember(string(string(nodoPartenza)+string(t)), V_T)
            periodo = Periodo(t);
            tarr = t + ceil(TempoPercorrenzaTau(nodoPartenza, nodoArrivo, periodo,TAU));
            %+tempo di servizio
            %energia e peso e costo
            if tarr <=47 && ismember(nodoArrivo+string(tarr),V_T)
                A_T{end+1} = nodoPartenza+string(t)+nodoArrivo+string(tarr);
            end
        end
    end

end
for i=1:length(V_T)
    nodoPartenza = extractBetween(V_T(i),1,1);
    t_str = extractAfter(V_T(i),1);
    t = str2double(t_str);
    tarr = t+1;
    if tarr <=47 && ismember(nodoPartenza+string(tarr),V_T)
        A_T{end+1} = nodoPartenza+string(t)+nodoPartenza+string(tarr);
        %energia e peso e costo
    end
end
