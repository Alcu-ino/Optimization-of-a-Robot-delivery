%% =======================================================================
%  MAIN — Optimization of a Robot delivery   (versione corretta)
%  Rete spazio-temporale (TEN) + export dati AMPL + risoluzione CPLEX
%
%  Da usare con il modello  robot_delivery_corretto.mod
%
%  ASSUNZIONI SUL PROBLEMA:
%  I costi di energia devono essere max 40% della batteria per tratta,
%  altrimenti andata e ritorno non sono possibili (ora viene controllato).
%
%  PREREQUISITI:
%  Prima di questo script devono essere definiti (script OSM):
%    - nomi  : string array dei nodi        (es. ["O";"N1";...;"N21"])
%    - archi : struct array degli archi fisici, campo 'nome' = "N1@N10"
%
%  MODIFICHE RISPETTO ALLA VERSIONE PRECEDENTE:
%   [M1] Controllo di coerenza fra orari di apertura e finestre di consegna
%        (errore se un cliente non e' mai servibile, avviso se e' sempre in
%        ritardo). Le due "eccezioni" su N11 e N2 che creavano questi casi
%        sono state disattivate.
%   [M2] Controlli sui dati: dimensioni delle tabelle, pesi dei pacchi,
%        orari dentro la timegrid, tempi degli archi, assunzione del 40%.
%   [M3] Nuovi parametri scritti nel .dat: tasso_ricarica, penale_dominante.
%   [M4] Percorsi relativi alla cartella dello script (non a pwd);
%        AMPL_HOME sovrascrivibile con la variabile d'ambiente AMPL_HOME.
%   [M5] Limite di tempo e gap per CPLEX; lo stato del solver viene letto
%        e i risultati sono mostrati solo se esiste una soluzione.
%   [M6] Risultati: termini dell'obiettivo, pacchi consegnati e non,
%        ritardi, percorso ordinato nel tempo, carichi alla partenza.
%  =======================================================================


%% ---------- COSTANTI GLOBALI -------------------------------------------
T_MAX      = 47;          % ultimo slot della timegrid (48 slot da 15 min)
SEP_NODO   = ":";         % separatore interno MATLAB:  NOME:TEMPO
SEP_ARCO   = "@";         % separatore archi fisici:    NOME@NOME
SEP_AMPL   = "_";         % separatore usato nel file .dat

% ATTENZIONE: il .dat controllato era stato generato con cap_batteria = 100,
% mentre qui il valore e' 1260. Le energie degli archi valgono 3-35:
% confermare l'unita' di misura prima di interpretare la SOC.
CAP_BATTERIA     = 1260;
CAP_MAX_ROBOT    = 10;
CONSUMO_PESO     = 0.003;
PENALE_MANCATA   = 100000;
TASSO_RICARICA   = CAP_BATTERIA;  % [M3] energia ricaricata per slot di attesa
                                  %      in stazione (CAP = ricarica completa in 1 slot)
PENALE_DOMINANTE = 1;             % [M3] 1: ogni pacco non consegnato pesa w_penale
                                  %      0: penale divisa per la somma (vecchia scala)

SOGLIA_ENERGIA_TRATTA = 0.40;     % assunzione: max 40% di batteria per tratta

CPLEX_TIMELIMIT = 600;            % [M5] secondi
CPLEX_MIPGAP    = 0.01;           % [M5] gap relativo accettato

% [M4] cartella dello script (se eseguito a sezioni, ripiega su pwd)
baseDir = fileparts(mfilename('fullpath'));
if isempty(baseDir), baseDir = pwd; end

addpath(fullfile(baseDir, 'funzioni'));

AMPL_HOME = getenv('AMPL_HOME');
if isempty(AMPL_HOME), AMPL_HOME = '/home/vito/Scrivania/TOOLS/AMPL'; end
MOD_FILE  = fullfile(baseDir, 'Ampl_Main.mod');
DAT_FILE  = fullfile(baseDir, 'archi_temp.dat');

