extends RefCounted
## HU2 – Conversão da consulta para álgebra relacional.
##
## Entrada: AST produzido pela HU1 (sql_validator.gd).
## Saída: árvore de operadores algébricos, nós em forma de Dictionary:
##   tabela   -> {"op": "tabela", "nome": "Cliente"}
##   junção ⋈ -> {"op": "join",   "condicao": COND, "esq": NO, "dir": NO}
##   seleção σ-> {"op": "select", "condicao": COND, "filho": NO}
##   projeção π-> {"op": "project", "atributos": ["Tabela.Atributo", ...], "filho": NO}
##
## As condições (COND/OP) são as do AST, sem reescrita: operadores e condições
## são preservados. A ordem segue o SQL (FROM, JOINs, WHERE, SELECT); a
## reordenação é trabalho da HU4.
##
## SELECT * gera π{*}: a projeção aparece em toda consulta.


static func converter(ast: Dictionary) -> Dictionary:
	var no := {"op": "tabela", "nome": ast.from}
	for junc in ast.joins:
		no = {
			"op": "join",
			"condicao": junc.condicao,
			"esq": no,
			"dir": {"op": "tabela", "nome": junc.tabela},
		}
	if ast.where != null:
		no = {"op": "select", "condicao": ast.where, "filho": no}
	# Projeção sempre presente; SELECT * vira π{*}
	no = {"op": "project", "atributos": ast.select, "filho": no}
	return no
