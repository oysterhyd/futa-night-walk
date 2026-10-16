class_name RunWorld
extends RefCounted

const BOUNDS = Rect2(120, 185, 1360, 590)
const MOB_STATS = {"paper_spirit": [19, 87, 9, 14, 5], "lantern_wisp": [32, 70, 12, 17, 8], "mist_fox": [34, 106, 11, 16, 8], "stone_guard": [85, 53, 17, 24, 13], "archer": [37, 67, 10, 16, 9]}
const SNAPSHOT_KEYS = ["run_id", "character", "mode", "difficulty", "contract", "camp", "weapons", "passives", "evolved", "relics", "timers", "stage", "time", "sector_time", "phase", "level", "xp", "xp_next", "pending_levels", "choices", "routes", "rerolls", "coins", "charge", "kills", "bosses", "shrines", "sector_damage", "total_damage_taken", "nohit", "resurrected", "damage_bonus", "next_curse", "sector_curse", "spawn_timer", "elite_spawned", "boss_spawned", "shrine", "shrine_index", "uid", "damage_by_skill", "victory", "player", "mobs", "bolts", "zones", "drops", "obstacles", "hazards", "reactions", "combo", "combo_time"]

var rng = RandomNumberGenerator.new()
var run_id = ""
var character = "keeper"
var mode = "campaign"
var difficulty = 0
var contract = "none"
var camp: Dictionary = {}
var weapons: Dictionary = {}
var passives: Dictionary = {}
var evolved: Array = []
var relics: Array = []
var timers: Dictionary = {}
var stage = 1
var time = 0.0
var sector_time = 0.0
var phase = "active"
var level = 1
var xp = 0.0
var xp_next = 30.0
var pending_levels = 0
var choices: Array = []
var routes: Array = []
var rerolls = 2
var coins = 0
var charge = 10.0
var kills = 0
var bosses = 0
var shrines = 0
var sector_damage = 0.0
var total_damage_taken = 0.0
var nohit = false
var resurrected = false
var damage_bonus = 0.0
var next_curse = false
var sector_curse = false
var spawn_timer = 1.3
var elite_spawned = false
var boss_spawned = false
var shrine: Dictionary = {}
var shrine_index = 0
var uid = 0
var damage_by_skill: Dictionary = {}
var victory = false
var player: Dictionary = {}
var mobs: Array = []
var bolts: Array = []
var zones: Array = []
var drops: Array = []
var obstacles: Array = []
var hazards: Array = []
var events: Array = []
var cells: Dictionary = {}
var reactions: Dictionary = {}
var combo = 0
var combo_time = 0.0
var oath = "none"
var pending_relics = 0
var relic_return_phase = "active"
var pending_replacement = ""
var step_stats: Dictionary = {}
var inside_step = false

func begin(options: Dictionary = {}) -> void:
	character = options.get("character", "keeper")
	mode = options.get("mode", "campaign")
	difficulty = int(options.get("difficulty", 0))
	contract = options.get("contract", "none")
	if mode=="daily":
		character = "keeper"
		difficulty = 0
		contract = "none"
	if options.has("seed"): rng.seed = int(options.seed)
	else: rng.randomize()
	run_id = "%s-%s" % [Time.get_ticks_usec(), rng.randi()]
	camp = options.get("camp", {}).duplicate(true) if mode != "daily" else {}
	var char_def = Content.data.characters[character]
	var hp = float(char_def.hp) + camp.get("vigor", 0) * 6
	if contract == "fragile":
		hp *= 0.7
	player = {"x": 800.0, "y": 480.0, "hp": hp, "max_hp": hp, "radius": 15.0, "facing": 1.0, "invulnerable": 1.5, "dash_time": 0.0, "dash_cd": 0.0, "dash_dx": 0.0, "dash_dy": 1.0, "moving": false, "fox_ready": false, "cast": 0.0}
	weapons = {char_def.skill: 1}
	rerolls += int(camp.get("fortune", 0))
	start_sector()
	if options.get("choose_oath",false):
		phase = "oath"
		choices = Content.data.oaths.keys().map(func(key): return "o:"+key)

func choose_oath(index: int) -> bool:
	if phase != "oath" or index<0 or index>=choices.size(): return false
	oath = choices[index].substr(2)
	if oath == "cinder":
		player.max_hp *= 0.9
		player.hp = minf(player.hp,player.max_hp)
	choices.clear()
	phase = "active"
	emit("notice",{"text":Content.data.oaths[oath].name+" · 誓愿已立"})
	return true

func open_relic_draft(return_phase: String = "active") -> void:
	var pool = Content.data.relics.keys().filter(func(key): return key not in relics)
	if pool.is_empty():
		coins += 30
		pending_relics = maxi(0,pending_relics-1)
		return
	relic_return_phase = return_phase
	phase = "relic"
	choices.clear()
	while not pool.is_empty() and choices.size()<3:
		var index = rng.randi_range(0,pool.size()-1)
		choices.append("r:"+pool[index])
		pool.remove_at(index)

func choose_relic(index: int) -> bool:
	if phase not in ["relic","relic_replace"]: return false
	if phase == "relic_replace" and index == -1:
		coins += 30
	elif index<0 or index>=choices.size(): return false
	elif phase == "relic":
		var key = choices[index].substr(2)
		if relics.size()>=4:
			pending_replacement = key
			phase = "relic_replace"
			choices = relics.map(func(old): return "d:"+old)
			return true
		relics.append(key)
		emit("notice",{"text":"获得遗物："+Content.data.relics[key].name})
	else:
		relics.erase(choices[index].substr(2))
		relics.append(pending_replacement)
		emit("notice",{"text":"替换遗物："+Content.data.relics[pending_replacement].name})
	pending_replacement = ""
	pending_relics = maxi(0,pending_relics-1)
	choices.clear()
	phase = relic_return_phase
	if pending_relics>0: open_relic_draft(phase)
	elif phase=="active" and pending_levels>0: roll_choices()
	return true

func biome() -> Dictionary:
	return Content.data.biomes[(stage - 1) % 4]

func pos(entity: Dictionary) -> Vector2:
	return Vector2(entity.x, entity.y)

func set_pos(entity: Dictionary, value: Vector2) -> void:
	entity.x = value.x
	entity.y = value.y

func emit(kind: String, values: Dictionary = {}) -> void:
	if events.size() < 512:
		var event = values.duplicate()
		event.kind = kind
		events.append(event)

func stat(key: String) -> float:
	var totals = step_stats if inside_step else calculate_stats()
	var value = float(totals[key])
	if key=="damage" and "red_thread" in relics and player.hp<player.max_hp*0.5: value *= 1.35
	return value

