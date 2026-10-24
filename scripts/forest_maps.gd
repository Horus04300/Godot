extends RefCounted

const NAMES = ["달빛 꺾임 · ㄱ", "침수 회랑 · ㄷ", "뿌리의 굽이 · ㄹ", "잊힌 원환", "세 갈래 성역"]
const ORIGIN = Vector2(64, 128)
const CELL = 32.0
const GRID = Vector2i(43, 26)
const DEFINITIONS = [
	{"areas": [Rect2i(5, 3, 7, 21), Rect2i(5, 3, 33, 7)],
		"entry": Vector2i(8, 21), "altar": Vector2i(8, 6),
		"gates": [Vector2i(35, 6), Vector2i(25, 4), Vector2i(30, 8)],
		"water": Rect2i(5, 14, 7, 3), "bridge": Rect2i(7, 14, 3, 3),
		"route": [Vector2i(8, 21), Vector2i(8, 6), Vector2i(35, 6)]},
	{"areas": [Rect2i(4, 3, 8, 21), Rect2i(4, 17, 34, 7), Rect2i(30, 3, 8, 21)],
		"entry": Vector2i(7, 5), "altar": Vector2i(24, 20),
		"gates": [Vector2i(34, 5), Vector2i(32, 10), Vector2i(35, 15)],
		"water": Rect2i(17, 17, 4, 7), "bridge": Rect2i(17, 19, 4, 3),
		"route": [Vector2i(7, 5), Vector2i(7, 20), Vector2i(34, 20), Vector2i(34, 5)]},
	{"areas": [Rect2i(5, 3, 33, 6), Rect2i(32, 3, 6, 14), Rect2i(5, 11, 33, 5), Rect2i(5, 11, 6, 14), Rect2i(5, 19, 33, 6)],
		"entry": Vector2i(35, 22), "altar": Vector2i(17, 13),
		"gates": [Vector2i(7, 5), Vector2i(13, 4), Vector2i(19, 6)],
		"water": Rect2i(20, 11, 3, 6), "bridge": Rect2i(20, 12, 3, 3),
		"route": [Vector2i(35, 22), Vector2i(8, 22), Vector2i(8, 14), Vector2i(35, 14), Vector2i(35, 6), Vector2i(8, 6)]},
	{"areas": [Rect2i(5, 3, 33, 7), Rect2i(5, 17, 33, 7), Rect2i(5, 3, 7, 21), Rect2i(31, 3, 7, 21)],
		"entry": Vector2i(21, 21), "altar": Vector2i(8, 13),
		"gates": [Vector2i(21, 6), Vector2i(15, 5), Vector2i(27, 7)],
		"water": Rect2i(31, 12, 7, 3), "bridge": Rect2i(33, 12, 3, 3),
		"route": [Vector2i(21, 21), Vector2i(8, 21), Vector2i(8, 6), Vector2i(34, 6), Vector2i(34, 21), Vector2i(21, 21)]},
	{"areas": [Rect2i(4, 4, 35, 8), Rect2i(17, 4, 9, 20)],
		"entry": Vector2i(21, 21), "altar": Vector2i(21, 9),
		"gates": [Vector2i(21, 6), Vector2i(7, 8), Vector2i(35, 8)],
		"water": Rect2i(17, 14, 9, 3), "bridge": Rect2i(20, 14, 3, 3),
		"route": [Vector2i(21, 21), Vector2i(21, 8), Vector2i(7, 8), Vector2i(35, 8)]}
]

static func center(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2(cell) * CELL + Vector2.ONE * CELL * 0.5

static func cell_at(pos: Vector2) -> Vector2i:
	return Vector2i(floori((pos.x - ORIGIN.x) / CELL), floori((pos.y - ORIGIN.y) / CELL))

static func layout(index: int) -> Dictionary:
	var definition: Dictionary = DEFINITIONS[posmod(index, 5)]
	var cells: Dictionary = {}
	for rect in definition.areas:
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				cells[Vector2i(x, y)] = "grass"
	for cell in cells:
		if definition.water.has_point(cell):
			cells[cell] = "bridge" if definition.bridge.has_point(cell) else "water"
		elif _on_trail(cell, definition.route):
			cells[cell] = "stone"
	var route: Array = []
	for cell in definition.route:
		route.append(center(cell))
	var gates: Array = []
	for cell in definition.gates:
		gates.append(center(cell))
	var anchors: Array = [center(definition.entry), center(definition.altar)] + gates
	var trees: Array = []
	var rocks: Array = []
	var decorations: Array = []
	for cell in cells:
		if cells[cell] in ["water", "bridge"]:
			continue
		var pos = center(cell)
		var safe = anchors.any(func(anchor): return anchor.distance_to(pos) < 130)
		if safe:
			continue
		var edge = not cells.has(cell + Vector2i.LEFT) or not cells.has(cell + Vector2i.UP)
		var hash_value = absi(cell.x * 197 + cell.y * 47 + index * 31)
		if edge and hash_value % 11 == 0:
			trees.append(pos)
		elif edge and hash_value % 13 == 0:
			rocks.append(Rect2(pos - Vector2(14, 14), Vector2(28, 28)))
		elif hash_value % 23 == 0:
			var kind: String = ["mushroom", "pillar", "roots"][int(hash_value / 9) % 3]
			if kind == "pillar":
				if not edge:
					kind = "roots"
				else:
					rocks.append(Rect2(pos - Vector2(13, 13), Vector2(26, 26)))
			decorations.append({"pos": pos, "kind": kind})
	var boundary = boundary_cells(cells)
	return {"cells": cells, "boundary": boundary, "rocks": rocks, "trees": trees, "decorations": decorations,
		"entry": center(definition.entry), "altar": center(definition.altar), "gates": gates,
		"paths": [route], "water_rect": definition.water, "bridge_rect": definition.bridge}

static func _on_trail(cell: Vector2i, route: Array) -> bool:
	for index in range(route.size() - 1):
		var nearest = Geometry2D.get_closest_point_to_segment(Vector2(cell), Vector2(route[index]), Vector2(route[index + 1]))
		if nearest.distance_to(Vector2(cell)) <= 1.4:
			return true
	return false

static func boundary_cells(cells: Dictionary) -> Dictionary:
	var boundary: Dictionary = {}
	for cell in cells:
		for y in range(-3, 4):
			for x in range(-3, 4):
				var outside: Vector2i = cell + Vector2i(x, y)
				if cells.has(outside):
					continue
				var distance = maxi(absi(x), absi(y))
				boundary[outside] = mini(boundary.get(outside, 4), distance)
	return boundary

static func walkable(cells: Dictionary, pos: Vector2, radius: float = 0.0) -> bool:
	var minimum = cell_at(pos - Vector2.ONE * radius)
	var maximum = cell_at(pos + Vector2.ONE * radius)
	for y in range(minimum.y, maximum.y + 1):
		for x in range(minimum.x, maximum.x + 1):
			var cell = Vector2i(x, y)
			if cells.get(cell, "void") in ["water", "void"]:
				return false
	return true
