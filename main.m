%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%ASSUNZIONI SUL PROBLEMA:
%I COSTI DI ENERGIA DEVONO ESSERE MAX 40 PERC DELLA BATTERIA PER TRATTA ALTRIMENTI ANDATA E RITORNO NON SONO POSSIBILI
pesiPacchi= [20 30 40]; %peso in kg dei pacchi

nodi = ['O';'B';'A'];
clienti = ['A'];
clienti_cell = cellstr(clienti);
%%%%%%%%%%%%%%%%%%%%% ARCHI E PROPRIETA' %%%%%%%%%%%%%%%%%%%%%

archi = [
    struct('nome',"OA",'costo',30,'energia',[10 15 8],'tempoPercorrenza',[2 3 2]);
    struct('nome',"AO",'costo',30,'energia',[10 15 8],'tempoPercorrenza', [2 3 2]);
    struct('nome',"OB",'costo',45,'energia',[30 33 26],'tempoPercorrenza',[3 4 3]);
    struct('nome',"BO",'costo',45,'energia',[30 33 26],'tempoPercorrenza',[3 4 3]);
    struct('nome',"BA",'costo',57,'energia',[35 40 30],'tempoPercorrenza',[4 10 4]);
    struct('nome',"AB",'costo',57,'energia',[35 40 30],'tempoPercorrenza',[4 10 4]);
];

%ENERGIA IN PERCENTUALE DELLA BATTERIA, TEMPO IN N SLOT DA 15 MINUTI
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%% TEMPI E NODI %%%%%%%%%%%%%%%%%%%%%
orario_apertura = {[0 12*4];[2*4 12*4];[11*4 12*4]}; %orari in slot da 15 minuti (orario 8-20)
timeWindow = {[0 12*4];[0 12*4];[11*4 12*4]}; %tempi in slot da 15 minuti (orario 8-20)
nodi_timeWindow = dictionary(nodi, timeWindow);
nodi_orario_apertura = dictionary(nodi, orario_apertura);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%% NODI AMMISSIBILI (ORARIO APERTURA) %%%%%%%%%%%%%%%%%%%%%
V = NodiSpaceTime(nodi,nodi_orario_apertura); %V{i} accede ai nodi
disp(V)

%%%%%%%%%%%%%%%%%%%%%% COSTRUZIONE TEN %%%%%%%%%%%%%%%%%%%%%
A = ArchiSpaceTime(V,archi);
disp(A)

%%%%%%%%%%%%%%%%%%%%%% AMPL %%%%%%%%%%%%%%%%%%%%%

ampl = com.ampl.AMPL(com.ampl.Environment('/home/vito/Scrivania/ampl'));
ampl.reset();
ampl.read('Ampl_Main.mod');

%OPEN FILE
dat_file = fullfile(pwd, 'archi_temp.dat');
fid = fopen(dat_file, 'w');
fprintf(fid, 'data;\n\n');

num_archi = length(A);

da_c       = cell(num_archi, 1);
a_c        = cell(num_archi, 1);
costo_v    = zeros(num_archi, 1);
energ_v    = zeros(num_archi, 1);
tempo_v    = zeros(num_archi, 1);
tempoNodo_v= zeros(num_archi, 1);
partenza_c = cell(num_archi, 1);
arrivo_c   = cell(num_archi, 1);

for i = 1:num_archi
    s             = A{i};
    da_c{i}        = char(s.da_nodo);
    a_c{i}         = char(s.a_nodo);
    costo_v(i)     = double(s.costo);
    energ_v(i)     = double(s.energia);
    tempo_v(i)     = double(s.tempoPercorrenza);
    tempoNodo_v(i) = str2double(extractAfter(a_c{i}, 1));
    partenza_c{i}  = char(s.nome_nodo_partenza);
    arrivo_c{i}    = char(s.nome_nodo_arrivo);
end

