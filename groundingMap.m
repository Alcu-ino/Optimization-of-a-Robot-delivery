%% =======================================================================
%  GROUNDING — dalla mappa OSM agli archi fisici fra le entrate
%
%  Produce le variabili usate dal main:
%    - nomi  : ["O";"N1";...]
%    - archi : struct array con campi nome ("N1@N10"), costo,
%              energia (1x3, una per fascia oraria), tempoPercorrenza (1x3)
%
%  Sostituisce sia groundingMap.m sia stochasticGroundingMap.m:
%  la variante robusta si attiva con USA_ROBUSTO = true.
%
%  CORREZIONI:
%   - Seme fisso per i costi casuali: due esecuzioni danno gli stessi dati.
%   - Percorso del file OSM relativo alla cartella dello script
%     (prima: pwd in un file, percorso assoluto nell'altro).
%   - Il grafo usa solo le <way> con tag "highway": prima entravano anche
%     edifici, recinzioni ecc., e un'entrata poteva essere agganciata a un
%     nodo non collegato alla rete percorribile.
%   - Le entrate sono agganciate al nodo piu' vicino della componente
%     connessa principale; avviso se l'aggancio e' lontano o se due
%     entrate finiscono sullo stesso nodo.
%   - Controllo finale: tutte le coppie di entrate devono avere un arco.
%  =======================================================================

%% ---------- PARAMETRI --------------------------------------------------
ENTRATE = [[41.108763, 16.880046]; [41.109204, 16.879889];[41.108310, 16.879877];[41.108090, 16.880510];[41.108743, 16.878600];[41.109187, 16.878415];[41.109404, 16.879188];[41.109759, 16.878875];[41.108498, 16.880554];
[41.108555, 16.881694];[41.109220, 16.880265];[41.108450, 16.883145 ];[41.109171, 16.881887];[41.109778, 16.883417];[41.107973, 16.883765];[41.107835, 16.884296];[41.110394, 16.882856];[41.110234, 16.881080];
[41.110337, 16.879755];[41.109274, 16.877188];[41.109363, 16.877724]];

velocita   = [4 3 5];      % km/h per fascia oraria (mattina, pomeriggio, sera)
consumoKm  = [45 40 50];   % % di batteria per km, per fascia oraria
costoRange = [20 60];      % costo casuale di ogni collegamento
MINUTI_SLOT = 15;

SEME_COSTI  = 42;          % seme del generatore casuale (riproducibilita')

USA_ROBUSTO = true;       % true: cammini minimi robusti (ex stochasticGroundingMap)
beta        = 2.0;         % deviazione massima relativa di ogni segmento
Gamma       = 10;           % numero di segmenti che possono deviare insieme

SOLO_HIGHWAY       = false; % usa solo le way con tag "highway"
DIST_MAX_AGGANCIO  = 30;   % metri: oltre questa distanza avvisa
MOSTRA_MAPPA       = true;

baseDir = fileparts(mfilename('fullpath'));
if isempty(baseDir), baseDir = pwd; end
filename = fullfile(baseDir, 'lib', 'export.osm');
assert(isfile(filename), "File OSM non trovato: %s", filename);

rng(SEME_COSTI);

nEnt = size(ENTRATE,1);
nomi = ["O";"N"+string(1:nEnt-1)'];
EuristicaGradoEntrate = zeros(nEnt,1);

%% ---------- LETTURA DEI NODI OSM ---------------------------------------
txt  = fileread(filename);
ntok = regexp(txt, '<node id="(\d+)"[^>]*? lat="(-?\d+\.?\d*)" lon="(-?\d+\.?\d*)"', 'tokens');
assert(~isempty(ntok), "Nessun nodo trovato nel file OSM.");
ntok = vertcat(ntok{:});
nodeId  = str2double(ntok(:,1));
nodeLat = str2double(ntok(:,2));
nodeLon = str2double(ntok(:,3));
id2idx  = containers.Map(nodeId, 1:numel(nodeId));

%% ---------- LETTURA DELLE WAY ------------------------------------------
linesTxt = splitlines(string(txt));
src = []; tgt = [];
curr = []; inWay = false; isHighway = false;
nWay = 0; nWayUsate = 0;
for k = 1:numel(linesTxt)
    ln = linesTxt(k);
    if contains(ln, "<way ")
        inWay = true; curr = []; isHighway = false;
    elseif contains(ln, "</way>")
        nWay = nWay + 1;
        if numel(curr) >= 2 && (isHighway || ~SOLO_HIGHWAY)
            src = [src; curr(1:end-1)]; %#ok<AGROW>
            tgt = [tgt; curr(2:end)];   %#ok<AGROW>
            nWayUsate = nWayUsate + 1;
        end
        inWay = false; curr = [];
    elseif inWay
        tok = regexp(ln, '<nd ref="(\d+)"', 'tokens', 'once');
        if ~isempty(tok)
            id = str2double(tok{1});
            if isKey(id2idx, id)
                curr(end+1,1) = id2idx(id); %#ok<AGROW>
            end
        elseif contains(ln, '<tag k="highway"')
            isHighway = true;
        end
    end
end
fprintf("Way lette: %d, usate per il grafo: %d.\n", nWay, nWayUsate);
assert(~isempty(src), "Nessuna way utilizzabile: se la mappa non ha tag " + ...
       "'highway' impostare SOLO_HIGHWAY = false.");

% i tratti con estremi coincidenti non servono
valido = src ~= tgt;
s = src(valido);
t = tgt(valido);

wgs84 = wgs84Ellipsoid("m");
d = distance(nodeLat(s), nodeLon(s), nodeLat(t), nodeLon(t), wgs84);
G = simplify(graph(s, t, d, numel(nodeId)), "min");

%% ---------- AGGANCIO DELLE ENTRATE ALLA RETE ---------------------------
% candidati: nodi della componente connessa piu' grande
comp       = conncomp(G);
suRete     = degree(G) > 0;
compPrinc  = mode(comp(suRete));
candidati  = find(comp(:) == compPrinc & suRete(:));
fprintf("Componente principale: %d nodi su %d collegati.\n", numel(candidati), nnz(suRete));

idxNodo  = zeros(nEnt,1);
distAgg  = zeros(nEnt,1);
for i = 1:nEnt
    dd = distance(nodeLat(candidati), nodeLon(candidati), ENTRATE(i,1), ENTRATE(i,2), wgs84);
    [distAgg(i), pos] = min(dd);
    idxNodo(i) = candidati(pos);
    if distAgg(i) > DIST_MAX_AGGANCIO
        warning("Entrata %s agganciata a un nodo distante %.0f m.", nomi(i), distAgg(i));
    end
end
[~, primi] = unique(idxNodo, 'stable');
doppi = setdiff(1:nEnt, primi);
if ~isempty(doppi)
    warning("Entrate agganciate a un nodo gia' usato da un'altra entrata: %s " + ...
            "(distanza 0 fra loro).", strjoin(nomi(doppi), ", "));
end

%% ---------- COSTRUZIONE ARCHI ------------------------------------------
SEP = "@";
dev = beta * G.Edges.Weight;    % usato solo nella variante robusta

nodiIncrocioUsati = [];
archi = struct('nome',{},'costo',{},'energia',{},'tempoPercorrenza',{});
k = 0;
nMancanti = 0;
for i = 1:nEnt
    for j = i+1:nEnt
        if USA_ROBUSTO
            % Lrob: lunghezza nel caso peggiore (per i tempi)
            % Lnom: lunghezza nominale dello stesso percorso (per l'energia)
            [route, Lrob, Lnom] = robustShortestPath(G, idxNodo(i), idxNodo(j), dev, Gamma);
        else
            [route, Lnom] = shortestpath(G, idxNodo(i), idxNodo(j));   % metri
            Lrob = Lnom;
        end
        if isempty(route)
            warning("Nessun percorso tra %s e %s (rete scollegata).", nomi(i), nomi(j));
            nMancanti = nMancanti + 1;
            continue
        end

        nodiIntermedi = route(2:end-1);
        nodiIncrocioUsati = [nodiIncrocioUsati; nodiIntermedi(:)]; %#ok<AGROW>
        altri = setdiff(1:nEnt, [i j]);
        passaPer = altri(ismember(idxNodo(altri), nodiIntermedi));
        EuristicaGradoEntrate(passaPer) = EuristicaGradoEntrate(passaPer) + 1;

        if ~isempty(passaPer)
            fprintf("Il percorso %s -> %s passa per: %s\n", ...
                nomi(i), nomi(j), strjoin(nomi(passaPer), ", "));
        end

        Lkm_nom = Lnom * 1e-3;
        Lkm_rob = Lrob * 1e-3;

        costo = randi(costoRange);                                       % stesso costo nei due versi
        en    = max(1, ceil(Lkm_nom .* consumoKm));                      % % di batteria, per fascia
        tp    = max(1, ceil(60 * Lkm_rob ./ velocita / MINUTI_SLOT));    % slot, per fascia

        k = k+1;
        archi(k,1) = struct('nome', nomi(i) + SEP + nomi(j), 'costo', costo, ...
                            'energia', en, 'tempoPercorrenza', tp);
        k = k+1;
        archi(k,1) = struct('nome', nomi(j) + SEP + nomi(i), 'costo', costo, ...
                            'energia', en, 'tempoPercorrenza', tp);
    end
end

fprintf("Archi fisici creati: %d (%d coppie su %d).\n", k, k/2, nEnt*(nEnt-1)/2);
if nMancanti > 0
    warning("%d coppie di entrate senza collegamento: la rete del main sara' incompleta.", nMancanti);
end
if ~isempty(archi)
    eTutte = vertcat(archi.energia);
    fprintf("Energia per tratta: min %g, max %g (%% di batteria).\n", min(eTutte(:)), max(eTutte(:)));
end

%% ---------- INCROCI USATI DAI PERCORSI ---------------------------------
nodiIncrocioUnici = unique(nodiIncrocioUsati);
gradiNodi = degree(G);
gradoMinimoIncrocio = 3;      % >= 3: intersezioni vere e proprie
nodiIncrocioUnici = nodiIncrocioUnici(gradiNodi(nodiIncrocioUnici) >= gradoMinimoIncrocio);

latIncroci = nodeLat(nodiIncrocioUnici);
lonIncroci = nodeLon(nodiIncrocioUnici);

fprintf("Trovati %d incroci stradali effettivi (grado >= %d) utilizzati nei percorsi.\n", ...
    numel(nodiIncrocioUnici), gradoMinimoIncrocio);

%% ---------- MAPPA ------------------------------------------------------
if MOSTRA_MAPPA
    linesLayer = readgeotable(filename, Layer="lines");   % strade, sentieri, ferrovie
    shp        = geopointshape(ENTRATE(:,1), ENTRATE(:,2));
    shpIncroci = geopointshape(latIncroci, lonIncroci);

    figure(1)
    geoplot(linesLayer, "Color", [0.4 0.4 0.4])
    hold on
    geoplot(shpIncroci, "o", "MarkerFaceColor", [0.9 0.1 0.1], ...
            "MarkerEdgeColor", "k", "MarkerSize", 5)
    geoplot(shp, "^", "MarkerFaceColor", [0.1 0.4 0.9], ...
            "MarkerEdgeColor", "k", "MarkerSize", 7)
    hold off
    geobasemap streets
    legend("rete", "incroci rilevanti", "entrate")
end

%% ---------- RIEPILOGO --------------------------------------------------
[~, ord] = sort(EuristicaGradoEntrate, 'descend');
riepilogo = table(nomi(ord), EuristicaGradoEntrate(ord), ...
    'VariableNames', {'Entrata','NumPercorsi'});
disp(riepilogo)
