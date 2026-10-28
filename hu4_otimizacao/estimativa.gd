extends RefCounted
## HU4 – Modelo de custo: estimativa de tuplas de cada operador e custo do plano.
##
## Não há dados reais, então toda relação base tem |R| = TUPLAS_POR_TABELA e as
## seletividades são os valores clássicos de livro-texto:
##   sel(A = constante) = 1/10   sel(A <> c) = 9/10   sel(intervalo <,>,<=,>=) = 1/3
##   sel(R.A = S.B) = 1/|R|   (junção por chave estrangeira → chave primária)
## Cardinalidades:
##   |σ_c(R)| = |R|·sel(c)     |π_A(R)| = |R| (SQL não elimina duplicatas sem DISTINCT)
##   |R ⋈_c S| = |R|·|S|·sel(c)     |R × S| = |R|·|S|
## Custo do plano = Σ das tuplas processadas (σ, π: |R|; ⋈, ×: |R|·|S|), ver custo().

const TUPLAS_POR_TABELA := 1000.0
const SELETIVIDADE := {"=": 0.1, "<>": 0.9, "<": 1.0 / 3, ">": 1.0 / 3, "<=": 1.0 / 3, ">=": 1.0 / 3}


## |R| de uma relação base: sempre a suposição padrão (sem estatísticas).
static func cardinalidade(_tabela: String) -> float:
	return TUPLAS_POR_TABELA


## Quebra a condição nas comparações ligadas por AND (parênteses só agrupam ANDs).
static func conjuncoes(condicao: Dictionary) -> Array:
	match condicao.tipo:
		"and":
			return conjuncoes(condicao.esq) + conjuncoes(condicao.dir)
		"grupo":
			return conjuncoes(condicao.expr)
	return [condicao]


## Igualdade entre atributos de tabelas diferentes (predicado de junção).
static func eh_igualdade_de_juncao(comparacao: Dictionary) -> bool:
	if comparacao.op != "=" or comparacao.esq.tipo != "atributo" or comparacao.dir.tipo != "atributo":
		return false
	return comparacao.esq.nome.get_slice(".", 0) != comparacao.dir.nome.get_slice(".", 0)


static func seletividade(comparacao: Dictionary) -> float:
	if eh_igualdade_de_juncao(comparacao):
		return 1.0 / TUPLAS_POR_TABELA
	return SELETIVIDADE.get(comparacao.op, 1.0 / 3)


## Seletividade de uma condição inteira: produto das comparações (independência).
static func seletividade_condicao(condicao: Dictionary) -> float:
	var total := 1.0
	for comparacao in conjuncoes(condicao):
		total *= seletividade(comparacao)
	return total


## Por que essa comparação tem essa seletividade (texto para a ficha teórica).
static func explica(comparacao: Dictionary) -> String:
	if eh_igualdade_de_juncao(comparacao):
		return "1/%d · igualdade de junção (chave estrangeira → primária)" % roundi(TUPLAS_POR_TABELA)
	match comparacao.op:
		"=":
			return "1/10 · igualdade com constante"
		"<>":
			return "9/10 · diferença"
	return "1/3 · comparação de intervalo"


## Tuplas estimadas de cada nó do grafo (HU3): {id: tuplas}. Nós em pós-ordem,
## então os filhos sempre já foram calculados.
static func estimar(grafo: Dictionary) -> Dictionary:
	var tuplas := {}
	for no in grafo.nos:
		var valor := 0.0
		match no.op:
			"tabela":
				valor = cardinalidade(no.algebra.nome)
			"select":
				valor = tuplas[no.filhos[0]] * seletividade_condicao(no.algebra.condicao)
			"project":
				valor = tuplas[no.filhos[0]]
			"join":
				valor = tuplas[no.filhos[0]] * tuplas[no.filhos[1]] * seletividade_condicao(no.algebra.condicao)
			"produto":
				valor = tuplas[no.filhos[0]] * tuplas[no.filhos[1]]
		tuplas[no.id] = valor
	return tuplas


## Custo do plano = Σ das tuplas processadas por cada operador:
##   σ e π leem a entrada uma vez (|R|);
##   ⋈ e × por laços aninhados comparam cada par de tuplas (|R|·|S|).
## É o que as heurísticas reduzem: entradas menores chegando às junções.
static func custo(grafo: Dictionary, tuplas: Dictionary) -> float:
	var total := 0.0
	for no in grafo.nos:
		match no.op:
			"select", "project":
				total += tuplas[no.filhos[0]]
			"join", "produto":
				total += tuplas[no.filhos[0]] * tuplas[no.filhos[1]]
	return total


## Volume que chega às junções = Σ, nas entradas de cada ⋈ e ×, tuplas × grau
## (valores que a junção precisa ler). Mostra o ganho da projeção antecipada,
## que não muda o número de tuplas mas deixa cada tupla menor.
static func volume(grafo: Dictionary, tuplas: Dictionary) -> float:
	var total := 0.0
	for no in grafo.nos:
		if no.op == "join" or no.op == "produto":
			for filho in no.filhos:
				var entrada: Dictionary = grafo.nos[filho - 1]
				total += tuplas[filho] * entrada.grau
	return total


static func formata(tuplas: float) -> String:
	if tuplas >= 100.0:
		return "%d" % roundi(tuplas)
	if tuplas >= 1.0:
		return "%.1f" % tuplas
	return "%.3f" % tuplas
