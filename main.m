%% =======================================================================
%  MAIN — Optimization of a Robot delivery
%  Rete spazio-temporale (TEN) + export dati AMPL + risoluzione CPLEX
%
%  ASSUNZIONI SUL PROBLEMA:
%  I costi di energia devono essere max 40% della batteria per tratta,
%  altrimenti andata e ritorno non sono possibili.
%
%  PREREQUISITI:
%  Prima di questo script devono essere definiti (script OSM):
%    - nomi  : string array dei nodi        (es. ["O";"N1";...;"N21"])
%    - archi : struct array degli archi fisici, campo 'nome' = "N1@N10"
%  =======================================================================

%% ---------- COSTANTI GLOBALI -------------------------------------------
T_MAX      = 48;          % ultimo slot della timegrid (48 slot da 15 min)
SEP_NODO   = ":";         % separatore interno MATLAB:  NOME:TEMPO
SEP_ARCO   = "@";         % separatore archi fisici:    NOME@NOME
SEP_AMPL   = "_";         % separatore usato nel file .dat (identificatore
                          % legale AMPL, evita di dover quotare i nomi)

CAP_BATTERIA   = 1260;
CAP_MAX_ROBOT  = 10;
CONSUMO_PESO   = 0.003;
PENALE_MANCATA = 100000;

AMPL_HOME  = '/home/vito/Scrivania/ampl';
MOD_FILE   = fullfile(pwd, 'Scrivania', 'optimization', ...
                      'Optimization-of-a-Robot-delivery-1', 'Ampl_Main.mod');
DAT_FILE   = fullfile(pwd, 'Scrivania', 'optimization', ...
                      'Optimization-of-a-Robot-delivery-1','archi_temp.dat');

%% ---------- DATI DEL PROBLEMA ------------------------------------------
pesiPacchi    = [4 4 5 4 4 5 5];        % peso in kg dei pacchi
nodi          = string(nomi(:));   % dallo script OSM
clienti       = ["N1"; "N2";"N19"];
nodi_ricarica = ["N1";"N15"];             % GROUNDING

nodo_deposito = "O";
t_partenza    = 0;
t_arrivo      = T_MAX;

% destinatario di ciascun pacco (deve essere un nodo cliente)
pacco_destinatario = ["N2"; "N1"; "N2";"N2"; "N1"; "N2";"N19"];

%% ---------- CONTROLLI DI COERENZA --------------------------------------
nNodi = numel(nodi);

assert(numel(unique(nodi)) == nNodi, ...
       "Nomi dei nodi duplicati in 'nomi'.");
assert(all(ismember([clienti; nodi_ricarica; nodo_deposito], nodi)), ...
       "Clienti, nodi di ricarica o deposito non presenti in 'nodi'.");
assert(all(ismember(pacco_destinatario, clienti)), ...
       "Un pacco e' destinato a un nodo che non e' un cliente.");
assert(exist('archi','var') == 1 && ~isempty(archi), ...
       "'archi' non definito: esegui prima lo script di costruzione da OSM.");

%% ---------- ORARI DI APERTURA E FINESTRE TEMPORALI ---------------------
% Slot da 15 minuti su orario 8:00-20:00  ->  slot 0..47
% Default: nodo aperto tutto il giorno, finestra libera.
orario_apertura = repmat({[0 T_MAX]}, nNodi, 1);
timeWindow      = repmat({[0 T_MAX]}, nNodi, 1);

nodi_orario_apertura = dictionary(nodi, orario_apertura);
nodi_timeWindow      = dictionary(nodi, timeWindow);

% --- eccezioni: apertura ---
nodi_orario_apertura("N1") = {[3*4 5*4]};   % nodo di ricarica

% --- eccezioni: finestre di consegna dei clienti ---
nodi_timeWindow("N2") = {[1*4  4*4]};

%% ---------- COSTRUZIONE DELLA TEN --------------------------------------
V = NodiSpaceTime(nodi, nodi_orario_apertura);
assert(~isempty(V),               "V vuoto: controlla gli orari di apertura.");
assert(all(contains(V, SEP_NODO)), "Separatore mancante nei nodi di V.");

A = ArchiSpaceTime(V, archi);
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
tempoNodo_v = zeros(num_archi, 1);
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

    parti_a        = split(string(a_c{i}), SEP_NODO);
    tempoNodo_v(i) = str2double(parti_a(2));
end

fprintf('Arco 1: %s -> %s | costo=%g | energia=%g | nodo_p=%s\n', ...
        da_c{1}, a_c{1}, costo_v(1), energ_v(1), partenza_c{1});

