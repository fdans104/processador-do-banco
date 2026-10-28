extends RefCounted
## HU5 – Plano de execução.
##
## Entrada: grafo otimizado (HU3 construído sobre a árvore da HU4) e as
## estimativas de tuplas de cada nó (hu4_otimizacao/estimativa.gd).
## Saída: lista ordenada de operações, na ordem definida pelo grafo:
##   [{"ordem": n, "id": id do nó, "op", "resultado": "R#n", "expressao": String,
##     "entradas": [ids], "tuplas": float, "grau": int, "explicacao": String}, ...]
##
## A ordem é a pós-ordem do grafo (os ids do grafo já seguem essa ordem): um
## operador só executa quando todas as suas entradas estão prontas. Cada passo
## materializa um resultado intermediário R#n, consumido pelo passo seguinte que
## depende dele; o último passo (a raiz, π) produz o resultado final.

const Grafo := preload("res://hu3_grafo_operadores/grafo_operadores.gd")
const AlgebraRenderer := preload("res://hu2_algebra_relacional/algebra_renderer.gd")

const EXPLICACOES := {
	"tabela": "varredura da relação base (lê todas as tuplas)",
	"select": "filtra as tuplas que satisfazem a condição",
	"project": "mantém só os atributos listados",
	"join": "combina as tuplas das duas entradas que satisfazem a condição",
	"produto": "combina cada tupla da esquerda com todas as da direita",
}


static func gerar(grafo: Dictionary, tuplas: Dictionary) -> Array:
	var passos: Array = []
	for no in grafo.nos:   # pós-ordem: filhos antes do pai
		passos.append({
			"ordem": no.id,
			"id": no.id,
			"op": no.op,
			"resultado": "RESULTADO" if no.id == grafo.raiz else "R%d" % no.id,
			"expressao": _expressao(no),
			"entradas": no.filhos.duplicate(),
			"tuplas": tuplas.get(no.id, 0.0),
			"grau": no.grau,
			"explicacao": EXPLICACOES[no.op],
		})
	return passos


## Expressão do passo usando os resultados anteriores: R5 ← σ{c}(R4)
static func _expressao(no: Dictionary) -> String:
	var alg: Dictionary = no.algebra
	var entradas: Array = []
	for filho in no.filhos:
		entradas.append("R%d" % filho)
	match no.op:
		"tabela":
			return alg.nome
		"select":
			return "σ{%s}(%s)" % [AlgebraRenderer.texto_condicao(alg.condicao), entradas[0]]
		"project":
			return "π{%s}(%s)" % [AlgebraRenderer.texto_atributos(alg.atributos), entradas[0]]
		"join":
			return "%s ⋈{%s} %s" % [entradas[0], AlgebraRenderer.texto_condicao(alg.condicao), entradas[1]]
		"produto":
			return "%s × %s" % [entradas[0], entradas[1]]
	return ""


## Cada passo só usa resultados de passos anteriores (dependências respeitadas).
static func respeita_dependencias(passos: Array) -> bool:
	var prontos := {}
	for passo in passos:
		for entrada in passo.entradas:
			if not prontos.has(entrada):
				return false
		prontos[passo.id] = true
	return true
