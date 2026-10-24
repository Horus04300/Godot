extends Node2D

const Art = preload("res://scripts/pixel_art.gd")
const ForestArt = preload("res://scripts/forest_art.gd")
const Sound = preload("res://scripts/sound.gd")
const Augments = preload("res://scripts/augments.gd")
const Elements = preload("res://scripts/elements.gd")
const ForestMaps = preload("res://scripts/forest_maps.gd")
const RarityEffect = preload("res://scripts/rarity_effect.gd")
const IntegrationTests = preload("res://tests/integration.gd")
const GOLD = Color("#f4c675")
const PAPER = Color("#f7edd2")
const MINT = Color("#82cbb2")
const RED = Color("#ed927e")
const MUTED = Color("#a9c1b5")
const SAVE_PATH = "user://sanctuary_save.json"
const ARENA = Rect2(64, 128, 1376, 832)
const PORTAL = Vector2(752, 148)
const ALTAR = Vector2(752, 515)
const WEST_GATE = Vector2(88, 544)
const EAST_GATE = Vector2(1416, 544)
const GROUND_X = Vector2(0.86, 0.43)
const GROUND_Y = Vector2(-0.86, 0.43)
var augment_data = Augments.catalog()

var sprites: Dictionary
var font: SystemFont
var sound: Node
var ui: CanvasLayer
var overlay: Control
var buttons: Array[Button] = []
var state = "hub"
var previous_state = "playing"
var rng = RandomNumberGenerator.new()
var time = 0.0
var run_time = 0.0
var depth = 0
var room_type = "battle"
var room_clear = false
var room_kills = 0
var total_kills = 0
var run_embers = 0
var meta_embers = 0
var meta_level = 0
var best_depth = 0
var save_error = ""
var save_path = SAVE_PATH
var testing = false
var auto_capture = false
var capture_frames = 0
var capture_path = ""
var hp = 110.0
var max_hp = 110.0
var attack_power = 20.0
var move_speed = 176.0
var attack_range = 86.0
var attack_interval = 0.30
var crit_chance = 0.05
var flask_power = 45.0
var flasks = 2
var augments: Dictionary = {}
var element_lock = ""
var tag_counts: Dictionary = {}
var elemental = Elements.new()
var hero: Dictionary = {}
var room_layout = 0
var layout_bag: Array[int] = []
var room_paths: Array = []
var reward_ranks: Array[int] = []
var settings_return = "pause"
var build_return = "playing"
var second_burst: Dictionary = {}
var flat_bonuses: Dictionary = {}
var offered: Array = []
var player = Vector2(480, 350)
var facing = Vector2.UP
var last_move = Vector2.UP
var attack_cd = 0.0
var skill_cd = 0.0
var skill_duration = 5.5
var dash_cd = 0.0
var dash_duration = 1.0
var dash_time = 0.0
var dash_vector = Vector2.UP
var invulnerable = 0.0
var combo = 0
var combo_timer = 0.0
var hit_stop = 0.0
var shake = 0.0
var slash_time = 0.0
var slash_angle = 0.0
var slash_heavy = false
var enemies: Array = []
var projectiles: Array = []
var particles: Array = []
var numbers: Array = []
var hazards: Array = []
var pickups: Array = []
var obstacles: Array[Vector2] = []
var toast = ""
var toast_time = 0.0
var room_seed = 0
var mouse_aim = true
var muted = false
var run_settled = false
var run_active = false
var quitting = false
var camera_position = Vector2(752, 778)
var view_offset = Vector2.ZERO
var pending_strike: Dictionary = {}
var attack_buffer = 0.0
var dash_charges = 2
var dash_attack = false
var trails: Array = []
var impacts: Array = []
var slash_origin = Vector2.ZERO
var recoil = Vector2.ZERO
var gold = 0
var experience = 0
var level = 1
var rerolls = 1
var breakables: Array = []
var floor_marks: Array = []
var visited: Array[String] = []
var shop_purchased = false
var effects_enabled = true
var screen_flash = 0.0
var showcase = false
var structures: Array[Rect2] = []
var navigation = AStarGrid2D.new()
var reward_deferred = false
var forest_trees: Array[Vector2] = []
var pointer_position = Vector2(480, 300)

func _ready() -> void:
	rng.randomize()
	get_tree().auto_accept_quit = false
	sprites = Art.create_sprites()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Arial"])
	sound = Sound.new()
	add_child(sound)
	hero = {"hp": hp, "pos": player, "knock": Vector2.ZERO, "defense": 20.0}
	elemental.prepare(hero, "무속성", 0)
	ui = CanvasLayer.new()
	add_child(ui)
	var args = OS.get_cmdline_user_args()
	testing = "--self-test" in args
	testing = testing or "--ui-test" in args or "--overhaul-test" in args or "--combat-test" in args or "--quarter-test" in args
	if testing:
		sound.set_muted(true)
	if not testing:
		_load_save()
		sound.load_settings()
		muted = not sound.enabled
		sound.start_music()
	_setup_input()
	_show_hub()
	if "--self-test" in args:
		call_deferred("_self_test")
	if "--ui-test" in args:
		IntegrationTests.run.call_deferred(self)
	if "--overhaul-test" in args:
		IntegrationTests.overhaul.call_deferred(self)
	if "--combat-test" in args:
		IntegrationTests.combat_run.call_deferred(self)
	if "--quarter-test" in args:
		IntegrationTests.quarter_view.call_deferred(self)
	if "--quit-test" in args:
		IntegrationTests.quit_test.call_deferred(self)
	for arg in args:
		if arg.begins_with("--capture="):
			auto_capture = true
			capture_path = arg.trim_prefix("--capture=")
			_start_run()
	for arg in args:
		if arg == "--capture-scene=hub":
			_show_hub()
		elif arg == "--capture-scene=reward":
			_offer_relics()
		elif arg == "--capture-scene=boss":
			_enter_room(6, "boss")
			player = ALTAR + Vector2(0, 110)
			camera_position = player
			camera_position.y = minf(camera_position.y, ARENA.end.y - 240)
			mouse_aim = false
			facing = Vector2.UP
		elif arg == "--capture-scene=action":
			showcase = true
			player = Vector2(640, 520)
			camera_position = player
			facing = Vector2.RIGHT
			mouse_aim = false
			invulnerable = 0
			enemies.clear()
			_spawn_enemy("brute", player + Vector2(65, 0))
			_spawn_enemy("archer", player + Vector2(200, -110))
			_spawn_enemy("crawler", player + Vector2(80, 85))
			_apply_augment("불0", 2)
			_apply_augment("불1", 3)
			_apply_augment("불2", 4)
		elif arg == "--capture-scene=inventory":
			for i in 6:
				_apply_augment("불" + str(i), i)
			_show_inventory()
		elif arg == "--capture-scene=settings":
			_show_settings()
		elif arg == "--capture-scene=forest":
			player = ALTAR + Vector2(120, 120)
			camera_position = player
			invulnerable = 0
			mouse_aim = false
			facing = Vector2(-1, -1).normalized()
			for i in enemies.size():
				enemies[i].pos = _move_actor(player + Vector2(-260 + i * 170, -260), Vector2.ZERO, 20)
		elif arg == "--capture-scene=rest":
			_enter_room(3, "rest")
			player = ALTAR + Vector2(90, 90)
			camera_position = player
			mouse_aim = false
		elif arg == "--capture-scene=shop":
			_enter_room(3, "shop")
			player = ALTAR + Vector2(90, 90)
			camera_position = player
			mouse_aim = false
	for arg in args:
		if arg.begins_with("--capture-layout="):
			var index = int(arg.trim_prefix("--capture-layout="))
			assert(index >= 0 and index < 5)
			layout_bag.assign([index])
			_enter_room(0, "battle")
			player = ALTAR + Vector2(60, 70)
			camera_position = player
			invulnerable = 999
		if arg.begins_with("--capture-rarity="):
			var rank = int(arg.trim_prefix("--capture-rarity="))
			for i in offered.size():
				offered[i].rarity = (rank + i) % 6
			_offer_relics(false)

func _setup_input() -> void:
	var mapping = {
		"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
		"move_up": [KEY_W, KEY_UP], "move_down": [KEY_S, KEY_DOWN],
		"slash": [KEY_J], "skill": [KEY_Q, KEY_K], "dash": [KEY_SPACE],
		"interact": [KEY_E], "flask": [KEY_F]
	}
	for action in mapping:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for key in mapping[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action, event)
	for pair in [["slash", MOUSE_BUTTON_LEFT], ["skill", MOUSE_BUTTON_RIGHT]]:
		var event = InputEventMouseButton.new()
		event.button_index = pair[1]
		InputMap.action_add_event(pair[0], event)

func _load_save() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var file = FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		_report_save_error("저장 파일을 읽지 못했습니다. 이번 플레이는 계속할 수 있습니다.")
		return
	var parser = JSON.new()
	if parser.parse(file.get_as_text()) != OK:
		_report_save_error("저장 파일이 손상되었습니다. 기존 파일은 덮어쓰지 않습니다.")
		return
	var data = parser.data
	if not data is Dictionary:
		_report_save_error("저장 파일 형식이 올바르지 않습니다. 기존 파일은 보존됩니다.")
		return
	for key in ["embers", "level", "best"]:
		if not data.has(key) or not (data[key] is float or data[key] is int):
			_report_save_error("저장 데이터가 올바르지 않습니다. 기존 파일은 보존됩니다.")
			return
		if not is_finite(float(data[key])) or data[key] < 0 or float(data[key]) != floor(float(data[key])):
			_report_save_error("저장 수치가 올바르지 않습니다. 기존 파일은 보존됩니다.")
			return
	if data.level > 5 or data.best > 7:
		_report_save_error("저장 범위가 올바르지 않습니다. 기존 파일은 보존됩니다.")
		return
	meta_embers = int(data.embers)
	meta_level = int(data.level)
	best_depth = int(data.best)

func _report_save_error(message: String) -> void:
	save_error = message
	push_error(message)

func _save() -> bool:
	if testing:
		return true
	if not save_error.is_empty():
		return false
	var temp_path = save_path + ".tmp"
	var file = FileAccess.open(temp_path, FileAccess.WRITE)
	if file == null:
		_report_save_error("진행 상황을 저장하지 못했습니다. 저장 공간과 권한을 확인해 주세요.")
		return false
	file.store_string(JSON.stringify({"embers": meta_embers, "level": meta_level, "best": best_depth}))
	file.flush()
	var write_error = file.get_error()
	file.close()
	if write_error != OK:
		_report_save_error("저장 쓰기에 실패했습니다. 기존 저장 파일은 보존됩니다.")
		return false
	var result = DirAccess.rename_absolute(ProjectSettings.globalize_path(temp_path), ProjectSettings.globalize_path(save_path))
	if result != OK:
		_report_save_error("저장 파일 교체에 실패했습니다. 기존 저장 파일은 보존됩니다.")
		return false
	return true

func _start_run() -> void:
	hp = 110.0 + meta_level * 12.0
	max_hp = hp
	attack_power = 20.0 + meta_level * 2.0
	move_speed = 176.0
	attack_range = 86.0
	attack_interval = 0.30
	crit_chance = 0.05
	flask_power = 45.0
	flasks = 2
	skill_duration = 5.5
	dash_duration = 1.0
	augments.clear()
	tag_counts.clear()
	flat_bonuses.clear()
	element_lock = ""
	elemental.reset()
	hero = {"hp": hp, "pos": player, "knock": Vector2.ZERO, "defense": 20.0}
	elemental.prepare(hero, "무속성", 0)
	second_burst.clear()
	layout_bag.clear()
	total_kills = 0
	run_embers = 0
	run_time = 0.0
	run_settled = false
	run_active = true
	gold = 30
	experience = 0
	level = 1
	visited.clear()
	_enter_room(0, "battle")

func _enter_room(next_depth: int, kind: String) -> void:
	depth = next_depth
	room_type = kind
	room_clear = false
	room_kills = 0
	player = Vector2(752, 860)
	camera_position = player
	facing = Vector2.UP
	last_move = facing
	enemies.clear()
	projectiles.clear()
	hazards.clear()
	particles.clear()
	numbers.clear()
	pickups.clear()
	obstacles.clear()
	structures.clear()
	breakables.clear()
	floor_marks.clear()
	trails.clear()
	impacts.clear()
	pending_strike.clear()
	attack_buffer = 0
	rerolls = 1
	reward_deferred = false
	shop_purchased = false
	while visited.size() <= depth:
		visited.append("")
	visited[depth] = kind
	attack_cd = 0.2
	skill_cd = 0.0
	dash_cd = 0.0
	dash_time = 0.0
	dash_charges = 2
	invulnerable = 1.0
	combo = 0
	combo_timer = 0.0
	slash_time = 0.0
	hit_stop = 0.0
	shake = 0.0
	room_seed = rng.randi_range(0, 99999)
	elemental.clear_room()
	hero.status.clear()
	hero.shield = 0.0
	hero.shield_until = 0.0
	hero.control_until = 0.0
	hero.knock_until = 0.0
	hero.knock = Vector2.ZERO
	second_burst.clear()
	if layout_bag.is_empty():
		for i in 5:
			if i != room_layout:
				layout_bag.append(i)
		_shuffle(layout_bag)
		layout_bag.push_front(room_layout)
	room_layout = layout_bag.pop_back()
	var layout = ForestMaps.layout(room_layout)
	structures.assign(layout.rocks)
	obstacles.assign(layout.trees)
	room_paths = layout.paths
	_build_forest_border()
	_close_overlay()
	state = "playing"
	if kind == "battle" or kind == "elite":
		var count = 4 + mini(depth, 4)
		for i in count:
			var enemy_kind = "crawler"
			if i % 3 == 1 and depth > 0:
				enemy_kind = "archer"
			if i % 4 == 3 and depth > 1:
				enemy_kind = "brute"
			_spawn_enemy(enemy_kind, Vector2(420 + i * 157 % 690, 430 + (i % 3) * 112), kind == "elite")
	elif kind == "boss":
		_spawn_enemy("boss", ALTAR)
	for i in 12:
		var pos = Vector2(165 + (i * 131 + depth * 57) % 1150, 260 + (i * 163) % 590)
		var inside_wall = false
		for structure in structures:
			inside_wall = inside_wall or structure.grow(25).has_point(pos)
		for obstacle in obstacles:
			inside_wall = inside_wall or obstacle.distance_to(pos) < 40
		if not inside_wall and pos.distance_to(player) > 80 and pos.distance_to(ALTAR) > 90:
			breakables.append({"pos": pos, "hp": 14.0, "kind": "crate" if i % 3 else "urn"})
	_rebuild_navigation()
	_notify(_room_title() + "  |  " + _room_objective())