%% ---------- SCRITTURA DEL FILE .dat ------------------------------------
% Il formato del file AMPL resta invariato: stessi set, stessi parametri,
% stesso ordine. Cambia solo il carattere separatore dentro il nome del
% nodo spazio-temporale (":" -> "_"), perche' ":" e' riservato dalla
% sintassi dei blocchi dati AMPL.

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
for i = 1:numel(V_ampl)
    fprintf(fid, ' %s', V_ampl(i));
end
fprintf(fid, ';\n\n');

% -- Set C --------------------------------------------------------------
fprintf(fid, 'set C :=');
for i = 1:numel(clienti)
    fprintf(fid, ' %s', clienti(i));
end
fprintf(fid, ';\n\n');

% -- Set R --------------------------------------------------------------
fprintf(fid, 'set R :=');
for i = 1:numel(nodi_ricarica)
    fprintf(fid, ' %s', nodi_ricarica(i));
end
fprintf(fid, ';\n\n');

% -- Set P (pacchi) -----------------------------------------------------
num_pacchi = numel(pesiPacchi);
fprintf(fid, 'set P :=');
for p = 1:num_pacchi
    fprintf(fid, ' P%d', p);
end
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
        fprintf(fid, '  %s %s %g\n', da_ampl(i), a_ampl(i), vals{p}(i));
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

% -- param startline (orario minimo di consegna) ------------------------
fprintf(fid, 'param startline :=\n');
for i = 1:numel(clienti)
    w = nodi_timeWindow(clienti(i));
    fprintf(fid, '  %s %g\n', clienti(i), w{1}(1));
end
fprintf(fid, ';\n\n');

% -- param deadline (orario massimo di consegna) ------------------------
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

clear cleaner          % chiude il file
fprintf("File dati scritto: %s\n", DAT_FILE);

%% ---------- RISOLUZIONE AMPL / CPLEX -----------------------------------
ampl = com.ampl.AMPL(com.ampl.Environment(AMPL_HOME));
ampl.reset();
ampl.read(MOD_FILE);
ampl.readData(DAT_FILE);
ampl.eval('display scala_costo, scala_energia, scala_tempo, scala_ritardo, scala_penale, nArchiMax;');
ampl.setOption('solver', 'cplex');
tic;
ampl.solve();
tempo_impiegato = toc;

%% ---------- RISULTATI: variabile x ------------------------------------
x  = ampl.getVariable('x');
xM = x.getValues();

valori_x = xM.getColumnAsDoubles('x.val');
index0   = string(xM.getColumnAsStrings('index0'));
index1   = string(xM.getColumnAsStrings('index1'));

filtro          = valori_x > 0.5;
index0_filtrato = index0(filtro);
index1_filtrato = index1(filtro);
valori_filtrati = valori_x(filtro);

risultato = table(index0_filtrato, index1_filtrato, valori_filtrati, ...
                  'VariableNames', {'index0', 'index1', 'x_val'});
disp(risultato);

if ~isempty(index0_filtrato)
    figure
    D = digraph(index0_filtrato, index1_filtrato);
    plot(D);
    title('Percorso ottimo sulla TEN');
end

nodi_attivi = unique([index0_filtrato; index1_filtrato]);

%% ---------- RISULTATI: stato di carica --------------------------------
soc  = ampl.getVariable('soc');
socM = soc.getValues();

soc_index  = string(socM.getColumnAsStrings('index0'));
valori_soc = socM.getColumnAsDoubles('soc.val');

filtro_soc = ismember(soc_index, nodi_attivi);

risultato_soc = table(soc_index(filtro_soc), valori_soc(filtro_soc), ...
                      'VariableNames', {'nodo', 'SOC'});
disp(risultato_soc);

%% ---------- RISULTATI: caricamento pacchi ------------------------------
carica_pacco = ampl.getVariable('carica_pacco');
cpM          = carica_pacco.getValues();

cp_da    = string(cpM.getColumnAsStrings('index0'));
cp_a     = string(cpM.getColumnAsStrings('index1'));
cp_pacco = string(cpM.getColumnAsStrings('index2'));
cp_val   = cpM.getColumnAsDoubles('carica_pacco.val');

filtro_cp = cp_val > 0.5;

risultato_caricamenti = table(cp_da(filtro_cp), cp_a(filtro_cp), cp_pacco(filtro_cp), ...
    'VariableNames', {'Dal_Nodo_SpazioTempo', 'Al_Nodo_SpazioTempo', 'Pacco_Caricato'});

disp('=== LOG DEI CARICAMENTI AL DEPOSITO (MULTI-TRIP) ===');
disp(risultato_caricamenti);
disp('=== TEMPO IMPIEGATO DAL SOLVER ===');
disp(tempo_impiegato)