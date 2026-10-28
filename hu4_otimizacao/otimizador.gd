extends RefCounted
## HU4 – Otimização heurística da consulta.
##
## Entrada: AST da HU1. Saída:
##   {"arvore": árvore final no formato da HU2 (pode conter {"op": "produto"} = ×, se inevitável),
##    "heuristicas": [String, ...]   (resumo do que foi aplicado),
##    "ordem": [tabela, ...]         (ordem final das junções),
##    "estimativas": {tabela: tuplas após a seleção},
##    "etapas": [ETAPA, ...]}        (a árvore depois de cada heurística, para o passo 5)
##   ETAPA = {"id": "H1".."H4", "titulo", "regra" (equivalência usada),
##            "mudancas": [String, ...], "arvore", "destacar": [op, ...]}
##
## As heurísticas são aplicadas em sequência, cada uma sobre o resultado da anterior:
##   H1 · seleções primeiro: cada condição do WHERE/ON que usa uma só tabela
##        vira σ logo acima dessa tabela (reduz tuplas antes das junções).
##   H2 · projeções na sequência: acima de cada σ, um π mantém só os atributos
##        que ainda serão usados (lista do SELECT + condições de junção).
##   H3 · mais restritivas primeiro: as tabelas são reordenadas da menor para a
##        maior estimativa de tuplas (isso sozinho pode criar produto cartesiano).
##   H4 · evitar produto cartesiano: a ordem é refeita de modo que cada tabela
##        entre ligada por condição às já unidas, ainda preferindo a mais restritiva;
##        o × só fica se nenhuma condição ligar a tabela.
##
## As estimativas vêm do modelo de custo em estimativa.gd.

const DbSchema := preload("res://hu1_entrada_validacao/db_schema.gd")
const AlgebraRenderer := preload("res://hu2_algebra_relacional/algebra_renderer.gd")
const Estimativa := preload("res://hu4_otimizacao/estimativa.gd")


