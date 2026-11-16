%% =======================================================================
%  LANCIA_SCALABILITA — analisi di scalabilita' pratica di Ampl_Main.mod
%
%  Il modello NON viene modificato: cambiano solo i dati (clienti, pacchi,
%  finestre temporali). Criteri comuni a tutti i passi:
%   - tutti i clienti hanno la stessa finestra temporale;
%   - ogni pacco pesa quanto la capacita' del robot;
%   - i clienti sono scelti a caso (ordine casuale fissato dal seme SEED);
%   - ogni altro parametro e' quello del modello (main.m).
%
%  Procedimento:
%   0. MATLAB costruisce la rete spazio-tempo di base con lo stesso orario
%      di apertura per tutti i clienti e la scrive (senza clienti, pacchi e
%      finestre) in analisi/scalabilita/scal_base.dat; scrive in
%      scal_param.dat l'ordine casuale dei clienti e i parametri dello studio.
%   1. scalabilita_clienti.run: 1, 2, 3, ... clienti, 1 pacco, finestra fissa,
%      fino a gap >= 5% a fine solve (600 s). n = clienti all'arresto.
%   2. MATLAB controlla il risultato e passa in scal_meta.dat floor(n/2) e la
%      soluzione gia' nota (floor(n/2) clienti, 1 pacco, finestra di base).
%   3. scalabilita_pacchi.run: floor(n/2) clienti, 2, 3, ... pacchi per
%      cliente, fino a gap >= 5%.
%   4. scalabilita_finestre.run: floor(n/2) clienti, finestra +1 h a ogni
%      passo, fino a gap >= 5% (o fino alla chiusura dei clienti).
%   5. scalabilita_apertura.run: floor(n/2) clienti, 1 pacco, finestra di
%      base; l'orario di apertura comune parte da APERTURA_COMUNE (soluzione
%      gia' nota) e si allarga di 1 h a ogni passo, fino a gap >= 5% o a
%      tutta la giornata. L'apertura cambia la rete spazio-tempo: MATLAB
%      prepara in anticipo la rete di ogni passo (aperture/rete_<k>.dat) e
%      la lista dei passi (scal_aperture.dat); il .run le carica una per volta.
%   I .run scrivono analisi/scalabilita/out_scal_*.txt e i dati di ogni passo
%   in analisi/scalabilita/scenari/. I grafici li fa grafici_scalabilita.m.
%
%  NB: perche' l'apertura si possa allargare, APERTURA_COMUNE deve essere
%  piu' stretta di tutta la giornata [0 47].
%
%  Prerequisito: nomi e archi nel workspace (groundingMap.m); se mancano,
%  lo script esegue groundingMap.m.
%  =======================================================================

%% 1. CONFIGURAZIONE
PROJECT_DIR = fileparts(mfilename('fullpath'));
if isempty(PROJECT_DIR), PROJECT_DIR = pwd; end     % esecuzione a sezioni
addpath(fullfile(PROJECT_DIR, 'funzioni'));

AMPL_HOME = getenv('AMPL_HOME');
if isempty(AMPL_HOME), AMPL_HOME = '/home/vito/Scrivania/TOOLS/AMPL'; end

MOD_FILE    = fullfile(PROJECT_DIR, 'Ampl_Main.mod');
DIR_ANALISI = fullfile(PROJECT_DIR, 'analisi');
DIR_SCAL    = fullfile(DIR_ANALISI, 'scalabilita');   % file di persistenza
DIR_SCEN    = fullfile(DIR_SCAL, 'scenari');          % dati di ogni passo (scritti dai .run)
BASE_DAT    = fullfile(DIR_SCAL, 'scal_base.dat');
PARAM_DAT   = fullfile(DIR_SCAL, 'scal_param.dat');
META_DAT    = fullfile(DIR_SCAL, 'scal_meta.dat');
DIR_AP      = fullfile(DIR_SCAL, 'aperture');         % reti dei passi dell'esperimento apertura
AP_DAT      = fullfile(DIR_SCAL, 'scal_aperture.dat');

ESPERIMENTI = struct( ...
    'nome', {'clienti', 'pacchi', 'finestre', 'apertura'}, ...
    'run',  {'scalabilita_clienti.run', 'scalabilita_pacchi.run', ...
             'scalabilita_finestre.run', 'scalabilita_apertura.run'}, ...
    'out',  {'out_scal_clienti.txt', 'out_scal_pacchi.txt', ...
             'out_scal_finestre.txt', 'out_scal_apertura.txt'});

