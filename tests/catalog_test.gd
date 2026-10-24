extends SceneTree

const Augments = preload("res://scripts/augments.gd")
var failures: int = 0
var checks: int = 0

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)

func ids(items: Array) -> Array:
	return items.map(func(item): return item.id)

func _initialize() -> void:
	var data: Array = Augments.catalog()
	check(data.size() == 152, "152 catalog entries")
	var unique: Dictionary = {}
	var types: Dictionary = {"normal": 0, "legendary": 0, "duo": 0}
	for item in data:
		check(not unique.has(item.id), "unique ID " + item.id)
		unique[item.id] = true
		types[item.kind] += 1
		check(not item.name.is_empty() and not item.description.is_empty(), "authored entry " + item.id)
		check(not item.description.contains("{"), "rendered description " + item.id)
		for group in item.prerequisites:
			for id in group:
				check(not Augments.find(data, id).is_empty(), "valid prerequisite " + id)
	check(types == {"normal": 120, "legendary": 10, "duo": 22}, "catalog composition")
	check(Augments.THRESHOLDS == [1, 2, 4, 6], "faith thresholds")
	check(is_equal_approx(Augments.scale(2, 5), 2.03), "rarity times level")
	check(Augments.scale(3, 5) == 1.0 and Augments.scale(4, 5) == 1.0, "fixed special effects")
	check(Augments.description(Augments.find(data, "F02"), 2, 5).contains("50.75%"), "scaled damage")
	check(Augments.description(Augments.find(data, "F02"), 2, 5).contains("2중첩"), "fixed status stacks")
	check(Augments.description(Augments.find(data, "F06"), 2, 5).contains("+3"), "fixed stack cap")
	check(Augments.description(Augments.find(data, "A06"), 2, 5).contains("+1"), "fixed dash count")
	check(Augments.rarity_at(0) == 0 and Augments.rarity_at(65) == 1 and Augments.rarity_at(90) == 2, "rarity boundaries")
	var partial: Dictionary = Augments.prerequisite_progress(data, {"F01": 0}, Augments.find(data, "D02"))
	check(partial.met == 1 and partial.total == 2 and not partial.complete, "codex partial AND progress")
	var completed: Dictionary = Augments.prerequisite_progress(data, {"F01": 0, "W04": 0}, Augments.find(data, "D02"))
	check(completed.complete and completed.groups[1].met, "codex fulfilled source group")
	var asleep: Dictionary = Augments.prerequisite_progress(data, {"F08": 0}, Augments.find(data, "F05"))
	check(not asleep.complete, "codex dormant prerequisites not fulfilled")
	for i in 10:
		for n in range(1, 5):
			check(Augments.slot(Augments.find(data, Augments.CODES[i] + "%02d" % n)) == Augments.SLOTS[n - 1], "four independent slots")
	var owned: Dictionary = {"F01": 0, "F05": 1, "F06": 0, "F07": 0, "F08": 0, "F-L": 3}
	check(Augments.counts(data, owned)["불"] == 5, "legend excluded from faith")
	check(Augments.active(data, owned)["F-L"], "legend prerequisites AND core")
	var change: Dictionary = Augments.preview(data, owned, Augments.find(data, "I01"))
	check(change.removed == ["F01"], "replace matching slot only")
	check(change.dormant.has("F07") and change.dormant.has("F-L") and change.dormant.has("F08"), "transitive dormancy")
	check(Augments.counts(data, change.owned)["불"] == 4, "dormant normals still faith")
	var restored: Dictionary = Augments.preview(data, change.owned, Augments.find(data, "F01"))
	check(restored.awakened.has("F07") and restored.awakened.has("F-L"), "automatic transitive reactivation")
	var mixed: Dictionary = {"F01": 0, "I02": 0, "W03": 0, "E04": 0}
	var mixed_change: Dictionary = Augments.preview(data, mixed, Augments.find(data, "Q02"))
	check(mixed_change.removed == ["I02"] and mixed_change.owned.has("F01") and mixed_change.owned.has("W03") and mixed_change.owned.has("E04"), "other slots survive replacement")
	var power_change: Dictionary = Augments.preview(data, {"F01": 0, "F05": 0, "F06": 0, "F07": 0}, Augments.find(data, "I01"))
	check(power_change.powers_lost == ["불"], "power loss preview")
	check(not Augments.active(data, {"F08": 0})["F08"], "self source cannot bootstrap")
	check(not Augments.active(data, {"L12": 0})["L12"], "charge spreader cannot bootstrap")
	check(Augments.active(data, {"L09": 0, "L05": 0})["L05"], "independent auxiliary source")
	check(not ids(Augments.eligible(data, {}, [])).has("F05"), "no unmet prerequisites")
	check(ids(Augments.eligible(data, {"F01": 0}, [])).has("F05"), "source group unlock")
	check(ids(Augments.eligible(data, {"A07": 0}, [])).has("A08"), "OR unlock")
	check(ids(Augments.eligible(data, {"F01": 0, "W04": 0}, [])).has("D02"), "duo AND sources")
	check(not ids(Augments.eligible(data, {"F01": 0}, [])).has("D02"), "duo incomplete")
	check(not ids(Augments.eligible(data, {"F06": 0, "F01": 0}, [])).has("F06"), "fixed functionality no levels")
	for fixed_id in ["N07", "I01", "I06", "I07", "A06", "Q10", "H10", "G07", "F-L", "D01"]:
		var fixed_item: Dictionary = Augments.find(data, fixed_id)
		if fixed_id != "I07":
			check(not Augments.can_level(fixed_item), "fixed functionality: " + fixed_id)
	check(not ids(Augments.eligible(data, {"F01": 0}, [], {"F01": 5})).has("F01"), "level cap")
	check(ids(Augments.eligible(data, {"F01": 1}, [], {"F01": 4})).has("F01"), "normal level eligible")
	var registered: Array = ["불", "얼음", "물", "땅"]
	for item in Augments.eligible(data, {}, registered):
		check(item.kind != "normal" or registered.has(item.element), "four deity pool")
	var rng = RandomNumberGenerator.new()
	rng.seed = 53021
	var boosted_rng = RandomNumberGenerator.new()
	boosted_rng.seed = 53021
	var normal_rng = RandomNumberGenerator.new()
	normal_rng.seed = 53021
	var normal_total: int = 0
	var boosted_total: int = 0
	for draw in 1000:
		var normal_rarity: int = Augments.roll_rarity(normal_rng)
		var boosted_rarity: int = Augments.roll_rarity(boosted_rng, true)
		check(boosted_rarity >= normal_rarity and boosted_rarity <= 2, "rarity contract stochastically improves normal tiers")
		normal_total += normal_rarity
		boosted_total += boosted_rarity
	check(boosted_total > normal_total, "rarity contract actually improves rolls")
	var pity: Dictionary = {"reward_element": "불"}
	for iteration in 100:
		var offers: Array = Augments.offer(data, owned, registered, {}, pity, rng)
		check(offers.size() == 3 and ids(offers).size() == 3, "three offers")
		var seen: Dictionary = {}
		for offered in offers:
			check(not seen.has(offered.id), "offer unique")
			seen[offered.id] = true
			check(ids(Augments.eligible(data, owned, registered)).has(offered.id), "offered candidate legal")
			check(offered.has("rarity") and offered.has("level") and offered.has("upgrade"), "offer payload")
			if offered.upgrade:
				check(offered.rarity == owned[offered.id] and offered.level == 2, "upgrade preserves rarity")
	var legend_owned: Dictionary = {"F01": 0, "F06": 0, "F07": 0, "F08": 0}
	pity = {"reward_element": "불", "waiting": {"F-L": {"age": 2, "since": 1}}}
	check(ids(Augments.offer(data, legend_owned, ["불"], {}, pity, rng)).has("F-L"), "third qualifying reward guarantees legend")
	pity = {"reward_element": "물", "waiting": {"D02": {"age": 3, "since": 1}}}
	check(ids(Augments.offer(data, {"F01": 0, "W04": 0}, ["불", "물"], {}, pity, rng)).has("D02"), "fourth combined reward guarantees duo")
	pity = {"reward_element": "불", "deities": {"불": {"misses": 2, "owned": ["F01"], "since": 0}}}
	var fresh_offers: Array = Augments.offer(data, {"F01": 0}, ["불"], {}, pity, rng)
	check(fresh_offers.any(func(item): return item.kind == "normal" and item.element == "불" and not item.upgrade), "new normal guarantee")
	pity = {"reward_element": "불"}
	var first: Array = Augments.offer(data, {}, [], {}, pity, rng)
	check(first.size() == 3, "empty inventory offers")
	pity = {"reward_element": "불", "reward_id": 1}
	Augments.offer(data, legend_owned, ["불"], {}, pity, rng)
	var first_age: int = pity.waiting["F-L"].age
	for reroll in 5:
		Augments.offer(data, legend_owned, ["불"], {}, pity, rng)
		check(pity.sequence == 1 and pity.waiting["F-L"].age == first_age, "stable reward ID prevents reroll pity advancement")
	pity["reward_id"] = 2
	Augments.offer(data, legend_owned, ["불"], {}, pity, rng)
	check(pity.sequence == 2, "new reward ID advances once")
	pity["reward_id"] = 3
	check(ids(Augments.offer(data, legend_owned, ["불"], {}, pity, rng)).has("F-L"), "third distinct reward guarantees legend")
	check(ids(Augments.offer(data, legend_owned, ["불"], {}, pity, rng)).has("F-L"), "guarantee survives reroll")
	pity = {"reward_element": "물"}
	Augments.offer(data, {"F01": 0, "W04": 0}, ["불", "물"], {}, pity, rng)
	var initial_duo_age: int = pity.waiting["D02"].age
	pity["reroll"] = true
	Augments.offer(data, {"F01": 0, "W04": 0}, ["불", "물"], {}, pity, rng)
	check(pity.sequence == 1 and pity.waiting["D02"].age == initial_duo_age and not pity.has("reroll"), "one-shot reroll marker")
	Augments.offer(data, {"F01": 0, "W04": 0}, ["불", "물"], {}, pity, rng)
	check(pity.sequence == 2, "reroll marker consumed")
	pity = {"reward_element": "불", "deities": {"불": {"misses": 2, "owned": ["F01"], "since": 0}}}
	Augments.offer(data, {"F01": 0, "F05": 0}, ["불"], {}, pity, rng)
	check(pity.deities["불"].misses == 0, "new normal acquisition resets pity")
	pity = {"reward_element": "물", "waiting": {"F-L": {"age": 2, "since": 1}}}
	Augments.offer(data, legend_owned, ["불", "물"], {}, pity, rng)
	check(not pity.waiting.has("F-L") or pity.waiting["F-L"].age == 2, "unrelated deity does not advance legend")
	pity = {"reward_element": "불", "waiting": {"D02": {"age": 2, "since": 1}}}
	Augments.offer(data, {"F01": 0, "W04": 0}, ["불", "물"], {}, pity, rng)
	if pity.waiting["D02"].age != 0:
		check(pity.waiting["D02"].age == 3, "first duo deity advances shared age")
		pity["reward_element"] = "물"
		check(ids(Augments.offer(data, {"F01": 0, "W04": 0}, ["불", "물"], {}, pity, rng)).has("D02"), "second duo deity completes shared guarantee")
	var complete: Dictionary = {}
	for item in data:
		if item.kind == "normal":
			complete[item.id] = 0
	var all_active: Dictionary = Augments.active(data, complete)
	for item in data:
		if item.kind != "normal":
			check(ids(Augments.eligible(data, complete)).has(item.id), "every authored combination unlockable: " + item.id)
		else:
			check(all_active[item.id], "every normal grounded: " + item.id)
	pity = {"reward_element": "불", "waiting": {
		"F-L": {"age": 2, "since": 4}, "D01": {"age": 3, "since": 1},
		"D02": {"age": 3, "since": 2}, "D03": {"age": 3, "since": 3},
	}}
	var queued: Array = Augments.offer(data, complete, [], {}, pity, rng)
	check(ids(queued) == ["D01", "D02", "D03"], "oldest three of four guarantees take priority")
	check(ids(Augments.offer(data, complete, [], {}, pity, rng)).has("F-L"), "deferred fourth guarantee survives")
	# Simulate acquisitions rather than only rolling an unchanged inventory.
	var run_owned: Dictionary = {}
	var run_levels: Dictionary = {}
	var run_pool: Array = []
	pity = {}
	for reward in 80:
		var options: Array = Augments.offer(data, run_owned, run_pool, run_levels, pity, rng)
		check(options.size() == 3, "progressive run always has three choices")
		var choice: Dictionary = options[rng.randi_range(0, 2)]
		var next: Dictionary = Augments.preview(data, run_owned, choice, choice.rarity, run_levels)
		run_owned = next.owned
		run_levels = next.levels
		if choice.kind == "normal" and not run_pool.has(choice.element):
			run_pool.append(choice.element)
		check(run_pool.size() <= 4, "progressive run respects deity cap")
		var occupied: Dictionary = {}
		for id in run_owned:
			var acquired_item: Dictionary = Augments.find(data, id)
			var core_slot: String = Augments.slot(acquired_item)
			if not core_slot.is_empty():
				check(not occupied.has(core_slot), "one core per slot")
				occupied[core_slot] = id
			check(run_levels[id] <= acquired_item.max_level, "level bounded")
	for element in Augments.ELEMENTS:
		check(Augments.synergy_text(element).contains("4: 권능"), "faith power text")
	print("CATALOG TEST: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
