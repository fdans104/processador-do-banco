extends Control
## Terminal do simulador (HU1): recebe a consulta SQL, valida e mostra o resultado.
## A interface é montada em scenes/main.tscn; aqui só há lógica.

const SqlValidator := preload("res://scripts/sql_validator.gd")
const DbSchema := preload("res://scripts/db_schema.gd")

const VERDE := Color(0.2, 1.0, 0.4)
const VERDE_ESCURO := Color(0.1, 0.55, 0.25)
const VERMELHO := Color(1.0, 0.35, 0.35)
const PROMPT := "sql@banco:~$ "

@onready var _saida: RichTextLabel = $Margem/Coluna/Saida
@onready var _entrada = $Margem/Coluna/Linha/Entrada
@onready var _painel: PanelContainer = $PainelConsultas
@onready var _lista: VBoxContainer = $PainelConsultas/Conteudo/Lista

var _historico: Array = []
var _indice_historico := 0


func _ready() -> void:
	_entrada.enviado.connect(_on_consulta_enviada)
	_entrada.historico_anterior.connect(_historico_anterior)
	_entrada.historico_proximo.connect(_historico_proximo)
	for botao in _lista.get_children():
		botao.pressed.connect(_on_consulta_exemplo.bind(botao.get_meta("sql", "")))
	_imprimir_banner()
	_entrada.grab_focus()


## P (com o campo vazio) abre as consultas de exemplo; P ou ESC fecham.
func _input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	if evento.keycode == KEY_ESCAPE and _painel.visible:
		_fecha_painel()
		get_viewport().set_input_as_handled()
	elif evento.keycode == KEY_P and _entrada.text.is_empty() and not evento.ctrl_pressed and not evento.alt_pressed:
		if _painel.visible:
			_fecha_painel()
		else:
			_abre_painel()
		get_viewport().set_input_as_handled()


func _abre_painel() -> void:
	_painel.visible = true
	_lista.get_child(0).grab_focus()


func _fecha_painel() -> void:
	_painel.visible = false
	_entrada.grab_focus()


func _on_consulta_exemplo(sql: String) -> void:
	_fecha_painel()
	_executa(sql)


func _imprimir_banner() -> void:
	_escreve("[color=%s]PROCESSADOR DE CONSULTAS // simulador de SGBD v0.1[/color]" % _cor(VERDE))
	_escreve("[color=%s][HU1] entrada e validação de consulta[/color]" % _cor(VERDE_ESCURO))
	_escreve("tabelas disponíveis: " + ", ".join(PackedStringArray(DbSchema.TABELAS.keys())))
	_escreve("exemplo: SELECT Cliente.Nome FROM Cliente JOIN Pedido ON Pedido.Cliente_idCliente = Cliente.idCliente WHERE Pedido.ValorTotalPedido > 100")
	_escreve("")


func _on_consulta_enviada(texto: String) -> void:
	_entrada.text = ""
	_entrada.grab_focus()
	_executa(_normaliza(texto))


func _executa(sql: String) -> void:
	if sql.is_empty():
		return

	if _historico.is_empty() or _historico.back() != sql:
		_historico.append(sql)
	_indice_historico = _historico.size()

	_escreve("[color=%s]%s[/color]%s" % [_cor(VERDE), PROMPT, _escapa(sql)])
	var r := SqlValidator.validate(sql)
	if r.ok:
		_escreve("[color=%s][OK][/color] sintaxe válida" % _cor(VERDE))
		_escreve("[color=%s]     tabelas:   %s[/color]" % [_cor(VERDE_ESCURO), ", ".join(PackedStringArray(r.tabelas))])
		_escreve("[color=%s]     atributos: %s[/color]" % [_cor(VERDE_ESCURO), ", ".join(PackedStringArray(r.atributos))])
	else:
		_escreve("[color=%s][ERRO] %s[/color]" % [_cor(VERMELHO), _escapa(r.erro)])
		_mostra_trecho_com_erro(sql, r.pos)
	_escreve("")


## Mostra um trecho da consulta com uma seta apontando o caractere do erro.
func _mostra_trecho_com_erro(sql: String, pos: int) -> void:
	var inicio := maxi(0, pos - 40)
	var prefixo := "..." if inicio > 0 else ""
	var trecho := sql.substr(inicio, 80)
	var recuo := "".lpad(PROMPT.length() + prefixo.length() + (pos - inicio), " ")
	_escreve("%s%s%s" % ["".lpad(PROMPT.length(), " "), prefixo, _escapa(trecho)])
	_escreve("[color=%s]%s^[/color]" % [_cor(VERMELHO), recuo])


func _historico_anterior() -> void:
	if _historico.is_empty():
		return
	_indice_historico = maxi(0, _indice_historico - 1)
	_mostra_historico()


func _historico_proximo() -> void:
	if _indice_historico >= _historico.size():
		return
	_indice_historico += 1
	_mostra_historico()


## Coloca no campo o comando do histórico (ou campo vazio, ao sair do histórico).
func _mostra_historico() -> void:
	var texto := ""
	if _indice_historico < _historico.size():
		texto = _historico[_indice_historico]
	_entrada.text = texto
	var ultima_linha: int = _entrada.get_line_count() - 1
	_entrada.set_caret_line(ultima_linha)
	_entrada.set_caret_column(_entrada.get_line(ultima_linha).length())


## Quebras de linha e tabs viram espaço (mesmo comprimento), então a posição do erro continua válida.
func _normaliza(texto: String) -> String:
	return texto.replace("\r", "").replace("\n", " ").replace("\t", " ").strip_edges()


func _escreve(bbcode: String) -> void:
	_saida.append_text(bbcode + "\n")


func _cor(cor: Color) -> String:
	return "#" + cor.to_html(false)


## Impede que o texto digitado seja interpretado como BBCode.
func _escapa(texto: String) -> String:
	return texto.replace("[", "[lb]")
