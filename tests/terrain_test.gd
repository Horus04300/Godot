extends RefCounted

static func run(game: Node) -> void:
	game.set_process(false)
	game._start_run()
	var checked = 0
	for index in 5:
		game.room_layout = index
		game._apply_layout(index)
		game.player = game.room_entry
		game._rebuild_navigation()
		var start = game.ForestMaps.cell_at(game.room_entry)
		var reachable: Dictionary = {start: true}
		var queue: Array = [start]
		var cursor = 0
		while cursor < queue.size():
			var cell: Vector2i = queue[cursor]
			cursor += 1
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				var next: Vector2i = cell + direction
				if game.navigation.is_in_boundsv(next) and not game.navigation.is_point_solid(next) and not reachable.has(next):
					reachable[next] = true
					queue.append(next)
		var navigable = 0
		var water = 0
		var bridges = 0
		var banks = 0
		var boundaries = 0
		var visible_boundary: Dictionary = {}
		for prop in game.boundary_props:
			visible_boundary[game.ForestMaps.cell_at(prop.pos)] = true
		for cell in game.forest_boundary:
			assert(not game.terrain.has(cell), "자연물 경계가 통로를 덮었습니다.")
			assert(not game._actor_clear(game.ForestMaps.center(cell), 0))
			if game.forest_boundary[cell] == 1:
				assert(visible_boundary.has(cell), "충돌 경계에 나무·덤불·바위 표시가 없습니다.")
		var x_min = 99
		var x_max = -1
		var y_min = 99
		var y_max = -1
		for cell in game.terrain:
			x_min = mini(x_min, cell.x)
			x_max = maxi(x_max, cell.x)
			y_min = mini(y_min, cell.y)
			y_max = maxi(y_max, cell.y)
			var center: Vector2 = game.ForestMaps.center(cell)
			if game.terrain[cell] == "water":
				water += 1
				assert(not game.ForestMaps.walkable(game.terrain, center))
				assert(game.navigation.is_point_solid(cell))
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					var bank = center + Vector2(direction) * 32
					if not game._actor_clear(bank, 12):
						continue
					var end: Vector2 = game._move_actor(bank, -Vector2(direction) * 160, 12)
					assert(game._actor_clear(end, 12) and end.distance_to(bank) < 32, "회피가 물길을 통과했습니다.")
					banks += 1
			elif game.terrain[cell] == "bridge":
				bridges += 1
			if not game.navigation.is_point_solid(cell):
				assert(reachable.has(cell), "고립된 내비게이션 셀: %s / %d" % [cell, index])
				navigable += 1
			if game._spawn_clear(center):
				assert(game._actor_clear(center, 29))
				checked += 1
			if game._actor_clear(center, 12):
				for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
					if game.terrain.has(cell + direction):
						continue
					assert(game.forest_boundary.get(cell + direction, 0) == 1)
					var end: Vector2 = game._move_actor(center, Vector2(direction) * 320, 12)
					assert(game._actor_clear(end, 12) and end.distance_to(center) < 32, "회피가 숲 경계를 통과했습니다.")
					boundaries += 1
		var bounding_area = (x_max - x_min + 1) * (y_max - y_min + 1)
		assert(game.terrain.size() < bounding_area * 0.85, "바닥이 여전히 직사각형입니다.")
		assert(navigable > 100 and water > 0 and bridges >= 9 and banks > 0 and boundaries > 20)
		for anchor in [game.ALTAR, game.PORTAL, game.WEST_GATE, game.EAST_GATE]:
			var goal: Vector2i = game.ForestMaps.cell_at(anchor)
			assert(not game.navigation.is_point_solid(goal), "막힌 제단/출구: %s / %d" % [goal, index])
			var path: PackedVector2Array = game.navigation.get_point_path(start, goal)
			assert(path.size() > 1)
			var actor: Vector2 = game.room_entry
			for point in path:
				actor = game._move_actor(actor, point - actor, 29)
				assert(actor.distance_to(point) < 0.01, "다리 또는 굽이 통과 실패")
			assert(actor.distance_to(anchor) < 0.01)
		var gates = [game.PORTAL, game.WEST_GATE, game.EAST_GATE]
		for first in range(gates.size()):
			assert(gates[first].distance_to(game.ALTAR) > 80)
			for second in range(first + 1, gates.size()):
				assert(gates[first].distance_to(gates[second]) > 156, "출구 상호작용 영역이 겹칩니다.")
		game.room_clear = true
		game.player = game.PORTAL
		game._interact()
		assert(game.state == "route" and game.buttons.size() == 3, "경로판 대신 옆 출구가 열렸습니다.")
		game._close_overlay()
		game.state = "playing"
		assert(not game._projectile_line_clear(game.room_entry, Vector2(-50, -50)))
		print("TERRAIN_MAP_PASS: %d silhouette=%d/%d connected=%d water=%d bridges=%d blocked_dash_banks=%d natural_boundaries=%d visible_boundary_props=%d" % [index, game.terrain.size(), bounding_area, navigable, water, bridges, banks, boundaries, visible_boundary.size()])
	game.layout_bag.clear()
	var last = -1
	for cycle in 10:
		var seen: Dictionary = {}
		for room in 5:
			game._enter_room(0, "battle")
			assert(not seen.has(game.room_layout))
			assert(last != game.room_layout)
			seen[game.room_layout] = true
			last = game.room_layout
			for enemy in game.enemies:
				assert(game._actor_clear(enemy.pos, game._enemy_radius(enemy)))
	print("TERRAIN_TEST_PASS: %d safe spawn cells, five connected forest clearings, visible natural boundaries, water/dash/bridge paths, 50-room rotation" % checked)
	await game.IntegrationTests.finish(game, "TERRAIN_COMPLETE")
