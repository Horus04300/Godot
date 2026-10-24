extends RefCounted

const NAMES = ["무속성", "불", "얼음", "물", "땅", "풀", "바람", "번개", "양자", "허수"]
const COLORS = ["#ddd5b6", "#f0aa78", "#bbe8ef", "#9acde4", "#dbbc88", "#afd294", "#abe3c1", "#e2c4ed", "#cfb8ef", "#f0d397"]
const RADIUS = 120.0
var zones: Array = []
var seeds: Array = []
var clock = 0.0
var serial = 0

func reset() -> void:
	zones.clear()
	seeds.clear()
	clock = 0
	serial = 0

func clear_room() -> void:
	zones.clear()
	seeds.clear()

func prepare(unit: Dictionary, element: String, side: int, immune: bool = false) -> void:
	serial += 1
	unit.merge({"uid": serial, "element": element, "side": side, "status": {}, "reaction_cd": {},
		"defense": unit.get("defense", 0.0),
		"shield": 0.0, "shield_until": 0.0, "control_until": 0.0, "knock_until": 0.0,
		"cc_immune": immune, "slow_immune": false}, true)

static func reaction(attack: String, target: String) -> String:
	if attack == "무속성" or target == "무속성" or attack == target:
		return ""
	if attack == "양자" and target == "허수":
		return "붕괴"
	if attack == "허수" and target == "양자":
		return "역설"
	if attack in ["양자", "허수"] or target in ["양자", "허수"]:
		return ""
	var pair = [attack, target]
	if "바람" in pair and "땅" not in pair:
		return "확산·" + (target if attack == "바람" else attack)
	var table = [
		["불", "얼음", "융해"], ["불", "물", "증발"], ["불", "땅", "용암"], ["불", "풀", "연소"], ["불", "번개", "과부하"],
		["얼음", "물", "빙결"], ["얼음", "땅", "동토"], ["얼음", "풀", "동해"], ["얼음", "번개", "초전도"],
		["물", "땅", "진창"], ["물", "풀", "개화"], ["물", "번개", "감전"],
		["땅", "풀", "생장"], ["땅", "바람", "모래폭풍"], ["땅", "번개", "접지"], ["풀", "번개", "활성"]]
	for row in table:
		if attack in [row[0], row[1]] and target in [row[0], row[1]]:
			return row[2]
	return ""

func active(unit: Dictionary, status: String) -> bool:
	return unit.status.has(status) and unit.status[status].until > clock

func movement(unit: Dictionary) -> float:
	if active(unit, "빙결") or active(unit, "생장"):
		return 0.0
	if unit.slow_immune:
		return 1.0
	if active(unit, "동토"):
		return 0.8 if unit.cc_immune else 0.6
	if active(unit, "진창"):
		return 0.8 if unit.cc_immune else 0.7
	if active(unit, "제어저항"):
		return 0.8
	return 1.0

func action_speed(unit: Dictionary) -> float:
	if active(unit, "빙결"):
		return 0
	return 0.8 if active(unit, "동해") else 1.0

func heal_factor(unit: Dictionary) -> float:
	return 0.7 if active(unit, "동해") else 1.0

func status(unit: Dictionary, name: String, duration: float) -> void:
	unit.status[name] = {"until": clock + duration}

func control(unit: Dictionary, name: String, duration: float) -> void:
	if unit.cc_immune or clock < unit.control_until:
		if not unit.slow_immune:
			status(unit, "제어저항", 2)
		return
	status(unit, name, duration)
	unit.control_until = clock + duration + 3

func knock(unit: Dictionary, direction: Vector2, force: float) -> void:
	if unit.get("augment_knock_immune", false):
		return
	if unit.cc_immune or clock < unit.knock_until:
		if not unit.slow_immune:
			status(unit, "제어저항", 2)
		return
	unit.knock = direction.normalized() * force
	unit.knock_until = clock + 3

func grant_shield(unit: Dictionary, amount: float, duration: float) -> void:
	if unit.shield_until <= clock:
		unit.shield = 0.0
	unit.shield = minf(unit.get("max_hp", INF) * 0.5, maxf(unit.shield, amount))
	unit.shield_until = clock + duration

func absorb(unit: Dictionary, damage: float) -> float:
	if unit.shield_until <= clock:
		unit.shield = 0.0
	var blocked = minf(unit.shield, damage)
	unit.shield -= blocked
	return damage - blocked

