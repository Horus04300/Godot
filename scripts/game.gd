extends Node2D

const Art = preload("res://scripts/pixel_art.gd")
const Sound = preload("res://scripts/sound.gd")
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
const BOARD_COLUMNS = 5
const BOARD_SIZE = 20
const RELICS = [
	{"id": "edge", "name": "01  잿빛 숫돌", "body": "검 공격력 +6\n기본 공격과 불씨 폭발을 함께 강화합니다.", "tag": "공격"},
	{"id": "vital", "name": "02  고목의 심장", "body": "최대 체력 +25, 체력 25 회복\n성소 깊숙이 들어갈 여유를 확보합니다.", "tag": "생존"},
	{"id": "fire", "name": "03  꺼지지 않는 심지", "body": "검에 맞은 적이 3초간 화상\n중첩마다 초당 화상 피해 +6", "tag": "화상"},
	{"id": "leech", "name": "04  뿌리의 송곳니", "body": "기본 공격 적중 시 체력 1 회복\n한 번의 휘두르기로 여러 적을 맞혀 보세요.", "tag": "흡혈"},
	{"id": "storm", "name": "05  울림의 방울", "body": "검 적중 시 가까운 다른 적에게 10 피해\n중첩마다 전이 피해 +10", "tag": "전이"},
	{"id": "stride", "name": "06  순례자의 장화", "body": "이동 속도 +15%, 회피 재사용 -12%\n예고된 공격을 피해 빈틈으로 진입합니다.", "tag": "기동"},
	{"id": "focus", "name": "07  불씨의 렌즈", "body": "불씨 폭발 재사용 시간 -20%\nQ 또는 마우스 오른쪽으로 광역 공격", "tag": "기술"},
	{"id": "reach", "name": "08  길게 드리운 그림자", "body": "검의 사거리 +15\n위험한 적을 더 먼 거리에서 베어냅니다.", "tag": "범위"},
	{"id": "crit", "name": "09  깨진 왕관", "body": "치명타 확률 +18%\n치명타는 피해가 2배입니다.", "tag": "치명"},
	{"id": "thorn", "name": "10  가시 갑옷", "body": "피격 시 주변 적에게 18 피해\n중첩마다 반격 피해 +18", "tag": "반격"},
	{"id": "flask", "name": "11  이슬의 병", "body": "회복약 1개 보충, 회복량 +10\nF로 회복약을 마십니다.", "tag": "회복"},
	{"id": "swift", "name": "12  쌍둥이 깃털", "body": "기본 공격 속도 +16%\n3연격의 마지막 베기는 더 강합니다.", "tag": "연격"}
]

var sprites: Dictionary
var tiles: Array
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
var relics: Dictionary = {}
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
var board: Array[String] = []
var board_selected = -1
var board_buttons: Array[Button] = []
var board_detail: Label
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

func _ready() -> void:
	rng.randomize()
	get_tree().auto_accept_quit = false
	sprites = Art.create_sprites()
	tiles = Art.floor_tiles()
	font = SystemFont.new()
	font.font_names = PackedStringArray(["Malgun Gothic", "Noto Sans CJK KR", "Arial"])
	sound = Sound.new()
	add_child(sound)
	ui = CanvasLayer.new()
	add_child(ui)
	var args = OS.get_cmdline_user_args()
	testing = "--self-test" in args
	testing = testing or "--ui-test" in args or "--overhaul-test" in args or "--combat-test" in args
	if testing:
		sound.enabled = false
	if not testing:
		_load_save()
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
			_apply_relic("fire")
			_apply_relic("storm")
			_apply_relic("swift")
		elif arg == "--capture-scene=inventory":
			for relic in RELICS:
				_apply_relic(relic.id)
			_show_inventory()

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
	relics.clear()
	total_kills = 0
	run_embers = 0
	run_time = 0.0
	run_settled = false
	run_active = true
	gold = 30
	experience = 0
	level = 1
	board.clear()
	for i in BOARD_SIZE:
		board.append("")
	visited.clear()
	_enter_room(0, "battle")

