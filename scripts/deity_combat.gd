extends RefCounted

const CODES = ["N", "F", "I", "W", "E", "G", "A", "L", "Q", "H"]
const ELEMENTS = ["무속성", "불", "얼음", "물", "땅", "풀", "바람", "번개", "양자", "허수"]
const STATUS = {"F": "burn", "I": "chill", "W": "wave", "E": "crack", "G": "spore", "A": "pressure", "L": "charge", "Q": "void", "H": "order"}
const CONTRACT_NAMES = ["무거운 손", "봉인된 힘", "침묵의 맹세", "무거운 발걸음", "갈라진 갑옷", "메마른 피", "탐욕의 대가", "불안정한 육체", "굶주린 권능", "추적자의 표식"]
const CONTRACT_TEXT = ["약공격 속도 -20%", "강공격 피해 -30%", "Q 대기시간 +40%", "이동 속도 -15%", "받는 피해 +20%", "회복량 -60%", "전투 금화 -50%", "최대 체력 -20%, 체력 비율 유지", "권능 충전 -70%", "전투방마다 강화 적 +1"]
const REWARD_TEXT = ["약공격 피해 +30%", "강공격 피해 +40%", "Q 피해 +35%", "이동 속도 +15%", "받는 피해 -10%", "최대 체력 +20%, 증가분 회복", "전투 금화 +30%", "희귀·영웅 등장 가중치 증가", "권능 충전 +20%", "한 번 죽음 거부, 체력 30%"]
var g
var clock = 0.0
var gauge = 0.0
var equipped = ""
var jobs: Array = []
var zones: Array = []
var seeds: Array = []
var timers: Dictionary = {}
var counters: Dictionary = {}
var contracts: Array = []
var rewards: Dictionary = {}
var room_limits: Dictionary = {}
var last_dash = -100.0
var last_hurt = -100.0
var hit_window = 0.0
var hit_gauge = 0
var dash_removed = 0
var dash_targets: Dictionary = {}
var shield_before = 0.0
var source_enemy: Dictionary = {}
var last_room_combat = false
var action_serial = 0

func _init(game) -> void:
	g = game

func reset() -> void:
	clock = 0
	gauge = 0
	equipped = ""
	jobs.clear()
	zones.clear()
	seeds.clear()
	timers.clear()
	counters.clear()
	contracts.clear()
	rewards.clear()
	room_limits.clear()
	last_dash = -100
	last_hurt = -100
	hit_window = 0
	hit_gauge = 0

func has(id: String) -> bool:
	return g.active_augments.get(id, false)

func value(id: String, base: float) -> float:
	if not has(id):
		return 0.0
	return base * g.Augments.scale(g.augments[id], g.augment_levels.get(id, 1))

func faith(code: String, count: int = 6) -> bool:
	return g.tag_counts.get(ELEMENTS[CODES.find(code)], 0) >= count

func code_for(action: String) -> String:
	return str(g.core_slots.get(action, "")).left(1)

func element_for(action: String) -> String:
	var code = code_for(action)
	return ELEMENTS[CODES.find(code)] if code in CODES else "무속성"

func reward_has(id: String) -> bool:
	return rewards.get(id, false)

func penalty(id: String) -> bool:
	return contracts.any(func(item): return item.id == id)

func ready(key: String, interval: float) -> bool:
	if timers.get(key, -1.0) > clock:
		return false
	timers[key] = clock + interval
	return true

func target_ready(target: Dictionary, key: String, interval: float) -> bool:
	return ready("%s:%d" % [key, target.uid], interval)

func count(key: String, every: int) -> bool:
	counters[key] = counters.get(key, 0) + 1
	return counters[key] % every == 0

func limit(key: String, maximum: int) -> bool:
	if room_limits.get(key, 0) >= maximum:
		return false
	room_limits[key] = room_limits.get(key, 0) + 1
	return true

func recompute() -> void:
	if not equipped.is_empty() and not faith(equipped, 4):
		equipped = ""
	if equipped.is_empty():
		for code in CODES:
			if faith(code, 4):
				equipped = code
				break
	g.dash_charges = mini(g.dash_charges, max_dashes())

func max_dashes() -> int:
	return 3 if has("A06") else 2

func attack_speed() -> float:
	var bonus = value("A01", 0.1)
	bonus += value("N09", 0.15) if timers.get("kill_speed", 0) > clock else 0.0
	bonus += 0.3 if timers.get("N_power", 0) > clock else 0.0
	bonus += 0.3 if timers.get("A_legend", 0) > clock else 0.0
	return (1 + bonus) * (0.8 if penalty("C01") else 1.0)

func speed() -> float:
	var bonus = value("A05", 0.1)
	bonus += value("A07", 0.2) if clock - last_dash <= 2 else 0.0
	bonus += 0.15 if reward_has("R04") else 0.0
	return g.move_speed * (1 + bonus) * (0.85 if penalty("C04") else 1.0)

func skill_cooldown_factor() -> float:
	return 1.4 if penalty("C03") else 1.0

func heal_factor() -> float:
	return 0.4 if penalty("C06") else 1.0

