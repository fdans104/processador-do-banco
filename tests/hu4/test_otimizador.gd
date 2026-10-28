extends SceneTree
## Testes headless da HU4 (otimização heurística).
## Executar: godot --headless --path . --script res://tests/hu4/test_otimizador.gd

const SqlValidator := preload("res://hu1_entrada_validacao/sql_validator.gd")
const AlgebraConverter := preload("res://hu2_algebra_relacional/algebra_converter.gd")
const AlgebraRenderer := preload("res://hu2_algebra_relacional/algebra_renderer.gd")
const Grafo := preload("res://hu3_grafo_operadores/grafo_operadores.gd")
const Otimizador := preload("res://hu4_otimizacao/otimizador.gd")
const Estimativa := preload("res://hu4_otimizacao/estimativa.gd")

const SETE_JOINS := "Select cliente.nome, tipocliente.descricao, pedido.idPedido, pedido.DataPedido, Status.descricao, pedido.ValorTotalPedido, categoria.descricao, produto.QuantEstoque from Cliente Join pedido on cliente.idcliente = pedido.Cliente_idCliente Join tipocliente on cliente.tipocliente_idtipocliente = tipocliente.idTipoCliente Join endereco on cliente.idcliente = endereco.Cliente_idCliente Join Status on Status.idstatus = Pedido.status_idstatus Join pedido_has_produto on pedido.idPedido = pedido_has_produto.Pedido_idPedido Join produto on produto.idProduto = pedido_has_produto.Produto_idProduto Join categoria on categoria.idcategoria = produto.Categoria_idCategoria where Status.descricao = 'Aberto' and cliente.email = 'Luffy@gmail.com' and pedido.ValorTotalPedido = 0 and produto.preco > 5000 and endereco.cidade = 'Gramado';"

var _total := 0
var _falhas := 0


