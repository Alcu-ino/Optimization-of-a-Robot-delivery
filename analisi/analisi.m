%% =======================================================================
%  ANALISI DEI RISULTATI — sensitivita' batteria e frontiere di Pareto
%  Legge i file prodotti dagli script AMPL (cartella 'analisi'):
%    analisi_sens_batteria.run               -> out_sens_batteria.txt
%    analisi_pareto_pesi_<A>_<B>.run         -> out_pareto_pesi_<A>_<B>.txt
%  Ogni file puo' mancare: il relativo grafico viene saltato.
%
%  CORREZIONI RISPETTO ALLA VERSIONE PRECEDENTE:
%   - Percorsi relativi alla cartella dello script, non a pwd; 'type'
%     usava un nome di file senza cartella.
%   - Colonne lette per nome dall'intestazione, non per posizione.
%   - Sono usati solo i punti con una soluzione (stato 0 o 1); quelli al
%     limite di tempo sono disegnati vuoti, gli altri esclusi e contati.
%   - Il metodo pesi-somma puo' dare punti ripetuti o dominati: la
%     frontiera disegnata e' solo quella dei punti non dominati, ordinata.
%   - Penale sostituita dal numero di pacchi non consegnati.
%   - Tempo = tempo operativo (prima era sempre 47).
%   - Avviso se una frontiera degenera in un solo punto.
%  =======================================================================

dirAnalisi = fullfile(pwd, 'analisi');

STATO_NOMI = ["ottimo", "limite di tempo", "infeasible", "nessuna soluzione"];

% esperimento | colonna x | colonna y | etichetta x | etichetta y
ESPERIMENTI = {
    'energia_penale',  'energia',        'non_consegnati', 'Energia consumata (% batteria)', 'Pacchi non consegnati'
    'energia_ritardo', 'energia',        'ritardo',        'Energia consumata (% batteria)', 'Ritardo totale (slot)'
    'penale_ritardo',  'non_consegnati', 'ritardo',        'Pacchi non consegnati',          'Ritardo totale (slot)'
    'tempo_ritardo',   'tempo_op',       'ritardo',        'Tempo operativo (slot)',         'Ritardo totale (slot)'
    'energia_tempooperativo', 'energia',     'tempo_op',       'Energia consumata (% batteria)', 'Tempo operativo (slot)'
};

%% ---------- LETTURA ----------------------------------------------------
sens = leggiRisultati(fullfile(dirAnalisi, 'out_sens_batteria.txt'), STATO_NOMI);

pareto = cell(size(ESPERIMENTI, 1), 1);
for k = 1:size(ESPERIMENTI, 1)
    f = fullfile(dirAnalisi, "out_pareto_pesi_" + ESPERIMENTI{k,1} + ".txt");
    pareto{k} = leggiRisultati(f, STATO_NOMI);
end

