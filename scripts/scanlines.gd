extends Control
## Linhas horizontais sutis por cima da tela, para o efeito de monitor antigo.


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	for y in range(0, int(size.y), 3):
		draw_line(Vector2(0, y), Vector2(size.x, y), Color(0, 0, 0, 0.25))