% --- parametri dello studio -------------------------------------------
SEED            = 1;       % seme dell'ordine casuale dei clienti
GAP_STOP        = 0.05;    % arresto: gap relativo a fine solve >= 5%
                           % (il limite di 600 s e' nella riga 'option cplex_options' dei .run)
TW_INIZIO       = 8;       % inizio della finestra comune (slot; slot 0 = 8:00 -> 8 = 10:00)
TW_ORE_BASE     = 1;       % larghezza della finestra negli esperimenti clienti e pacchi [h]
SLOT_ORA        = 4;       % slot da 15 minuti
PPC_MAX         = 30;      % limite di sicurezza sui pacchi per cliente
APERTURA_COMUNE = [8 24];  % orario di apertura (finestra rigida) uguale per tutti i clienti,
                           % in slot: [8 24] = 10:00-14:00. Deve contenere la finestra di
                           % base e lasciare spazio per allargarla (non [0 47]).
APERTURA_PASSO_ORE = 1;    % allargamento dell'apertura a ogni passo [h]
MOSTRA_GRAFICI  = true;    % al termine esegue grafici_scalabilita.m

% --- parametri del modello: gli stessi di main.m ---------------------------
T_MAX            = 47;
CAP_BATTERIA     = 1260;
CAP_MAX_ROBOT    = 10;
CONSUMO_PESO     = 0.003;
PENALE_MANCATA   = 100000;
TASSO_RICARICA   = CAP_BATTERIA;
PENALE_DOMINANTE = 1;
nodi_ricarica    = ["O"; "N11"; "N12"];
nodo_deposito    = "O";

%% 2. CONTROLLI
assert(isfolder(AMPL_HOME), "Cartella AMPL non trovata: %s", AMPL_HOME);
assert(isfile(MOD_FILE), "Modello non trovato: %s", MOD_FILE);
for e = ESPERIMENTI
    assert(isfile(fullfile(DIR_SCAL, e.run)), "Script non trovato: %s", e.run);
end

tw_fine = TW_INIZIO + TW_ORE_BASE * SLOT_ORA;
assert(tw_fine <= T_MAX, "La finestra di base [%d %d] supera l'orizzonte (%d).", TW_INIZIO, tw_fine, T_MAX);
assert(TW_INIZIO >= APERTURA_COMUNE(1) && tw_fine <= APERTURA_COMUNE(2), ...
       "La finestra di base [%d %d] non e' dentro l'orario di apertura [%d %d].", ...
       TW_INIZIO, tw_fine, APERTURA_COMUNE(1), APERTURA_COMUNE(2));
if isequal(APERTURA_COMUNE, [0 T_MAX])
    warning("APERTURA_COMUNE e' gia' tutta la giornata: l'esperimento apertura non ha passi.");
end

if ~(exist('nomi', 'var') && exist('archi', 'var'))
    fprintf("'nomi' e 'archi' non sono nel workspace: eseguo groundingMap.m\n");
    run(fullfile(PROJECT_DIR, 'groundingMap.m'));
end

if ~isfolder(DIR_SCEN), mkdir(DIR_SCEN); end

% via i risultati e i passaggi della corsa precedente, per non riusarli per errore
for e = ESPERIMENTI
    f = fullfile(DIR_SCAL, e.out);
    if isfile(f), delete(f); end
end
if isfile(META_DAT), delete(META_DAT); end
if isfile(AP_DAT),   delete(AP_DAT);   end
if ~isfolder(DIR_AP), mkdir(DIR_AP); end
vecchie = dir(fullfile(DIR_AP, '*.dat'));
for i = 1:numel(vecchie), delete(fullfile(DIR_AP, vecchie(i).name)); end

%% 3. DATI DI BASE: rete spazio-tempo con apertura comune -> scal_base.dat
nodi      = string(nomi(:));
candidati = nodi(nodi ~= nodo_deposito);
assert(all(ismember([nodi_ricarica; nodo_deposito], nodi)), ...
       "Deposito o stazioni di ricarica non presenti in 'nomi'.");

fid = fopen(BASE_DAT, 'w');
assert(fid > 0, "Impossibile scrivere %s", BASE_DAT);
fprintf(fid, '# Rete di base per la scalabilita'' (lancia_scalabilita.m, %s)\n', string(datetime('now')));
fprintf(fid, '# Clienti, pacchi e finestre NON sono qui: li scrive ogni .run a ogni passo.\n\n');
[nV, nA] = scriviRete(fid, nodi, archi, APERTURA_COMUNE, nodo_deposito, T_MAX);
fprintf("Rete di base: %d nodi, %d archi (apertura comune [%d %d]).\n", ...
        nV, nA, APERTURA_COMUNE(1), APERTURA_COMUNE(2));
fprintf(fid, 'set R :=');   fprintf(fid, ' %s', nodi_ricarica);   fprintf(fid, ';\n\n');
fprintf(fid, 'param nodoPartenza := %s_0;\n', nodo_deposito);
fprintf(fid, 'param nodoArrivo   := %s_%d;\n', nodo_deposito, T_MAX);
fprintf(fid, 'param cap_batteria := %g;\n', CAP_BATTERIA);
fprintf(fid, 'param cap_max_robot := %g;\n', CAP_MAX_ROBOT);
fprintf(fid, 'param consumo_peso := %g;\n', CONSUMO_PESO);
fprintf(fid, 'param tasso_ricarica := %g;\n', TASSO_RICARICA);
fprintf(fid, 'param penale_dominante := %d;\n', PENALE_DOMINANTE);
fclose(fid);

%% 4. PARAMETRI DELLO STUDIO E ORDINE CASUALE DEI CLIENTI -> scal_param.dat
rng(SEED);
ordine = candidati(randperm(numel(candidati)));

fid = fopen(PARAM_DAT, 'w');
assert(fid > 0, "Impossibile scrivere %s", PARAM_DAT);
fprintf(fid, '# Parametri dello studio (lancia_scalabilita.m, seme %d)\n', SEED);
fprintf(fid, 'param NCAND := %d;\n', numel(ordine));
fprintf(fid, 'param ORDINE :=\n');
fprintf(fid, '%s\n', compose("  %d %s", (1:numel(ordine))', ordine));
fprintf(fid, ';\n');
fprintf(fid, 'param TW_INIZIO := %d;\n', TW_INIZIO);
fprintf(fid, 'param TW_ORE_BASE := %g;\n', TW_ORE_BASE);
fprintf(fid, 'param SLOT_ORA := %d;\n', SLOT_ORA);
fprintf(fid, 'param GAP_STOP := %g;\n', GAP_STOP);
fprintf(fid, 'param PENALE_PACCO := %g;\n', PENALE_MANCATA);
fprintf(fid, 'param PPC_MAX := %d;\n', PPC_MAX);
fprintf(fid, 'param DIR_SCEN := "analisi/scalabilita/scenari/";\n');
fclose(fid);
fprintf("Ordine casuale dei clienti: %s\n", strjoin(ordine, " "));

%% 5. ESPERIMENTO 1: SCALABILITA' DEI CLIENTI
ampl = com.ampl.AMPL(com.ampl.Environment(AMPL_HOME));
chiudiAmpl = onCleanup(@() ampl.close());
esiti = strings(1, numel(ESPERIMENTI));

esiti(1) = eseguiRun(ampl, PROJECT_DIR, fullfile(DIR_SCAL, ESPERIMENTI(1).run), ...
                     fullfile(DIR_SCAL, ESPERIMENTI(1).out));
assert(esiti(1) == "ok", "Esperimento clienti non riuscito (%s): impossibile proseguire.", esiti(1));

%% 6. CONTROLLO E PASSAGGIO DELLA SOLUZIONE NOTA -> scal_meta.dat
fileOut1 = fullfile(DIR_SCAL, ESPERIMENTI(1).out);
T1 = leggiOut(fileOut1);
assert(height(T1) >= 1, "%s non contiene passi.", fileOut1);
assert(isequal(T1.n_clienti(:)', 1:height(T1)), "Passi mancanti o fuori ordine in %s.", fileOut1);

n = T1.n_clienti(end);
if T1.stato(end) >= 2 || T1.gap(end) >= GAP_STOP
    fprintf("\nEsperimento clienti fermato a n = %d clienti (gap %.4g, stato %d).\n", ...
            n, T1.gap(end), T1.stato(end));
else
    warning("Gap mai >= %g: clienti candidati esauriti, n = %d.", GAP_STOP, n);
end

nMeta = max(1, floor(n / 2));
iNota = find(T1.n_clienti == nMeta, 1);
assert(~isempty(iNota) && T1.stato(iNota) <= 1, ...
       "Il passo con %d clienti non ha una soluzione da riusare.", nMeta);

righe = strtrim(readlines(fileOut1));
righe = righe(2:end);
righe = righe(righe ~= "");
token = split(righe(iNota));
assert(numel(token) == width(T1), "Riga %d di %s non valida.", iNota, fileOut1);
token(end) = "1";                                    % origine = 1: riga riusata
rigaNota = join(token, " ");

fid = fopen(META_DAT, 'w');
assert(fid > 0, "Impossibile scrivere %s", META_DAT);
fprintf(fid, '# Passaggio dall''esperimento clienti (lancia_scalabilita.m)\n');
fprintf(fid, '# n = %d clienti all''arresto -> floor(n/2) = %d\n', n, nMeta);
fprintf(fid, 'param N_META := %d;\n', nMeta);
fprintf(fid, 'param RIGA_NOTA := "%s";\n', rigaNota);
fclose(fid);
fprintf("Esperimenti pacchi, finestre e apertura con %d clienti: %s\n", nMeta, strjoin(ordine(1:nMeta), " "));

%% 6b. PASSI DELL'ESPERIMENTO APERTURA -> aperture/rete_<k>.dat, scal_aperture.dat
% Ogni passo allarga l'apertura comune di APERTURA_PASSO_ORE: prima si sposta
% la chiusura fino a fine giornata, poi l'apertura fino a inizio giornata.
passo    = APERTURA_PASSO_ORE * SLOT_ORA;
aperture = zeros(0, 2);
ap       = APERTURA_COMUNE;
while ap(1) > 0 || ap(2) < T_MAX
    if ap(2) < T_MAX
        ap(2) = min(T_MAX, ap(2) + passo);
    else
        ap(1) = max(0, ap(1) - passo);
    end
    aperture(end+1, :) = ap; %#ok<SAGROW>
end
nAp = size(aperture, 1);

fileRete = strings(nAp, 1);
for k = 1:nAp
    fileRete(k) = "analisi/scalabilita/aperture/rete_" + k + ".dat";   % relativo al progetto (per AMPL)
    fid = fopen(fullfile(PROJECT_DIR, fileRete(k)), 'w');
    assert(fid > 0, "Impossibile scrivere %s", fileRete(k));
    fprintf(fid, '# Rete con apertura comune [%d %d] (passo %d)\n\n', aperture(k,1), aperture(k,2), k);
    [nV, nA] = scriviRete(fid, nodi, archi, aperture(k,:), nodo_deposito, T_MAX);
    fclose(fid);
    fprintf("Apertura passo %2d: [%2d %2d] = %5.2f h -> %d nodi, %d archi\n", ...
            k, aperture(k,1), aperture(k,2), diff(aperture(k,:)) / SLOT_ORA, nV, nA);
end

% riga gia' nota con le colonne dell'apertura di base
rigaNotaAp = rigaNota + sprintf(" %d %d %g", APERTURA_COMUNE(1), APERTURA_COMUNE(2), ...
                                diff(APERTURA_COMUNE) / SLOT_ORA);

fid = fopen(AP_DAT, 'w');
assert(fid > 0, "Impossibile scrivere %s", AP_DAT);
fprintf(fid, '# Passi dell''esperimento apertura (lancia_scalabilita.m)\n');
fprintf(fid, '# apertura di base [%d %d]: soluzione gia'' nota\n', APERTURA_COMUNE(1), APERTURA_COMUNE(2));
fprintf(fid, 'param NAP := %d;\n', nAp);
if nAp > 0
    fprintf(fid, 'param AP_INIZIO :=\n'); fprintf(fid, '%s\n', compose("  %d %d", (1:nAp)', aperture(:,1))); fprintf(fid, ';\n');
    fprintf(fid, 'param AP_FINE :=\n');   fprintf(fid, '%s\n', compose("  %d %d", (1:nAp)', aperture(:,2))); fprintf(fid, ';\n');
    fprintf(fid, 'param AP_FILE :=\n');   fprintf(fid, '%s\n', compose("  %d ""%s""", (1:nAp)', fileRete));
end
fprintf(fid, 'param RIGA_NOTA_AP := "%s";\n', rigaNotaAp);
fclose(fid);

%% 7. ESPERIMENTI 2, 3 E 4: PACCHI, FINESTRE, APERTURA
for k = 2:numel(ESPERIMENTI)
    if ESPERIMENTI(k).nome == "apertura" && nAp == 0
        esiti(k) = "saltato: APERTURA_COMUNE e' gia' tutta la giornata";
        continue
    end
    esiti(k) = eseguiRun(ampl, PROJECT_DIR, fullfile(DIR_SCAL, ESPERIMENTI(k).run), ...
                         fullfile(DIR_SCAL, ESPERIMENTI(k).out));
end
clear chiudiAmpl          % chiude AMPL

%% 8. RIEPILOGO
fprintf("\n=== RIEPILOGO SCALABILITA' ===\n");
for k = 1:numel(ESPERIMENTI)
    if esiti(k) ~= "ok"
        fprintf("%-9s %s\n", ESPERIMENTI(k).nome, esiti(k));
        continue
    end
    T = leggiOut(fullfile(DIR_SCAL, ESPERIMENTI(k).out));
    fprintf("%-9s ok: %2d passi | ultimo: %d clienti, %d pacchi/cliente, finestra %g h, gap %.4g, %.0f s\n", ...
            ESPERIMENTI(k).nome, height(T), T.n_clienti(end), T.pacchi_per_cliente(end), ...
            T.tw_ore(end), T.gap(end), T.secondi(end));
end

if MOSTRA_GRAFICI
    run(fullfile(DIR_SCAL, 'grafici_scalabilita.m'));
end

%% =======================================================================
%  FUNZIONI LOCALI
%  =======================================================================
function esito = eseguiRun(ampl, cartella, fileRun, fileOut)
% Esegue un .run nella sessione AMPL e controlla che abbia scritto fileOut.
    fprintf("\n==================== %s ====================\n", fileRun);
    inizio = datetime('now');
    tic
    try
        % i percorsi nei .run sono relativi alla cartella del progetto
        ampl.eval(sprintf('cd "%s";', cartella));
        ampl.read(fileRun);
        info = dir(fileOut);
        if isempty(info)
            esito = "ERRORE: file di uscita non creato";
        elseif datetime(info.datenum, 'ConvertFrom', 'datenum') < inizio - seconds(1)
            esito = "ERRORE: file di uscita non aggiornato";
        else
            esito = "ok";
        end
    catch err
        esito = "ERRORE: " + string(err.message);
        warning("%s non completato:\n%s", fileRun, err.message);
    end
    fprintf("--> %s (%.0f s)\n", esito, toc);
end

function [nV, nA] = scriviRete(fid, nodi, archi, apertura, deposito, T_MAX)
% Costruisce la rete spazio-tempo con lo stesso orario di apertura per tutti
% i nodi tranne il deposito (aperto tutta la giornata) e ne scrive nodi, archi
% e dati degli archi nel file gia' aperto fid (formato .dat di AMPL).
    orari = repmat({apertura}, numel(nodi), 1);
    orari{nodi == deposito} = [0 T_MAX];
    V = NodiSpaceTime(nodi, dictionary(nodi, orari), T_MAX);
    A = ArchiSpaceTime(V, archi, T_MAX);

    nA     = numel(A);
    nV     = numel(V);
    da     = strings(nA, 1);  a     = strings(nA, 1);
    nomeDa = strings(nA, 1);  nomeA = strings(nA, 1);
    costo  = zeros(nA, 1);    energia = zeros(nA, 1);  tempo = zeros(nA, 1);
    for i = 1:nA
        da(i)     = A(i).da_nodo;             a(i)       = A(i).a_nodo;
        nomeDa(i) = A(i).nome_nodo_partenza;  nomeA(i)   = A(i).nome_nodo_arrivo;
        costo(i)  = double(A(i).costo);       energia(i) = double(A(i).energia);
        tempo(i)  = double(A(i).tempoPercorrenza);
    end
    slotDa = str2double(extractAfter(da, ":"));
    slotA  = str2double(extractAfter(a,  ":"));       % = tempoNodo, come in main.m
    assert(all(tempo == slotA - slotDa), "tempoPercorrenza non coerente con gli slot.");

    daA = amplNode(da, ":", "_");
    aA  = amplNode(a,  ":", "_");

    fprintf(fid, 'set V :=');   fprintf(fid, ' %s', amplNode(V, ":", "_"));   fprintf(fid, ';\n\n');
    fprintf(fid, 'set A :=\n'); fprintf(fid, '  (%s, %s)\n', [daA aA]');      fprintf(fid, ';\n\n');
    num = {'costo', costo; 'energia', energia; 'tempoPercorrenza', tempo; 'tempoNodo', slotA};
    for p = 1:size(num, 1)
        fprintf(fid, 'param %s :=\n', num{p,1});
        fprintf(fid, '%s\n', compose("  %s %s %.15g", daA, aA, num{p,2}));
        fprintf(fid, ';\n\n');
    end
    sym = {'nome_nodo_partenza', nomeDa; 'nome_nodo_arrivo', nomeA};
    for p = 1:size(sym, 1)
        fprintf(fid, 'param %s :=\n', sym{p,1});
        fprintf(fid, '%s\n', compose("  %s %s %s", daA, aA, sym{p,2}));
        fprintf(fid, ';\n\n');
    end
end

function T = leggiOut(file)
% Legge un file out_scal_*.txt (intestazione + righe separate da spazi).
    opts = detectImportOptions(file, 'FileType', 'text', 'Delimiter', ' ', ...
                               'ConsecutiveDelimitersRule', 'join');
    opts = setvartype(opts, 'double');
    T = readtable(file, opts);
end