assert(isfolder(AMPL_HOME), "Cartella AMPL non trovata: %s", AMPL_HOME);
assert(isfile(MOD_FILE),    "Modello non trovato: %s", MOD_FILE);

%% ---------- DATI DEL PROBLEMA ------------------------------------------
pesiPacchi    = [2 7 4 9 1 6 3 10 5 8 2 6 9 4 7 1 10 3 5];        % peso in kg dei pacchi
nodi          = string(nomi(:));   % dallo script OSM
% destinatario di ciascun pacco (deve essere un nodo cliente)
pacco_destinatario = ["N14"; "N3"; "N3"; "N12"; "N1"; "N11"; "N20";"N13"; "N13"; "N1"; "N10"; "N1"; "N14"; "N10"; "N11"; "N1"; "N12";"N3"; "N3"];
clienti       = unique(pacco_destinatario);
nodi_ricarica = ["O";"N11";"N12"];             % GROUNDING

nodo_deposito = "O";
t_partenza    = 0;
t_arrivo      = T_MAX;

%% ---------- CONTROLLI DI COERENZA --------------------------------------
nNodi      = numel(nodi);
num_pacchi = numel(pesiPacchi);

assert(numel(unique(nodi)) == nNodi, ...
       "Nomi dei nodi duplicati in 'nomi'.");
assert(~any(contains(nodi, [SEP_NODO, SEP_AMPL, SEP_ARCO])), ...
       "I nomi dei nodi non possono contenere i separatori ':' '_' '@'.");
assert(all(ismember([clienti; nodi_ricarica; nodo_deposito], nodi)), ...
       "Clienti, nodi di ricarica o deposito non presenti in 'nodi'.");
assert(numel(unique(clienti)) == numel(clienti), "Clienti duplicati.");
assert(all(ismember(pacco_destinatario, clienti)), ...
       "Un pacco e' destinato a un nodo che non e' un cliente.");
assert(numel(pacco_destinatario) == num_pacchi, ...                        % [M2]
       "pesiPacchi (%d) e pacco_destinatario (%d) hanno lunghezze diverse.", ...
       num_pacchi, numel(pacco_destinatario));
assert(all(pesiPacchi > 0 & pesiPacchi <= CAP_MAX_ROBOT), ...              % [M2]
       "Un pacco ha peso nullo o superiore alla capacita' del robot.");
assert(exist('archi','var') == 1 && ~isempty(archi), ...
       "'archi' non definito: esegui prima lo script di costruzione da OSM.");

%% ---------- ORARI DI APERTURA E FINESTRE TEMPORALI ---------------------
% Slot da 15 minuti su orario 8:00-20:00  ->  slot 0..47
% Le righe seguono l'ordine di 'nodi' (O, N1, N2, ...).
orario_apertura = {
    [0 47]
    [ 3 15]
    [17 29]
    [28 44]
    [ 9 31]
    [35 47]
    [21 46]
    [ 0 12]
    [14 26]
    [30 42]
    [ 6 18]
    [23 40]
    [11 23]
    [33 47]     % era [33 48]: 48 e' fuori dalla timegrid
    [18 35]
    [ 2 20]
    [26 38]
    [ 8 20]
    [19 31]
    [31 43]
    [12 24]
};

timeWindow = {
    [0 47]
    [6 13]
    [20 26]
    [30 37]
    [11 19]
    [39 44]
    [25 31]
    [3 10]
    [17 22]
    [33 40]
    [9 14]
    [27 33]
    [15 20]
    [36 43]
    [22 28]
    [5 12]
    [29 36]
    [12 18]
    [23 29]
    [35 41]
    [16 22]
    };

assert(numel(orario_apertura) == nNodi && numel(timeWindow) == nNodi, ...  % [M2]
       "orario_apertura / timeWindow devono avere una riga per nodo (%d).", nNodi);

