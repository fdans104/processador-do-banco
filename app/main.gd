extends Control
## Casca da aplicação: liga a interface (scenes/main.tscn) às histórias de usuário.
##   HU1 – entrada, validação e tela BANCO (F11) ... hu1_entrada_validacao/
##   HU2 – álgebra relacional (forma canônica) ..... hu2_algebra_relacional/
##   HU3 – grafo de operadores ..................... hu3_grafo_operadores/
##   HU4 – otimização heurística e custo ........... hu4_otimizacao/
##   HU5 – plano de execução ....................... hu5_plano_execucao/
## Aqui só há orquestração: a lógica de cada HU fica na sua pasta.
##
## A consulta percorre passos, avançados pela seta PRÓXIMO (ou ENTER com o campo vazio):
##   1 · VALIDAR → 2 · CANÔNICA → 3 · GRAFO → 4 · OTIMIZAR → 5 · PLANO
## Nos passos com grafo, clicar em um nó abre a ficha teórica (app/ficha_no.gd).

const SqlValidator := preload("res://hu1_entrada_validacao/sql_validator.gd")
const DbSchema := preload("res://hu1_entrada_validacao/db_schema.gd")
const AlgebraConverter := preload("res://hu2_algebra_relacional/algebra_converter.gd")
const AlgebraRenderer := preload("res://hu2_algebra_relacional/algebra_renderer.gd")
const Grafo := preload("res://hu3_grafo_operadores/grafo_operadores.gd")
const Otimizador := preload("res://hu4_otimizacao/otimizador.gd")
const Estimativa := preload("res://hu4_otimizacao/estimativa.gd")
const Plano := preload("res://hu5_plano_execucao/plano.gd")
const FichaNo := preload("res://app/ficha_no.gd")

const VERDE := Color(0.2, 1.0, 0.4)
const VERDE_ESCURO := Color(0.1, 0.55, 0.25)
const VERMELHO := Color(1.0, 0.35, 0.35)
const AMBAR := Color(1.0, 0.8, 0.35)
const CIANO := Color(0.35, 0.85, 1.0)
const APAGADO := Color(0.42, 0.5, 0.58)
const PROMPT := "sql@banco:~$ "
const NOMES_PASSOS := ["1 · VALIDAR", "2 · CANÔNICA", "3 · GRAFO", "4 · OTIMIZAR", "5 · PASSO A PASSO"]
const DESCRICOES_PASSOS := [
	"validar a consulta",
	"montar a forma canônica",
	"montar o grafo de operadores",
	"otimizar com as heurísticas",
	"ver cada heurística sendo aplicada e o plano de execução",
]
const ULTIMO_PASSO := 5