func calculate_stats() -> Dictionary:
	var totals = {"damage": 1.0 + damage_bonus + camp.get("focus", 0) * 0.04, "haste": 0.0, "speed": 1.0 + camp.get("stride", 0) * 0.03, "crit": 0.05, "magnet": 1.0, "armor": 0.0, "burn": 1.0, "xp": 1.0, "regen": 0.0, "dash": 0.0, "pulse": 1.0}
	for key_id in passives:
		var item = Content.data.passives[key_id]
		if totals.has(item.stat): totals[item.stat] += item.value * passives[key_id]
	totals.damage *= Content.data.characters[character].damage
	if contract == "fragile": totals.damage *= 1.25
	if character == "keeper": totals.magnet *= 1.35
	if character == "alchemist": totals.burn *= 1.6
	if character == "swordswoman": totals.dash += 0.25
	if oath == "tide": totals.dash += 0.2
	if "crow_feather" in relics: totals.crit += 0.12
	if "silver" in relics: totals.haste += 0.12
	if "map" in relics:
		totals.magnet += 0.5
		totals.speed += 0.08
	return totals

func heal(amount: float) -> void:
	if contract != "silence" and player.hp > 0:
		player.hp = minf(player.max_hp, player.hp + amount)

func dash(move: Vector2) -> bool:
	if phase != "active" or player.dash_cd > 0 or player.hp <= 0: return false
	if move.length_squared() < 0.01: move = Vector2(player.facing, 0)
	move = move.normalized()
	player.dash_dx = move.x
	player.dash_dy = move.y
	player.dash_time = 0.18
	player.dash_cd = 2.4 * maxf(0.35, 1.0 - stat("dash"))
	player.invulnerable = maxf(player.invulnerable, 0.32)
	player.fox_ready = "fox_tooth" in relics
	emit("dash", {"x": player.x, "y": player.y})
	return true

func pulse() -> bool:
	if phase != "active" or charge < 30 or player.hp <= 0: return false
	charge = 0
	var radius = 310.0 if "drum" in relics else 260.0
	var damage = 65*stat("damage")*stat("pulse")
	for mob in mobs:
		if mob.hp > 0 and pos(mob).distance_to(pos(player)) < radius + mob.radius:
			hit(mob, damage, "pulse", 95)
			mob.stun = 0.15 if mob.boss else 0.7
	bolts = bolts.filter(func(b): return not b.hostile or ("drum" not in relics and pos(b).distance_to(pos(player)) > radius))
	player.invulnerable = maxf(player.invulnerable, 0.35)
	if character == "keeper": heal(8)
	emit("pulse", {"x": player.x, "y": player.y, "radius": radius})
	return true

func hurt(amount: float) -> void:
	if phase != "active" or player.invulnerable > 0 or player.hp <= 0: return
	amount = maxf(1, amount - stat("armor"))
	player.hp -= amount
	player.invulnerable = 0.72
	sector_damage += amount
	total_damage_taken += amount
	emit("hurt", {"x": player.x, "y": player.y, "amount": int(amount)})
	if "wine" in relics: charge = minf(30, charge + 5)
	if player.hp <= 0 and "old_wick" in relics and not resurrected:
		player.hp = 1
		player.invulnerable = 3
		resurrected = true
		emit("notice", {"text": "不灭芯生效 · 保留一命！"})
	if player.hp <= 0: finish(false)

func effective(key: String) -> Dictionary:
	var skill = Content.skills[key].duplicate(true)
	var lv = int(weapons.get(key, 1))
	for n in range(2, mini(lv, 3) + 1):
		var scaling = skill.get("level_scaling", {}).get(str(n), {})
		for field in scaling: skill[field] = scaling[field]
	var multiplier = [1.0, 1.1, 1.22, 1.45, 1.75][lv - 1]
	skill.damage = roundf(skill.damage * multiplier)
	skill.cooldown *= 1.0 - 0.06 * (lv - 1)
	skill.burn_damage = skill.get("burn_damage", 0.0) * multiplier
	return skill

func available_choices() -> Array:
	var pool: Array = []
	for key in Content.skills:
		if weapons.get(key, 0) < 5 and (weapons.has(key) or weapons.size() < 4): pool.append("w:" + key)
	for key in Content.data.passives:
		if passives.get(key, 0) < 3 and (passives.has(key) or passives.size() < 6): pool.append("p:" + key)
	for key in Content.data.evolutions:
		if weapons.get(key, 0) >= 5 and passives.has(Content.data.evolutions[key].passive) and key not in evolved: pool.append("e:" + key)
	return pool

func roll_choices() -> void:
	var pool = available_choices()
	choices = []
	var evolutions = pool.filter(func(k): return k.begins_with("e:"))
	if not evolutions.is_empty():
		var key = evolutions[rng.randi_range(0, evolutions.size() - 1)]
		choices.append(key)
		pool.erase(key)
	while not pool.is_empty() and choices.size() < 3:
		var weighted: Array = []
		for key in pool:
			weighted.append(key)
			if key.begins_with("w:") and weapons.has(key.substr(2)):
				weighted.append(key)
				weighted.append(key)
		var key = weighted[rng.randi_range(0, weighted.size() - 1)]
		choices.append(key)
		pool.erase(key)
	if choices.is_empty(): choices = ["gift:heal", "gift:coin"]
	phase = "upgrade"

func reroll() -> bool:
	if phase != "upgrade" or rerolls <= 0: return false
	rerolls -= 1
	roll_choices()
	return true

func choose(index: int) -> bool:
	if phase != "upgrade" or index < 0 or index >= choices.size(): return false
	var parts = choices[index].split(":")
	var key = parts[1]
	match parts[0]:
		"w": weapons[key] = int(weapons.get(key, 0)) + 1
		"p":
			passives[key] = int(passives.get(key, 0)) + 1
			if key == "jade":
				player.max_hp += 18
				heal(18)
		"e":
			evolved.append(key)
			emit("notice", {"text": Content.data.evolutions[key].name + " · 符术进阶！"})
		"gift":
			if key == "heal": heal(25)
			else: coins += 30
	pending_levels = maxi(0, pending_levels - 1)
	choices = []
	phase = "active"
	emit("upgrade", {"x": player.x, "y": player.y})
	if pending_levels > 0: roll_choices()
	return true

func gain_xp(value: float) -> void:
	xp += value * stat("xp")
	while xp >= xp_next:
		xp -= xp_next
		level += 1
		xp_next = 30 + (level - 1) * 13
		pending_levels += 1
		if "bamboo" in relics: heal(4)

func add_relic() -> String:
	if relics.size()>=4:
		pending_relics += 1
		open_relic_draft()
		return ""
	var pool = Content.data.relics.keys().filter(func(k): return k not in relics)
	if pool.is_empty():
		coins += 30
		return ""
	var key = pool[rng.randi_range(0, pool.size() - 1)]
	relics.append(key)
	emit("notice", {"text": "获得遗物：" + Content.data.relics[key].name})
	return key

func route_available(key: String) -> bool:
	return key != "market" or coins >= 35