func _enter_room(next_depth: int, kind: String) -> void:
	depth = next_depth
	room_type = kind
	room_clear = false
	room_kills = 0
	player = Vector2(752, 860)
	camera_position = Vector2(player.x, minf(player.y, ARENA.end.y - 240))
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
	_close_overlay()
	state = "playing"
	if kind == "battle" or kind == "elite":
		var structure_layouts = [
			[Rect2(290, 580, 160, 64), Rect2(1060, 300, 160, 64)],
			[Rect2(540, 380, 64, 180), Rect2(880, 600, 190, 64)],
			[Rect2(260, 580, 180, 64), Rect2(1030, 380, 64, 180)],
			[Rect2(470, 310, 190, 64), Rect2(900, 730, 190, 64)]
		]
		structures.assign(structure_layouts[depth % structure_layouts.size()])
		var layouts = [
			[Vector2(440, 470), Vector2(472, 470), Vector2(504, 470), Vector2(1030, 620), Vector2(1062, 620), Vector2(1094, 620)],
			[Vector2(430, 350), Vector2(430, 382), Vector2(430, 414), Vector2(1070, 680), Vector2(1070, 712), Vector2(1070, 744)],
			[Vector2(590, 450), Vector2(622, 450), Vector2(654, 450), Vector2(850, 650), Vector2(882, 650), Vector2(914, 650)],
			[Vector2(350, 530), Vector2(382, 530), Vector2(1110, 530), Vector2(1142, 530), Vector2(752, 350)]
		]
		obstacles.assign(layouts[depth % layouts.size()])
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
		"kind": kind, "pos": _move_actor(pos, Vector2.ZERO, 20), "hp": health, "max_hp": health,
		"cooldown": rng.randf_range(0.7, 1.6), "windup": 0.0,
		"target": player, "flash": 0.0, "burn": 0.0, "burn_tick": 0.0,
		"knock": Vector2.ZERO, "elite": elite, "phase": 0, "attack_index": 0,
		"stagger": 0.0, "wall_hit": false, "alert": false
	}
	enemies.append(enemy)
	return enemy

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
				_tick_strike(delta)
				_tick_enemies(delta)
				if state == "playing":
					_tick_projectiles(delta)
				if state == "playing":
					_tick_hazards(delta)
				if state == "playing":
					_tick_pickups(delta)
					_collect_dead()
		var target_camera = Vector2(clampf(player.x, 480, ARENA.end.x - 480), clampf(player.y, 330, ARENA.end.y - 240))
		camera_position = camera_position.lerp(target_camera, 1 - exp(-delta * 9))
	_tick_effects(delta if state == "playing" else 0.0)
	queue_redraw()
	if auto_capture:
		capture_frames += 1
		if capture_frames == 45 and state == "playing" and not showcase:
			_attack(false)
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
	attack_cd = maxf(0, attack_cd - delta)
	skill_cd = maxf(0, skill_cd - delta)
	if dash_charges < 2:
		dash_cd = maxf(0, dash_cd - delta)
		if dash_cd <= 0:
			dash_charges += 1
			dash_cd = dash_duration if dash_charges < 2 else 0
	invulnerable = maxf(0, invulnerable - delta)
	combo_timer = maxf(0, combo_timer - delta)
	if combo_timer <= 0:
		combo = 0
	var movement = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if movement.length_squared() > 0.01:
		last_move = movement
		if not mouse_aim:
			facing = movement
	if mouse_aim:
		var aim = get_global_mouse_position() - view_offset - player
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
		if Input.is_action_pressed("slash") and attack_cd <= 0:
			_attack(false)
	else:
		var speed_multiplier = 0.72 if not pending_strike.is_empty() else 1.0
		player = _move_actor(player, movement * move_speed * speed_multiplier * delta + recoil * delta, 12)
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
		var sides = [absf(result.x - expanded.position.x), absf(result.x - expanded.end.x), absf(result.y - expanded.position.y), absf(result.y - expanded.end.y)]
		var smallest = sides.find(sides.min())
		match smallest:
			0: result.x = expanded.position.x - 0.1
			1: result.x = expanded.end.x + 0.1
			2: result.y = expanded.position.y - 0.1
			3: result.y = expanded.end.y + 0.1
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
	if not pending_strike.is_empty():
		return
	if heavy and skill_cd > 0:
		return
	if not heavy and attack_cd > 0:
		return
	if heavy:
		skill_cd = skill_duration
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
	var radius = 136.0 if heavy else attack_range + (22 if rushing else 0)
	var hits = 0
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		var diff: Vector2 = enemy.pos - player
		if diff.length() > radius + _enemy_radius(enemy):
			continue
		if not heavy and diff.length() > 20 and direction.dot(diff.normalized()) < 0.05:
			continue
		var damage = (attack_power + _board_bonus()) * (2.4 if heavy else (1.6 if combo == 3 else 1.0)) * (1.25 if rushing else 1.0)
		var critical = rng.randf() < crit_chance
		if critical:
			damage *= 2
		_hit_enemy(enemy, damage, critical)
		enemy.knock = diff.normalized() * (320.0 if heavy or combo == 3 else 180.0)
		enemy.stagger = 0.18 if enemy.kind != "boss" else 0.0
		enemy.wall_hit = false
		if relics.has("fire"):
			enemy.burn = 3.0
		if not heavy:
			hp = minf(max_hp, hp + relics.get("leech", 0))
		if relics.has("storm"):
			for other in enemies:
				if other != enemy and other.hp > 0 and other.pos.distance_to(enemy.pos) < 155:
					_hit_enemy(other, relics.storm * 10.0)
					impacts.append({"pos": enemy.pos, "end": other.pos, "life": 0.2, "kind": "chain"})
					break
		hits += 1
	if heavy:
		_emit(player, GOLD, 34, 260)
		shake = 5
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
	enemy.hp -= damage
	enemy.flash = 0.12
	impacts.append({"pos": enemy.pos + Vector2(0, -12), "angle": (enemy.pos - player).angle(), "life": 0.16, "kind": "hit", "critical": critical})
	_float_text(enemy.pos + Vector2(0, -30), str(int(damage)) + ("!" if critical else ""), GOLD if critical else PAPER)
	_emit(enemy.pos, GOLD if critical else MINT, 5, 100)

func _hurt(damage: float) -> void:
	if invulnerable > 0 or state != "playing":
		return
	hp = maxf(0, hp - damage)
	invulnerable = 0.75
	shake = 7
	_float_text(player + Vector2(0, -35), "-" + str(int(damage)), RED)
	_emit(player, RED, 12, 130)
	sound.play_tone("hurt")
	if relics.has("thorn"):
		for enemy in enemies:
			if enemy.pos.distance_to(player) < 120:
				_hit_enemy(enemy, relics.thorn * 18.0)
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
	hp = minf(max_hp, hp + flask_power)
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
		enemy.cooldown -= delta
		enemy.stagger = maxf(0, enemy.stagger - delta)
		enemy.burn -= delta
		enemy.burn_tick -= delta
		if enemy.burn > 0 and enemy.burn_tick <= 0:
			enemy.burn_tick = 0.5
			_hit_enemy(enemy, relics.get("fire", 0) * 3.0)
			if enemy.hp <= 0:
				continue
		if enemy.knock.length() > 2:
			var desired: Vector2 = enemy.pos + enemy.knock * delta
			enemy.pos = _move_actor(enemy.pos, enemy.knock * delta, _enemy_radius(enemy))
			if desired.distance_to(enemy.pos) > 3 and enemy.knock.length() > 130 and not enemy.wall_hit:
				enemy.wall_hit = true
				_hit_enemy(enemy, 10)
				_float_text(enemy.pos + Vector2(0, -44), "벽 충돌", GOLD)
				shake = 4
			enemy.knock = enemy.knock.move_toward(Vector2.ZERO, delta * 650)
		if enemy.hp <= 0 or enemy.stagger > 0:
			continue
		if enemy.kind == "boss":
			_tick_boss(enemy, delta)
			continue
		var diff: Vector2 = player - enemy.pos
		var distance = diff.length()
		if not enemy.alert:
			enemy.alert = distance < 430
			if not enemy.alert:
				continue
		if enemy.windup > 0:
			enemy.windup -= delta
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
		enemy.pos = _move_actor(enemy.pos, velocity * delta, _enemy_radius(enemy))