func _spawn_enemy(kind: String, pos: Vector2, elite: bool = false) -> Dictionary:
	var base_hp = {"crawler": 42.0, "archer": 36.0, "brute": 90.0, "boss": 720.0}[kind]
	var health = base_hp * (1.0 + depth * 0.10 if kind != "boss" else 1.0)
	if elite:
		health *= 1.4
	var enemy = {
		"kind": kind, "pos": _safe_spawn(pos), "hp": health, "max_hp": health,
		"defense": 40.0 if kind == "boss" else (30.0 if kind == "brute" else 10.0),
		"cooldown": rng.randf_range(0.7, 1.6), "windup": 0.0,
		"target": player, "flash": 0.0,
		"knock": Vector2.ZERO, "elite": elite, "phase": 0, "attack_index": 0,
		"stagger": 0.0, "wall_hit": false, "alert": false
	}
	elemental.prepare(enemy, Elements.NAMES[(depth * 3 + enemies.size()) % Elements.NAMES.size()], 1, kind == "boss")
	enemies.append(enemy)
	return enemy

func _safe_spawn(pos: Vector2) -> Vector2:
	var cell = Vector2i((pos - ARENA.position) / 32)
	var center = ARENA.position + Vector2(cell) * 32 + Vector2(16, 16)
	if _spawn_clear(center) and _move_actor(pos, Vector2.ZERO, 29).distance_to(pos) < 0.01:
		return pos
	var nearest = Vector2.ZERO
	var distance = INF
	for y in 26:
		for x in 43:
			var candidate = ARENA.position + Vector2(x * 32 + 16, y * 32 + 16)
			if _spawn_clear(candidate) and candidate.distance_squared_to(pos) < distance:
				nearest = candidate
				distance = candidate.distance_squared_to(pos)
	assert(distance < INF, "적 생성 지점을 찾지 못했습니다.")
	return nearest

func _spawn_clear(pos: Vector2) -> bool:
	for rect in structures:
		if rect.grow(32).has_point(pos):
			return false
	for tree in obstacles:
		if pos.distance_to(tree) < 48:
			return false
	return ARENA.grow(-32).has_point(pos)

func _process(delta: float) -> void:
	time += delta
	toast_time = maxf(0.0, toast_time - delta)
	if state == "playing":
		run_time += delta
		if hit_stop > 0.0:
			hit_stop -= delta
		else:
			_tick_player(delta)
			if state == "playing":
				_apply_element_events(elemental.tick(delta, _units()))
			if state == "playing":
				_tick_strike(delta)
				if not second_burst.is_empty():
					second_burst.timer -= delta
					if second_burst.timer <= 0:
						_element_burst(second_burst.radius, second_burst.damage)
						second_burst.clear()
				_tick_enemies(delta)
				if state == "playing":
					_tick_projectiles(delta)
				if state == "playing":
					_tick_hazards(delta)
				if state == "playing":
					_tick_pickups(delta)
					_collect_dead()
		var target_camera = Vector2(clampf(player.x, ARENA.position.x + 100, ARENA.end.x - 100), clampf(player.y, ARENA.position.y + 100, ARENA.end.y - 100))
		camera_position = camera_position.lerp(target_camera, 1 - exp(-delta * 9))
	_tick_effects(delta if state == "playing" else 0.0)
	queue_redraw()
	if auto_capture:
		capture_frames += 1
		if capture_frames == 52 and showcase:
			attack_cd = 0
			combo = 2
			_attack(false)
			_tick_strike(0.1)
			slash_time = 0.12
			invulnerable = 0
			for enemy in enemies:
				if enemy.pos.distance_to(player) < 130:
					enemy.flash = 0.1
		if capture_frames == 55:
			await RenderingServer.frame_post_draw
			var error = get_viewport().get_texture().get_image().save_png(capture_path)
			print("CAPTURE_RESULT=", error)
			_quit_game(0 if error == OK else 1)

func _tick_player(delta: float) -> void:
	var action_speed: float = elemental.action_speed(hero)
	attack_cd = maxf(0, attack_cd - delta * action_speed)
	skill_cd = maxf(0, skill_cd - delta * action_speed)
	if dash_charges < 2:
		dash_cd = maxf(0, dash_cd - delta)
		if dash_cd <= 0:
			dash_charges += 1
			dash_cd = dash_duration if dash_charges < 2 else 0
	invulnerable = maxf(0, invulnerable - delta)
	combo_timer = maxf(0, combo_timer - delta)
	if combo_timer <= 0:
		combo = 0
	if action_speed <= 0:
		dash_time = 0
		pending_strike.clear()
		return
	if elemental.movement(hero) == 0:
		dash_time = 0
		recoil = Vector2.ZERO
	var movement = _screen_movement(Input.get_vector("move_left", "move_right", "move_up", "move_down"))
	movement *= elemental.movement(hero)
	if movement.length_squared() > 0.01:
		last_move = movement
		if not mouse_aim:
			facing = movement
	if mouse_aim:
		var aim = _aim_world_point(pointer_position) - player
		if aim.length() > 8:
			facing = aim.normalized()
	if Input.is_action_just_pressed("dash"):
		_dash(movement)
	attack_buffer = maxf(0, attack_buffer - delta)
	if Input.is_action_just_pressed("slash"):
		attack_buffer = 0.14
	if dash_time > 0:
		dash_time -= delta
		player = _move_actor(player, dash_vector * 620.0 * delta, 12)
		trails.append({"pos": player, "life": 0.17})
		if _tier("이동속도") >= 3:
			for enemy in enemies:
				if enemy.hp > 0 and enemy.pos.distance_to(player) < 45:
					_hit_enemy(enemy, delta * attack_power * (4 if _tier("이동속도") == 4 else 2))
		if Input.is_action_pressed("slash") and attack_cd <= 0:
			_attack(false)
	else:
		var speed_multiplier = 0.72 if not pending_strike.is_empty() else 1.0
		player = _move_actor(player, movement * move_speed * speed_multiplier * delta + (recoil + hero.knock) * delta, 12)
		hero.knock = hero.knock.move_toward(Vector2.ZERO, delta * 650)
		recoil = recoil.move_toward(Vector2.ZERO, delta * 1200)
		if (Input.is_action_pressed("slash") or attack_buffer > 0) and attack_cd <= 0:
			_attack(false)
		if Input.is_action_just_pressed("skill") and skill_cd <= 0:
			_attack(true)
	if Input.is_action_just_pressed("flask"):
		_use_flask()
	if Input.is_action_just_pressed("interact"):
		_interact()

func _move_actor(pos: Vector2, movement: Vector2, radius: float) -> Vector2:
	var steps = maxi(1, ceili(movement.length() / 12))
	var result = pos
	for step in steps:
		result = _slide_actor(result + movement / steps, radius)
	return result

func _slide_actor(pos: Vector2, radius: float) -> Vector2:
	var result = pos
	result.x = clampf(result.x, ARENA.position.x + radius, ARENA.end.x - radius)
	result.y = clampf(result.y, ARENA.position.y + radius, ARENA.end.y - radius)
	for obstacle in obstacles:
		var diff = result - obstacle
		var minimum = 19.0 + radius
		if diff.length() < minimum:
			result = obstacle + diff.normalized() * minimum if diff.length() > 0.001 else obstacle + Vector2(minimum, 0)
	for structure in structures:
		var expanded = structure.grow(radius)
		if not expanded.has_point(result):
			continue
		var candidates = [Vector2(expanded.position.x - 0.1, result.y), Vector2(expanded.end.x + 0.1, result.y),
			Vector2(result.x, expanded.position.y - 0.1), Vector2(result.x, expanded.end.y + 0.1)]
		var nearest: Vector2 = result
		var distance = INF
		for candidate in candidates:
			if ARENA.grow(-radius).has_point(candidate) and candidate.distance_squared_to(result) < distance:
				distance = candidate.distance_squared_to(result)
				nearest = candidate
		assert(distance < INF, "지형 충돌 해소에 실패했습니다.")
		result = nearest
	return result

func _rebuild_navigation() -> void:
	navigation.region = Rect2i(0, 0, 43, 26)
	navigation.cell_size = Vector2(32, 32)
	navigation.offset = ARENA.position + Vector2(16, 16)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.update()
	for y in 26:
		for x in 43:
			var at = ARENA.position + Vector2(x * 32 + 16, y * 32 + 16)
			var blocked = false
			for structure in structures:
				blocked = blocked or structure.grow(24).has_point(at)
			for obstacle in obstacles:
				blocked = blocked or at.distance_to(obstacle) < 40
			navigation.set_point_solid(Vector2i(x, y), blocked)

func _navigation_direction(enemy: Dictionary) -> Vector2:
	var direct: Vector2 = player - enemy.pos
	var blocked = false
	for structure in structures:
		blocked = blocked or Geometry2D.segment_intersects_segment(enemy.pos, player, structure.position, Vector2(structure.end.x, structure.position.y)) != null
		blocked = blocked or Geometry2D.segment_intersects_segment(enemy.pos, player, structure.end, Vector2(structure.position.x, structure.end.y)) != null
		blocked = blocked or Geometry2D.segment_intersects_segment(enemy.pos, player, structure.position, Vector2(structure.position.x, structure.end.y)) != null
		blocked = blocked or Geometry2D.segment_intersects_segment(enemy.pos, player, structure.end, Vector2(structure.end.x, structure.position.y)) != null
		blocked = blocked or structure.grow(24).has_point(enemy.pos + direct.normalized() * 50)
	for obstacle in obstacles:
		blocked = blocked or Geometry2D.get_closest_point_to_segment(obstacle, enemy.pos, player).distance_to(obstacle) < 43
	if not blocked:
		return direct.normalized()
	var start = Vector2i((enemy.pos - ARENA.position) / 32)
	var end = Vector2i((player - ARENA.position) / 32)
	start.x = clampi(start.x, 0, 42)
	start.y = clampi(start.y, 0, 25)
	end.x = clampi(end.x, 0, 42)
	end.y = clampi(end.y, 0, 25)
	if navigation.is_point_solid(start) or navigation.is_point_solid(end):
		return direct.normalized()
	if not enemy.has("path_time") or enemy.path_time < time:
		enemy.path = navigation.get_point_path(start, end)
		enemy.path_time = time + 0.35
	var path: PackedVector2Array = enemy.get("path", PackedVector2Array())
	for point in path:
		if point.distance_to(enemy.pos) > 26:
			return (point - enemy.pos).normalized()
	return direct.normalized()

func _dash(movement: Vector2) -> void:
	if elemental.movement(hero) == 0 or elemental.active(hero, "진창") or elemental.action_speed(hero) == 0:
		_notify("이동 제어 효과로 회피할 수 없습니다.")
		return
	if dash_charges <= 0:
		return
	dash_charges -= 1
	if dash_cd <= 0:
		dash_cd = dash_duration
	dash_vector = movement.normalized() if movement.length() > 0.1 else last_move
	dash_time = 0.17
	pending_strike.clear()
	attack_cd = minf(attack_cd, 0.05)
	recoil = Vector2.ZERO
	invulnerable = maxf(invulnerable, 0.25)
	sound.play_tone("dash")

func _attack(heavy: bool) -> void:
	if elemental.action_speed(hero) <= 0:
		return
	if not pending_strike.is_empty():
		return
	if heavy and skill_cd > 0:
		return
	if not heavy and attack_cd > 0:
		return
	if heavy:
		skill_cd = skill_duration
		if _tier("생존") >= 3:
			elemental.grant_shield(hero, 24 if _tier("생존") == 4 else 12, 3)
		sound.play_tone("skill")
	else:
		combo = combo % 3 + 1
		combo_timer = 0.85
		attack_cd = attack_interval * (1.15 if combo == 3 else 1.0)
		sound.play_tone("slash")
	attack_buffer = 0
	dash_attack = dash_time > 0 and not heavy
	pending_strike = {"timer": 0.07 if heavy else 0.045, "heavy": heavy, "direction": facing, "dash": dash_attack}
	if not heavy and not dash_attack:
		recoil = facing * (120 if combo == 3 else 65)

func _tick_strike(delta: float) -> void:
	if pending_strike.is_empty():
		return
	pending_strike.timer -= delta
	if pending_strike.timer > 0:
		return
	var strike: Dictionary = pending_strike.duplicate()
	pending_strike.clear()
	_resolve_strike(strike.heavy, strike.direction, strike.dash)

