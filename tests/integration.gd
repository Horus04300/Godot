extends RefCounted

const Augments = preload("res://scripts/augments.gd")
const Elements = preload("res://scripts/elements.gd")
const Maps = preload("res://scripts/forest_maps.gd")

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

static func finish(game: Node, marker: String) -> void:
	print(marker)
	game._close_overlay()
	await game.get_tree().process_frame
	await game.get_tree().process_frame
	game.get_tree().quit(0)

static func run(game: Node) -> void:
	game.set_process(false)
	await click(game, 4)
	assert(game.state == "settings")
	await key(game, KEY_ESCAPE)
	assert(game.state == "hub")
	game.meta_embers = 25
	game._show_hub()
	await click(game, 1)
	assert(game.meta_level == 1 and game.meta_embers == 0)
	await click(game, 2)
	assert(game.state == "help")
	await key(game, KEY_ESCAPE)
	assert(game.state == "hub")
	await click(game, 0)
	await key(game, KEY_ESCAPE)
	assert(game.state == "pause")
	await click(game, 3)
	assert(game.state == "settings")
	var slider: HSlider = game.overlay.find_child("master", true, false)
	assert(slider.has_focus())
	var old = slider.value
	await key(game, KEY_LEFT)
	assert(slider.value == old - 1 and is_equal_approx(game.sound.levels.master, slider.value / 100))
	await key(game, KEY_TAB)
	assert(game.overlay.find_child("music", true, false).has_focus())
	await key(game, KEY_RIGHT)
	await key(game, KEY_TAB)
	assert(game.overlay.find_child("effects", true, false).has_focus())
	await key(game, KEY_LEFT)
	await click(game, 0)
	assert(game.sound.last_rarity == 4)
	await click(game, 1)
	assert(game.muted and not game.sound.enabled)
	await click(game, 2)
	assert(game.state == "pause")
	print("UI_PASS: Esc pause > settings; keyboard master/music/effects sliders; preview; mute; close")
	await click(game, 1)
	assert(game.state == "inventory")
	assert(game.overlay.find_children("*", "GridContainer", true, false).is_empty())
	await click(game, 0)
	assert(game.state == "help")
	await key(game, KEY_ESCAPE)
	assert(game.state == "pause")
	await click(game, 0)
	await key(game, KEY_I)
	assert(game.state == "inventory")
	await key(game, KEY_ESCAPE)
	assert(game.state == "playing")
	await key(game, KEY_G)
	assert(game.state == "map")
	await click(game, 0)
	await key(game, KEY_V)
	assert(not game.effects_enabled)
	await key(game, KEY_T)
	assert(not game.mouse_aim)
	for selection in 3:
		game._start_run()
		game._offer_relics()
		assert(game.buttons.size() == 4)
		var id: String = game.offered[selection].id
		var rarity: int = game.offered[selection].rarity
		await click(game, selection)
		assert(game.augments.has(id) and game.augments[id] == rarity and game.room_clear)
	game._offer_relics()
	var previous: Array = game.offered.duplicate(true)
	await key(game, KEY_ESCAPE)
	assert(game.reward_deferred)
	game.player = game.ALTAR
	game._interact()
	assert(game.offered == previous)
	await click(game, 3)
	assert(game.rerolls == 0 and game.buttons[3].disabled and game.offered != previous)
	await key(game, KEY_2)
	assert(game.state == "playing" and game.room_clear)
	game.player = game.PORTAL
	game._interact()
	await click(game, 2)
	assert(game.state == "playing")
	game._interact()
	await click(game, 1)
	assert(game.depth == 1 and game.room_type == "elite")
	game._enter_room(3, "shop")
	game._show_shop()
	await click(game, 0)
	assert(game.state == "reward" and game.gold == 5)
	await click(game, 0)
	game._show_shop()
	assert(game.buttons[0].disabled)
	game.gold = 12
	game.hp = 5
	game._show_shop()
	await click(game, 1)
	assert(game.hp > 5 and game.gold == 0)
	await click(game, 2)
	assert(game.room_clear)
	game._enter_room(3, "rest")
	game._show_rest()
	game.hp = 5
	await click(game, 0)
	assert(game.hp > 5 and game.room_clear)
	game._show_rest()
	var old_attack: float = game.attack_power
	await click(game, 1)
	assert(game.attack_power == old_attack + 8)
	for choice in 3:
		game._enter_room(2, "battle")
		game.room_clear = true
		game._show_routes()
		await click(game, choice)
		assert(game.room_type == ["rest", "treasure", "shop"][choice])
		if choice == 1:
			game.player = game.ALTAR
			game._interact()
			await click(game, 0)
			assert(game.room_clear)
	game._enter_room(5, "battle")
	game._show_routes()
	await click(game, 0)
	assert(game.depth == 6 and game.room_type == "boss")
	game._enter_room(6, "boss")
	game.enemies[0].hp = 0
	game._collect_dead()
	assert(game.state == "victory")
	await click(game, 1)
	assert(game.state == "playing")
	game.hp = 1
	game.invulnerable = 0
	game._shoot(game.player, Vector2.ZERO, 0, 50)
	game._tick_projectiles(0.01)
	assert(game.state == "dead" and game.projectiles.is_empty())
	await click(game, 0)
	assert(game.state == "hub")
	game._start_run()
	game._show_pause()
	await click(game, 2)
	assert(game.state == "hub" and not game.run_active)
	print("UI_PASS: empty/read-only build, help, map, visual/aim toggles, all 3 choices, defer/reopen, reroll, routes, shop, rest, victory, retry, projectile death, hub")
	await finish(game, "UI_TEST_PASS")

