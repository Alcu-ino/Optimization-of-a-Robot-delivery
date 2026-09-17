%% 1. CONFIGURAZIONE DEI PATH (Usa la cartella corrente di MATLAB)
AMPL_HOME  = '/home/vito/Scrivania/TOOLS/AMPL';

MOD_FILE   = fullfile(pwd,'Ampl_Main.mod');
DAT_FILE   = fullfile(pwd,'archi_temp.dat');
run_filename = fullfile(pwd,'analisi','analisi_pareto_pesi.run');%analisi_pareto_pesi.run|analisi_sens_batteria.run

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