func _resolve_strike(heavy: bool, direction: Vector2, rushing: bool) -> void:
	slash_time = 0.30 if heavy else 0.21
	slash_origin = player
	slash_angle = direction.angle()
	slash_heavy = heavy
	var radius = _skill_radius() if heavy else attack_range + (22 if rushing else 0)
	var hits = 0
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		var diff: Vector2 = enemy.pos - player
		if diff.length() > radius + _enemy_radius(enemy):
			continue
		if not heavy and diff.length() > 20 and direction.dot(diff.normalized()) < 0.05:
			continue
		var damage = _attack_damage(heavy) * (1.0 if heavy else (1.6 if combo == 3 else 1.0)) * (1.25 if rushing else 1.0)
		var critical = rng.randf() < crit_chance
		if critical:
			damage *= 2
		_element_hit(hero, enemy, damage, hero.element, critical)
		elemental.knock(enemy, diff, 320.0 if heavy or combo == 3 else 180.0)
		enemy.stagger = 0.18 if enemy.kind != "boss" else 0.0
		enemy.wall_hit = false
		if not heavy and _tier("물리공격") == 4:
			_hit_enemy(enemy, damage * 0.35)
		hits += 1
	if heavy:
		_emit(player, GOLD, 34, 260)
		shake = 5
		if _tier(element_lock) >= 3:
			_element_burst(radius + 55, _attack_damage(true) * 0.35)
		if _tier("기술") == 4 or _tier("속성공격") == 4:
			second_burst = {"timer": 0.24, "radius": radius, "damage": _attack_damage(true) * 0.6}
	elif _tier("공격속도") == 4 or (_tier("공격속도") >= 3 and combo == 3):
		_element_burst(attack_range + 35, _attack_damage(false) * 0.3)
	for prop in breakables:
		var diff: Vector2 = prop.pos - player
		if prop.hp > 0 and diff.length() < radius + 14 and (heavy or direction.dot(diff.normalized()) > 0.05):
			prop.hp = 0
			gold += 3
			_emit(prop.pos, GOLD, 12, 110)
			_float_text(prop.pos, "+3 금화", GOLD)
	if hits > 0:
		hit_stop = 0.065 if heavy or combo == 3 else 0.035
		shake = 5 if heavy or combo == 3 else 2
		screen_flash = 0.09 if heavy or combo == 3 else 0.035
		sound.play_tone("finisher" if heavy or combo == 3 else "hit")

func _hit_enemy(enemy: Dictionary, damage: float, critical: bool = false) -> void:
	if enemy.hp <= 0:
		return
	damage = elemental.absorb(enemy, damage)
	enemy.hp -= damage
	enemy.flash = 0.12
	impacts.append({"pos": enemy.pos + Vector2(0, -12), "angle": (enemy.pos - player).angle(), "life": 0.16, "kind": "hit", "critical": critical})
	_float_text(enemy.pos + Vector2(0, -30), str(int(damage)) + ("!" if critical else ""), GOLD if critical else PAPER)
	_emit(enemy.pos, GOLD if critical else MINT, 5, 100)

func _units() -> Array:
	hero.hp = hp
	hero.pos = player
	return [hero] + enemies

func _heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount * elemental.heal_factor(hero) * (1.2 if _tier("생존") >= 2 else 1.0))
	hero.hp = hp

func _attack_damage(heavy: bool) -> float:
	var physical = 0.0 if heavy else 0.15 * flat_bonuses.get("물리공격", 0) + 0.1 * mini(_tier("물리공격"), 2)
	var elemental_bonus = 0.15 * flat_bonuses.get("속성공격", 0) + 0.1 * mini(_tier("속성공격"), 2)
	elemental_bonus += 0.12 * mini(_tier(element_lock), 2)
	var skill = 0.16 * flat_bonuses.get("기술", 0) + (0.15 if _tier("기술") >= 2 else 0) + (0.25 if _tier("속성공격") >= 3 else 0)
	return attack_power * (2.4 if heavy else 1.0) * (1 + physical + elemental_bonus + (skill if heavy else 0))

func _skill_radius() -> float:
	return 136.0 + (30 if _tier("기술") >= 3 else 0) + (90 if _tier(element_lock) == 4 else 0)

func _element_burst(radius: float, damage: float) -> void:
	impacts.append({"pos": player, "life": 0.3, "kind": "element", "radius": radius, "element": hero.element})
	for enemy in enemies:
		if enemy.hp > 0 and enemy.pos.distance_to(player) < radius:
			_element_hit(hero, enemy, damage, hero.element)

func _element_hit(attacker: Dictionary, target: Dictionary, damage: float, element: String, critical: bool = false) -> void:
	_units()
	if elemental.active(attacker, "모래") and rng.randf() < 0.15:
		_float_text(target.pos, "빗나감", MUTED)
		return
	var events = elemental.hit(attacker, target, damage, element, _units())
	events[0].critical = critical
	_apply_element_events(events)

func _apply_element_events(events: Array) -> void:
	for event in events:
		if state != "playing":
			return
		var target: Dictionary = event.target
		if target.hp <= 0:
			continue
		if target.side == 0:
			_hurt(event.damage, true)
		else:
			_hit_enemy(target, event.damage, event.get("critical", false))
		if not event.reaction.is_empty():
			_float_text(target.pos + Vector2(0, -75), event.reaction, _element_color(event.element))
			_emit(target.pos, _element_color(event.element), 12, 150)

func _incoming(attacker: Dictionary, damage: float) -> void:
	if invulnerable > 0 or state != "playing":
		return
	_element_hit(attacker, hero, damage, attacker.element)
	invulnerable = 0.75

func _element_color(element: String) -> Color:
	return Color(Elements.COLORS[Elements.NAMES.find(element)])

func _hurt(damage: float, periodic: bool = false) -> void:
	if (invulnerable > 0 and not periodic) or state != "playing":
		return
	damage *= 0.92 if _tier("생존") >= 1 else 1.0
	damage = elemental.absorb(hero, damage)
	hp = maxf(0, hp - damage)
	hero.hp = hp
	if not periodic:
		invulnerable = 0.75
	shake = 7
	_float_text(player + Vector2(0, -35), "-" + str(int(damage)), RED)
	_emit(player, RED, 12, 130)
	sound.play_tone("hurt")
	if hp <= 0:
		_finish_run(false)

func _use_flask() -> void:
	if flasks <= 0:
		_notify("회복약이 없습니다.")
		return
	if hp >= max_hp:
		_notify("체력이 가득 차 있습니다.")
		return
	flasks -= 1
	_heal(flask_power)
	_emit(player, MINT, 20, 100)
	sound.play_tone("reward")
	_notify("이슬의 회복약  +" + str(int(flask_power)) + " 체력")

func _enemy_radius(enemy: Dictionary) -> float:
	return 29.0 if enemy.kind == "boss" else (20.0 if enemy.kind == "brute" else 15.0)

func _tick_enemies(delta: float) -> void:
	for enemy in enemies:
		if state != "playing":
			return
		if enemy.hp <= 0:
			continue
		enemy.flash = maxf(0, enemy.flash - delta)
		var action_speed: float = elemental.action_speed(enemy)
		enemy.cooldown -= delta * action_speed
		enemy.stagger = maxf(0, enemy.stagger - delta)
		if enemy.knock.length() > 2:
			var desired: Vector2 = enemy.pos + enemy.knock * delta
			enemy.pos = _move_actor(enemy.pos, enemy.knock * delta, _enemy_radius(enemy))
			if desired.distance_to(enemy.pos) > 3 and enemy.knock.length() > 130 and not enemy.wall_hit:
				enemy.wall_hit = true
				_hit_enemy(enemy, 10)
				_float_text(enemy.pos + Vector2(0, -44), "벽 충돌", GOLD)
				shake = 4
			enemy.knock = enemy.knock.move_toward(Vector2.ZERO, delta * 650)
		if enemy.hp <= 0 or enemy.stagger > 0 or action_speed == 0:
			continue
		if enemy.kind == "boss":
			_tick_boss(enemy, delta * action_speed)
			continue
		var diff: Vector2 = player - enemy.pos
		var distance = diff.length()
		if not enemy.alert:
			enemy.alert = distance < 430
			if not enemy.alert:
				continue
		if enemy.windup > 0:
			enemy.windup -= delta * action_speed
			if enemy.windup <= 0:
				_resolve_enemy_attack(enemy)
			continue
		if enemy.cooldown <= 0 and (distance < 62 or enemy.kind == "archer"):
			enemy.windup = 0.65 if enemy.kind == "brute" else 0.48
			enemy.target = player
			continue
		var speed = 88.0 + depth * 3.0
		if enemy.kind == "brute":
			speed = 62
		if enemy.kind == "archer":
			speed = 44 if distance > 235 else (-42 if distance < 150 else 0)
		var velocity = _navigation_direction(enemy) * speed
		for other in enemies:
			if other == enemy or other.hp <= 0:
				continue
			var away: Vector2 = enemy.pos - other.pos
			if away.length() < _enemy_radius(enemy) + _enemy_radius(other) + 5 and away.length() > 0.01:
				velocity += away.normalized() * 65
		enemy.pos = _move_actor(enemy.pos, velocity * delta * elemental.movement(enemy), _enemy_radius(enemy))

func _resolve_enemy_attack(enemy: Dictionary) -> void:
	var direction: Vector2 = (enemy.target - enemy.pos).normalized()
	enemy.cooldown = 1.65 if enemy.kind == "brute" else 1.15
	if enemy.kind == "archer":
		_shoot(enemy.pos, direction, 185, 13, enemy)
	elif enemy.kind == "brute":
		_emit(enemy.pos + direction * 35, RED, 12, 150)
		if player.distance_to(enemy.pos + direction * 28) < 69:
			_incoming(enemy, 23)
	else:
		_emit(enemy.pos + direction * 20, RED, 5, 70)
		if player.distance_to(enemy.pos) < 68 and direction.dot((player - enemy.pos).normalized()) > 0:
			_incoming(enemy, 12)

func _tick_boss(enemy: Dictionary, delta: float) -> void:
	var enraged = enemy.hp < enemy.max_hp * 0.5
	if enraged and enemy.phase == 0:
		enemy.phase = 1
		_notify("성소의 수호자: 뿌리의 분노")
		_emit(enemy.pos, GOLD, 40, 220)
	if enemy.windup > 0:
		enemy.windup -= delta
		if enemy.windup <= 0:
			var attack_index: int = enemy.attack_index % 3
			if attack_index == 0:
				var count = 14 if enraged else 10
				for i in count:
					var angle = TAU * i / count + time * 0.15
					_shoot(enemy.pos, Vector2.from_angle(angle), 152 if enraged else 125, 16, enemy)
			elif attack_index == 1:
				var direction: Vector2 = (enemy.target - enemy.pos).normalized()
				for offset in [-0.24, 0.0, 0.24]:
					_shoot(enemy.pos, direction.rotated(offset), 260, 20, enemy)
			else:
				for i in (5 if enraged else 3):
					var pos: Vector2 = player + Vector2(rng.randf_range(-120, 120), rng.randf_range(-70, 70))
					pos.x = clampf(pos.x, ARENA.position.x + 55, ARENA.end.x - 55)
					pos.y = clampf(pos.y, ARENA.position.y + 55, ARENA.end.y - 55)
					hazards.append({"pos": pos, "timer": 0.95, "life": 1.25, "fired": false, "source": enemy})
			enemy.attack_index += 1
			enemy.cooldown = 0.75 if enraged else 1.2
		return
	var diff: Vector2 = player - enemy.pos
	if diff.length() > 80:
		enemy.pos = _move_actor(enemy.pos, _navigation_direction(enemy) * delta * elemental.movement(enemy) * (55 if enraged else 38), 29)
	if diff.length() < 64:
		_incoming(enemy, 22)
	if enemy.cooldown <= 0:
		enemy.windup = 0.65 if enraged else 0.9
		enemy.target = player
		if enemy.attack_index % 3 == 2:
			_notify("발밑을 조심하세요. 뿌리가 솟아오릅니다!")

func _shoot(pos: Vector2, direction: Vector2, speed: float, damage: float, source: Dictionary = {}) -> void:
	projectiles.append({"pos": pos, "velocity": direction * speed, "damage": damage, "life": 5.0, "source": source})

func _tick_projectiles(delta: float) -> void:
	for i in range(projectiles.size() - 1, -1, -1):
		var projectile: Dictionary = projectiles[i]
		projectile.pos += projectile.velocity * delta
		projectile.life -= delta
		var remove = projectile.life <= 0 or not ARENA.has_point(projectile.pos)
		for obstacle in obstacles:
			if projectile.pos.distance_to(obstacle) < 28:
				remove = true
		for structure in structures:
			if structure.has_point(projectile.pos):
				remove = true
		if not remove and projectile.pos.distance_to(player) < 16:
			if projectile.source.is_empty():
				_hurt(projectile.damage)
			else:
				_incoming(projectile.source, projectile.damage)
			if state != "playing":
				return
			remove = true
		if remove:
			_emit(projectile.pos, RED, 3, 60)
			projectiles.remove_at(i)

func _tick_hazards(delta: float) -> void:
	for i in range(hazards.size() - 1, -1, -1):
		var hazard: Dictionary = hazards[i]
		hazard.timer -= delta
		hazard.life -= delta
		if hazard.timer <= 0 and not hazard.fired:
			hazard.fired = true
			_emit(hazard.pos, GOLD, 18, 180)
			if hazard.pos.distance_to(player) < 48:
				_incoming(hazard.source, 24)
				if state != "playing":
					return
		if hazard.life <= 0:
			hazards.remove_at(i)

func _collect_dead() -> void:
	var killed_boss = false
	for i in range(enemies.size() - 1, -1, -1):
		var enemy: Dictionary = enemies[i]
		if enemy.hp > 0:
			continue
		killed_boss = killed_boss or enemy.kind == "boss"
		total_kills += 1
		room_kills += 1
		run_embers += 3 if enemy.elite else 2
		gold += 5 if enemy.elite else 3
		_gain_experience(18 if enemy.elite else 12)
		floor_marks.append({"pos": enemy.pos, "kind": enemy.kind})
		_emit(enemy.pos, GOLD, 20, 180)
		for j in 3:
			pickups.append({"pos": enemy.pos + Vector2(rng.randf_range(-18, 18), rng.randf_range(-18, 18)), "age": 0.0})
		enemies.remove_at(i)
	if killed_boss:
		run_embers += 35
		_finish_run(true)
		return
	if enemies.is_empty() and not room_clear and not reward_deferred and (room_type == "battle" or room_type == "elite") and state == "playing":
		projectiles.clear()
		hazards.clear()
		_offer_relics()