static func actor(engine: RefCounted, element: String, side: int, pos: Vector2 = Vector2.ZERO) -> Dictionary:
	var unit = {"hp": 1000.0, "pos": pos, "knock": Vector2.ZERO}
	engine.prepare(unit, element, side)
	return unit

static func total(events: Array, unit: Dictionary) -> float:
	var result = 0.0
	for event in events:
		if event.target.uid == unit.uid:
			result += event.damage
	return result

static func reaction_tests() -> void:
	var outcome: Array = []
	var rows = [
		["불", "얼음", "융해"], ["불", "물", "증발"], ["불", "땅", "용암"], ["불", "풀", "연소"],
		["불", "바람", "확산·불"], ["불", "번개", "과부하"], ["얼음", "물", "빙결"], ["얼음", "땅", "동토"],
		["얼음", "풀", "동해"], ["얼음", "바람", "확산·얼음"], ["얼음", "번개", "초전도"], ["물", "땅", "진창"],
		["물", "풀", "개화"], ["물", "바람", "확산·물"], ["물", "번개", "감전"], ["땅", "풀", "생장"],
		["땅", "바람", "모래폭풍"], ["땅", "번개", "접지"], ["풀", "바람", "확산·풀"],
		["풀", "번개", "활성"], ["바람", "번개", "확산·번개"]]
	for row in rows:
		for reverse in 2:
			var attack: String = row[reverse]
			var target_element: String = row[1 - reverse]
			var engine = Elements.new()
			var source = actor(engine, attack, reverse)
			var target = actor(engine, target_element, 1 - reverse)
			var splash = actor(engine, target_element, 1 - reverse, Vector2(50, 0))
			var events = engine.hit(source, target, 100, attack, [source, target, splash])
			assert(events[0].reaction == row[2], str(row))
			assert(target.element == target_element)
			var expected = 100.0
			if row[2] in ["융해", "증발"]:
				expected = 150
			elif row[2] == "과부하":
				expected = 140
				assert(total(events, splash) == 40)
			elif row[2] == "초전도":
				expected = 120
			elif row[2] == "접지":
				expected = 125
				assert(source.shield == 30)
			elif row[2].begins_with("확산"):
				assert(total(events, splash) == 30)
			assert(is_equal_approx(total(events, target), expected))
			var repeat = engine.hit(source, target, 100, attack, [source, target, splash])
			if row[2] in ["융해", "증발"]:
				assert(total(repeat, target) == 150)
			else:
				assert(repeat[0].reaction.is_empty())
				assert(repeat.size() == 1)
	for attack in Elements.NAMES:
		for native in Elements.NAMES:
			if attack == "무속성" or native == "무속성" or attack == native or ((attack in ["양자", "허수"] or native in ["양자", "허수"]) and not (attack in ["양자", "허수"] and native in ["양자", "허수"] and attack != native)):
				assert(Elements.reaction(attack, native).is_empty())
	assert(Elements.reaction("양자", "허수") == "붕괴")
	assert(Elements.reaction("허수", "양자") == "역설")
	for pair in [["양자", "허수"], ["허수", "양자"]]:
		var engine = Elements.new()
		var source = actor(engine, pair[0], 0)
		var target = actor(engine, pair[1], 1)
		outcome = engine.hit(source, target, 100, pair[0], [source, target])
		assert(total(outcome, target) == 150)
	var engine = Elements.new()
	var source = actor(engine, "불", 0)
	var target = actor(engine, "풀", 1)
	engine.hit(source, target, 100, "불", [source, target])
	outcome = engine.tick(1, [source, target])
	assert(total(outcome, target) == 15)
	engine.hit(source, target, 200, "불", [source, target])
	assert(target.status.size() == 1)
	outcome = engine.tick(4, [source, target])
	assert(total(outcome, target) == 120)
	assert(target.status.is_empty())
	engine.reset()
	source = actor(engine, "번개", 0)
	target = actor(engine, "물", 1)
	var nearby = [target]
	for i in 3:
		nearby.append(actor(engine, "물", 1, Vector2(20 + i * 20, 0)))
	engine.hit(source, target, 100, "번개", [source] + nearby)
	outcome = engine.tick(3, [source] + nearby)
	assert(outcome.size() == 9)
	engine.reset()
	source = actor(engine, "불", 0)
	target = actor(engine, "땅", 1)
	engine.hit(source, target, 100, "불", [source, target])
	assert(engine.zones.size() == 1)
	outcome = engine.tick(3, [source, target])
	assert(total(outcome, target) == 45)
	engine.hit(source, target, 200, "불", [source, target])
	var distant = actor(engine, "땅", 1, Vector2(500, 0))
	engine.hit(source, distant, 100, "불", [source, distant])
	assert(engine.zones.size() == 1 and engine.zones[0].pos == distant.pos)
	engine.reset()
	source = actor(engine, "물", 0)
	target = actor(engine, "풀", 1)
	for i in 4:
		var seed_target = actor(engine, "풀", 1)
		var events = engine.hit(source, seed_target, 100, "물", [source, seed_target, target])
		if i == 3:
			assert(total(events, target) == 50)
	assert(engine.seeds.size() == 3)
	outcome = engine.tick(2, [source, target])
	assert(total(outcome, target) == 150)
	engine.reset()
	target = actor(engine, "물", 1)
	engine.control(target, "빙결", 2)
	assert(engine.movement(target) == 0 and engine.action_speed(target) == 0)
	engine.tick(2, [target])
	engine.control(target, "생장", 1.5)
	assert(not engine.active(target, "생장") and engine.movement(target) == 0.8)
	engine.tick(3, [target])
	engine.control(target, "생장", 1.5)
	assert(engine.movement(target) == 0 and engine.action_speed(target) == 1)
	engine.status(target, "동해", 4)
	assert(engine.heal_factor(target) == 0.7 and engine.action_speed(target) == 0.8)
	engine.status(target, "동토", 4)
	engine.status(target, "진창", 4)
	engine.tick(1.5, [target])
	assert(engine.movement(target) == 0.6)
	engine.grant_shield(target, 30, 3)
	var overflow: float = engine.absorb(target, 10)
	assert(overflow == 0 and target.shield == 20)
	engine.grant_shield(target, 15, 3)
	assert(target.shield == 20)
	engine.tick(3, [target])
	overflow = engine.absorb(target, 10)
	assert(overflow == 10)
	target.cc_immune = true
	engine.control(target, "빙결", 2)
	assert(not engine.active(target, "빙결") and engine.movement(target) == 0.8)
	target.slow_immune = true
	assert(engine.movement(target) == 1)
	engine.reset()
	source = actor(engine, "번개", 0)
	target = actor(engine, "풀", 1)
	outcome = engine.hit(source, target, 100, "번개", [source, target])
	assert(total(outcome, target) == 100)
	outcome = engine.hit(source, target, 100, "번개", [source, target])
	assert(total(outcome, target) == 120)
	engine.reset()
	source = actor(engine, "얼음", 0)
	target = actor(engine, "번개", 1)
	target.defense = 100
	outcome = engine.hit(source, target, 100, "얼음", [source, target])
	assert(total(outcome, target) == 60)
	outcome = engine.hit(source, target, 100, "얼음", [source, target])
	assert(is_equal_approx(total(outcome, target), 100.0 / 1.8))
	engine.knock(target, Vector2.RIGHT, 100)
	var first_knock: Vector2 = target.knock
	engine.knock(target, Vector2.LEFT, 100)
	assert(target.knock == first_knock and engine.active(target, "제어저항"))
	engine.reset()
	source = actor(engine, "땅", 0)
	target = actor(engine, "바람", 1)
	engine.hit(source, target, 100, "땅", [source, target])
	var sand = engine.tick(1, [source, target])
	assert(total(sand, target) == 10 and engine.active(target, "모래"))
	engine.tick(3, [source, target])
	assert(engine.zones.is_empty() and not engine.active(target, "모래"))
	print("ELEMENT_PASS: all 21 general pairs in both directions; neutral/same/quantum isolation; quantum directions; multipliers, cooldowns, DoT refresh/ticks/chains, zone replacement, seeds cap, CC immunity, strongest slow, healing, shield, activation timing")

