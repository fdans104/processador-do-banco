extends Control
## HU3 – Desenho do grafo de operadores na interface.
##
## Raiz (última projeção) no topo, tabelas (folhas) embaixo. As setas vão do
## nó que produz o resultado intermediário para o nó que o consome. O número
## #n de cada nó é a sua ordem de execução. Passar o mouse mostra o detalhe.
## O zoom se ajusta para caber na área; botões +/− ou Ctrl+roda mudam o zoom.
## Também desenha o grafo otimizado da HU4 (mesmo formato de grafo).

signal no_destacado(texto: String)
signal escala_mudou(escala: float)
signal no_clicado(id: int)

const Grafo := preload("res://hu3_grafo_operadores/grafo_operadores.gd")
const AlgebraRenderer := preload("res://hu2_algebra_relacional/algebra_renderer.gd")

const LARGURA_NO := 250.0
const ALTURA_NO := 46.0
const ESPACO_X := 40.0
const ESPACO_Y := 34.0
const MARGEM := 16.0
const TAMANHO_FONTE := 14
const ESCALA_MIN_AJUSTE := 0.6   # o ajuste automático não reduz além disso (texto legível)
const ESCALA_MIN := 0.3
const ESCALA_MAX := 2.0
const COR_FUNDO_NO := Color(0.06, 0.1, 0.15)
const COR_ARESTA := Color(0.5, 0.62, 0.72)
const COR_APLICADO := Color(1.0, 0.8, 0.35)
const COR_FUNDO_APLICADO := Color(0.2, 0.16, 0.05)
const TEXTO_AJUDA := "clique em um nó para ver detalhes"

@export var fonte: Font

var _grafo: Dictionary = {}
var _posicoes: Dictionary = {}   # id -> canto superior esquerdo do nó (sem escala)
var _tamanho_base := Vector2.ZERO
var _escala := 1.0
var _zoom_manual := false
var _piso_ajuste := ESCALA_MIN_AJUSTE
var _destacado := -1
var _selecionado := -1
var _ops_aplicadas: Array = []   # operadores realçados (os que a heurística da etapa mudou)


func _ready() -> void:
	# PASS: a roda do mouse (sem Ctrl) continua rolando o ScrollContainer pai
	mouse_filter = Control.MOUSE_FILTER_PASS
	get_parent().resized.connect(_ajusta_escala)
	resized.connect(queue_redraw)


## `realcar`: operadores a destacar em âmbar (usado no passo 5, etapa por etapa).
func mostrar(grafo: Dictionary, realcar: Array = []) -> void:
	_grafo = grafo
	_ops_aplicadas = realcar
	_posicoes.clear()
	_destacado = -1
	_selecionado = -1
	_zoom_manual = false
	_piso_ajuste = ESCALA_MIN_AJUSTE
	if grafo.is_empty():
		_tamanho_base = Vector2.ZERO
	else:
		_calcula_layout()
		no_destacado.emit(TEXTO_AJUDA)
	_ajusta_escala()
	# Depois que o ScrollContainer recalcular o tamanho, rola até a raiz
	_rola_ate_raiz.call_deferred()


## Abre o grafo mostrando a raiz (topo), centralizada na horizontal.
func _rola_ate_raiz() -> void:
	var rolagem := get_parent() as ScrollContainer
	if rolagem == null or _grafo.is_empty() or not _posicoes.has(_grafo.raiz):
		return
	var centro_raiz: float = _deslocamento().x + (_posicoes[_grafo.raiz].x + LARGURA_NO / 2) * _escala
	rolagem.scroll_vertical = 0
	rolagem.scroll_horizontal = maxi(0, roundi(centro_raiz - rolagem.size.x / 2))


## Layout de árvore "arrumada": cada subárvore é encaixada à direita da
## anterior o mais perto possível sem sobrepor nenhum nível, e o pai fica
## centralizado sobre os filhos. Setas não se cruzam e a árvore fica compacta.
## Unidade de x = uma vaga de nó (LARGURA_NO + ESPACO_X).
func _calcula_layout() -> void:
	var arranjo := _arranja(_grafo.raiz)
	var min_x: float = arranjo.esq.min()
	var max_x: float = arranjo.dir.max()
	for id in arranjo.pos:
		var no := Grafo.obter_no(_grafo, id)
		_posicoes[id] = Vector2(
			MARGEM + (arranjo.pos[id] - min_x) * (LARGURA_NO + ESPACO_X),
			MARGEM + no.profundidade * (ALTURA_NO + ESPACO_Y))
	_tamanho_base = Vector2(
		(max_x - min_x + 1) * (LARGURA_NO + ESPACO_X) - ESPACO_X + 2 * MARGEM,
		arranjo.esq.size() * (ALTURA_NO + ESPACO_Y) - ESPACO_Y + 2 * MARGEM)