func _resolve_enemy_attack(enemy: Dictionary) -> void:
	var direction: Vector2 = (enemy.target - enemy.pos).normalized()
	enemy.cooldown = 1.65 if enemy.kind == "brute" else 1.15
	if enemy.kind == "archer":
		_shoot(enemy.pos, direction, 185, 13)
	elif enemy.kind == "brute":
		_emit(enemy.pos + direction * 35, RED, 12, 150)
		if player.distance_to(enemy.pos + direction * 28) < 69:
			_hurt(23)
	else:
		_emit(enemy.pos + direction * 20, RED, 5, 70)
		if player.distance_to(enemy.pos) < 68 and direction.dot((player - enemy.pos).normalized()) > 0:
			_hurt(12)

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
					_shoot(enemy.pos, Vector2.from_angle(angle), 152 if enraged else 125, 16)
			elif attack_index == 1:
				var direction: Vector2 = (enemy.target - enemy.pos).normalized()
				for offset in [-0.24, 0.0, 0.24]:
					_shoot(enemy.pos, direction.rotated(offset), 260, 20)
			else:
				for i in (5 if enraged else 3):
					var pos: Vector2 = player + Vector2(rng.randf_range(-120, 120), rng.randf_range(-70, 70))
					pos.x = clampf(pos.x, ARENA.position.x + 55, ARENA.end.x - 55)
					pos.y = clampf(pos.y, ARENA.position.y + 55, ARENA.end.y - 55)
					hazards.append({"pos": pos, "timer": 0.95, "life": 1.25, "fired": false})
			enemy.attack_index += 1
			enemy.cooldown = 0.75 if enraged else 1.2
		return
	var diff: Vector2 = player - enemy.pos
	if diff.length() > 80:
		enemy.pos = _move_actor(enemy.pos, _navigation_direction(enemy) * delta * (55 if enraged else 38), 29)
	if diff.length() < 64:
		_hurt(22)
	if enemy.cooldown <= 0:
		enemy.windup = 0.65 if enraged else 0.9
		enemy.target = player
		if enemy.attack_index % 3 == 2:
			_notify("발밑을 조심하세요. 뿌리가 솟아오릅니다!")

func _shoot(pos: Vector2, direction: Vector2, speed: float, damage: float) -> void:
	projectiles.append({"pos": pos, "velocity": direction * speed, "damage": damage, "life": 5.0})

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
			_hurt(projectile.damage)
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
				_hurt(24)
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
			hp = minf(max_hp, hp + 1)
			sound.play_tone("coin")
			pickups.remove_at(i)

func _gain_experience(amount: int) -> void:
	experience += amount
	while experience >= _experience_needed():
		experience -= _experience_needed()
		level += 1
		max_hp += 5
		hp = minf(max_hp, hp + 15)
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
		numbers[i].pos.y -= delta * 40
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
		var pool = range(RELICS.size()).filter(func(index): return index not in offered)
		pool.shuffle()
		offered = [pool[0], pool[1], pool[2]]
	var box = _new_panel("불씨의 유물", "유물을 고르면 가방에 배치됩니다. 같은 계열을 붙이면 연결당 공격력 +2", 850)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 22)
	box.add_child(row)
	var choices = VBoxContainer.new()
	choices.custom_minimum_size.x = 385
	choices.add_theme_constant_override("separation", 8)
	row.add_child(choices)
	for i in 3:
		var relic: Dictionary = RELICS[offered[i]]
		var button = _add_button(choices, "[" + str(i + 1) + "] " + relic.name + "\n" + relic.body, _choose_relic.bind(i), 87)
		button.icon = sprites[relic.id]
		button.expand_icon = true
		button.add_theme_constant_override("icon_max_width", 32)
		button.add_theme_font_size_override("font_size", 14)
	var board_box = VBoxContainer.new()
	board_box.custom_minimum_size.x = 330
	row.add_child(board_box)
	_add_label(board_box, "순례자의 가방   %d / 20" % _occupied_slots(), 18, GOLD)
	_build_board(board_box)
	board_detail = _add_label(board_box, "유물 칸을 선택하면 설명이 표시됩니다.\n배치 변경: 탐험 중 I", 13, MUTED)
	var reroll_button = _add_button(box, "다시 보기  (%d회 남음)" % rerolls, _reroll_relics, 42)
	reroll_button.disabled = rerolls <= 0
	reroll_button.focus_mode = Control.FOCUS_NONE if reroll_button.disabled else Control.FOCUS_ALL
	_finish_panel()

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
	var relic: Dictionary = RELICS[offered[index]]
	_apply_relic(relic.id)
	if room_type == "elite":
		hp = minf(max_hp, hp + 12)
	_close_overlay()
	state = "playing"
	room_clear = true
	sound.play_tone("reward")
	_notify(relic.name + " 획득. 북쪽 문에서 E: 다음 방")

func _apply_relic(id: String) -> void:
	if board.size() != BOARD_SIZE:
		board.resize(BOARD_SIZE)
		board.fill("")
	if not relics.has(id):
		var empty = board.find("")
		if empty >= 0:
			board[empty] = id
	relics[id] = relics.get(id, 0) + 1
	match id:
		"edge": attack_power += 6
		"vital": max_hp += 25; hp = minf(max_hp, hp + 25)
		"stride": move_speed *= 1.15; dash_duration = maxf(0.35, dash_duration * 0.88)
		"focus": skill_duration = maxf(1.0, skill_duration * 0.8)
		"reach": attack_range += 15
		"crit": crit_chance = minf(1, crit_chance + 0.18)
		"flask": flasks += 1; flask_power += 10
		"swift": attack_interval = maxf(0.10, attack_interval / 1.16)

func _relic_family(id: String) -> int:
	if id in ["edge", "fire", "storm", "reach", "crit", "swift"]:
		return 0
	if id in ["vital", "leech", "thorn", "flask"]:
		return 1
	return 2

func _family_color(id: String) -> Color:
	return [Color("#d78875"), Color("#9ac394"), Color("#87c7cc")][_relic_family(id)]

func _occupied_slots() -> int:
	var count = 0
	for id in board:
		if not id.is_empty():
			count += 1
	return count

func _board_bonus() -> int:
	var links = 0
	for i in board.size():
		if board[i].is_empty():
			continue
		for neighbor in [i + 1 if i % BOARD_COLUMNS < BOARD_COLUMNS - 1 else -1, i + BOARD_COLUMNS]:
			if neighbor >= 0 and neighbor < board.size() and not board[neighbor].is_empty() and _relic_family(board[i]) == _relic_family(board[neighbor]):
				links += 1
	return links * 2

