extends Control

const Augments = preload("res://scripts/augments.gd")
var rank = 0
var elapsed = 0.0
var animate = true

func _ready() -> void:
	custom_minimum_size.y = 24
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 1.3:
		queue_redraw()

func _draw() -> void:
	var color = Color(Augments.COLORS[rank])
	var center = size / 2
	draw_line(center - Vector2(54, 0), center + Vector2(54, 0), color, 1)
	for line in rank + 1:
		var x = center.x - rank * 7 + line * 14
		var height = 4 + rank
		draw_line(Vector2(x, center.y - height), Vector2(x, center.y + height), color, 2)
	if animate and elapsed < 1.2:
		for ray in (rank + 1) * 2:
			var direction = Vector2.from_angle(ray * TAU / ((rank + 1) * 2))
			var distance = 7 + elapsed * (12 + rank * 9)
			draw_line(center + direction * distance, center + direction * (distance + 2 + rank), Color(color, 1 - elapsed / 1.2), 2)