func _tick_pickups(delta: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pickup: Dictionary = pickups[i]
		pickup.age += delta
		var diff: Vector2 = player - pickup.pos
		if diff.length() < 145 or room_clear:
			pickup.pos += diff.normalized() * delta * 270
		if diff.length() < 20:
			_heal(1)
			sound.play_tone("coin")
			pickups.remove_at(i)

func _gain_experience(amount: int) -> void:
	experience += amount
	while experience >= _experience_needed():
		experience -= _experience_needed()
		level += 1
		max_hp += 5
		_heal(15)
		attack_power += 2
		_float_text(player + Vector2(0, -55), "LEVEL UP  %d" % level, GOLD)
		_emit(player, GOLD, 26, 180)
		sound.play_tone("reward")

func _experience_needed() -> int:
	return 45 + (level - 1) * 20

func _emit(pos: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		var velocity = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(speed * 0.15, speed)
		particles.append({"pos": pos, "velocity": velocity, "life": rng.randf_range(0.18, 0.5), "color": color, "size": rng.randi_range(2, 5)})

func _float_text(pos: Vector2, text: String, color: Color) -> void:
	numbers.append({"pos": pos, "text": text, "color": color, "life": 0.7})

func _tick_effects(delta: float) -> void:
	var motion_delta = 0.0 if hit_stop > 0 else delta
	slash_time = maxf(0, slash_time - motion_delta)
	shake = maxf(0, shake - delta * 25)
	screen_flash = maxf(0, screen_flash - delta)
	for i in range(trails.size() - 1, -1, -1):
		trails[i].life -= delta
		if trails[i].life <= 0:
			trails.remove_at(i)
	for i in range(impacts.size() - 1, -1, -1):
		impacts[i].life -= motion_delta
		if impacts[i].life <= 0:
			impacts.remove_at(i)
	for i in range(particles.size() - 1, -1, -1):
		var particle: Dictionary = particles[i]
		particle.pos += particle.velocity * delta
		particle.velocity *= maxf(0, 1 - delta * 4)
		particle.life -= delta
		if particle.life <= 0:
			particles.remove_at(i)
	for i in range(numbers.size() - 1, -1, -1):
		numbers[i].life -= delta
		if numbers[i].life <= 0:
			numbers.remove_at(i)

func _interact() -> void:
	if reward_deferred and player.distance_to(ALTAR) < 80:
		_offer_relics(false)
	elif room_type == "treasure" and not room_clear and player.distance_to(ALTAR) < 80:
		_offer_relics()
	elif room_type == "rest" and not room_clear and player.distance_to(ALTAR) < 80:
		_show_rest()
	elif room_type == "shop" and player.distance_to(ALTAR) < 80:
		_show_shop()
	elif room_clear and player.distance_to(WEST_GATE) < 78:
		_take_gate(0)
	elif room_clear and player.distance_to(EAST_GATE) < 78:
		_take_gate(1)
	elif room_clear and player.distance_to(PORTAL) < 78:
		_show_routes()
	else:
		_notify("빛나는 제단이나 열린 북쪽 문 가까이에서 E를 누르세요.")

func _offer_relics(refresh: bool = true) -> void:
	state = "reward"
	reward_deferred = false
	pending_strike.clear()
	if refresh:
		var pool = Augments.eligible(augment_data, augments, element_lock)
		var previous_ids = offered.map(func(item): return item.id)
		var fresh = pool.filter(func(item): return item.id not in previous_ids)
		if fresh.size() >= 3:
			pool = fresh
		_shuffle(pool)
		assert(pool.size() >= 3, "증강 풀이 부족합니다.")
		offered.clear()
		for i in 3:
			var item: Dictionary = pool[i].duplicate(true)
			item.rarity = Augments.roll_rarity(rng)
			offered.append(item)
	reward_ranks.clear()
	var lock_label = "첫 속성 증강을 고르면 자신의 속성이 결정됩니다." if element_lock.is_empty() else "현재 속성: " + element_lock + " / 해당 속성 증강만 등장"
	var box = _new_panel("새벽의 증강", lock_label + "\n같은 태그 2 / 3 / 4 / 6개로 시너지. 보유 증강은 다시 나오지 않습니다.", 850)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	box.add_child(row)
	for i in 3:
		var item: Dictionary = offered[i]
		var choices = VBoxContainer.new()
		choices.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		choices.custom_minimum_size.x = 240
		row.add_child(choices)
		var rank: int = item.rarity
		reward_ranks.append(rank)
		var tags = " / ".join(item.tags)
		var progress = ""
		for tag in item.tags:
			var count: int = tag_counts.get(tag, 0)
			var next = 6
			for threshold in Augments.THRESHOLDS:
				if count < threshold:
					next = threshold
					break
			progress += "%s %d>%d  (다음 %d)\n" % [tag, count, count + 1, next]
		_add_label(choices, Augments.RARITIES[rank], 20, Color(Augments.COLORS[rank]))
		var effect = RarityEffect.new()
		effect.rank = rank
		effect.animate = effects_enabled
		choices.add_child(effect)
		var button = _add_button(choices, "[%d] %s\n\n%s\n\n%s\n\n%s" % [i + 1, item.name, Augments.description(item, rank), tags, progress.strip_edges()], _choose_relic.bind(i), 245)
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.add_theme_font_size_override("font_size", 14)
		button.focus_entered.connect(sound.play_rarity.bind(rank))
		var style: StyleBoxFlat = button.get_theme_stylebox("normal").duplicate()
		style.border_color = Color(Augments.COLORS[rank])
		style.set_border_width_all(1 + rank / 2)
		button.add_theme_stylebox_override("normal", style)
	var reroll_button = _add_button(box, "다시 보기  (%d회 남음)" % rerolls, _reroll_relics, 42)
	reroll_button.disabled = rerolls <= 0
	reroll_button.focus_mode = Control.FOCUS_NONE if reroll_button.disabled else Control.FOCUS_ALL
	_finish_panel()
	sound.play_rarity(reward_ranks.max())

func _defer_reward() -> void:
	reward_deferred = true
	_resume_room()
	_notify("보상을 남겨 두었습니다. 중앙 제단에서 E를 누르면 다시 선택합니다.")

func _reroll_relics() -> void:
	if state != "reward" or rerolls <= 0:
		return
	rerolls -= 1
	_offer_relics()

func _choose_relic(index: int) -> void:
	if state != "reward" or index < 0 or index >= offered.size():
		return
	var item: Dictionary = offered[index]
	if not _apply_augment(item.id, item.rarity):
		return
	if room_type == "elite":
		_heal(12)
	_close_overlay()
	state = "playing"
	room_clear = true
	sound.play_rarity(item.rarity)
	_notify(item.name + " 획득. 출구에서 E: 다음 방")

func _shuffle(items: Array) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j = rng.randi_range(0, i)
		var value = items[i]
		items[i] = items[j]
		items[j] = value

func _apply_augment(id: String, rarity: int) -> bool:
	var matches = augment_data.filter(func(item): return item.id == id)
	if matches.is_empty() or augments.has(id) or rarity < 0 or rarity > 5:
		push_error("획득할 수 없는 증강: " + id)
		_notify("증강 획득에 실패했습니다. 중복 및 데이터를 확인하세요.")
		return false
	var item: Dictionary = matches[0]
	if not element_lock.is_empty() and not item.element.is_empty() and item.element != element_lock:
		push_error("다른 속성 증강 획득 거부: " + id)
		_notify("현재 속성과 다른 증강은 획득할 수 없습니다.")
		return false
	if element_lock.is_empty() and not item.element.is_empty():
		element_lock = item.element
		hero.element = element_lock
	augments[id] = rarity
	flat_bonuses[item.stat] = flat_bonuses.get(item.stat, 0.0) + Augments.POWER[rarity]
	if item.stat == "생존":
		max_hp += roundi(15 * Augments.POWER[rarity])
		_heal(roundi(15 * Augments.POWER[rarity]))
	tag_counts = Augments.counts(augment_data, augments)
	attack_interval = maxf(0.10, 0.3 / (1 + 0.12 * flat_bonuses.get("공격속도", 0) + 0.1 * mini(_tier("공격속도"), 2)))
	move_speed = 176 * (1 + 0.08 * flat_bonuses.get("이동속도", 0) + (0.08 if _tier("이동속도") >= 1 else 0))
	dash_duration = maxf(0.35, 1 - 0.05 * flat_bonuses.get("이동속도", 0) - (0.15 if _tier("이동속도") >= 2 else 0))
	skill_duration = maxf(1.0, 5.5 * (1 - 0.06 * flat_bonuses.get("기술", 0) - (0.1 if _tier("기술") >= 1 else 0)))
	attack_range = 106 if _tier("물리공격") >= 3 else 86
	return true

func _tier(tag: String) -> int:
	return Augments.tier(tag_counts.get(tag, 0))

func _take_gate(choice: int) -> void:
	var next = depth + 1
	if next >= 6:
		_enter_room(6, "boss")
	elif next == 3:
		_enter_room(next, "rest" if choice == 0 else "treasure")
	else:
		_enter_room(next, "battle" if choice == 0 else "elite")

func _show_routes() -> void:
	state = "route"
	var next = depth + 1
	var box = _new_panel("더 깊은 성소로", "지나온 방은 돌아갈 수 없습니다. 다음 길을 선택하세요.", 580)
	if next >= 6:
		_add_button(box, "수호자의 옥좌\n마지막 보스. 원형 탄막과 뿌리 폭발에 대비하세요.", _enter_room.bind(6, "boss"), 88)
	elif next == 3:
		_add_button(box, "이슬의 샘\n체력을 회복하거나 공격력을 축복받습니다.", _enter_room.bind(next, "rest"), 84)
		_add_button(box, "묻힌 보물방\n전투 없이 증강을 하나 획득합니다.", _enter_room.bind(next, "treasure"), 84)
		_add_button(box, "떠돌이 상인\n모은 금화로 증강과 회복약을 구매합니다.", _enter_room.bind(next, "shop"), 70)
	else:
		_add_button(box, "무너진 회랑\n일반 전투. 적을 처치하고 증강을 얻습니다.", _enter_room.bind(next, "battle"), 84)
		_add_button(box, "가시의 시련\n강화된 적. 처치 불씨 증가, 방 클리어 시 체력 12 회복", _enter_elite.bind(next), 84)
	_add_button(box, "아직 준비 중입니다", _resume_room, 42)
	_finish_panel()

func _enter_elite(next: int) -> void:
	_enter_room(next, "elite")

func _resume_room() -> void:
	_close_overlay()
	state = "playing"

func _show_rest() -> void:
	state = "rest"
	var box = _new_panel("이슬이 고인 제단", "불씨를 품은 뿌리가 순례자의 손길을 기다립니다.", 580)
	_add_button(box, "샘물 마시기\n최대 체력의 50% 회복, 회복약 1개 보충", _rest_choice.bind(true), 85)
	_add_button(box, "검에 축복 새기기\n공격력 +8. 체력은 회복하지 않습니다.", _rest_choice.bind(false), 85)
	_finish_panel()

func _show_shop() -> void:
	state = "shop"
	var box = _new_panel("숲길의 상인", "금화 %d  /  나무 상자와 항아리를 부수거나 적을 처치해 금화를 모으세요." % gold, 670)
	var relic_button = _add_button(box, "숲의 증강  /  25 금화\n세 증강 중 하나를 고릅니다. 방마다 한 번 구매할 수 있습니다.", _shop_buy.bind("relic"), 80)
	relic_button.disabled = gold < 25 or shop_purchased
	relic_button.focus_mode = Control.FOCUS_NONE if relic_button.disabled else Control.FOCUS_ALL
	var heal_button = _add_button(box, "이슬의 약  /  12 금화\n체력 35 회복, 회복약 1개 보충", _shop_buy.bind("heal"), 70)
	heal_button.disabled = gold < 12
	heal_button.focus_mode = Control.FOCUS_NONE if heal_button.disabled else Control.FOCUS_ALL
	_add_button(box, "거래를 마치고 출구 열기", _leave_shop, 46)
	_finish_panel()

func _shop_buy(kind: String) -> void:
	if state != "shop":
		return
	if kind == "relic" and gold >= 25 and not shop_purchased:
		gold -= 25
		shop_purchased = true
		_offer_relics()
	elif kind == "heal" and gold >= 12:
		gold -= 12
		_heal(35)
		flasks += 1
		sound.play_tone("reward")
		_show_shop()

func _leave_shop() -> void:
	room_clear = true
	_resume_room()

func _rest_choice(heal: bool) -> void:
	if heal:
		_heal(max_hp * 0.5)
		flasks += 1
	else:
		attack_power += 8
	room_clear = true
	_resume_room()
	sound.play_tone("reward")
	_notify("제단의 축복을 받았습니다. 북쪽 문으로 이동하세요.")

func _settle_run(won: bool) -> void:
	if run_settled:
		return
	run_settled = true
	run_active = false
	meta_embers += run_embers
	best_depth = maxi(best_depth, depth + (1 if won else 0))
	best_depth = mini(best_depth, 7)
	_save()

func _finish_run(won: bool) -> void:
	_settle_run(won)
	state = "victory" if won else "dead"
	projectiles.clear()
	hazards.clear()
	var title = "성소에 다시 불이 켜졌습니다" if won else "불씨는 아직 꺼지지 않았습니다"
	var subtitle = "수호자를 쓰러뜨렸습니다. 데모를 플레이해 주셔서 감사합니다." if won else "이번 탐험의 증강은 사라집니다. 모은 불씨는 야영지에 남습니다."
	var box = _new_panel(title, subtitle, 650)
	_add_label(box, "도달한 방  %d / 7     처치  %d     시간  %s" % [depth + 1, total_kills, _clock(run_time)], 18, PAPER)
	_add_label(box, "획득한 불씨  +%d     보유 불씨  %d" % [run_embers, meta_embers], 22, GOLD)
	if not save_error.is_empty():
		_add_label(box, save_error, 15, RED)
	_add_button(box, "야영지로 돌아가기  /  영구 강화", _show_hub, 52)
	_add_button(box, "같은 강화로 다시 도전  [R]", _start_run, 48)
	_finish_panel()

func _show_hub() -> void:
	state = "hub"
	player = ALTAR + Vector2(120, 120)
	camera_position = ALTAR
	enemies.clear()
	obstacles.clear()
	structures.clear()
	breakables.clear()
	floor_marks.clear()
	_build_forest_border()
	projectiles.clear()
	hazards.clear()
	pickups.clear()
	elemental.clear_room()
	hero.status.clear()
	hero.shield = 0.0
	second_burst.clear()
	var box = _new_panel("불씨의 성소", "EMBER SANCTUARY  /  쿼터뷰 액션 로그라이트", 630)
	box.add_theme_constant_override("separation", 6)
	_add_label(box, "새벽의 숲: 일곱 공터의 수호자를 찾아가세요.", 17, PAPER)
	_add_label(box, "보유 불씨  %d     영구 강화  %d / 5" % [meta_embers, meta_level], 21, GOLD)
	_add_label(box, "강화당 시작 체력 +12 / 공격력 +2. 사망해도 유지됩니다.", 15, MUTED)
	_add_button(box, "성소에 들어가기", _start_run, 48)
	var cost = _upgrade_cost()
	var upgrade_text = "불씨로 단련하기  (%d 필요)" % cost if meta_level < 5 else "단련 완료  (최대 단계)"
	var upgrade = _add_button(box, upgrade_text, _buy_upgrade, 48)
	upgrade.disabled = meta_level >= 5 or meta_embers < cost or not save_error.is_empty()
	upgrade.focus_mode = Control.FOCUS_NONE if upgrade.disabled else Control.FOCUS_ALL
	_add_button(box, "조작법과 탐험 안내", _show_help.bind("hub"), 44)
	_add_button(box, "게임 종료", _quit_game, 44)
	_add_button(box, "사운드 설정", _show_settings.bind("hub"), 44)
	if not save_error.is_empty():
		_add_label(box, save_error, 14, RED)
	if not sound.settings_error.is_empty():
		_add_label(box, sound.settings_error, 14, RED)
	_finish_panel()

func _upgrade_cost() -> int:
	return 25 + meta_level * 20

func _buy_upgrade() -> void:
	if meta_level >= 5 or meta_embers < _upgrade_cost() or not save_error.is_empty():
		return
	meta_embers -= _upgrade_cost()
	meta_level += 1
	_save()
	sound.play_tone("reward")
	_show_hub()

func _quit_game(exit_code: int = 0) -> void:
	if testing or quitting:
		return
	quitting = true
	if run_active and not auto_capture:
		_settle_run(false)
	sound.enabled = false
	sound.stop_all()
	await get_tree().create_timer(0.15).timeout
	get_tree().quit(exit_code)

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		_quit_game()

func _show_help(return_to: String) -> void:
	previous_state = return_to
	state = "help"
	var box = _new_panel("순례자의 수첩", "마우스 또는 키보드만으로 플레이할 수 있습니다.", 640)
	_add_label(box, "이동   WASD / 방향키 (화면 기준)       조준   마우스\n베기   좌클릭 유지 / J       불씨 폭발   우클릭 / Q / K\n회피   Space (이동 방향, 무적)       회복약   F\n상호작용   E       일시정지   Esc       수첩   Tab\n음소거   M       조준 방식 변경   T", 18, PAPER)
	_add_label(box, "I  증강·시너지 / G  탐험 지도 / V  화면 흔들림·섬광 전환\n회피는 2회 충전. 회피 공격 피해 +25%. Esc에서 소리 설정.\n증강은 중복 없이 획득. 같은 태그 2/3/4/6개로 시너지가 열립니다.\n첫 속성 선택 후 해당 속성 증강만 등장. 공용 증강은 속성 선택 전만 등장.\n적의 머리 위 속성이 반응 기준입니다. 자신의 속성도 반응합니다.\n네 번째 방은 휴식·보물·상인, 일곱 번째 방은 보스입니다.", 15, MUTED)
	_add_button(box, "수첩 닫기", _close_help.bind(return_to), 46)
	_finish_panel()

func _close_help(return_to: String) -> void:
	if return_to == "hub":
		_show_hub()
	elif return_to == "pause":
		_show_pause()
	else:
		_resume_room()

func _show_pause() -> void:
	state = "pause"
	var box = _new_panel("잠시 숨 고르기", "탐험 시간과 전투가 멈췄습니다.", 540)
	_add_button(box, "탐험 계속하기  [Esc]", _resume_room, 52)
	_add_button(box, "획득 증강과 시너지", _show_inventory.bind("pause"), 48)
	_add_button(box, "야영지로 귀환  (현재 불씨 정산)", _abandon_run, 48)
	_add_button(box, "사운드 설정", _show_settings.bind("pause"), 44)
	if not sound.settings_error.is_empty():
		_add_label(box, sound.settings_error + " (기존 파일 보존)", 14, RED)
	_finish_panel()

func _abandon_run() -> void:
	_settle_run(false)
	_show_hub()

func _show_inventory(return_to: String = "playing") -> void:
	state = "inventory"
	build_return = return_to
	var box = _new_panel("증강과 공명", "자신의 고유 속성: %s / 보유 증강 %d개 / 배치·중첩 없음" % [hero.element, augments.size()], 820)
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.y = 255
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(content)
	if augments.is_empty():
		_add_label(content, "아직 선택한 증강이 없습니다. 첫 방의 적을 쓰러뜨리세요.", 17, PAPER)
	for tag in tag_counts:
		_add_label(content, "%s  %d개 / 활성 단계 %d\n%s" % [tag, tag_counts[tag], _tier(tag), Augments.synergy_text(tag)], 14, GOLD if _tier(tag) > 0 else MUTED)
	for item in augment_data:
		if augments.has(item.id):
			var rank: int = augments[item.id]
			_add_label(content, "%s  [%s]  %s\n%s" % [item.name, Augments.RARITIES[rank], " / ".join(item.tags), Augments.description(item, rank)], 14, PAPER)
	_add_button(box, "조작법 보기", _show_help.bind("pause"), 44)
	_add_button(box, "닫기  [Esc]", _close_build, 44)
	_finish_panel()

func _close_build() -> void:
	if build_return == "pause":
		_show_pause()
	else:
		_resume_room()

func _show_settings(return_to: String = "pause") -> void:
	settings_return = return_to
	state = "settings"
	var box = _new_panel("사운드 설정", "즉시 적용됩니다. 좌우 방향키로 조절, Esc로 저장하고 닫기.", 650)
	for pair in [["master", "전체 음량"], ["music", "배경 음악"], ["effects", "효과음"]]:
		var label = _add_label(box, "%s  %d%%" % [pair[1], roundi(sound.levels[pair[0]] * 100)], 17, PAPER)
		var slider = HSlider.new()
		slider.name = pair[0]
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = sound.levels[pair[0]] * 100
		slider.custom_minimum_size.y = 20
		var focus = StyleBoxFlat.new()
		focus.bg_color = Color(0, 0, 0, 0)
		focus.border_color = GOLD
		focus.set_border_width_all(2)
		slider.add_theme_stylebox_override("focus", focus)
		slider.value_changed.connect(func(value): sound.set_level(pair[0], value / 100.0); label.text = "%s%s  %d%%" % ["[조절] " if slider.has_focus() else "", pair[1], value])
		slider.focus_entered.connect(func(): label.text = "[조절] %s  %d%%" % [pair[1], slider.value]; label.add_theme_color_override("font_color", GOLD))
		slider.focus_exited.connect(func(): label.text = "%s  %d%%" % [pair[1], slider.value]; label.add_theme_color_override("font_color", PAPER))
		box.add_child(slider)
	_add_label(box, "BGM: Sunrise Over the Elder Grove\n전체 음소거는 M. 효과음 미리 듣기는 현재 음량으로 재생합니다.", 14, MUTED)
	_add_button(box, "효과음 미리 듣기", sound.play_rarity.bind(4), 44)
	_add_button(box, "전체 소리 " + ("켜기" if muted else "끄기"), _settings_mute, 44)
	_add_button(box, "저장하고 닫기", _close_settings, 44)
	if not sound.settings_error.is_empty():
		_add_label(box, sound.settings_error, 14, RED)
	_finish_panel()
	box.find_child("master", true, false).grab_focus()

func _settings_mute() -> void:
	_toggle_sound()
	_show_settings(settings_return)

func _close_settings() -> void:
	if not testing and not sound.save_settings():
		_notify(sound.settings_error + " 기존 설정 파일은 보존됩니다.")
	if settings_return == "hub":
		_show_hub()
	else:
		_show_pause()

func _show_map() -> void:
	state = "map"
	var box = _new_panel("성소의 발자취", "탐험은 일곱 방으로 이어집니다. 물음표는 아직 선택하지 않은 길입니다.", 730)
	var descriptions = ""
	for i in 7:
		var marker = "현재" if i == depth else ("완료" if i < depth else "미탐험")
		var kind = visited[i] if i < visited.size() else ""
		descriptions += "%02d   %s   %s\n" % [i + 1, marker, _kind_name(kind) if not kind.is_empty() else "?"]
	_add_label(box, descriptions.strip_edges(), 19, PAPER)
	_add_label(box, "현재 방의 형상과 남은 적은 우상단 미니맵에 표시됩니다.", 15, MUTED)
	_add_button(box, "지도를 접고 탐험 계속", _resume_room, 46)
	_finish_panel()

func _kind_name(kind: String) -> String:
	return {"battle": "이끼 숲길", "elite": "가시의 시련", "treasure": "묻힌 보물", "rest": "이슬의 샘", "shop": "숲길의 상인", "boss": "뿌리의 옥좌"}.get(kind, "야영지")

func _toggle_sound() -> void:
	muted = not muted
	sound.set_muted(muted)
	_notify("소리 " + ("꺼짐" if muted else "켜짐"))

func _new_panel(title: String, subtitle: String, width: float) -> VBoxContainer:
	_close_overlay()
	buttons.clear()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var dim = ColorRect.new()
	dim.color = Color(0.04, 0.04, 0.06, 0.82)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = width
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#182d29")
	style.border_color = Color("#b89a61")
	style.set_border_width_all(2)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)
	var box = VBoxContainer.new()
	box.add_theme_constant_override("separation", 9)
	panel.add_child(box)
	_add_label(box, title, 30, GOLD)
	_add_label(box, subtitle, 15, MUTED)
	var separator = HSeparator.new()
	box.add_child(separator)
	return box

func _add_label(box: VBoxContainer, text: String, size: int, color: Color) -> Label:
	var label = Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(label)
	return label

func _add_button(box: VBoxContainer, text: String, action: Callable, height: float) -> Button:
	var button = Button.new()
	button.text = text
	button.custom_minimum_size.y = height
	button.add_theme_font_override("font", font)
	button.add_theme_font_size_override("font_size", 17)
	button.add_theme_color_override("font_color", PAPER)
	button.add_theme_color_override("font_hover_color", GOLD)
	button.add_theme_color_override("font_focus_color", GOLD)
	button.add_theme_color_override("font_disabled_color", Color("#9aada5"))
	for style_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color("#30423b") if style_name != "hover" else Color("#485342")
		style.border_color = GOLD if style_name == "focus" else Color("#8b7b6c")
		style.set_border_width_all(2 if style_name == "focus" else 1)
		style.content_margin_left = 12
		style.content_margin_right = 12
		button.add_theme_stylebox_override(style_name, style)
	button.pressed.connect(action)
	box.add_child(button)
	buttons.append(button)
	return button

func _finish_panel() -> void:
	for button in buttons:
		if not button.disabled:
			button.grab_focus()
			break

func _close_overlay() -> void:
	if is_instance_valid(overlay):
		ui.remove_child(overlay)
		overlay.queue_free()
	overlay = null
	buttons.clear()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pointer_position = event.position

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if state == "playing":
					_show_pause()
				elif state in ["pause", "route", "map"]:
					_resume_room()
				elif state == "inventory":
					_close_build()
				elif state == "settings":
					_close_settings()
				elif state == "hub":
					_show_settings("hub")
				elif state == "shop":
					_leave_shop()
				elif state == "rest":
					_resume_room()
				elif state == "reward":
					_defer_reward()
				elif state == "help":
					_close_help(previous_state)
			KEY_TAB:
				if state == "playing":
					previous_state = "playing"
					_show_help("playing")
			KEY_T:
				mouse_aim = not mouse_aim
				facing = last_move
				_notify("조준: " + ("마우스" if mouse_aim else "이동 방향 (키보드)"))
			KEY_M:
				_toggle_sound()
				if state == "settings":
					_show_settings(settings_return)
			KEY_I:
				if state == "playing":
					_show_inventory()
				elif state == "inventory":
					_close_build()
			KEY_G:
				if state == "playing":
					_show_map()
				elif state == "map":
					_resume_room()
			KEY_V:
				effects_enabled = not effects_enabled
				if is_instance_valid(overlay):
					for control in overlay.find_children("*", "Control", true, false):
						if control.get_script() == RarityEffect:
							control.animate = effects_enabled
							control.queue_redraw()
				_notify("화면 흔들림·섬광 " + ("켜짐" if effects_enabled else "꺼짐"))
			KEY_R:
				if state == "dead" or state == "victory":
					_start_run()
			KEY_1, KEY_2, KEY_3:
				if state == "reward":
					_choose_relic(event.physical_keycode - KEY_1)

func _notify(message: String) -> void:
	toast = message
	toast_time = 3.5

func _room_title() -> String:
	match room_type:
		"boss": return "07  뿌리의 옥좌"
		"treasure": return "%02d  묻힌 보물" % (depth + 1)
		"rest": return "%02d  이슬의 샘" % (depth + 1)
		"shop": return "%02d  숲길의 거래" % (depth + 1)
		"elite": return "%02d  가시의 시련" % (depth + 1)
	return "%02d  " % (depth + 1) + ["숲의 문턱", "이끼 숲길", "잠든 정원", "뿌리의 쉼터", "새벽의 공터", "수호자의 길"][mini(depth, 5)]

func _room_objective() -> String:
	if reward_deferred:
		return "중앙 제단에서 E: 남겨 둔 보상"
	if room_clear:
		return "미니맵의 출구 또는 경로판에서 E"
	if room_type == "treasure":
		return "보물상자 가까이에서 E"
	if room_type == "rest":
		return "샘 가까이에서 E"
	if room_type == "shop":
		return "상인 가까이에서 E"
	if room_type == "boss":
		return "수호자를 처치하세요"
	return "남은 적 %d" % enemies.size()

func _clock(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _project(pos: Vector2) -> Vector2:
	return GROUND_X * pos.x + GROUND_Y * pos.y

func _unproject(pos: Vector2) -> Vector2:
	return Vector2(pos.x / (2 * GROUND_X.x) + pos.y / (2 * GROUND_X.y), -pos.x / (2 * GROUND_X.x) + pos.y / (2 * GROUND_X.y))

func _screen_to_world(pos: Vector2) -> Vector2:
	return _unproject(pos - view_offset)

func _aim_world_point(pos: Vector2) -> Vector2:
	var target = _screen_to_world(pos)
	var closest = INF
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		var foot = _project(enemy.pos) + view_offset
		var height = 130.0 if enemy.kind == "boss" else (88.0 if enemy.kind == "brute" else 62.0)
		var half_width = height * 0.36
		if Rect2(foot - Vector2(half_width, height), Vector2(half_width * 2, height + 4)).has_point(pos):
			var distance = pos.distance_squared_to(foot - Vector2(0, height * 0.5))
			if distance < closest:
				closest = distance
				target = enemy.pos
	return target

func _screen_movement(direction: Vector2) -> Vector2:
	return _unproject(direction).normalized() * direction.length()

func _ground_transform() -> void:
	draw_set_transform_matrix(Transform2D(GROUND_X, GROUND_Y, view_offset))

func _billboard(pos: Vector2) -> void:
	draw_set_transform(_project(pos) + view_offset)

func _build_forest_border() -> void:
	forest_trees.clear()
	for i in 22:
		var x = ARENA.position.x - 45 + i * 68
		var y = ARENA.position.y - 40 + i * 42
		forest_trees.append(Vector2(x, ARENA.position.y - 45 - (i * 17) % 65))
		forest_trees.append(Vector2(x, ARENA.end.y + 70 + (i * 31) % 45))
		if i < 21:
			forest_trees.append(Vector2(ARENA.position.x - 60 - (i * 19) % 45, y))
			forest_trees.append(Vector2(ARENA.end.x + 65 + (i * 23) % 55, y))

func _draw() -> void:
	if sprites.is_empty():
		return
	draw_rect(Rect2(0, 0, 960, 540), Color("#102b28"))
	view_offset = Vector2(480, 300) - _project(camera_position)
	if effects_enabled:
		view_offset += Vector2(sin(time * 97), cos(time * 83)) * shake
	view_offset = view_offset.round()
	_ground_transform()
	_draw_room()
	_draw_entities()
	_draw_interaction_labels()
	draw_set_transform(Vector2.ZERO)
	_draw_forest_light()
	if effects_enabled and screen_flash > 0:
		draw_rect(Rect2(0, 0, 960, 540), Color(1.0, 0.82, 0.53, screen_flash * 0.6))
	_draw_hud()

func _draw_room() -> void:
	draw_rect(ARENA.grow(350), Color("#18382f"))
	draw_rect(ARENA.grow(48), Color("#254436"))
	draw_rect(ARENA, Color("#39543a"))
	for y in 26:
		for x in 43:
			var pos = ARENA.position + Vector2(x * 32, y * 32)
			if not Rect2(-70, -70, 1100, 680).has_point(_project(pos) + view_offset):
				continue
			var hash_value = absi(x * 37 + y * 131 + room_seed)
			var patch = Color("#3c583b") if hash_value % 3 else Color("#345138")
			var patch_points = PackedVector2Array([pos + Vector2(2, 10), pos + Vector2(18, 1), pos + Vector2(33, 11), pos + Vector2(29, 27), pos + Vector2(10, 33)])
			draw_colored_polygon(patch_points, patch)
	for path in room_paths:
		_draw_forest_path(PackedVector2Array(path))
	for i in 150:
		var p = Vector2(90 + (i * 137 + room_seed) % 1310, 175 + (i * 193) % 750)
		var blade_color = Color("#7b9355") if i % 4 == 0 else Color("#547444")
		for blade in 3:
			var grass = p + Vector2(blade * 5, 0)
			draw_line(grass, grass + Vector2(blade * 3 - 5, -6 - i % 8), blade_color, 2)
		if i % 7 == 0:
			draw_circle(p + Vector2(-3, -5), 3, Color("#c2bd7a"))
			draw_circle(p + Vector2(3, -8), 2, Color("#e1d4a0"))
		if i % 9 == 0:
			draw_arc(p, 19, 0.2, 2.6, 7, Color("#263f31"), 4)
	for mark in floor_marks:
		draw_ellipse_shadow(mark.pos, Vector2(18, 7))
		for i in 5:
			draw_rect(Rect2(mark.pos + Vector2(i * 7 - 16, (i * 11) % 13 - 5), Vector2(4, 3)), Color("#66503a"))
	if room_type == "boss":
		for i in 9:
			var direction = Vector2.from_angle(i * TAU / 9)
			var points = PackedVector2Array([ALTAR + direction * 250, ALTAR + direction.rotated(0.13) * 170, ALTAR + direction * 90])
			draw_polyline(points, Color("#243c2e"), 15)
			draw_polyline(points, Color("#78653f"), 5)
	_draw_floor_emblem(ALTAR)
	if reward_deferred:
		_draw_sprite("chest", ALTAR, 3)
	_draw_gate(PORTAL, room_clear)
	_draw_gate(WEST_GATE, room_clear)
	_draw_gate(EAST_GATE, room_clear)
	if room_clear:
		var gate_direction = (PORTAL - player).normalized()
		draw_line(player + gate_direction * 42, player + gate_direction * 53, GOLD, 3)
	if room_type == "treasure" and not room_clear:
		_draw_sprite("chest", ALTAR, 3)
	if room_type == "rest" and not room_clear:
		draw_circle(ALTAR, 54, Color("#658064"))
		draw_circle(ALTAR, 44, Color("#254d48"))
		draw_arc(ALTAR, 37, 0, TAU, 32, MINT, 3)
		for i in 5:
			draw_arc(ALTAR, 9 + fmod(time * 12 + i * 7, 26), 0, TAU, 20, Color("#5c9588"), 1)
	if room_type == "shop":
		draw_rect(Rect2(ALTAR - Vector2(42, 15), Vector2(84, 30)), Color("#8f6950"))
		_draw_sprite("archer", ALTAR + Vector2(0, -25), 2, Color("#edc993"))
		_draw_sprite("chest", ALTAR + Vector2(-30, 10), 2)
	for i in 22:
		var p = Vector2(80 + fposmod(i * 137.0 + sin(time * 0.3 + i) * 24, 1300), 140 + fposmod(i * 79.0 - time * (4 + i % 3), 790))
		draw_rect(Rect2(p, Vector2(2, 2)), Color(0.8, 0.72, 0.42, 0.25 + sin(time + i) * 0.15))

func _draw_forest_path(points: PackedVector2Array) -> void:
	var curve = Curve2D.new()
	for i in points.size():
		var tangent = Vector2.ZERO
		if i > 0 and i < points.size() - 1:
			tangent = (points[i + 1] - points[i - 1]) * 0.13
		curve.add_point(points[i], -tangent, tangent)
	var trail = curve.get_baked_points()
	draw_polyline(trail, Color("#304b33"), 124)
	draw_polyline(trail, Color("#6b6948"), 91)
	draw_polyline(trail, Color("#817552"), 65)
	draw_polyline(trail, Color("#8a7b57"), 34)

func _draw_forest_light() -> void:
	for i in 3:
		var x = 90.0 + i * 330 - fposmod(_project(camera_position).x * 0.16, 120)
		var beam = PackedVector2Array([Vector2(x, -20), Vector2(x + 45, -20), Vector2(x + 310, 540), Vector2(x + 180, 540)])
		draw_colored_polygon(beam, Color(0.87, 0.89, 0.57, 0.035))
	for i in 24:
		var pos = Vector2(fposmod(i * 137.0 - _project(camera_position).x * 0.15, 960), fposmod(i * 83.0 + time * (3 + i % 4) - _project(camera_position).y * 0.1, 540))
		draw_circle(pos, 1.2, Color(0.94, 0.86, 0.55, 0.2 + sin(time + i) * 0.12))

func _draw_obstacle(pos: Vector2) -> void:
	_draw_tree(pos, int(pos.x) % 5)

func _draw_tree(pos: Vector2, variant: int) -> void:
	var at = _project(pos) + view_offset
	if not Rect2(-80, -50, 1120, 790).has_point(at):
		return
	var diff = _project(player) - _project(pos)
	var alpha = 0.28 if absf(diff.x) < 65 and diff.y < 12 and diff.y > -155 else 1.0
	_billboard(pos)
	var size_factor = 0.88 + posmod(variant, 5) * 0.06
	draw_set_transform(at, 0, Vector2.ONE * size_factor)
	ForestArt.tree(self, variant, alpha)
	_ground_transform()

func _draw_structure(rect: Rect2) -> void:
	if rect.position.x == ARENA.position.x or rect.end.x == ARENA.end.x:
		draw_rect(rect, Color("#203e30"))
		for x in range(int(rect.position.x) + 25, int(rect.end.x), 65):
			for y in range(int(rect.position.y) + 40, int(rect.end.y), 90):
				_draw_tree(Vector2(x, y), x + y)
		return
	var corners = PackedVector2Array([
		rect.position + Vector2(12, 0), Vector2(rect.end.x - 12, rect.position.y),
		Vector2(rect.end.x, rect.position.y + 12), rect.end - Vector2(0, 12),
		rect.end - Vector2(12, 0), Vector2(rect.position.x + 12, rect.end.y),
		Vector2(rect.position.x, rect.end.y - 12), rect.position + Vector2(0, 12)])
	var top = PackedVector2Array()
	var base = PackedVector2Array()
	for point in corners:
		base.append(_project(point) + view_offset)
		top.append(_project(point) + view_offset - Vector2(0, 32 + top.size() % 3 * 4))
	draw_set_transform(Vector2.ZERO)
	for i in 8:
		var next = (i + 1) % 8
		if absf(base[i].x - base[next].x) < 0.1:
			continue
		draw_colored_polygon(PackedVector2Array([top[i], base[i], base[next], top[next]]), Color("#3f5140") if i < 4 else Color("#2c4034"))
	draw_colored_polygon(top, Color("#738365"))
	draw_polyline(PackedVector2Array([top[7], top[0], top[1], top[2]]), Color("#b0ac7c"), 2)
	var center = (_project(rect.get_center()) + view_offset) - Vector2(0, 35)
	for i in 4:
		draw_line(top[i * 2].lerp(center, 0.15), center + Vector2(i * 4 - 8, i % 2 * 4), Color("#4b5c43"), 2)
	draw_colored_polygon(PackedVector2Array([top[5], top[6], top[7].lerp(center, 0.4), center, top[4].lerp(center, 0.5)]), Color("#577547"))
	_ground_transform()

func _draw_breakable(prop: Dictionary) -> void:
	_billboard(prop.pos)
	if prop.hp <= 0:
		for i in 4:
			draw_line(Vector2(i * 6 - 10, i % 2 * 3), Vector2(i * 6 - 7, -5), Color("#977549"), 3)
		_ground_transform()
		return
	ForestArt.ellipse(self, Vector2(3, 3), Vector2(19, 7), Color(0.03, 0.09, 0.07, 0.45))
	if prop.kind == "crate":
		ForestArt.polygon(self, [Vector2(-16, -23), Vector2(0, -31), Vector2(17, -23), Vector2(17, -1), Vector2(0, 7), Vector2(-16, -1)], Color("#4a3528"))
		ForestArt.polygon(self, [Vector2(-14, -22), Vector2(0, -28), Vector2(14, -22), Vector2(0, -15)], Color("#b18e57"))
		ForestArt.polygon(self, [Vector2(-14, -20), Vector2(-1, -13), Vector2(-1, 4), Vector2(-14, -3)], Color("#937044"))
		ForestArt.polygon(self, [Vector2(1, -13), Vector2(14, -20), Vector2(14, -3), Vector2(1, 4)], Color("#6c5033"))
		draw_line(Vector2(-12, -18), Vector2(-3, 0), Color("#d4ac68"), 2)
		draw_line(Vector2(3, -1), Vector2(12, -17), Color("#b99156"), 2)
	else:
		ForestArt.polygon(self, [Vector2(-7, -30), Vector2(7, -30), Vector2(5, -24), Vector2(13, -16), Vector2(11, 0), Vector2(-8, 2), Vector2(-13, -14), Vector2(-5, -24)], Color("#a18e66"))
		ForestArt.ellipse(self, Vector2(0, -30), Vector2(8, 3), Color("#ded0a0"))
		draw_line(Vector2(-7, -18), Vector2(-5, -2), Color("#dfcc99"), 3)
	_ground_transform()

func _draw_gate(pos: Vector2, opened: bool) -> void:
	draw_circle(pos, 30, Color("#7b7850") if opened else Color("#354c34"))
	_billboard(pos)
	ForestArt.polygon(self, [Vector2(-32, 3), Vector2(-29, -48), Vector2(-20, -65), Vector2(-15, -41), Vector2(-21, -2)], Color("#64553a"))
	ForestArt.polygon(self, [Vector2(21, 1), Vector2(16, -47), Vector2(24, -62), Vector2(33, -44), Vector2(34, 4)], Color("#4c4934"))
	draw_polyline(PackedVector2Array([Vector2(-25, -40), Vector2(-10, -60), Vector2(11, -66), Vector2(26, -43)]), Color("#8b8350"), 7)
	draw_line(Vector2(-22, -47), Vector2(-11, -57), Color("#b9ab72"), 2)
	if opened:
		for i in 4:
			draw_circle(Vector2(-15 + i * 9, -fmod(time * 24 + i * 9, 50)), 2, GOLD)
	else:
		for i in 3:
			draw_line(Vector2(-20, -13 - i * 13), Vector2(20, -29 - i * 8), Color("#96784c"), 4)
	_ground_transform()

func _draw_interaction_labels() -> void:
	if state == "hub":
		return
	if reward_deferred:
		_world_label(ALTAR, "[E]  남겨 둔 보상", GOLD)
	elif room_type == "treasure" and not room_clear:
		_world_label(ALTAR, "[E]  증강 보상", GOLD)
	elif room_type == "rest" and not room_clear:
		_world_label(ALTAR, "[E]  이슬의 샘", MINT)
	elif room_type == "shop":
		_world_label(ALTAR, "[E]  숲길의 상인", GOLD)
	if room_clear:
		_world_label(PORTAL, "[E]  경로 선택", GOLD)
		_world_label(WEST_GATE, "[E]  " + ("옥좌" if depth >= 5 else ("휴식" if depth == 2 else "숲길")), GOLD)
		_world_label(EAST_GATE, "[E]  " + ("옥좌" if depth >= 5 else ("보물" if depth == 2 else "시련")), GOLD)

func _world_label(pos: Vector2, text: String, color: Color) -> void:
	_billboard(pos)
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_rect(Rect2(Vector2(-width / 2 - 7, -88), Vector2(width + 14, 25)), Color("#182d29"))
	_text(Vector2(0, -70), text, 14, color, true)
	_ground_transform()

func _draw_floor_emblem(center: Vector2) -> void:
	var color = Color("#899666")
	draw_arc(center, 82, 0, TAU, 32, color, 2)
	draw_arc(center, 68, 0, TAU, 32, color, 1)
	for i in 8:
		var direction = Vector2.from_angle(i * TAU / 8)
		draw_line(center + direction * 68, center + direction * 82, color, 3)
	draw_polyline(PackedVector2Array([center + Vector2(0, -38), center + Vector2(21, 2), center + Vector2(0, 37), center + Vector2(-21, 2), center + Vector2(0, -38)]), color, 3)

func _draw_entities() -> void:
	for zone in elemental.zones:
		var color = _element_color("불" if zone.name == "용암" else "땅")
		draw_circle(zone.pos, Elements.RADIUS, Color(color, 0.16))
		draw_arc(zone.pos, Elements.RADIUS, 0, TAU, 40, color, 3)
	for seed_item in elemental.seeds:
		draw_circle(seed_item.pos, 12 + sin(time * 8) * 3, _element_color("풀"))
	for hazard in hazards:
		var color = RED if hazard.timer > 0 else GOLD
		draw_circle(hazard.pos, 46, Color(color, 0.15))
		draw_arc(hazard.pos, 46, 0, TAU, 24, color, 2)
		if hazard.timer > 0:
			draw_arc(hazard.pos, 46 * (1 - hazard.timer / 0.95), 0, TAU, 24, RED, 2)
		else:
			draw_line(hazard.pos + Vector2(0, 15), hazard.pos + Vector2(0, -65), GOLD, 9)
	for pickup in pickups:
		var p: Vector2 = pickup.pos + Vector2(0, sin(time * 5 + pickup.pos.x) * 3)
		draw_rect(Rect2(p - Vector2(3, 3), Vector2(6, 6)), GOLD)
		draw_rect(Rect2(p - Vector2(1, 2), Vector2(2, 3)), PAPER)
	for trail in trails:
		_draw_sprite("hero", trail.pos, 2, Color(0.49, 0.87, 0.85, trail.life * 2))
	var actors: Array = enemies.duplicate()
	actors.append({"kind": "hero", "pos": player})
	for i in forest_trees.size():
		actors.append({"kind": "tree", "pos": forest_trees[i], "variant": i})
	for pos in obstacles:
		actors.append({"kind": "wall", "pos": pos})
	for rect in structures:
		actors.append({"kind": "structure", "pos": rect.end, "rect": rect})
	for prop in breakables:
		actors.append({"kind": "prop", "pos": prop.pos, "data": prop})
	actors.sort_custom(func(a, b): return _project(a.pos).y < _project(b.pos).y)
	for actor in actors:
		if actor.kind == "hero":
			_draw_player()
		elif actor.kind == "wall":
			_draw_obstacle(actor.pos)
		elif actor.kind == "tree":
			_draw_tree(actor.pos, actor.variant)
		elif actor.kind == "structure":
			_draw_structure(actor.rect)
		elif actor.kind == "prop":
			_draw_breakable(actor.data)
		else:
			_draw_enemy(actor)
	for projectile in projectiles:
		var tail: Vector2 = projectile.pos - projectile.velocity.normalized() * 12
		draw_line(tail, projectile.pos, RED, 5)
		draw_rect(Rect2(projectile.pos - Vector2(3, 3), Vector2(6, 6)), GOLD)
	for particle in particles:
		draw_line(particle.pos, particle.pos - particle.velocity.normalized() * particle.size * 2, particle.color, 2)
	for impact in impacts:
		if impact.kind == "chain":
			var points = PackedVector2Array()
			for i in 9:
				var point: Vector2 = impact.pos.lerp(impact.end, i / 8.0)
				if i > 0 and i < 8:
					point += Vector2(sin(i * 37) * 7, cos(i * 17) * 7)
				points.append(point)
			draw_polyline(points, MINT, 4)
			draw_polyline(points, PAPER, 1)
		elif impact.kind == "element":
			var radius: float = impact.radius * (1.0 - impact.life / 0.3)
			draw_arc(impact.pos, maxf(1, radius), 0, TAU, 40, _element_color(impact.element), 4)
		else:
			var ratio: float = impact.life / 0.16
			for i in 6:
				var direction = Vector2.from_angle(impact.angle + i * TAU / 6)
				draw_line(impact.pos + direction * 3, impact.pos + direction * (28 * ratio + 8), GOLD if impact.critical else PAPER, 3)
			draw_line(impact.pos - Vector2(0, 19 * ratio), impact.pos + Vector2(0, 19 * ratio), GOLD, 4)
	for number in numbers:
		_billboard(number.pos)
		var rise: float = (0.7 - number.life) * 40 + 25
		var width = font.get_string_size(number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_rect(Rect2(Vector2(-width / 2 - 3, -rise - 19), Vector2(width + 6, 24)), Color("#182d29"))
		_text(Vector2(0, -rise), number.text, 19, number.color, true)
		_ground_transform()

func _draw_sprite(kind: String, pos: Vector2, scale_factor: float, tint: Color = Color.WHITE) -> void:
	_billboard(pos)
	if kind in ["hero", "crawler", "archer", "brute", "boss"]:
		ForestArt.character(self, kind, time * 5 + pos.x, _project(facing).normalized(), tint.r > 2, tint.a)
	elif kind == "chest":
		ForestArt.chest(self, scale_factor / 3.0)
	else:
		draw_texture_rect(sprites[kind], Rect2(-Vector2(8, 13) * scale_factor, Vector2(16, 16) * scale_factor), false, tint)
	_ground_transform()

func draw_ellipse_shadow(pos: Vector2, size: Vector2) -> void:
	_billboard(pos)
	ForestArt.ellipse(self, Vector2.ZERO, size, Color(0.02, 0.07, 0.04, 0.5))
	_ground_transform()

func _draw_player() -> void:
	draw_ellipse_shadow(player + Vector2(0, 4), Vector2(14, 5))
	var tint = Color.WHITE
	if invulnerable > 0 and int(time * 16) % 2:
		tint = Color(1, 1, 1, 0.45)
	var walking = Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.1 and state == "playing"
	_billboard(player)
	ForestArt.character(self, "hero", time * 14 if walking else 0.0, _project(facing).normalized(), false, tint.a)
	var sword_direction = facing
	if slash_time > 0:
		var swing = 1.0 - slash_time / (0.30 if slash_heavy else 0.21)
		sword_direction = Vector2.from_angle(slash_angle + lerpf(-1.25, 1.25, swing) * (1 if combo % 2 else -1))
	elif not pending_strike.is_empty():
		sword_direction = facing.rotated(-1.2)
	sword_direction = _project(sword_direction).normalized()
	var hand = sword_direction * 13 + Vector2(0, -26)
	var blade = sword_direction * 36
	draw_line(hand, hand + blade, PAPER, 5)
	draw_line(hand - sword_direction * 3, hand + sword_direction * 3, GOLD, 7)
	draw_line(hand - sword_direction * 9, hand - sword_direction * 3, Color("#a27047"), 4)
	_ground_transform()
	if not mouse_aim:
		draw_line(player + facing * 36, player + facing * 43, GOLD, 3)
	if slash_time > 0:
		var radius = 136.0 if slash_heavy else attack_range + (22 if dash_attack else 0)
		var progress = 1.0 - slash_time / (0.30 if slash_heavy else 0.21)
		var color = GOLD if slash_heavy or combo == 3 else PAPER
		if slash_heavy:
			draw_arc(slash_origin, radius * (0.35 + progress * 0.65), 0, TAU, 48, Color(GOLD, 1 - progress), 8 * (1 - progress) + 1)
			for i in 8:
				var dir = Vector2.from_angle(i * TAU / 8)
				draw_line(slash_origin + dir * radius * progress * 0.6, slash_origin + dir * radius * progress, Color(PAPER, 1 - progress), 3)
		else:
			var arc_points = PackedVector2Array()
			var start = slash_angle - 1.35
			var end = slash_angle + 1.35
			for i in 25:
				var t = i / 24.0
				arc_points.append(slash_origin + Vector2.from_angle(lerpf(start, end, t)) * radius * (0.78 + progress * 0.22))
			for i in range(23, 0, -1):
				var t = i / 24.0
				var inner = radius * (0.78 + progress * 0.22) - sin(t * PI) * maxf(2, 19 * (1 - progress))
				arc_points.append(slash_origin + Vector2.from_angle(lerpf(start, end, t)) * inner)
			draw_colored_polygon(arc_points, Color(color, 1 - progress))
			draw_arc(slash_origin, radius * 0.68, start + 0.2, end - 0.2, 24, Color(MINT, (1 - progress) * 0.7), 2)

func _draw_enemy(enemy: Dictionary) -> void:
	var radius = _enemy_radius(enemy)
	draw_ellipse_shadow(enemy.pos + Vector2(0, 5), Vector2(radius + 5, radius * 0.4))
	if enemy.windup > 0:
		var aim: Vector2 = (enemy.target - enemy.pos).normalized()
		if enemy.kind == "archer":
			draw_line(enemy.pos, enemy.pos + aim * 260, Color(RED, 0.5), 2)
		elif enemy.kind == "boss":
			draw_arc(enemy.pos, 55 + sin(time * 15) * 4, 0, TAU, 32, RED, 3)
		else:
			draw_arc(enemy.pos, 60 if enemy.kind == "brute" else 46, aim.angle() - 1.0, aim.angle() + 1.0, 20, RED, 4)
	_billboard(enemy.pos)
	var aim_direction: Vector2 = (player - enemy.pos).normalized()
	ForestArt.character(self, enemy.kind, time * 9 + enemy.pos.x, _project(aim_direction).normalized(), enemy.flash > 0)
	if enemy.elite:
		draw_arc(Vector2(0, -46), 26, PI, TAU, 16, GOLD, 2)
	if not enemy.status.is_empty():
		var status_names = PackedStringArray()
		for key in enemy.status:
			var effect: Dictionary = enemy.status[key]
			var label: String = effect.get("name", key)
			if label not in status_names:
				status_names.append(label)
		_actor_label(Vector2(0, 19), " / ".join(status_names), 11, PAPER)
	if elemental.active(enemy, "빙결"):
		draw_arc(Vector2(0, -20), 28, 0, TAU, 6, _element_color("얼음"), 4)
	elif elemental.active(enemy, "생장"):
		draw_arc(Vector2(0, -4), 22, 0, TAU, 12, _element_color("풀"), 4)
	if enemy.kind != "boss":
		_actor_label(Vector2(0, -100 if enemy.kind == "brute" else -80), enemy.element, 12, _element_color(enemy.element))
		if enemy.hp < enemy.max_hp or enemy.windup > 0:
			var pos = Vector2(-22, -89 if enemy.kind == "brute" else -70)
			_bar(Rect2(pos, Vector2(44, 4)), enemy.hp / enemy.max_hp, GOLD if enemy.elite else RED)
	_ground_transform()

func _actor_label(pos: Vector2, label: String, size: int, color: Color) -> void:
	var width = font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_rect(Rect2(pos - Vector2(width / 2 + 3, size + 1), Vector2(width + 6, size + 5)), Color("#182d29"))
	_text(pos, label, size, color, true)

func _draw_hud() -> void:
	_hud_panel(Rect2(14, 449, 245, 77))
	draw_set_transform(Vector2(37, 499), 0, Vector2(0.65, 0.65))
	ForestArt.character(self, "hero", 0, Vector2.RIGHT)
	draw_set_transform(Vector2.ZERO)
	_bar(Rect2(60, 459, 182, 17), hp / max_hp, Color("#9f453f"))
	_text(Vector2(151, 472), "%d / %d" % [ceili(hp), int(max_hp)], 12, PAPER, true)
	_bar(Rect2(60, 480, 182, 4), float(experience) / _experience_needed(), Color("#5c9c99"))
	_text(Vector2(60, 500), "Lv.%d   EXP %d / %d" % [level, experience, _experience_needed()], 11, PAPER)
	for i in 2:
		draw_rect(Rect2(27 + i * 20, 510, 14, 5), MINT if i < dash_charges else Color("#4c565d"))
	_text(Vector2(73, 519), "회피 %d/2  /  " % dash_charges + ("마우스 조준" if mouse_aim else "이동 조준"), 11, MUTED)
	_hud_panel(Rect2(14, 14, 224, 49))
	_text(Vector2(27, 35), "I  새벽의 숲", 19, GOLD)
	_text(Vector2(27, 53), ForestMaps.NAMES[room_layout], 11, MUTED)
	_hud_panel(Rect2(335, 14, 290, 53))
	_text(Vector2(480, 36), _room_title(), 17, PAPER, true)
	_text(Vector2(480, 56), _room_objective(), 12, MINT, true)
	_draw_minimap()
	_hud_panel(Rect2(271, 468, 442, 58))
	_ability(281, "J / 클릭", "베기", attack_cd, attack_interval * 1.15, 0)
	_ability(385, "Q / 우클릭", "불씨", skill_cd, skill_duration, 1)
	_ability(501, "Space", "회피", dash_cd if dash_charges == 0 else 0, dash_duration, 2)
	_ability(609, "F x%d" % flasks, "회복약", 0, 1, 3)
	_hud_panel(Rect2(14, 74, 172, 40))
	_text(Vector2(24, 91), "속성: " + hero.element, 13, _element_color(hero.element))
	_text(Vector2(24, 107), "증강 %d개 / I 상세" % augments.size(), 11, PAPER)
	if hero.shield > 0 and hero.shield_until > elemental.clock:
		_text(Vector2(60, 447), "보호막 %d" % hero.shield, 12, MINT)
	var status_y = 133
	for status_name in hero.status:
		var display: String = hero.status[status_name].get("name", status_name)
		_hud_panel(Rect2(14, status_y - 14, 172, 20))
		_text(Vector2(24, status_y), display, 12, RED)
		status_y += 22
	_hud_panel(Rect2(738, 464, 208, 62))
	_text(Vector2(750, 486), "금화 %d   불씨 %d" % [gold, run_embers], 14, GOLD)
	_text(Vector2(750, 505), "I 증강  G 지도  Esc 설정", 12, PAPER)
	_text(Vector2(750, 521), "E 상호작용   %s" % _clock(run_time), 11, MUTED)
	if toast_time > 0:
		var text_width = font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_hud_panel(Rect2(480 - text_width / 2 - 16, 410, text_width + 32, 30))
		_text(Vector2(480, 431), toast, 16, GOLD, true)
	for enemy in enemies:
		if enemy.kind == "boss":
			_hud_panel(Rect2(280, 75, 400, 42))
			_bar(Rect2(290, 99, 380, 8), enemy.hp / enemy.max_hp, Color("#9f453f"))
			_text(Vector2(480, 92), "가시 왕관의 수호자 [" + enemy.element + "]" + (" / 분노" if enemy.phase == 1 else ""), 13, PAPER, true)

func _hud_panel(rect: Rect2) -> void:
	draw_rect(rect, Color("#182d29"))
	draw_rect(rect, Color("#a18858"), false, 1)
	draw_line(rect.position + Vector2(8, 3), rect.position + Vector2(34, 3), GOLD, 2)
	draw_line(rect.end - Vector2(34, 3), rect.end - Vector2(8, 3), GOLD, 2)

func _draw_minimap() -> void:
	var panel = Rect2(793, 14, 153, 124)
	_hud_panel(panel)
	var mini = Rect2(805, 25, 129, 79)
	draw_rect(mini, Color("#151c27"))
	var boundary = PackedVector2Array()
	for corner in [ARENA.position, Vector2(ARENA.end.x, ARENA.position.y), ARENA.end, Vector2(ARENA.position.x, ARENA.end.y), ARENA.position]:
		boundary.append(_minimap_position(corner, mini))
	draw_polyline(boundary, Color("#8a9d73"), 2)
	for obstacle in obstacles:
		var at = _minimap_position(obstacle, mini)
		draw_circle(at, 2, Color("#64835a"))
	for structure in structures:
		var corners = PackedVector2Array()
		for corner in [structure.position, Vector2(structure.end.x, structure.position.y), structure.end, Vector2(structure.position.x, structure.end.y)]:
			corners.append(_minimap_position(corner, mini))
		draw_colored_polygon(corners, Color("#88967c"))
	for gate in [PORTAL, WEST_GATE, EAST_GATE]:
		var at = _minimap_position(gate, mini)
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)), GOLD if room_clear else Color("#8c6a5e"))
	for enemy in enemies:
		if enemy.hp > 0 and (enemy.alert or enemy.kind == "boss"):
			var at = _minimap_position(enemy.pos, mini)
			draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), RED)
	var marker = _minimap_position(player, mini)
	draw_rect(Rect2(marker - Vector2(2, 2), Vector2(5, 5)), PAPER)
	_text(Vector2(868, 126), "%d / 7   G 지도" % (depth + 1), 12, PAPER, true)

