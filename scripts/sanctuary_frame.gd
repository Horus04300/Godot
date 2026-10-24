extends Control

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var brass = Color("#a68e5e")
	var light = Color("#dfc58b")
	var outer = Rect2(Vector2(-20, -9), size + Vector2(40, 18))
	draw_rect(outer, Color("#445a50"), false, 1)
	for corner in [outer.position, Vector2(outer.end.x, outer.position.y), Vector2(outer.position.x, outer.end.y), outer.end]:
		var sign_x = 1.0 if corner.x < size.x / 2 else -1.0
		var sign_y = 1.0 if corner.y < size.y / 2 else -1.0
		var axis_x = Vector2(sign_x, 0)
		var axis_y = Vector2(0, sign_y)
		draw_polyline(PackedVector2Array([corner + axis_y * 34, corner, corner + axis_x * 34]), brass, 2)
		draw_colored_polygon(PackedVector2Array([corner + axis_y * 6, corner + axis_x * 16 + axis_y * 4, corner + axis_x * 6 + axis_y * 16]), brass)
		draw_line(corner + axis_x * 4 + axis_y * 4, corner + axis_x * 14 + axis_y * 14, light, 1)
	var mid = Vector2(size.x / 2, outer.position.y)
	draw_colored_polygon(PackedVector2Array([mid + Vector2(-6, 0), mid + Vector2(0, -4), mid + Vector2(6, 0), mid + Vector2(0, 4)]), light)
