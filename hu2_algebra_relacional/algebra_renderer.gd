extends RefCounted
## HU2 – Apresentação da álgebra relacional.
##
## Gera duas visões da árvore de operadores produzida por algebra_converter.gd:
##   • notação linear:  π{Cliente.Nome}(σ{...}(Cliente ⋈{...} Pedido))
##   • árvore:          π / └── σ / └── ⋈ / ├── Cliente / └── Pedido
## bbcode() junta as duas, coloridas, para o painel da interface.
## texto_linear() e texto_arvore() são as versões sem cor (usadas nos testes).

const COR_TITULO := Color(0.35, 0.85, 1.0)
const COR_TEXTO := Color(0.6, 0.7, 0.78)
const COR_PI := Color(0.45, 0.9, 1.0)
const COR_SIGMA := Color(1.0, 0.8, 0.35)
const COR_JOIN := Color(1.0, 0.55, 0.9)
const COR_TABELA := Color(0.55, 1.0, 0.7)
const COR_ATRIBUTO := Color(0.88, 0.92, 0.97)


static func texto_linear(no: Dictionary) -> String:
	return _linear(no, false)


static func texto_arvore(no: Dictionary) -> String:
	var linhas: Array = []
	_arvore(no, "", "", linhas, false)
	return "\n".join(linhas)


## Texto puro de uma condição e de uma lista de atributos (usados pela HU3).
static func texto_condicao(condicao: Dictionary) -> String:
	return _cond(condicao, false)


static func texto_atributos(atributos: Array) -> String:
	return _lista_atributos(atributos, false)


## Só a notação linear, colorida (usada pela HU4).
static func bbcode_linear(no: Dictionary) -> String:
	return _linear(no, true)


static func bbcode(no: Dictionary) -> String:
	var linhas: Array = []
	_arvore(no, "", "", linhas, true)
	return "[color=#%s]NOTAÇÃO[/color]\n%s\n\n[color=#%s]ÁRVORE DE OPERADORES[/color]\n%s" % [
		COR_TITULO.to_html(false),
		_linear(no, true),
		COR_TITULO.to_html(false),
		"\n".join(linhas),
	]


# ---------- notação linear ----------

static func _linear(no: Dictionary, colorir: bool) -> String:
	match no.op:
		"tabela":
			return _c(no.nome, COR_TABELA, colorir)
		"join":
			return "%s %s{%s} %s" % [
				_filho_de_join(no.esq, colorir),
				_c("⋈", COR_JOIN, colorir),
				_cond(no.condicao, colorir),
				_filho_de_join(no.dir, colorir),
			]
		"produto":
			return "%s %s %s" % [
				_filho_de_join(no.esq, colorir),
				_c("×", COR_JOIN, colorir),
				_filho_de_join(no.dir, colorir),
			]
		"select":
			return "%s{%s}(%s)" % [
				_c("σ", COR_SIGMA, colorir),
				_cond(no.condicao, colorir),
				_linear(no.filho, colorir),
			]
		"project":
			return "%s{%s}(%s)" % [
				_c("π", COR_PI, colorir),
				_lista_atributos(no.atributos, colorir),
				_linear(no.filho, colorir),
			]
	return ""


## Junções aninhadas ficam entre parênteses: (A ⋈ B) ⋈ C
static func _filho_de_join(no: Dictionary, colorir: bool) -> String:
	if no.op == "join" or no.op == "produto":
		return "(%s)" % _linear(no, colorir)
	return _linear(no, colorir)


# ---------- árvore ----------

static func _arvore(no: Dictionary, linha_prefixo: String, filhos_prefixo: String, linhas: Array, colorir: bool) -> void:
	linhas.append(linha_prefixo + _rotulo(no, colorir))
	var filhos := _filhos(no)
	for i in filhos.size():
		var ultimo: bool = i == filhos.size() - 1
		var ramo := "└── " if ultimo else "├── "
		var continuacao := "    " if ultimo else "│   "
		_arvore(filhos[i], filhos_prefixo + ramo, filhos_prefixo + continuacao, linhas, colorir)


static func _filhos(no: Dictionary) -> Array:
	match no.op:
		"join", "produto":
			return [no.esq, no.dir]
		"select", "project":
			return [no.filho]
	return []


static func _rotulo(no: Dictionary, colorir: bool) -> String:
	match no.op:
		"tabela":
			return _c(no.nome, COR_TABELA, colorir)
		"join":
			return "%s {%s}" % [_c("⋈", COR_JOIN, colorir), _cond(no.condicao, colorir)]
		"produto":
			return "%s (produto cartesiano)" % _c("×", COR_JOIN, colorir)
		"select":
			return "%s {%s}" % [_c("σ", COR_SIGMA, colorir), _cond(no.condicao, colorir)]
		"project":
			return "%s {%s}" % [_c("π", COR_PI, colorir), _lista_atributos(no.atributos, colorir)]
	return ""


# ---------- condições e atributos ----------

static func _cond(c: Dictionary, colorir: bool) -> String:
	match c.tipo:
		"and":
			return "%s %s %s" % [_cond(c.esq, colorir), _c("∧", COR_SIGMA, colorir), _cond(c.dir, colorir)]
		"comparacao":
			return "%s %s %s" % [_operando(c.esq, colorir), _c(c.op, COR_TEXTO, colorir), _operando(c.dir, colorir)]
		"grupo":
			return "(%s)" % _cond(c.expr, colorir)
	return ""


static func _operando(op: Dictionary, colorir: bool) -> String:
	match op.tipo:
		"atributo":
			return _c(op.nome, COR_ATRIBUTO, colorir)
		_:
			return _c(op.valor, COR_TEXTO, colorir)


static func _lista_atributos(atributos: Array, colorir: bool) -> String:
	var partes: Array = []
	for nome in atributos:
		partes.append(_c(nome, COR_ATRIBUTO, colorir))
	return ", ".join(partes)


static func _c(texto: String, cor: Color, colorir: bool) -> String:
	if not colorir:
		return texto
	return "[color=#%s]%s[/color]" % [cor.to_html(false), texto.replace("[", "[lb]")]