@onready var _saida: RichTextLabel = $Margem/Coluna/Saida
@onready var _entrada = $Margem/Coluna/Linha/Entrada
@onready var _botao_consultas: Button = $Margem/Coluna/Barra/BotaoConsultas
@onready var _botao_banco: Button = $Margem/Coluna/Barra/BotaoBanco
@onready var _rotulos_passos: Array = [
	$Margem/Coluna/PainelEtapas/Etapas/BarraPassos/Passo1,
	$Margem/Coluna/PainelEtapas/Etapas/BarraPassos/Passo2,
	$Margem/Coluna/PainelEtapas/Etapas/BarraPassos/Passo3,
	$Margem/Coluna/PainelEtapas/Etapas/BarraPassos/Passo4,
	$Margem/Coluna/PainelEtapas/Etapas/BarraPassos/Passo5,
]
@onready var _setas: Array = [
	$Margem/Coluna/PainelEtapas/Etapas/BarraPassos/Seta1,
	$Margem/Coluna/PainelEtapas/Etapas/BarraPassos/Seta2,
	$Margem/Coluna/PainelEtapas/Etapas/BarraPassos/Seta3,
	$Margem/Coluna/PainelEtapas/Etapas/BarraPassos/Seta4,
]
@onready var _botao_voltar: Button = $Margem/Coluna/PainelEtapas/Etapas/BarraPassos/BotaoVoltar
@onready var _botao_proximo: Button = $Margem/Coluna/PainelEtapas/Etapas/BarraPassos/BotaoProximo
@onready var _texto_etapa: RichTextLabel = $Margem/Coluna/PainelEtapas/Etapas/TextoEtapa
@onready var _area_grafo: VBoxContainer = $Margem/Coluna/PainelEtapas/Etapas/AreaGrafo
@onready var _legenda: RichTextLabel = $Margem/Coluna/PainelEtapas/Etapas/AreaGrafo/Legenda
@onready var _grafo_view = $Margem/Coluna/PainelEtapas/Etapas/AreaGrafo/Corpo/Rolagem/Grafo
@onready var _lateral: RichTextLabel = $Margem/Coluna/PainelEtapas/Etapas/AreaGrafo/Corpo/Lateral
@onready var _detalhe_grafo: Label = $Margem/Coluna/PainelEtapas/Etapas/AreaGrafo/BarraZoom/Detalhe
@onready var _rotulo_escala: Label = $Margem/Coluna/PainelEtapas/Etapas/AreaGrafo/BarraZoom/Escala
@onready var _painel: PanelContainer = $PainelConsultas
@onready var _lista: VBoxContainer = $PainelConsultas/Conteudo/Rolagem/Lista
@onready var _status: Label = $PainelConsultas/Conteudo/Status
@onready var _banco = $PainelBanco
@onready var _painel_no: PanelContainer = $PainelNo
@onready var _texto_no: RichTextLabel = $PainelNo/Conteudo/Texto
@onready var _barra_heuristicas: HBoxContainer = $Margem/Coluna/PainelEtapas/Etapas/AreaGrafo/BarraHeuristicas
@onready var _linha_do_tempo: RichTextLabel = $Margem/Coluna/PainelEtapas/Etapas/AreaGrafo/BarraHeuristicas/LinhaDoTempo
@onready var _botao_reproduzir: Button = $Margem/Coluna/PainelEtapas/Etapas/AreaGrafo/BarraHeuristicas/BotaoReproduzir
@onready var _botao_etapa_anterior: Button = $Margem/Coluna/PainelEtapas/Etapas/AreaGrafo/BarraHeuristicas/BotaoEtapaAnterior
@onready var _botao_etapa_proxima: Button = $Margem/Coluna/PainelEtapas/Etapas/AreaGrafo/BarraHeuristicas/BotaoEtapaProxima
@onready var _timer_etapas: Timer = $TimerEtapas

var _historico: Array = []
var _indice_historico := 0

# Estado da consulta atual nos passos
var _passo := 0                   # 0 = nenhuma consulta; 1..5 = passo exibido
var _resultado: Dictionary = {}   # HU1
var _algebra: Dictionary = {}     # HU2
var _grafo: Dictionary = {}       # HU3 (grafo canônico)
var _tuplas_canonico: Dictionary = {}
var _otimizacao: Dictionary = {}  # HU4
var _grafo_otimizado: Dictionary = {}
var _tuplas_otimizado: Dictionary = {}
var _plano: Array = []            # HU5
var _etapas: Array = []           # passo 5: canônica → H1 → H2 → H3 → H4 → plano
var _etapa := 0
# Grafo desenhado agora (a ficha do nó usa o mesmo)
var _chave_na_tela := ""
var _grafo_exibido: Dictionary = {}
var _tuplas_exibidas: Dictionary = {}


