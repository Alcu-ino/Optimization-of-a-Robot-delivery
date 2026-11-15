function [A_T] = ArchiSpaceTime(V_T, archi, T_MAX)
%ARCHISPACETIME Genera gli archi della TEN.
%   A_T = ArchiSpaceTime(V_T, archi, T_MAX)
%   Nodi spazio-temporali nel formato "NOME:TEMPO" (es. "N10:12").
%   Archi della TEN nel formato "NOME:TEMPO@NOME:TEMPO" (es. "N1:4@N10:7").
%   Gli archi in input hanno i campi 'da'/'a' oppure un campo 'nome'
%   nel formato "NOME_PARTENZA@NOME_ARRIVO" (es. "N1@N10").
%   'energia' e 'tempoPercorrenza' possono essere scalari oppure vettori
%   con un valore per fascia oraria (vedi Periodo).
%
%   CORREZIONI:
%   - T_MAX e' un argomento (prima era fisso a 47 anche se il main ne
%     usava un altro); se omesso vale 47.
%   - Il tempo di viaggio e' letto direttamente dall'arco in esame, senza
%     ricercarlo ogni volta in tutta la lista (stesso risultato, molto
%     piu' veloce).
%   - Appartenenza a V_T con una mappa invece di ismember su stringhe.

    if nargin < 3 || isempty(T_MAX)
        T_MAX = 47;
    end
    SEP_NODO = ":";
    SEP_ARCO = "@";

    V_T = string(V_T(:));
    inV = containers.Map(cellstr(V_T), true(numel(V_T), 1));

    lista = {};

    % ---------- archi di movimento ----------
    for i = 1:numel(archi)

        [nodoPartenza, nodoArrivo] = estraiEstremi(archi(i), SEP_ARCO);

        for t = 0:T_MAX
            da_nodo = nodoPartenza + SEP_NODO + string(t);
            if ~isKey(inV, char(da_nodo))
                continue
            end

            periodo       = Periodo(t);
            tempo_viaggio = ceil(valoreFascia(archi(i).tempoPercorrenza, periodo));
            if tempo_viaggio < 1
                error("ArchiSpaceTime:tempoNonValido", ...
                      "Tempo di percorrenza < 1 slot sull'arco %s -> %s.", ...
                      nodoPartenza, nodoArrivo);
            end
            tarr = t + tempo_viaggio;

            if tarr > T_MAX
                continue
            end

            a_nodo = nodoArrivo + SEP_NODO + string(tarr);
            if ~isKey(inV, char(a_nodo))
                continue
            end

            arco = struct();
            arco.nome               = char(da_nodo + SEP_ARCO + a_nodo);
            arco.costo              = archi(i).costo;
            arco.energia            = valoreFascia(archi(i).energia, periodo);
            arco.tempoPercorrenza   = tempo_viaggio;
            arco.nome_nodo_partenza = char(nodoPartenza);
            arco.nome_nodo_arrivo   = char(nodoArrivo);
            arco.da_nodo            = char(da_nodo);
            arco.a_nodo             = char(a_nodo);

            lista{end+1,1} = arco; %#ok<AGROW>
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
        if ~isKey(inV, char(a_nodo))
            continue
        end

        arco = struct();
        arco.nome               = char(da_nodo + SEP_ARCO + a_nodo);
        arco.costo              = 0;
        arco.energia            = 0;
        arco.tempoPercorrenza   = 1;   % attesa di uno slot
        arco.nome_nodo_partenza = char(nodoPartenza);
        arco.nome_nodo_arrivo   = char(nodoPartenza);
        arco.da_nodo            = char(da_nodo);
        arco.a_nodo             = char(a_nodo);

        lista{end+1,1} = arco; %#ok<AGROW>
    end

    if isempty(lista)
        A_T = struct('nome',{}, 'costo',{}, 'energia',{}, 'tempoPercorrenza',{}, ...
                     'nome_nodo_partenza',{}, 'nome_nodo_arrivo',{}, ...
                     'da_nodo',{}, 'a_nodo',{});
    else
        A_T = vertcat(lista{:});
    end
end

function v = valoreFascia(valori, periodo)
% Valore della fascia oraria; se il dato e' scalare vale per tutte le fasce.
    if isscalar(valori)
        v = valori;
    else
        v = valori(periodo);
    end
end