nodi_orario_apertura = dictionary(nodi, orario_apertura);
nodi_timeWindow      = dictionary(nodi, timeWindow);

% --- eccezioni -----------------------------------------------------------
% [M1] Le due eccezioni originali rendevano i dati incoerenti e sono state
% disattivate; le tabelle di base qui sopra sono coerenti fra loro.
%   - N11 aperto solo negli slot 12-20 con finestra di consegna 27-33:
%     il pacco per N11 non era mai consegnabile.
%   - N2 con finestra 4-16 ma aperto solo negli slot 17-29:
%     consegna sempre in ritardo.
% Se servono, riattivarle aggiornando insieme apertura E finestra.
% nodi_orario_apertura("N11") = {[3*4 5*4]};
% nodi_timeWindow("N2")       = {[1*4 4*4]};

% [M2] orari e finestre dentro la timegrid e ben ordinati
for i = 1:nNodi
    oa = nodi_orario_apertura(nodi(i));  oa = oa{1};
    tw = nodi_timeWindow(nodi(i));       tw = tw{1};
    assert(numel(oa) == 2 && oa(1) >= 0 && oa(2) <= T_MAX && oa(1) <= oa(2), ...
           "Orario di apertura non valido per %s: [%g %g].", nodi(i), oa(1), oa(end));
    assert(numel(tw) == 2 && tw(1) >= 0 && tw(1) <= tw(2), ...
           "Finestra temporale non valida per %s: [%g %g].", nodi(i), tw(1), tw(end));
end

%% ---------- COSTRUZIONE DELLA TEN --------------------------------------
V = NodiSpaceTime(nodi, nodi_orario_apertura, T_MAX);
assert(~isempty(V),               "V vuoto: controlla gli orari di apertura.");
assert(all(contains(V, SEP_NODO)), "Separatore mancante nei nodi di V.");

A = ArchiSpaceTime(V, archi, T_MAX);
assert(~isempty(A), "Nessun arco generato: controlla archi e finestre temporali.");

fprintf("TEN generata: %d nodi, %d archi.\n", numel(V), numel(A));

% diagnostica: slot disponibili per nodo
for i = 1:nNodi
    n_slot = sum(startsWith(V, nodi(i) + SEP_NODO));
    if n_slot == 0
        warning("Il nodo %s non ha alcuno slot temporale.", nodi(i));
    end
end

%% ---------- ESTRAZIONE DEI DATI DEGLI ARCHI ----------------------------
num_archi = numel(A);

da_c        = cell(num_archi, 1);
a_c         = cell(num_archi, 1);
costo_v     = zeros(num_archi, 1);
energ_v     = zeros(num_archi, 1);
tempo_v     = zeros(num_archi, 1);
tempoNodo_v = zeros(num_archi, 1);   % slot di ARRIVO dell'arco
slotDa_v    = zeros(num_archi, 1);   % slot di partenza dell'arco
partenza_c  = cell(num_archi, 1);
arrivo_c    = cell(num_archi, 1);

for i = 1:num_archi
    s = A(i);

    da_c{i}        = char(s.da_nodo);
    a_c{i}         = char(s.a_nodo);
    costo_v(i)     = double(s.costo);
    energ_v(i)     = double(s.energia);
    tempo_v(i)     = double(s.tempoPercorrenza);
    partenza_c{i}  = char(s.nome_nodo_partenza);
    arrivo_c{i}    = char(s.nome_nodo_arrivo);

    parti_da       = split(string(da_c{i}), SEP_NODO);
    parti_a        = split(string(a_c{i}),  SEP_NODO);
    slotDa_v(i)    = str2double(parti_da(2));
    tempoNodo_v(i) = str2double(parti_a(2));
end

partenza_s = string(partenza_c);
arrivo_s   = string(arrivo_c);

