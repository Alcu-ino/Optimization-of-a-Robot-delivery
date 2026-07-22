ENTRATE = [[41.108763, 16.880046]; [41.109204, 16.879889];[41.108310, 16.879877];[41.108090, 16.880510];[41.108743, 16.878600];[41.109187, 16.878415];[41.109404, 16.879188];[41.109759, 16.878875];[41.108498, 16.880554];
[41.108555, 16.881694];[41.109220, 16.880265];[41.109171, 16.881887];[41.109569, 16.881619];[41.108852, 16.882931];[41.107973, 16.883765];[41.107835, 16.884296];[41.109925, 16.883617];[41.110394, 16.882856];[41.110234, 16.881080];
[41.110337, 16.879755];[41.109274, 16.877188];[41.109363, 16.877724]];

velocita  = [4 3 5];       
consumoKm = [45 40 50];
costoRange = [20 60];


nEnt = size(ENTRATE,1);
nomi = "N" + string(1:nEnt)';

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

%% ---------- COSTRUZIONE ARCHI ----------
archi = struct('nome',{},'costo',{},'energia',{},'tempoPercorrenza',{});
k = 0;
for i = 1:nEnt
    for j = i+1:nEnt
        [route, L] = shortestpath(G, idxNodo(i), idxNodo(j));
        if isempty(route)
            warning("Nessun percorso tra %s e %s (rete scollegata).", nomi(i), nomi(j));
            continue
        end
        Lkm   = L * 1e-3;
        costo = randi(costoRange);                 % stesso costo nei due versi
        en    = Lkm .* consumoKm;                  % % batteria
        tp    = 60 * Lkm ./ velocita;              % minuti

        k = k+1;
        archi(k,1) = struct('nome', nomi(i)+nomi(j), 'costo', costo, ...
                            'energia', en, 'tempoPercorrenza', tp);
        k = k+1;
        archi(k,1) = struct('nome', nomi(j)+nomi(i), 'costo', costo, ...
                            'energia', en, 'tempoPercorrenza', tp);
    end
end
%%

filename = "/home/vito/Scrivania/lib/export.osm";
linesLayer  = readgeotable(filename, Layer="lines");   % strade, sentieri, ferrovie
pts = readgeotable(filename, Layer="points");
% tag "di servizio" da scartare
scarta = contains(pts.other_tags, '"traffic_calming"=>"bump"') | ...
         contains(pts.other_tags, '"noexit"=>"yes"') | ...
         contains(pts.name, "Ingresso Via Orabona")  | ...
         contains(pts.name, "Ingresso Via Re David")  | ...
         contains(pts.barrier, "lift_gate")  | ...
         contains(pts.barrier, "gate") | ...
         contains(pts.other_tags, '"amenity"=>"bench"')  | ...
         contains(pts.highway, "crossing")       | ...
         contains(pts.highway, "give_way")        | ...
         contains(pts.highway, "stop")            | ...
         contains(pts.highway, "traffic_signals") | ...
         contains(pts.highway, "service") | ...
         contains(pts.highway, "milestone");
ptsPuliti = pts(~scarta, :);

shp = geopointshape(ENTRATE(:,1), ENTRATE(:,2));
shp.GeographicCRS = pts.Shape.GeographicCRS;

figure(1)
geoplot(linesLayer, "Color", [0.4 0.4 0.4])
hold on
geoplot(ptsPuliti, "o", "MarkerFaceColor",[0.85 0.2 0.2], ...
        "MarkerEdgeColor","k", "MarkerSize",5)
geoplot(shp, "^", "MarkerFaceColor",[0.1 0.4 0.9], ...
        "MarkerEdgeColor","k", "MarkerSize",7)
hold off
geobasemap streets
legend("rete","POI","entrate")