func _build_board(box: VBoxContainer) -> void:
	board_buttons.clear()
	if board.size() != BOARD_SIZE:
		board.resize(BOARD_SIZE)
		board.fill("")
	var grid = GridContainer.new()
	grid.columns = BOARD_COLUMNS
	grid.add_theme_constant_override("h_separation", 4)
	grid.add_theme_constant_override("v_separation", 4)
	box.add_child(grid)
	for i in BOARD_SIZE:
		var slot = Button.new()
		slot.custom_minimum_size = Vector2(58, 54)
		slot.expand_icon = true
		slot.add_theme_constant_override("icon_max_width", 38)
		slot.add_theme_font_override("font", font)
		var id = board[i]
		var style = StyleBoxFlat.new()
		style.bg_color = Color("#303540") if id.is_empty() else Color("#3a3d47")
		style.border_color = Color("#656572") if id.is_empty() else _family_color(id)
		style.set_border_width_all(2)
		slot.add_theme_stylebox_override("normal", style)
		var focused: StyleBoxFlat = style.duplicate()
		focused.border_color = GOLD
		focused.set_border_width_all(3)
		slot.add_theme_stylebox_override("focus", focused)
		slot.add_theme_stylebox_override("hover", focused)
		slot.add_theme_stylebox_override("pressed", focused)
		if not id.is_empty():
			slot.icon = sprites[id]
			slot.tooltip_text = _relic_description(id)
			if relics.get(id, 0) > 1:
				slot.text = "x%d" % relics[id]
				slot.add_theme_color_override("font_color", PAPER)
		else:
			slot.tooltip_text = "빈 유물 칸"
		slot.pressed.connect(_select_slot.bind(i))
		slot.mouse_entered.connect(_inspect_slot.bind(i))
		slot.focus_entered.connect(_inspect_slot.bind(i))
		grid.add_child(slot)
		board_buttons.append(slot)

func _relic_description(id: String) -> String:
	for relic in RELICS:
		if relic.id == id:
			return relic.name + "  x%d\n" % relics.get(id, 0) + relic.body
	return ""

func _inspect_slot(index: int) -> void:
	if is_instance_valid(board_detail):
		board_detail.text = "빈 칸. 선택한 유물을 이곳으로 옮길 수 있습니다." if board[index].is_empty() else _relic_description(board[index])

func _select_slot(index: int) -> void:
	if state != "inventory":
		_inspect_slot(index)
		return
	if board_selected < 0:
		if board[index].is_empty():
			_inspect_slot(index)
			return
		board_selected = index
		board_detail.text = "이동할 칸을 선택하세요. 같은 칸을 다시 누르면 취소합니다."
		board_buttons[index].text = "*"
	else:
		var source = board_selected
		var id = board[index]
		board[index] = board[source]
		board[source] = id
		board_selected = -1
		_show_inventory()
		board_buttons[index].grab_focus()

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
		_add_button(box, "묻힌 보물방\n전투 없이 유물을 하나 획득합니다.", _enter_room.bind(next, "treasure"), 84)
		_add_button(box, "떠돌이 상인\n모은 금화로 유물과 회복약을 구매합니다.", _enter_room.bind(next, "shop"), 70)
	else:
		_add_button(box, "무너진 회랑\n일반 전투. 적을 처치하고 유물을 얻습니다.", _enter_room.bind(next, "battle"), 84)
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
	var box = _new_panel("폐허의 상인", "금화 %d  /  나무 상자와 항아리를 부수거나 적을 처치해 금화를 모으세요." % gold, 670)
	var relic_button = _add_button(box, "봉인된 유물  /  25 금화\n세 유물 중 하나를 고릅니다. 방마다 한 번 구매할 수 있습니다.", _shop_buy.bind("relic"), 80)
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
		hp = minf(max_hp, hp + 35)
		flasks += 1
		sound.play_tone("reward")
		_show_shop()

func _leave_shop() -> void:
	room_clear = true
	_resume_room()

func _rest_choice(heal: bool) -> void:
	if heal:
		hp = minf(max_hp, hp + max_hp * 0.5)
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
	var subtitle = "수호자를 쓰러뜨렸습니다. 데모를 플레이해 주셔서 감사합니다." if won else "이번 탐험의 유물은 사라집니다. 모은 불씨는 야영지에 남습니다."
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
	player = Vector2(480, 320)
	enemies.clear()
	obstacles.clear()
	structures.clear()
	projectiles.clear()
	hazards.clear()
	pickups.clear()
	var box = _new_panel("불씨의 성소", "EMBER SANCTUARY  /  탑다운 로그라이트 액션 데모", 630)
	_add_label(box, "잠든 숲의 일곱 방. 유물을 엮고, 마지막 수호자를 깨우세요.", 18, PAPER)
	_add_label(box, "보유 불씨  %d     영구 강화  %d / 5" % [meta_embers, meta_level], 21, GOLD)
	_add_label(box, "강화당 시작 체력 +12 / 공격력 +2. 사망해도 유지됩니다.", 15, MUTED)
	_add_button(box, "성소에 들어가기", _start_run, 56)
	var cost = _upgrade_cost()
	var upgrade_text = "불씨로 단련하기  (%d 필요)" % cost if meta_level < 5 else "단련 완료  (최대 단계)"
	var upgrade = _add_button(box, upgrade_text, _buy_upgrade, 48)
	upgrade.disabled = meta_level >= 5 or meta_embers < cost or not save_error.is_empty()
	upgrade.focus_mode = Control.FOCUS_NONE if upgrade.disabled else Control.FOCUS_ALL
	_add_button(box, "조작법과 탐험 안내", _show_help.bind("hub"), 44)
	_add_button(box, "게임 종료", _quit_game, 40)
	if not save_error.is_empty():
		_add_label(box, save_error, 14, RED)
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
	_add_label(box, "이동   WASD / 방향키       조준   마우스\n베기   좌클릭 유지 / J       불씨 폭발   우클릭 / Q / K\n회피   Space (이동 방향, 무적)       회복약   F\n상호작용   E       일시정지   Esc       수첩   Tab\n음소거   M       조준 방식 변경   T", 18, PAPER)
	_add_label(box, "I  유물 가방 / G  탐험 지도 / V  화면 흔들림·섬광 전환\n회피는 2회 충전. 회피 중 공격하면 돌진 베기(피해 +25%)입니다.\n상자를 베어 금화를 모으세요. 경험치는 체력·공격력을 올립니다.\n같은 계열의 유물을 상하좌우로 붙이면 연결당 공격력 +2\n방 정리 > 유물 선택 > 좌우 출구(E) 또는 북쪽 경로판(E)\n네 번째 방은 휴식·보물·상인 중 선택. 일곱 번째 방은 보스입니다.", 15, MUTED)
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
	_add_button(box, "조작법과 유물 확인", _show_inventory, 48)
	_add_button(box, "야영지로 귀환  (현재 불씨 정산)", _abandon_run, 48)
	_add_button(box, "소리: " + ("꺼짐" if muted else "켜짐"), _toggle_sound_menu, 44)
	_finish_panel()

