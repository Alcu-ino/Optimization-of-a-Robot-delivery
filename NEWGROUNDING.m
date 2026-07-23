%% =======================================================================
%  COSTRUZIONE DEL GRAFO STRADALE SPARSO
%
%  Invece di collegare ogni ingresso con ogni altro (grafo completo), si
%  costruisce il grafo che rispetta la geometria reale della rete:
%    - nodi "ingresso"  -> O, N1, N2, ...   (dalle coordinate ENTRATE)
%    - nodi "strada"    -> S1, S2, ...      (incroci e biforcazioni OSM)
%    - archi            -> tratti di strada fra due nodi significativi
%
%  I nodi OSM di grado 2 sono soltanto punti di interpolazione della
%  geometria: vengono contratti, e la loro lunghezza confluisce nel
%  tratto risultante.
%  =======================================================================

clc

%% ---------- PARAMETRI --------------------------------------------------
ENTRATE = [[41.108763, 16.880046]; [41.109204, 16.879889];[41.108310, 16.879877];[41.108090, 16.880510];[41.108743, 16.878600];[41.109187, 16.878415];[41.109404, 16.879188];[41.109759, 16.878875];[41.108498, 16.880554];
[41.108555, 16.881694];[41.109220, 16.880265];[41.108450, 16.883145 ];[41.109171, 16.881887];[41.109778, 16.883417];[41.107973, 16.883765];[41.107835, 16.884296];[41.110394, 16.882856];[41.110234, 16.881080];
[41.110337, 16.879755];[41.109274, 16.877188];[41.109363, 16.877724]];

velocita   = [4 3 5];        % km/h nei tre periodi
consumoKm  = [45 40 50];     % % batteria per km nei tre periodi
costoRange = [20 60];

RAGGIO_MAX   = 800;          % m: scarta i nodi OSM lontani dagli ingressi
SNAP_MAX     = 60;           % m: distanza massima ingresso -> nodo OSM
TIENI_VICOLI = true;         % true = tiene anche i vicoli ciechi (grado 1)
SEP          = "@";

OSM_FILE = "/home/vito/Scrivania/lib/export.osm";

%% ---------- LETTURA DEI NODI OSM ---------------------------------------
txt = fileread(OSM_FILE);

ntok = regexp(txt, '<node id="(\d+)" lat="(-?\d+\.?\d*)" lon="(-?\d+\.?\d*)"', 'tokens');
ntok = vertcat(ntok{:});

nodeId  = str2double(ntok(:,1));
nodeLat = str2double(ntok(:,2));
nodeLon = str2double(ntok(:,3));
id2idx  = containers.Map(nodeId, 1:numel(nodeId));

fprintf("Nodi OSM letti: %d\n", numel(nodeId));

%% ---------- LETTURA DELLE WAY (archi) ----------------------------------
linesTxt = splitlines(string(txt));

src = []; tgt = [];
curr = []; inWay = false;

for k = 1:numel(linesTxt)
    ln = linesTxt(k);

    if contains(ln, "<way ")
        inWay = true; curr = [];

    elseif contains(ln, "</way>")
        if numel(curr) >= 2
            src = [src; curr(1:end-1)];   %#ok<AGROW>
            tgt = [tgt; curr(2:end)];     %#ok<AGROW>
        end
        inWay = false; curr = [];

    elseif inWay
        tok = regexp(ln, '<nd ref="(\d+)"', 'tokens', 'once');
        if ~isempty(tok)
            id = str2double(tok{1});
            if isKey(id2idx, id)
                curr(end+1,1) = id2idx(id); %#ok<AGROW>
            end
        end
    end
end

%% ---------- GRAFO COMPLETO OSM -----------------------------------------
wgs84 = wgs84Ellipsoid("m");
pesi  = distance(nodeLat(src), nodeLon(src), nodeLat(tgt), nodeLon(tgt), wgs84);

G = simplify(graph(src, tgt, pesi, numel(nodeId)), "min");

fprintf("Grafo OSM: %d nodi, %d archi\n", numnodes(G), numedges(G));

%% ---------- SNAP DEGLI INGRESSI ----------------------------------------
nEnt    = size(ENTRATE,1);
idxEntr = zeros(nEnt,1);
distSnap = zeros(nEnt,1);

for i = 1:nEnt
    dd = distance(nodeLat, nodeLon, ENTRATE(i,1), ENTRATE(i,2), wgs84);
    [distSnap(i), idxEntr(i)] = min(dd);

    if distSnap(i) > SNAP_MAX
        warning("Ingresso %d agganciato a %.0f m dal nodo OSM piu' vicino.", ...
                i, distSnap(i));
    end
