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
const ARENA = Rect2(65, 124, 830, 328)
const PORTAL = Vector2(480, 146)
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
	testing = testing or "--ui-test" in args
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
			player = Vector2(480, 365)
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
	_enter_room(0, "battle")

func _enter_room(next_depth: int, kind: String) -> void:
	depth = next_depth
	room_type = kind
	room_clear = false
	room_kills = 0
	player = Vector2(480, 392)
	facing = Vector2.UP
	last_move = facing
	enemies.clear()
	projectiles.clear()
	hazards.clear()
	particles.clear()
	numbers.clear()
	pickups.clear()
	obstacles.clear()
	attack_cd = 0.2
	skill_cd = 0.0
	dash_cd = 0.0
	dash_time = 0.0
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
		var layouts = [
			[Vector2(280, 245), Vector2(680, 245)],
			[Vector2(265, 210), Vector2(695, 210), Vector2(265, 354), Vector2(695, 354)],
			[Vector2(360, 260), Vector2(600, 310)],
			[Vector2(240, 285), Vector2(720, 285), Vector2(480, 202)]
		]
		obstacles.assign(layouts[depth % layouts.size()])
		var count = 4 + mini(depth, 4)
		for i in count:
			var enemy_kind = "crawler"
			if i % 3 == 1 and depth > 0:
				enemy_kind = "archer"
			if i % 4 == 3 and depth > 1:
				enemy_kind = "brute"
			_spawn_enemy(enemy_kind, Vector2(135 + i * 107 % 690, 175 + (i % 2) * 100), kind == "elite")
	elif kind == "boss":
		_spawn_enemy("boss", Vector2(480, 226))
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
		"knock": Vector2.ZERO, "elite": elite, "phase": 0, "attack_index": 0
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
				_tick_enemies(delta)
				if state == "playing":
					_tick_projectiles(delta)
				if state == "playing":
					_tick_hazards(delta)
				if state == "playing":
					_tick_pickups(delta)
					_collect_dead()
	_tick_effects(delta)
	queue_redraw()
	if auto_capture:
		capture_frames += 1
		if capture_frames == 45 and state == "playing":
			_attack(false)
		if capture_frames == 55:
			await RenderingServer.frame_post_draw
			var error = get_viewport().get_texture().get_image().save_png(capture_path)
			print("CAPTURE_RESULT=", error)
			_quit_game(0 if error == OK else 1)

func _tick_player(delta: float) -> void:
	attack_cd = maxf(0, attack_cd - delta)
	skill_cd = maxf(0, skill_cd - delta)
	dash_cd = maxf(0, dash_cd - delta)
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
		var aim = get_global_mouse_position() - player
		if aim.length() > 8:
			facing = aim.normalized()
	if Input.is_action_just_pressed("dash"):
		_dash(movement)
	if dash_time > 0:
		dash_time -= delta
		player = _move_actor(player, dash_vector * 620.0 * delta, 12)
		_emit(player, MINT, 1, 20)
	else:
		player = _move_actor(player, movement * move_speed * delta, 12)
		if Input.is_action_pressed("slash") and attack_cd <= 0:
			_attack(false)
		if Input.is_action_just_pressed("skill") and skill_cd <= 0:
			_attack(true)
	if Input.is_action_just_pressed("flask"):
		_use_flask()
	if Input.is_action_just_pressed("interact"):
		_interact()

func _move_actor(pos: Vector2, movement: Vector2, radius: float) -> Vector2:
	var result = pos + movement
	result.x = clampf(result.x, ARENA.position.x + radius, ARENA.end.x - radius)
	result.y = clampf(result.y, ARENA.position.y + radius, ARENA.end.y - radius)
	for obstacle in obstacles:
		var diff = result - obstacle
		var minimum = 25.0 + radius
		if diff.length() < minimum:
			result = obstacle + diff.normalized() * minimum if diff.length() > 0.001 else obstacle + Vector2(minimum, 0)
	return result

func _dash(movement: Vector2) -> void:
	if dash_cd > 0:
		return
	dash_vector = movement.normalized() if movement.length() > 0.1 else last_move
	dash_time = 0.17
	dash_cd = dash_duration
	invulnerable = maxf(invulnerable, 0.25)
	sound.play_tone("dash")