func _ready() -> void:
	_entrada.enviado.connect(_on_consulta_enviada)
	_entrada.historico_anterior.connect(_historico_anterior)
	_entrada.historico_proximo.connect(_historico_proximo)
	for item in _lista.get_children():
		var campo_sql: TextEdit = item.get_node("Sql")
		var rotulo: Label = item.get_node("Rotulo")
		item.get_node("Copiar").pressed.connect(_copia_consulta.bind(campo_sql, rotulo.text))
	$PainelConsultas/Conteudo/Fechar.pressed.connect(_fecha_painel)
	_botao_consultas.pressed.connect(_alterna_consultas)
	_botao_banco.pressed.connect(_alterna_banco)
	_botao_proximo.pressed.connect(_proximo_passo)
	_botao_voltar.pressed.connect(_passo_anterior)
	_grafo_view.no_destacado.connect(func(texto: String) -> void: _detalhe_grafo.text = texto)
	_grafo_view.no_clicado.connect(_abre_ficha)
	_grafo_view.escala_mudou.connect(func(escala: float) -> void: _rotulo_escala.text = "%d%%" % roundi(escala * 100))
	$Margem/Coluna/PainelEtapas/Etapas/AreaGrafo/BarraZoom/BotaoMais.pressed.connect(_grafo_view.zoom.bind(1.2))
	$Margem/Coluna/PainelEtapas/Etapas/AreaGrafo/BarraZoom/BotaoMenos.pressed.connect(_grafo_view.zoom.bind(1.0 / 1.2))
	$Margem/Coluna/PainelEtapas/Etapas/AreaGrafo/BarraZoom/BotaoAjustar.pressed.connect(_grafo_view.ajustar)
	$PainelNo/Conteudo/Cabecalho/BotaoFechar.pressed.connect(_fecha_ficha)
	_botao_etapa_anterior.pressed.connect(func() -> void: _pausa(); _vai_para_etapa(_etapa - 1))
	_botao_etapa_proxima.pressed.connect(func() -> void: _pausa(); _vai_para_etapa(_etapa + 1))
	_botao_reproduzir.pressed.connect(_alterna_reproducao)
	_timer_etapas.timeout.connect(_avanca_etapa_automatica)
	_banco.fechado.connect(_entrada.grab_focus)
	_imprimir_banner()
	_mostra_passo()
	_entrada.grab_focus()


## F12 = lista de consultas, F11 = banco de dados, ESC fecha a tela aberta.
func _input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	if evento.keycode == KEY_F12:
		_alterna_consultas()
		get_viewport().set_input_as_handled()
	elif evento.keycode == KEY_F11:
		_alterna_banco()
		get_viewport().set_input_as_handled()
	elif evento.keycode == KEY_ESCAPE and (_painel_no.visible or _painel.visible or _banco.visible):
		if _painel_no.visible:
			_fecha_ficha()
		elif _painel.visible:
			_fecha_painel()
		else:
			_banco.fechar()
		get_viewport().set_input_as_handled()


# ---------- passos: 1 validar → 2 canônica → 3 grafo → 4 otimizar → 5 plano ----------

## Passo 1: valida a consulta (HU1) e reinicia os passos.
func _executa(sql: String) -> void:
	if _historico.is_empty() or _historico.back() != sql:
		_historico.append(sql)
	_indice_historico = _historico.size()

	_fecha_ficha()
	_escreve("[color=%s]%s[/color]%s" % [_cor(VERDE), PROMPT, _escapa(sql)])
	_resultado = SqlValidator.validate(sql)
	_algebra = {}
	_grafo = {}
	_otimizacao = {}
	_grafo_otimizado = {}
	_plano = []
	_etapas = []
	_pausa()
	_chave_na_tela = ""
	_passo = 1
	if _resultado.ok:
		_escreve("[color=%s]  ✓ consulta válida[/color]" % _cor(VERDE))
	else:
		_escreve("[color=%s]  ✗ %s[/color]" % [_cor(VERMELHO), _escapa(_resultado.erro)])
		_mostra_trecho_com_erro(sql, _resultado.pos)
	_mostra_passo()


func _pode_avancar() -> bool:
	return _passo >= 1 and _passo < ULTIMO_PASSO and _resultado.get("ok", false)


