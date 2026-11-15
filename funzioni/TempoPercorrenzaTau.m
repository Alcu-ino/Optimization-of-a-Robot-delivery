function Ttot = TempoPercorrenzaTau(da, a, periodo, archi)
%TEMPOPERCORRENZATAU Tempo di percorrenza dell'arco da->a nel periodo dato.

    SEP_ARCO = "@";

    da = string(da);
    a  = string(a);

    for k = 1:numel(archi)

        if isfield(archi(k),'da') && isfield(archi(k),'a')
            k_da = string(archi(k).da);
            k_a  = string(archi(k).a);
        else
            parti = split(string(archi(k).nome), SEP_ARCO);
            if numel(parti) ~= 2
                continue
            end
            k_da = parti(1);
            k_a  = parti(2);
        end

        if k_da == da && k_a == a
            Ttot = archi(k).tempoPercorrenza(periodo);
            return
        end
    end

    error("TempoPercorrenzaTau:arcoNonTrovato", ...
          "Nessun arco %s -> %s (periodo %d).", da, a, periodo);
end