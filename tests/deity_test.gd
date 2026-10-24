extends RefCounted

static func enable(game, ids: Array) -> void:
	game.augments.clear()
	game.augment_levels.clear()
	game.active_augments.clear()
	game.core_slots.clear()
	for id in ids:
		var item: Dictionary = game.Augments.find(game.augment_data, id)
		assert(not item.is_empty(), id)
		game.augments[id] = 0
		game.augment_levels[id] = 1
		game.active_augments[id] = true
		var slot: String = game.Augments.slot(item)
		if not slot.is_empty():
			game.core_slots[slot] = id
	game.tag_counts = game.Augments.counts(game.augment_data, game.augments)
	game.deity.recompute()

static func target(game, element: String = "무속성", offset: Vector2 = Vector2(50, 0)) -> Dictionary:
	game.enemies.clear()
	var enemy: Dictionary = game._spawn_enemy("brute", game.player + offset)
	enemy.pos = game.player + offset
	enemy.hp = 100000.0
	enemy.max_hp = enemy.hp
	enemy.defense = 0.0
	enemy.element = element
	return enemy

static func legendary_matrix(game) -> void:
	var d = game.deity
	game._start_run()
	var enemy = target(game)
	enable(game, ["N02", "N06", "N08", "N-L"])
	d.add_status(enemy, "rupture")
	d.heavy_procs(enemy, 100, true)
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 50.6))
	game._start_run()
	enemy = target(game)
	enable(game, ["I02", "I06", "I07", "I-L"])
	d.add_status(enemy, "chill", 6, false)
	d.heavy_procs(enemy, 40, false)
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 44) and d.stacks(enemy, "chill") == 0)
	assert(not game.elemental.active(enemy, "빙결"))
	game._start_run()
	enemy = target(game)
	enable(game, ["W02", "W05", "W07", "W-L", "D07", "D14"])
	enemy.water_knock = true
	d.add_status(enemy, "chill")
	d.timers.D14 = d.clock + 3
	d.wall_hit(enemy)
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 63.36))
	game._start_run()
	enemy = target(game)
	enable(game, ["G03", "G07", "G08", "G-L"])
	d.add_status(enemy, "spore", 5)
	d.spawn_seed(enemy.pos)
	d.tick(2.01)
	assert(d.seeds.size() == 1 and d.seeds[0].generated)
	d.tick(2.01)
	assert(d.seeds.is_empty())
	game._start_run()
	enable(game, ["A01", "A06", "A08", "A-L"])
	d.dash_start()
	d.dash_start()
	assert(is_equal_approx(d.attack_speed(), 1.4) and d.timers.A_legend > d.clock)
	game._start_run()
	enemy = target(game)
	enable(game, ["L01", "L05", "L07", "L-L"])
	for i in 5:
		var other: Dictionary = game._spawn_enemy("crawler", enemy.pos + Vector2(20 + i * 10, 0))
		other.pos = enemy.pos + Vector2(20 + i * 10, 0)
		other.hp = 1000.0
		other.max_hp = 1000.0
		other.defense = 0
	d.add_status(enemy, "charge", 3)
	var chained = 0
	for other in game.enemies:
		if other != enemy and other.hp < other.max_hp:
			chained += 1
			assert(is_equal_approx(other.max_hp - other.hp, 10.56) and d.stacks(other, "charge") == 0)
	assert(chained == 4)
	game._start_run()
	enemy = target(game)
	enable(game, ["H03", "H06", "H11", "H-L"])
	game.crit_chance = 0
	for i in 3:
		d.direct(enemy, "skill", 48, d.begin_action("skill"), true)
	assert(d.jobs.size() == 4)
	game._start_run()
	enemy = target(game)
	enable(game, ["W01", "W02", "W03", "W04", "W05", "W06"])
	d.add_status(enemy, "wave")
	d.blast(enemy.pos, 10, "물")
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 13.5))
	var before: float = enemy.hp
	d.deal(enemy, 10, "물")
	assert(is_equal_approx(before - enemy.hp, 11))
	game._start_run()
	enemy = target(game)
	enable(game, ["A01", "A05", "A07", "F01", "F05", "W10", "L06", "Q12"])
	for id in game.augments:
		game.augments[id] = 2
		game.augment_levels[id] = 5
	var multiplier = 1.45 * 1.4
	d.last_dash = d.clock
	assert(is_equal_approx(d.attack_speed(), 1 + 0.1 * multiplier))
	assert(is_equal_approx(d.speed() / game.move_speed, 1 + 0.3 * multiplier))
	assert(is_equal_approx(d.currency_factor(), 1 + 0.15 * multiplier))
	d.add_status(enemy, "burn")
	assert(is_equal_approx(d.statuses(enemy).burn.until - d.clock, 4 + 2 * multiplier))
	d.end_action("skill", {}, 0)
	game.dash_cd = 1
	d.dash_start()
	assert(game.dash_cd == 0, "scaled Q12 must clamp at 100% and work on a miss")
	print("DEITY_PASS: all ten legendary mechanisms, AoE-only water myth, scaled utility fields and zero-hit Q12")