func _proximo_passo() -> void:
	if not _pode_avancar():
		return
	_fecha_ficha()
	_passo += 1
	if _passo == 2 and _algebra.is_empty():
		_algebra = AlgebraConverter.converter(_resultado.ast)
		_escreve("[color=%s]  ✓ álgebra relacional[/color]" % _cor(VERDE))
	elif _passo == 3 and _grafo.is_empty():
		_grafo = Grafo.construir(_algebra)
		_tuplas_canonico = Estimativa.estimar(_grafo)
		_escreve("[color=%s]  ✓ grafo de operadores[/color]" % _cor(VERDE))
	elif _passo == 4 and _otimizacao.is_empty():
		_otimizacao = Otimizador.otimizar(_resultado.ast)
		_grafo_otimizado = Grafo.construir(_otimizacao.arvore)
		_tuplas_otimizado = Estimativa.estimar(_grafo_otimizado)
		_escreve("[color=%s]  ✓ grafo otimizado[/color]" % _cor(VERDE))
	elif _passo == 5:
		if _plano.is_empty():
			_plano = Plano.gerar(_grafo_otimizado, _tuplas_otimizado)
			_monta_etapas()
			_escreve("[color=%s]  ✓ plano de execução[/color]" % _cor(VERDE))
		# Recomeça a animação pela forma canônica
		_etapa = 0
		_chave_na_tela = ""
		_reproduz()
	_mostra_passo()


func _passo_anterior() -> void:
	if _passo > 1:
		_fecha_ficha()
		_pausa()
		_passo -= 1
		_mostra_passo()


# ---------- passo 5: heurísticas sendo aplicadas, uma etapa por vez ----------

## Etapas: forma canônica → H1 → H2 → H3 → H4 → plano de execução (HU5).
## Cada uma guarda seu grafo e suas estimativas, para mostrar o custo caindo.
func _monta_etapas() -> void:
	_etapas = [{
		"id": "C", "titulo": "FORMA CANÔNICA", "grafo": _grafo, "tuplas": _tuplas_canonico,
		"mudancas": ["sem heurísticas aplicadas"], "realcar": [],
	}]
	for etapa in _otimizacao.etapas:
		var grafo := Grafo.construir(etapa.arvore)
		_etapas.append({
			"id": etapa.id, "titulo": etapa.titulo, "grafo": grafo, "tuplas": Estimativa.estimar(grafo),
			"mudancas": etapa.mudancas, "realcar": etapa.destacar,
		})
	_etapas.append({
		"id": "P", "titulo": "PLANO DE EXECUÇÃO", "grafo": _grafo_otimizado, "tuplas": _tuplas_otimizado,
		"mudancas": [], "realcar": [],
	})


func _vai_para_etapa(indice: int) -> void:
	if _etapas.is_empty():
		return
	_fecha_ficha()
	_etapa = clampi(indice, 0, _etapas.size() - 1)
	_mostra_passo()


func _reproduz() -> void:
	_timer_etapas.start()
	_botao_reproduzir.text = "❚❚ PAUSAR"


func _pausa() -> void:
	if _timer_etapas != null:
		_timer_etapas.stop()
	if _botao_reproduzir != null:
		_botao_reproduzir.text = "▶ REPRODUZIR"


func _alterna_reproducao() -> void:
	if not _timer_etapas.is_stopped():
		_pausa()
		return
	if _etapa >= _etapas.size() - 1:
		_vai_para_etapa(0)
	_reproduz()


func _avanca_etapa_automatica() -> void:
	if _passo != 5 or _etapa >= _etapas.size() - 1:
		_pausa()
		return
	_vai_para_etapa(_etapa + 1)
	if _etapa >= _etapas.size() - 1:
		_pausa()