func _attack(heavy: bool) -> void:
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
	slash_time = 0.24 if heavy else 0.16
	slash_angle = facing.angle()
	slash_heavy = heavy
	var radius = 136.0 if heavy else attack_range
	var hits = 0
	for enemy in enemies:
		if enemy.hp <= 0:
			continue
		var diff: Vector2 = enemy.pos - player
		if diff.length() > radius + _enemy_radius(enemy):
			continue
		if not heavy and diff.length() > 20 and facing.dot(diff.normalized()) < 0.05:
			continue
		var damage = attack_power * (2.4 if heavy else (1.6 if combo == 3 else 1.0))
		var critical = rng.randf() < crit_chance
		if critical:
			damage *= 2
		_hit_enemy(enemy, damage, critical)
		enemy.knock = diff.normalized() * (200.0 if heavy else 110.0)
		if relics.has("fire"):
			enemy.burn = 3.0
		if not heavy:
			hp = minf(max_hp, hp + relics.get("leech", 0))
		if relics.has("storm"):
			for other in enemies:
				if other != enemy and other.hp > 0 and other.pos.distance_to(enemy.pos) < 155:
					_hit_enemy(other, relics.storm * 10.0)
					_emit((other.pos + enemy.pos) * 0.5, MINT, 8, 90)
					break
		hits += 1
	if heavy:
		_emit(player, GOLD, 34, 260)
		shake = 5
	if hits > 0:
		hit_stop = 0.045
		shake = 5 if heavy or combo == 3 else 2
		sound.play_tone("hit")

func _hit_enemy(enemy: Dictionary, damage: float, critical: bool = false) -> void:
	if enemy.hp <= 0:
		return
	enemy.hp -= damage
	enemy.flash = 0.12
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
		enemy.burn -= delta
		enemy.burn_tick -= delta
		if enemy.burn > 0 and enemy.burn_tick <= 0:
			enemy.burn_tick = 0.5
			_hit_enemy(enemy, relics.get("fire", 0) * 3.0)
			if enemy.hp <= 0:
				continue
		if enemy.knock.length() > 2:
			enemy.pos = _move_actor(enemy.pos, enemy.knock * delta, _enemy_radius(enemy))
			enemy.knock = enemy.knock.move_toward(Vector2.ZERO, delta * 650)
		if enemy.kind == "boss":
			_tick_boss(enemy, delta)
			continue
		var diff: Vector2 = player - enemy.pos
		var distance = diff.length()
		if enemy.windup > 0:
			enemy.windup -= delta
			if enemy.windup <= 0:
				_resolve_enemy_attack(enemy)
			continue
		if enemy.cooldown <= 0 and (distance < 62 or enemy.kind == "archer"):
			enemy.windup = 0.65 if enemy.kind == "brute" else 0.48
			enemy.target = player
			continue
		var speed = 68.0 + depth * 3.0
		if enemy.kind == "brute":
			speed = 47
		if enemy.kind == "archer":
			speed = 44 if distance > 235 else (-42 if distance < 150 else 0)
		var velocity = diff.normalized() * speed
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
					pos.x = clampf(pos.x, 100, 860)
					pos.y = clampf(pos.y, 150, 420)
					hazards.append({"pos": pos, "timer": 0.95, "life": 1.25, "fired": false})
			enemy.attack_index += 1
			enemy.cooldown = 0.75 if enraged else 1.2
		return
	var diff: Vector2 = player - enemy.pos
	if diff.length() > 80:
		enemy.pos = _move_actor(enemy.pos, diff.normalized() * delta * (55 if enraged else 38), 29)
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
		_emit(enemy.pos, GOLD, 20, 180)
		for j in 3:
			pickups.append({"pos": enemy.pos + Vector2(rng.randf_range(-18, 18), rng.randf_range(-18, 18)), "age": 0.0})
		enemies.remove_at(i)
	if killed_boss:
		run_embers += 35
		_finish_run(true)
		return
	if enemies.is_empty() and not room_clear and (room_type == "battle" or room_type == "elite") and state == "playing":
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

func _emit(pos: Vector2, color: Color, count: int, speed: float) -> void:
	for i in count:
		var velocity = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(speed * 0.15, speed)
		particles.append({"pos": pos, "velocity": velocity, "life": rng.randf_range(0.18, 0.5), "color": color, "size": rng.randi_range(2, 5)})

func _float_text(pos: Vector2, text: String, color: Color) -> void:
	numbers.append({"pos": pos, "text": text, "color": color, "life": 0.7})

