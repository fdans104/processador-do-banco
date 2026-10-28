# HU5 – Plano de execução

O passo 5 (PASSO A PASSO) mostra as heurísticas sendo aplicadas uma a uma (canônica → H1 → H2 → H3 → H4) e termina no plano ordenado, ao lado do grafo otimizado.

| Critério | Como é atendido |
|---|---|
| Exibir ordem de execução | lista numerada `1. R1 ← Cliente`, `2. R2 ← σ{…}(R1)`, …, `n. RESULTADO ← π{…}(Rk)` |
| Operações na ordem correta | pós-ordem do grafo: cada operação só usa resultados de passos anteriores (`respeita_dependencias`) |
| Segue o grafo otimizado | o plano é gerado do grafo da HU4; `Rn` é o resultado do nó `#n` do grafo |

| Arquivo | Responsabilidade |
|---|---|
| `plano.gd` | Grafo otimizado + estimativas → lista ordenada de operações (expressão, explicação, tuplas, grau). |

Testes: `tests/hu5/test_plano.gd`
(`godot --headless --path . --script res://tests/hu5/test_plano.gd`)