## Atualiza a barra de passos (seta acesa = próximo passo) e o conteúdo exibido.
func _mostra_passo() -> void:
	for i in ULTIMO_PASSO:
		var numero := i + 1
		var rotulo: Label = _rotulos_passos[i]
		if numero < _passo:
			rotulo.text = "✓ " + NOMES_PASSOS[i]
			rotulo.add_theme_color_override("font_color", VERDE)
		elif numero == _passo:
			rotulo.text = "[ " + NOMES_PASSOS[i] + " ]"
			rotulo.add_theme_color_override("font_color", CIANO if _resultado.get("ok", false) else VERMELHO)
		else:
			rotulo.text = NOMES_PASSOS[i]
			rotulo.add_theme_color_override("font_color", APAGADO)
	for i in ULTIMO_PASSO - 1:
		var proxima := _pode_avancar() and i + 1 == _passo
		_setas[i].add_theme_color_override("font_color", AMBAR if proxima else APAGADO)
	_botao_proximo.disabled = not _pode_avancar()
	_botao_proximo.tooltip_text = "próximo: %s" % DESCRICOES_PASSOS[_passo] if _pode_avancar() else ""
	_botao_voltar.disabled = _passo <= 1

	# Passos 3, 4 e 5 mostram o grafo; 4 e 5 com painel lateral
	var com_grafo := _passo >= 3
	$Margem/Coluna/PainelEtapas.size_flags_stretch_ratio = 5.0 if com_grafo else 2.0
	_area_grafo.visible = com_grafo
	_texto_etapa.visible = not com_grafo
	_lateral.visible = _passo >= 4
	_barra_heuristicas.visible = _passo == 5
	if com_grafo:
		match _passo:
			3:
				_exibe_grafo("canonico", _grafo, _tuplas_canonico)
			4:
				_exibe_grafo("otimizado", _grafo_otimizado, _tuplas_otimizado)
			5:
				var etapa: Dictionary = _etapas[_etapa]
				_exibe_grafo("etapa%d" % _etapa, etapa.grafo, etapa.tuplas, etapa.realcar)
				_atualiza_barra_heuristicas()
		_legenda.clear()
		_legenda.append_text(_texto_legenda())
	if _passo >= 4:
		_lateral.clear()
		_lateral.append_text(_texto_passo4() if _passo == 4 else _texto_etapa_heuristica())
		_lateral.scroll_to_line(0)

	_texto_etapa.clear()
	match _passo:
		0:
			_texto_etapa.append_text(_texto_inicial())
		1:
			_texto_etapa.append_text(_texto_passo1())
		2:
			_texto_etapa.append_text(_texto_passo2())


# ---------- conteúdo teórico de cada passo ----------

func _titulo(texto: String) -> String:
	return "[color=%s]%s[/color]" % [_cor(CIANO), texto]


func _texto_inicial() -> String:
	return "[color=%s]Digite uma consulta SQL e pressione ENTER.[/color]" % _cor(APAGADO)


func _texto_passo1() -> String:
	var titulo := _titulo("PASSO 1 · VALIDAÇÃO") + "\n\n"
	if not _resultado.ok:
		return titulo + "[color=%s]✗ %s[/color]" % [_cor(VERMELHO), _escapa(_resultado.erro)]
	return titulo + "[color=%s]✓ consulta válida[/color]\ntabelas:    %s\natributos:  %s" % [
		_cor(VERDE),
		", ".join(PackedStringArray(_resultado.tabelas)),
		", ".join(PackedStringArray(_resultado.atributos)),
	]


func _texto_passo2() -> String:
	return _titulo("PASSO 2 · ÁLGEBRA RELACIONAL") + "\n\n" + AlgebraRenderer.bbcode(_algebra)


