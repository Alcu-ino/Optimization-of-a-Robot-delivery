function [A_T] = ArchiSpaceTime(V_T, archi)
%ARCHISPACETIME Genera la TEN completa.
%   Nodi spazio-temporali nel formato "NOME:TEMPO" (es. "N10:12").
%   Archi della TEN nel formato "NOME:TEMPO@NOME:TEMPO" (es. "N1:4@N10:7").
%   Gli archi in input hanno i campi 'da'/'a' oppure un campo 'nome'
%   nel formato "NOME_PARTENZA@NOME_ARRIVO" (es. "N1@N10").

    T_MAX    = 47;
    SEP_NODO = ":";
    SEP_ARCO = "@";

    V_T = string(V_T(:));

    A_T = struct('nome',{}, 'costo',{}, 'energia',{}, 'tempoPercorrenza',{}, ...
                 'nome_nodo_partenza',{}, 'nome_nodo_arrivo',{}, ...
                 'da_nodo',{}, 'a_nodo',{});

    % ---------- archi di movimento ----------
    for i = 1:numel(archi)

        [nodoPartenza, nodoArrivo] = estraiEstremi(archi(i), SEP_ARCO);

        for t = 0:T_MAX
            da_nodo = nodoPartenza + SEP_NODO + string(t);
            if ~ismember(da_nodo, V_T)
                continue
            end

            periodo       = Periodo(t);
            tempo_viaggio = ceil(TempoPercorrenzaTau(nodoPartenza, nodoArrivo, periodo, archi));
            tarr          = t + tempo_viaggio;

            if tarr > T_MAX
                continue
            end

            a_nodo = nodoArrivo + SEP_NODO + string(tarr);
            if ~ismember(a_nodo, V_T)
                continue
            end

            arco = struct();
            arco.nome               = char(da_nodo + SEP_ARCO + a_nodo);
            arco.costo              = archi(i).costo;
            arco.energia            = archi(i).energia(periodo);
            arco.tempoPercorrenza   = tempo_viaggio;
            arco.nome_nodo_partenza = char(nodoPartenza);
            arco.nome_nodo_arrivo   = char(nodoArrivo);
            arco.da_nodo            = char(da_nodo);
            arco.a_nodo             = char(a_nodo);

            A_T(end+1,1) = arco; %#ok<AGROW>
        end
    end

    % ---------- archi di attesa (holding) ----------
    for i = 1:numel(V_T)
        da_nodo = V_T(i);

        parti = split(da_nodo, SEP_NODO);
        if numel(parti) ~= 2
            error("ArchiSpaceTime:nodoMalformato", ...
                  "Nodo '%s' non nel formato NOME%sTEMPO.", da_nodo, SEP_NODO);
        end
        nodoPartenza = parti(1);
        t            = str2double(parti(2));

        tarr = t + 1;
        if tarr > T_MAX
            continue
        end

        a_nodo = nodoPartenza + SEP_NODO + string(tarr);
        if ~ismember(a_nodo, V_T)
            continue
        end

        arco = struct();
        arco.nome               = char(da_nodo + SEP_ARCO + a_nodo);
        arco.costo              = 0;
        arco.energia            = 0;
        arco.tempoPercorrenza   = 1;   % 0 ma perdo 1 dt
        arco.nome_nodo_partenza = char(nodoPartenza);
        arco.nome_nodo_arrivo   = char(nodoPartenza);
        arco.da_nodo            = char(da_nodo);
        arco.a_nodo             = char(a_nodo);

        A_T(end+1,1) = arco; %#ok<AGROW>
    end
end