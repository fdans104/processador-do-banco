extends RefCounted
## Ficha de um nó do grafo (abre ao clicar em um nó nos passos 3, 4 e 5):
## definição, condição, esquema/grau, tuplas estimadas, fluxo e ordem de execução.

const Grafo := preload("res://hu3_grafo_operadores/grafo_operadores.gd")
const Estimativa := preload("res://hu4_otimizacao/estimativa.gd")
const AlgebraRenderer := preload("res://hu2_algebra_relacional/algebra_renderer.gd")

const COR_ROTULO := Color(1.0, 0.8, 0.35)
const COR_FORMULA := Color(0.45, 0.9, 1.0)

const DEFINICOES := {
	"select": "σ_c(R) = { t ∈ R | c(t) é verdadeira }",
	"project": "π_A(R) = { t[A] | t ∈ R }",
	"join": "R ⋈_c S = σ_c(R × S)",
	"produto": "R × S = { (r, s) | r ∈ R, s ∈ S }",
}


static func bbcode(grafo: Dictionary, id: int, tuplas: Dictionary, _atributos_consulta: Array) -> String:
	var no := Grafo.obter_no(grafo, id)
	var linhas: Array = [_titulo(no, grafo), ""]
	if no.op == "tabela":
		var colunas: Array = []
		for atributo in no.esquema:
			colunas.append(atributo.get_slice(".", 1))
		linhas.append(_item("relação", _formula("%s(%s)" % [no.detalhe, ", ".join(colunas)])))
	else:
		linhas.append(_item("definição", _formula(DEFINICOES[no.op])))
		if no.op == "select" or no.op == "join":
			linhas.append(_item("condição", _escapa(AlgebraRenderer.texto_condicao(no.algebra.condicao))))
		elif no.op == "project":
			linhas.append(_item("atributos", ", ".join(no.algebra.atributos)))
	linhas.append(_item("grau", "%d atributos" % no.grau))
	linhas.append(_item("tuplas", "≈ " + Estimativa.formata(tuplas[no.id])))
	var entradas: Array = []
	for filho in no.filhos:
		var entrada := Grafo.obter_no(grafo, filho)
		entradas.append("#%d %s" % [entrada.id, entrada.nome])
	if not entradas.is_empty():
		linhas.append(_item("recebe de", ", ".join(entradas)))
	var destino := Grafo.consumidor(grafo, no.id)
	linhas.append(_item("envia para", "#%d %s" % [destino, Grafo.obter_no(grafo, destino).nome] if destino != -1 else "resultado final"))
	linhas.append(_item("ordem", "executa no passo %d de %d" % [no.id, grafo.nos.size()]))
	return "\n".join(linhas)


static func _titulo(no: Dictionary, grafo: Dictionary) -> String:
	var cor := _cor(no.op).to_html(false)
	if no.op == "tabela":
		return "[color=#%s]#%d · RELAÇÃO BASE %s[/color]" % [cor, no.id, no.detalhe]
	return "[color=#%s]#%d · %s %s%s[/color]" % [cor, no.id, no.simbolo, no.nome, "  (raiz)" if no.id == grafo.raiz else ""]


static func _item(rotulo: String, valor: String) -> String:
	return "[color=#%s]%-11s[/color] %s" % [COR_ROTULO.to_html(false), rotulo, valor]


static func _formula(texto: String) -> String:
	return "[color=#%s]%s[/color]" % [COR_FORMULA.to_html(false), texto]


static func _cor(op: String) -> Color:
	match op:
		"project":
			return AlgebraRenderer.COR_PI
		"select":
			return AlgebraRenderer.COR_SIGMA
		"join":
			return AlgebraRenderer.COR_JOIN
		"produto":
			return Color(1.0, 0.4, 0.4)
	return AlgebraRenderer.COR_TABELA


static func _escapa(texto: String) -> String:
	return texto.replace("[", "[lb]")