func currency_factor() -> float:
	return (1 + value("W10", 0.15) + (0.3 if reward_has("R07") else 0.0)) * (0.5 if penalty("C07") else 1.0)

func add_gauge(amount: float) -> void:
	gauge = minf(100, gauge + amount * (0.3 if penalty("C09") else 1.0) * (1.2 if reward_has("R09") else 1.0))

func statuses(target: Dictionary) -> Dictionary:
	if target.is_empty():
		return {}
	if not target.has("deity_status"):
		target.deity_status = {}
	return target.deity_status

func stacks(target: Dictionary, name: String) -> int:
	var status: Dictionary = statuses(target).get(name, {})
	return status.get("stacks", 0) if status.get("until", 0) > clock else 0

func clear(target: Dictionary, name: String) -> void:
	statuses(target).erase(name)

func add_status(target: Dictionary, name: String, amount: int = 1, check_freeze: bool = true) -> void:
	var duration = {"rupture": 4.0, "burn": 4.0, "chill": 4.0, "wave": 5.0, "crack": 4.0, "spore": 5.0, "pressure": 4.0, "charge": 5.0, "void": 5.0, "order": 6.0}[name]
	var maximum = {"burn": 5 + (3 if has("F06") else 0), "chill": 6, "spore": 5, "charge": 3, "order": 4}.get(name, 1)
	duration += {"burn": value("F05", 2), "chill": value("I05", 3), "spore": value("G05", 3), "charge": value("L06", 3), "void": value("Q06", 4), "order": value("H07", 4)}.get(name, 0.0)
	var old: Dictionary = statuses(target).get(name, {})
	var total = mini(maximum, stacks(target, name) + amount)
	statuses(target)[name] = {"stacks": total, "until": clock + duration, "next": old.get("next", clock + 1), "power": g.attack_power}
	if name == "chill" and check_freeze:
		check_chill(target)
	if name == "charge" and total >= 3:
		clear(target, name)
		charge_explosion(target)
	if name == "order" and total >= 4:
		clear(target, name)
		deal(target, g.attack_power * (0.7 + value("H08", 0.28)), "허수")
		if has("H06") and ready("H06", 1):
			g.skill_cd = maxf(0, g.skill_cd - value("H06", 0.4))
		if has("H09") and ready("H09", 2):
			shield(g.attack_power * value("H09", 0.1), 4)
		if has("H10") and target_ready(target, "H10", 6):
			g.elemental.control(target, "생장", 1)
		if faith("H") and count("H_myth", 4):
			g.skill_cd = maxf(0, g.skill_cd - 2)
		if has("D22") and stacks(target, "void") > 0 and target_ready(target, "D22", 2):
			delay(target.pos, g.attack_power, "양자", 0.8, 20, target)

func enemy_movement(target: Dictionary) -> float:
	var slow = stacks(target, "chill") * 0.05
	if target.cc_immune:
		slow = minf(maxf(0, 1 - 0.8 / g.elemental.movement(target)), slow)
	return 1 - slow

func check_chill(target: Dictionary, heavy: bool = false) -> void:
	if stacks(target, "chill") < 6:
		return
	if has("I-L") and heavy and target_ready(target, "I-L", 5):
		clear(target, "chill")
		deal(target, g.attack_power * 2, "얼음")
	elif has("I06") and not (heavy and has("I-L")) and target_ready(target, "I06", 6):
		clear(target, "chill")
		g.elemental.control(target, "빙결", 1)

func enemy_attack_speed(target: Dictionary) -> float:
	var reduction = value("I08", 0.15) if stacks(target, "chill") >= 6 else 0.0
	reduction += value("L08", 0.1) if stacks(target, "charge") > 0 else 0.0
	return maxf(0.1, 1 - reduction)

func begin_action(action: String) -> Dictionary:
	action_serial += 1
	var result = {"id": action_serial, "bonus": 0.0, "crit": false}
	if action == "heavy":
		if timers.get("N04", 0) > clock:
			result.bonus += value("N04", 0.35)
		if counters.get("N_myth_ready", 0) > 0:
			result.crit = true
			counters["N_myth_ready"] = 0
		if counters.get("H05_ready", 0) > 0:
			result.bonus += value("H05", 0.4)
			counters["H05_ready"] = 0
	if timers.get("N04", 0) > clock:
		result.bonus += value("N04", 0.35) if action != "heavy" else 0.0
		timers["N04"] = 0
	if faith("A") and clock - last_dash <= 1 and not counters.get("dash_myth_used", false):
		result.bonus += 0.3
		counters["dash_myth_used"] = true
	if action == "skill":
		result.bonus += value("H12", 0.5) if not counters.get("first_skill", false) else 0
		counters["first_skill"] = true
		counters["H_skill"] = counters.get("H_skill", 0) + 1
	return result

