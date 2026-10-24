extends Control

var game: Node

func _ready() -> void:
	custom_minimum_size = Vector2(0, 215)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _point(pos: Vector2) -> Vector2:
	var scale_factor = minf((size.x - 40) / 1900.0, (size.y - 12) / 950.0)
	return size / 2 + game._project(pos - game.ARENA.get_center()) * scale_factor

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("#091d22"))
	for cell in game.forest_boundary:
		if game.forest_boundary[cell] == 1:
			draw_circle(_point(game.ForestMaps.center(cell)), 2, Color("#25493c"))
	for cell in game.terrain:
		var at: Vector2 = game.ForestMaps.ORIGIN + Vector2(cell) * 32
		var points = PackedVector2Array()
		for corner in [at, at + Vector2(32, 0), at + Vector2(32, 32), at + Vector2(0, 32)]:
			points.append(_point(corner))
		var kind: String = game.terrain[cell]
		var color = Color("#456f62")
		if kind == "water":
			color = Color("#338c9a")
		elif kind == "bridge":
			color = Color("#d2af6c")
		draw_colored_polygon(points, color)
		for pair in [[Vector2i.LEFT, 0, 3], [Vector2i.RIGHT, 1, 2], [Vector2i.UP, 0, 1], [Vector2i.DOWN, 3, 2]]:
			if not game.terrain.has(cell + pair[0]):
				draw_line(points[pair[1]], points[pair[2]], Color("#648260"), 1)
	for tree in game.obstacles:
		draw_circle(_point(tree), 2, Color("#102c2d"))
	for rock in game.structures:
		draw_circle(_point(rock.get_center()), 2, Color("#102c2d"))
	for gate in [game.PORTAL, game.WEST_GATE, game.EAST_GATE]:
		var pos = _point(gate)
		draw_colored_polygon(PackedVector2Array([pos + Vector2(0, -4), pos + Vector2(4, 0), pos + Vector2(0, 4), pos + Vector2(-4, 0)]), game.GOLD)
	draw_arc(_point(game.ALTAR), 5, 0, TAU, 20, game.MINT, 2)
	for enemy in game.enemies:
		if enemy.hp > 0 and (enemy.alert or enemy.kind == "boss"):
			draw_circle(_point(enemy.pos), 2, game.RED)
	draw_circle(_point(game.player), 4, game.PAPER)
	draw_arc(_point(game.player), 7, 0, TAU, 20, game.PAPER, 1)