func _abandon_run() -> void:
	_settle_run(false)
	_show_hub()

func _show_inventory() -> void:
	state = "inventory"
	board_selected = -1
	var box = _new_panel("순례자의 유물 가방", "공격력 %d + 연결 %d / 치명타 %d%% / 레벨 %d / 금화 %d" % [attack_power, _board_bonus(), crit_chance * 100, level, gold], 790)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	box.add_child(row)
	var board_box = VBoxContainer.new()
	row.add_child(board_box)
	_build_board(board_box)
	var description_box = VBoxContainer.new()
	description_box.custom_minimum_size.x = 340
	row.add_child(description_box)
	board_detail = _add_label(description_box, "아직 획득한 유물이 없습니다." if relics.is_empty() else "유물에 마우스를 올리거나 Tab으로 이동하면 설명이 표시됩니다.", 17, PAPER)
	board_detail.custom_minimum_size.y = 128
	_add_label(description_box, "유물 선택 > 이동할 칸 선택\n빈 칸 이동과 유물 맞바꾸기가 가능합니다.\n\n공격 / 생존 / 기동 계열\n같은 계열 상하좌우 연결당 공격력 +2\n같은 유물은 같은 칸에 중첩됩니다.", 15, MUTED)
	_add_button(box, "조작법 보기", _show_help.bind("pause"), 44)
	_add_button(box, "일시정지로 돌아가기", _show_pause, 44)
	_finish_panel()
	board_buttons[0].grab_focus()

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
	return {"battle": "이끼 회랑", "elite": "가시의 시련", "treasure": "묻힌 보물", "rest": "이슬의 샘", "shop": "폐허의 상인", "boss": "뿌리의 옥좌"}.get(kind, "야영지")

func _toggle_sound_menu() -> void:
	_toggle_sound()
	_show_pause()

func _toggle_sound() -> void:
	muted = not muted
	sound.enabled = not muted
	for voice in sound.voices:
		voice.stop()
	_notify("소리 " + ("꺼짐" if muted else "켜짐"))

func _new_panel(title: String, subtitle: String, width: float) -> VBoxContainer:
	_close_overlay()
	board_detail = null
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
	style.bg_color = Color("#262b36")
	style.border_color = Color("#a58e72")
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
		style.bg_color = Color("#343945") if style_name != "hover" else Color("#494951")
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

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_ESCAPE:
				if state == "playing":
					_show_pause()
				elif state in ["pause", "route", "map"]:
					_resume_room()
				elif state == "inventory":
					_resume_room()
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
			KEY_I:
				if state == "playing":
					_show_inventory()
				elif state == "inventory":
					_resume_room()
			KEY_G:
				if state == "playing":
					_show_map()
				elif state == "map":
					_resume_room()
			KEY_V:
				effects_enabled = not effects_enabled
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
		"elite": return "%02d  가시의 시련" % (depth + 1)
	return "%02d  " % (depth + 1) + ["숲의 문턱", "이끼 회랑", "잠든 정원", "뿌리의 쉼터", "잊힌 제단", "수호자의 길"][mini(depth, 5)]

func _room_objective() -> String:
	if reward_deferred:
		return "중앙 제단에서 E: 남겨 둔 보상"
	if room_clear:
		return "좌우 출구 또는 북쪽 경로판에서 E"
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

func _draw() -> void:
	if sprites.is_empty():
		return
	draw_rect(Rect2(0, 0, 960, 540), Color("#191d28"))
	view_offset = Vector2(480, 300) - camera_position
	if effects_enabled:
		view_offset += Vector2(sin(time * 97), cos(time * 83)) * shake
	view_offset = view_offset.round()
	draw_set_transform(view_offset)
	_draw_room()
	_draw_entities()
	draw_set_transform(Vector2.ZERO)
	if effects_enabled and screen_flash > 0:
		draw_rect(Rect2(0, 0, 960, 540), Color(1.0, 0.82, 0.53, screen_flash * 0.6))
	_draw_hud()