func direct(target: Dictionary, action: String, base: float, context: Dictionary, first: bool) -> void:
	var code = code_for(action)
	var element = element_for(action)
	var bonus: float = context.bonus
	bonus += 0.1 if code in CODES and faith(code, 2) else 0.0
	bonus += {"N01": value("N01", 0.25), "N02": value("N02", 0.4), "F01": value("F01", 0.1), "F02": value("F02", 0.25), "F03": value("F03", 0.2), "I02": value("I02", 0.25), "I03": value("I03", 0.2), "W02": value("W02", 0.25), "W03": value("W03", 0.2), "E02": value("E02", 0.3), "G02": value("G02", 0.15), "L02": value("L02", 0.2), "Q02": value("Q02", 0.25), "Q03": value("Q03", 0.2), "H02": value("H02", 0.2)}.get(g.core_slots.get(action, ""), 0.0)
	bonus += value("N10", 0.2) if nearby(g.player, 200).size() == 1 else 0.0
	bonus += value("N12", 0.3) if target.hp <= target.max_hp * 0.2 else 0.0
	bonus += value("A08", minf(0.2, maxf(0, speed() / g.move_speed - 1) * 0.4))
	bonus += 0.2 if element == "땅" and faith("E") and shield_active() else 0.0
	bonus += 0.2 if element == "얼음" and faith("I") and stacks(target, "chill") > 0 else 0.0
	bonus += value("W08", 0.2) if element == "물" and target.cc_immune else 0.0
	bonus += value("F12", 0.2) if element == "불" and inside_zone("fire", g.player) else 0.0
	bonus += 0.2 if element == "바람" and timers.get("A_legend", 0) > clock else 0.0
	bonus += value("L11", 0.25) if element == "번개" and timers.get("L11", 0) > clock else 0.0
	bonus += value("D16", 0.2) if shield_active() and stacks(target, "spore") >= 5 else 0.0
	if action == "heavy":
		bonus += 0.15 if stacks(target, "rupture") > 0 else 0.0
		bonus += 0.4 if reward_has("R02") else 0.0
	elif action == "light":
		bonus += 0.3 if reward_has("R01") else 0.0
	elif action == "skill":
		bonus += value("I10", 0.2) if clock - last_hurt >= 1 else 0.0
		bonus += 0.35 if reward_has("R03") else 0.0
	var critical: bool = context.crit or g.rng.randf() < g.crit_chance + value("N05", 0.05) + (0.2 if timers.get("N_power", 0) > clock else 0.0)
	var damage = base * (1 + bonus) * ((2 + value("N06", 0.25)) if critical else 1.0) * (0.7 if action == "heavy" and penalty("C02") else 1.0)
	var defense: float = target.defense
	target.defense = defense * (1 - (value("E07", 0.18) if has("E07") else 0.1) if stacks(target, "crack") > 0 else 1.0) * (1 - value("N03", 0.2) if code == "N" and action == "skill" else 1.0)
	g._element_hit(g.hero, target, damage, element, critical)
	target.defense = defense
	if clock - hit_window >= 1:
		hit_window = clock
		hit_gauge = 0
	if hit_gauge < 3:
		add_gauge(1)
		hit_gauge += 1
	if action == "heavy":
		heavy_procs(target, damage, critical)
	if critical and has("N07"):
		add_status(target, "rupture")
	if action == "light":
		if first and faith("N") and count("N_basic", 3):
			counters["N_myth_ready"] = 1
		if first and has("H05") and count("H_basic", 4):
			counters["H05_ready"] = 1
		if has("Q07") and count("Q_basic", 5):
			shadow(target.pos, g.attack_power * value("Q07", 0.6), 0, 40, {}, true)
	if code == "N" and action == "heavy":
		add_status(target, "rupture")
	elif code == "G" and action == "skill":
		if first:
			spawn_seed(target.pos)
	elif code == "L" and action == "skill":
		if first:
			for other in closest(target.pos, 2, target):
				deal(other, g.attack_power * value("L03", 0.3), "번개")
	elif code == "A" and action == "skill":
		if first:
			pull(target.pos, 160)
		if has("D19") and first:
			for other in nearby(target.pos):
				add_status(other, "spore")
		if has("D05") and ready("D05", 4) and inside_zone("fire", target.pos):
			zones = zones.filter(func(zone): return zone.name != "fire" or zone.pos.distance_to(target.pos) > zone.radius)
			blast(target.pos, g.attack_power * 1.8, "불")
		if has("D14"):
			timers["D14"] = clock + 3
	elif code == "A" and action == "light":
		pass
	elif STATUS.has(code):
		add_status(target, STATUS[code], 2 if action in ["heavy", "skill"] and code in ["F", "I", "G", "L", "H"] else 1, code != "I")
	if element == "불" and faith("F") and stacks(target, "burn") > 0:
		add_status(target, "burn", 0)
	if has("I12") and stacks(target, "chill") > 0:
		target["healing_multiplier"] = maxf(0, 1 - value("I12", 0.5))
	if has("Q10") and stacks(target, "void") > 0 and not target.cc_immune:
		target["death_ability_disabled"] = true
	if has("D21") and clock - last_dash < 2 and not counters.get("D21_used", false):
		add_status(target, "charge")
		counters["D21_used"] = true
	if action == "skill" and first:
		var repeats = 2 if has("H-L") and counters.get("H_skill", 0) % 3 == 0 else 1
		if has("E11"):
			delay(target.pos, g.attack_power * value("E11", 0.6), "땅", 0.8)
		for i in repeats:
			if has("H11"):
				delay(target.pos, g.attack_power * value("H11", 0.6), "허수", 1 + i * 0.3)
		if has("A11") and ready("A11", 1):
			g.dash_cd = maxf(0, g.dash_cd - value("A11", 0.3))
	check_chill(target, action == "heavy")

