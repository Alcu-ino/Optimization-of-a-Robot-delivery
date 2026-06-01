%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%ASSUNZIONI SUL PROBLEMA:
%I COSTI DI ENERGIA DEVONO ESSERE MAX 40 PERC DELLA BATTERIA PER TRATTA ALTRIMENTI ANDATA E RITORNO NON SONO POSSIBILI
pesiPacchi= [20 30 40]; %peso in kg dei pacchi

nodi = ['O';'B';'A'];
%%%%%%%%%%%%%%%%%%%%% ARCHI E PROPRIETA' %%%%%%%%%%%%%%%%%%%%%

archi = [
    struct('nome',"OA",'costo',30,'energia',[10 15 8],'tempoPercorrenza',[2 3 2]);
    struct('nome',"AO",'costo',30,'energia',[10 15 8],'tempoPercorrenza', [2 3 2]);
    struct('nome',"OB",'costo',45,'energia',[30 33 26],'tempoPercorrenza',[3 4 3]);
    struct('nome',"BO",'costo',45,'energia',[30 33 26],'tempoPercorrenza',[3 4 3]);
    struct('nome',"BA",'costo',57,'energia',[35 40 30],'tempoPercorrenza',[4 10 4]);
    struct('nome',"BA",'costo',57,'energia',[35 40 30],'tempoPercorrenza',[4 10 4]);
];

%ENERGIA IN PERCENTUALE DELLA BATTERIA, TEMPO IN N SLOT DA 15 MINUTI
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%% TEMPI E NODI %%%%%%%%%%%%%%%%%%%%%
orario_apertura = {[0 12*4];[2*4 12*4];[11*4 12*4]}; %orari in slot da 15 minuti (orario 8-20)
timeWindow = {[7*4 9*4];[2*4 3*4];[11*4 12*4]}; %tempi in slot da 15 minuti (orario 8-20)
nodi_timeWindow = dictionary(nodi, timeWindow);
nodi_orario_apertura = dictionary(nodi, orario_apertura);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%%%%%%%%%%%%%%%%%%%%% NODI AMMISSIBILI (ORARIO APERTURA) %%%%%%%%%%%%%%%%%%%%%
V = NodiSpaceTime(nodi,nodi_orario_apertura); %V{i} accede ai nodi
disp(V)

%%%%%%%%%%%%%%%%%%%%%% COSTRUZIONE TEN %%%%%%%%%%%%%%%%%%%%%
A = ArchiSpaceTime(V,archi);
disp(A)