% Verifica — deve stampare valori reali, non 0 o vuoto
fprintf('Arco 1: %s -> %s | costo=%g | energia=%g | nodo_p=%s\n', ...
        da_c{1}, a_c{1}, costo_v(1), energ_v(1), partenza_c{1});

% ── Set V ──────────────────────────────────────────
fprintf(fid, 'set V :=');
for i = 1:length(V)
    fprintf(fid, ' %s', char(V(i)));
end
fprintf(fid, ';\n\n');

% ── Set C ──────────────────────────────────────────
fprintf(fid, 'set C :=');
for i = 1:numel(clienti_cell)
    fprintf(fid, ' %s', clienti_cell{i});
end
fprintf(fid, ';\n\n');

% ── Set A (archi spazio-temporali) ─────────────────
fprintf(fid, 'set A :=\n');
for i = 1:num_archi
    fprintf(fid, '  (%s, %s)\n', da_c{i}, a_c{i});
end
fprintf(fid, ';\n\n');

% ── Parametri numerici ─────────────────────────────
params = {'costo', 'energia', 'tempoPercorrenza', 'tempoNodo'};
vals   = {costo_v, energ_v, tempo_v, tempoNodo_v};
for p = 1:4
    fprintf(fid, 'param %s :=\n', params{p});
    for i = 1:num_archi
        fprintf(fid, '  %s %s %g\n', da_c{i}, a_c{i}, vals{p}(i));
    end
    fprintf(fid, ';\n\n');
end

% ── Parametri simbolici ────────────────────────────
params_sym = {'nome_nodo_partenza', 'nome_nodo_arrivo'};
vals_sym   = {partenza_c, arrivo_c};
for p = 1:2
    fprintf(fid, 'param %s :=\n', params_sym{p});
    for i = 1:num_archi
        fprintf(fid, '  %s %s %s\n', da_c{i}, a_c{i}, vals_sym{p}{i});
    end
    fprintf(fid, ';\n\n');
end

% ── ORARIO MINIMO VOGLIO CONSEGNA(VETTORE STARTLINE->timeWindow) ────────────────────────────
fprintf(fid, 'param startline :=\n');
for i = 1:numel(clienti_cell)
    w = nodi_timeWindow(clienti_cell{i});
    fprintf(fid, '  %s %g\n', clienti_cell{i}, w{1}(1));
end
fprintf(fid, ';\n\n');

% ── ORARIO MASSIMO VOGLIO CONSEGNA(VETTORE DEADLINE->timeWindow) ────────────────────────────
fprintf(fid, 'param deadline :=\n');
for i = 1:numel(clienti_cell)
    w = nodi_timeWindow(clienti_cell{i});
    fprintf(fid, '  %s %g\n', clienti_cell{i}, w{1}(2));
end
fprintf(fid, ';\n\n');

% ── Parametri scalari ──────────────────────────────
fprintf(fid, 'param nodoPartenza := O0;\n');
fprintf(fid, 'param nodoArrivo   := O47;\n');
fprintf(fid, 'param cap_batteria := 100;\n');

fclose(fid);

% ── SOLUZIONE ─────────────────────────────
ampl.readData(dat_file);
ampl.setOption('solver', 'cplex'); 
ampl.solve();

% ── RESTITUISCI X ─────────────────────────────
x = ampl.getVariable('x');
xM = x.getValues();
valori_x = xM.getColumnAsDoubles('x.val');
index0 = xM.getColumnAsStrings('index0'); 
index1 = xM.getColumnAsStrings('index1');
filtro = (valori_x == 1);
index0_filtrato = string(index0(filtro));
index1_filtrato = string(index1(filtro));
valori_filtrati = valori_x(filtro);
risultato = table(index0_filtrato, index1_filtrato, valori_filtrati, ...
    'VariableNames', {'index0', 'index1', 'x_val'});
disp(risultato);
D = digraph(index0_filtrato, index1_filtrato);
plot(D);