func heavy_procs(target: Dictionary, damage: float, critical: bool) -> void:
	if stacks(target, "rupture") > 0:
		if has("N08") and target_ready(target, "N08", 1):
			deal(target, g.attack_power * value("N08", 0.3), "무속성")
		if has("N-L") and critical:
			deal(target, damage * 0.4, "무속성")
	if stacks(target, "burn") >= (8 if has("F06") else 5) and has("F07"):
		var amount = stacks(target, "burn")
		clear(target, "burn")
		blast(target.pos, g.attack_power * value("F07", 0.25) * amount * (1.4 if has("D01") and stacks(target, "chill") > 0 else 1.0), "불")
		if has("F-L"):
			zone("phoenix", target.pos, 3, 1, g.attack_power * 0.6, "불")
			var phoenix = zones.filter(func(item): return item.name == "phoenix")
			if phoenix.size() > 2:
				zones.erase(phoenix[0])
	if has("I07") and g.elemental.active(target, "빙결"):
		blast(target.pos, g.attack_power * value("I07", 0.8), "얼음")
	check_chill(target, true)
	if has("E08") and stacks(target, "crack") > 0 and target_ready(target, "E08", 1):
		deal(target, g.attack_power * value("E08", 0.5), "땅")
	if has("G11") and stacks(target, "spore") >= 5 and target_ready(target, "G11", 6):
		g.elemental.control(target, "생장", 1)
	if stacks(target, "pressure") > 0:
		clear(target, "pressure")
		deal(target, g.attack_power * 0.4, "바람")
		if has("A12") and target_ready(target, "A12", 2):
			pull(target.pos, 80)
		if has("D10") and ready("D10", 2):
			for other in nearby(target.pos):
				add_status(other, "chill", 2)
		if has("D17") and stacks(target, "crack") > 0 and target_ready(target, "D17", 2):
			blast(target.pos, g.attack_power * 0.8, "땅")
	if has("Q05") and stacks(target, "void") > 0 and target_ready(target, "Q05", 1):
		shadow(target.pos, g.attack_power * value("Q05", 0.5), 0.8, 20, target)
	if faith("Q") and ready("Q_myth", 3):
		shadow(target.pos, g.attack_power * 0.8, 0.8)
	if has("D02") and stacks(target, "burn") > 0 and stacks(target, "wave") > 0 and target_ready(target, "D02", 3):
		deal(target, g.attack_power, "물")
	if has("D12") and stacks(target, "wave") > 0 and ready("D12", 3):
		shield(g.attack_power * 0.15, 4)

func end_action(action: String, _context: Dictionary, _hits: int) -> void:
	if action == "skill" and has("Q12") and ready("Q12", 5):
		counters["Q12_ready"] = true

func deal(target: Dictionary, damage: float, element: String, category: String = "augment", snapshot_bonus: float = -1) -> void:
	if target.hp <= 0:
		return
	var code = CODES[ELEMENTS.find(element)]
	var bonus = (0.1 if faith(code, 2) else 0.0) if snapshot_bonus < 0 else snapshot_bonus
	bonus += 0.25 if category == "area" and faith("W") and stacks(target, "wave") > 0 else 0.0
	var defense: float = target.defense * (1 - (value("E07", 0.18) if has("E07") else 0.1)) if stacks(target, "crack") > 0 else target.defense
	g._hit_enemy(target, damage * (1 + bonus) * 100 / (100 + maxf(0, defense)))

func nearby(pos: Vector2, radius: float = 120) -> Array:
	return g.enemies.filter(func(enemy): return enemy.hp > 0 and enemy.pos.distance_to(pos) <= radius)

func closest(pos: Vector2, maximum: int, except: Dictionary = {}) -> Array:
	var result = nearby(pos, 120 + value("L06", 80))
	result = result.filter(func(enemy): return enemy != except)
	result.sort_custom(func(a, b): return a.pos.distance_squared_to(pos) < b.pos.distance_squared_to(pos))
	return result.slice(0, maximum)

func blast(pos: Vector2, damage: float, element: String, radius: float = 120, category: String = "area", snapshot_bonus: float = -1) -> void:
	g.impacts.append({"pos": pos, "life": 0.3, "kind": "element", "radius": radius, "element": element})
	for target in nearby(pos, radius):
		deal(target, damage, element, category, snapshot_bonus)

func delay(pos: Vector2, damage: float, element: String, after: float, radius: float = 120, target: Dictionary = {}) -> void:
	jobs.append({"at": clock + after, "pos": pos, "damage": damage, "element": element, "radius": radius, "target": target, "bonus": 0.1 if faith(CODES[ELEMENTS.find(element)], 2) else 0.0})

