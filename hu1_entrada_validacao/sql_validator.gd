extends RefCounted
## HU1 – Entrada e validação da consulta.
##
## Tokenização por expressão regular + análise sintática descendente +
## verificação de tabelas e atributos contra o modelo (db_schema.gd).
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
##
## validate() devolve:
##   {"ok", "erro", "pos", "tabelas", "atributos", "ast"}
## "pos" é o índice do erro no texto (-1 se válida). "ast" só existe se ok.
##
## AST (entrada da HU2):
##   {"select": ["Tabela.Atributo", ...] ou ["*"],
##    "from": "Tabela",
##    "joins": [{"tabela": "Tabela", "condicao": COND}, ...],
##    "where": COND ou null}
##   COND = {"tipo": "and", "esq": COND, "dir": COND}
##        | {"tipo": "comparacao", "esq": OP, "op": "=", "dir": OP}
##        | {"tipo": "grupo", "expr": COND}              (parênteses do usuário)
##   OP   = {"tipo": "atributo", "nome": "Tabela.Atributo"}
##        | {"tipo": "numero", "valor": "1"}
##        | {"tipo": "texto", "valor": "'Aberto'"}

const DbSchema := preload("res://hu1_entrada_validacao/db_schema.gd")


static func validate(sql: String) -> Dictionary:
	return _Parser.new(sql).run()