func _minimap_position(pos: Vector2, rect: Rect2) -> Vector2:
	var scale_factor = minf((rect.size.x - 10) / ((ARENA.size.x + ARENA.size.y) * GROUND_X.x), (rect.size.y - 10) / ((ARENA.size.x + ARENA.size.y) * GROUND_X.y))
	return rect.get_center() + _project(pos - ARENA.get_center()) * scale_factor

func _ability(x: float, key: String, title: String, cooldown: float, full: float, icon: int) -> void:
	var pos = Vector2(x, 480)
	draw_rect(Rect2(pos, Vector2(34, 34)), Color("#244448"))
	var color = GOLD if cooldown <= 0 else MUTED
	match icon:
		0:
			draw_line(pos + Vector2(10, 26), pos + Vector2(25, 7), color, 4)
			draw_line(pos + Vector2(7, 18), pos + Vector2(18, 27), GOLD, 3)
		1:
			draw_arc(pos + Vector2(17, 17), 10, 0, TAU, 8, color, 3)
			draw_line(pos + Vector2(17, 4), pos + Vector2(17, 30), color, 2)
		2:
			for i in 3:
				draw_line(pos + Vector2(6 + i * 7, 24), pos + Vector2(13 + i * 7, 10), color, 3)
		3:
			draw_rect(Rect2(pos + Vector2(10, 11), Vector2(15, 18)), MINT)
			draw_rect(Rect2(pos + Vector2(14, 5), Vector2(7, 6)), GOLD)
	if cooldown > 0:
		draw_rect(Rect2(pos.x, pos.y, 34, 34 * cooldown / full), Color(0.02, 0.08, 0.09, 0.65))
		_text(pos + Vector2(17, 23), "%.1f" % cooldown, 13, PAPER, true)
	_text(pos + Vector2(39, 11), key, 10, color)
	_text(pos + Vector2(39, 29), title, 13, PAPER)