func shadow(pos: Vector2, damage: float, after: float, radius: float = 120, target: Dictionary = {}, blade: bool = false) -> void:
	damage *= 1 + value("Q11", 0.35)
	delay(pos, damage, "양자", after, radius, target)
	if blade and has("Q-L"):
		delay(pos, damage * 0.7, "양자", after + 0.2, radius, target)

func pull(pos: Vector2, force: float) -> void:
	for target in nearby(pos):
		if not target.cc_immune:
			target.knock = (pos - target.pos).normalized() * force

func knock_hit(target: Dictionary, action: String) -> void:
	if action not in ["heavy", "skill"] or code_for(action) != "W" or target.cc_immune:
		return
	var direction: Vector2 = (target.pos - g.player).normalized()
	target.knock = direction * 320
	if has("W07") and g.rng.randf() < value("W07", 0.3):
		jobs.append({"at": clock + 0.2, "pos": target.pos, "damage": 0.0, "element": "물", "radius": 20, "target": target, "force": direction * 320})
	target.wall_hit = false
	target["water_knock"] = true
	if has("W06") and target_ready(target, "W06", 1) and stacks(target, "wave") > 0:
		deal(target, g.attack_power * value("W06", 0.3), "물")

func wall_hit(target: Dictionary) -> void:
	if not target.get("water_knock", false) or not has("W05") or not target_ready(target, "W05", 1):
		return
	var bonus = (0.6 if has("D07") and stacks(target, "chill") > 0 else 0.0) + (0.5 if has("D14") and timers.get("D14", 0) > clock else 0.0)
	deal(target, g.attack_power * value("W05", 0.8) * (1 + bonus), "물")
	if has("W-L"):
		blast(target.pos, g.attack_power * 1.2, "물")

func charge_explosion(target: Dictionary) -> void:
	var damage: float = g.attack_power * (0.6 + value("L10", 0.21))
	damage *= 1.35 if has("D20") and stacks(target, "spore") >= 5 else 1.0
	deal(target, damage, "번개")
	if has("L05"):
		var chain_count = 4 if has("L-L") else 2
		chain_count += 2 if has("D15") and stacks(target, "wave") > 0 else 0
		for other in closest(target.pos, chain_count, target):
			deal(other, damage * (0.8 if has("L-L") else value("L05", 0.5)) * (1.4 if has("D11") and stacks(target, "chill") > 0 else 1.0), "번개")
	if has("L07") and g.rng.randf() < value("L07", 0.25):
		deal(target, g.attack_power * value("L07", 0.4), "번개")
	if faith("L") and count("L_myth", 5):
		var candidates = closest(g.player, 1)
		if not candidates.is_empty():
			deal(candidates[0], g.attack_power * 1.2, "번개")
	if has("D06") and stacks(target, "burn") > 0:
		statuses(target).burn.stacks -= 1
		deal(target, g.attack_power * 0.5, "불")
	if has("D18") and ready("D18", 2):
		shield(g.attack_power * 0.1, 4)

func shield_active() -> bool:
	return g.hero.shield > 0 and g.hero.shield_until > g.elemental.clock

func shield(amount: float, duration: float) -> void:
	if has("D03") and inside_zone("fire", g.player):
		amount *= 1.4
	g.elemental.grant_shield(g.hero, minf(g.max_hp * 0.5, amount), duration)
	if has("D08") and ready("D08", 3):
		for target in nearby(g.player):
			add_status(target, "chill", 2)

func before_hurt(_damage: float) -> void:
	shield_before = g.hero.shield if shield_active() else 0.0
	last_hurt = clock
	if has("L09") and ready("L09", 2):
		for target in nearby(g.player):
			add_status(target, "charge")

func after_shield_damage(_damage: float) -> void:
	if shield_before > g.hero.shield:
		if has("E06") and ready("E06", 1):
			blast(g.player, g.attack_power * value("E06", 0.4), "땅")
		if g.hero.shield <= 0 and has("E-L") and ready("E-L", 10):
			blast(g.player, g.attack_power * 2.5, "땅")

func incoming_factor() -> float:
	var reduction = value("E05", 0.1) if shield_active() else 0.0
	reduction += value("N11", 0.15) if g.hp <= g.max_hp * 0.35 else 0.0
	reduction += value("E10", 0.2) if g.pending_strike.get("action", "") == "heavy" else 0.0
	for area in zones:
		if area.name == "order" and area.until > clock and area.pos.distance_to(g.player) <= area.radius:
			reduction += area.reduction
			break
	reduction += 0.1 if reward_has("R05") else 0.0
	for pair in [["F09", "burn"], ["I09", "chill"], ["W11", "wave"]]:
		if has(pair[0]) and stacks(source_enemy, pair[1]) > 0:
			reduction += value(pair[0], 0.1)
	return maxf(0.1, 1 - reduction + (0.2 if penalty("C05") else 0.0))

func incoming_dodge() -> bool:
	return has("Q08") and clock - last_dash <= 2 and g.rng.randf() < value("Q08", 0.1)

