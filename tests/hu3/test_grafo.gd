extends SceneTree
## Testes headless da HU3 (grafo de operadores).
## Executar: godot --headless --path . --script res://tests/hu3/test_grafo.gd

const SqlValidator := preload("res://hu1_entrada_validacao/sql_validator.gd")
const AlgebraConverter := preload("res://hu2_algebra_relacional/algebra_converter.gd")
const Grafo := preload("res://hu3_grafo_operadores/grafo_operadores.gd")

var _total := 0
var _falhas := 0


func _init() -> void:
	var simples := _grafo_de("SELECT Cliente.Nome FROM Cliente JOIN Pedido ON Pedido.Cliente_idCliente = Cliente.idCliente WHERE Pedido.ValorTotalPedido > 100")
	# Ordem de execução (pós-ordem): Cliente, Pedido, ⋈, σ, π
	var ops: Array = []
	for no in simples.nos:
		ops.append(no.op)
	_checar(ops == ["tabela", "tabela", "join", "select", "project"], "ordem de execução inesperada: %s" % str(ops))
	_checar(Grafo.obter_no(simples, simples.raiz).op == "project", "a raiz deve ser a última projeção")
	_checar(simples.raiz == simples.nos.size(), "a raiz deve ser o último nó a executar")
	_checar(simples.arestas.size() == simples.nos.size() - 1, "árvore: arestas = nós - 1")
	_checar(Grafo.obter_no(simples, 1).detalhe == "Cliente" and Grafo.obter_no(simples, 2).detalhe == "Pedido", "folhas devem ser Cliente e Pedido")
	_checar(Grafo.obter_no(simples, 3).detalhe == "Pedido.Cliente_idCliente = Cliente.idCliente", "o nó de junção deve manter a condição do ON")
	_checar(Grafo.consumidor(simples, 3) == 4, "a junção deve enviar o resultado para a seleção")
	_checar(Grafo.consumidor(simples, simples.raiz) == -1, "a raiz não envia para ninguém")

	# Consulta do usuário com 7 JOINs
	var grande := _grafo_de("Select cliente.nome, tipocliente.descricao, pedido.idPedido, pedido.DataPedido, Status.descricao, pedido.ValorTotalPedido, categoria.descricao, produto.QuantEstoque from Cliente Join pedido on cliente.idcliente = pedido.Cliente_idCliente Join tipocliente on cliente.tipocliente_idtipocliente = tipocliente.idTipoCliente Join endereco on cliente.idcliente = endereco.Cliente_idCliente Join Status on Status.idstatus = Pedido.status_idstatus Join pedido_has_produto on pedido.idPedido = pedido_has_produto.Pedido_idPedido Join produto on produto.idProduto = pedido_has_produto.Produto_idProduto Join categoria on categoria.idcategoria = produto.Categoria_idCategoria where Status.descricao = 'Aberto' and cliente.email = 'Luffy@gmail.com' and pedido.ValorTotalPedido = 0 and produto.preco > 5000 and endereco.cidade = 'Gramado';")
	_checar(grande.folhas.size() == 8, "deveria haver 8 tabelas (folhas)")
	var juncoes := 0
	for no in grande.nos:
		if no.op == "join":
			juncoes += 1
		# Folhas são tabelas e somente tabelas não têm filhos
		_checar((no.op == "tabela") == no.filhos.is_empty(), "nó #%d: só tabelas podem ser folhas" % no.id)
	_checar(juncoes == 7, "deveria haver 7 junções")

	# Dependências lógicas: toda aresta vai de um nó que executa antes para um que executa depois
	for aresta in grande.arestas:
		_checar(aresta.de < aresta.para, "aresta #%d -> #%d viola a ordem de execução" % [aresta.de, aresta.para])

	# Toda tabela chega até a raiz seguindo as arestas
	for folha in grande.folhas:
		var atual: int = folha
		var passos := 0
		while Grafo.consumidor(grande, atual) != -1 and passos < 100:
			atual = Grafo.consumidor(grande, atual)
			passos += 1
		_checar(atual == grande.raiz, "a tabela #%d deveria chegar à raiz" % folha)

	print("%d/%d testes passaram" % [_total - _falhas, _total])
	quit(1 if _falhas > 0 else 0)


func _grafo_de(sql: String) -> Dictionary:
	var r := SqlValidator.validate(sql)
	if not r.ok:
		_checar(false, "consulta inválida: %s" % r.erro)
		return {"nos": [], "arestas": [], "raiz": 0, "folhas": []}
	return Grafo.construir(AlgebraConverter.converter(r.ast))


func _checar(condicao: bool, mensagem: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		print("FALHA: " + mensagem)