fprintf('Arco 1: %s -> %s | costo=%g | energia=%g | nodo_p=%s\n', ...
        da_c{1}, a_c{1}, costo_v(1), energ_v(1), partenza_c{1});

%% ---------- CONTROLLI SULLA TEN                                [M1][M2]
% archi tutti in avanti nel tempo e durata coerente con gli slot
assert(all(tempoNodo_v > slotDa_v), "Esistono archi che non avanzano nel tempo.");
assert(all(tempo_v == tempoNodo_v - slotDa_v), ...
       "tempoPercorrenza non coincide con la differenza di slot su %d archi.", ...
       sum(tempo_v ~= tempoNodo_v - slotDa_v));
assert(all(costo_v >= 0) && all(energ_v >= 0), "Costi o energie negativi sugli archi.");

% archi duplicati
chiavi = string(da_c) + "|" + string(a_c);
assert(numel(unique(chiavi)) == num_archi, "Archi spazio-temporali duplicati.");

% assunzione del 40%
e_max = max(energ_v);
if e_max > SOGLIA_ENERGIA_TRATTA * CAP_BATTERIA
    warning("Energia massima di un arco (%g) oltre il %g%% della batteria (%g).", ...
            e_max, 100*SOGLIA_ENERGIA_TRATTA, CAP_BATTERIA);
end
if e_max < 0.05 * CAP_BATTERIA
    warning("Energia massima di un arco (%g) sotto il 5%% della batteria (%g): " + ...
            "verificare l'unita' di misura di CAP_BATTERIA.", e_max, CAP_BATTERIA);
end

% finestre di consegna raggiungibili
problemi = strings(0,1);
for i = 1:numel(clienti)
    c  = clienti(i);
    w  = nodi_timeWindow(c);  w = w{1};
    arrivi = unique(tempoNodo_v(arrivo_s == c & partenza_s ~= c));
    if isempty(arrivi) || ~any(arrivi >= w(1))
        problemi(end+1,1) = sprintf("%s: nessun arrivo possibile dopo l'apertura " + ...
            "della finestra [%g %g] -> pacchi MAI consegnabili.", c, w(1), w(2)); %#ok<SAGROW>
    elseif ~any(arrivi >= w(1) & arrivi <= w(2))
        warning("%s: nessun arrivo possibile dentro la finestra [%g %g] " + ...
                "(ritardo minimo %g slot).", c, w(1), w(2), min(arrivi(arrivi >= w(1))) - w(2));
    end
end
assert(isempty(problemi), "Finestre incoerenti con gli orari di apertura:\n%s", ...
       join(problemi, newline));

% il deposito deve avere archi in uscita e in ingresso
assert(any(partenza_s == nodo_deposito & arrivo_s ~= nodo_deposito), ...
       "Nessun arco in uscita dal deposito.");

%% ---------- SCRITTURA DEL FILE .dat ------------------------------------
V_ampl        = amplNode(V,          SEP_NODO, SEP_AMPL);
da_ampl       = amplNode(da_c,       SEP_NODO, SEP_AMPL);
a_ampl        = amplNode(a_c,        SEP_NODO, SEP_AMPL);
nodoPartenza  = amplNode(nodo_deposito + SEP_NODO + string(t_partenza), SEP_NODO, SEP_AMPL);
nodoArrivo    = amplNode(nodo_deposito + SEP_NODO + string(t_arrivo),   SEP_NODO, SEP_AMPL);

assert(ismember(nodo_deposito + SEP_NODO + string(t_partenza), V), ...
       "Il nodo di partenza non esiste nella TEN.");
assert(ismember(nodo_deposito + SEP_NODO + string(t_arrivo), V), ...
       "Il nodo di arrivo non esiste nella TEN.");

fid = fopen(DAT_FILE, 'w');
assert(fid > 0, "Impossibile aprire il file %s in scrittura.", DAT_FILE);
cleaner = onCleanup(@() fcloseIfOpen(fid));

fprintf(fid, 'data;\n\n');