static func fixture(game, ids: Array) -> Dictionary:
	game._start_run()
	game.crit_chance = 0
	var enemy = target(game)
	enable(game, ids)
	return enemy

static func neighbor(game, enemy: Dictionary) -> Dictionary:
	var other: Dictionary = game._spawn_enemy("crawler", enemy.pos + Vector2(30, 0))
	other.pos = enemy.pos + Vector2(30, 0)
	other.hp = 10000.0
	other.max_hp = other.hp
	other.defense = 0
	return other

static func duo_matrix(game) -> void:
	var d = game.deity
	var enemy = fixture(game, ["F06", "F07", "D01"])
	d.add_status(enemy, "burn", 8)
	d.add_status(enemy, "chill")
	d.heavy_procs(enemy, 0, false)
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 61.6))
	enemy = fixture(game, ["D02"])
	d.add_status(enemy, "burn")
	d.add_status(enemy, "wave")
	d.heavy_procs(enemy, 0, false)
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 20))
	enemy = fixture(game, ["D03"])
	d.zone("fire", game.player, 2, 1, 0, "불")
	d.shield(20, 3)
	assert(is_equal_approx(game.hero.shield, 28))
	enemy = fixture(game, ["D04"])
	d.add_status(enemy, "burn")
	d.spawn_seed(enemy.pos)
	d.explode_seed(d.seeds.pop_front())
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 15))
	enemy = fixture(game, ["A03", "F04", "D05"])
	d.zone("fire", enemy.pos, 2, 1, 0, "불")
	d.direct(enemy, "skill", 0, d.begin_action("skill"), true)
	assert(d.zones.is_empty() and is_equal_approx(enemy.max_hp - enemy.hp, 36))
	enemy = fixture(game, ["D06"])
	d.add_status(enemy, "burn")
	d.add_status(enemy, "charge", 3)
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 22) and d.stacks(enemy, "burn") == 0)
	enemy = fixture(game, ["W05", "D07"])
	enemy.water_knock = true
	d.add_status(enemy, "chill")
	d.wall_hit(enemy)
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 25.6))
	enemy = fixture(game, ["D08"])
	d.shield(10, 3)
	assert(d.stacks(enemy, "chill") == 2)
	enemy = fixture(game, ["D09"])
	d.add_status(enemy, "spore")
	d.add_status(enemy, "chill")
	d.tick(4)
	assert(is_equal_approx(d.statuses(enemy).spore.until, 7))
	d.tick(2.9)
	assert(d.stacks(enemy, "spore") == 1)
	d.tick(0.2)
	assert(d.stacks(enemy, "spore") == 0)
	enemy = fixture(game, ["D10"])
	d.add_status(enemy, "pressure")
	d.heavy_procs(enemy, 0, false)
	assert(d.stacks(enemy, "chill") == 2)
	enemy = fixture(game, ["L05", "D11"])
	var other = neighbor(game, enemy)
	d.add_status(enemy, "chill")
	d.add_status(enemy, "charge", 3)
	assert(is_equal_approx(other.max_hp - other.hp, 8.4))
	enemy = fixture(game, ["D12"])
	d.add_status(enemy, "wave")
	d.heavy_procs(enemy, 0, false)
	assert(is_equal_approx(game.hero.shield, 3))
	enemy = fixture(game, ["D13"])
	game.hp = 50
	d.add_status(enemy, "wave")
	d.spawn_seed(enemy.pos)
	d.explode_seed(d.seeds.pop_front())
	assert(is_equal_approx(game.hp, 51.1))
	enemy = fixture(game, ["L05", "D15"])
	for i in 4:
		neighbor(game, enemy)
	d.add_status(enemy, "wave")
	d.add_status(enemy, "charge", 3)
	var hit_count = 0
	for unit in game.enemies:
		if unit.hp < unit.max_hp:
			hit_count += 1
	assert(hit_count == 5)
	enemy = fixture(game, ["D16"])
	d.shield(1, 3)
	d.add_status(enemy, "spore", 5)
	d.direct(enemy, "heavy", 40, d.begin_action("heavy"), true)
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 48))
	enemy = fixture(game, ["D17"])
	d.add_status(enemy, "pressure")
	d.add_status(enemy, "crack")
	d.heavy_procs(enemy, 0, false)
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 24))
	enemy = fixture(game, ["D18"])
	d.add_status(enemy, "charge", 3)
	assert(is_equal_approx(game.hero.shield, 2))
	enemy = fixture(game, ["A03", "D19"])
	other = neighbor(game, enemy)
	d.direct(enemy, "skill", 0, d.begin_action("skill"), true)
	assert(d.stacks(enemy, "spore") == 1 and d.stacks(other, "spore") == 1)
	enemy = fixture(game, ["D20"])
	d.add_status(enemy, "spore", 5)
	d.add_status(enemy, "charge", 3)
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 16.2))
	enemy = fixture(game, ["D21"])
	d.dash_start()
	d.direct(enemy, "light", 0, d.begin_action("light"), true)
	d.direct(enemy, "light", 0, d.begin_action("light"), true)
	assert(d.stacks(enemy, "charge") == 1)
	enemy = fixture(game, ["D22"])
	d.add_status(enemy, "void")
	d.add_status(enemy, "order", 4)
	d.tick(0.81)
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 34))
	enemy = fixture(game, ["F01", "F05"])
	d.zone("fire", enemy.pos, 2, 1, 10, "불")
	enable(game, ["W01"])
	d.tick(1)
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 11))
	print("DEITY_PASS: D01-D22 triggered with exact damage/status/shield/heal/count assertions; D14 in wall matrix; generated damage snapshot")