## Devolve {"pos": {id: x relativo à raiz da subárvore},
##          "esq"/"dir": menor/maior x em cada nível abaixo (contornos)}.
func _arranja(id: int) -> Dictionary:
	var no := Grafo.obter_no(_grafo, id)
	if no.filhos.is_empty():
		return {"pos": {id: 0.0}, "esq": [0.0], "dir": [0.0]}
	var subarvores: Array = []
	for filho in no.filhos:
		subarvores.append(_arranja(filho))
	# Encaixa cada filho à direita dos anteriores, nível a nível
	var deslocamentos: Array = [0.0]
	var esq: Array = subarvores[0].esq.duplicate()
	var dir: Array = subarvores[0].dir.duplicate()
	for k in range(1, subarvores.size()):
		var sub: Dictionary = subarvores[k]
		var deslocamento := -INF
		for nivel in mini(dir.size(), sub.esq.size()):
			deslocamento = maxf(deslocamento, dir[nivel] - sub.esq[nivel] + 1.0)
		deslocamentos.append(deslocamento)
		for nivel in sub.esq.size():
			if nivel < dir.size():
				esq[nivel] = minf(esq[nivel], sub.esq[nivel] + deslocamento)
				dir[nivel] = maxf(dir[nivel], sub.dir[nivel] + deslocamento)
			else:
				esq.append(sub.esq[nivel] + deslocamento)
				dir.append(sub.dir[nivel] + deslocamento)
	var centro: float = (deslocamentos[0] + deslocamentos[-1]) / 2.0
	var pos := {id: 0.0}
	for k in subarvores.size():
		for outro in subarvores[k].pos:
			pos[outro] = subarvores[k].pos[outro] + deslocamentos[k] - centro
	var esq_final: Array = [0.0]
	var dir_final: Array = [0.0]
	for nivel in esq.size():
		esq_final.append(esq[nivel] - centro)
		dir_final.append(dir[nivel] - centro)
	return {"pos": pos, "esq": esq_final, "dir": dir_final}


func limpar_selecao() -> void:
	_selecionado = -1
	queue_redraw()


## Botões + e − (e Ctrl+roda): muda o zoom em torno do valor atual.
func zoom(fator: float) -> void:
	if _grafo.is_empty():
		return
	_escala = clampf(_escala * fator, ESCALA_MIN, ESCALA_MAX)
	_zoom_manual = true
	_ajusta_escala()


## Botão AJUSTAR: mostra o grafo inteiro na área, mesmo que fique pequeno.
func ajustar() -> void:
	_zoom_manual = false
	_piso_ajuste = ESCALA_MIN
	_ajusta_escala()


func _ajusta_escala() -> void:
	var area: Vector2 = get_parent().size
	if not _zoom_manual and _tamanho_base != Vector2.ZERO and area.x > 0 and area.y > 0:
		var cabe := minf(area.x / _tamanho_base.x, area.y / _tamanho_base.y)
		_escala = clampf(cabe, _piso_ajuste, 1.0)
	custom_minimum_size = _tamanho_base * _escala
	escala_mudou.emit(_escala)
	queue_redraw()


## Centraliza horizontalmente quando o grafo é mais estreito que a área.
func _deslocamento() -> Vector2:
	return Vector2(maxf(0.0, (size.x - _tamanho_base.x * _escala) / 2.0), 0.0)


func _draw() -> void:
	if _grafo.is_empty() or fonte == null:
		return
	draw_set_transform(_deslocamento(), 0.0, Vector2(_escala, _escala))
	for aresta in _grafo.arestas:
		var origem: Vector2 = _posicoes[aresta.de] + Vector2(LARGURA_NO / 2, 0)
		var destino: Vector2 = _posicoes[aresta.para] + Vector2(LARGURA_NO / 2, ALTURA_NO)
		_desenha_seta(origem, destino)
	for no in _grafo.nos:
		_desenha_no(no)


