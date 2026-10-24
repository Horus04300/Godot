extends RefCounted

static func click(game: Node, index: int) -> void:
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	var button: Button = game.buttons[index]
	assert(not button.disabled)
	var center = button.get_global_rect().get_center()
	var motion = InputEventMouseMotion.new()
	motion.position = center
	game.get_viewport().push_input(motion, true)
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		game.get_viewport().push_input(event, true)
	await game.get_tree().process_frame

static func key(game: Node, physical_key: Key) -> void:
	for pressed in [true, false]:
		var event = InputEventKey.new()
		event.physical_keycode = physical_key
		event.keycode = physical_key
		event.pressed = pressed
		game.get_viewport().push_input(event, true)
	await game.get_tree().process_frame

static func run(game: Node) -> void:
	await game.get_tree().process_frame
	await click(game, 2)
	assert(game.state == "help")
	await key(game, KEY_ESCAPE)
	assert(game.state == "hub")
	print("UI_PASS: hub help > Escape > hub")
	await key(game, KEY_TAB)
	assert(game.buttons[2].has_focus())
	await key(game, KEY_ENTER)
	assert(game.state == "help")
	await key(game, KEY_SPACE)
	assert(game.state == "hub")
	print("UI_PASS: Tab skips disabled upgrade, Enter opens help, Space closes help")
	await click(game, 0)
	assert(game.state == "playing")
	await key(game, KEY_ESCAPE)
	assert(game.state == "pause")
	await click(game, 3)
	assert(game.muted)
	await click(game, 1)
	assert(game.state == "inventory")
	await click(game, 0)
	assert(game.state == "help")
	await click(game, 0)
	assert(game.state == "pause")
	await click(game, 0)
	assert(game.state == "playing")
	print("UI_PASS: start > pause > mute > inventory > help > back > resume")
	await key(game, KEY_T)
	assert(not game.mouse_aim)
	await key(game, KEY_TAB)
	assert(game.state == "help")
	await key(game, KEY_ESCAPE)
	assert(game.state == "playing")
	print("UI_PASS: keyboard aim toggle, Tab help, Escape resume")
	for depth in 6:
		if depth == 3:
			game._enter_room(depth, "treasure")
			game.player = game.ALTAR
			game._interact()
		else:
			game._enter_room(depth, "elite" if depth == 2 else "battle")
			for enemy in game.enemies:
				enemy.hp = 0
			game._collect_dead()
		assert(game.state == "reward")
		await click(game, depth % 3)
		assert(game.room_clear and game.state == "playing")
		game.player = game.PORTAL
		game._interact()
		assert(game.state == "route")
		if depth == 0:
			await click(game, 2)
			assert(game.state == "playing" and game.room_clear)
			game._interact()
			await click(game, 1)
			assert(game.room_type == "elite")
		else:
			await click(game, 0)
			assert(game.depth == depth + 1)
	print("UI_PASS: all 3 relic buttons, normal/elite/rest/boss routes, route cancel, 7-room progression")
	game.enemies[0].hp = 0
	game._collect_dead()
	assert(game.state == "victory")
	await click(game, 1)
	assert(game.state == "playing" and game.depth == 0)
	game.invulnerable = 0
	game.hp = 1
	game._shoot(game.player, Vector2.ZERO, 0, 50)
	game._tick_projectiles(0.01)
	assert(game.state == "dead" and game.projectiles.is_empty())
	await click(game, 0)
	assert(game.state == "hub")
	game.meta_embers = 500
	game._show_hub()
	await click(game, 1)
	assert(game.meta_level == 1)
	await click(game, 0)
	game.invulnerable = 0
	game.hp = 1
	game.hazards.append({"pos": game.player, "timer": 0.001, "life": 0.01, "fired": false})
	game._tick_hazards(0.02)
	assert(game.state == "dead")
	await key(game, KEY_R)
	assert(game.state == "playing")
	await key(game, KEY_ESCAPE)
	await click(game, 2)
	assert(game.state == "hub")
	print("UI_PASS: victory retry, lethal projectile, death return, upgrade, lethal hazard, R retry, abandon")
	game._enter_room(3, "rest")
	game.player = game.ALTAR
	game._interact()
	await click(game, 1)
	assert(game.room_clear and game.attack_power == 30)
	game._enter_room(3, "rest")
	game.hp = 10
	game.player = game.ALTAR
	game._interact()
	await click(game, 0)
	assert(game.hp > 10 and game.room_clear)
	print("UI_PASS: rest altar blessing and healing")
	game.save_path = "user://integration_test_%d.json" % Time.get_ticks_usec()
	game.testing = false
	game.save_error = ""
	game.meta_embers = 137
	game.meta_level = 3
	game.best_depth = 7
	assert(game._save())
	game.meta_embers = 0
	game.meta_level = 0
	game.best_depth = 0
	game._load_save()
	assert(game.meta_embers == 137 and game.meta_level == 3 and game.best_depth == 7)
	game.meta_embers = 138
	assert(game._save())
	game._load_save()
	assert(game.meta_embers == 138)
	assert(DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path)) == OK)
	game.testing = true
	print("PERSISTENCE_PASS: atomic create, readback, overwrite, readback; isolated test save removed")
	game._close_overlay()
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	print("INTEGRATION_PASS: real viewport mouse/key events, all game menu actions, lethal damage regressions, persistence")
	game.get_tree().quit(0)