static func overhaul(game: Node) -> void:
	game.set_process(false)
	game.rng.seed = 239
	game._start_run()
	reaction_tests()
	var boundaries = [0.0, 45.0, 72.0, 88.0, 96.0, 99.0]
	for i in 6:
		assert(Augments.rarity_at(boundaries[i]) == i)
		assert(Augments.rarity_at(boundaries[i] + Augments.WEIGHTS[i] - 0.001) == i)
	assert(Augments.WEIGHTS.reduce(func(sum, value): return sum + value, 0) == 100)
	var distribution = [0, 0, 0, 0, 0, 0]
	for i in 100000:
		distribution[Augments.roll_rarity(game.rng)] += 1
	for i in 6:
		assert(absf(distribution[i] / 1000.0 - Augments.WEIGHTS[i]) < 0.7)
	for element in Augments.ELEMENTS:
		game._start_run()
		for i in 6:
			var acquired: bool = game._apply_augment(element + str(i), 0)
			assert(acquired)
			assert(game._tier(element) == Augments.tier(i + 1))
		assert(game.hero.element == element and game._skill_radius() >= 226)
		var pool = Augments.eligible(game.augment_data, game.augments, game.element_lock)
		assert(pool.size() == 6)
		for item in pool:
			assert(item.element == element and not game.augments.has(item.id))
		var old = game.augments.size()
		game._offer_relics()
		for item in game.offered:
			assert(item.element == element)
		game._choose_relic(0)
		assert(game.augments.size() == old + 1)
	game._start_run()
	for i in 6:
		game._apply_augment("불" + str(i), 0)
	var first_damage: float = game._attack_damage(true)
	game.enemies.clear()
	var target: Dictionary = game._spawn_enemy("brute", game.player + Vector2(170, 0))
	target.hp = 10000
	target.defense = 0
	target.element = "얼음"
	game._resolve_strike(true, Vector2.RIGHT, false)
	assert(target.hp < 10000 - first_damage * 1.5)
	game.hero.element = "풀"
	game.invulnerable = 0
	var old_health: float = game.hp
	var enemy: Dictionary = game.enemies[0]
	enemy.element = "불"
	game._incoming(enemy, 10)
	assert(game.hp < old_health and not game.hero.status.is_empty())
	var after_hit: float = game.hp
	game._apply_element_events(game.elemental.tick(1, game._units()))
	assert(game.hp < after_hit)
	print("AUGMENT_PASS: 45/27/16/8/3/1 boundaries and 100000 rolls; all 10 element-locked pools, unique acquisition, 2/3/4/6 tiers and actual transformed skill; enemy-to-player reactions and periodic damage")
	for parity in 2:
		game._start_run()
		for i in 6:
			game._apply_augment("불" + str(i * 2 + parity), 0)
		if parity == 0:
			assert(game._tier("공격속도") == 4 and game._tier("속성공격") == 4 and game._tier("생존") == 4)
			assert(game.attack_interval < 0.3)
		else:
			assert(game._tier("물리공격") == 4 and game._tier("이동속도") == 4 and game._tier("기술") == 4)
			assert(game.move_speed > 176 and game.dash_duration < 1 and game.attack_range == 106)
		game.enemies.clear()
		var dummy: Dictionary = game._spawn_enemy("brute", game.player + Vector2(60, 0))
		dummy.hp = 10000
		dummy.defense = 0
		dummy.element = "무속성"
		var base: float = game._attack_damage(false)
		game.combo = 1
		game._resolve_strike(false, Vector2.RIGHT, false)
		assert(dummy.hp < 10000 - base)
		game.skill_cd = 0
		game._attack(true)
		game._tick_strike(0.08)
		assert(not game.second_burst.is_empty())
		if parity == 0:
			assert(game.hero.shield == 24)
	print("SYNERGY_PASS: all six stat tags reach 6 via distinct acquisitions; actual speed/range/cooldown, shockwave/extra hit, shield and delayed second burst")
	var signatures: Array = []
	game._start_run()
	for i in 10:
		if i > 0:
			game._enter_room(i % 6, "battle")
		if i < 5:
			assert(game.room_layout not in signatures)
			signatures.append(game.room_layout)
		if i > 0:
			assert(game.room_layout != int(game.get_meta("previous_layout", -1)))
		game.set_meta("previous_layout", game.room_layout)
		var start = Vector2i((game.player - game.ARENA.position) / 32)
		for gate in [game.PORTAL, game.WEST_GATE, game.EAST_GATE, game.ALTAR]:
			var end = Vector2i((gate - game.ARENA.position) / 32)
			assert(not game.navigation.is_point_solid(end))
			assert(game.navigation.get_point_path(start, end).size() > 1)
		for enemy_unit in game.enemies:
			var end = Vector2i((enemy_unit.pos - game.ARENA.position) / 32)
			assert(not game.navigation.is_point_solid(end), "Enemy spawned outside navigable cell in layout %d at %s" % [game.room_layout, enemy_unit.pos])
			assert(game.navigation.get_point_path(start, end).size() > 1)
	print("MAP_PASS: all five layouts once per cycle, no adjacent repeat, gates/altar/all spawns connected through collision-derived navigation")
	var audio = game.sound
	var original_path: String = audio.settings_path
	audio.settings_path = "user://test_audio_overhaul.json"
	audio.settings_error = ""
	audio.set_level("master", 0.37)
	audio.set_level("music", 0.24)
	audio.set_level("effects", 0.61)
	audio.set_muted(true)
	var saved: bool = audio.save_settings()
	assert(saved)
	audio.set_level("music", 1)
	audio.load_settings()
	assert(is_equal_approx(audio.levels.music, 0.24) and not audio.enabled)
	assert(audio.music.stream is AudioStreamMP3 and audio.music.stream.loop)
	for i in 6:
		assert(audio.clips["rarity%d" % i].data.size() > 0)
		if i > 0:
			assert(audio.clips["rarity%d" % i].data.size() > audio.clips["rarity%d" % (i - 1)].data.size())
	DirAccess.remove_absolute(ProjectSettings.globalize_path(audio.settings_path))
	audio.settings_path = original_path
	var original_save: String = game.save_path
	game.save_path = "user://test_meta_overhaul.json"
	game.testing = false
	game.meta_embers = 123
	game.meta_level = 3
	game.best_depth = 7
	saved = game._save()
	assert(saved)
	game.meta_embers = 0
	game.meta_level = 0
	game._load_save()
	assert(game.meta_embers == 123 and game.meta_level == 3 and game.best_depth == 7)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(game.save_path))
	game.save_path = original_save
	game.testing = true
	print("AUDIO_PASS: MP3 loaded and looped, master/music/effects values plus mute persisted/reloaded, six distinct synthesized rarity clips")
	await finish(game, "OVERHAUL_TEST_PASS")

