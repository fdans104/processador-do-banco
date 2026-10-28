# App – casca da aplicação

Liga a interface (`scenes/main.tscn`) às histórias de usuário.

| Arquivo | Responsabilidade |
|---|---|
| `main.gd` | Orquestra os passos 1 · VALIDAR (HU1) → 2 · CANÔNICA (HU2) → 3 · GRAFO (HU3) → 4 · OTIMIZAR (HU4) → 5 · PASSO A PASSO (heurísticas sendo aplicadas uma a uma, com reprodução automática, e o plano da HU5), avançados pelo botão PRÓXIMO ou ENTER com o campo vazio. Cada passo traz uma explicação teórica. Também lista de consultas (F12), tela BANCO (F11), histórico e terminal. |
| `ficha_no.gd` | Ficha teórica aberta ao clicar em um nó do grafo: definição formal, propriedades, condição e seletividade, esquema e grau, cardinalidade estimada, fluxo e ordem de execução. Junta HU3 (grafo) e HU4 (custo). |
| `scanlines.gd` | Efeito visual de linhas de varredura. |
