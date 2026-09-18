%% LETTURA

SENS_BATTERIA = fullfile(pwd,'analisi','out_sens_batteria.txt');
if exist(SENS_BATTERIA, 'file')
    sens_data = readmatrix(SENS_BATTERIA, 'CommentStyle', '#');
    type('out_sens_batteria.txt')     % stampa il file grezzo
    cap_vals  = sens_data(:, 1);
    OF_vals = sens_data(:, 9);
else
    sens_data = [];
end


TRADE_E_P = fullfile(pwd,'analisi','out_pareto_pesi_energia_penale.txt');
if exist(TRADE_E_P, 'file')
    pareto_data_EP = readmatrix(TRADE_E_P, 'CommentStyle', '#');
    penalita_EP    = pareto_data_EP(:, 8);
    energia_EP   = pareto_data_EP(:, 5);
    p_OF_EP = pareto_data_EP(:,9);
else
    pareto_data_EP = [];
end


TRADE_E_R = fullfile(pwd,'analisi','out_pareto_pesi_energia_ritardo.txt');
if exist(TRADE_E_R, 'file')
    pareto_data_ER = readmatrix(TRADE_E_R, 'CommentStyle', '#');
    ritardo_ER    = pareto_data_ER(:, 7);
    energia_ER   = pareto_data_ER(:, 5);
    p_OF_ER = pareto_data_ER(:,9);
else
    pareto_data_ER = [];
end


TRADE_P_R = fullfile(pwd,'analisi','out_pareto_pesi_penale_ritardo.txt');
if exist(TRADE_P_R, 'file')
    pareto_data_P_R = readmatrix(TRADE_P_R, 'CommentStyle', '#');
    penalita_P_R    = pareto_data_P_R(:, 8);
    ritardo_P_R   = pareto_data_P_R(:, 7);
    p_OF_P_R = pareto_data_P_R(:,9);
else
    pareto_data_P_R = [];
end


TRADE_T_R = fullfile(pwd,'analisi','out_pareto_pesi_tempo_ritardo.txt');
if exist(TRADE_T_R, 'file')
    pareto_data_T_R = readmatrix(TRADE_T_R, 'CommentStyle', '#');
    tempo_T_R    = pareto_data_T_R(:, 6);
    ritardo_T_R   = pareto_data_T_R(:, 7);
    p_OF_T_R = pareto_data_T_R(:,9);
else
    pareto_data_T_R = [];
end

%% Generazione Grafici
figure('Name', 'Analisi e Ottimizzazione AMPL', 'Position', [100, 100, 1000, 450]);

%BATTERIA SENSITIVITY
subplot(3, 2, 1);
if ~isempty(sens_data)
    plot(cap_vals, OF_vals, '-o', 'LineWidth', 2, 'MarkerSize', 6, 'Color', 'b');
    grid on;
    title('Sensitività: Cap. Batteria vs Valore Funzione Obiettivo');
    xlabel('Capacità Batteria');
    ylabel('OF');
end

%PARETO ENERGY VS PENALTY
subplot(3, 2, 2);
if ~isempty(pareto_data_EP)
    plot(energia_EP, penalita_EP,'-o', 'LineWidth', 2, 'MarkerSize', 6, 'Color', 'b');
    grid on;
    title('Frontiera di Pareto: Energia vs Penalità');
    xlabel('Valori energia');
    ylabel('Valori penalità');
end

%PARETO ENERGY VS DELAY
subplot(3, 2, 3);
if ~isempty(pareto_data_ER)
    plot(energia_ER, ritardo_ER,'-o', 'LineWidth', 2, 'MarkerSize', 6, 'Color', 'b');
    grid on;
    title('Frontiera di Pareto: Energia vs Ritardo');
    xlabel('Valori energia');
    ylabel('Valori ritardo');
end

%PARETO PENALTY VS DELAY
subplot(3, 2, 4);
if ~isempty(pareto_data_P_R)
    plot(penalita_P_R, ritardo_P_R,'-o', 'LineWidth', 2, 'MarkerSize', 6, 'Color', 'b');
    grid on;
    title('Frontiera di Pareto: Penalità vs Ritardo');
    xlabel('Valori penalità');
    ylabel('Valori ritardo');
end

%PARETO TIME VS DELAY
subplot(3, 2, 5);
if ~isempty(pareto_data_T_R)
    plot(tempo_T_R, ritardo_T_R,'-o', 'LineWidth', 2, 'MarkerSize', 6, 'Color', 'b');
    grid on;
    title('Frontiera di Pareto: Tempo vs Ritardo');
    xlabel('Valori tempo');
    ylabel('Valori ritardo');
end
