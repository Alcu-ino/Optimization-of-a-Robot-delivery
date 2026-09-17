SENS_BATTERIA = fullfile(pwd,'analisi','out_sens_batteria.txt');

if exist(SENS_BATTERIA, 'file')
    sens_data = readmatrix(SENS_BATTERIA, 'CommentStyle', '#');
    type('out_sens_batteria.txt')     % stampa il file grezzo
    cap_vals  = sens_data(:, 1);
    cost_vals = sens_data(:, 9);
else
    sens_data = [];
end

TRADE = fullfile(pwd,'analisi','out_pareto_pesi.txt');


if exist(TRADE, 'file')
    pareto_data = readmatrix(TRADE, 'CommentStyle', '#');
    w_vals      = pareto_data(:, 1);
    penalita    = pareto_data(:, 7);
    p_energie   = pareto_data(:, 4);
    p_OF = pareto_data(:,7);
else
    pareto_data = [];
end

% Stampa tabelle
if ~isempty(sens_data)
    disp(table(cap_vals, cost_vals, 'VariableNames', {'Capacita_Batteria', 'Costo_Totale'}));
end
if ~isempty(pareto_data)
    disp(table(w_vals, p_tempo, p_energie, 'VariableNames', {'Peso_Costo_Tempo', 'Tempo', 'Energia_Consumata'}));
end

% Generazione Grafici
figure('Name', 'Analisi e Ottimizzazione AMPL', 'Position', [100, 100, 1000, 450]);

subplot(1, 2, 1);
if ~isempty(sens_data)
    plot(cap_vals, cost_vals, '-o', 'LineWidth', 2, 'MarkerSize', 6, 'Color', 'b');
    grid on;
    title('Sensitività: Cap. Batteria vs Costo');
    xlabel('Capacità Batteria');
    ylabel('Costo Totale');
end

subplot(1, 2, 2);
if ~isempty(pareto_data)
    plot(p_energie,penalita,'r*');
    grid on;
    title('Frontiera di Pareto: Energia vs Penalità');
    xlabel('Valori energia');
    ylabel('Valori penalità');
end