func _tick_effects(delta: float) -> void:
	slash_time = maxf(0, slash_time - delta)
	shake = maxf(0, shake - delta * 25)
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
	if room_type == "treasure" and not room_clear and player.distance_to(Vector2(480, 275)) < 80:
		_offer_relics()
	elif room_type == "rest" and not room_clear and player.distance_to(Vector2(480, 275)) < 80:
		_show_rest()
	elif room_clear and player.distance_to(PORTAL) < 78:
		_show_routes()
	else:
		_notify("빛나는 제단이나 열린 북쪽 문 가까이에서 E를 누르세요.")

func _offer_relics() -> void:
	state = "reward"
	var pool = range(RELICS.size())
	pool.shuffle()
	offered = [pool[0], pool[1], pool[2]]
	var box = _new_panel("불씨가 남긴 선물", "유물은 이번 탐험 동안 중첩됩니다. 하나를 선택하세요.", 640)
	for i in 3:
		var relic: Dictionary = RELICS[offered[i]]
		_add_button(box, "[" + str(i + 1) + "]  " + relic.name + "  /  " + relic.tag + "\n" + relic.body, _choose_relic.bind(i), 82)
	_finish_panel()

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

func _show_routes() -> void:
	state = "route"
	var next = depth + 1
	var box = _new_panel("더 깊은 성소로", "지나온 방은 돌아갈 수 없습니다. 다음 길을 선택하세요.", 580)
	if next >= 6:
		_add_button(box, "수호자의 옥좌\n마지막 보스. 원형 탄막과 뿌리 폭발에 대비하세요.", _enter_room.bind(6, "boss"), 88)
	elif next == 3:
		_add_button(box, "이슬의 샘\n체력을 회복하거나 공격력을 축복받습니다.", _enter_room.bind(next, "rest"), 84)
		_add_button(box, "묻힌 보물방\n전투 없이 유물을 하나 획득합니다.", _enter_room.bind(next, "treasure"), 84)
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
	_add_label(box, "키보드 조준: T를 누르면 이동 방향으로 공격합니다.\n적의 붉은 예고를 보고 회피하세요. 3연격의 마지막 타격은 강합니다.\n적을 쓰러뜨린 자리의 불씨는 체력을 1 회복합니다.\n방 정리 > 유물 선택 > 북쪽 문(E) > 경로 선택 > 7번째 방 보스\n유물은 중첩됩니다. 사망 또는 승리 시 불씨로 영구 강화하세요.", 16, MUTED)
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
	var box = _new_panel("이번 탐험의 유물", "공격력 %d / 치명타 %d%% / 사거리 %d / 회복약 %d" % [attack_power, crit_chance * 100, attack_range, flasks], 650)
	var description = "아직 획득한 유물이 없습니다.\n전투를 마치거나 보물방을 찾아 유물을 획득하세요."
	if not relics.is_empty():
		description = ""
		for relic in RELICS:
			if relics.has(relic.id):
				description += relic.name + "  x" + str(relics[relic.id]) + "  [" + relic.tag + "]\n"
	_add_label(box, description.strip_edges(), 15, PAPER)
	_add_button(box, "조작법 보기", _show_help.bind("pause"), 44)
	_add_button(box, "일시정지로 돌아가기", _show_pause, 44)
	_finish_panel()

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
	buttons.clear()
	overlay = Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var dim = ColorRect.new()
	dim.color = Color(0.015, 0.035, 0.04, 0.88)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var center = CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var panel = PanelContainer.new()
	panel.custom_minimum_size.x = width
	var style = StyleBoxFlat.new()
	style.bg_color = Color("#10292e")
	style.border_color = Color("#668f7d")
	style.set_border_width_all(2)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 20
	style.content_margin_bottom = 20
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
		style.bg_color = Color("#1c3c40") if style_name != "hover" else Color("#2c5150")
		style.border_color = GOLD if style_name == "focus" else Color("#446a61")
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
				elif state == "pause" or state == "route":
					_resume_room()
				elif state == "inventory":
					_show_pause()
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
	if room_clear:
		return "북쪽 문에서 E: 다음 방 선택"
	if room_type == "treasure":
		return "보물상자 가까이에서 E"
	if room_type == "rest":
		return "샘 가까이에서 E"
	if room_type == "boss":
		return "수호자를 처치하세요"
	return "남은 적 %d" % enemies.size()

