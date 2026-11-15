%% =======================================================================
%  LANCIA_ANALISI — esegue gli script AMPL di analisi e mostra i grafici
%
%  Struttura attesa della cartella del progetto:
%    <progetto>/Ampl_Main.mod          modello (corretto)
%    <progetto>/archi_temp.dat         dati generati dal main
%    <progetto>/analisi/*.run          script di analisi
%    <progetto>/analisi/out_*.txt      risultati (scritti dagli script)
%
%  Ogni .run fa da solo  reset; model Ampl_Main.mod; data archi_temp.dat;
%  quindi qui NON si caricano modello e dati: basta portare AMPL nella
%  cartella del progetto (cd) e leggere lo script.
%
%  Questo file va messo nella cartella del progetto; se lo esegui da
%  un'altra parte, imposta PROJECT_DIR a mano.
%  =======================================================================

%% 1. CONFIGURAZIONE
PROJECT_DIR = fileparts(mfilename('fullpath'));
if isempty(PROJECT_DIR), PROJECT_DIR = pwd; end     % esecuzione a sezioni
addpath(fullfile(pwd, 'analisi'));
addpath(fullfile(pwd, 'funzioni'));

AMPL_HOME = getenv('AMPL_HOME');
if isempty(AMPL_HOME), AMPL_HOME = '/home/vito/Scrivania/TOOLS/AMPL'; end

MOD_FILE    = fullfile(PROJECT_DIR, 'Ampl_Main.mod');
DAT_FILE    = fullfile(PROJECT_DIR, 'archi_temp.dat');
DIR_ANALISI = fullfile(PROJECT_DIR, 'analisi');

% Analisi da eseguire: commenta le righe che non servono.
ANALISI = {
    'analisi_sens_batteria'
    'analisi_pareto_pesi_energia_penale'
    'analisi_pareto_pesi_energia_ritardo'
    'analisi_pareto_pesi_penale_ritardo'
    'analisi_pareto_pesi_tempo_ritardo'
    'analisi_pareto_pesi_energia_tempooperativo'
};

MOSTRA_GRAFICI = false;    % al termine esegue display_result.m

%% 2. CONTROLLI
assert(isfolder(AMPL_HOME), "Cartella AMPL non trovata: %s", AMPL_HOME);
assert(isfile(MOD_FILE), "Modello non trovato: %s", MOD_FILE);
assert(isfile(DAT_FILE), "Dati non trovati: %s (esegui prima il main)", DAT_FILE);
for k = 1:numel(ANALISI)
    f = fullfile(DIR_ANALISI, ANALISI{k} + ".run");
    assert(isfile(f), "Script non trovato: %s", f);
end

%% 3. ESECUZIONE
ampl = com.ampl.AMPL(com.ampl.Environment(AMPL_HOME));
chiudiAmpl = onCleanup(@() ampl.close());

esito = strings(numel(ANALISI), 1);
durata = nan(numel(ANALISI), 1);

for k = 1:numel(ANALISI)
    nome     = ANALISI{k};
    fileRun  = fullfile(DIR_ANALISI, nome + ".run");
    fileOut  = fullfile(DIR_ANALISI, "out_" + extractAfter(string(nome), "analisi_") + ".txt");

    fprintf("\n==================== %s ====================\n", nome);
    inizio = datetime('now');
    tic
    try
        % i nomi dentro il .run (modello, dati, analisi/) sono relativi
        % alla cartella corrente di AMPL: la portiamo nel progetto
        ampl.eval(sprintf('cd "%s";', PROJECT_DIR));
        ampl.read(fileRun);
        durata(k) = toc;

        info = dir(fileOut);
        if isempty(info)
            esito(k) = "ERRORE: file di uscita non creato";
        elseif datetime(info.datenum, 'ConvertFrom', 'datenum') < inizio - seconds(1)
            esito(k) = "ERRORE: file di uscita non aggiornato";
        else
            esito(k) = "ok";
        end
    catch err
        durata(k) = toc;
        esito(k) = "ERRORE: " + string(err.message);
        warning("%s non completata:\n%s", nome, err.message);
    end
    fprintf("--> %s (%.0f s)\n", esito(k), durata(k));
end

clear chiudiAmpl          % chiude AMPL

%% 4. RIEPILOGO
riepilogo = table(string(ANALISI), esito, round(durata), ...
                  'VariableNames', {'Analisi', 'Esito', 'Secondi'});
fprintf("\n=== RIEPILOGO ===\n");
disp(riepilogo);

%% 5. GRAFICI
if MOSTRA_GRAFICI
    fileGrafici = fullfile(PROJECT_DIR, 'display_result.m');
    if isfile(fileGrafici)
        run(fileGrafici);
    else
        warning("display_result.m non trovato in %s.", PROJECT_DIR);
    end
end