func take_route(key: String) -> bool:
	if phase != "route" or key not in routes or not route_available(key): return false
	match key:
		"tea":
			heal(player.max_hp * 0.4)
			coins += 10
		"relic": pending_relics += 1
		"market":
			coins -= 35
			pending_levels += 2
		"curse":
			player.hp = maxf(1, player.hp * 0.8)
			damage_bonus += 0.2
			coins += 35
		"study":
			pending_levels += 1
			next_curse = true
		"spring":
			player.max_hp += 12
			heal(20)
	stage += 1
	start_sector()
	if pending_relics>0: open_relic_draft("active")
	elif pending_levels > 0: roll_choices()
	return true

func start_sector() -> void:
	sector_time = 0
	mobs.clear()
	bolts.clear()
	zones.clear()
	drops.clear()
	player.x = 800.0
	player.y = 500.0
	player.invulnerable = 1.5
	player.dash_cd = 0
	sector_damage = 0
	resurrected = false
	boss_spawned = false
	elite_spawned = false
	shrine = {}
	shrine_index = 0
	spawn_timer = 1.3
	sector_curse = next_curse
	next_curse = false
	phase = "active"
	routes = []
	obstacles = [{"x": 390.0, "y": 330.0, "radius": 34.0}, {"x": 1210.0, "y": 660.0, "radius": 34.0}]
	hazards = []
	if (stage - 1) % 4 == 1:
		hazards = [{"x": 400.0, "y": 265.0, "radius": 85.0, "kind": "water"}, {"x": 1200.0, "y": 625.0, "radius": 85.0, "kind": "water"}]
	if character == "alchemist": heal(15)
	emit("sector", {"text": biome().name})

func move_entity(entity: Dictionary, delta: Vector2) -> void:
	var p = pos(entity) + delta
	var radius = float(entity.radius)
	p.x = clampf(p.x, BOUNDS.position.x + radius, BOUNDS.end.x - radius)
	p.y = clampf(p.y, BOUNDS.position.y + radius, BOUNDS.end.y - radius)
	for obstacle in obstacles:
		var away = p - pos(obstacle)
		var distance = away.length()
		if distance < radius + obstacle.radius:
			p = pos(obstacle) + (away.normalized() if distance > 0 else Vector2.RIGHT) * (radius + obstacle.radius)
	set_pos(entity, p)

func spawn(kind: String, elite: bool = false, boss: bool = false) -> Dictionary:
	if mobs.size()>=180 and not boss: return {}
	var side = rng.randi_range(0, 3)
	var p = Vector2(rng.randf_range(BOUNDS.position.x, BOUNDS.end.x), rng.randf_range(BOUNDS.position.y, BOUNDS.end.y))
	match side:
		0: p.x = BOUNDS.position.x
		1: p.x = BOUNDS.end.x
		2: p.y = BOUNDS.position.y
		3: p.y = BOUNDS.end.y
	if p.distance_to(pos(player)) < 220:
		p = Vector2(1400 if player.x < 800 else 200, 700 if player.y < 480 else 240)
	var stats = MOB_STATS.get(kind, MOB_STATS.paper_spirit)
	var hp = float(stats[0]) * (1 + 0.38 * (stage - 1)) * (1 + 0.22 * difficulty) * (1.15 if sector_curse else 1.0)
	var speed = float(stats[1]) * minf(1.55, 1.0 + 0.04 * (stage - 1 + difficulty))
	var damage = float(stats[2]) * (1 + 0.1 * (stage - 1 + difficulty))
	var radius = float(stats[3])
	var experience = int(stats[4])
	if boss:
		hp = (1000 + ((stage - 1) % 4) * 480) * (1 + 0.5 * int((stage - 1) / 4)) * (1 + 0.25 * difficulty)
		speed = 57
		damage = 19 + 3 * stage
		radius = 43
		experience = 150
		p = Vector2(800, 260)
		if p.distance_to(pos(player)) < 220: p.x = 1300 if player.x < 800 else 300
	if elite:
		hp *= 3.4
		damage *= 1.3
		radius *= 1.3
		experience *= 3
	uid += 1
	var mob = {"uid": uid, "kind": kind, "x": p.x, "y": p.y, "hp": hp, "max_hp": hp, "speed": speed, "damage": damage, "radius": radius, "elite": elite, "boss": boss, "cooldown": rng.randf_range(1.5, 3.5), "windup": 0.0, "charging": 0.0, "dx": 0.0, "dy": 1.0, "slow": 0.0, "stun": 0.0, "burn": 0.0, "burn_dps": 0.0, "burn_source": "fire_talisman", "poison": 0.0, "poison_dps": 0.0, "wet": 0.0, "reaction_cd": 0.0, "flash": 0.0, "facing": -1.0, "attack": 0, "xp": experience, "enraged": false, "spawn_age": 0.0}
	mobs.append(mob)
	emit("spawn", {"x": p.x, "y": p.y, "boss": boss})
	if boss: emit("boss", {"text": biome().boss})
	return mob

func rebuild_index() -> void:
	cells.clear()
	for mob in mobs:
		if mob.hp <= 0: continue
		var key = Vector2i(floori(mob.x / 100), floori(mob.y / 100))
		if not cells.has(key): cells[key] = []
		cells[key].append(mob)

func near(p: Vector2, radius: float) -> Array:
	var found: Array = []
	var broad_radius = radius + 64.0
	for x in range(floori((p.x - broad_radius) / 100), floori((p.x + broad_radius) / 100) + 1):
		for y in range(floori((p.y - broad_radius) / 100), floori((p.y + broad_radius) / 100) + 1):
			for mob in cells.get(Vector2i(x, y), []):
				if mob.hp > 0 and pos(mob).distance_squared_to(p) <= pow(radius + mob.radius, 2): found.append(mob)
	return found

func nearest(p: Vector2) -> Dictionary:
	var result: Dictionary = {}
	var best = INF
	for mob in mobs:
		if mob.hp <= 0: continue
		var distance = pos(mob).distance_squared_to(p)
		if distance < best:
			best = distance
			result = mob
	return result