% -- Set V --------------------------------------------------------------
fprintf(fid, 'set V :=');
fprintf(fid, ' %s', V_ampl);
fprintf(fid, ';\n\n');

% -- Set C --------------------------------------------------------------
fprintf(fid, 'set C :=');
fprintf(fid, ' %s', clienti);
fprintf(fid, ';\n\n');

% -- Set R --------------------------------------------------------------
fprintf(fid, 'set R :=');
fprintf(fid, ' %s', nodi_ricarica);
fprintf(fid, ';\n\n');

% -- Set P (pacchi) -----------------------------------------------------
fprintf(fid, 'set P :=');
fprintf(fid, ' P%d', 1:num_pacchi);
fprintf(fid, ';\n\n');

% -- param pacco_cliente ------------------------------------------------
fprintf(fid, 'param pacco_cliente :=\n');
for p = 1:num_pacchi
    fprintf(fid, '  P%d %s\n', p, pacco_destinatario(p));
end
fprintf(fid, ';\n\n');

% -- param peso_pacco ---------------------------------------------------
fprintf(fid, 'param peso_pacco :=\n');
for p = 1:num_pacchi
    fprintf(fid, '  P%d %g\n', p, pesiPacchi(p));
end
fprintf(fid, ';\n\n');

% -- param penale_mancata_consegna --------------------------------------
fprintf(fid, 'param penale_mancata_consegna :=\n');
for p = 1:num_pacchi
    fprintf(fid, '  P%d %g\n', p, PENALE_MANCATA);
end
fprintf(fid, ';\n\n');

% -- Set A (archi spazio-temporali) -------------------------------------
fprintf(fid, 'set A :=\n');
for i = 1:num_archi
    fprintf(fid, '  (%s, %s)\n', da_ampl(i), a_ampl(i));
end
fprintf(fid, ';\n\n');

% -- Parametri numerici sugli archi -------------------------------------
params = {'costo', 'energia', 'tempoPercorrenza', 'tempoNodo'};
vals   = {costo_v, energ_v, tempo_v, tempoNodo_v};
for p = 1:numel(params)
    fprintf(fid, 'param %s :=\n', params{p});
    for i = 1:num_archi
        fprintf(fid, '  %s %s %.15g\n', da_ampl(i), a_ampl(i), vals{p}(i));
    end
    fprintf(fid, ';\n\n');
end

% -- Parametri simbolici sugli archi ------------------------------------
params_sym = {'nome_nodo_partenza', 'nome_nodo_arrivo'};
vals_sym   = {partenza_c, arrivo_c};
for p = 1:numel(params_sym)
    fprintf(fid, 'param %s :=\n', params_sym{p});
    for i = 1:num_archi
        fprintf(fid, '  %s %s %s\n', da_ampl(i), a_ampl(i), vals_sym{p}{i});
    end
    fprintf(fid, ';\n\n');
end

% -- param startline / deadline -----------------------------------------
fprintf(fid, 'param startline :=\n');
for i = 1:numel(clienti)
    w = nodi_timeWindow(clienti(i));
    fprintf(fid, '  %s %g\n', clienti(i), w{1}(1));
end
fprintf(fid, ';\n\n');

fprintf(fid, 'param deadline :=\n');
for i = 1:numel(clienti)
    w = nodi_timeWindow(clienti(i));
    fprintf(fid, '  %s %g\n', clienti(i), w{1}(2));
end
fprintf(fid, ';\n\n');

% -- Parametri scalari --------------------------------------------------
fprintf(fid, 'param nodoPartenza := %s;\n', nodoPartenza);
fprintf(fid, 'param nodoArrivo   := %s;\n', nodoArrivo);
fprintf(fid, 'param cap_batteria := %g;\n', CAP_BATTERIA);
fprintf(fid, 'param cap_max_robot := %g;\n', CAP_MAX_ROBOT);
fprintf(fid, 'param consumo_peso := %g;\n', CONSUMO_PESO);
fprintf(fid, 'param tasso_ricarica := %g;\n', TASSO_RICARICA);        % [M3]
fprintf(fid, 'param penale_dominante := %d;\n', PENALE_DOMINANTE);    % [M3]

