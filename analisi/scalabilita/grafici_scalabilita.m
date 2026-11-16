%% =======================================================================
%  GRAFICI_SCALABILITA — tempo di soluzione in funzione del parametro
%  incrementato, per i quattro esperimenti lanciati da lancia_scalabilita.m
%
%    analisi/out_scal_clienti.txt   parametro: numero di clienti
%    analisi/out_scal_pacchi.txt    parametro: pacchi per cliente
%    analisi/out_scal_finestre.txt  parametro: larghezza della finestra [h]
%    analisi/out_scal_apertura.txt  parametro: durata dell'orario di apertura [h]
%
%  Riga in alto: tempo di soluzione (scala log), con il limite di 600 s.
%  Riga in basso: gap a fine solve, con la soglia di arresto; per l'apertura
%  anche il numero di variabili (asse destro), perche' li' cresce la rete.
%  Marcatori: pieno = ottimo (entro il mipgap), vuoto = limite di tempo,
%  croce rossa = nessuna soluzione, quadrato verde = soluzione riusata
%  dall'esperimento clienti, cerchio rosso = passo di arresto.
%  Ogni file puo' mancare: la relativa colonna resta vuota.
%  =======================================================================

dirAnalisi = fullfile(pwd, 'analisi/scalabilita/');

TIMELIMIT = 600;    % come nei .run
GAP_STOP  = 0.05;   % come in lancia_scalabilita.m

ESP = {
    'clienti',  'n_clienti',          'Numero di clienti'
    'pacchi',   'pacchi_per_cliente', 'Pacchi per cliente'
    'finestre', 'tw_ore',             'Larghezza della finestra [h]'
    'apertura', 'ap_ore',             'Orario di apertura dei clienti [h]'
};
BLU = [0.3 0.5 0.9];  ROSSO = [0.85 0.2 0.2];  VERDE = [0.2 0.6 0.2];

figure('Name', 'Scalabilita''', 'Position', [60 100 1700 750]);
tl = tiledlayout(2, size(ESP, 1), 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Robot delivery: scalabilita'' di Ampl\_Main.mod');

for k = 1:size(ESP, 1)
    file = fullfile(dirAnalisi, "out_scal_" + ESP{k,1} + ".txt");
    axT  = nexttile(tl, k);
    axG  = nexttile(tl, k + size(ESP, 1));
    if ~isfile(file)
        text(axT, 0.5, 0.5, "manca out\_scal\_" + ESP{k,1} + ".txt", 'HorizontalAlignment', 'center');
        axis(axT, 'off');  axis(axG, 'off');
        continue
    end

    T = leggiOutScal(file);
    x = T.(ESP{k,2});
    t = T.secondi;
    ott   = T.stato == 0;
    lim   = T.stato == 1;
    noSol = T.stato >= 2;
    nota  = T.origine == 1;
    arresto = T.stato(end) >= 2 || T.gap(end) >= GAP_STOP;

    % --- tempo di soluzione ----------------------------------------------
    hold(axT, 'on');  grid(axT, 'on');
    plot(axT, x, t, '-', 'Color', BLU, 'LineWidth', 1.3, 'HandleVisibility', 'off');
    if any(ott),   plot(axT, x(ott), t(ott), 'o', 'MarkerFaceColor', BLU, 'MarkerEdgeColor', 'k', 'DisplayName', 'ottimo'); end
    if any(lim),   plot(axT, x(lim), t(lim), 'o', 'MarkerEdgeColor', BLU, 'LineWidth', 1.3, 'DisplayName', 'limite di tempo'); end
    if any(noSol), plot(axT, x(noSol), t(noSol), 'x', 'Color', ROSSO, 'MarkerSize', 10, 'LineWidth', 1.5, 'DisplayName', 'nessuna soluzione'); end
    if any(nota),  plot(axT, x(nota), t(nota), 's', 'MarkerSize', 11, 'MarkerEdgeColor', VERDE, 'LineWidth', 1.3, 'DisplayName', 'riusata da clienti'); end
    if arresto,    plot(axT, x(end), t(end), 'o', 'MarkerSize', 14, 'MarkerEdgeColor', ROSSO, 'LineWidth', 1.5, 'DisplayName', 'arresto'); end
    yline(axT, TIMELIMIT, '--', sprintf('limite %d s', TIMELIMIT), 'HandleVisibility', 'off');
    set(axT, 'YScale', 'log');
    xlabel(axT, ESP{k,3});
    ylabel(axT, 'Tempo di soluzione [s]');
    if k == 1
        title(axT, "Clienti (1 pacco, finestra " + T.tw_ore(1) + " h)");
    elseif k == 2
        title(axT, "Pacchi (" + T.n_clienti(1) + " clienti, finestra " + T.tw_ore(1) + " h)");
    elseif k == 3
        title(axT, "Finestre (" + T.n_clienti(1) + " clienti, 1 pacco)");
    else
        title(axT, "Apertura (" + T.n_clienti(1) + " clienti, 1 pacco, finestra " + T.tw_ore(1) + " h)");
    end
    legend(axT, 'Location', 'northwest');

    % --- gap a fine solve -------------------------------------------------
    hold(axG, 'on');  grid(axG, 'on');
    plot(axG, x, 100 * T.gap, '-o', 'Color', BLU, 'LineWidth', 1.3);
    yline(axG, 100 * GAP_STOP, '--', sprintf('arresto %g%%', 100 * GAP_STOP), 'Color', ROSSO);
    xlabel(axG, ESP{k,3});
    ylabel(axG, 'Gap a fine solve [%]');
    if strcmp(ESP{k,1}, 'apertura')               % qui cresce la rete: si mostra anche la dimensione
        yyaxis(axG, 'right');
        plot(axG, x, T.nvars, '-s', 'LineWidth', 1.1);
        ylabel(axG, 'Variabili del modello');
        yyaxis(axG, 'left');
    end

    fprintf('\n=== SCALABILITA'': %s ===\n', ESP{k,1});
    disp(T(:, {'n_clienti', 'pacchi_per_cliente', 'n_pacchi', 'tw_ore', 'stato', 'gap', ...
               'secondi', 'nvars', 'consegnati', 'ritardo', 'origine'}));
end

%% =======================================================================
function T = leggiOutScal(file)
% Legge un file out_scal_*.txt (intestazione + righe separate da spazi).
    opts = detectImportOptions(file, 'FileType', 'text', 'Delimiter', ' ', ...
                               'ConsecutiveDelimitersRule', 'join');
    opts = setvartype(opts, 'double');
    T = readtable(file, opts);
end
