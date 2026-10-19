extends RefCounted
## Validador da HU1: tokenização por expressão regular + análise sintática
## descendente + verificação de tabelas e atributos contra o modelo.
##
## Gramática aceita (palavras-chave sem diferença de maiúsculas/minúsculas,
## espaços e tabs repetidos ignorados, ";" final opcional):
##   consulta := SELECT lista FROM tabela (JOIN tabela ON condicao)* [WHERE condicao]
##   lista    := '*' | coluna (',' coluna)*
##   coluna   := [tabela '.'] atributo
##   condicao := termo (AND termo)*
##   termo    := '(' condicao ')' | operando OP operando
##   operando := coluna | numero | 'texto'
##   OP       := =  >  <  <=  >=  <>


## Retorna {"ok": bool, "erro": String, "pos": int, "tabelas": Array, "atributos": Array}.
## "pos" é o índice do caractere onde o erro foi detectado (-1 se válida).
static func validate(sql: String) -> Dictionary:
	return _Parser.new(sql).run()


class _Parser:
	extends RefCounted

	const DbSchema := preload("res://scripts/db_schema.gd")
	const KEYWORDS: Array = ["SELECT", "FROM", "WHERE", "JOIN", "ON", "AND"]
	const TIPOS: Array = ["str", "num", "op", "punct", "id", "bad"]
	# Uma passada de regex: espaços, literais, operadores, pontuação, identificadores
	# e, como último recurso, qualquer caractere não reconhecido (vira erro).
	const TOKEN_RE := r"\s*(?:(?<str>'[^']*')|(?<num>\d+(?:\.\d+)?)|(?<op><=|>=|<>|=|<|>)|(?<punct>[(),.;*])|(?<id>[A-Za-z_]\w*)|(?<bad>\S))"

	var _sql: String
	var _tokens: Array = []
	var _i := 0
	var _tabelas: Array = []          # tabelas já introduzidas por FROM/JOIN (nome canônico)
	var _atributos: Array = []        # atributos resolvidos "Tabela.Atributo"
	var _colunas_select: Array = []   # refs da lista SELECT, resolvidas ao fim do parse
	var _erro := ""
	var _erro_pos := -1


	func _init(sql: String) -> void:
		_sql = sql


	func run() -> Dictionary:
		if _tokenizar() and not _sql.strip_edges().is_empty():
			_consulta()
		elif _erro == "":
			_falha("consulta vazia", 0)
		return _resultado()


	func _resultado() -> Dictionary:
		return {
			"ok": _erro == "",
			"erro": _erro,
			"pos": _erro_pos,
			"tabelas": _tabelas.duplicate(),
			"atributos": _atributos.duplicate(),
		}


	func _falha(mensagem: String, pos: int) -> bool:
		if _erro == "":
			_erro = mensagem
			_erro_pos = pos
		return false


	# ---------- léxico ----------

	func _tokenizar() -> bool:
		var re := RegEx.new()
		re.compile(TOKEN_RE)
		for m in re.search_all(_sql):
			var tipo := ""
			for t in TIPOS:
				if m.get_string(t) != "":
					tipo = t
					break
			var texto := m.get_string(tipo)
			var pos := m.get_start(tipo)
			if tipo == "bad":
				var msg := "string não fechada" if texto == "'" else "caractere inválido '%s'" % texto
				return _falha(msg, pos)
			if tipo == "id" and KEYWORDS.has(texto.to_upper()):
				tipo = "kw"
			_tokens.append({"tipo": tipo, "texto": texto, "pos": pos})
		return true


	func _atual() -> Dictionary:
		if _i < _tokens.size():
			return _tokens[_i]
		return {"tipo": "fim", "texto": "", "pos": _sql.length()}


	func _descreve(token: Dictionary) -> String:
		return "fim da consulta" if token.tipo == "fim" else "'%s'" % token.texto


	func _is_kw(nome: String) -> bool:
		return _atual().tipo == "kw" and _atual().texto.to_upper() == nome


	func _is_tipo(tipo: String) -> bool:
		return _atual().tipo == tipo


	func _is_pontuacao(simbolo: String) -> bool:
		return _atual().tipo == "punct" and _atual().texto == simbolo


	func _espera_kw(nome: String) -> bool:
		if _is_kw(nome):
			_i += 1
			return true
		return _falha("esperado '%s', encontrado %s" % [nome, _descreve(_atual())], _atual().pos)


	# ---------- sintaxe ----------

	func _consulta() -> bool:
		if not _espera_kw("SELECT"):
			return false
		if not _lista_select():
			return false
		if not _espera_kw("FROM"):
			return false
		if not _tabela():
			return false
		while _is_kw("JOIN"):
			_i += 1
			if not _tabela():
				return false
			if not _espera_kw("ON"):
				return false
			if not _condicao():
				return false
		if _is_kw("WHERE"):
			_i += 1
			if not _condicao():
				return false
		if _is_pontuacao(";"):
			_i += 1
		if not _is_tipo("fim"):
			return _falha("token inesperado %s" % _descreve(_atual()), _atual().pos)
		return _resolve_select()


	func _lista_select() -> bool:
		if _is_pontuacao("*"):
			_i += 1
			return true
		var ref := {}
		if not _coluna(ref):
			return false
		_colunas_select.append(ref)
		while _is_pontuacao(","):
			_i += 1
			ref = {}
			if not _coluna(ref):
				return false
			_colunas_select.append(ref)
		return true


	func _tabela() -> bool:
		if not _is_tipo("id"):
			return _falha("esperado nome de tabela, encontrado %s" % _descreve(_atual()), _atual().pos)
		var token := _atual()
		_i += 1
		var canonica: String = DbSchema.encontrar_tabela(token.texto)
		if canonica == "":
			return _falha("tabela '%s' não existe no modelo" % token.texto, token.pos)
		if _tabelas.has(canonica):
			return _falha("tabela '%s' repetida (aliases e auto-junção não suportados nesta HU)" % token.texto, token.pos)
		_tabelas.append(canonica)
		return true


	func _coluna(ref: Dictionary) -> bool:
		if not _is_tipo("id"):
			return _falha("esperado nome de atributo, encontrado %s" % _descreve(_atual()), _atual().pos)
		var primeiro := _atual()
		_i += 1
		ref["pos"] = primeiro.pos
		if _is_pontuacao("."):
			_i += 1
			if not _is_tipo("id"):
				return _falha("esperado nome de atributo após '.', encontrado %s" % _descreve(_atual()), _atual().pos)
			ref["tabela"] = primeiro.texto
			ref["atributo"] = _atual().texto
			_i += 1
		else:
			ref["tabela"] = ""
			ref["atributo"] = primeiro.texto
		return true


	func _condicao() -> bool:
		if not _termo():
			return false
		while _is_kw("AND"):
			_i += 1
			if not _termo():
				return false
		return true


	func _termo() -> bool:
		if _is_pontuacao("("):
			_i += 1
			if not _condicao():
				return false
			if not _is_pontuacao(")"):
				return _falha("esperado ')', encontrado %s" % _descreve(_atual()), _atual().pos)
			_i += 1
			return true
		if not _operando():
			return false
		if not _is_tipo("op"):
			return _falha("esperado operador (=, >, <, <=, >=, <>), encontrado %s" % _descreve(_atual()), _atual().pos)
		_i += 1
		return _operando()


	func _operando() -> bool:
		var token := _atual()
		if token.tipo == "num" or token.tipo == "str":
			_i += 1
			return true
		if token.tipo != "id":
			return _falha("esperado atributo ou valor, encontrado %s" % _descreve(token), token.pos)
		var ref := {}
		if not _coluna(ref):
			return false
		return _resolve(ref)


	# ---------- semântica ----------

	func _resolve_select() -> bool:
		for ref in _colunas_select:
			if not _resolve(ref):
				return false
		return true


	func _resolve(ref: Dictionary) -> bool:
		var atributo: String = ref.atributo
		var nome := ""
		if ref.tabela != "":
			var tab: String = DbSchema.encontrar_tabela(ref.tabela)
			if tab == "":
				return _falha("tabela '%s' não existe no modelo" % ref.tabela, ref.pos)
			if not (tab in _tabelas):
				return _falha("tabela '%s' não faz parte do FROM/JOIN" % tab, ref.pos)
			var coluna: String = DbSchema.coluna_em(tab, atributo)
			if coluna == "":
				return _falha("atributo '%s' não existe na tabela %s" % [atributo, tab], ref.pos)
			nome = "%s.%s" % [tab, coluna]
		else:
			var achados: Array = []
			for tab in _tabelas:
				if DbSchema.coluna_em(tab, atributo) != "":
					achados.append(tab)
			if achados.is_empty():
				var no_modelo: Array = DbSchema.tabelas_com_atributo(atributo)
				if no_modelo.is_empty():
					return _falha("atributo '%s' não existe no modelo" % atributo, ref.pos)
				return _falha("atributo '%s' não pertence às tabelas da consulta (existe em: %s)" % [atributo, ", ".join(PackedStringArray(no_modelo))], ref.pos)
			if achados.size() > 1:
				return _falha("atributo '%s' é ambíguo, use Tabela.%s (existe em: %s)" % [atributo, atributo, ", ".join(PackedStringArray(achados))], ref.pos)
			nome = "%s.%s" % [achados[0], DbSchema.coluna_em(achados[0], atributo)]
		if not (nome in _atributos):
			_atributos.append(nome)
		return true