clear cleaner          % chiude il file
fprintf("File dati scritto: %s\n", DAT_FILE);

%% ---------- RISOLUZIONE AMPL / CPLEX -----------------------------------
ampl = com.ampl.AMPL(com.ampl.Environment(AMPL_HOME));
chiudiAmpl = onCleanup(@() ampl.close());
ampl.reset();
ampl.read(MOD_FILE);
ampl.readData(DAT_FILE);
ampl.eval('display scala_costo, scala_energia, scala_tempo_op, scala_ritardo, scala_penale, nArchiMax;');
ampl.setOption('solver', 'cplex');
ampl.setOption('cplex_options', ...                                    % [M5]
    sprintf('timelimit=%g mipgap=%g', CPLEX_TIMELIMIT, CPLEX_MIPGAP));
tic;
ampl.solve();
tempo_impiegato = toc;

% [M5] stato del solver
stato = string(ampl.getValue('solve_result'));
fprintf("Stato del solver: %s (%.1f s)\n", stato, tempo_impiegato);

switch stato
    case "solved"
        % soluzione ottima entro il gap richiesto
    case "limit"
        warning("Limite di tempo raggiunto: la soluzione mostrata, se esiste, " + ...
                "NON e' dimostrata ottima.");
    otherwise
        error("Nessuna soluzione utilizzabile (solve_result = %s).", stato);
end

%% ---------- RISULTATI: variabile x ------------------------------------
x  = ampl.getVariable('x');
xM = x.getValues();

valori_x = xM.getColumnAsDoubles('x.val');
index0   = string(xM.getColumnAsStrings('index0'));
index1   = string(xM.getColumnAsStrings('index1'));

filtro          = valori_x > 0.5;
index0_filtrato = index0(filtro);
index1_filtrato = index1(filtro);

if isempty(index0_filtrato)
    error("Il solver non ha restituito alcun percorso (stato %s).", stato);
end

% [M6] percorso ordinato nel tempo
slot_da = str2double(extractAfter(index0_filtrato, SEP_AMPL));
[~, ord] = sort(slot_da);
index0_filtrato = index0_filtrato(ord);
index1_filtrato = index1_filtrato(ord);
base_da = extractBefore(index0_filtrato, SEP_AMPL);
base_a  = extractBefore(index1_filtrato, SEP_AMPL);

tipo = repmat("movimento", numel(ord), 1);
tipo(base_da == base_a) = "attesa";
tipo(base_da == base_a & ismember(base_da, nodi_ricarica)) = "attesa/ricarica";

risultato = table(index0_filtrato, index1_filtrato, tipo, ...
                  'VariableNames', {'index0', 'index1', 'tipo'});
disp(risultato);

figure
D = digraph(index0_filtrato, index1_filtrato);
plot(D);
title('Percorso sulla TEN (' + stato + ')');

nodi_attivi = unique([index0_filtrato; index1_filtrato], 'stable');

%% ---------- RISULTATI: obiettivo                                 [M6]
obiettivo = ampl.getValue('CostoTotale');
costo_tot = ampl.getValue('sum {(i,j) in A} costo[i,j] * x[i,j]');
energ_tot = ampl.getValue('sum {(i,j) in A} energia[i,j] * x[i,j]');
tempo_op  = ampl.getValue(['sum {(i,j) in A: base[i] != "O" or base[j] != "O"} ' ...
                           'tempoPercorrenza[i,j] * x[i,j]']);
rit_tot   = ampl.getValue('sum {c in C} ritardo[c]');
n_cons    = ampl.getValue('sum {p in P} consegnato[p]');

