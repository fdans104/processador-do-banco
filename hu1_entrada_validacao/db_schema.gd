extends RefCounted
## Modelo de dados de referência
## Fonte única das tabelas e atributos aceitos pelo parser.
##
## A tela BANCO (F11):
## cria e remove tabelas e atributos; as mudanças valem só enquanto o programa
## estiver aberto (nada é gravado em disco).

const PALAVRAS_RESERVADAS: Array = ["SELECT", "FROM", "WHERE", "JOIN", "ON", "AND"]

const MODELO_PADRAO: Dictionary = {
	"Categoria": ["idCategoria", "Descricao"],
	"Produto": ["idProduto", "Nome", "Descricao", "Preco", "QuantEstoque", "Categoria_idCategoria"],
	"TipoCliente": ["idTipoCliente", "Descricao"],
	"Cliente": ["idCliente", "Nome", "Email", "Nascimento", "Senha", "TipoCliente_idTipoCliente", "DataRegistro"],
	"TipoEndereco": ["idTipoEndereco", "Descricao"],
	"Endereco": ["idEndereco", "EnderecoPadrao", "Logradouro", "Numero", "Complemento", "Bairro", "Cidade", "UF", "CEP", "TipoEndereco_idTipoEndereco", "Cliente_idCliente"],
	"Telefone": ["Numero", "Cliente_idCliente"],
	"Status": ["idStatus", "Descricao"],
	"Pedido": ["idPedido", "Status_idStatus", "DataPedido", "ValorTotalPedido", "Cliente_idCliente"],
	"Pedido_has_Produto": ["idPedidoProduto", "Pedido_idPedido", "Produto_idProduto", "Quantidade", "PrecoUnitario"],
}

## Tabelas atuais: nome -> lista de atributos (ordem de criação preservada).
static var TABELAS: Dictionary = MODELO_PADRAO.duplicate(true)


## Nome canônico da tabela (ignora maiúsculas/minúsculas) ou "" se não existir.
static func encontrar_tabela(nome: String) -> String:
	for tabela in TABELAS:
		if tabela.to_lower() == nome.to_lower():
			return tabela
	return ""


## Nome canônico do atributo dentro da tabela ou "" se não existir.
static func coluna_em(tabela: String, atributo: String) -> String:
	for coluna in TABELAS.get(tabela, []):
		if coluna.to_lower() == atributo.to_lower():
			return coluna
	return ""


## Todas as tabelas do modelo que possuem o atributo informado.
static func tabelas_com_atributo(atributo: String) -> Array:
	var achadas: Array = []
	for tabela in TABELAS:
		if coluna_em(tabela, atributo) != "":
			achadas.append(tabela)
	return achadas


## Cada função de alteração devolve "" em sucesso, ou a mensagem de erro.
static func criar_tabela(nome: String) -> String:
	nome = nome.strip_edges()
	var erro := _valida_nome(nome, "tabela")
	if erro != "":
		return erro
	if encontrar_tabela(nome) != "":
		return "já existe uma tabela chamada '%s' (destacada na lista)" % encontrar_tabela(nome)
	TABELAS[nome] = []
	return ""


static func excluir_tabela(nome: String) -> String:
	var tabela := encontrar_tabela(nome)
	if tabela == "":
		return "tabela '%s' não existe" % nome
	TABELAS.erase(tabela)
	return ""


static func adicionar_atributo(tabela: String, atributo: String) -> String:
	var canonica := encontrar_tabela(tabela)
	if canonica == "":
		return "tabela '%s' não existe" % tabela
	atributo = atributo.strip_edges()
	var erro := _valida_nome(atributo, "atributo")
	if erro != "":
		return erro
	var existente := coluna_em(canonica, atributo)
	if existente != "":
		return "atributo '%s' já existe em %s (destacado na lista)" % [existente, canonica]
	TABELAS[canonica].append(atributo)
	return ""


static func excluir_atributo(tabela: String, atributo: String) -> String:
	var canonica := encontrar_tabela(tabela)
	if canonica == "":
		return "tabela '%s' não existe" % tabela
	var coluna := coluna_em(canonica, atributo)
	if coluna == "":
		return "atributo '%s' não existe em %s" % [atributo, canonica]
	TABELAS[canonica].erase(coluna)
	return ""


## Volta ao modelo do enunciado.
static func restaurar_padrao() -> void:
	TABELAS = MODELO_PADRAO.duplicate(true)


static func _valida_nome(nome: String, rotulo: String) -> String:
	if nome.is_empty():
		return "informe o nome da %s" % rotulo
	if not nome.is_valid_identifier():
		return "nome inválido '%s': use só letras, números e _, sem começar por número" % nome
	if PALAVRAS_RESERVADAS.has(nome.to_upper()):
		return "'%s' é palavra reservada do SQL" % nome
	return ""
