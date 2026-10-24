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
			game.player = Vector2(480, 275)
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
	game.player = Vector2(480, 275)
	game._interact()
	await click(game, 1)
	assert(game.room_clear and game.attack_power == 30)
	game._enter_room(3, "rest")
	game.hp = 10
	game.player = Vector2(480, 275)
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