func revive() -> bool:
	if reward_has("R10") and not counters.get("revived", false):
		counters["revived"] = true
		g.hp = g.max_hp * 0.3
		g.hero.hp = g.hp
		g.invulnerable = 1.5
		g._notify("거부된 죽음: 체력 30%로 생존")
		return true
	return false

func dash_start() -> void:
	if counters.get("Q12_ready", false):
		g.dash_cd *= maxf(0, 1 - value("Q12", 0.5))
		counters["Q12_ready"] = false
	dash_removed = 0
	dash_targets.clear()
	counters["D21_used"] = false
	counters["dash_myth_used"] = false
	if has("A-L") and clock - last_dash <= 3 and ready("A-L", 8):
		timers["A_legend"] = clock + 3
	last_dash = clock
	timers["N04"] = clock + 2 if has("N04") else 0
	match code_for("dash"):
		"F": zone("fire", g.player, 2, 1, g.attack_power * value("F04", 0.2), "불")
		"I":
			for target in nearby(g.player):
				add_status(target, "chill", 2)
		"G":
			if ready("G04", 2):
				spawn_seed(g.player)
		"L":
			for target in nearby(g.player):
				add_status(target, "charge")
		"Q": shadow(g.player, g.attack_power * value("Q04", 0.4), 1)
	if has("A04"):
		g.dash_time *= 1 + value("A04", 0.15)

func dash_path(_delta: float) -> void:
	if has("W04"):
		for target in nearby(g.player, 45):
			if not dash_targets.has(target.uid):
				dash_targets[target.uid] = true
				deal(target, g.attack_power * value("W04", 0.35), "물")
				add_status(target, "wave")

func dash_end() -> void:
	if has("E04") and ready("E04", 4):
		shield(g.attack_power * value("E04", 0.15), 4)
	if has("A04"):
		for target in nearby(g.player):
			add_status(target, "pressure")
	if has("H04"):
		zone("order", g.player, 2, 1, 0, "허수")

func remove_projectile() -> bool:
	if g.dash_time <= 0 or not has("A09") or dash_removed >= 3:
		return false
	dash_removed += 1
	if has("A10") and dash_removed == 1:
		var targets = closest(g.player, 1)
		if not targets.is_empty():
			deal(targets[0], g.attack_power * value("A10", 0.35), "바람")
	return true

func zone(name: String, pos: Vector2, duration: float, interval: float, damage: float, element: String, radius: float = 120) -> void:
	zones.append({"name": name, "pos": pos, "until": clock + duration, "next": clock + interval, "interval": interval, "damage": damage, "element": element, "radius": radius, "bonus": 0.1 if faith(CODES[ELEMENTS.find(element)], 2) else 0.0, "reduction": value("H04", 0.1) if name == "order" else 0.0})

func inside_zone(name: String, pos: Vector2) -> bool:
	return zones.any(func(item): return item.name == name and item.until > clock and item.pos.distance_to(pos) <= item.radius)

func spawn_seed(pos: Vector2, generated: bool = false) -> void:
	var maximum = 5 if has("G07") else 3
	if seeds.size() >= maximum:
		var oldest: Dictionary = seeds.pop_front()
		explode_seed(oldest)
	seeds.append({"pos": pos, "at": clock + 2, "damage": g.attack_power * 0.5 * (1 + value("G08", 0.4)), "generated": generated, "bonus": 0.1 if faith("G", 2) else 0.0})

func explode_seed(item: Dictionary) -> void:
	var targets = nearby(item.pos)
	for target in targets:
		deal(target, item.damage * (1.5 if has("D04") and stacks(target, "burn") > 0 else 1.0), "풀", "area", item.bonus)
		if faith("G"):
			add_status(target, "spore")
		if has("G-L") and not item.generated and stacks(target, "spore") >= 5 and ready("G-L", 2):
			spawn_seed(target.pos, true)
		if has("D13") and stacks(target, "wave") > 0 and ready("D13", 3) and limit("D13", 5):
			g._heal(g.max_hp * 0.01)
	if targets.size() >= 3 and has("G09") and limit("G09", 5):
		g._heal(g.max_hp * value("G09", 0.01))

func killed(target: Dictionary) -> void:
	if has("N09"):
		timers["kill_speed"] = clock + 4
	if stacks(target, "burn") > 0:
		if has("F08"):
			for other in nearby(target.pos):
				add_status(other, "burn", 2)
		if has("F10"):
			var amount = minf(value("F10", 2), 20.0 - room_limits.get("F10_gauge", 0.0))
			if amount > 0:
				room_limits["F10_gauge"] = room_limits.get("F10_gauge", 0.0) + amount
				add_gauge(amount)
	if has("I11") and stacks(target, "chill") > 0:
		for other in nearby(target.pos):
			add_status(other, "chill", 2)
	if stacks(target, "spore") > 0:
		if has("G06"):
			for other in nearby(target.pos):
				add_status(other, "spore", 2)
		if has("G10") and limit("G10", 10):
			g._heal(value("G10", 1))
	if has("W12") and stacks(target, "wave") > 0:
		blast(target.pos, g.attack_power * value("W12", 0.5), "물")
	if has("L12") and stacks(target, "charge") > 0:
		var targets = closest(target.pos, 1, target)
		if not targets.is_empty():
			add_status(targets[0], "charge", 2)
	if has("Q09") and stacks(target, "void") > 0 and limit("Q09", 10):
		shield(g.attack_power * value("Q09", 0.1), 4)
	if has("E12") and target.elite and limit("E12", 1):
		g.gold += 8