func _init() -> void:
	# Seleção desce, projeções reduzem atributos, Pedido (mais restritiva) entra primeiro
	_esperar_linear(
		"SELECT Cliente.Nome FROM Cliente JOIN Pedido ON Pedido.Cliente_idCliente = Cliente.idCliente WHERE Pedido.ValorTotalPedido > 100",
		"π{Cliente.Nome}(π{Pedido.Cliente_idCliente}(σ{Pedido.ValorTotalPedido > 100}(Pedido)) ⋈{Pedido.Cliente_idCliente = Cliente.idCliente} π{Cliente.idCliente, Cliente.Nome}(Cliente))")
	# Uma tabela: só σ e o π final
	_esperar_linear("SELECT Nome FROM Produto WHERE Preco > 10", "π{Produto.Nome}(σ{Produto.Preco > 10}(Produto))")
	# SELECT *: nenhuma projeção intermediária
	_esperar_linear(
		"SELECT * FROM Cliente JOIN Pedido ON Pedido.Cliente_idCliente = Cliente.idCliente WHERE Cliente.Nome = 'Ana'",
		"π{*}(σ{Cliente.Nome = 'Ana'}(Cliente) ⋈{Pedido.Cliente_idCliente = Cliente.idCliente} Pedido)")
	# ON com uma tabela só: vira seleção e o × é inevitável (e avisado)
	var produto := _otimiza("SELECT * FROM Cliente JOIN Status ON Status.Descricao = 'Aberto'")
	_checar(AlgebraRenderer.texto_linear(produto.arvore).contains("×"), "deveria haver produto cartesiano inevitável")
	_checar(" ".join(produto.heuristicas).contains("inevitável"), "o produto inevitável deveria ser explicado")

	# Consulta com 7 JOINs
	var grande := _otimiza(SETE_JOINS)
	var linear := AlgebraRenderer.texto_linear(grande.arvore)
	_checar(not linear.contains("×"), "não deveria haver produto cartesiano")
	_checar(linear.count("⋈") == 7, "deveria manter as 7 junções")
	_checar(linear.count("σ") == 5, "cada condição de uma tabela vira uma seleção (5)")
	_checar(grande.ordem[0] == "Cliente", "deveria começar pela primeira tabela mais restritiva (Cliente), veio %s" % grande.ordem[0])
	_checar(grande.ordem.size() == 8, "todas as 8 tabelas devem entrar na junção")

	var grafo := Grafo.construir(grande.arvore)
	_checar(Grafo.obter_no(grafo, grafo.raiz).op == "project", "a raiz continua sendo a última projeção")
	for no in grafo.nos:
		if no.op == "select":
			# H1: toda seleção fica logo acima da tabela
			_checar(Grafo.obter_no(grafo, no.filhos[0]).op == "tabela", "seleção #%d deveria estar logo acima de uma tabela" % no.id)
		if no.op == "tabela" and no.detalhe == "Cliente":
			# H2: Cliente passa por σ (Email) e depois por π só com o que ainda é usado
			var selecao := Grafo.consumidor(grafo, no.id)
			var projecao := Grafo.obter_no(grafo, Grafo.consumidor(grafo, selecao))
			_checar(projecao.op == "project", "Cliente deveria ter projeção logo após a seleção")
			_checar(projecao.detalhe == "Cliente.idCliente, Cliente.Nome, Cliente.TipoCliente_idTipoCliente",
				"projeção de Cliente deveria manter só idCliente, Nome e TipoCliente_idTipoCliente, veio %s" % projecao.detalhe)

	# Condições preservadas: mesmas comparações da forma canônica
	var canonica := AlgebraRenderer.texto_linear(AlgebraConverter.converter(SqlValidator.validate(SETE_JOINS).ast))
	for comparacao in ["Status.Descricao = 'Aberto'", "Cliente.Email = 'Luffy@gmail.com'", "Produto.Preco > 5000", "Categoria.idCategoria = Produto.Categoria_idCategoria"]:
		_checar(canonica.contains(comparacao) and linear.contains(comparacao), "condição perdida na otimização: %s" % comparacao)

	# Etapas (passo 5): H1 → H2 → H3 → H4, cada uma sobre a anterior
	var etapas: Array = grande.etapas
	_checar(etapas.size() == 4 and etapas[0].id == "H1" and etapas[3].id == "H4", "deveria haver as etapas H1..H4")
	_checar(AlgebraRenderer.texto_linear(etapas[3].arvore) == linear, "a última etapa é a árvore otimizada final")
	_checar(AlgebraRenderer.texto_linear(etapas[0].arvore).count("σ") == 5 and not AlgebraRenderer.texto_linear(etapas[0].arvore).contains("π{Cliente.idCliente"), "H1 só desce seleções (ainda sem projeções intermediárias)")
	_checar(AlgebraRenderer.texto_linear(etapas[1].arvore).contains("π{Cliente.idCliente, Cliente.Nome, Cliente.TipoCliente_idTipoCliente}"), "H2 acrescenta as projeções")
	_checar(AlgebraRenderer.texto_linear(etapas[2].arvore).contains("×"), "H3 sozinha (só estimativa) cria produto cartesiano nesta consulta")
	_checar(not AlgebraRenderer.texto_linear(etapas[3].arvore).contains("×"), "H4 elimina o produto cartesiano")
	var custos: Array = []
	var volumes: Array = []
	for etapa in etapas:
		var g := Grafo.construir(etapa.arvore)
		var t := Estimativa.estimar(g)
		custos.append(Estimativa.custo(g, t))
		volumes.append(Estimativa.volume(g, t))
	var canonico := Grafo.construir(AlgebraConverter.converter(SqlValidator.validate(SETE_JOINS).ast))
	var custo_canonico := Estimativa.custo(canonico, Estimativa.estimar(canonico))
	_checar(custos[0] < custo_canonico, "H1 reduz as tuplas processadas")
	_checar(volumes[1] < volumes[0], "H2 reduz o volume que chega às junções")
	_checar(custos[2] > custos[1], "H3 sem H4 encarece (produto cartesiano)")
	_checar(custos[3] < custos[2] and custos[3] <= custos[1], "H4 dá o menor custo")

	# Toda relação base vale 1000 tuplas; junção por igualdade tem seletividade 1/1000
	_checar(Estimativa.cardinalidade("Cliente") == 1000.0 and Estimativa.cardinalidade("Pedido") == 1000.0, "toda tabela deveria valer 1000 tuplas")
	var juncao: Dictionary = SqlValidator.validate("SELECT * FROM Cliente JOIN Pedido ON Pedido.Cliente_idCliente = Cliente.idCliente").ast.joins[0].condicao
	_checar(is_equal_approx(Estimativa.seletividade(juncao), 1.0 / 1000.0), "sel(junção) deveria ser 1/1000")

	print("%d/%d testes passaram" % [_total - _falhas, _total])
	quit(1 if _falhas > 0 else 0)


func _otimiza(sql: String) -> Dictionary:
	var r := SqlValidator.validate(sql)
	_checar(r.ok, "consulta inválida: %s -> %s" % [sql, r.erro])
	return Otimizador.otimizar(r.ast) if r.ok else {"arvore": {"op": "tabela", "nome": "?"}, "heuristicas": [], "ordem": [""]}


func _esperar_linear(sql: String, esperada: String) -> void:
	var obtida := AlgebraRenderer.texto_linear(_otimiza(sql).arvore)
	_checar(obtida == esperada, "otimização diferente\n  sql:      %s\n  esperada: %s\n  obtida:   %s" % [sql, esperada, obtida])


func _checar(condicao: bool, mensagem: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		print("FALHA: " + mensagem)