static func quarter_view(game: Node) -> void:
	game._start_run()
	game.set_process(false)
	game.player = game.ALTAR
	game.structures.clear()
	game.obstacles.clear()
	game.view_offset = Vector2(480, 300) - game._project(game.player)
	for pos in [game.ARENA.position, game.ARENA.end, game.player, game.WEST_GATE, game.EAST_GATE, game.PORTAL]:
		assert(game._unproject(game._project(pos)).distance_to(pos) < 0.001)
	for i in 8:
		game.enemies.clear()
		var screen_direction = Vector2.from_angle(i * TAU / 8)
		var direction: Vector2 = game._screen_movement(screen_direction)
		assert(game._project(direction).normalized().dot(screen_direction) > 0.999)
		var target: Vector2 = game.player + direction * 60
		var enemy: Dictionary = game._spawn_enemy("crawler", target)
		enemy.defense = 0
		var motion = InputEventMouseMotion.new()
		motion.position = game._project(target) + game.view_offset - Vector2(0, 32)
		game.get_viewport().push_input(motion, true)
		game.mouse_aim = true
		game._tick_player(0)
		assert(game.facing.dot(direction) > 0.999)
		game.attack_cd = 0
		game.combo = 0
		game.crit_chance = 0
		game.pending_strike.clear()
		var hp: float = enemy.hp
		game._attack(false)
		game._tick_strike(0.05)
		assert(enemy.hp == hp - game.attack_power)
	for pair in [[KEY_W, Vector2.UP], [KEY_D, Vector2.RIGHT], [KEY_S, Vector2.DOWN], [KEY_A, Vector2.LEFT]]:
		game.recoil = Vector2.ZERO
		game.mouse_aim = false
		var before: Vector2 = game.player
		var event = InputEventKey.new()
		event.physical_keycode = pair[0]
		event.pressed = true
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		game._tick_player(0.05)
		event = event.duplicate()
		event.pressed = false
		Input.parse_input_event(event)
		Input.flush_buffered_events()
		assert(game._project(game.player - before).normalized().dot(pair[1]) > 0.999)
	game.enemies.clear()
	game.pending_strike.clear()
	for i in 8:
		game.player = game.ALTAR
		game.dash_charges = 2
		var direction = Vector2.from_angle(i * TAU / 8)
		game._dash(game._screen_movement(direction))
		game._tick_player(0.05)
		assert(game._project(game.player - game.ALTAR).normalized().dot(direction) > 0.999)
	print("QUARTER_PASS: projected aiming/body picking and actual damage in eight directions; real WASD input and eight dodge directions")
	await finish(game, "QUARTER_TEST_PASS")

