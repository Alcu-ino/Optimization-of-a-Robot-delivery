import networkx as nx
import matplotlib.pyplot as plt
import re
# Crea un grafo vuoto
G = nx.DiGraph()

input_text = """ INPUT OF YOUR MATLAB A_T"""
pattern = r'\{\["([A-Z]\d+)([A-Z]\d+)"\]\}'
lista_nodi = re.findall(pattern, input_text)

# Aggiunge gli archi (che creano automaticamente anche i nodi)
G.add_edges_from(lista_nodi)

# Disegna il grafo
nx.draw(G, with_labels=True, node_color='lightblue', node_size=700, font_size=16)
plt.show()