fprintf("\n=== OBIETTIVO ===\n");
fprintf("Valore obiettivo      : %.5f\n", obiettivo);
fprintf("Costo totale          : %g\n",   costo_tot);
fprintf("Energia totale        : %g\n",   energ_tot);
fprintf("Tempo operativo (slot): %g\n",   tempo_op);
fprintf("Ritardo totale (slot) : %g\n",   rit_tot);
fprintf("Pacchi consegnati     : %g su %d\n", n_cons, num_pacchi);

%% ---------- RISULTATI: stato di carica --------------------------------
soc  = ampl.getVariable('soc');
socM = soc.getValues();

soc_index  = string(socM.getColumnAsStrings('index0'));
valori_soc = socM.getColumnAsDoubles('soc.val');

[trovato, pos] = ismember(nodi_attivi, soc_index);     % nell'ordine del percorso
risultato_soc = table(nodi_attivi(trovato), valori_soc(pos(trovato)), ...
                      'VariableNames', {'nodo', 'SOC'});
disp(risultato_soc);

%% ---------- RISULTATI: pacchi                                    [M6]
carica_pacco = ampl.getVariable('carica_pacco');
cpM          = carica_pacco.getValues();

cp_da    = string(cpM.getColumnAsStrings('index0'));
cp_a     = string(cpM.getColumnAsStrings('index1'));
cp_pacco = string(cpM.getColumnAsStrings('index2'));
cp_val   = cpM.getColumnAsDoubles('carica_pacco.val');

attivo   = cp_val > 0.5;
cp_da    = cp_da(attivo);  cp_a = cp_a(attivo);  cp_pacco = cp_pacco(attivo);
cp_bda   = extractBefore(cp_da, SEP_AMPL);
cp_ba    = extractBefore(cp_a,  SEP_AMPL);

% carichi: archi che escono dal deposito con il pacco a bordo
f_car = cp_bda == nodo_deposito & cp_ba ~= nodo_deposito;
risultato_caricamenti = sortrows(table( ...
    str2double(extractAfter(cp_da(f_car), SEP_AMPL)), cp_da(f_car), cp_a(f_car), cp_pacco(f_car), ...
    'VariableNames', {'slot', 'Dal_Nodo_SpazioTempo', 'Al_Nodo_SpazioTempo', 'Pacco_Caricato'}));

disp('=== CARICAMENTI AL DEPOSITO (MULTI-TRIP) ===');
disp(risultato_caricamenti);

% consegne: archi che entrano nel cliente destinatario
nomiP  = "P" + string(1:num_pacchi)';
slot_consegna = nan(num_pacchi, 1);
for p = 1:num_pacchi
    f = cp_pacco == nomiP(p) & cp_ba == pacco_destinatario(p) & cp_bda ~= pacco_destinatario(p);
    if any(f)
        slot_consegna(p) = str2double(extractAfter(cp_a(find(f, 1)), SEP_AMPL));
    end
end
deadline_p = zeros(num_pacchi, 1);
for p = 1:num_pacchi
    w = nodi_timeWindow(pacco_destinatario(p));
    deadline_p(p) = w{1}(2);
end
ritardo_p = max(0, slot_consegna - deadline_p);

risultato_consegne = table(nomiP, pacco_destinatario(:), pesiPacchi(:), ...
    ~isnan(slot_consegna), slot_consegna, deadline_p, ritardo_p, ...
    'VariableNames', {'Pacco', 'Cliente', 'Peso', 'Consegnato', 'Slot_Consegna', 'Deadline', 'Ritardo'});

disp('=== CONSEGNE ===');
disp(risultato_consegne);

non_cons = nomiP(isnan(slot_consegna));
if ~isempty(non_cons)
    warning("Pacchi NON consegnati: %s", join(non_cons, ", "));
end

disp('=== TEMPO IMPIEGATO DAL SOLVER (s) ===');
disp(tempo_impiegato)