func hit(mob: Dictionary, amount: float, source: String, knockback: float = 0, critical: bool = false) -> void:
	if mob.hp <= 0: return
	amount = maxf(0, amount)
	damage_by_skill[source] = damage_by_skill.get(source, 0.0) + minf(amount, mob.hp)
	mob.hp -= amount
	mob.flash = 0.12
	if knockback > 0: move_entity(mob, (pos(mob) - pos(player)).normalized() * knockback * (0.2 if mob.boss else 1.0))
	emit("hit", {"x": mob.x, "y": mob.y, "amount": int(amount), "source": source, "critical": critical})
	if mob.hp > 0: return
	kills += 1
	combo += 1
	combo_time = 2.6
	if oath == "script" and kills%60 == 0:
		rerolls += 1
		emit("notice",{"text":"百符誓生效 · 刷新次数 +1"})
	charge = minf(30, charge + 1.0/maxf(0.4,1.0-passives.get("ink",0)*0.1))
	drops.append({"x": mob.x, "y": mob.y, "value": mob.xp, "kind": "xp", "age": 0.0})
	if rng.randf() < 0.17 or mob.elite: drops.append({"x": mob.x + 12, "y": mob.y, "value": 8 if mob.elite else 1, "kind": "coin", "age": 0.0})
	if rng.randf() < 0.025: drops.append({"x": mob.x, "y": mob.y + 10, "value": 9, "kind": "heal", "age": 0.0})
	emit("death", {"x": mob.x, "y": mob.y, "source": source, "boss": mob.boss})
	if "prayer" in relics and kills % 30 == 0: heal(5)
	if mob.elite: pending_relics += 1
	if mob.boss:
		bosses += 1
		coins += 30
		nohit = nohit or sector_damage == 0
		heal(15)
		for drop in drops:
			if drop.kind == "xp": gain_xp(drop.value)
			elif drop.kind == "coin": coins += int(drop.value)
			elif drop.kind == "heal": heal(drop.value)
		drops.clear()
		if mode != "endless" and stage >= 4:
			finish(true)
		else:
			phase = "route"
			var pool = Content.data.routes.duplicate()
			routes = []
			while routes.size() < 3:
				var index = rng.randi_range(0, pool.size() - 1)
				routes.append(pool[index].id)
				pool.remove_at(index)
			emit("boss_clear", {"text": "首领击破 · 前方出现岔路"})
			pending_relics += 1
			open_relic_draft("route")

func apply_element(mob: Dictionary, source: String, amount: float) -> void:
	if mob.hp <= 0: return
	var element = Content.element(source)
	var reaction = ""
	if mob.reaction_cd <= 0:
		if element == "fire" and mob.poison > 0: reaction = "燃瘴"
		elif element == "poison" and mob.burn > 0: reaction = "燃瘴"
		elif element == "thunder" and (mob.wet > 0 or mob.slow > 0): reaction = "引雷"
		elif (element == "fire" and mob.slow > 0) or (element == "frost" and mob.burn > 0): reaction = "融霜"
	if not reaction.is_empty():
		mob.reaction_cd = 1.5
		reactions[reaction] = int(reactions.get(reaction, 0)) + 1
		var multiplier = 0.65 if reaction == "引雷" else 1.2
		hit(mob, amount * multiplier, "reaction:" + reaction)
		if reaction in ["燃瘴", "引雷"]:
			for other in near(pos(mob), 110):
				if other.uid != mob.uid: hit(other, amount * 0.5, "reaction:" + reaction)
		emit("reaction", {"x": mob.x, "y": mob.y, "text": reaction, "source": source, "radius": 110})
		mob.burn *= 0.5
		mob.poison *= 0.5
		mob.slow *= 0.5
		if reaction=="燃瘴" and oath=="cinder":
			heal(2)
			charge = minf(30,charge+3)
	match element:
		"fire":
			mob.burn = maxf(mob.burn, 1.8)
			mob.burn_dps = maxf(mob.burn_dps, maxf(4, amount * 0.22) * stat("burn"))
			mob.burn_source = source
		"frost": mob.slow = maxf(mob.slow, 3.0 if oath=="tide" else 2.0)
		"poison":
			mob.poison = maxf(mob.poison, 2.5)
			mob.poison_dps = maxf(mob.poison_dps, (3.0 + 1.8 * weapons.get(source, 1)) * stat("burn") * stat("damage"))
		"thunder": mob.stun = maxf(mob.stun, 0.08 if mob.boss else 0.2)

func make_bolt(p: Vector2, velocity: Vector2, damage: float, source: String, hostile: bool = false, pierce: int = 0, homing: float = 0, skin: String = "seal") -> void:
	if bolts.size() >= 700: return
	uid += 1
	bolts.append({"uid": uid, "x": p.x, "y": p.y, "vx": velocity.x, "vy": velocity.y, "damage": damage, "source": source, "hostile": hostile, "pierce": pierce, "homing": homing, "skin":skin, "radius": 7.0 if hostile else 6.0, "life": 5.0 if hostile else 3.2, "hits": []})

func make_zone(p: Vector2, radius: float, damage: float, source: String, life: float = 2.1, warning: float = 0, hostile: bool = false, once: bool = false) -> void:
	zones.append({"x": p.x, "y": p.y, "radius": radius, "damage": damage, "source": source, "life": life, "warning": warning, "warning_max": warning, "hostile": hostile, "once": once, "tick": 0.0})

func cast(key: String) -> void:
	var skill = effective(key)
	var lv = int(weapons[key])
	var evo = key in evolved
	var critical = rng.randf() < minf(0.65, stat("crit"))
	var damage = float(skill.damage) * stat("damage") * (2 if critical else 1) * (1.35 if evo else 1.0)
	if oath=="cinder" and Content.element(key)=="fire": damage *= 1.25
	if oath=="tide" and Content.element(key) not in ["frost","thunder"]: damage *= 0.92
	if player.fox_ready:
		damage *= 2
		player.fox_ready = false
	var p = pos(player)
	var target = nearest(p)
	player.cast = 0.16
	match key:
		"healing_mark":
			heal(3 + lv * 1.5)
			for mob in near(p, 95): hit(mob, damage, key, 35)
			emit("heal", {"x": p.x, "y": p.y})
		"ward_shard", "shadow_twin":
			var radius = (80 if key == "ward_shard" else 120) + lv * 3
			var count = 6 if evo else maxi(2, int(skill.get("orbit_count", 2)) + int(lv >= 4))
			for i in range(count):
				var angle = time * (2.3 if key == "ward_shard" else -1.6) + TAU * i / count
				var orb = p + Vector2.from_angle(angle) * radius
				for mob in near(orb, 15): hit(mob, damage * 0.55, key, 16 if evo else 0)
		"poison_mist", "binding_hex", "starfall":
			if target.is_empty() and key != "binding_hex": return
			var location = p if key == "binding_hex" else pos(target)
			var radius = (86 + lv * 7) if key == "binding_hex" else (66 + lv * 7) * (1.4 if evo else 1.0)
			make_zone(location, radius, damage * (1.8 if key == "starfall" else 0.45), key, 0.5 if key == "starfall" else (4.0 if evo else 2.1), 0.65 if key == "starfall" else 0.0, false, key == "starfall")
			emit("cast", {"x": location.x, "y": location.y, "source": key})
		"shock_ring", "frost_ring", "soul_banner":
			var radius = 135 + lv * 10
			for mob in near(p, radius):
				hit(mob, damage, key, 25)
				apply_element(mob, key, damage)
			emit("ring", {"x": p.x, "y": p.y, "radius": radius, "source": key})
			if key == "soul_banner":
				for i in range(8): make_bolt(p, Vector2.from_angle(TAU * i / 8 + time) * 310, damage * 0.6, key)
		_:
			if target.is_empty(): return
			var angle = (pos(target) - p).angle()
			var count = maxi(1, int(skill.get("shots", 1)))
			if key == "fire_talisman" and evo: count = 3
			if key == "piercing_spike": count = 5 if evo else (3 if lv >= 5 else count)
			if key == "frost_sand" and evo: count = 12
			if oath=="script":
				count += 1
				damage *= 0.8
			var speed = maxf(220, skill.projectile_speed)
			for i in range(count):
				var offset = (i - (count - 1) / 2.0) * deg_to_rad(skill.get("spread_angle", 18.0))
				if key == "frost_sand" and evo: offset = TAU * i / count
				make_bolt(p, Vector2.from_angle(angle + offset) * speed, damage, key, false, 12 if key == "piercing_spike" else 0, 1.6 if skill.get("homing_strength", 0.0) > 0 else 0.0)
			emit("cast", {"x": p.x, "y": p.y, "source": key})

