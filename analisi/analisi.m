%% 1. CONFIGURAZIONE DEI PATH (Usa la cartella corrente di MATLAB)
AMPL_HOME  = '/home/vito/Scrivania/ampl';

MOD_FILE   = fullfile(pwd, 'Scrivania', 'optimization', ...
                      'Optimization-of-a-Robot-delivery-1', 'Ampl_Main.mod');
DAT_FILE   = fullfile(pwd, 'Scrivania', 'optimization', ...
                      'Optimization-of-a-Robot-delivery-1','archi_temp.dat');
run_filename = fullfile(pwd,'Scrivania', 'optimization', ...
                      'Optimization-of-a-Robot-delivery-1','analisi','analisi.run');

ampl = com.ampl.AMPL(com.ampl.Environment(AMPL_HOME));
ampl.reset();
disp('Caricamento del modello...');
ampl.read(MOD_FILE);
    
disp('Caricamento dei dati...');
ampl.readData(DAT_FILE);
    
ampl.setOption('solver', 'cplex');

%% 3. ESECUZIONE DEL SCRIPT .RUN TRAMITE API JAVA
disp('Esecuzione dello script di analisi in corso...');
ampl.eval(['include ', run_filename, ';']);

% Chiusura della sessione AMPL
disp('Elaborazione AMPL completata con successo!');

%% 4. LETTURA DEI RISULTATI E PLOT IN MATLAB
SENS_BATTERIA = fullfile(pwd,'Scrivania', 'optimization', ...
                      'Optimization-of-a-Robot-delivery-1','analisi','out_sens_batteria.txt');

if exist(SENS_BATTERIA, 'file')
    sens_data = readmatrix(SENS_BATTERIA, 'CommentStyle', '#');
    type('out_sens_batteria.txt')     % stampa il file grezzo
    cap_vals  = sens_data(:, 1);
    cost_vals = sens_data(:, 9);
else
    sens_data = [];
end

TRADE = fullfile(pwd,'Scrivania', 'optimization', ...
                      'Optimization-of-a-Robot-delivery-1','analisi','out_pareto_pesi.txt');


if exist(TRADE, 'file')
    pareto_data = readmatrix(TRADE, 'CommentStyle', '#');
    w_vals      = pareto_data(:, 1);
    p_tempo    = pareto_data(:, 5);
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
    [p_tempo_sorted, idx_sortT] = sort(p_tempo);
    [p_energie_sorted , idx_sortE]= sort(p_energie);
    p_OF_sortedT = p_OF(idx_sortT);
    p_OF_sortedE = p_OF(idx_sortE);
    plot(p_energie_sorted, p_OF_sortedE,'b--', p_tempo_sorted,p_OF_sortedT,'r--');
    grid on;
    title('Frontiera di Pareto: Costo vs Energia');
    xlabel('Valori energia e tempo');
    ylabel('Funzione obiettivo');
end

figure('Name', 'Analisi e Ottimizzazione AMPL');
p_energie_sorted = p_energie(idx_sortT)
plot(p_energie_sorted,p_tempo_sorted,'r*');
grid on;
title('Frontiera di Pareto: Costo vs Energia');
xlabel('Valori energia e tempo');
ylabel('Funzione obiettivo');