end

if numel(unique(idxEntr)) < nEnt
    warning("Due o piu' ingressi sono agganciati allo stesso nodo OSM.");
end

%% ---------- POTATURA: componente connessa e raggio ---------------------
% tiene solo la componente che contiene gli ingressi
comp    = conncomp(G);
compEnt = unique(comp(idxEntr));

if numel(compEnt) > 1
    warning(['Gli ingressi ricadono in %d componenti separate. ' ...
             'Viene tenuta quella piu' ' popolosa.'], numel(compEnt));
    conteggi = arrayfun(@(c) sum(comp == c), compEnt);
    [~, imax] = max(conteggi);
    compEnt = compEnt(imax);
end

% distanza dal baricentro degli ingressi
latC = mean(ENTRATE(:,1));
lonC = mean(ENTRATE(:,2));
dCentro = distance(nodeLat, nodeLon, latC, lonC, wgs84);

tieni = (comp(:) == compEnt) & (dCentro <= RAGGIO_MAX);
tieni(idxEntr) = true;                       % gli ingressi non si scartano mai

mapOld2New = zeros(numnodes(G),1);
mapOld2New(tieni) = 1:sum(tieni);

G = subgraph(G, find(tieni));
latG = nodeLat(tieni);
lonG = nodeLon(tieni);
idxEntr = mapOld2New(idxEntr);

fprintf("Dopo potatura: %d nodi, %d archi\n", numnodes(G), numedges(G));

%% ---------- INDIVIDUAZIONE DEI NODI SIGNIFICATIVI ----------------------
% Significativo = ingresso, incrocio (grado >= 3) o, se richiesto,
% vicolo cieco (grado 1). I nodi di grado 2 sono geometria pura.
gradi = degree(G);

isKeyNode = false(numnodes(G),1);
isKeyNode(idxEntr) = true;
isKeyNode(gradi >= 3) = true;
if TIENI_VICOLI
    isKeyNode(gradi == 1) = true;
end

fprintf("Nodi significativi: %d (di cui %d ingressi, %d incroci)\n", ...
        sum(isKeyNode), nEnt, sum(gradi >= 3));

%% ---------- CONTRAZIONE DELLE CATENE -----------------------------------
% Da ogni nodo significativo si percorre ciascun ramo attraversando i
% nodi di grado 2, accumulando la lunghezza, fino al successivo nodo
% significativo. Il tratto risultante diventa un arco del grafo ridotto.

visitato = false(numedges(G),1);
segU = []; segV = []; segL = [];

listaKey = find(isKeyNode)';

for a = listaKey
    for b = neighbors(G, a)'

        e = findedge(G, a, b);
        if visitato(e)
            continue
        end
        visitato(e) = true;

        Lacc = G.Edges.Weight(e);
        prev = a;
        cur  = b;

        % avanza finche' non incontra un nodo significativo
        while ~isKeyNode(cur)
            vicini = neighbors(G, cur);
            nxt = vicini(vicini ~= prev);

            if isempty(nxt)
                break                      % catena senza sbocco
            end
            nxt = nxt(1);

            e2 = findedge(G, cur, nxt);
            if visitato(e2)
                break                      % anello gia' percorso
            end
            visitato(e2) = true;

            Lacc = Lacc + G.Edges.Weight(e2);
            prev = cur;
            cur  = nxt;
        end

        if isKeyNode(cur) && cur ~= a
            segU(end+1,1) = a;    %#ok<AGROW>
            segV(end+1,1) = cur;  %#ok<AGROW>
            segL(end+1,1) = Lacc; %#ok<AGROW>
        end
    end
end

fprintf("Tratti contratti: %d\n", numel(segL));

%% ---------- GRAFO RIDOTTO ----------------------------------------------
% rinumerazione dei soli nodi significativi effettivamente usati
usati = unique([segU; segV; idxEntr]);
old2new = zeros(numnodes(G),1);
old2new(usati) = 1:numel(usati);

rU = old2new(segU);
rV = old2new(segV);

Gr = simplify(graph(rU, rV, segL, numel(usati)), "min");

latR = latG(usati);
lonR = lonG(usati);
idxEntrR = old2new(idxEntr);

%% ---------- NOMI DEI NODI ----------------------------------------------
% Ingressi: O (deposito) + N1..N(k).  Nodi stradali: S1..S(m).
nomi = strings(numnodes(Gr),1);