static func combat_run(game: Node) -> void:
	game.rng.seed = 1234
	game._start_run()
	game.mouse_aim = false
	game.set_process(false)
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
			while game.state == "playing" and not game.room_clear and room_ticks < 7200:
				var nearest: Dictionary = {}
				var distance = INF
				for enemy in game.enemies:
					if enemy.hp > 0 and enemy.pos.distance_to(game.player) < distance:
						nearest = enemy
						distance = enemy.pos.distance_to(game.player)
				if not nearest.is_empty():
					var direction: Vector2 = (nearest.pos - game.player).normalized()
					game.facing = direction
					if distance > 60 and game.dash_time <= 0 and game.elemental.movement(game.hero) > 0:
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
						game.player = game._move_actor(game.player, direction * game.move_speed / 60.0 * game.elemental.movement(game.hero), 12)
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
				if ticks % 240 == 0:
					await game.get_tree().process_frame
			assert(game.state != "dead", "Autonomous combat died in room %d" % (room + 1))
			assert(room_ticks < 7200, "Combat stalled in room %d" % (room + 1))
			if game.state == "reward":
				var selected = 0
				for i in game.offered.size():
					if game.offered[i].stat in ["물리공격", "생존", "기술"]:
						selected = i
						break
				game._choose_relic(selected)
		print("COMBAT_ROOM_PASS: %d kills=%d hp=%.1f level=%d" % [room + 1, game.total_kills, game.hp, game.level])
	assert(game.state == "victory" and game.total_kills >= 25)
	await finish(game, "COMBAT_RUN_PASS: seven rooms, real attacks/damage/reactions/dodge/consumables; no forced deaths or healing")

static func quit_test(game: Node) -> void:
	game.save_path = "user://test_quit_save.json"
	await game.get_tree().create_timer(0.25).timeout
	assert(game.sound.music.playing and game.sound.music.stream.get_length() > 0)
	if game.sound.enabled and game.sound.levels.master > 0 and game.sound.levels.music > 0:
		assert(game.sound.music.get_playback_position() > 0)
	print("BGM_START_PASS: playing=", game.sound.music.playing, " position=", game.sound.music.get_playback_position(), " length=", game.sound.music.stream.get_length())
	game._start_run()
	game.run_embers = 7
	game._show_hub()
	await click(game, 3)
	assert(game.quitting and not game.run_active)
	print("QUIT_BUTTON_PASS: actual hub quit click settles run and exits")
