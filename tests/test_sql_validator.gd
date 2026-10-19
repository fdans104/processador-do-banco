extends SceneTree
## Testes headless do validador (HU1).
## Executar: godot --headless --path . --script res://tests/test_sql_validator.gd

const SqlValidator := preload("res://scripts/sql_validator.gd")

var _total := 0
var _falhas := 0


func _init() -> void:
	# --- consultas válidas ---
	_esperar_ok("SELECT * FROM Cliente")
	_esperar_ok("select nome from cliente ;")
	_esperar_ok("sElEcT   Cliente.Nome,\t Cliente.idCliente   FROM   Cliente")
	_esperar_ok("SELECT Cliente.Nome, Pedido.idPedido FROM Cliente JOIN Pedido ON Pedido.Cliente_idCliente = Cliente.idCliente WHERE Pedido.ValorTotalPedido >= 100 AND Cliente.Nome <> 'Ana'")
	_esperar_ok("SELECT Produto.Nome FROM Produto JOIN Pedido_has_Produto ON Pedido_has_Produto.Produto_idProduto = Produto.idProduto JOIN Pedido ON Pedido.idPedido = Pedido_has_Produto.Pedido_idPedido JOIN Cliente ON Cliente.idCliente = Pedido.Cliente_idCliente WHERE (Produto.Preco <= 50) AND (Cliente.Nome = 'Ana')")
	_esperar_ok("SELECT Nome FROM Produto WHERE ((Preco > 10) AND (QuantEstoque <= 5))")
	_esperar_ok("SELECT * FROM Produto WHERE Preco = 1 AND Preco > 2 AND Preco < 3 AND Preco <= 4 AND Preco >= 5 AND Preco <> 6")
	_esperar_ok("SELECT * FROM Produto WHERE Preco > 10.5")
	_esperar_ok("SELECT * FROM Produto WHERE Nome = ''")

	# --- consultas do usuário (HU1 reais) ---
	_esperar_ok("Select cliente.nome, pedido.idPedido, pedido.DataPedido, pedido.ValorTotalPedido from Cliente Join pedido on cliente.idcliente = pedido.Cliente_idCliente where cliente.TipoCliente_idTipoCliente = 1 and pedido.ValorTotalPedido = 0;")
	_esperar_ok("Select cliente.nome, pedido.idPedido, pedido.DataPedido, Status.descricao, pedido.ValorTotalPedido from Cliente Join pedido on cliente.idcliente = pedido.Cliente_idCliente Join Status on Status.idstatus = Pedido.status_idstatus where Status.descricao = 'Aberto' and cliente.TipoCliente_idTipoCliente = 1 and pedido.ValorTotalPedido = 0;")
	_esperar_ok("Select cliente.nome, pedido.idPedido, pedido.DataPedido, Status.descricao, pedido.ValorTotalPedido, produto.QuantEstoque from Cliente Join pedido on cliente.idcliente = pedido.Cliente_idCliente Join Status on Status.idstatus = Pedido.status_idstatus Join pedido_has_produto on pedido.idPedido = pedido_has_produto.Pedido_idPedido Join produto on produto.idProduto = pedido_has_produto.Produto_idProduto where Status.descricao = 'Aberto' and cliente.TipoCliente_idTipoCliente = 1 and pedido.ValorTotalPedido = 0 and produto.QuantEstoque > 0;")
	_esperar_ok("Select cliente.nome, tipocliente.descricao, pedido.idPedido, pedido.DataPedido, Status.descricao, pedido.ValorTotalPedido, categoria.descricao, produto.QuantEstoque from Cliente Join pedido on cliente.idcliente = pedido.Cliente_idCliente Join tipocliente on cliente.tipocliente_idtipocliente = tipocliente.idTipoCliente Join endereco on cliente.idcliente = endereco.Cliente_idCliente Join Status on Status.idstatus = Pedido.status_idstatus Join pedido_has_produto on pedido.idPedido = pedido_has_produto.Pedido_idPedido Join produto on produto.idProduto = pedido_has_produto.Produto_idProduto Join categoria on categoria.idcategoria = produto.Categoria_idCategoria where Status.descricao = 'Aberto' and cliente.email = 'Luffy@gmail.com' and pedido.ValorTotalPedido = 0 and produto.preco > 5000 and endereco.cidade = 'Gramado';")

	# --- erros esperados: [consulta, trecho da mensagem] ---
	_esperar_erro("SELECT * FROM Clientes", "tabela 'Clientes' não existe")
	_esperar_erro("SELECT Foo FROM Cliente", "atributo 'Foo' não existe no modelo")
	_esperar_erro("SELECT Preco FROM Cliente", "não pertence às tabelas da consulta")
	_esperar_erro("SELECT Nome FROM Cliente JOIN Produto ON Produto.idProduto = Cliente.idCliente", "é ambíguo")
	_esperar_erro("SELECT Cliente.Preco FROM Cliente", "atributo 'Preco' não existe na tabela Cliente")
	_esperar_erro("SELECT Produto.Nome FROM Cliente", "tabela 'Produto' não faz parte do FROM/JOIN")
	_esperar_erro("SELECT * FROM Cliente WHERE Nome = ", "esperado atributo ou valor")
	_esperar_erro("SELECT * FROM Cliente WHERE Nome != 'x'", "caractere inválido '!'")
	_esperar_erro("SELECT * FROM Cliente WHERE Nome LIKE 'x'", "esperado operador")
	_esperar_erro("SELECT * FROM Cliente WHERE Nome = 'Ana", "string não fechada")
	_esperar_erro("SELECT * FROM Cliente WHERE (Nome = 'Ana'", "esperado ')'")
	_esperar_erro("SELECT * Cliente", "esperado 'FROM'")
	_esperar_erro("SELECT * FROM Cliente JOIN Pedido Cliente.idCliente = Pedido.Cliente_idCliente", "esperado 'ON'")
	_esperar_erro("SELECT * FROM Cliente c", "token inesperado 'c'")
	_esperar_erro("SELECT * FROM Cliente WHERE Nome = 'Ana' OR Nome = 'Bia'", "token inesperado 'OR'")
	_esperar_erro("SELECT * FROM Cliente WHERE Nome = 'Ana' ;;", "token inesperado ';'")
	_esperar_erro("SELECT * FROM Cliente JOIN Cliente ON Cliente.idCliente = Cliente.idCliente", "repetida")
	_esperar_erro("SELECT * FROM Cliente JOIN Pedido ON Pedido.Cliente_idCliente = Produto.idProduto JOIN Produto ON Produto.idProduto = Pedido.idPedido", "tabela 'Produto' não faz parte do FROM/JOIN")
	_esperar_erro("SELECT * FROM Cliente WHERE Nome = 'Ana' AND", "esperado atributo ou valor")
	_esperar_erro("   ", "consulta vazia")

	# --- posição do erro (índice no texto original) ---
	var r := SqlValidator.validate("SELECT * FROM Clientes")
	_checar(r.pos == 14, "posição do erro de tabela deveria ser 14, veio %d" % r.pos)

	# --- tabelas e atributos resolvidos ---
	r = SqlValidator.validate("select pedido.idpedido from PEDIDO join cliente on cliente.idcliente = pedido.cliente_idcliente")
	_checar(r.ok, "consulta com caixa mista deveria ser válida: %s" % r.erro)
	_checar(r.tabelas == ["Pedido", "Cliente"], "tabelas resolvidas incorretas: %s" % str(r.tabelas))
	_checar("Pedido.idPedido" in r.atributos, "atributo idPedido deveria estar resolvido")

	print("%d/%d testes passaram" % [_total - _falhas, _total])
	quit(1 if _falhas > 0 else 0)


func _esperar_ok(sql: String) -> void:
	var r := SqlValidator.validate(sql)
	_checar(r.ok, "esperava válida: '%s' -> %s" % [sql, r.erro])


func _esperar_erro(sql: String, trecho: String) -> void:
	var r := SqlValidator.validate(sql)
	_checar(not r.ok and r.erro.contains(trecho), "esperava erro contendo '%s' em '%s', veio ok=%s erro='%s'" % [trecho, sql, r.ok, r.erro])


func _checar(condicao: bool, mensagem: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		print("FALHA: " + mensagem)