func _texto_legenda() -> String:
	var titulo := ""
	match _passo:
		3:
			titulo = _titulo("PASSO 3 · GRAFO DE OPERADORES")
		4:
			titulo = "%s   [color=%s]custo %s → %s (%s) · volume %s → %s[/color]" % [
				_titulo("PASSO 4 · GRAFO OTIMIZADO"), _cor(AMBAR),
				Estimativa.formata(_custo_canonico()), Estimativa.formata(_custo_otimizado()), _reducao(),
				Estimativa.formata(Estimativa.volume(_grafo, _tuplas_canonico)), Estimativa.formata(Estimativa.volume(_grafo_otimizado, _tuplas_otimizado))]
		5:
			titulo = _titulo("PASSO 5 · %s" % _etapas[_etapa].titulo)
	var legenda := "[color=#%s]π projeção[/color]  [color=#%s]σ seleção[/color]  [color=#%s]⋈ junção[/color]  [color=#%s]▭ tabela[/color]  [color=%s]#n ordem[/color]" % [
		AlgebraRenderer.COR_PI.to_html(false), AlgebraRenderer.COR_SIGMA.to_html(false),
		AlgebraRenderer.COR_JOIN.to_html(false), AlgebraRenderer.COR_TABELA.to_html(false), _cor(APAGADO)]
	return titulo + "    " + legenda


func _texto_passo4() -> String:
	var linhas: Array = [_titulo("HEURÍSTICAS APLICADAS"), ""]
	for heuristica in _otimizacao.heuristicas:
		linhas.append("[color=%s]•[/color] %s" % [_cor(AMBAR), _escapa(heuristica)])
	return "\n".join(linhas)


## Painel lateral do passo 5: o que a etapa mudou, ou o plano na última etapa.
func _texto_etapa_heuristica() -> String:
	var etapa: Dictionary = _etapas[_etapa]
	if etapa.id == "P":
		return _texto_plano()
	var linhas: Array = [_titulo(etapa.titulo), ""]
	# custo = tuplas processadas; volume = tuplas × atributos que chegam às junções
	var custo := Estimativa.custo(etapa.grafo, etapa.tuplas)
	var volume := Estimativa.volume(etapa.grafo, etapa.tuplas)
	if _etapa == 0:
		linhas.append("custo:  %s" % Estimativa.formata(custo))
		linhas.append("volume: %s" % Estimativa.formata(volume))
	else:
		var anterior: Dictionary = _etapas[_etapa - 1]
		var custo_anterior := Estimativa.custo(anterior.grafo, anterior.tuplas)
		var volume_anterior := Estimativa.volume(anterior.grafo, anterior.tuplas)
		linhas.append("custo:  %s → %s %s" % [Estimativa.formata(custo_anterior), Estimativa.formata(custo), _variacao(custo_anterior, custo)])
		linhas.append("volume: %s → %s %s" % [Estimativa.formata(volume_anterior), Estimativa.formata(volume), _variacao(volume_anterior, volume)])
	linhas.append("[color=%s]custo = tuplas processadas · volume = tuplas × atributos nas junções[/color]" % _cor(APAGADO))
	linhas.append("")
	for mudanca in etapa.mudancas:
		linhas.append("[color=%s]•[/color] %s" % [_cor(AMBAR), _escapa(mudanca)])
	return "\n".join(linhas)


func _variacao(antes: float, depois: float) -> String:
	if antes <= 0.0 or is_equal_approx(antes, depois):
		return "[color=%s](igual)[/color]" % _cor(APAGADO)
	var percentual := (depois / antes - 1.0) * 100.0
	if percentual < 0.0:
		return "[color=%s](−%.1f%%)[/color]" % [_cor(VERDE), -percentual]
	return "[color=%s](+%.1f%%)[/color]" % [_cor(VERMELHO), percentual]


## Linha do tempo: ✓ etapas já vistas, [atual], demais apagadas.
func _atualiza_barra_heuristicas() -> void:
	var partes: Array = []
	for i in _etapas.size():
		var nome: String = _etapas[i].id if _etapas[i].id != "C" else "canônica"
		if _etapas[i].id == "P":
			nome = "plano"
		if i < _etapa:
			partes.append("[color=%s]✓ %s[/color]" % [_cor(VERDE), nome])
		elif i == _etapa:
			partes.append("[color=%s][lb] %s ][/color]" % [_cor(AMBAR), nome])
		else:
			partes.append(nome)
	_linha_do_tempo.clear()
	_linha_do_tempo.append_text(" → ".join(partes))
	_botao_etapa_anterior.disabled = _etapa <= 0
	_botao_etapa_proxima.disabled = _etapa >= _etapas.size() - 1