static func quit_test(game: Node) -> void:
	await click(game, 3)
	assert(game.quitting)
	print("QUIT_PASS: real quit button click initiated clean application shutdown")

static func click_board(game: Node, index: int) -> void:
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	var center: Vector2 = game.board_buttons[index].get_global_rect().get_center()
	for pressed in [true, false]:
		var event = InputEventMouseButton.new()
		event.position = center
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		game.get_viewport().push_input(event, true)
	await game.get_tree().process_frame

static func overhaul(game: Node) -> void:
	game._start_run()
	assert(game.ARENA.size.x > 960 and game.ARENA.size.y > 540)
	game._apply_relic("edge")
	game._apply_relic("fire")
	game._apply_relic("storm")
	assert(game._board_bonus() == 4)
	game._apply_relic("edge")
	assert(game._occupied_slots() == 3 and game.relics.edge == 2)
	game._show_inventory()
	assert(game.board_buttons[0].has_focus())
	await click_board(game, 1)
	assert(game.board_selected == 1)
	await click_board(game, 7)
	assert(game.board[7] == "fire" and game.board[1] == "" and game._board_bonus() == 2)
	assert(game.board_buttons[7].has_focus())
	await key(game, KEY_I)
	assert(game.state == "playing")
	await key(game, KEY_G)
	assert(game.state == "map")
	await click(game, 0)
	assert(game.state == "playing")
	print("OVERHAUL_PASS: 5x4 board, real two-click relocation, family adjacency recomputed, stacked relic, G map")
	game._offer_relics()
	var original = game.offered.duplicate()
	await click(game, 3)
	assert(game.rerolls == 0 and game.buttons[3].disabled)
	for offer in game.offered:
		assert(offer not in original)
	var rerolled = game.offered.duplicate()
	await key(game, KEY_ESCAPE)
	assert(game.state == "playing" and game.reward_deferred and not game.room_clear)
	game.player = game.ALTAR
	game._interact()
	assert(game.state == "reward" and game.offered == rerolled and game.rerolls == 0)
	await click(game, 0)
	assert(game.room_clear)
	game.player = game.WEST_GATE
	game._interact()
	assert(game.depth == 1 and game.room_type == "battle")
	game.room_clear = true
	game.player = game.EAST_GATE
	game._interact()
	assert(game.depth == 2 and game.room_type == "elite")
	print("OVERHAUL_PASS: reroll button and limit, physical west/east branching gates")
	game._enter_room(3, "shop")
	game.gold = 50
	game.hp = 1
	game.player = game.ALTAR
	game._interact()
	assert(game.state == "shop")
	await click(game, 1)
	assert(game.gold == 38 and game.hp == 36)
	await click(game, 0)
	assert(game.gold == 13 and game.state == "reward")
	await click(game, 2)
	game._show_shop()
	assert(game.buttons[0].disabled)
	await click(game, 2)
	assert(game.room_clear and game.state == "playing")
	print("OVERHAUL_PASS: merchant heal, relic purchase, price deduction, once-per-room limit and exit")
	game._start_run()
	game.enemies.clear()
	game.obstacles.clear()
	game.breakables.clear()
	game.player = Vector2(700, 500)
	game.facing = Vector2.RIGHT
	game.mouse_aim = false
	game.attack_cd = 0
	var enemy: Dictionary = game._spawn_enemy("brute", Vector2(755, 500))
	enemy.hp = 1000
	enemy.max_hp = 1000
	game.crit_chance = 0
	game._attack(false)
	var old_health: float = enemy.hp
	game._tick_strike(0.02)
	assert(enemy.hp == old_health)
	game._tick_strike(0.03)
	assert(enemy.hp == old_health - game.attack_power and game.impacts.size() > 0)
	game.attack_cd = 0
	game._attack(false)
	game._dash(Vector2.RIGHT)
	assert(game.pending_strike.is_empty() and game.dash_charges == 1)
	game.attack_cd = 0
	game._attack(false)
	old_health = enemy.hp
	game._tick_strike(0.05)
	assert(enemy.hp < old_health - game.attack_power and game.dash_attack)
	game._dash(Vector2.RIGHT)
	assert(game.dash_charges == 0)
	var remaining: float = game.dash_cd
	game._dash(Vector2.LEFT)
	assert(game.dash_charges == 0 and game.dash_cd == remaining)
	game._tick_player(game.dash_duration + 0.01)
	assert(game.dash_charges == 1)
	print("OVERHAUL_PASS: timed hit, windup dash cancellation, dash-strike bonus, double dash charge and recharge")
	game.dash_time = 0
	game.attack_cd = 0
	game.pending_strike.clear()
	game.facing = Vector2.RIGHT
	game.breakables.append({"pos": game.player + Vector2(30, 0), "hp": 14.0, "kind": "crate"})
	var old_gold: int = game.gold
	game._attack(false)
	game._tick_strike(0.05)
	assert(game.breakables[0].hp == 0 and game.gold == old_gold + 3)
	game._gain_experience(45)
	assert(game.level == 2 and game.attack_power == 22 and game.max_hp == 115)
	await key(game, KEY_V)
	assert(not game.effects_enabled)
	game._enter_room(0, "battle")
	var wall: Rect2 = game.structures[0]
	var from = Vector2(wall.position.x - 60, wall.get_center().y)
	var stopped: Vector2 = game._move_actor(from, Vector2(300, 0), 12)
	assert(stopped.x < wall.position.x and not wall.has_point(stopped))
	var start = Vector2i((from - game.ARENA.position) / 32)
	var end = Vector2i((from + Vector2(330, 0) - game.ARENA.position) / 32)
	var route: PackedVector2Array = game.navigation.get_point_path(start, end)
	assert(route.size() > 2)
	for point in route:
		assert(not wall.grow(12).has_point(point))
	game.enemies.clear()
	var slammed: Dictionary = game._spawn_enemy("brute", from + Vector2(20, 0))
	slammed.hp = 200
	slammed.knock = Vector2(320, 0)
	game._tick_enemies(0.2)
	assert(slammed.wall_hit and slammed.hp == 190)
	game._close_overlay()
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	print("OVERHAUL_PASS: destructibles, gold, exact XP threshold, level stats, reduced effects toggle")
	print("OVERHAUL_PASS: no tunneling through ruin wall, valid AStar path, 10 damage wall slam, reward defer/resume without reroll exploit")
	game.get_tree().quit(0)

