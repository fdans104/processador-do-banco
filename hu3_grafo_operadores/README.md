# HU3 – Construção do grafo de operadores

A forma canônica (HU2) vira um grafo de operadores em memória, mostrado no passo 3.

| Critério | Como é atendido |
|---|---|
| Gerado em memória | `grafo_operadores.gd` devolve `{nos, arestas, raiz, folhas}` |
| Nós = operadores | cada nó é π, σ ou ⋈ (com condição/atributos) |
| Folhas = tabelas | toda tabela do FROM/JOIN é uma folha |
| Arestas = fluxo | cada aresta vai de quem produz o resultado intermediário para quem o consome |
| Raiz = última projeção | o nó raiz é sempre o π |
| Dependências lógicas | ids em ordem de execução (pós-ordem): todo nó executa depois dos filhos |

| Arquivo | Responsabilidade |
|---|---|
| `grafo_operadores.gd` | Árvore da HU2 → grafo em memória. Sem reordenação (isso é HU4). |
| `grafo_view.gd` | Desenha o grafo (canônico no passo 3, otimizado no passo 4): caixas por operador, setas de fluxo sem cruzamento, zoom automático, botões − / + / AJUSTAR e Ctrl+roda, detalhe ao passar o mouse. |

Testes: `tests/hu3/test_grafo.gd`
(`godot --headless --path . --script res://tests/hu3/test_grafo.gd`)
