extends SceneTree
## Testes headless da HU5 (plano de execução) e do modelo de custo / ficha teórica.
## Executar: godot --headless --path . --script res://tests/hu5/test_plano.gd

const SqlValidator := preload("res://hu1_entrada_validacao/sql_validator.gd")
const AlgebraConverter := preload("res://hu2_algebra_relacional/algebra_converter.gd")
const Grafo := preload("res://hu3_grafo_operadores/grafo_operadores.gd")
const Otimizador := preload("res://hu4_otimizacao/otimizador.gd")
const Estimativa := preload("res://hu4_otimizacao/estimativa.gd")
const Plano := preload("res://hu5_plano_execucao/plano.gd")
const FichaNo := preload("res://app/ficha_no.gd")

const SETE_JOINS := "Select cliente.nome, tipocliente.descricao, pedido.idPedido, pedido.DataPedido, Status.descricao, pedido.ValorTotalPedido, categoria.descricao, produto.QuantEstoque from Cliente Join pedido on cliente.idcliente = pedido.Cliente_idCliente Join tipocliente on cliente.tipocliente_idtipocliente = tipocliente.idTipoCliente Join endereco on cliente.idcliente = endereco.Cliente_idCliente Join Status on Status.idstatus = Pedido.status_idstatus Join pedido_has_produto on pedido.idPedido = pedido_has_produto.Pedido_idPedido Join produto on produto.idProduto = pedido_has_produto.Produto_idProduto Join categoria on categoria.idcategoria = produto.Categoria_idCategoria where Status.descricao = 'Aberto' and cliente.email = 'Luffy@gmail.com' and pedido.ValorTotalPedido = 0 and produto.preco > 5000 and endereco.cidade = 'Gramado';"

var _total := 0
var _falhas := 0


func _init() -> void:
	# Plano da consulta simples, na ordem do grafo otimizado
	var simples := _otimizado("SELECT Cliente.Nome FROM Cliente JOIN Pedido ON Pedido.Cliente_idCliente = Cliente.idCliente WHERE Pedido.ValorTotalPedido > 100")
	var plano := Plano.gerar(simples.grafo, simples.tuplas)
	var expressoes: Array = []
	for passo in plano:
		expressoes.append("%s ← %s" % [passo.resultado, passo.expressao])
	var esperado := [
		"R1 ← Pedido",
		"R2 ← σ{Pedido.ValorTotalPedido > 100}(R1)",
		"R3 ← π{Pedido.Cliente_idCliente}(R2)",
		"R4 ← Cliente",
		"R5 ← π{Cliente.idCliente, Cliente.Nome}(R4)",
		"R6 ← R3 ⋈{Pedido.Cliente_idCliente = Cliente.idCliente} R5",
		"RESULTADO ← π{Cliente.Nome}(R6)",
	]
	_checar(expressoes == esperado, "plano diferente do esperado:\n  " + "\n  ".join(expressoes))
	_checar(Plano.respeita_dependencias(plano), "cada passo deve usar só resultados de passos anteriores")

	# Consulta com 7 JOINs: plano completo, ordenado e terminando na projeção
	var grande := _otimizado(SETE_JOINS)
	var plano_grande := Plano.gerar(grande.grafo, grande.tuplas)
	_checar(plano_grande.size() == grande.grafo.nos.size(), "o plano lista todas as operações do grafo")
	_checar(Plano.respeita_dependencias(plano_grande), "plano grande respeita dependências")
	_checar(plano_grande[-1].op == "project" and plano_grande[-1].resultado == "RESULTADO", "o último passo é a projeção final")
	for i in plano_grande.size():
		_checar(plano_grande[i].ordem == i + 1, "ordem numerada em sequência")

	# Custo: o plano otimizado gera menos tuplas intermediárias que a forma canônica
	var r := SqlValidator.validate(SETE_JOINS)
	var canonico := Grafo.construir(AlgebraConverter.converter(r.ast))
	var custo_canonico := Estimativa.custo(canonico, Estimativa.estimar(canonico))
	var custo_otimizado := Estimativa.custo(grande.grafo, grande.tuplas)
	_checar(custo_otimizado < custo_canonico, "otimização deveria reduzir o custo (%s → %s)" % [custo_canonico, custo_otimizado])

	# Esquema e grau: junção soma os graus; σ mantém; π reduz
	for no in grande.grafo.nos:
		match no.op:
			"join":
				var soma := 0
				for filho in no.filhos:
					soma += Grafo.obter_no(grande.grafo, filho).grau
				_checar(no.grau == soma, "grau da junção #%d deve ser a soma das entradas" % no.id)
			"select":
				_checar(no.grau == Grafo.obter_no(grande.grafo, no.filhos[0]).grau, "σ não muda o grau (#%d)" % no.id)
			"project":
				_checar(no.grau <= Grafo.obter_no(grande.grafo, no.filhos[0]).grau, "π não aumenta o grau (#%d)" % no.id)

	# Ficha teórica: folha e operadores trazem definição formal
	var ficha_folha := FichaNo.bbcode(simples.grafo, 1, simples.tuplas, r.atributos)
	_checar(ficha_folha.contains("RELAÇÃO BASE") and ficha_folha.contains("Pedido(idPedido"), "ficha da folha mostra o esquema da relação")
	_checar(FichaNo.bbcode(simples.grafo, 2, simples.tuplas, r.atributos).contains("σ_c(R) = { t ∈ R | c(t) é verdadeira }"), "ficha da seleção mostra a definição")
	_checar(FichaNo.bbcode(simples.grafo, 6, simples.tuplas, r.atributos).contains("R ⋈_c S = σ_c(R × S)"), "ficha da junção mostra a definição")
	_checar(FichaNo.bbcode(simples.grafo, 7, simples.tuplas, r.atributos).contains("raiz"), "ficha da raiz indica que é a raiz")

	print("%d/%d testes passaram" % [_total - _falhas, _total])
	quit(1 if _falhas > 0 else 0)


func _otimizado(sql: String) -> Dictionary:
	var r := SqlValidator.validate(sql)
	_checar(r.ok, "consulta inválida: %s" % r.erro)
	var grafo := Grafo.construir(Otimizador.otimizar(r.ast).arvore)
	return {"grafo": grafo, "tuplas": Estimativa.estimar(grafo)}


func _checar(condicao: bool, mensagem: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		print("FALHA: " + mensagem)
