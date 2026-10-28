extends SceneTree
## Testes headless da HU2 (conversão para álgebra relacional).
## Executar: godot --headless --path . --script res://tests/hu2/test_algebra.gd

const SqlValidator := preload("res://hu1_entrada_validacao/sql_validator.gd")
const AlgebraConverter := preload("res://hu2_algebra_relacional/algebra_converter.gd")
const AlgebraRenderer := preload("res://hu2_algebra_relacional/algebra_renderer.gd")

var _total := 0
var _falhas := 0


func _init() -> void:
	# Notação linear esperada: [consulta, álgebra]
	_esperar_linear("SELECT * FROM Cliente", "π{*}(Cliente)")
	_esperar_linear("select cliente.nome from cliente", "π{Cliente.Nome}(Cliente)")
	_esperar_linear(
		"SELECT Cliente.Nome FROM Cliente WHERE Cliente.Nome = 'Ana'",
		"π{Cliente.Nome}(σ{Cliente.Nome = 'Ana'}(Cliente))")
	_esperar_linear(
		"SELECT Cliente.Nome FROM Cliente JOIN Pedido ON Pedido.Cliente_idCliente = Cliente.idCliente WHERE Pedido.ValorTotalPedido > 100",
		"π{Cliente.Nome}(σ{Pedido.ValorTotalPedido > 100}(Cliente ⋈{Pedido.Cliente_idCliente = Cliente.idCliente} Pedido))")
	_esperar_linear(
		"SELECT * FROM Cliente JOIN Pedido ON Pedido.Cliente_idCliente = Cliente.idCliente JOIN Status ON Status.idStatus = Pedido.Status_idStatus WHERE (Cliente.Nome = 'Ana') AND Status.Descricao = 'Aberto'",
		"π{*}(σ{(Cliente.Nome = 'Ana') ∧ Status.Descricao = 'Aberto'}((Cliente ⋈{Pedido.Cliente_idCliente = Cliente.idCliente} Pedido) ⋈{Status.idStatus = Pedido.Status_idStatus} Status))")

	# Consulta do usuário com 7 JOINs: deve haver 7 junções e 1 seleção
	var grande := SqlValidator.validate("Select cliente.nome, tipocliente.descricao, pedido.idPedido, pedido.DataPedido, Status.descricao, pedido.ValorTotalPedido, categoria.descricao, produto.QuantEstoque from Cliente Join pedido on cliente.idcliente = pedido.Cliente_idCliente Join tipocliente on cliente.tipocliente_idtipocliente = tipocliente.idTipoCliente Join endereco on cliente.idcliente = endereco.Cliente_idCliente Join Status on Status.idstatus = Pedido.status_idstatus Join pedido_has_produto on pedido.idPedido = pedido_has_produto.Pedido_idPedido Join produto on produto.idProduto = pedido_has_produto.Produto_idProduto Join categoria on categoria.idcategoria = produto.Categoria_idCategoria where Status.descricao = 'Aberto' and cliente.email = 'Luffy@gmail.com' and pedido.ValorTotalPedido = 0 and produto.preco > 5000 and endereco.cidade = 'Gramado';")
	_checar(grande.ok, "consulta com 7 JOINs deveria ser válida: %s" % grande.erro)
	if grande.ok:
		var linear := AlgebraRenderer.texto_linear(AlgebraConverter.converter(grande.ast))
		_checar(linear.count("⋈") == 7, "esperava 7 junções, veio %d" % linear.count("⋈"))
		_checar(linear.count("σ") == 1, "esperava 1 seleção")
		_checar(linear.count("∧") == 4, "esperava 4 conjunções (5 condições do WHERE)")
		_checar(linear.begins_with("π{"), "a álgebra deveria começar pela projeção")

	# Árvore: raiz é a projeção, folhas são as tabelas
	var ast: Dictionary = SqlValidator.validate("SELECT Cliente.Nome FROM Cliente JOIN Pedido ON Pedido.Cliente_idCliente = Cliente.idCliente WHERE Pedido.ValorTotalPedido > 100").ast
	var arvore := AlgebraRenderer.texto_arvore(AlgebraConverter.converter(ast))
	var esperada := "\n".join([
		"π {Cliente.Nome}",
		"└── σ {Pedido.ValorTotalPedido > 100}",
		"    └── ⋈ {Pedido.Cliente_idCliente = Cliente.idCliente}",
		"        ├── Cliente",
		"        └── Pedido",
	])
	_checar(arvore == esperada, "árvore diferente do esperado:\n%s" % arvore)

	print("%d/%d testes passaram" % [_total - _falhas, _total])
	quit(1 if _falhas > 0 else 0)


func _esperar_linear(sql: String, esperada: String) -> void:
	var r := SqlValidator.validate(sql)
	if not r.ok:
		_checar(false, "consulta inválida: %s -> %s" % [sql, r.erro])
		return
	var obtida := AlgebraRenderer.texto_linear(AlgebraConverter.converter(r.ast))
	_checar(obtida == esperada, "álgebra diferente\n  sql:      %s\n  esperada: %s\n  obtida:   %s" % [sql, esperada, obtida])


func _checar(condicao: bool, mensagem: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		print("FALHA: " + mensagem)