class _Parser:
	extends RefCounted

	const KEYWORDS: Array = ["SELECT", "FROM", "WHERE", "JOIN", "ON", "AND"]
	const TIPOS: Array = ["str", "num", "op", "punct", "id", "bad"]
	# Uma passada de regex: espaços, literais, operadores, pontuação, identificadores
	# e, como último recurso, qualquer caractere não reconhecido (vira erro).
	const TOKEN_RE := r"\s*(?:(?<str>'[^']*')|(?<num>\d+(?:\.\d+)?)|(?<op><=|>=|<>|=|<|>)|(?<punct>[(),.;*])|(?<id>[A-Za-z_]\w*)|(?<bad>\S))"

	var _sql: String
	var _tokens: Array = []
	var _i := 0
	var _tabelas: Array = []     # tabelas de FROM/JOIN já introduzidas (nome canônico)
	var _atributos: Array = []   # atributos resolvidos "Tabela.Atributo", sem repetição
	var _ast: Variant = null
	var _erro := ""
	var _erro_pos := -1


	func _init(sql: String) -> void:
		_sql = sql


	func run() -> Dictionary:
		if _tokenizar():
			if _tokens.is_empty():
				_falha("consulta vazia", 0)
			else:
				_consulta()
		return _resultado()


	func _resultado() -> Dictionary:
		return {
			"ok": _erro == "",
			"erro": _erro,
			"pos": _erro_pos,
			"tabelas": _tabelas.duplicate(),
			"atributos": _atributos.duplicate(),
			"ast": _ast,
		}


	func _falha(mensagem: String, pos: int) -> void:
		if _erro == "":
			_erro = mensagem
			_erro_pos = pos


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
				_falha(msg, pos)
				return false
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
		_falha("esperado '%s', encontrado %s" % [nome, _descreve(_atual())], _atual().pos)
		return false


	# ---------- sintaxe (cada função devolve o nó do AST, ou null em erro) ----------

	func _consulta() -> bool:
		if not _espera_kw("SELECT"):
			return false
		var lista = _lista_select()
		if lista == null:
			return false
		if not _espera_kw("FROM"):
			return false
		var origem := _tabela()
		if origem == "":
			return false
		var joins: Array = []
		while _is_kw("JOIN"):
			_i += 1
			var tabela := _tabela()
			if tabela == "":
				return false
			if not _espera_kw("ON"):
				return false
			var condicao = _condicao()
			if condicao == null:
				return false
			joins.append({"tabela": tabela, "condicao": condicao})
		var where = null
		if _is_kw("WHERE"):
			_i += 1
			where = _condicao()
			if where == null:
				return false
		if _is_pontuacao(";"):
			_i += 1
		if not _is_tipo("fim"):
			_falha("token inesperado %s" % _descreve(_atual()), _atual().pos)
			return false

		# Lista do SELECT só é resolvida agora, com todas as tabelas do FROM/JOIN conhecidas
		var select: Array = []
		for item in lista:
			if item is String:
				select.append(item)
			else:
				var nome := _resolve(item)
				if nome == "":
					return false
				select.append(nome)

		_ast = {"select": select, "from": origem, "joins": joins, "where": where}
		return true


	## Devolve Array de refs (Dictionary) ou ["*"]; null em erro.
	func _lista_select():
		if _is_pontuacao("*"):
			_i += 1
			return ["*"]
		var refs: Array = []
		var ref := {}
		if not _coluna(ref):
			return null
		refs.append(ref)
		while _is_pontuacao(","):
			_i += 1
			ref = {}
			if not _coluna(ref):
				return null
			refs.append(ref)
		return refs


	## Devolve o nome canônico da tabela, ou "" em erro.
	func _tabela() -> String:
		if not _is_tipo("id"):
			_falha("esperado nome de tabela, encontrado %s" % _descreve(_atual()), _atual().pos)
			return ""
		var token := _atual()
		_i += 1
		var canonica: String = DbSchema.encontrar_tabela(token.texto)
		if canonica == "":
			_falha("tabela '%s' não existe no modelo" % token.texto, token.pos)
			return ""
		if _tabelas.has(canonica):
			_falha("tabela '%s' repetida (aliases e auto-junção não suportados nesta HU)" % token.texto, token.pos)
			return ""
		_tabelas.append(canonica)
		return canonica


	func _coluna(ref: Dictionary) -> bool:
		if not _is_tipo("id"):
			_falha("esperado nome de atributo, encontrado %s" % _descreve(_atual()), _atual().pos)
			return false
		var primeiro := _atual()
		_i += 1
		ref["pos"] = primeiro.pos
		if _is_pontuacao("."):
			_i += 1
			if not _is_tipo("id"):
				_falha("esperado nome de atributo após '.', encontrado %s" % _descreve(_atual()), _atual().pos)
				return false
			ref["tabela"] = primeiro.texto
			ref["atributo"] = _atual().texto
			_i += 1
		else:
			ref["tabela"] = ""
			ref["atributo"] = primeiro.texto
		return true


	## Devolve nó COND, ou null em erro.
	func _condicao():
		var esq = _termo()
		if esq == null:
			return null
		while _is_kw("AND"):
			_i += 1
			var dir = _termo()
			if dir == null:
				return null
			esq = {"tipo": "and", "esq": esq, "dir": dir}
		return esq


	func _termo():
		if _is_pontuacao("("):
			_i += 1
			var expr = _condicao()
			if expr == null:
				return null
			if not _is_pontuacao(")"):
				_falha("esperado ')', encontrado %s" % _descreve(_atual()), _atual().pos)
				return null
			_i += 1
			return {"tipo": "grupo", "expr": expr}
		var esq = _operando()
		if esq == null:
			return null
		if not _is_tipo("op"):
			_falha("esperado operador (=, >, <, <=, >=, <>), encontrado %s" % _descreve(_atual()), _atual().pos)
			return null
		var op: String = _atual().texto
		_i += 1
		var dir = _operando()
		if dir == null:
			return null
		return {"tipo": "comparacao", "esq": esq, "op": op, "dir": dir}


	func _operando():
		var token := _atual()
		if token.tipo == "num" or token.tipo == "str":
			_i += 1
			return {"tipo": "numero" if token.tipo == "num" else "texto", "valor": token.texto}
		if token.tipo != "id":
			_falha("esperado atributo ou valor, encontrado %s" % _descreve(token), token.pos)
			return null
		var ref := {}
		if not _coluna(ref):
			return null
		var nome := _resolve(ref)
		if nome == "":
			return null
		return {"tipo": "atributo", "nome": nome}


	# ---------- semântica ----------

	## Devolve "Tabela.Atributo" canônico, ou "" em erro (com a mensagem registrada).
	func _resolve(ref: Dictionary) -> String:
		var atributo: String = ref.atributo
		var nome := ""
		if ref.tabela != "":
			var tab: String = DbSchema.encontrar_tabela(ref.tabela)
			if tab == "":
				_falha("tabela '%s' não existe no modelo" % ref.tabela, ref.pos)
				return ""
			if not (tab in _tabelas):
				_falha("tabela '%s' não faz parte do FROM/JOIN" % tab, ref.pos)
				return ""
			var coluna: String = DbSchema.coluna_em(tab, atributo)
			if coluna == "":
				_falha("atributo '%s' não existe na tabela %s" % [atributo, tab], ref.pos)
				return ""
			nome = "%s.%s" % [tab, coluna]
		else:
			var achados: Array = []
			for tab in _tabelas:
				if DbSchema.coluna_em(tab, atributo) != "":
					achados.append(tab)
			if achados.is_empty():
				var no_modelo: Array = DbSchema.tabelas_com_atributo(atributo)
				if no_modelo.is_empty():
					_falha("atributo '%s' não existe no modelo" % atributo, ref.pos)
				else:
					_falha("atributo '%s' não pertence às tabelas da consulta (existe em: %s)" % [atributo, ", ".join(PackedStringArray(no_modelo))], ref.pos)
				return ""
			if achados.size() > 1:
				_falha("atributo '%s' é ambíguo, use Tabela.%s (existe em: %s)" % [atributo, atributo, ", ".join(PackedStringArray(achados))], ref.pos)
				return ""
			nome = "%s.%s" % [achados[0], DbSchema.coluna_em(achados[0], atributo)]
		if not (nome in _atributos):
			_atributos.append(nome)
		return nome
