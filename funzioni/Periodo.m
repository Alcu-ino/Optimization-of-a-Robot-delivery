function [time] = Periodo(t)
%PERIODO Indice di fascia oraria (1, 2, 3) dello slot t.
%   Serve per leggere i valori per fascia degli archi (energia, tempo).
%   Slot da 15 minuti a partire dalle 8:00.
%     1 = MATTINA     slot  0..15  ( 8:00 - 12:00)
%     2 = POMERIGGIO  slot 16..40  (12:00 - 18:15)
%     3 = SERA        slot 41..    (18:15 in poi)
%
%   CORREZIONE: la condizione era t > 0, quindi lo slot 0 finiva nella
%   fascia SERA. Ora lo slot 0 e' MATTINA.

    if t >= 0 && t < 4*4
        time = 1; % MATTINA
    elseif t >= 4*4 && t <= 10*4
        time = 2; % POMERIGGIO
    else
        time = 3; % SERA
    end
end
