extends Control

const Augments = preload("res://scripts/augments.gd")
const SanctuaryArt = preload("res://scripts/sanctuary_art.gd")
var rank = 0
var element = ""
var assets: Dictionary = {}
var elapsed = 0.0
var animate = true

func _ready() -> void:
	custom_minimum_size.y = 44
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(delta: float) -> void:
	elapsed += delta
	if elapsed < 1.3:
		queue_redraw()

func _draw() -> void:
	var color = Color(Augments.COLORS[rank])
	var center = size / 2
	draw_line(center - Vector2(70, 0), center - Vector2(26, 0), color, 1)
	draw_line(center + Vector2(26, 0), center + Vector2(70, 0), color, 1)
	if not element.is_empty():
		SanctuaryArt.icon(self, assets, element, center - Vector2(17, 17), 34)
		var diamond = PackedVector2Array([center + Vector2(0, -21), center + Vector2(21, 0), center + Vector2(0, 21), center + Vector2(-21, 0), center + Vector2(0, -21)])
		draw_polyline(diamond, color, 1 + rank / 2)
	for line in rank + 1:
		var x = center.x - 66 + line * 7
		var height = 4 + rank
		draw_line(Vector2(x, center.y - height), Vector2(x, center.y + height), color, 2)
		draw_line(Vector2(center.x * 2 - x, center.y - height), Vector2(center.x * 2 - x, center.y + height), color, 2)
	if animate and elapsed < 1.2:
		for ray in (rank + 1) * 2:
			var direction = Vector2.from_angle(ray * TAU / ((rank + 1) * 2))
			var distance = 7 + elapsed * (12 + rank * 9)
			draw_line(center + direction * distance, center + direction * (distance + 2 + rank), Color(color, 1 - elapsed / 1.2), 2)