func _clock(seconds: float) -> String:
	return "%02d:%02d" % [int(seconds) / 60, int(seconds) % 60]

func _draw() -> void:
	if sprites.is_empty():
		return
	draw_rect(Rect2(0, 0, 960, 540), Color("#08171d"))
	var offset = Vector2(sin(time * 97), cos(time * 83)) * shake
	draw_set_transform(offset)
	_draw_room()
	_draw_entities()
	draw_set_transform(Vector2.ZERO)
	_draw_hud()

func _draw_room() -> void:
	draw_rect(Rect2(42, 84, 876, 401), Color("#0d242a"))
	for y in 8:
		for x in 18:
			var index = absi(x * 17 + y * 31 + room_seed) % tiles.size()
			draw_texture_rect(tiles[index], Rect2(48 + x * 48, 100 + y * 48, 48, 48), false)
	for x in 19:
		var pos = Vector2(24 + x * 48, 82)
		draw_rect(Rect2(pos, Vector2(46, 32)), Color("#36504e"))
		draw_rect(Rect2(pos + Vector2(3, 3), Vector2(40, 4)), Color("#537366"))
		draw_rect(Rect2(pos + Vector2(0, 26), Vector2(46, 6)), Color("#152e33"))
	draw_rect(Rect2(35, 111, 25, 372), Color("#182f34"))
	draw_rect(Rect2(900, 111, 25, 372), Color("#182f34"))
	draw_rect(Rect2(35, 461, 890, 22), Color("#142b30"))
	draw_line(Vector2(60, 461), Vector2(900, 461), Color("#527063"), 3)
	for side in [115, 800]:
		_draw_sprite("torch", Vector2(side, 143), 3)
		var flame = Vector2(side, 112 + sin(time * 8 + side) * 2)
		draw_rect(Rect2(flame - Vector2(2, 3), Vector2(4, 6)), PAPER)
		_draw_sprite("torch", Vector2(side, 443), 3)
	for side in [66.0, 889.0]:
		for i in 7:
			var root = Vector2(side, 156 + i * 45)
			var inward = 1.0 if side < 480 else -1.0
			var branch = root + Vector2(inward * (12 + i % 3 * 7), 16)
			draw_line(root - Vector2(0, 20), root + Vector2(0, 23), Color("#345b49"), 5)
			draw_line(root, branch, Color("#345b49"), 3)
			draw_rect(Rect2(branch - Vector2(4, 4), Vector2(9, 5)), Color("#52795a"))
	for i in 16:
		var x = 80 + (i * 137 + room_seed) % 790
		var y = 134 if i % 2 else 448
		for blade in 3:
			var grass = Vector2(x + blade * 4, y)
			draw_line(grass, grass + Vector2(blade - 1, -5 - i % 4), Color("#51765a"), 2)
	for obstacle in obstacles:
		draw_ellipse_shadow(obstacle, Vector2(31, 13))
		draw_rect(Rect2(obstacle - Vector2(26, 37), Vector2(52, 43)), Color("#172e31"))
		draw_rect(Rect2(obstacle - Vector2(23, 43), Vector2(46, 38)), Color("#49665b"))
		draw_rect(Rect2(obstacle - Vector2(19, 40), Vector2(38, 5)), Color("#77917a"))
		draw_rect(Rect2(obstacle - Vector2(22, 12), Vector2(44, 5)), Color("#315a4b"))
		draw_line(obstacle + Vector2(-5, -35), obstacle + Vector2(4, -13), Color("#203e39"), 3)
	_draw_floor_emblem(Vector2(480, 277))
	var gate_color = GOLD if room_clear else Color("#3f625c")
	draw_rect(Rect2(444, 95, 72, 31), Color("#08171d"))
	draw_rect(Rect2(444, 95, 5, 37), gate_color)
	draw_rect(Rect2(511, 95, 5, 37), gate_color)
	if room_clear:
		for i in 4:
			var y = 111 + fmod(time * 22 + i * 10, 40)
			draw_rect(Rect2(458 + i * 12, y, 3, 7), GOLD)
		_text(Vector2(480, 168), "[E]  다음 방", 15, GOLD, true)
	else:
		for x in range(455, 510, 12):
			draw_line(Vector2(x, 100), Vector2(x, 124), Color("#39544e"), 3)
	if room_type == "treasure" and not room_clear:
		_draw_sprite("chest", Vector2(480, 275), 4)
		_text(Vector2(480, 220), "[E]  유물 상자", 17, GOLD, true)
	if room_type == "rest" and not room_clear:
		draw_circle(Vector2(480, 275), 40, Color("#102d31"))
		draw_arc(Vector2(480, 275), 37, 0, TAU, 32, MINT, 3)
		for i in 5:
			draw_arc(Vector2(480, 275), 9 + fmod(time * 12 + i * 7, 26), 0, TAU, 20, Color("#477a6d"), 1)
		_text(Vector2(480, 220), "[E]  이슬의 샘", 17, MINT, true)
	for i in 22:
		var p = Vector2(80 + fmod(i * 137.0 + sin(time * 0.3 + i) * 24, 800), 140 + fmod(i * 79.0 - time * (4 + i % 3), 300))
		draw_rect(Rect2(p, Vector2(2, 2)), Color(0.8, 0.72, 0.42, 0.25 + sin(time + i) * 0.15))

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
	var actors: Array = enemies.duplicate()
	actors.append({"kind": "hero", "pos": player})
	actors.sort_custom(func(a, b): return a.pos.y < b.pos.y)
	for actor in actors:
		if actor.kind == "hero":
			_draw_player()
		else:
			_draw_enemy(actor)
	for projectile in projectiles:
		var tail: Vector2 = projectile.pos - projectile.velocity.normalized() * 12
		draw_line(tail, projectile.pos, RED, 5)
		draw_rect(Rect2(projectile.pos - Vector2(3, 3), Vector2(6, 6)), GOLD)
	for particle in particles:
		draw_rect(Rect2(particle.pos, Vector2.ONE * particle.size), particle.color)
	for number in numbers:
		var width = font.get_string_size(number.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 19).x
		draw_rect(Rect2(number.pos - Vector2(width / 2 + 3, 19), Vector2(width + 6, 24)), Color("#10292e"))
		_text(number.pos, number.text, 19, number.color, true)