func bolt_hit(bolt: Dictionary, mob: Dictionary) -> void:
	var key = bolt.source
	var skill = effective(key)
	var evo = key in evolved
	hit(mob, bolt.damage, key, 20 if key == "armor_breaker" else 0, bolt.damage > skill.damage * stat("damage") * 1.7)
	apply_element(mob, key, bolt.damage)
	if skill.get("burn_duration",0)>0 and Content.element(key)=="fire":
		mob.burn = maxf(mob.burn,skill.burn_duration)
		mob.burn_dps = maxf(mob.burn_dps,skill.burn_damage*stat("burn")*stat("damage"))
	if skill.get("slow_duration",0)>0:
		mob.slow = maxf(mob.slow,skill.slow_duration+(1 if oath=="tide" else 0))
	mob.stun = maxf(mob.stun, skill.get("hit_stun", 0) * (0.25 if mob.boss else 1.0))
	if evo and key=="frost_sand": mob.stun = maxf(mob.stun,0.15 if mob.boss else 0.7)
	var chains = int(skill.get("chain_targets", 0)) + (4 if evo and key == "thunder_mark" else 0)
	if oath=="tide" and key=="thunder_mark": chains += 1
	var previous = mob
	var visited = [mob.uid]
	for i in range(chains):
		var candidates = near(pos(previous), maxf(160, skill.get("chain_range", 0))).filter(func(m): return m.uid not in visited)
		if candidates.is_empty(): break
		candidates.sort_custom(func(a, b): return pos(a).distance_squared_to(pos(previous)) < pos(b).distance_squared_to(pos(previous)))
		var chosen = candidates[0]
		emit("chain", {"x": previous.x, "y": previous.y, "tx": chosen.x, "ty": chosen.y, "source": key})
		hit(chosen, bolt.damage * 0.72, key)
		apply_element(chosen, key, bolt.damage * 0.72)
		visited.append(chosen.uid)
		previous = chosen
	var radius = 85 if evo and key == "fire_talisman" else skill.get("explosion_radius", 0)
	if radius > 0:
		for other in near(pos(mob), radius):
			if other.uid != mob.uid:
				var splash = 0.7 if evo and key=="fire_talisman" else skill.get("explosion_damage_ratio",0.7)
				hit(other, bolt.damage * splash, key)
				apply_element(other, key, bolt.damage * splash)
		emit("ring", {"x": mob.x, "y": mob.y, "radius": radius, "source": key})
	if key == "echo_mark": make_zone(pos(mob), 55, bolt.damage * 0.6, key, 0.4, 0.22, false, true)
	if key == "soul_lantern": heal(0.8)

func hostile_fan(mob: Dictionary, count: int, speed: float, radial: bool = false, aim: Vector2 = Vector2.ZERO) -> void:
	mob["cast"] = maxf(0.25,mob.get("cast",0))
	var base = aim.angle() if aim.length_squared()>0.01 else (pos(player)-pos(mob)).angle()
	emit("enemy_attack",{"x":mob.x,"y":mob.y,"angle":base,"source":"enemy","enemy_kind":mob.kind})
	for i in range(count):
		var angle = base + (TAU * i / count if radial else (i - (count - 1) / 2.0) * 0.17)
		make_bolt(pos(mob), Vector2.from_angle(angle)*speed,mob.damage*0.7,"enemy",true,0,0,"arrow" if mob.kind=="archer" else "seal")

func boss_attack(mob: Dictionary) -> void:
	mob["cast"] = 0.5
	var n = (stage - 1) % 4
	var angry = mob.hp < mob.max_hp * 0.5
	mob.attack += 1
	if angry and not mob.enraged:
		mob.enraged = true
		emit("enrage", {"x": mob.x, "y": mob.y, "text": "妖气暴涨 · 首领进入狂暴阶段！"})
	if n == 0 or (n == 3 and mob.attack % 2 == 0):
		for i in range(5 if angry else 3):
			var p = pos(player) if i == 0 else Vector2(rng.randf_range(230, 1380), rng.randf_range(260, 720))
			make_zone(p, 65 if n == 0 else 78, mob.damage, "enemy", 0.6, 1.25 if n == 0 else 1.05, true, true)
		hostile_fan(mob, 7 if angry else 3, 165)
	elif n == 1:
		var direction = (pos(player) - pos(mob)).normalized()
		mob.dx = direction.x
		mob.dy = direction.y
		mob.windup = 0.9 if not angry else 0.65
		hostile_fan(mob, 10 if angry else 6, 145, true)
	elif n == 2:
		make_zone(pos(player), 105, mob.damage, "enemy", 0.5, 1.2, true, true)
		hostile_fan(mob, 20 if angry else 12, 145, true)
		if angry: make_zone(pos(mob), 210, mob.damage * 0.7, "enemy", 0.35, 1.5, true, true)
	else:
		hostile_fan(mob, 20 if angry else 12, 165, true)
		hostile_fan(mob, 5, 220)
	if angry and mob.attack % 3 == 0:
		for i in range(2): spawn(biome().enemies[rng.randi_range(0, biome().enemies.size() - 1)])
	mob.cooldown = (2.6 if angry else 3.8) * (1 - 0.06 * difficulty)

