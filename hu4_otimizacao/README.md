# HU4 – Otimização da consulta

No passo 4 a consulta é reconstruída aplicando as heurísticas, e o grafo otimizado
é exibido ao lado da lista do que foi aplicado.

| Heurística | Como é aplicada |
|---|---|
| H1 · seleções primeiro | cada comparação do WHERE/ON que usa uma só tabela vira σ logo acima da tabela |
| H2 · projeções na sequência | acima de cada σ, um π mantém só os atributos usados depois (SELECT + junções) |
| H3 · mais restritivas primeiro | começa pela tabela com menor estimativa de tuplas; a cada passo une a mais restritiva entre as ligadas |
| H4 · evitar produto cartesiano | só entra na junção uma tabela ligada por condição às já unidas; × só se não houver condição (e é avisado) |

Estimativas: toda relação base tem 1000 tuplas (sem estatísticas reais); seletividades clássicas `=` ×1/10, `<` `>` `<=` `>=` ×1/3, `<>` ×9/10, junção por igualdade ×1/1000.
Custo do plano = Σ tuplas processadas: σ e π leem |R|; ⋈ e × por laços aninhados |R|·|S|.
Empates mantêm a ordem em que as tabelas aparecem na consulta.

| Arquivo | Responsabilidade |
|---|---|
| `otimizador.gd` | AST da HU1 → árvore otimizada (formato da HU2) + lista de heurísticas aplicadas. O grafo vem da HU3. |
| `estimativa.gd` | Modelo de custo: 1000 tuplas por tabela, seletividades, tuplas estimadas por nó e custo do plano (Σ tuplas processadas), canônico × otimizado. |

Testes: `tests/hu4/test_otimizador.gd`
(`godot --headless --path . --script res://tests/hu4/test_otimizador.gd`)

## Etapas (usadas no passo 5 · PASSO A PASSO)

`otimizar()` também devolve `etapas`: a árvore depois de cada heurística, aplicada sobre a anterior.

| Etapa | O que muda | Efeito típico no custo |
|---|---|---|
| H1 | σ descem até as tabelas (junções ainda na ordem do FROM) | tuplas processadas caem muito |
| H2 | π logo após cada σ | volume que chega às junções (tuplas × atributos) cai |
| H3 | junções reordenadas só pela estimativa | pode criar produto cartesiano × e encarecer |
| H4 | ordem refeita só com tabelas ligadas por condição | remove o × e chega ao menor custo |