static func otimizar(ast: Dictionary) -> Dictionary:
	var c := _classificar(ast)
	var tabelas: Array = c.tabelas
	var etapas: Array = []

	# H1 · seleções primeiro (junções ainda na ordem do FROM/JOIN)
	var h1 := _folhas(c, false)
	var mudancas_h1: Array = []
	for tabela in tabelas:
		if c.selecoes.has(tabela):
			mudancas_h1.append("σ{%s} → %s  (≈%s → ≈%s tuplas)" % [
				AlgebraRenderer.texto_condicao(_e(c.selecoes[tabela])), tabela,
				Estimativa.formata(Estimativa.cardinalidade(tabela)), Estimativa.formata(c.estimativas[tabela])])
	if mudancas_h1.is_empty():
		mudancas_h1.append("nenhuma seleção para descer")
	etapas.append({
		"id": "H1", "titulo": "H1 · SELEÇÕES PRIMEIRO",
		"regra": "σ_c(R ⋈ S) ≡ σ_c(R) ⋈ S, se c só usa atributos de R  ·  cascata: σ_c1∧c2(R) ≡ σ_c1(σ_c2(R))",
		"mudancas": mudancas_h1,
		"arvore": _finaliza(_monta(tabelas, h1.folhas, c.juncoes).arvore, c),
		"destacar": ["select"],
	})

	# H2 · projeções na sequência
	var h2 := _folhas(c, true)
	etapas.append({
		"id": "H2", "titulo": "H2 · PROJEÇÕES NA SEQUÊNCIA",
		"regra": "π_L(R ⋈_c S) ≡ π_L(π_A(R) ⋈_c π_B(S)), com A e B contendo os atributos de L e de c",
		"mudancas": h2.mudancas,
		"arvore": _finaliza(_monta(tabelas, h2.folhas, c.juncoes).arvore, c),
		"destacar": ["project"],
	})

	# H3 · mais restritivas primeiro: só a estimativa decide a ordem
	var ordem_h3 := _ordem_por_estimativa(tabelas, c.estimativas)
	var montagem_h3 := _monta(ordem_h3, h2.folhas, c.juncoes)
	var mudancas_h3: Array = ["ordem: " + _descreve_ordem(ordem_h3, c.estimativas)]
	if tabelas.size() == 1:
		mudancas_h3 = ["uma tabela: nada a ordenar"]
	elif montagem_h3.produtos.is_empty():
		mudancas_h3.append("sem produto cartesiano")
	else:
		for tabela in montagem_h3.produtos:
			mudancas_h3.append("⚠ produto cartesiano com %s" % tabela)
	etapas.append({
		"id": "H3", "titulo": "H3 · MAIS RESTRITIVAS PRIMEIRO",
		"regra": "comutativa R ⋈ S ≡ S ⋈ R  ·  associativa (R ⋈ S) ⋈ T ≡ R ⋈ (S ⋈ T): as junções podem ser reordenadas",
		"mudancas": mudancas_h3,
		"arvore": _finaliza(montagem_h3.arvore, c),
		"destacar": ["join", "produto"],
	})

	# H4 · evitar produto cartesiano: só entra tabela ligada às já unidas
	var ordem_h4 := _ordem_conectada(tabelas, c.estimativas, c.juncoes)
	var montagem_h4 := _monta(ordem_h4, h2.folhas, c.juncoes)
	var arvore_final := _finaliza(montagem_h4.arvore, c)
	var mudancas_h4: Array = []
	if tabelas.size() == 1:
		mudancas_h4.append("uma tabela: nada a ordenar")
	else:
		mudancas_h4.append("ordem: " + _descreve_ordem(ordem_h4, c.estimativas))
		if montagem_h4.produtos.is_empty():
			mudancas_h4.append("sem produto cartesiano")
		else:
			for tabela in montagem_h4.produtos:
				mudancas_h4.append("produto cartesiano inevitável com %s" % tabela)
	etapas.append({
		"id": "H4", "titulo": "H4 · EVITAR PRODUTO CARTESIANO",
		"regra": "R ⋈_c S ≡ σ_c(R × S): sem a condição c sobra o produto |R|·|S|",
		"mudancas": mudancas_h4,
		"arvore": arvore_final,
		"destacar": ["join"],
	})

	# Resumo (lista do passo 4)
	var heuristicas: Array = []
	for linha in mudancas_h1:
		heuristicas.append("H1 · " + linha)
	for linha in h2.mudancas:
		heuristicas.append("H2 · " + linha)
	if tabelas.size() > 1:
		heuristicas.append("H3 · junções, mais restritiva primeiro: " + _descreve_ordem(ordem_h4, c.estimativas))
		if montagem_h4.produtos.is_empty():
			heuristicas.append("H4 · sem produto cartesiano")
		else:
			for tabela in montagem_h4.produtos:
				heuristicas.append("H4 · produto cartesiano inevitável com %s" % tabela)
	else:
		heuristicas.append("H3/H4 · uma tabela: nada a ordenar")

	return {"arvore": arvore_final, "heuristicas": heuristicas, "ordem": ordem_h4,
		"estimativas": c.estimativas, "etapas": etapas}


# ---------- classificação das condições ----------