func update_mobs(dt: float) -> void:
	for mob in mobs.duplicate():
		if mob.hp <= 0: continue
		mob.spawn_age += dt
		mob["cast"] = maxf(0,mob.get("cast",0)-dt)
		for field in ["slow", "stun", "flash", "wet", "reaction_cd"]: mob[field] = maxf(0, mob[field] - dt)
		for hazard in hazards:
			var offset = pos(mob)-pos(hazard)
			if Vector2(offset.x/hazard.radius,offset.y/(hazard.radius*0.55)).length_squared()<1: mob.wet = 1.0
		if mob.burn > 0:
			mob.burn = maxf(0, mob.burn - dt)
			hit(mob, mob.burn_dps * dt, mob.burn_source)
		if mob.poison > 0:
			mob.poison = maxf(0, mob.poison - dt)
			hit(mob, mob.poison_dps * dt, "poison_mist")
		if mob.hp <= 0 or phase != "active": continue
		if mob.stun>0: continue
		var direction = (pos(player) - pos(mob)).normalized()
		var look = Vector2(mob.dx,mob.dy) if mob.windup>0 or mob.charging>0 else direction
		if absf(look.x)>0.1: mob.facing = signf(look.x)
		mob.cooldown -= dt
		mob["preparing"] = maxf(0,mob.get("preparing",0)-dt)
		if mob.boss and mob.get("attack_pending",false) and mob.preparing<=0:
			mob.attack_pending = false
			boss_attack(mob)
		if mob.windup > 0:
			if mob.kind=="archer" and not mob.get("aim_locked",false):
				mob.dx = direction.x
				mob.dy = direction.y
				mob["aim_locked"] = true
			mob.windup -= dt
			if mob.windup <= 0:
				if mob.kind == "stone_guard" and not mob.boss:
					mob["cast"] = 0.35
					make_zone(pos(mob),95,mob.damage,"enemy",0.35,0,true,true)
					emit("ring",{"x":mob.x,"y":mob.y,"radius":95,"source":"enemy"})
				elif mob.kind=="archer" and not mob.boss:
					hostile_fan(mob,3 if mob.elite else 1,200,false,Vector2(mob.dx,mob.dy))
				else:
					mob.charging = 0.65
					emit("enemy_dash", {"x": mob.x, "y": mob.y})
		elif mob.charging > 0:
			mob.charging -= dt
			move_entity(mob, Vector2(mob.dx, mob.dy) * dt * 560)
		elif mob.stun <= 0 and mob.preparing<=0:
			var speed = mob.speed * (0.48 if mob.slow > 0 else 1.0)
			if mob.kind == "archer" and not mob.boss:
				var distance = pos(mob).distance_to(pos(player))
				if distance < 260: direction = -direction
				elif distance < 400: direction = Vector2.ZERO
			move_entity(mob, direction * speed * dt)
		if mob.cooldown <= 0 and mob.stun <= 0:
			if mob.boss and not mob.get("attack_pending",false):
				mob["preparing"] = 0.65 if mob.hp<mob.max_hp*0.5 else 0.85
				mob["attack_pending"] = true
				mob.cooldown = 10
			elif mob.kind == "archer":
				mob.dx = direction.x
				mob.dy = direction.y
				mob["aim_locked"] = true
				mob.windup = 0.45
				mob.cooldown = 2.6
			elif mob.kind == "mist_fox":
				mob.dx = direction.x
				mob.dy = direction.y
				mob.windup = 0.65
				mob.cooldown = 4.5
			elif mob.kind == "lantern_wisp":
				mob["cast"] = 0.35
				make_zone(pos(mob), 62, mob.damage, "enemy", 0.35, 0.95, true, true)
				mob.cooldown = 5.0
			elif mob.kind == "stone_guard" and pos(mob).distance_to(pos(player))<170:
				mob.windup = 0.8
				mob.cooldown = 4.6
		if mob.spawn_age > 0.4 and pos(mob).distance_to(pos(player)) < mob.radius + player.radius: hurt(mob.damage)

func update_bolts(dt: float) -> void:
	for bolt in bolts:
		bolt.life -= dt
		if bolt.homing > 0 and not bolt.hostile:
			var target = nearest(pos(bolt))
			if not target.is_empty():
				var velocity = Vector2(bolt.vx, bolt.vy)
				velocity = velocity.lerp((pos(target) - pos(bolt)).normalized() * velocity.length(), minf(1, dt * bolt.homing * 4))
				bolt.vx = velocity.x
				bolt.vy = velocity.y
		var before = pos(bolt)
		set_pos(bolt, before + Vector2(bolt.vx, bolt.vy) * dt)
		if bolt.hostile:
			var closest = Geometry2D.get_closest_point_to_segment(pos(player), before, pos(bolt))
			if closest.distance_to(pos(player)) < player.radius + bolt.radius:
				hurt(bolt.damage)
				bolt.life = 0
		else:
			var candidates = near((before + pos(bolt)) * 0.5, before.distance_to(pos(bolt)) * 0.5 + bolt.radius + 45)
			for mob in candidates:
				if mob.uid in bolt.hits: continue
				var closest = Geometry2D.get_closest_point_to_segment(pos(mob), before, pos(bolt))
				if closest.distance_to(pos(mob)) < mob.radius + bolt.radius:
					bolt.hits.append(mob.uid)
					bolt_hit(bolt, mob)
					bolt.pierce -= 1
					if bolt.pierce < 0:
						bolt.life = 0
						break
	bolts = bolts.filter(func(b): return b.life > 0 and Rect2(40, 110, 1520, 730).has_point(pos(b)))

func update_zones(dt: float) -> void:
	for zone in zones:
		if zone.warning > 0:
			zone.warning = maxf(0, zone.warning - dt)
			if zone.warning <= 0: emit("ring", {"x": zone.x, "y": zone.y, "radius": zone.radius, "source": zone.source})
			continue
		zone.life -= dt
		zone.tick -= dt
		if zone.tick > 0: continue
		zone.tick = 0.38
		if zone.hostile:
			if pos(zone).distance_to(pos(player)) < zone.radius + player.radius: hurt(zone.damage)
		else:
			for mob in near(pos(zone), zone.radius):
				hit(mob, zone.damage, zone.source)
				apply_element(mob, zone.source, zone.damage)
				if zone.source=="binding_hex": mob.slow = maxf(mob.slow,1.0)
		if zone.once: zone.life = 0
	zones = zones.filter(func(z): return z.life > 0)

func update_drops(dt: float) -> void:
	var remaining: Array = []
	var pickup_radius = 105*stat("magnet")
	for drop in drops:
		drop.age += dt
		var direction = pos(player) - pos(drop)
		var distance = direction.length()
		if distance < pickup_radius or drop.age > 35: set_pos(drop, pos(drop) + direction.normalized() * minf(distance, (350 + drop.age * 10) * dt))
		if distance < 24:
			match drop.kind:
				"xp": gain_xp(drop.value)
				"coin":
					coins += int(drop.value)
					if "broken_coin" in relics: heal(1)
				"heal": heal(drop.value)
			emit("pickup", {"x": drop.x, "y": drop.y, "kind_drop": drop.kind})
		else: remaining.append(drop)
	drops = remaining

func director(dt: float) -> void:
	spawn_timer -= dt
	if spawn_timer <= 0 and mobs.size() < 170:
		var count = 1 + int(sector_time / 22) + int((stage - 1) / 2)
		if contract == "swarm": count = ceili(count * 1.35)
		count = mini(count,170-mobs.size())
		for i in range(count): spawn(biome().enemies[rng.randi_range(0, biome().enemies.size() - 1)])
		spawn_timer = maxf(0.42, 1.45 - sector_time * 0.012 - difficulty * 0.12)
	if sector_time >= 35 and not elite_spawned:
		elite_spawned = true
		spawn(biome().enemies[0], true)
	if sector_time >= 75 and not boss_spawned:
		boss_spawned = true
		spawn("boss" + str((stage - 1) % 4), false, true)
	if shrine.is_empty() and shrine_index < 2 and sector_time >= [22, 52][shrine_index]:
		shrine_index += 1
		shrine = {"x": 420.0 if shrine_index == 1 else 1180.0, "y": 650.0 if shrine_index == 1 else 310.0, "progress": 0.0, "life": 24.0}
		emit("notice", {"text": "古灯升起 · 靠近并长按 E 点灯"})

