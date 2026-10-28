extends SceneTree
## Testes headless da tela BANCO: criar/excluir tabelas e atributos e
## verificar que o validador passa a enxergar as mudanças.
## Executar: godot --headless --path . --script res://tests/hu1/test_banco.gd

const DbSchema := preload("res://hu1_entrada_validacao/db_schema.gd")
const SqlValidator := preload("res://hu1_entrada_validacao/sql_validator.gd")

var _total := 0
var _falhas := 0


func _init() -> void:
	DbSchema.restaurar_padrao()

	_checar(DbSchema.criar_tabela("Fornecedor") == "", "deveria criar a tabela Fornecedor")
	_checar(DbSchema.criar_tabela("fornecedor") != "", "nome repetido (sem diferença de caixa) deveria falhar")
	_checar(DbSchema.criar_tabela("1tabela") != "", "nome começando por número deveria falhar")
	_checar(DbSchema.criar_tabela("from") != "", "palavra reservada do SQL deveria falhar")
	_checar(DbSchema.criar_tabela("") != "", "nome vazio deveria falhar")

	_checar(DbSchema.adicionar_atributo("Fornecedor", "Nome") == "", "deveria adicionar Nome em Fornecedor")
	_checar(DbSchema.adicionar_atributo("Fornecedor", "nome") != "", "atributo repetido deveria falhar")
	_checar(DbSchema.adicionar_atributo("Inexistente", "x") != "", "tabela inexistente deveria falhar")
	_checar(DbSchema.adicionar_atributo("Fornecedor", "Cidade Nova") != "", "atributo com espaço deveria falhar")

	# O validador enxerga a tabela e o atributo novos
	var r := SqlValidator.validate("SELECT Fornecedor.Nome FROM Fornecedor")
	_checar(r.ok, "consulta sobre a tabela nova deveria ser válida: %s" % r.erro)

	# Exclusão: a consulta volta a ser inválida
	_checar(DbSchema.excluir_atributo("Fornecedor", "Nome") == "", "deveria excluir o atributo")
	_checar(not SqlValidator.validate("SELECT Fornecedor.Nome FROM Fornecedor").ok, "atributo excluído não deveria validar")
	_checar(DbSchema.excluir_tabela("Fornecedor") == "", "deveria excluir a tabela")
	_checar(not SqlValidator.validate("SELECT * FROM Fornecedor").ok, "tabela excluída não deveria validar")

	# Restaurar devolve o modelo do enunciado
	DbSchema.criar_tabela("Teste")
	DbSchema.restaurar_padrao()
	_checar(DbSchema.encontrar_tabela("Teste") == "", "restaurar deveria remover tabelas criadas")
	_checar(DbSchema.encontrar_tabela("Cliente") == "Cliente", "restaurar deveria manter as tabelas do enunciado")

	print("%d/%d testes passaram" % [_total - _falhas, _total])
	quit(1 if _falhas > 0 else 0)


func _checar(condicao: bool, mensagem: String) -> void:
	_total += 1
	if not condicao:
		_falhas += 1
		print("FALHA: " + mensagem)