func _draw_room() -> void:
	draw_rect(ARENA.grow(28), Color("#141923"))
	for y in 26:
		for x in 43:
			var pos = ARENA.position + Vector2(x * 32, y * 32)
			if not Rect2(-view_offset - Vector2(40, 40), Vector2(1040, 620)).has_point(pos):
				continue
			var hash_value = absi(x * 37 + y * 131 + room_seed)
			var index = hash_value % 8
			if (x * 7 + y * 3 + depth) % 17 < 4:
				index = 8 + hash_value % 4
			draw_texture_rect(tiles[index], Rect2(pos, Vector2(32, 32)), false)
	for x in 44:
		_draw_stone(Vector2(48 + x * 32, 96), Vector2(32, 48))
		_draw_stone(Vector2(48 + x * 32, 956), Vector2(32, 24))
	for y in 26:
		_draw_stone(Vector2(34, 128 + y * 32), Vector2(30, 32))
		_draw_stone(Vector2(1440, 128 + y * 32), Vector2(30, 32))
	for side in [98, 1400]:
		for y in [235, 445, 680, 900]:
			var torch_pos = Vector2(side, y)
			draw_circle(torch_pos + Vector2(0, -20), 37, Color(0.96, 0.65, 0.3, 0.045))
			draw_circle(torch_pos + Vector2(0, -20), 23, Color(0.96, 0.65, 0.3, 0.06))
			_draw_sprite("torch", torch_pos, 2)
	for i in 38:
		var p = Vector2(90 + (i * 137 + room_seed) % 1310, 175 + (i * 193) % 750)
		var moss = Color("#5d7053")
		if i % 3 == 0:
			draw_rect(Rect2(p, Vector2(7, 4)), Color("#6c7470"))
			draw_rect(Rect2(p + Vector2(1, -2), Vector2(4, 2)), Color("#8e9184"))
		else:
			for blade in 3:
				var grass = p + Vector2(blade * 3, 0)
				draw_line(grass, grass + Vector2(blade - 1, -4 - i % 5), moss, 2)
	if depth % 2 == 0 and room_type not in ["boss", "rest", "treasure", "shop"]:
		for rail_y in [342, 358]:
			draw_line(Vector2(150, rail_y), Vector2(1300, rail_y), Color("#232932"), 5)
			draw_line(Vector2(150, rail_y - 2), Vector2(1300, rail_y - 2), Color("#77776c"), 2)
		for x in range(150, 1300, 25):
			draw_rect(Rect2(x, 335, 5, 33), Color("#6d5b4c"))
	for mark in floor_marks:
		draw_ellipse_shadow(mark.pos, Vector2(18, 7))
		for i in 5:
			draw_rect(Rect2(mark.pos + Vector2(i * 7 - 16, (i * 11) % 13 - 5), Vector2(4, 3)), Color("#292e34"))
	if room_type == "boss":
		draw_rect(Rect2(ALTAR.x - 96, 270, 192, 450), Color("#49363d"))
		draw_rect(Rect2(ALTAR.x - 90, 276, 180, 438), Color("#563b43"), false, 3)
		draw_rect(Rect2(ALTAR.x - 80, 286, 160, 418), Color("#9b785e"), false, 1)
	_draw_floor_emblem(ALTAR)
	if reward_deferred:
		_draw_sprite("chest", ALTAR, 3)
		_world_label(ALTAR + Vector2(0, -55), "[E]  남겨 둔 보상", GOLD)
	_draw_gate(PORTAL, "경로 선택", room_clear)
	_draw_gate(WEST_GATE, "휴식" if depth == 2 else "회랑", room_clear)
	_draw_gate(EAST_GATE, "보물" if depth == 2 else "시련", room_clear)
	if room_clear:
		var gate_direction = (PORTAL - player).normalized()
		draw_line(player + gate_direction * 42, player + gate_direction * 53, GOLD, 3)
	if room_type == "treasure" and not room_clear:
		_draw_sprite("chest", ALTAR, 3)
		_world_label(ALTAR + Vector2(0, -55), "[E]  유물 상자", GOLD)
	if room_type == "rest" and not room_clear:
		draw_circle(ALTAR, 40, Color("#243d44"))
		draw_arc(ALTAR, 37, 0, TAU, 32, MINT, 3)
		for i in 5:
			draw_arc(ALTAR, 9 + fmod(time * 12 + i * 7, 26), 0, TAU, 20, Color("#5c9588"), 1)
		_world_label(ALTAR + Vector2(0, -55), "[E]  이슬의 샘", MINT)
	if room_type == "shop":
		draw_rect(Rect2(ALTAR - Vector2(42, 15), Vector2(84, 30)), Color("#8f6950"))
		_draw_sprite("archer", ALTAR + Vector2(0, -25), 2, Color("#edc993"))
		_draw_sprite("chest", ALTAR + Vector2(-30, 10), 2)
		_world_label(ALTAR + Vector2(0, -75), "[E]  폐허의 상인", GOLD)
	for i in 22:
		var p = Vector2(80 + fposmod(i * 137.0 + sin(time * 0.3 + i) * 24, 1300), 140 + fposmod(i * 79.0 - time * (4 + i % 3), 790))
		draw_rect(Rect2(p, Vector2(2, 2)), Color(0.8, 0.72, 0.42, 0.25 + sin(time + i) * 0.15))

func _draw_stone(pos: Vector2, size: Vector2) -> void:
	draw_rect(Rect2(pos, size), Color("#292c36"))
	draw_rect(Rect2(pos + Vector2(2, 2), size - Vector2(4, 5)), Color("#676960"))
	draw_rect(Rect2(pos + Vector2(3, 3), Vector2(size.x - 6, 5)), Color("#90907b"))
	draw_rect(Rect2(pos + Vector2(3, 10), Vector2(size.x - 6, size.y - 14)), Color("#545951"))
	draw_rect(Rect2(pos + Vector2(4, size.y - 8), Vector2(size.x - 8, 3)), Color("#424a49"))

func _draw_obstacle(pos: Vector2) -> void:
	draw_ellipse_shadow(pos + Vector2(0, 8), Vector2(23, 8))
	_draw_stone(pos - Vector2(19, 33), Vector2(38, 44))
	draw_rect(Rect2(pos - Vector2(16, 14), Vector2(32, 5)), Color("#58705a"))

func _draw_structure(rect: Rect2) -> void:
	draw_rect(rect.grow(6), Color("#242934"))
	for y in int(rect.size.y / 32):
		for x in int(rect.size.x / 32):
			_draw_stone(rect.position + Vector2(x * 32, y * 32 - 20), Vector2(32, 44))
	draw_rect(Rect2(rect.position + Vector2(6, -19), Vector2(rect.size.x - 12, 8)), Color("#657956"))

func _draw_breakable(prop: Dictionary) -> void:
	if prop.hp <= 0:
		draw_rect(Rect2(prop.pos, Vector2(9, 3)), Color("#6e5a49"))
		return
	draw_ellipse_shadow(prop.pos + Vector2(0, 3), Vector2(14, 5))
	if prop.kind == "crate":
		draw_rect(Rect2(prop.pos - Vector2(13, 22), Vector2(26, 26)), Color("#322b2b"))
		draw_rect(Rect2(prop.pos - Vector2(11, 21), Vector2(22, 22)), Color("#977756"))
		draw_rect(Rect2(prop.pos - Vector2(8, 18), Vector2(16, 16)), Color("#6c523e"))
		draw_line(prop.pos - Vector2(8, 17), prop.pos + Vector2(8, -2), Color("#c49b6a"), 3)
	else:
		draw_rect(Rect2(prop.pos - Vector2(9, 20), Vector2(18, 20)), Color("#99927b"))
		draw_rect(Rect2(prop.pos - Vector2(5, 24), Vector2(10, 5)), Color("#d0b78c"))
		draw_rect(Rect2(prop.pos - Vector2(6, 15), Vector2(4, 12)), Color("#b9b29b"))

func _draw_gate(pos: Vector2, label: String, opened: bool) -> void:
	draw_rect(Rect2(pos - Vector2(24, 22), Vector2(48, 44)), Color("#191e29"))
	draw_rect(Rect2(pos - Vector2(28, 26), Vector2(6, 50)), Color("#a18a68"))
	draw_rect(Rect2(pos + Vector2(22, -26), Vector2(6, 50)), Color("#a18a68"))
	if opened:
		for i in 4:
			draw_rect(Rect2(pos + Vector2(-15 + i * 9, 15 - fmod(time * 24 + i * 9, 36)), Vector2(3, 5)), GOLD)
		_world_label(pos + Vector2(0, 44), "[E]  " + ("옥좌" if depth >= 5 else label), GOLD)
	else:
		for x in range(-16, 22, 9):
			draw_line(pos + Vector2(x, -22), pos + Vector2(x, 22), Color("#696d67"), 3)

