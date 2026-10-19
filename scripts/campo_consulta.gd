extends TextEdit
## Campo de consulta de várias linhas (aceita Ctrl+V de consultas inteiras).
## ENTER envia, SHIFT+ENTER quebra linha, CIMA/BAIXO percorrem o histórico
## quando o cursor está na primeira/última linha.

signal enviado(texto: String)
signal historico_anterior
signal historico_proximo


func _gui_input(evento: InputEvent) -> void:
	if not (evento is InputEventKey) or not evento.pressed or evento.echo:
		return
	match evento.keycode:
		KEY_ENTER, KEY_KP_ENTER:
			if evento.shift_pressed:
				return
			accept_event()
			enviado.emit(text)
		KEY_UP:
			if get_caret_line() == 0:
				accept_event()
				historico_anterior.emit()
		KEY_DOWN:
			if get_caret_line() == get_line_count() - 1:
				accept_event()
				historico_proximo.emit()
