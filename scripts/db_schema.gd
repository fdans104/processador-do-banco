extends RefCounted
## Modelo de dados de referência (enunciado / Imagem 01).
## Fonte única das tabelas e atributos aceitos pelo parser.

const TABELAS: Dictionary = {
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
