ENTRATE = [[41.108763, 16.880046]; [41.109204, 16.879889];[41.108310, 16.879877];[41.108090, 16.880510];[41.108743, 16.878600];[41.109187, 16.878415];[41.109404, 16.879188];[41.109759, 16.878875];[41.108498, 16.880554];
[41.108555, 16.881694];[41.109220, 16.880265];[41.108450, 16.883145 ];[41.109171, 16.881887];[41.109778, 16.883417];[41.107973, 16.883765];[41.107835, 16.884296];[41.110394, 16.882856];[41.110234, 16.881080];
[41.110337, 16.879755];[41.109274, 16.877188];[41.109363, 16.877724]];

velocita  = [4 3 5];       
consumoKm = [45 40 50];
costoRange = [20 60];


nEnt = size(ENTRATE,1);
nomi = ["O";"N"+string(1:nEnt-1)'];

filename = "/home/vito/Scrivania/lib/export.osm";
txt = fileread(filename);
ntok = regexp(txt, '<node id="(\d+)" lat="(-?\d+\.?\d*)" lon="(-?\d+\.?\d*)"', 'tokens');
ntok = vertcat(ntok{:});
nodeId  = str2double(ntok(:,1));
nodeLat = str2double(ntok(:,2));
nodeLon = str2double(ntok(:,3));
id2idx  = containers.Map(nodeId, 1:numel(nodeId));


linesTxt = splitlines(string(txt));
src = []; tgt = [];
curr = [];
inWay = false;
for k = 1:numel(linesTxt)
    ln = linesTxt(k);
    if contains(ln, "<way ")
        inWay = true; curr = [];
    elseif contains(ln, "</way>")
        if numel(curr) >= 2
            src = [src; curr(1:end-1)];
            tgt = [tgt; curr(2:end)];
        end
        inWay = false; curr = [];
    elseif inWay
        tok = regexp(ln, '<nd ref="(\d+)"', 'tokens', 'once');
        if ~isempty(tok)
            id = str2double(tok{1});
            if isKey(id2idx, id)
                curr(end+1,1) = id2idx(id);
            end
        end
    end
end
s = src;
t = tgt;

wgs84 = wgs84Ellipsoid("m");
d = distance(nodeLat(s), nodeLon(s), nodeLat(t), nodeLon(t), wgs84);
G = simplify(graph(s, t, d, numel(nodeId)), "min");

idxNodo = zeros(nEnt,1);
for i = 1:nEnt
    [~, idxNodo(i)] = min(distance(nodeLat, nodeLon, ENTRATE(i,1), ENTRATE(i,2), wgs84));
end

%% ---------- PARAMETRI DI ROBUSTEZZA ----------
beta  = 0.6;
dev   = beta * G.Edges.Weight;   % allineato a G.Edges
Gamma = 3;

%% ---------- COSTRUZIONE ARCHI (robusta) ----------
SEP = "@";
nodiIncrocioUsati = [];
archi = struct('nome',{},'costo',{},'energia',{},'tempoPercorrenza',{});
k = 0;
for i = 1:nEnt
    for j = i+1:nEnt
        [route, Lrob, Lnom] = robustShortestPath(G, idxNodo(i), idxNodo(j), dev, Gamma);
        if isempty(route)
            warning("Nessun percorso tra %s e %s (rete scollegata).", nomi(i), nomi(j));
            continue
        end
        nodiIntermedi = route(2:end-1);
        nodiIncrocioUsati = [nodiIncrocioUsati; nodiIntermedi(:)];

        Lkm_nom = Lnom * 1e-3;
        Lkm_rob = Lrob * 1e-3;

        costo = randi(costoRange);
        en    = max(1, ceil(Lkm_nom .* consumoKm));            % 1x3
        tp    = max(1, ceil(60 * Lkm_rob ./ velocita / 15));   % 1x3

        k = k+1;
        archi(k,1) = struct('nome', nomi(i)+SEP+nomi(j), 'costo', costo, ...
                            'energia', en, 'tempoPercorrenza', tp);
        k = k+1;
        archi(k,1) = struct('nome', nomi(j)+SEP+nomi(i), 'costo', costo, ...
                            'energia', en, 'tempoPercorrenza', tp);
    end
end

%% ---------- ESTRAZIONE INCROCI ----------
nodiIncrocioUnici = unique(nodiIncrocioUsati);
gradiNodi = degree(G);
gradoMinimoIncrocio = 3;
maskIncrociReali = gradiNodi(nodiIncrocioUnici) >= gradoMinimoIncrocio;
nodiIncrocioUnici = nodiIncrocioUnici(maskIncrociReali);
latIncroci = nodeLat(nodiIncrocioUnici);
lonIncroci = nodeLon(nodiIncrocioUnici);

%% ---------- PLOT ----------
linesLayer = readgeotable(filename, Layer="lines");
shp        = geopointshape(ENTRATE(:,1), ENTRATE(:,2));
shpIncroci = geopointshape(latIncroci, lonIncroci);

figure(1)
geoplot(linesLayer, "Color", [0.4 0.4 0.4]); hold on
geoplot(shpIncroci, "o", "MarkerFaceColor",[0.9 0.1 0.1], "MarkerEdgeColor","k", "MarkerSize",5)
geoplot(shp, "^", "MarkerFaceColor",[0.1 0.4 0.9], "MarkerEdgeColor","k", "MarkerSize",7)
hold off
geobasemap streets
legend("rete","incroci rilevanti","entrate")

%% ---------- FUNZIONE ROBUSTA ----------
function [route, Lrob, Lnom] = robustShortestPath(G, src, dst, dev, Gamma)
    nom = G.Edges.Weight;
    thr = unique([dev(:); 0]);
    bestCost = inf; route = [];
    for l = 1:numel(thr)
        theta = thr(l);
        Gk = G;
        Gk.Edges.Weight = nom + max(dev - theta, 0);
        [p, c] = shortestpath(Gk, src, dst);
        if ~isempty(p) && (Gamma*theta + c) < bestCost
            bestCost = Gamma*theta + c;
            route = p;
        end
    end
    if isempty(route), Lrob = inf; Lnom = inf; return; end
    Lrob = bestCost;
    e    = findedge(G, route(1:end-1), route(2:end));
    Lnom = sum(nom(e));
end