## Separa as comparações do ON/WHERE por quantas tabelas usam e estima as tuplas
## de cada tabela depois das suas seleções.
static func _classificar(ast: Dictionary) -> Dictionary:
	var tabelas: Array = [ast.from]
	var predicados: Array = []
	for juncao in ast.joins:
		tabelas.append(juncao.tabela)
		predicados.append_array(Estimativa.conjuncoes(juncao.condicao))
	if ast.where != null:
		predicados.append_array(Estimativa.conjuncoes(ast.where))
	var selecoes := {}           # tabela -> [COND]
	var juncoes: Array = []      # [{"condicao": COND, "tabelas": [...]}]
	var constantes: Array = []   # condições sem atributo (ex.: 1 = 1)
	for predicado in predicados:
		var usadas := _tabelas_de(predicado)
		if usadas.size() == 1:
			if not selecoes.has(usadas[0]):
				selecoes[usadas[0]] = []
			selecoes[usadas[0]].append(predicado)
		elif usadas.size() >= 2:
			juncoes.append({"condicao": predicado, "tabelas": usadas})
		else:
			constantes.append(predicado)
	var estimativas := {}
	for tabela in tabelas:
		var tuplas := Estimativa.cardinalidade(tabela)
		for condicao in selecoes.get(tabela, []):
			tuplas *= Estimativa.seletividade(condicao)
		estimativas[tabela] = tuplas
	var lista_select: Array = ast.select
	return {
		"tabelas": tabelas, "selecoes": selecoes, "juncoes": juncoes, "constantes": constantes,
		"estimativas": estimativas, "select": lista_select,
		"select_todos": lista_select.size() == 1 and lista_select[0] == "*",
	}


# ---------- construção da árvore ----------

## Folha de cada tabela: σ (H1) e, se pedido, π (H2) logo acima.
static func _folhas(c: Dictionary, com_projecao: bool) -> Dictionary:
	var folhas := {}
	var mudancas: Array = []
	for tabela in c.tabelas:
		var no := {"op": "tabela", "nome": tabela}
		if c.selecoes.has(tabela):
			no = {"op": "select", "condicao": _e(c.selecoes[tabela]), "filho": no}
		# Com uma tabela só, o π final já é a projeção; com SELECT * nada é descartado
		if com_projecao and not c.select_todos and c.tabelas.size() > 1:
			var necessarios := _atributos_necessarios(tabela, c.select, c.juncoes)
			var total: int = DbSchema.TABELAS.get(tabela, []).size()
			if necessarios.size() < total:
				no = {"op": "project", "atributos": necessarios, "filho": no}
				mudancas.append("π{%s} → %s  (%d de %d atributos)" % [
					AlgebraRenderer.texto_atributos(necessarios), tabela, necessarios.size(), total])
		folhas[tabela] = no
	if com_projecao and mudancas.is_empty():
		mudancas.append("sem projeção intermediária (" + (
			"SELECT *" if c.select_todos else "nada a descartar") + ")")
	return {"folhas": folhas, "mudancas": mudancas}


## Junções da esquerda para a direita na ordem dada. Cada tabela leva junto as
## condições que já podem ser avaliadas; sem nenhuma, vira produto cartesiano.
static func _monta(ordem: Array, folhas: Dictionary, juncoes: Array) -> Dictionary:
	var arvore: Dictionary = folhas[ordem[0]]
	var unidas: Array = [ordem[0]]
	var aplicadas: Array = []
	var produtos: Array = []
	for k in range(1, ordem.size()):
		var proxima: String = ordem[k]
		var condicoes: Array = []
		for i in juncoes.size():
			if i in aplicadas:
				continue
			var cabe := true
			for usada in juncoes[i].tabelas:
				if not (usada in unidas or usada == proxima):
					cabe = false
			if cabe:
				condicoes.append(juncoes[i].condicao)
				aplicadas.append(i)
		if condicoes.is_empty():
			arvore = {"op": "produto", "esq": arvore, "dir": folhas[proxima]}
			produtos.append(proxima)
		else:
			arvore = {"op": "join", "condicao": _e(condicoes), "esq": arvore, "dir": folhas[proxima]}
		unidas.append(proxima)
	return {"arvore": arvore, "produtos": produtos}


## Condições sem atributo ficam numa σ no topo; a raiz é sempre a projeção final.
static func _finaliza(arvore: Dictionary, c: Dictionary) -> Dictionary:
	if not c.constantes.is_empty():
		arvore = {"op": "select", "condicao": _e(c.constantes), "filho": arvore}
	return {"op": "project", "atributos": c.select, "filho": arvore}


# ---------- ordens de junção ----------