static func run(game) -> void:
	game.set_process(false)
	game.rng.seed = 429
	game.meta_level = 0
	game._start_run()
	game.mouse_aim = false
	game.crit_chance = 0
	assert(game.augment_data.size() == 152)
	var d = game.deity
	game.IntegrationTests.reaction_tests()
	legendary_matrix(game)
	duo_matrix(game)
	game._start_run()
	game.crit_chance = 0
	enable(game, ["F01", "W02", "A03"])
	assert(d.element_for("light") == "불" and d.element_for("heavy") == "물" and d.element_for("skill") == "바람")
	var enemy = target(game)
	game.facing = Vector2.RIGHT
	game.attack_cd = 0
	game._begin_action("light")
	game._tick_strike(0.05)
	assert(d.stacks(enemy, "burn") == 1)
	assert(is_equal_approx(enemy.max_hp - enemy.hp, 22))
	game.pending_strike.clear()
	game.heavy_cd = 0
	var before: float = enemy.hp
	game._begin_action("heavy")
	game._tick_strike(0.29)
	assert(enemy.hp == before)
	game._tick_strike(0.02)
	assert(d.stacks(enemy, "wave") == 1 and enemy.hp < before and game.heavy_cd == 0.85)
	game.skill_cd = 0
	game._begin_action("skill")
	game._tick_strike(0.13)
	assert(game.skill_cd == game.skill_duration and enemy.hp < before)
	assert(game.hero.element == "무속성")
	print("DEITY_PASS: independent light/fire heavy/water skill/wind; real windups and cooldowns")

	game._start_run()
	for id in ["F01", "F05", "F06", "F08"]:
		var ok: bool = game._apply_augment(id, 0)
		assert(ok)
	assert(d.faith("F", 4) and d.equipped == "F")
	var replaced: bool = game._apply_augment("W01", 0)
	assert(replaced and not game.augments.has("F01"))
	assert(not game.active_augments.F05 and not d.faith("F", 4) and d.equipped.is_empty())
	var restored: bool = game._apply_augment("F02", 0)
	assert(restored and game.active_augments.F05 and d.faith("F", 4))
	assert(game.registered_deities.size() == 2)
	print("DEITY_PASS: core replacement removes faith, dormancy and power; restoration reactivates")

	game._start_run()
	game.crit_chance = 0
	enemy = target(game, "물")
	enable(game, ["F01"])
	d.direct(enemy, "light", 20, d.begin_action("light"), true)
	before = enemy.hp
	d.deal(enemy, 20, "불")
	assert(is_equal_approx(before - enemy.hp, 20), "augment damage must not vaporize")
	assert(d.stacks(enemy, "burn") == 1)
	assert(enemy.element == "물")
	d.tick(1)
	assert(is_equal_approx(before - enemy.hp, 21.6))
	d.add_status(enemy, "burn", 10)
	assert(d.stacks(enemy, "burn") == 5)
	enable(game, ["F01", "F06"])
	d.add_status(enemy, "burn", 10)
	assert(d.stacks(enemy, "burn") == 8)
	d.add_status(enemy, "chill", 6)
	assert(is_equal_approx(d.enemy_movement(enemy), 0.7))
	enemy.cc_immune = true
	game.elemental.status(enemy, "동토", 4)
	assert(game.elemental.movement(enemy) * d.enemy_movement(enemy) >= 0.8 - 0.00001)
	game.elemental.control(enemy, "빙결", 2)
	assert(game.elemental.action_speed(enemy) == 1)
	print("DEITY_PASS: direct-only reactions, burn caps/ticks/refresh, native independence, boss CC and slow cap")

	game._start_run()
	enemy = target(game)
	enable(game, ["L01", "L05", "L07", "L10", "L-L", "D18"])
	for i in 3:
		d.add_status(enemy, "charge")
	assert(d.stacks(enemy, "charge") == 0 and enemy.hp < enemy.max_hp)
	assert(game.hero.shield > 0)
	enable(game, ["H01", "H06", "H08", "H09", "H10", "D22"])
	game.skill_cd = 5
	d.add_status(enemy, "void")
	for i in 4:
		d.add_status(enemy, "order")
	assert(d.stacks(enemy, "order") == 0 and game.skill_cd == 4.6 and d.jobs.size() == 1)
	before = enemy.hp
	d.tick(0.81)
	assert(enemy.hp < before)
	enable(game, ["G03", "G07", "G08", "G-L"])
	for i in 6:
		d.spawn_seed(enemy.pos)
	assert(d.seeds.size() == 5)
	d.tick(2.1)
	assert(d.seeds.size() <= 1)
	print("DEITY_PASS: charges, no-rechain legendary, order reductions, delayed duo, seed caps and recursion bound")

	game._start_run()
	enemy = target(game)
	enable(game, ["F01", "F02", "F03", "F04", "F05", "F06", "F07", "F08", "F-L", "D01"])
	d.add_status(enemy, "burn", 8)
	d.add_status(enemy, "chill")
	d.heavy_procs(enemy, 40, false)
	assert(d.stacks(enemy, "burn") == 0 and d.zones.size() == 1)
	enable(game, ["Q01", "Q07", "Q11", "Q-L"])
	d.jobs.clear()
	d.shadow(enemy.pos, 10, 0.8, 120, {}, true)
	assert(d.jobs.size() == 2 and is_equal_approx(d.jobs[1].damage / d.jobs[0].damage, 0.7))
	enable(game, ["E04", "E06", "E09", "E-L"])
	game._units()
	d.shield(9999, 3)
	assert(game.hero.shield == game.max_hp * 0.5)
	d.before_hurt(999)
	game.elemental.absorb(game.hero, 999)
	before = enemy.hp
	d.after_shield_damage(999)
	assert(enemy.hp < before)
	print("DEITY_PASS: fire consume/phoenix, quantum second hit, shield cap and enemy-break legendary")

	for code in d.CODES:
		game._start_run()
		enemy = target(game)
		var ids: Array = []
		for i in range(1, 7):
			ids.append("%s%02d" % [code, i])
		enable(game, ids)
		game.room_clear = true
		d.equipped = ""
		game._show_inventory()
		await game.get_tree().process_frame
		await game.get_tree().process_frame
		game.buttons[0].grab_focus()
		await game.get_tree().process_frame
		await game.IntegrationTests.click(game, 0)
		assert(d.equipped == code)
		game._resume_room()
		game.room_clear = false
		d.gauge = 100
		game.pointer_position = game._project(enemy.pos) + game.view_offset
		d.use_power()
		assert(d.gauge == 0)
		d.tick(6.01)
		var expected: float = {"N": 0.0, "F": 216.48, "I": 77.0, "W": 110.0, "E": 66.0, "G": 52.8, "A": 66.0, "L": 154.0, "Q": 143.0, "H": 103.4}[code]
		assert(absf(enemy.max_hp - enemy.hp - expected) < 0.01, "%s power expected %f got %f" % [code, expected, enemy.max_hp - enemy.hp])
		assert(d.gauge <= 13, "powers cannot generate hit gauge")
	print("DEITY_PASS: all ten powers execute, bounded schedules, no power-hit gauge recursion")

	for i in 10:
		game._start_run()
		game.room_clear = true
		var old_max: float = game.max_hp
		game._show_contracts()
		await game.get_tree().process_frame
		await game.get_tree().process_frame
		game.buttons[i].grab_focus()
		await game.get_tree().process_frame
		await game.IntegrationTests.click(game, i)
		assert(d.contracts.size() == 1, "contract click %d rect=%s" % [i, game.buttons[i].get_global_rect()])
		game._resume_room()
		match i:
			0: assert(is_equal_approx(d.attack_speed(), 0.8))
			1:
				enemy = target(game)
				game.crit_chance = 0
				d.direct(enemy, "heavy", 40, d.begin_action("heavy"), true)
				assert(is_equal_approx(enemy.max_hp - enemy.hp, 28))
			2: assert(is_equal_approx(d.skill_cooldown_factor(), 1.4))
			3: assert(is_equal_approx(d.speed(), game.move_speed * 0.85))
			4: assert(is_equal_approx(d.incoming_factor(), 1.2))
			5: assert(is_equal_approx(d.heal_factor(), 0.4))
			6: assert(is_equal_approx(d.currency_factor(), 0.5))
			7: assert(is_equal_approx(game.max_hp, old_max * 0.8))
			8:
				d.add_gauge(100)
				assert(is_equal_approx(d.gauge, 30))
			9:
				game._enter_room(1, "battle")
				assert(game.enemies.size() == 6 and game.enemies.back().elite)
		for j in 3:
			d.last_room_combat = true
			d.complete_room()
		assert(d.contracts.is_empty() and d.reward_has("R%02d" % (i + 1)))
		if i == 7:
			assert(is_equal_approx(game.max_hp, old_max))
		if i == 9:
			var revived: bool = d.revive()
			var repeated: bool = d.revive()
			assert(revived and not repeated)
	game._start_run()
	game.room_clear = true
	d.accept_contract(0)
	d.accept_contract(1)
	d.accept_contract(2)
	assert(d.contracts.size() == 2)
	game._start_run()
	enable(game, ["G02", "G12"])
	game.augment_levels["G12"] = 5
	for i in 4:
		d.last_room_combat = true
		d.complete_room()
	assert(game.augment_levels.G02 == 2 and game.augment_xp.G02 == 0 and game.tag_counts["풀"] == 2)
	game._start_run()
	game.room_clear = true
	d.accept_contract(7)
	game._gain_experience(45)
	d.last_room_combat = true
	for i in 3:
		d.last_room_combat = true
		d.complete_room()
	assert(is_equal_approx(game.max_hp, 115))
	print("DEITY_PASS: all ten contracts, three-room completion, max two, C08 ratios, one revive")

	game._start_run()
	game._offer_relics()
	assert(game.offered.size() == 3 and not game.reward_ready)
	game._tick_reward_intro(1.01)
	assert(not game.reward_ready and game.reward_neutral_time < 0.02)
	game._offer_relics(false)
	var owned: int = game.augments.size()
	for i in 30:
		game._choose_relic(0)
		game._reroll_relics()
		game._tick_reward_intro(0.02)
	assert(game.augments.size() == owned and game.rerolls == 1)
	Input.action_press("slash")
	game._tick_reward_intro(2)
	assert(not game.reward_ready)
	Input.action_release("slash")
	game._tick_reward_intro(0.24)
	assert(not game.reward_ready)
	game._tick_reward_intro(0.02)
	assert(game.reward_ready)
	game._choose_relic(0)
	assert(game.augments.size() == owned + 1 and game.state == "playing")
	game._offer_relics()
	game._tick_reward_intro(2)
	game._tick_reward_intro(0.26)
	game._reroll_relics()
	assert(not game.reward_ready and game.rerolls == 0)
	game._tick_reward_intro(2)
	game._tick_reward_intro(0.26)
	game._defer_reward()
	game._offer_relics(false)
	assert(not game.reward_ready)
	await game.get_tree().process_frame
	for pressed in [true, false]:
		var key = InputEventKey.new()
		key.physical_keycode = KEY_1
		key.keycode = KEY_1
		key.pressed = pressed
		game.get_viewport().push_input(key, true)
		await game.get_tree().process_frame
		if pressed:
			game._tick_reward_intro(2)
			assert(not game.reward_ready and game.state == "reward")
	game._tick_reward_intro(0.26)
	assert(game.reward_ready)
	await game.IntegrationTests.key(game, KEY_1)
	assert(game.state == "playing")
	game._offer_relics()
	await game.get_tree().process_frame
	var button: Button = game.buttons[0]
	var mouse = InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.position = button.get_global_rect().get_center()
	mouse.pressed = true
	game.get_viewport().push_input(mouse, true)
	await game.get_tree().process_frame
	game._tick_reward_intro(2)
	assert(not game.reward_ready and game.state == "reward")
	mouse = mouse.duplicate()
	mouse.pressed = false
	game.get_viewport().push_input(mouse, true)
	await game.get_tree().process_frame
	game._tick_reward_intro(0.26)
	assert(game.reward_ready)
	await game.IntegrationTests.click(game, 0)
	assert(game.state == "playing")
	for keycode in [KEY_2, KEY_3, KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_J, KEY_K, KEY_Q, KEY_R]:
		game._offer_relics()
		for pressed in [true, false]:
			var input = InputEventKey.new()
			input.physical_keycode = keycode
			input.keycode = keycode
			input.pressed = pressed
			game.get_viewport().push_input(input, true)
			await game.get_tree().process_frame
			if pressed:
				game._tick_reward_intro(2)
				assert(not game.reward_ready and game.state == "reward")
		game._tick_reward_intro(0.26)
		assert(game.reward_ready)
		game._defer_reward()
	print("DEITY_PASS: early direct/mouse/key paths blocked, held attack release barrier, reroll/reopen relock")
	await game.IntegrationTests.finish(game, "DEITY_TEST_PASS")