func _draw_sprite(kind: String, pos: Vector2, scale_factor: float, tint: Color = Color.WHITE) -> void:
	draw_texture_rect(sprites[kind], Rect2((pos - Vector2(8, 13) * scale_factor).round(), Vector2(16, 16) * scale_factor), false, tint)

func draw_ellipse_shadow(pos: Vector2, size: Vector2) -> void:
	draw_set_transform(pos, 0, Vector2(1, size.y / size.x))
	draw_circle(Vector2.ZERO, size.x, Color(0.02, 0.07, 0.08, 0.55))
	draw_set_transform(Vector2(sin(time * 97), cos(time * 83)) * shake)

func _draw_player() -> void:
	draw_ellipse_shadow(player + Vector2(0, 5), Vector2(21, 8))
	var tint = Color.WHITE
	if invulnerable > 0 and int(time * 16) % 2:
		tint = Color(1, 1, 1, 0.45)
	var bob = sin(time * 16) * 1.5 if Input.get_vector("move_left", "move_right", "move_up", "move_down").length() > 0.1 and state == "playing" else 0.0
	_draw_sprite("hero", player + Vector2(0, bob), 3, tint)
	var hand = player + facing * 17 + Vector2(0, -14)
	var blade = facing * 27
	draw_line(hand, hand + blade, PAPER, 5)
	draw_line(hand - facing * 3, hand + facing * 3, GOLD, 9)
	draw_line(hand - facing * 9, hand - facing * 3, Color("#a27047"), 4)
	if not mouse_aim:
		draw_line(player + facing * 36, player + facing * 43, GOLD, 3)
	if slash_time > 0:
		var radius = 136.0 if slash_heavy else attack_range
		var progress = 1.0 - slash_time / (0.24 if slash_heavy else 0.16)
		var start = 0.0 if slash_heavy else slash_angle - 1.3
		var end = TAU if slash_heavy else slash_angle + 1.3
		var color = GOLD if slash_heavy or combo == 3 else PAPER
		draw_arc(player, radius * (0.8 + progress * 0.2), start, end, 30, Color(color, 1.0 - progress), 7)
		draw_arc(player, radius * 0.72, start + 0.12, end - 0.12, 28, Color(MINT, (1.0 - progress) * 0.6), 3)

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
	var scale_factor = 5.0 if enemy.kind == "boss" else (3.5 if enemy.kind == "brute" else 3.0)
	_draw_sprite(enemy.kind, enemy.pos + Vector2(0, sin(time * 5 + enemy.pos.x) * 1.5), scale_factor, tint)
	if enemy.elite:
		draw_arc(enemy.pos + Vector2(0, -24), 26, PI, TAU, 16, GOLD, 2)
	if enemy.burn > 0:
		for i in 3:
			var p: Vector2 = enemy.pos + Vector2(-12 + i * 12, -20 - fmod(time * 30 + i * 13, 25))
			draw_rect(Rect2(p, Vector2(4, 7)), GOLD)
	if enemy.kind != "boss":
		var pos: Vector2 = enemy.pos + Vector2(-22, -52)
		_bar(Rect2(pos, Vector2(44, 4)), enemy.hp / enemy.max_hp, GOLD if enemy.elite else RED)

