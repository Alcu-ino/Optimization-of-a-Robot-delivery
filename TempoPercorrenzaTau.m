function [Ttot] = TempoPercorrenzaTau(i,j,labelPeriodo,archi)
%TempoPercorrenzaTau(i,j,labelPeriodo,archiOrTAU)
% Controlla tutti gli elementi della struct 'archi'. Se esiste un elemento
% tale che archi(k).nome == string(i)+string(j) allora restituisce
% archi(k).tempoPercorrenza(labelPeriodo) (o il campo alternativo
% 'tempidipercorrenza' se presente).

si = string(i);
sj = string(j);
key = si + sj;

if isstruct(archi) && ~isempty(archi)
	if isfield(archi,'nome')
		for k = 1:length(archi)
			nome_k = string(archi(k).nome);
			if nome_k == key
				if isfield(archiOrTAU(k),'tempoPercorrenza')
					vec = archiOrTAU(k).tempoPercorrenza;
				else
					error('TempoPercorrenzaTau:MissingField', ...
						'Arco trovato ma non contiene un campo di tempo percorrenza.');
				end
				Ttot = vec(labelPeriodo);
				return
			end
		end
	end
end