%% ---------- GRAFICI ----------------------------------------------------
figure('Name', 'Analisi e Ottimizzazione AMPL', 'Position', [100, 50, 1100, 1150]);
tl = tiledlayout(4, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(tl, 'Robot delivery: sensitivita'' e frontiere di Pareto');

% --- Sensitivita' alla capacita' della batteria ---
nexttile;
if ~isempty(sens)
    ok = sens.stato <= 1;
    s  = sortrows(sens(ok, :), 'cap_batteria');
    lim = s.stato == 1;

    yyaxis left
    plot(s.cap_batteria, s.obiettivo, '-o', 'LineWidth', 1.5, 'MarkerFaceColor', 'auto');
    hold on
    plot(s.cap_batteria(lim), s.obiettivo(lim), 'o', 'MarkerSize', 10, 'LineWidth', 1.5);
    ylabel('Funzione obiettivo');

    yyaxis right
    plot(s.cap_batteria, s.consegnati, '-s', 'LineWidth', 1.5);
    ylabel('Pacchi consegnati');
    hold off

    set(gca, 'XScale', 'log');
    grid on
    xlabel('Capacita'' batteria');
    title(titoloConEsclusi('Sensitivita'': capacita'' batteria', sum(~ok), sum(lim)));
else
    text(0.5, 0.5, 'out\_sens\_batteria.txt non trovato', 'HorizontalAlignment', 'center');
    axis off
end

% --- Frontiere di Pareto ---
for k = 1:size(ESPERIMENTI, 1)
    nexttile;
    T = pareto{k};
    nomeEsp = strrep(strrep(ESPERIMENTI{k,1}, 'tempooperativo', 'tempo operativo'), '_', ' vs ');
    if isempty(T)
        text(0.5, 0.5, "out\_pareto\_pesi\_" + strrep(ESPERIMENTI{k,1}, '_', '\_') + ".txt non trovato", ...
             'HorizontalAlignment', 'center');
        axis off
        continue
    end

    ok  = T.stato <= 1;
    T   = T(ok, :);
    xv  = T.(ESPERIMENTI{k,2});
    yv  = T.(ESPERIMENTI{k,3});
    lim = T.stato == 1;

    nd = nonDominati(xv, yv);
    [xf, ord] = sort(xv(nd));
    yf = yv(nd);  yf = yf(ord);

    % tutti i punti: pieni = ottimi, vuoti = limite di tempo
    plot(xv(~lim), yv(~lim), 'o', 'MarkerFaceColor', [0.3 0.5 0.9], ...
         'MarkerEdgeColor', 'k', 'MarkerSize', 7);
    hold on
    plot(xv(lim), yv(lim), 'o', 'MarkerEdgeColor', [0.3 0.5 0.9], ...
         'LineWidth', 1.5, 'MarkerSize', 7);
    plot(xf, yf, '-', 'Color', [0.85 0.2 0.2], 'LineWidth', 1.5);

    % peso del secondo obiettivo (3a colonna, es. w_penale) accanto a ogni punto
    for i = 1:height(T)
        text(xv(i), yv(i), sprintf('  %.2f', T{i, 3}), 'FontSize', 8, ...
             'VerticalAlignment', 'bottom');
    end
    hold off
    grid on
    xlabel(ESPERIMENTI{k,4});
    ylabel(ESPERIMENTI{k,5});
    title(titoloConEsclusi("Pareto: " + nomeEsp, sum(~ok), sum(lim)));

    if numel(unique([xv yv], 'rows')) <= 2
        warning("Frontiera %s: tutti i punti coincidono, i pesi non cambiano la soluzione.", ...
                ESPERIMENTI{k,1});
    end
end

% --- Legenda e note ---
nexttile;
axis off
text(0, 0.85, '\bf Legenda', 'FontSize', 10);
text(0, 0.70, '\color[rgb]{0.3 0.5 0.9}\bullet\color{black}  soluzione ottima', 'FontSize', 9);
text(0, 0.58, '\circ  limite di tempo (non dimostrata ottima)', 'FontSize', 9);
text(0, 0.46, '\color[rgb]{0.85 0.2 0.2}---\color{black}  frontiera dei punti non dominati', 'FontSize', 9);
text(0, 0.34, 'Numero accanto ai punti: peso del 2° obiettivo', 'FontSize', 9);
text(0, 0.22, 'I due obiettivi si dividono 0.4; gli altri pesi restano 0.2', 'FontSize', 9);

%% ---------- TABELLE A CONSOLE -----------------------------------------
if ~isempty(sens)
    fprintf('\n=== SENSITIVITA'': CAPACITA'' BATTERIA ===\n');
    disp(sens(:, {'cap_batteria','stato','gap','energia','consegnati','ritardo','soc_min','obiettivo'}));
end
for k = 1:size(ESPERIMENTI, 1)
    if isempty(pareto{k}), continue; end
    fprintf('\n=== PARETO: %s ===\n', ESPERIMENTI{k,1});
    nomiCol = pareto{k}.Properties.VariableNames;   % colonne 2-3: pesi dei due obiettivi
    disp(pareto{k}(:, [nomiCol(1:3), {'stato','gap','costo','energia', ...
                       'tempo_op','ritardo','consegnati','obiettivo'}]));
end

%% =======================================================================
%  FUNZIONI LOCALI
%  =======================================================================
function T = leggiRisultati(file, STATO_NOMI)
% Legge un file di analisi.run; [] se il file non esiste.
    if ~isfile(file)
        warning("File non trovato: %s", file);
        T = [];
        return
    end
    opts = detectImportOptions(file, 'FileType', 'text', 'Delimiter', ' ', ...
                               'ConsecutiveDelimitersRule', 'join');
    opts = setvartype(opts, 'double');
    opts.MissingRule = 'fill';
    T = readtable(file, opts);

    assert(ismember('stato', T.Properties.VariableNames), ...
           "Formato non riconosciuto in %s: rigenerare con gli script analisi_*.run.", file);

    [~, nome] = fileparts(file);
    conteggi = arrayfun(@(s) sum(T.stato == s), 0:3);
    fprintf("%s: %d punti (%s)\n", nome, height(T), ...
            strjoin(compose("%s %d", STATO_NOMI(:), conteggi(:)), ", "));
end

function nd = nonDominati(x, y)
% Indici logici dei punti non dominati (entrambi gli obiettivi da minimizzare).
% Tra punti identici ne viene tenuto uno solo.
    n  = numel(x);
    nd = true(n, 1);
    for i = 1:n
        domina = x <= x(i) & y <= y(i) & (x < x(i) | y < y(i));
        uguale = x == x(i) & y == y(i) & (1:n)' < i;
        nd(i)  = ~any(domina) && ~any(uguale);
    end
end

function t = titoloConEsclusi(base, nEsclusi, nLimite)
    t = string(base);
    note = strings(0);
    if nLimite > 0,  note(end+1) = sprintf("%d al limite", nLimite); end
    if nEsclusi > 0, note(end+1) = sprintf("%d senza soluzione", nEsclusi); end
    if ~isempty(note), t = t + " (" + strjoin(note, ", ") + ")"; end
end
