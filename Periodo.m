function [time] = Periodo(t)
%Periodo(t) restituisce l'indice 1 2 3 per accedere alle rispettive label
%di percorrensa degli archi in base al tempo

if t>0 && t < 4*4
    time = 1; %'MATTINA';
elseif t >= 4*4 && t <= 10*4
    time = 2; %'POMERIGGIO';
else 
    time = 3; %'SERA';
end

end