func _draw_hud() -> void:
	draw_rect(Rect2(0, 0, 960, 76), Color("#0b2027"))
	draw_line(Vector2(24, 76), Vector2(936, 76), Color("#456357"), 2)
	_text(Vector2(25, 28), "불씨의 성소", 22, GOLD)
	_text(Vector2(25, 54), "순례자  /  단련 " + str(meta_level), 14, MUTED)
	_bar(Rect2(215, 20, 220, 16), hp / max_hp, Color("#9f453f"))
	_text(Vector2(325, 33), "%d / %d" % [ceili(hp), int(max_hp)], 13, PAPER, true)
	_text(Vector2(215, 58), "불씨 %d    유물 %d    %s" % [run_embers, _relic_count(), _clock(run_time)], 15, GOLD)
	_text(Vector2(475, 29), _room_title(), 19, PAPER)
	_text(Vector2(475, 55), _room_objective(), 14, MINT)
	for i in 7:
		var pos = Vector2(773 + i * 23, 26)
		if i > 0:
			draw_line(pos - Vector2(16, 0), pos, Color("#456357"), 2)
		draw_rect(Rect2(pos - Vector2(6, 6), Vector2(12, 12)), GOLD if i == depth else (Color("#6b9982") if i < depth else Color("#28464a")))
	_text(Vector2(775, 59), "성소  %d / 7" % (depth + 1), 14, MUTED)
	draw_rect(Rect2(0, 483, 960, 57), Color("#0b2027"))
	draw_line(Vector2(24, 483), Vector2(936, 483), Color("#456357"), 2)
	_ability(24, "J / 좌클릭", "3연 베기", attack_cd, attack_interval, 0)
	_ability(186, "Q / 우클릭", "불씨 폭발", skill_cd, skill_duration, 1)
	_ability(348, "Space", "무적 회피", dash_cd, dash_duration, 2)
	_ability(510, "F  x%d" % flasks, "회복약", 0, 1, 3)
	_text(Vector2(681, 507), "E  상호작용    Tab  수첩", 14, PAPER)
	_text(Vector2(681, 529), "Esc  일시정지   T  조준   M  소리", 13, MUTED)
	if toast_time > 0:
		var text_width = font.get_string_size(toast, HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x
		draw_rect(Rect2(480 - text_width / 2 - 16, 440, text_width + 32, 30), Color("#0b2027"))
		_text(Vector2(480, 461), toast, 16, GOLD, true)
	for enemy in enemies:
		if enemy.kind == "boss":
			_bar(Rect2(260, 90, 440, 12), enemy.hp / enemy.max_hp, Color("#b95c52"))
			_text(Vector2(480, 119), "가시 왕관의 수호자" + ("  /  분노" if enemy.phase == 1 else ""), 14, PAPER, true)

func _relic_count() -> int:
	var count = 0
	for value in relics.values():
		count += value
	return count

func _ability(x: float, key: String, title: String, cooldown: float, full: float, icon: int) -> void:
	var pos = Vector2(x, 495)
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
	_text(pos + Vector2(43, 12), key, 13, color)
	_text(pos + Vector2(43, 32), title, 15, PAPER)

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
	player = Vector2(480, 275)
	_interact()
	assert(state == "rest")
	hp = 1
	buttons[0].pressed.emit()
	assert(room_clear and hp > 1)
	_enter_room(3, "treasure")
	player = Vector2(480, 275)
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