func _exibe_grafo(chave: String, grafo: Dictionary, tuplas: Dictionary, realcar: Array = []) -> void:
	if _chave_na_tela == chave:
		return
	_grafo_view.mostrar(grafo, realcar)
	# No passo a passo o grafo inteiro fica visível, para acompanhar cada mudança
	if _passo == 5:
		_grafo_view.ajustar()
	_chave_na_tela = chave
	_grafo_exibido = grafo
	_tuplas_exibidas = tuplas


func _texto_plano() -> String:
	var linhas: Array = [_titulo("PLANO DE EXECUÇÃO"), ""]
	for passo in _plano:
		var cor: Color = AlgebraRenderer.COR_TABELA if passo.op == "tabela" else AMBAR
		linhas.append("[color=%s]%2d.[/color] [color=%s]%s ←[/color] %s" % [_cor(CIANO), passo.ordem, _cor(cor), passo.resultado, _escapa(passo.expressao)])
	return "\n".join(linhas)


func _custo_canonico() -> float:
	return Estimativa.custo(_grafo, _tuplas_canonico) if not _grafo.is_empty() else 0.0


func _custo_otimizado() -> float:
	return Estimativa.custo(_grafo_otimizado, _tuplas_otimizado) if not _grafo_otimizado.is_empty() else 0.0


func _reducao() -> String:
	var antes := _custo_canonico()
	if antes <= 0.0:
		return "—"
	var variacao := (_custo_otimizado() / antes - 1.0) * 100.0
	if variacao > 0.0:
		return "+%.1f%%: as heurísticas não garantem o ótimo nesta estimativa" % variacao
	return "−%.1f%%" % -variacao


# ---------- ficha teórica do nó ----------

func _abre_ficha(id: int) -> void:
	_pausa()
	_texto_no.clear()
	_texto_no.append_text(FichaNo.bbcode(_grafo_exibido, id, _tuplas_exibidas, _resultado.atributos))
	_texto_no.scroll_to_line(0)
	_painel_no.visible = true


func _fecha_ficha() -> void:
	if _painel_no.visible:
		_painel_no.visible = false
		_grafo_view.limpar_selecao()


# ---------- painéis F12 / F11 ----------

func _alterna_consultas() -> void:
	if _painel.visible:
		_fecha_painel()
	else:
		_banco.visible = false
		_abre_painel()


func _alterna_banco() -> void:
	if _banco.visible:
		_banco.fechar()
	else:
		_fecha_painel()
		_banco.abrir()


func _abre_painel() -> void:
	_status.text = " "
	_painel.visible = true
	_lista.get_child(0).get_node("Copiar").grab_focus()


func _fecha_painel() -> void:
	_painel.visible = false
	_entrada.grab_focus()


## Copia a consulta para a área de transferência (só copiar: não executa).
func _copia_consulta(campo_sql: TextEdit, rotulo: String) -> void:
	DisplayServer.clipboard_set(campo_sql.text)
	_status.text = "copiado: " + rotulo


# ---------- terminal ----------

func _imprimir_banner() -> void:
	_escreve("[color=%s]PROCESSADOR DE CONSULTAS[/color]" % _cor(VERDE))
	_escreve("")


## ENTER com consulta = passo 1; ENTER com o campo vazio = próximo passo
## (no passo 5, próxima etapa das heurísticas).
func _on_consulta_enviada(texto: String) -> void:
	_entrada.text = ""
	_entrada.grab_focus()
	var sql := _normaliza(texto)
	if not sql.is_empty():
		_executa(sql)
	elif _passo == 5:
		_pausa()
		_vai_para_etapa(_etapa + 1)
	else:
		_proximo_passo()


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