func hit(attacker: Dictionary, target: Dictionary, damage: float, element: String, units: Array) -> Array:
	var events: Array = []
	if active(target, "활성") and element in ["풀", "번개"]:
		damage *= 1.2
	var defense: float = target.defense * (0.8 if active(target, "초전도") else 1.0)
	damage *= 100.0 / (100.0 + maxf(0, defense))
	var name = reaction(element, target.element)
	var amplified = name in ["융해", "증발", "붕괴", "역설"]
	events.append({"target": target, "damage": damage * (1.5 if amplified else 1.0), "element": element, "reaction": name if amplified else ""})
	if name.is_empty() or amplified:
		return events
	var key = "%d:%s" % [attacker.uid, name]
	if target.reaction_cd.get(key, -1.0) > clock:
		return events
	target.reaction_cd[key] = clock + 1
	events[0].reaction = name
	match name:
		"연소", "감전":
			target.status[name + str(attacker.uid)] = {"until": clock + (4 if name == "연소" else 3),
				"next": clock + 1, "damage": damage * 0.15, "name": name, "source": _source(attacker)}
		"빙결": control(target, name, 2)
		"생장": control(target, name, 1.5)
		"동토", "동해", "진창": status(target, name, 4)
		"초전도":
			events.append(_event(target, damage * 0.2, "무속성"))
			status(target, name, 5)
		"활성": status(target, name, 5)
		"접지":
			events.append(_event(target, damage * 0.25, "땅"))
			grant_shield(attacker, damage * 0.3, 3)
		"용암", "모래폭풍":
			zones = zones.filter(func(zone): return zone.source.uid != attacker.uid or zone.name != name)
			zones.append({"source": _source(attacker), "name": name, "pos": target.pos, "until": clock + 3,
				"next": clock + 1, "damage": damage * (0.15 if name == "용암" else 0.1)})
		"개화":
			var owned = seeds.filter(func(seed_item): return seed_item.source.uid == attacker.uid)
			if owned.size() >= 3:
				_blast(events, owned[0].pos, owned[0].source, owned[0].damage, "풀", units)
				seeds.erase(owned[0])
			seeds.append({"source": _source(attacker), "pos": target.pos, "until": clock + 2, "damage": damage * 0.5})
		"과부하":
			_blast(events, target.pos, attacker, damage * 0.4, "불", units)
			for unit in units:
				if unit.side != attacker.side and unit.hp > 0 and unit.pos.distance_to(target.pos) <= RADIUS:
					knock(unit, unit.pos - attacker.pos, 260)
		_:
			if name.begins_with("확산"):
				for unit in units:
					if unit.uid != target.uid and unit.side != attacker.side and unit.hp > 0 and unit.pos.distance_to(target.pos) <= RADIUS:
						events.append(_event(unit, damage * 0.3, name.trim_prefix("확산·")))
	return events

func _event(target: Dictionary, damage: float, element: String) -> Dictionary:
	return {"target": target, "damage": damage, "element": element, "reaction": ""}

func _source(unit: Dictionary) -> Dictionary:
	return {"uid": unit.uid, "side": unit.side}

func _blast(events: Array, pos: Vector2, source: Dictionary, damage: float, element: String, units: Array) -> void:
	for unit in units:
		if unit.side != source.side and unit.hp > 0 and unit.pos.distance_to(pos) <= RADIUS:
			events.append(_event(unit, damage, element))

func tick(delta: float, units: Array) -> Array:
	clock += delta
	var events: Array = []
	for unit in units:
		if unit.hp <= 0:
			continue
		for key in unit.status.keys():
			var effect: Dictionary = unit.status[key]
			if effect.has("next"):
				while effect.next <= clock + 0.00001 and effect.next <= effect.until + 0.00001:
					events.append(_event(unit, effect.damage, "불" if effect.name == "연소" else "번개"))
					if effect.name == "감전":
						var nearby = units.filter(func(other): return other.uid != unit.uid and other.side == unit.side and other.hp > 0 and other.pos.distance_to(unit.pos) <= RADIUS)
						nearby.sort_custom(func(a, b): return a.pos.distance_squared_to(unit.pos) < b.pos.distance_squared_to(unit.pos))
						for i in mini(2, nearby.size()):
							events.append(_event(nearby[i], effect.damage, "번개"))
					effect.next += 1
			if effect.until <= clock:
				unit.status.erase(key)
	for zone in zones:
		if zone.name == "모래폭풍" and zone.until >= clock:
			for unit in units:
				if unit.side != zone.source.side and unit.pos.distance_to(zone.pos) <= RADIUS:
					status(unit, "모래", delta + 0.05)
		while zone.next <= clock + 0.00001 and zone.next <= zone.until + 0.00001:
			_blast(events, zone.pos, zone.source, zone.damage, "불" if zone.name == "용암" else "땅", units)
			zone.next += 1
	zones = zones.filter(func(zone): return zone.until > clock)
	for seed_item in seeds:
		if seed_item.until <= clock:
			_blast(events, seed_item.pos, seed_item.source, seed_item.damage, "풀", units)
	seeds = seeds.filter(func(seed_item): return seed_item.until > clock)
	return events