func _bar(rect: Rect2, fraction: float, color: Color) -> void:
	draw_rect(rect, Color("#08171d"))
	draw_rect(Rect2(rect.position, Vector2(rect.size.x * clampf(fraction, 0, 1), rect.size.y)), color)
	draw_rect(rect, Color("#6a8173"), false, 1)

func _text(pos: Vector2, text: String, size: int, color: Color, centered: bool = false) -> void:
	var at = pos
	if centered:
		at.x -= font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x / 2
	draw_string(font, at + Vector2(1, 2), text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color("#08171d"))
	draw_string(font, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)

func _self_test() -> void:
	var checks = 0
	_start_run()
	assert(state == "playing" and enemies.size() == 4)
	checks += 1
	attack_cd = 0
	var target: Dictionary = enemies[0]
	player = target.pos + Vector2(0, 40)
	facing = Vector2.UP
	var old_health: float = target.hp
	_attack(false)
	assert(target.hp == old_health and not pending_strike.is_empty())
	_tick_strike(0.05)
	assert(target.hp < old_health and combo == 1)
	checks += 1
	_dash(Vector2.RIGHT)
	var old_hp = hp
	_hurt(10)
	assert(dash_time > 0 and hp == old_hp)
	checks += 1
	invulnerable = 0
	_hurt(10)
	assert(hp == old_hp - 10)
	hp = 30
	_use_flask()
	assert(hp == 75 and flasks == 1)
	checks += 1
	for i in 6:
		_apply_augment("불" + str(i), 0)
	assert(augments.size() == 6 and _tier("불") == 4)
	assert(_skill_radius() >= 226 and skill_duration < 5.5)
	checks += 1
	for enemy in enemies:
		enemy.hp = 0
	_collect_dead()
	assert(state == "reward" and offered.size() == 3 and total_kills == 4)
	var count = augments.size()
	_choose_relic(1)
	assert(state == "playing" and room_clear and augments.size() == count + 1)
	checks += 1
	player = PORTAL
	_interact()
	assert(state == "route" and buttons.size() == 3)
	buttons[0].pressed.emit()
	assert(depth == 1 and state == "playing")
	checks += 1
	_enter_room(3, "rest")
	player = ALTAR
	_interact()
	assert(state == "rest")
	hp = 1
	buttons[0].pressed.emit()
	assert(room_clear and hp > 1)
	_enter_room(3, "treasure")
	player = ALTAR
	_interact()
	assert(state == "reward")
	_choose_relic(0)
	assert(room_clear)
	checks += 1
	_enter_room(6, "boss")
	var boss: Dictionary = enemies[0]
	boss.cooldown = 0
	_tick_boss(boss, 0.01)
	assert(boss.windup > 0)
	_tick_boss(boss, 1)
	assert(projectiles.size() == 10)
	boss.hp = boss.max_hp * 0.4
	boss.cooldown = 0
	_tick_boss(boss, 0.01)
	assert(boss.phase == 1)
	boss.windup = 0
	boss.attack_index = 2
	boss.cooldown = 0
	_tick_boss(boss, 0.01)
	_tick_boss(boss, 1)
	assert(hazards.size() == 5)
	checks += 1
	boss.hp = 0
	_collect_dead()
	assert(state == "victory" and meta_embers >= 35 and best_depth == 7)
	var settled = meta_embers
	_settle_run(true)
	assert(meta_embers == settled)
	checks += 1
	_show_hub()
	meta_embers = 500
	_buy_upgrade()
	assert(meta_level == 1 and meta_embers == 475)
	_start_run()
	assert(max_hp == 122 and attack_power == 22 and augments.is_empty())
	checks += 1
	_show_pause()
	assert(state == "pause")
	buttons[1].pressed.emit()
	assert(state == "inventory")
	buttons[0].pressed.emit()
	assert(state == "help")
	buttons[0].pressed.emit()
	assert(state == "pause")
	buttons[0].pressed.emit()
	assert(state == "playing")
	checks += 1
	var initial = player
	Input.action_press("move_right")
	_tick_player(0.1)
	Input.action_release("move_right")
	assert(player.x > initial.x)
	var collision = _move_actor(Vector2(100, 200), Vector2(-999, -999), 12)
	assert(ARENA.has_point(collision))
	checks += 1
	_enter_room(0, "battle")
	enemies.clear()
	_apply_augment("불0", 0)
	player = Vector2(480, 340)
	facing = Vector2.UP
	crit_chance = 0
	attack_cd = 0
	hp = 50
	var first = _spawn_enemy("brute", Vector2(480, 290))
	var second = _spawn_enemy("brute", Vector2(510, 290))
	first.hp = 500
	second.hp = 500
	first.element = "풀"
	second.element = "풀"
	_attack(false)
	_tick_strike(0.05)
	assert(not first.status.is_empty() and not second.status.is_empty())
	assert(first.hp < 500 and second.hp < 500)
	assert(hp == 50)
	var before_burn: float = first.hp
	_apply_element_events(elemental.tick(1, _units()))
	assert(first.hp < before_burn)
	invulnerable = 0
	var before_hurt = hp
	_hurt(5)
	assert(hp == before_hurt - 5)
	checks += 1
	skill_cd = 0
	var before_skill: float = first.hp
	_attack(true)
	_tick_strike(0.08)
	assert(is_equal_approx(first.hp, before_skill - _attack_damage(true) * 100.0 / (100.0 + first.defense)) and skill_cd == skill_duration)
	var after_skill: float = first.hp
	_attack(true)
	assert(first.hp == after_skill)
	hp = max_hp
	var before_flasks = flasks
	_use_flask()
	assert(flasks == before_flasks)
	checks += 1
	print("SELF_TEST_PASS: ", checks, " groups: combat, dodge, damage, flasks, augments, synergies, rewards, routes, rest, treasure, boss phases, settlement, upgrades, menus, movement.")
	_close_overlay()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)