func _desenha_seta(origem: Vector2, destino: Vector2) -> void:
	draw_line(origem, destino, COR_ARESTA, 2.0, true)
	var direcao := (destino - origem).normalized()
	var lado := Vector2(-direcao.y, direcao.x)
	var base := destino - direcao * 11.0
	draw_colored_polygon(PackedVector2Array([destino, base + lado * 5.5, base - lado * 5.5]), COR_ARESTA)


func _desenha_no(no: Dictionary) -> void:
	var pos: Vector2 = _posicoes[no.id]
	var caixa := Rect2(pos, Vector2(LARGURA_NO, ALTURA_NO))
	var cor := _cor_do_operador(no.op)
	var aplicado: bool = _ops_aplicadas.has(no.op) and no.id != _grafo.raiz
	draw_rect(caixa, COR_FUNDO_APLICADO if aplicado else COR_FUNDO_NO)
	if aplicado:
		draw_rect(caixa.grow(4.0), COR_APLICADO, false, 2.5)
		draw_string(fonte, pos + Vector2(LARGURA_NO - 74, -6), "◆ aplicado", HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_FONTE - 2, COR_APLICADO)
	if no.id == _selecionado:
		draw_rect(caixa.grow(5.0), cor, false, 2.0)
	draw_rect(caixa, cor, false, 3.0 if no.id == _destacado or no.id == _selecionado else 1.5)
	var titulo := "#%d  %s %s" % [no.id, no.simbolo, no.nome] if no.simbolo != "" else "#%d  %s" % [no.id, no.nome]
	draw_string(fonte, pos + Vector2(10, 18), titulo, HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_FONTE, cor)
	var cor_detalhe := AlgebraRenderer.COR_TABELA if no.op == "tabela" else AlgebraRenderer.COR_ATRIBUTO
	draw_string(fonte, pos + Vector2(10, 37), _corta(no.detalhe, _caracteres_que_cabem()), HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_FONTE - 1, cor_detalhe)


func _cor_do_operador(op: String) -> Color:
	match op:
		"project":
			return AlgebraRenderer.COR_PI
		"select":
			return AlgebraRenderer.COR_SIGMA
		"join":
			return AlgebraRenderer.COR_JOIN
		"produto":
			return Color(1.0, 0.4, 0.4)
	return AlgebraRenderer.COR_TABELA


func _caracteres_que_cabem() -> int:
	var largura_letra := fonte.get_string_size("M", HORIZONTAL_ALIGNMENT_LEFT, -1, TAMANHO_FONTE - 1).x
	return int((LARGURA_NO - 20) / maxf(largura_letra, 1.0))


func _corta(texto: String, limite: int) -> String:
	if texto.length() <= limite:
		return texto
	return texto.substr(0, limite - 1) + "…"


func _gui_input(evento: InputEvent) -> void:
	if _grafo.is_empty():
		return
	if evento is InputEventMouseButton and evento.pressed and evento.ctrl_pressed:
		if evento.button_index == MOUSE_BUTTON_WHEEL_UP or evento.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom(1.1 if evento.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.1)
			accept_event()
	elif evento is InputEventMouseButton and evento.pressed and evento.button_index == MOUSE_BUTTON_LEFT:
		var clicado := _no_em((evento.position - _deslocamento()) / _escala)
		if clicado != -1:
			_selecionado = clicado
			queue_redraw()
			no_clicado.emit(clicado)
			accept_event()
	elif evento is InputEventMouseMotion:
		var id := _no_em((evento.position - _deslocamento()) / _escala)
		mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if id != -1 else Control.CURSOR_ARROW
		if id != _destacado:
			_destacado = id
			queue_redraw()
			no_destacado.emit(TEXTO_AJUDA if id == -1 else _descricao(id))


func _no_em(ponto: Vector2) -> int:
	for id in _posicoes:
		if Rect2(_posicoes[id], Vector2(LARGURA_NO, ALTURA_NO)).has_point(ponto):
			return id
	return -1


## Texto completo do nó e de onde vêm / para onde vão os resultados.
func _descricao(id: int) -> String:
	var no := Grafo.obter_no(_grafo, id)
	var partes: Array = ["#%d %s: %s" % [id, no.nome, no.detalhe]]
	if not no.filhos.is_empty():
		var entradas: Array = []
		for filho in no.filhos:
			entradas.append("#%d" % filho)
		partes.append("recebe de " + ", ".join(entradas))
	var destino := Grafo.consumidor(_grafo, id)
	partes.append("envia para #%d" % destino if destino != -1 else "raiz: resultado final")
	return "  ·  ".join(partes)
