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