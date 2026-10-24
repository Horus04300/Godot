extends RefCounted

const ELEMENTS = ["무속성", "불", "얼음", "물", "땅", "풀", "바람", "번개", "양자", "허수"]
const RARITIES = ["일반", "고급", "희귀", "영웅", "초월", "전설"]
const WEIGHTS = [45, 27, 16, 8, 3, 1]
const POWER = [1.0, 1.2, 1.5, 1.9, 2.4, 3.0]
const COLORS = ["#d7dccb", "#a9dc9d", "#9bceef", "#dab8f2", "#f1b3a0", "#ffe299"]
const THRESHOLDS = [2, 3, 4, 6]
const STATS = ["공격속도", "물리공격", "속성공격", "이동속도", "생존", "기술"]

static func catalog() -> Array:
	var result: Array = []
	var names = ["박동", "칼날", "파동", "걸음", "수호", "각성", "질주", "공명", "잔향", "흐름", "숨결", "의식"]
	for element in ELEMENTS:
		for i in names.size():
			var stat: String = STATS[i % STATS.size()]
			result.append({"id": element + str(i), "name": element + "의 " + names[i],
				"element": element, "tags": [element, stat, STATS[(i + 2) % STATS.size()], STATS[(i + 4) % STATS.size()]],
				"stat": stat, "icon": ["swift", "edge", "fire", "stride", "vital", "focus"][i % 6]})
	var common_names = ["순례자의 맥박", "회랑의 검술", "내면의 불빛", "흐르는 발걸음", "고목의 인내", "새벽의 의식",
		"바람을 가르는 손", "검사의 결의", "깨어난 정신", "길잡이의 보폭", "이슬의 가호", "성소의 호흡"]
	for i in common_names.size():
		result.append({"id": "common" + str(i), "name": common_names[i], "element": "",
			"tags": [STATS[i % 6], STATS[(i + 1) % 6]], "stat": STATS[i % 6],
			"icon": ["swift", "edge", "storm", "stride", "vital", "focus"][i % 6]})
	return result

static func roll_rarity(random: RandomNumberGenerator) -> int:
	return rarity_at(random.randf() * 100.0)

static func rarity_at(value: float) -> int:
	var total = 0.0
	for i in WEIGHTS.size():
		total += WEIGHTS[i]
		if value < total:
			return i
	return 5

static func eligible(data: Array, owned: Dictionary, locked: String) -> Array:
	return data.filter(func(item): return not owned.has(item.id) and (locked.is_empty() or item.element == locked))

static func tier(count: int) -> int:
	var result = 0
	for threshold in THRESHOLDS:
		if count >= threshold:
			result += 1
	return result

static func counts(data: Array, owned: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for item in data:
		if owned.has(item.id):
			for tag in item.tags:
				result[tag] = result.get(tag, 0) + 1
	return result

static func description(item: Dictionary, rarity: int) -> String:
	var power: float = POWER[rarity]
	match item.stat:
		"공격속도": return "기본 공격 속도 +%d%%" % roundi(12 * power)
		"물리공격": return "기본 베기 피해 +%d%%" % roundi(15 * power)
		"속성공격": return "속성 공격 피해 +%d%%" % roundi(15 * power)
		"이동속도": return "이동 속도 +%d%%, 회피 충전 시간 -%d%%" % [roundi(8 * power), roundi(5 * power)]
		"생존": return "최대 체력 +%d, 즉시 같은 양 회복" % roundi(15 * power)
	return "특수 기술 피해 +%d%%, 재사용 -%d%%" % [roundi(16 * power), roundi(6 * power)]

static func synergy_text(tag: String) -> String:
	match tag:
		"공격속도": return "2: 공격속도 +10% / 3: 추가 +10% / 4: 3연격 충격파 / 6: 매 베기 충격파"
		"물리공격": return "2: 기본 피해 +10% / 3: 추가 +10% / 4: 기본 사거리 +20 / 6: 검격 추가타 35%"
		"속성공격": return "2: 속성 피해 +10% / 3: 추가 +10% / 4: 기술 피해 +25% / 6: 기술 2연 폭발"
		"이동속도": return "2: 속도 +8% / 3: 회피 충전 -15% / 4: 회피 길에 피해 / 6: 회피 길 피해 2배"
		"생존": return "2: 피해 -8% / 3: 회복 +20% / 4: 기술 사용 시 보호막 12 / 6: 보호막 24"
		"기술": return "2: 기술 재사용 -10% / 3: 기술 피해 +15% / 4: 기술 범위 +30 / 6: 기술 2연 폭발"
	return "2: 해당 속성 피해 +12% / 3: 추가 +12% / 4: 기술 속성 파동 / 6: 기술을 대범위 원소 폭풍으로 변경"