func enter_room(combat: bool) -> void:
	jobs.clear()
	zones.clear()
	seeds.clear()
	room_limits.clear()
	counters["first_skill"] = false
	last_room_combat = combat
	if combat and has("E09"):
		shield(g.max_hp * value("E09", 0.1), 3600)
	if combat and penalty("C10"):
		g._spawn_enemy("brute", g.ALTAR + Vector2(100, 0), true)

func complete_room() -> void:
	if not last_room_combat:
		return
	last_room_combat = false
	if has("W09"):
		g._heal(g.max_hp * value("W09", 0.02))
	if has("G12"):
		var choices = g.augment_data.filter(func(item): return g.augments.has(item.id) and item.kind == "normal" and g.augment_levels.get(item.id, 1) < 5 and item.get("scalable", false))
		if not choices.is_empty():
			var chosen: Dictionary = choices[g.rng.randi_range(0, choices.size() - 1)]
			g.augment_xp[chosen.id] = g.augment_xp.get(chosen.id, 0) + 25
			if g.augment_xp[chosen.id] >= 100:
				g.augment_xp[chosen.id] -= 100
				g.augment_levels[chosen.id] = g.augment_levels.get(chosen.id, 1) + 1
	for i in range(contracts.size() - 1, -1, -1):
		var contract: Dictionary = contracts[i]
		contract.remaining -= 1
		if contract.remaining > 0:
			continue
		contracts.remove_at(i)
		if contract.id == "C08":
			change_max_hp(g.max_hp / 0.8, false, true)
		rewards[contract.reward] = true
		if contract.reward == "R06":
			change_max_hp(g.max_hp * 1.2, true)
		g._notify("계약 완수: " + REWARD_TEXT[int(contract.reward.right(2)) - 1])

func change_max_hp(amount: float, heal_added: bool = false, ratio: bool = false) -> void:
	var old: float = g.max_hp
	var health: float = g.hp / old
	g.max_hp = amount
	g.hp = minf(amount, amount * health if ratio else g.hp + (maxf(0, amount - old) if heal_added else 0))
	g.hero.hp = g.hp

func accept_contract(index: int) -> void:
	var id = "C%02d" % (index + 1)
	var reward = "R%02d" % (index + 1)
	if contracts.size() >= 2 or penalty(id) or reward_has(reward) or (index == 7 and g.max_hp * 0.8 < 1):
		g._notify("진행할 수 없는 계약입니다.")
		return
	contracts.append({"id": id, "reward": reward, "remaining": 3})
	if id == "C08":
		change_max_hp(g.max_hp * 0.8, false, true)
	g._show_contracts()

func use_power() -> void:
	if equipped.is_empty() or not faith(equipped, 4):
		g._notify("같은 신격 일반 증강 4종으로 권능을 해금하세요.")
		return
	if gauge < 100:
		g._notify("권능 게이지가 부족합니다. %d / 100" % int(gauge))
		return
	gauge = 0
	var point: Vector2 = g._aim_world_point(g.pointer_position)
	var p: float = g.attack_power
	match equipped:
		"N": timers["N_power"] = clock + 6
		"F":
			blast(point, p * 6, "불", 140, "power")
			for target in nearby(point, 140):
				add_status(target, "burn", 8 if has("F06") else 5)
		"I": zone("snow", g.player, 5, 0.5, p * 0.35, "얼음", 160)
		"W":
			for target in nearby(g.player, 260):
				if (target.pos - g.player).normalized().dot(g.facing) >= 0:
					deal(target, p * 5, "물", "power")
					if not target.cc_immune:
						target.knock = g.facing * 600
		"E":
			shield(g.max_hp * 0.3, 6)
			blast(g.player, p * 3, "땅", 160, "power")
		"G": zone("garden", g.player, 6, 1, p * 0.4, "풀", 160)
		"A": zone("wind", g.player, 5, 0.5, p * 0.3, "바람", 150)
		"L": zone("storm", g.player, 4, 0.4, p * 0.7, "번개", 300)
		"Q": delay(point, p * 6.5, "양자", 4, 180)
		"H": zone("court", g.player, 5, 1, p * 0.8, "허수", 160)
	if has("L11"):
		timers["L11"] = clock + 4
	g.sound.play_tone("skill")
	g._emit(g.player, g.GOLD, 36, 220)
	g.shake = 5

