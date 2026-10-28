extends RefCounted
## HU3 – Construção do grafo de operadores (em memória).
##
## Entrada: árvore de álgebra relacional da HU2 (algebra_converter.gd).
## Saída: grafo dirigido
##   {"nos": [NO, ...], "arestas": [{"de": id, "para": id}, ...], "raiz": id, "folhas": [id, ...]}
##   NO = {"id", "op", "simbolo", "nome", "detalhe", "filhos": [id, ...], "profundidade",
##         "esquema": ["Tabela.Atributo", ...] (atributos do resultado do nó),
##         "grau": número de atributos do resultado, "algebra": nó original da HU2}
##
## Regras:
##   • cada nó é um operador (π, σ, ⋈) ou uma tabela; as tabelas são as folhas;
##   • cada aresta vai do nó que produz um resultado intermediário para o nó que o
##     consome (fluxo das folhas para a raiz);
##   • a raiz é a última projeção;
##   • os ids seguem a ordem de execução (pós-ordem): um nó só executa depois dos
##     filhos, o que respeita as dependências lógicas da consulta.

const AlgebraRenderer := preload("res://hu2_algebra_relacional/algebra_renderer.gd")
const DbSchema := preload("res://hu1_entrada_validacao/db_schema.gd")

const SIMBOLOS := {"tabela": "", "join": "⋈", "produto": "×", "select": "σ", "project": "π"}
const NOMES := {"tabela": "TABELA", "join": "JUNÇÃO", "produto": "PRODUTO CARTESIANO", "select": "SELEÇÃO", "project": "PROJEÇÃO"}


static func construir(arvore: Dictionary) -> Dictionary:
	var grafo := {"nos": [], "arestas": [], "raiz": 0, "folhas": []}
	grafo.raiz = _visita(arvore, 0, grafo)
	return grafo


static func obter_no(grafo: Dictionary, id: int) -> Dictionary:
	return grafo.nos[id - 1]


## Id do nó que consome o resultado de `id` (-1 para a raiz).
static func consumidor(grafo: Dictionary, id: int) -> int:
	for aresta in grafo.arestas:
		if aresta.de == id:
			return aresta.para
	return -1


static func _visita(no_algebra: Dictionary, profundidade: int, grafo: Dictionary) -> int:
	var filhos: Array = []
	for filho in _filhos(no_algebra):
		filhos.append(_visita(filho, profundidade + 1, grafo))
	var id: int = grafo.nos.size() + 1
	var esquema := _esquema(no_algebra, filhos, grafo)
	grafo.nos.append({
		"id": id,
		"op": no_algebra.op,
		"simbolo": SIMBOLOS[no_algebra.op],
		"nome": NOMES[no_algebra.op],
		"detalhe": _detalhe(no_algebra),
		"filhos": filhos,
		"profundidade": profundidade,
		"esquema": esquema,
		"grau": esquema.size(),
		"algebra": no_algebra,
	})
	for filho_id in filhos:
		grafo.arestas.append({"de": filho_id, "para": id})
	if no_algebra.op == "tabela":
		grafo.folhas.append(id)
	return id


static func _filhos(no_algebra: Dictionary) -> Array:
	match no_algebra.op:
		"join", "produto":
			return [no_algebra.esq, no_algebra.dir]
		"select", "project":
			return [no_algebra.filho]
	return []


## Esquema do resultado: relação base → seus atributos; σ → igual ao da entrada;
## π → os atributos projetados; ⋈ e × → concatenação dos esquemas das entradas.
static func _esquema(no_algebra: Dictionary, filhos: Array, grafo: Dictionary) -> Array:
	var esquema: Array = []
	match no_algebra.op:
		"tabela":
			for coluna in DbSchema.TABELAS.get(no_algebra.nome, []):
				esquema.append("%s.%s" % [no_algebra.nome, coluna])
		"project":
			if no_algebra.atributos.size() == 1 and no_algebra.atributos[0] == "*":
				esquema = obter_no(grafo, filhos[0]).esquema.duplicate()
			else:
				esquema = no_algebra.atributos.duplicate()
		_:
			for filho in filhos:
				esquema.append_array(obter_no(grafo, filho).esquema)
	return esquema


static func _detalhe(no_algebra: Dictionary) -> String:
	match no_algebra.op:
		"tabela":
			return no_algebra.nome
		"join", "select":
			return AlgebraRenderer.texto_condicao(no_algebra.condicao)
		"project":
			return AlgebraRenderer.texto_atributos(no_algebra.atributos)
		"produto":
			return "sem condição de junção"
	return ""
