%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%ASSUNZIONI SUL PROBLEMA
nodi = ['O';'B';'A'];
archi = [
    struct('nome',"OA",'costo',0,'energia',0,'tempoPercorrenza',0);
    struct('nome',"OB",'costo',0,'energia',0,'tempoPercorrenza',0)
];
percorrenze = {[0.5 0.8 0.3];[0.9 1 0.3]}; %multipli di 15! evito divisione per dt (ci sta?)
TAU = dictionary(archi, percorrenze);
tempi_limite = {[0 12*4];[2*4 12*4];[11*4 12*4]}; %tempi in slot da 15 minuti (orario 8-20)
limiti_nodi = dictionary(nodi, tempi_limite);
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
V = NodiSpaceTime(nodi,limiti_nodi); %V{i} accede ai nodi
disp(V)


%%%%%%%%%%%%%%%%%%% PROVA TEMPO PERCORRENZA E PERIODO %%%%%%%%%%%%%%%%%%%
t = Periodo(11);
Ttot = TempoPercorrenzaTau('O','B',t,TAU); 
disp(Ttot)
%%%%%%%%%%%%%%%%%%% PROVA ARCHISPACETIME        %%%%%%%%%%%%%%%%%%%
A = ArchiSpaceTime(V,archi,TAU);
disp(A)