func _world_label(pos: Vector2, text: String, color: Color) -> void:
	var width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x
	draw_rect(Rect2(pos - Vector2(width / 2 + 5, 16), Vector2(width + 10, 23)), Color("#242a35"))
	_text(pos, text, 14, color, true)

func _draw_floor_emblem(center: Vector2) -> void:
	var color = Color("#3d5c52")
	draw_arc(center, 82, 0, TAU, 32, color, 2)
	draw_arc(center, 68, 0, TAU, 32, color, 1)
	for i in 8:
		var direction = Vector2.from_angle(i * TAU / 8)
		draw_line(center + direction * 68, center + direction * 82, color, 3)
	draw_polyline(PackedVector2Array([center + Vector2(0, -38), center + Vector2(21, 2), center + Vector2(0, 37), center + Vector2(-21, 2), center + Vector2(0, -38)]), color, 3)

func _draw_entities() -> void:
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
	for pos in obstacles:
		actors.append({"kind": "wall", "pos": pos})
	for rect in structures:
		actors.append({"kind": "structure", "pos": rect.end, "rect": rect})
	for prop in breakables:
		actors.append({"kind": "prop", "pos": prop.pos, "data": prop})
	actors.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for actor in actors:
		if actor.kind == "hero":
			_draw_player()
		elif actor.kind == "wall":
			_draw_obstacle(actor.pos)
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
		else:
			var ratio: float = impact.life / 0.16
			for i in 6:
				var direction = Vector2.from_angle(impact.angle + i * TAU / 6)
				draw_line(impact.pos + direction * 3, impact.pos + direction * (28 * ratio + 8), GOLD if impact.critical else PAPER, 3)
			draw_line(impact.pos - Vector2(0, 19 * ratio), impact.pos + Vector2(0, 19 * ratio), GOLD, 4)
	for number in numbers:
		var width = font.get_string_size(number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_rect(Rect2(number.pos - Vector2(width / 2 + 3, 19), Vector2(width + 6, 24)), Color("#10292e"))
		_text(number.pos, number.text, 19, number.color, true)

func _draw_sprite(kind: String, pos: Vector2, scale_factor: float, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(sprites[kind], Rect2((pos - Vector2(8, 13) * scale_factor).round(), Vector2(16, 16) * scale_factor), false, tint)

func draw_ellipse_shadow(pos: Vector2, size: Vector2) -> void:
	draw_set_transform(pos + view_offset, 0, Vector2(1, size.y / size.x))
	draw_circle(Vector2.ZERO, size.x, Color(0.02, 0.07, 0.08, 0.55))
	draw_set_transform(view_offset)

func _draw_player() -> void:
	draw_ellipse_shadow(player + Vector2(0, 4), Vector2(14, 5))
	var tint = Color.WHITE
	if invulnerable > 0 and int(time * 16) % 2:
		tint = Color(1, 1, 1, 0.45)
	var walking = Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.1 and state == "playing"
	var bob = sin(time * 18) * 1.2 if walking else 0.0
	var hero = "hero_walk%d" % (int(time * 12) % 4) if walking else "hero"
	var hero_rect = Rect2((player + Vector2(-16, -26 + bob)).round(), Vector2(32, 32))
	if facing.x < -0.1:
		hero_rect.position.x += 32
		hero_rect.size.x = -32
	draw_texture_rect(sprites[hero], hero_rect, false, tint)
	var sword_direction = facing
	if slash_time > 0:
		var swing = 1.0 - slash_time / (0.30 if slash_heavy else 0.21)
		sword_direction = Vector2.from_angle(slash_angle + lerpf(-1.25, 1.25, swing) * (1 if combo % 2 else -1))
	elif not pending_strike.is_empty():
		sword_direction = facing.rotated(-1.2)
	var hand = player + sword_direction * 11 + Vector2(0, -9)
	var blade = sword_direction * 28
	draw_line(hand, hand + blade, PAPER, 5)
	draw_line(hand - sword_direction * 3, hand + sword_direction * 3, GOLD, 7)
	draw_line(hand - sword_direction * 9, hand - sword_direction * 3, Color("#a27047"), 4)
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
	var tint = Color(2.8, 2.8, 2.8) if enemy.flash > 0 else Color.WHITE
	var scale_factor = 4.0 if enemy.kind == "boss" else (2.5 if enemy.kind == "brute" else 2.0)
	_draw_sprite(enemy.kind, enemy.pos + Vector2(0, sin(time * 5 + enemy.pos.x) * 1.5), scale_factor, tint)
	if enemy.elite:
		draw_arc(enemy.pos + Vector2(0, -24), 26, PI, TAU, 16, GOLD, 2)
	if enemy.burn > 0:
		for i in 3:
			var p: Vector2 = enemy.pos + Vector2(-12 + i * 12, -20 - fmod(time * 30 + i * 13, 25))
			draw_rect(Rect2(p, Vector2(4, 7)), GOLD)
	if enemy.kind != "boss":
		if enemy.hp < enemy.max_hp or enemy.windup > 0:
			var pos: Vector2 = enemy.pos + Vector2(-17, -38)
			_bar(Rect2(pos, Vector2(34, 3)), enemy.hp / enemy.max_hp, GOLD if enemy.elite else RED)

func _draw_hud() -> void:
	_hud_panel(Rect2(14, 14, 245, 108))
	_draw_sprite("hero", Vector2(38, 52), 2)
	_bar(Rect2(60, 26, 182, 16), hp / max_hp, Color("#9f453f"))
	_text(Vector2(151, 39), "%d / %d" % [ceili(hp), int(max_hp)], 12, PAPER, true)
	_bar(Rect2(60, 46, 182, 5), float(experience) / _experience_needed(), Color("#5c9c99"))
	_text(Vector2(60, 69), "Lv.%d   EXP %d / %d" % [level, experience, _experience_needed()], 12, PAPER)
	for i in 2:
		draw_rect(Rect2(28 + i * 21, 87, 15, 6), MINT if i < dash_charges else Color("#4c565d"))
	_text(Vector2(78, 96), "회피 %d/2    F 약 %d" % [dash_charges, flasks], 13, PAPER)
	_text(Vector2(26, 114), "조준: " + ("마우스" if mouse_aim else "이동 방향"), 11, MUTED)
	_hud_panel(Rect2(335, 14, 290, 53))
	_text(Vector2(480, 36), _room_title(), 17, PAPER, true)
	_text(Vector2(480, 56), _room_objective(), 12, MINT, true)
	_draw_minimap()
	_hud_panel(Rect2(14, 450, 442, 76))
	_ability(24, "J / 클릭", "베기", attack_cd, attack_interval * 1.15, 0)
	_ability(128, "Q / 우클릭", "불씨", skill_cd, skill_duration, 1)
	_ability(244, "Space", "회피", dash_cd if dash_charges == 0 else 0, dash_duration, 2)
	_ability(352, "F x%d" % flasks, "회복약", 0, 1, 3)
	var x = 24
	for relic in RELICS:
		if relics.has(relic.id):
			draw_texture_rect(sprites[relic.id], Rect2(x, 502, 22, 22), false)
			x += 25
			if x > 420:
				break
	_hud_panel(Rect2(738, 464, 208, 62))
	_text(Vector2(750, 486), "금화 %d   불씨 %d" % [gold, run_embers], 14, GOLD)
	_text(Vector2(750, 505), "I 가방  G 지도  Esc 정지", 12, PAPER)
	_text(Vector2(750, 521), "E 상호작용   %s" % _clock(run_time), 11, MUTED)
	if toast_time > 0:
		var text_width = font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		_hud_panel(Rect2(480 - text_width / 2 - 16, 410, text_width + 32, 30))
		_text(Vector2(480, 431), toast, 16, GOLD, true)
	for enemy in enemies:
		if enemy.kind == "boss":
			_hud_panel(Rect2(280, 75, 400, 42))
			_bar(Rect2(290, 99, 380, 8), enemy.hp / enemy.max_hp, Color("#9f453f"))
			_text(Vector2(480, 92), "가시 왕관의 수호자" + ("  /  분노" if enemy.phase == 1 else ""), 13, PAPER, true)

func _hud_panel(rect: Rect2) -> void:
	draw_rect(rect, Color("#242a35"))
	draw_rect(rect, Color("#8b7e6b"), false, 1)
	draw_rect(Rect2(rect.position + Vector2(3, 3), rect.size - Vector2(6, 6)), Color("#464b54"), false, 1)

func _draw_minimap() -> void:
	var panel = Rect2(793, 14, 153, 124)
	_hud_panel(panel)
	var mini = Rect2(805, 25, 129, 79)
	draw_rect(mini, Color("#151c27"))
	draw_rect(mini.grow(-3), Color("#78857a"), false, 2)
	for obstacle in obstacles:
		var at = mini.position + (obstacle - ARENA.position) / ARENA.size * mini.size
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(4, 4)), Color("#647467"))
	for structure in structures:
		var at = mini.position + (structure.position - ARENA.position) / ARENA.size * mini.size
		draw_rect(Rect2(at, structure.size / ARENA.size * mini.size), Color("#647467"))
	for gate in [PORTAL, WEST_GATE, EAST_GATE]:
		var at: Vector2 = mini.position + (gate - ARENA.position) / ARENA.size * mini.size
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(5, 5)), GOLD if room_clear else Color("#8c6a5e"))
	for enemy in enemies:
		if enemy.hp > 0 and (enemy.alert or enemy.kind == "boss"):
			var at: Vector2 = mini.position + (enemy.pos - ARENA.position) / ARENA.size * mini.size
			draw_rect(Rect2(at - Vector2(1, 1), Vector2(3, 3)), RED)
	var marker = mini.position + (player - ARENA.position) / ARENA.size * mini.size
	draw_rect(Rect2(marker - Vector2(2, 2), Vector2(5, 5)), PAPER)
	_text(Vector2(868, 126), "%d / 7   G 지도" % (depth + 1), 12, PAPER, true)

