extends PanelContainer
## HU1 – tela BANCO (F11): cria e remove tabelas e atributos do modelo
## usado pelo validador. As mudanças valem só enquanto o programa estiver aberto.

const DbSchema := preload("res://hu1_entrada_validacao/db_schema.gd")
const COR_OK := Color(0.2, 1.0, 0.4)
const COR_ERRO := Color(1.0, 0.35, 0.35)

signal fechado

@onready var _lista_tabelas: ItemList = $Conteudo/Corpo/ColTabelas/ListaTabelas
@onready var _campo_tabela: LineEdit = $Conteudo/Corpo/ColTabelas/LinhaNovaTabela/CampoNovaTabela
@onready var _rotulo_atributos: Label = $Conteudo/Corpo/ColAtributos/RotuloAtributos
@onready var _lista_atributos: ItemList = $Conteudo/Corpo/ColAtributos/ListaAtributos
@onready var _campo_atributo: LineEdit = $Conteudo/Corpo/ColAtributos/LinhaNovoAtributo/CampoNovoAtributo
@onready var _status: Label = $Conteudo/Status


func _ready() -> void:
	$Conteudo/Corpo/ColTabelas/LinhaNovaTabela/BotaoCriarTabela.pressed.connect(_criar_tabela)
	$Conteudo/Corpo/ColTabelas/BotaoExcluirTabela.pressed.connect(_excluir_tabela)
	$Conteudo/Corpo/ColAtributos/LinhaNovoAtributo/BotaoAdicionarAtributo.pressed.connect(_adicionar_atributo)
	$Conteudo/Corpo/ColAtributos/BotaoExcluirAtributo.pressed.connect(_excluir_atributo)
	$Conteudo/Rodape/BotaoRestaurar.pressed.connect(_restaurar)
	$Conteudo/Rodape/BotaoFechar.pressed.connect(fechar)
	_campo_tabela.text_submitted.connect(func(_texto: String) -> void: _criar_tabela())
	_campo_atributo.text_submitted.connect(func(_texto: String) -> void: _adicionar_atributo())
	_lista_tabelas.item_selected.connect(func(_indice: int) -> void: _mostra_atributos())
	visible = false


func abrir() -> void:
	visible = true
	_atualiza_tabelas()
	_campo_tabela.grab_focus()


func fechar() -> void:
	visible = false
	fechado.emit()


func _atualiza_tabelas(selecionar := "") -> void:
	_lista_tabelas.clear()
	for tabela in DbSchema.TABELAS:
		_lista_tabelas.add_item(tabela)
		if tabela == selecionar:
			_lista_tabelas.select(_lista_tabelas.item_count - 1)
	if selecionar == "" and _lista_tabelas.item_count > 0:
		_lista_tabelas.select(0)
	_mostra_atributos()


func _tabela_selecionada() -> String:
	var selecionados := _lista_tabelas.get_selected_items()
	if selecionados.is_empty():
		return ""
	return _lista_tabelas.get_item_text(selecionados[0])


func _mostra_atributos() -> void:
	_lista_atributos.clear()
	var tabela := _tabela_selecionada()
	if tabela == "":
		_rotulo_atributos.text = "ATRIBUTOS"
		return
	_rotulo_atributos.text = "ATRIBUTOS de %s" % tabela
	for atributo in DbSchema.TABELAS[tabela]:
		_lista_atributos.add_item(atributo)


func _criar_tabela() -> void:
	var nome := _campo_tabela.text.strip_edges()
	var erro := DbSchema.criar_tabela(nome)
	_mostra_resultado(erro, "tabela '%s' criada" % nome)
	if erro == "":
		_campo_tabela.clear()
		_atualiza_tabelas(nome)
	elif DbSchema.encontrar_tabela(nome) != "":
		_atualiza_tabelas(DbSchema.encontrar_tabela(nome))
		_destaca(_lista_tabelas, DbSchema.encontrar_tabela(nome))


func _excluir_tabela() -> void:
	var tabela := _tabela_selecionada()
	if tabela == "":
		_mostra_status("selecione uma tabela na lista", false)
		return
	_mostra_resultado(DbSchema.excluir_tabela(tabela), "tabela '%s' excluída" % tabela)
	_atualiza_tabelas()


func _adicionar_atributo() -> void:
	var tabela := _tabela_selecionada()
	if tabela == "":
		_mostra_status("selecione uma tabela antes de adicionar atributos", false)
		return
	var atributo := _campo_atributo.text.strip_edges()
	var erro := DbSchema.adicionar_atributo(tabela, atributo)
	_mostra_resultado(erro, "atributo '%s' adicionado a %s" % [atributo, tabela])
	if erro == "":
		_campo_atributo.clear()
		_atualiza_tabelas(tabela)
	elif DbSchema.coluna_em(tabela, atributo) != "":
		_destaca(_lista_atributos, DbSchema.coluna_em(tabela, atributo))


func _excluir_atributo() -> void:
	var tabela := _tabela_selecionada()
	var selecionados := _lista_atributos.get_selected_items()
	if tabela == "" or selecionados.is_empty():
		_mostra_status("selecione um atributo na lista", false)
		return
	var atributo := _lista_atributos.get_item_text(selecionados[0])
	_mostra_resultado(DbSchema.excluir_atributo(tabela, atributo), "atributo '%s' excluído de %s" % [atributo, tabela])
	_atualiza_tabelas(tabela)


func _restaurar() -> void:
	DbSchema.restaurar_padrao()
	_mostra_resultado("", "modelo padrão restaurado (Imagem 01)")
	_atualiza_tabelas()


func _mostra_resultado(erro: String, sucesso: String) -> void:
	_mostra_status(erro if erro != "" else sucesso, erro == "")


## Seleciona e rola até o item já existente, para o usuário ver o repetido.
func _destaca(lista: ItemList, texto: String) -> void:
	for i in lista.item_count:
		if lista.get_item_text(i) == texto:
			lista.select(i)
			lista.ensure_current_is_visible()
			return


func _mostra_status(texto: String, ok: bool) -> void:
	_status.text = ("OK: " if ok else "ERRO: ") + texto
	_status.add_theme_color_override("font_color", COR_OK if ok else COR_ERRO)
