function out = amplNode(nomiNodi, sepInterno, sepAmpl)
%AMPLNODE Converte i nomi dei nodi spazio-temporali in identificatori AMPL.
%   Sostituisce il separatore interno con uno legale in AMPL, cosi' i nomi
%   non devono essere quotati nel file .dat.

    out = replace(string(nomiNodi(:)), sepInterno, sepAmpl);
end