static func combat_run(game: Node) -> void:
	seed(1234)
	game.rng.seed = 1234
	game._start_run()
	game.mouse_aim = false
	var ticks = 0
	var path = PackedVector2Array()
	var path_index = 0
	for room in 7:
		path = PackedVector2Array()
		if room == 3:
			game._enter_room(room, "rest")
			game._show_rest()
			game._rest_choice(true)
		else:
			if room > 0:
				game._enter_room(room, "boss" if room == 6 else "battle")
			var room_ticks = 0
			while game.state == "playing" and not game.room_clear and room_ticks < 5400:
				var nearest: Dictionary = {}
				var distance = INF
				for enemy in game.enemies:
					if enemy.hp > 0 and enemy.pos.distance_to(game.player) < distance:
						nearest = enemy
						distance = enemy.pos.distance_to(game.player)
				if not nearest.is_empty():
					var direction: Vector2 = (nearest.pos - game.player).normalized()
					game.facing = direction
					if distance > 60 and game.dash_time <= 0:
						if room_ticks % 15 == 0 or path.is_empty():
							path = PackedVector2Array()
							var start = Vector2i((game.player - game.ARENA.position) / 32)
							var end = Vector2i((nearest.pos - game.ARENA.position) / 32)
							if not game.navigation.is_point_solid(start) and not game.navigation.is_point_solid(end):
								path = game.navigation.get_point_path(start, end)
								path_index = mini(1, path.size() - 1)
						if path.size() > 1 and path_index >= 0:
							if game.player.distance_to(path[path_index]) < 20 and path_index < path.size() - 1:
								path_index += 1
							direction = (path[path_index] - game.player).normalized()
						game.player = game._move_actor(game.player, direction * game.move_speed / 60.0, 12)
					if distance < 115 and game.skill_cd <= 0:
						game._attack(true)
					elif distance < game.attack_range + 8 and game.attack_cd <= 0:
						game._attack(false)
					if nearest.windup > 0.1 and distance < 78 and game.dash_time <= 0:
						game._dash(direction.rotated(PI / 2))
				if game.hp < 55 and game.flasks > 0:
					game._use_flask()
				game._process(1.0 / 60)
				room_ticks += 1
				ticks += 1
				if ticks % 120 == 0:
					await game.get_tree().process_frame
			if room_ticks >= 5400:
				print("COMBAT_STALL: player=", game.player, " enemies=", game.enemies)
			assert(game.state != "dead", "Autonomous combat died in room %d" % (room + 1))
			assert(room_ticks < 5400, "Combat stalled in room %d" % (room + 1))
			if game.state == "reward":
				var selected = 0
				for i in game.offered.size():
					if game.RELICS[game.offered[i]].id in ["edge", "vital", "leech"]:
						selected = i
						break
				game._choose_relic(selected)
		print("COMBAT_ROOM_PASS: %d kills=%d hp=%.1f level=%d" % [room + 1, game.total_kills, game.hp, game.level])
	assert(game.state == "victory" and game.total_kills >= 25)
	print("COMBAT_RUN_PASS: full seven-room run won using actual movement, attack timers, damage, dodge and consumables; no forced enemy deaths")
	game._close_overlay()
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	game.get_tree().quit(0)