func _relic_count() -> int:
	var count = 0
	for value in relics.values():
		count += value
	return count

func _ability(x: float, key: String, title: String, cooldown: float, full: float, icon: int) -> void:
	var pos = Vector2(x, 460)
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
	for relic in RELICS:
		_apply_relic(relic.id)
	assert(relics.size() == 12 and attack_power == 26 and max_hp == 135)
	assert(attack_range == 101 and flasks == 2 and skill_duration < 5.5)
	checks += 1
	for enemy in enemies:
		enemy.hp = 0
	_collect_dead()
	assert(state == "reward" and offered.size() == 3 and total_kills == 4)
	var count = _relic_count()
	_choose_relic(1)
	assert(state == "playing" and room_clear and _relic_count() == count + 1)
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
	assert(max_hp == 122 and attack_power == 22 and relics.is_empty())
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
	for id in ["fire", "leech", "storm", "thorn"]:
		_apply_relic(id)
	player = Vector2(480, 340)
	facing = Vector2.UP
	crit_chance = 0
	attack_cd = 0
	hp = 50
	var first = _spawn_enemy("brute", Vector2(480, 290))
	var second = _spawn_enemy("brute", Vector2(510, 290))
	first.hp = 500
	second.hp = 500
	_attack(false)
	_tick_strike(0.05)
	assert(first.burn == 3 and second.burn == 3)
	assert(first.hp < 500 - attack_power and second.hp < 500 - attack_power)
	assert(hp == 52)
	var before_burn: float = first.hp
	_tick_enemies(0.1)
	assert(first.hp < before_burn)
	invulnerable = 0
	var before_thorns: float = first.hp
	_hurt(5)
	assert(first.hp == before_thorns - 18)
	checks += 1
	skill_cd = 0
	var before_skill: float = first.hp
	_attack(true)
	_tick_strike(0.08)
	assert(first.hp < before_skill - attack_power * 2 and skill_cd == skill_duration)
	var after_skill: float = first.hp
	_attack(true)
	assert(first.hp == after_skill)
	hp = max_hp
	var before_flasks = flasks
	_use_flask()
	assert(flasks == before_flasks)
	checks += 1
	print("SELF_TEST_PASS: ", checks, " groups: combat, dodge, damage, flasks, 12 relics, rewards, routes, rest, treasure, boss phases, settlement, upgrades, menus, movement.")
	_close_overlay()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(0)