func tick(delta: float) -> void:
	var previous_clock = clock
	clock += delta
	if not g.room_clear and g.room_type in ["battle", "elite", "boss"]:
		add_gauge(delta * 2)
	for target in g.enemies:
		target["healing_multiplier"] = maxf(0, 1 - value("I12", 0.5)) if stacks(target, "chill") > 0 else 1.0
		target["death_ability_disabled"] = has("Q10") and stacks(target, "void") > 0 and not target.cc_immune
		var data = statuses(target)
		var cold_until: float = data.get("chill", {}).get("until", 0.0)
		for name in data.keys():
			var status: Dictionary = data[name]
			if name == "spore" and has("D09") and status.until > previous_clock:
				status.until += maxf(0, minf(clock, cold_until) - previous_clock) * 0.5
			if name in ["burn", "spore"]:
				while status.next <= minf(clock, status.until) + 0.00001:
					var bonus = value("F11", 0.4) if name == "burn" and target.hp <= target.max_hp * 0.3 else 0.0
					deal(target, status.power * status.stacks * (0.08 if name == "burn" else 0.06) * (1 + bonus), "불" if name == "burn" else "풀")
					status.next += 1
			if status.until <= clock:
				data.erase(name)
	var due = jobs.filter(func(job): return job.at <= clock)
	jobs = jobs.filter(func(job): return job.at > clock)
	for job in due:
		if job.has("force"):
			if job.target.hp > 0 and not job.target.cc_immune:
				job.target.knock = job.force
				job.target.wall_hit = false
			continue
		if not job.target.is_empty():
			deal(job.target, job.damage, job.element, "augment", job.bonus)
		else:
			blast(job.pos, job.damage, job.element, job.radius, "area", job.bonus)
	var expired = seeds.filter(func(item): return item.at <= clock)
	seeds = seeds.filter(func(item): return item.at > clock)
	for item in expired:
		explode_seed(item)
	for area in zones.duplicate():
		if area.name == "wind":
			area.pos = g.player
		while area.next <= minf(clock, area.until) + 0.00001:
			area.next += area.interval
			var targets = nearby(area.pos, area.radius)
			if area.name == "storm":
				if not targets.is_empty():
					deal(targets[g.rng.randi_range(0, targets.size() - 1)], area.damage, area.element, "power", area.bonus)
			else:
				for target in targets:
					if area.damage > 0:
						deal(target, area.damage, area.element, "power" if area.name in ["snow", "garden", "wind", "court"] else "area", area.bonus)
					if area.name == "snow":
						add_status(target, "chill")
					if area.name == "court":
						add_status(target, "order")
				if area.name == "wind":
					pull(area.pos, 100)
				if area.name == "garden" and g.player.distance_to(area.pos) <= area.radius:
					g._heal(g.max_hp * 0.01)
		if area.until <= clock:
			zones.erase(area)

func preview(item: Dictionary) -> String:
	var slot_name: String = g.Augments.slot(item)
	var previous: String = g.core_slots.get(slot_name, "")
	var next_owned: Dictionary = g.augments.duplicate()
	if not slot_name.is_empty() and previous != item.id:
		next_owned.erase(previous)
	next_owned[item.id] = item.get("rarity", 0)
	var counts: Dictionary = g.Augments.counts(g.augment_data, next_owned)
	var text = "조건부 선택 획득 · 신앙 수에 미포함"
	var count_now: int = g.tag_counts.get(item.element, 0)
	if item.kind == "normal":
		text = "신앙 %d → %d (2 가호 / 4 권능 / 6 신화)" % [count_now, counts.get(item.element, 0)]
	if not slot_name.is_empty() and not previous.is_empty() and previous != item.id:
		var next_active: Dictionary = g.Augments.active(g.augment_data, next_owned)
		var old_item: Dictionary = g.Augments.find(g.augment_data, previous)
		text += "\n교체 제거: %s\n%s" % [old_item.name, g.Augments.description(old_item, g.augments[previous], g.augment_levels.get(previous, 1))]
		for id in g.augments:
			if has(id) and not next_active.get(id, false) and id != previous:
				text += "\n휴면 전환: " + g.Augments.find(g.augment_data, id).name
		for element in g.tag_counts:
			if counts.get(element, 0) < g.tag_counts[element]:
				text += "\n%s 신앙 %d → %d" % [element, g.tag_counts[element], counts.get(element, 0)]
	if not item.get("requirements_text", "").is_empty():
		text += "\n선행: " + item.requirements_text
	if g.augments.has(item.id):
		text += "\n현재: " + g.Augments.description(item, g.augments[item.id], g.augment_levels.get(item.id, 1))
	var combinations: Array = []
	for candidate in g.augment_data:
		if candidate.kind == "normal" or g.augments.has(candidate.id):
			continue
		var before: Dictionary = g.Augments.prerequisite_progress(g.augment_data, g.augments, candidate)
		var after: Dictionary = g.Augments.prerequisite_progress(g.augment_data, next_owned, candidate)
		if after.met > before.met:
			combinations.append({"score": float(after.met) / maxi(1, after.total), "text": "%s 조건 %d/%d (완성 후 보상 후보)" % [candidate.name, after.met, after.total]})
	combinations.sort_custom(func(a, b): return a.score > b.score)
	for i in mini(2, combinations.size()):
		text += "\n" + combinations[i].text
	return text