## H3: da menor para a maior estimativa (empate mantém a ordem da consulta).
static func _ordem_por_estimativa(tabelas: Array, estimativas: Dictionary) -> Array:
	var restantes := tabelas.duplicate()
	var ordem: Array = []
	while not restantes.is_empty():
		var proxima := _mais_restritiva(restantes, estimativas)
		ordem.append(proxima)
		restantes.erase(proxima)
	return ordem


## H4: começa pela mais restritiva e, a cada passo, escolhe a mais restritiva
## entre as tabelas ligadas por condição às já unidas.
static func _ordem_conectada(tabelas: Array, estimativas: Dictionary, juncoes: Array) -> Array:
	var restantes := tabelas.duplicate()
	var primeira := _mais_restritiva(restantes, estimativas)
	restantes.erase(primeira)
	var ordem: Array = [primeira]
	var aplicadas: Array = []
	while not restantes.is_empty():
		var candidatas: Array = []
		for tabela in restantes:
			if _ligada(tabela, ordem, juncoes, aplicadas):
				candidatas.append(tabela)
		var proxima := _mais_restritiva(candidatas if not candidatas.is_empty() else restantes, estimativas)
		for i in juncoes.size():
			if i in aplicadas:
				continue
			var cabe := true
			for usada in juncoes[i].tabelas:
				if not (usada in ordem or usada == proxima):
					cabe = false
			if cabe:
				aplicadas.append(i)
		ordem.append(proxima)
		restantes.erase(proxima)
	return ordem


static func _descreve_ordem(ordem: Array, estimativas: Dictionary) -> String:
	var partes: Array = []
	for tabela in ordem:
		partes.append(tabela)
	return " → ".join(partes)


# ---------- auxiliares ----------

## Junta comparações com AND (o inverso de Estimativa.conjuncoes).
static func _e(condicoes: Array) -> Dictionary:
	var resultado: Dictionary = condicoes[0]
	for i in range(1, condicoes.size()):
		resultado = {"tipo": "and", "esq": resultado, "dir": condicoes[i]}
	return resultado


static func _tabelas_de(comparacao: Dictionary) -> Array:
	var usadas: Array = []
	for lado in [comparacao.esq, comparacao.dir]:
		if lado.tipo == "atributo":
			var tabela: String = lado.nome.get_slice(".", 0)
			if not (tabela in usadas):
				usadas.append(tabela)
	return usadas


## Atributos da tabela usados depois dela: lista do SELECT e condições de junção.
## Ficam na ordem do modelo de dados.
static func _atributos_necessarios(tabela: String, lista_select: Array, juncoes: Array) -> Array:
	var usados: Array = []
	for nome in lista_select:
		usados.append(nome)
	for juncao in juncoes:
		for lado in [juncao.condicao.esq, juncao.condicao.dir]:
			if lado.tipo == "atributo":
				usados.append(lado.nome)
	var necessarios: Array = []
	for coluna in DbSchema.TABELAS.get(tabela, []):
		var nome := "%s.%s" % [tabela, coluna]
		if nome in usados:
			necessarios.append(nome)
	return necessarios


## Menor estimativa de tuplas; empate fica com a primeira na ordem da consulta.
static func _mais_restritiva(tabelas: Array, estimativas: Dictionary) -> String:
	var melhor: String = tabelas[0]
	for tabela in tabelas:
		if estimativas[tabela] < estimativas[melhor]:
			melhor = tabela
	return melhor


## A tabela tem condição de junção ainda não aplicada que a liga às já unidas?
static func _ligada(tabela: String, unidas: Array, juncoes: Array, aplicadas: Array) -> bool:
	for i in juncoes.size():
		if i in aplicadas or not (tabela in juncoes[i].tabelas):
			continue
		var cabe := true
		for usada in juncoes[i].tabelas:
			if not (usada in unidas or usada == tabela):
				cabe = false
		if cabe:
			return true
	return false
