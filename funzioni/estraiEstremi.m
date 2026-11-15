function [da, a] = estraiEstremi(arco, SEP_ARCO)
% Ricava i nodi estremi di un arco fisico, dai campi 'da'/'a' se presenti,
% altrimenti dal campo 'nome' ("N1@N10").

    if isfield(arco,'da') && isfield(arco,'a')
        da = string(arco.da);
        a  = string(arco.a);
        return
    end

    parti = split(string(arco.nome), SEP_ARCO);
    if numel(parti) ~= 2
        error("ArchiSpaceTime:arcoMalformato", ...
              "Arco '%s' non nel formato NOME%sNOME.", arco.nome, SEP_ARCO);
    end
    da = parti(1);
    a  = parti(2);
end