func update(dt: float, move: Vector2 = Vector2.ZERO, interact: bool = false) -> void:
	if phase != "active": return
	step_stats = calculate_stats()
	inside_step = true
	update_step(dt,move,interact)
	inside_step = false

func update_step(dt: float, move: Vector2, interact: bool) -> void:
	dt = clampf(dt, 0, 0.05)
	time += dt
	sector_time += dt
	combo_time = maxf(0, combo_time - dt)
	if combo_time == 0: combo = 0
	for field in ["invulnerable", "dash_cd", "cast"]: player[field] = maxf(0, player[field] - dt)
	player.moving = move.length_squared() > 0.01 or player.dash_time > 0
	if absf(move.x) > 0.01: player.facing = signf(move.x)
	var speed = Content.data.characters[character].speed * stat("speed")
	if player.dash_time > 0:
		player.dash_time = maxf(0, player.dash_time - dt)
		move = Vector2(player.dash_dx, player.dash_dy)
		speed = 790
	move_entity(player, move.limit_length(1.0) * speed * dt)
	heal(stat("regen") * dt)
	director(dt)
	update_mobs(dt)
	if phase != "active": return
	rebuild_index()
	for key in weapons:
		timers[key] = float(timers.get(key, 0)) - dt
		if timers[key] <= 0 and (not mobs.is_empty() or key == "healing_mark"):
			cast(key)
			timers[key] = (0.22 if key in ["ward_shard", "shadow_twin"] else effective(key).cooldown) * maxf(0.4, 1.0 - stat("haste"))
			if phase != "active": return
	update_bolts(dt)
	if phase != "active": return
	update_zones(dt)
	if phase != "active": return
	update_drops(dt)
	mobs = mobs.filter(func(m): return m.hp > 0)
	if not shrine.is_empty():
		shrine.life -= dt
		if interact and pos(player).distance_to(pos(shrine)) < 85: shrine.progress += dt * (2 if "green_lamp" in relics else 1)
		else: shrine.progress = maxf(0, shrine.progress - dt * 0.3)
		if shrine.progress >= 2.6:
			shrines += 1
			coins += 33 if "green_lamp" in relics else 18
			heal(8)
			gain_xp(35)
			emit("shrine", {"x": shrine.x, "y": shrine.y})
			shrine = {}
		elif shrine.life <= 0: shrine = {}
	if player.hp <= 0: finish(false)
	elif pending_relics > 0: open_relic_draft("active")
	elif pending_levels > 0: roll_choices()

func finish(won: bool) -> void:
	victory = won
	phase = "finished"
	emit("victory" if won else "defeat")

func result() -> Dictionary:
	var reward = int((4 + int(kills / 25) + bosses * 8 + (24 if victory else 0)) * Content.data.contracts[contract].bonus)
	return {"run_id": run_id, "character": character, "mode": mode, "seed":str(rng.seed), "difficulty": difficulty, "contract": contract, "oath":oath, "victory": victory, "stage": stage, "time": int(time), "kills": kills, "bosses": bosses, "reward": reward, "level": level, "weapons":weapons.duplicate(), "passives":passives.duplicate(), "evolved": evolved.duplicate(), "relics": relics.duplicate(), "damage_by_skill": damage_by_skill.duplicate(), "damage_taken": int(total_damage_taken), "reactions": reactions.duplicate(), "date": Time.get_datetime_string_from_system()}

func snapshot() -> Dictionary:
	var raw = {"version": 4, "rng_state": str(rng.state), "rng_seed": str(rng.seed)}
	for key in SNAPSHOT_KEYS:
		var value = get(key)
		raw[key] = value.duplicate(true) if value is Dictionary or value is Array else value
	for key in ["oath","pending_relics","relic_return_phase","pending_replacement"]: raw[key] = get(key)
	return raw

func restore(raw: Dictionary) -> bool:
	if not valid_snapshot(raw): return false
	raw = raw.duplicate(true)
	for key in SNAPSHOT_KEYS:
		var value = raw[key]
		if key in ["difficulty", "stage", "level", "pending_levels", "rerolls", "coins", "kills", "bosses", "shrines", "shrine_index", "uid", "combo"]: value = int(value)
		set(key, value)
	for mob in mobs:
		for key in ["uid", "attack", "xp"]: mob[key] = int(mob[key])
	for collection in [weapons, passives, camp, reactions]:
		for key in collection: collection[key] = int(collection[key])
	for drop in drops: drop.value = int(drop.value)
	for bolt in bolts:
		for key in ["uid", "pierce"]: bolt[key] = int(bolt[key])
		for i in range(bolt.hits.size()): bolt.hits[i] = int(bolt.hits[i])
	rng.seed = int(raw.rng_seed)
	for key in ["oath","pending_relics","relic_return_phase","pending_replacement"]: set(key,raw[key])
	pending_relics = int(pending_relics)
	rng.state = int(raw.rng_state)
	rebuild_index()
	return true

func numeric(value, minimum: float = -1.0e12, maximum: float = 1.0e12, integer: bool = false) -> bool:
	if not (value is int or value is float): return false
	return is_finite(float(value)) and value>=minimum and value<=maximum and (not integer or value==floorf(value))

func record(value, numbers: Array, booleans: Array = [], strings: Array = []) -> bool:
	if not value is Dictionary: return false
	for key in numbers:
		if not value.has(key) or not numeric(value[key]): return false
	for key in booleans:
		if not value.get(key) is bool: return false
	for key in strings:
		if not value.get(key) is String or value[key].length()>120: return false
	if value.has("radius") and not numeric(value.radius,1,2000): return false
	return true

func known_source(value) -> bool:
	return value is String and (value=="enemy" or Content.skills.has(value))