nomi(idxEntrR(1)) = "O";
for i = 2:nEnt
    nomi(idxEntrR(i)) = "N" + string(i-1);
end

idxStrada = setdiff((1:numnodes(Gr))', idxEntrR);
for i = 1:numel(idxStrada)
    nomi(idxStrada(i)) = "S" + string(i);
end

assert(all(nomi ~= ""),                    "Nodo senza nome.");
assert(numel(unique(nomi)) == numel(nomi), "Nomi duplicati.");
assert(~any(contains(nomi, "_")),          "I nomi non devono contenere '_'.");

fprintf("Grafo ridotto: %d nodi (%d ingressi + %d strada), %d archi\n", ...
        numnodes(Gr), nEnt, numel(idxStrada), numedges(Gr));

%% ---------- COSTRUZIONE DEGLI ARCHI PER LA TEN -------------------------
archi = struct('nome',{},'da',{},'a',{},'costo',{},'energia',{}, ...
               'tempoPercorrenza',{},'lunghezza_m',{});
k = 0;

EE = Gr.Edges;

for e = 1:height(EE)
    u = EE.EndNodes(e,1);
    v = EE.EndNodes(e,2);
    Lm = EE.Weight(e);

    Lkm   = Lm * 1e-3;
    costo = randi(costoRange);                              % simmetrico
    en    = max(1, ceil(Lkm .* consumoKm));                 % % batteria
    tp    = max(1, ceil(60 * Lkm ./ velocita / 15));        % slot da 15 min

    k = k+1;
    archi(k,1) = struct('nome', nomi(u) + SEP + nomi(v), ...
                        'da', nomi(u), 'a', nomi(v), ...
                        'costo', costo, 'energia', en, ...
                        'tempoPercorrenza', tp, 'lunghezza_m', Lm);
    k = k+1;
    archi(k,1) = struct('nome', nomi(v) + SEP + nomi(u), ...
                        'da', nomi(v), 'a', nomi(u), ...
                        'costo', costo, 'energia', en, ...
                        'tempoPercorrenza', tp, 'lunghezza_m', Lm);
end

%% ---------- DIAGNOSTICA ------------------------------------------------
gradiR = degree(Gr);
fprintf("\nGrado medio: %.2f  (grafo completo avrebbe %.0f)\n", ...
        mean(gradiR), numnodes(Gr)-1);
fprintf("Densita': %.1f%% degli archi di un grafo completo\n", ...
        100 * numedges(Gr) / (numnodes(Gr)*(numnodes(Gr)-1)/2));

tuttiTp = vertcat(archi.tempoPercorrenza);
fprintf("Slot di percorrenza: min=%d  max=%d  media=%.1f\n", ...
        min(tuttiTp(:)), max(tuttiTp(:)), mean(tuttiTp(:)));

tuttiEn = vertcat(archi.energia);
fprintf("Energia per tratta: min=%d  max=%d  (%% batteria)\n", ...
        min(tuttiEn(:)), max(tuttiEn(:)));

if any(gradiR == 0)
    warning("%d nodi isolati nel grafo ridotto.", sum(gradiR == 0));
end
%%
figure('Name','Grafo stradale ridotto')

u  = EE.EndNodes(:,1);
v  = EE.EndNodes(:,2);
nE = numel(u);

% [inizio; fine; NaN] per ogni tratto, poi linearizzato
latSeg = [latR(u), latR(v), nan(nE,1)]';
lonSeg = [lonR(u), lonR(v), nan(nE,1)]';
latSeg = latSeg(:);
lonSeg = lonSeg(:);

geoplot(latSeg, lonSeg, '-', 'Color', [0.35 0.35 0.35], 'LineWidth', 1.2)
hold on

geoplot(latR(idxStrada), lonR(idxStrada), 'o', ...
        'MarkerFaceColor', [0.9 0.7 0.1], 'MarkerEdgeColor','k', 'MarkerSize', 6)

geoplot(latR(idxEntrR), lonR(idxEntrR), '^', ...
        'MarkerFaceColor', [0.1 0.4 0.9], 'MarkerEdgeColor','k', 'MarkerSize', 10)

for i = 1:numnodes(Gr)
    text(latR(i), lonR(i), "  " + nomi(i), 'FontSize', 8, 'Clipping', 'on')
end

hold off
geobasemap streets
legend('tratti', 'nodi strada', 'ingressi')
title('Rete stradale: geometria reale')