func valid_snapshot(raw: Dictionary) -> bool:
	if raw.get("version") != 4: return false
	if raw.get("phase", "") not in ["active", "upgrade", "route","oath","relic","relic_replace"]: return false
	if raw.get("oath","")!="none" and not Content.data.oaths.has(raw.get("oath","")): return false
	if not numeric(raw.get("pending_relics"),0,100,true): return false
	if raw.get("relic_return_phase") not in ["active","route"]: return false
	if not raw.get("pending_replacement") is String: return false
	if raw.pending_replacement!="" and not Content.data.relics.has(raw.pending_replacement): return false
	for key in ["rng_seed","rng_state"]:
		if not raw.get(key) is String or raw[key].length()>20 or not raw[key].is_valid_int(): return false
	if not Content.data.characters.has(raw.get("character", "")): return false
	if not Content.data.contracts.has(raw.get("contract", "")): return false
	if raw.get("mode", "") not in ["campaign", "daily", "endless"]: return false
	for key in SNAPSHOT_KEYS:
		if not raw.has(key): return false
		if not raw.has(key) or typeof(raw[key]) != typeof(get(key)):
			if not ((raw.get(key) is float or raw.get(key) is int) and (get(key) is float or get(key) is int)): return false
		if (get(key) is float or get(key) is int) and not numeric(raw[key]): return false
	if not numeric(raw.stage,1,10000,true) or not numeric(raw.difficulty,0,3,true): return false
	for key in ["level","xp","xp_next","pending_levels","rerolls","coins","kills","bosses","shrines","shrine_index","uid","combo","time","sector_time","sector_damage","total_damage_taken","charge"]:
		if not numeric(raw[key],0): return false
	if raw.level<1 or raw.xp_next<=0 or raw.charge>30 or raw.run_id.is_empty() or raw.run_id.length()>120: return false
	if raw.weapons.is_empty() or raw.weapons.size() > 4 or raw.passives.size() > 6: return false
	for key in raw.weapons:
		if not Content.skills.has(key) or not numeric(raw.weapons[key],1,5,true): return false
	for key in raw.passives:
		if not Content.data.passives.has(key) or not numeric(raw.passives[key],1,3,true): return false
	for key in raw.camp:
		if not Content.data.camp.has(key) or not numeric(raw.camp[key],0,8,true): return false
	if raw.relics.size()>4 or raw.evolved.size()>4: return false
	for key in raw.relics:
		if not Content.data.relics.has(key) or raw.relics.count(key)!=1: return false
	for key in raw.evolved:
		if not Content.data.evolutions.has(key) or raw.evolved.count(key)!=1: return false
		if raw.weapons.get(key,0)!=5 or not raw.passives.has(Content.data.evolutions[key].passive): return false
	for key in raw.timers:
		if not raw.weapons.has(key) or not numeric(raw.timers[key]): return false
	for key in raw.reactions:
		if key not in ["融霜","燃瘴","引雷"] or not numeric(raw.reactions[key],0,1e12,true): return false
	for key in raw.damage_by_skill:
		if not (Content.skills.has(key) or key in ["pulse","reaction:融霜","reaction:燃瘴","reaction:引雷"]) or not numeric(raw.damage_by_skill[key],0): return false
	if not record(raw.player,["x","y","hp","max_hp","radius","facing","invulnerable","dash_time","dash_cd","dash_dx","dash_dy","cast"],["moving","fox_ready"]): return false
	if raw.player.hp<=0 or raw.player.max_hp<=0 or raw.player.hp>raw.player.max_hp: return false
	if not BOUNDS.grow(1).has_point(Vector2(raw.player.x,raw.player.y)): return false
	for spec in [["mobs",200],["bolts",700],["zones",1000],["drops",2000],["obstacles",50],["hazards",50]]:
		if raw[spec[0]].size()>spec[1]: return false
	var seen_ids = {}
	for mob in raw.mobs:
		if not record(mob,["uid","x","y","hp","max_hp","speed","damage","radius","cooldown","windup","charging","dx","dy","slow","stun","burn","burn_dps","poison","poison_dps","wet","reaction_cd","flash","facing","attack","xp","spawn_age"],["elite","boss","enraged"],["kind","burn_source"]): return false
		if mob.kind not in MOB_STATS and mob.kind not in ["boss0","boss1","boss2","boss3"]: return false
		if mob.boss != mob.kind.begins_with("boss") or mob.max_hp<=0 or not numeric(mob.uid,1,raw.uid,true) or seen_ids.has(mob.uid): return false
		if not known_source(mob.burn_source): return false
		seen_ids[mob.uid] = true
		for key in ["cast","preparing"]:
			if mob.has(key) and not numeric(mob[key],0): return false
		if mob.has("attack_pending") and not mob.attack_pending is bool: return false
		if mob.has("aim_locked") and not mob.aim_locked is bool: return false
	for bolt in raw.bolts:
		if not record(bolt,["uid","x","y","vx","vy","damage","pierce","homing","radius","life"],["hostile"],["source"]): return false
		if not known_source(bolt.source) or not bolt.get("hits") is Array or bolt.hits.size()>200: return false
		if bolt.has("skin") and bolt.skin not in ["seal","arrow"]: return false
		if not numeric(bolt.uid,1,raw.uid,true) or seen_ids.has(bolt.uid): return false
		seen_ids[bolt.uid] = true
		for id in bolt.hits:
			if not numeric(id,1,raw.uid,true): return false
	for zone in raw.zones:
		if not record(zone,["x","y","radius","damage","life","warning","warning_max","tick"],["hostile","once"],["source"]) or not known_source(zone.source): return false
	for drop in raw.drops:
		if not record(drop,["x","y","value","age"],[],["kind"]) or drop.kind not in ["xp","coin","heal"] or not numeric(drop.value,0,1e9,true): return false
	for obstacle in raw.obstacles:
		if not record(obstacle,["x","y","radius"]): return false
	for hazard in raw.hazards:
		if not record(hazard,["x","y","radius"],[],["kind"]) or hazard.kind!="water": return false
	if not raw.shrine.is_empty() and not record(raw.shrine,["x","y","progress","life"]): return false
	if raw.choices.size()>4 or raw.routes.size()>3: return false
	for route in raw.routes:
		if not route is String or Content.route(route).is_empty(): return false
	for choice in raw.choices:
		if not choice is String: return false
		var parts = choice.split(":")
		if parts.size()!=2: return false
		var kind = parts[0]
		var key = parts[1]
		if kind not in ["w","p","e","r","d","o","gift"]: return false
		if kind=="w" and (not Content.skills.has(key) or raw.weapons.get(key,0)>=5): return false
		if kind=="p" and (not Content.data.passives.has(key) or raw.passives.get(key,0)>=3): return false
		if kind=="e" and (not Content.data.evolutions.has(key) or raw.weapons.get(key,0)<5 or not raw.passives.has(Content.data.evolutions[key].passive) or key in raw.evolved): return false
		if kind in ["r","d"] and not Content.data.relics.has(key): return false
		if kind=="o" and not Content.data.oaths.has(key): return false
		if kind=="gift" and key not in ["heal","coin"]: return false
		if raw.phase=="upgrade" and kind not in ["w","p","e","gift"]: return false
		if raw.phase=="relic" and (kind!="r" or key in raw.relics): return false
		if raw.phase=="relic_replace" and (kind!="d" or key not in raw.relics): return false
		if raw.phase=="oath" and kind!="o": return false
	if raw.phase in ["upgrade","oath","relic","relic_replace"] and raw.choices.is_empty(): return false
	if raw.phase=="relic_replace" and (raw.relics.size()!=4 or raw.pending_replacement=="" or raw.pending_replacement in raw.relics): return false
	if raw.phase=="route" and raw.routes.is_empty(): return false
	return true
