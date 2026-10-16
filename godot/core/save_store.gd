extends Node

var directory = "user://"
var profile: Dictionary = {}
var error = ""
# Keys added after the first 3.x release; older profiles without them stay valid.
const OPTIONAL_KEYS = ["records", "story_seen"]
const OPTIONAL_SETTINGS = ["motion", "numbers"]

func _ready() -> void:
	load_profile()

func defaults() -> Dictionary:
	return {"version": 3, "embers": 0, "camp": {"vigor": 0, "focus": 0, "stride": 0, "fortune": 0}, "kills": 0, "bosses": 0, "victories": 0, "shrines": 0, "achievements": [], "history": [], "records":{}, "settled": [], "settings": {"music": 0.55, "sfx": 0.75, "shake": true, "particles": true, "fullscreen": false, "motion": true, "numbers": true}, "tutorial_seen": false, "story_seen": false}

func read_json(name: String) -> Dictionary:
	for suffix in ["", ".bak"]:
		var path = directory + name + suffix
		if not FileAccess.file_exists(path):
			continue
		var file = FileAccess.open(path,FileAccess.READ)
		if file==null: continue
		if file.get_length()>16*1024*1024:
			file.close()
			continue
		file.close()
		var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
		if raw is Dictionary and (name != "profile.json" or valid_profile(raw)):
			return raw
	return {}

func valid_profile(raw: Dictionary) -> bool:
	if raw.get("version",0) != 3: return false
	for key in defaults():
		if key in OPTIONAL_KEYS and not raw.has(key): continue
		if not raw.has(key): return false
		var expected = defaults()[key]
		if expected is int:
			if not (raw[key] is float or raw[key] is int) or not is_finite(float(raw[key])) or raw[key]<0: return false
		elif typeof(raw[key]) != typeof(expected): return false
	for key in defaults().camp:
		var value = raw.camp.get(key,-1)
		if not (value is float or value is int) or not is_finite(float(value)) or value<0 or value>8: return false
	for key in raw.camp:
		if not defaults().camp.has(key): return false
	for key in defaults().settings:
		if not raw.settings.has(key):
			if key in OPTIONAL_SETTINGS: continue
			return false
		var value = raw.settings[key]
		if defaults().settings[key] is bool:
			if not value is bool: return false
		elif not (value is float or value is int) or not is_finite(float(value)): return false
	for key in raw.achievements:
		if not key is String: return false
	for id in raw.settled:
		if not id is String or id.length()>120: return false
	if raw.history.size()>20: return false
	for item in raw.history:
		if not valid_result(item): return false
	for id in raw.get("records",{}):
		if not id is String or id.length()>80 or not valid_result(raw.records[id]): return false
	return true

func valid_result(item) -> bool:
	if not item is Dictionary or not item.get("victory") is bool: return false
	if item.get("ruleset") in ["chapter_one","nightroad_campaign"]:
		var definitions=load("res://content/chapter_content.gd")
		if not definitions.GEAR.has(item.get("gear")) or not definitions.SKILLS.has(item.get("skill")): return false
		if not item.get("sigils",{}) is Dictionary or item.get("sigils",{}).size()>6: return false
		for key in item.get("sigils",{}):
			if not definitions.SIGILS.has(key) or not RunWorld.new().numeric(item.sigils[key],1,3,true): return false
		if not item.get("attributes",{}) is Dictionary: return false
		for key in item.get("attributes",{}):
			if not definitions.ATTRIBUTES.has(key) or not RunWorld.new().numeric(item.attributes[key],0,100,true): return false
		for key in ["gear_rank","skill_rank"]:
			if not RunWorld.new().numeric(item.get(key,1),1,3,true): return false
		for key in ["gear_mod","skill_mod"]:
			if not RunWorld.new().numeric(item.get(key,-1),-1,1,true): return false
	if not Content.data.characters.has(item.get("character")): return false
	if item.get("mode") not in ["campaign","endless","daily"]: return false
	for key in ["stage","kills","bosses","time","level","reward","difficulty"]:
		if not (item.get(key) is int or item.get(key) is float) or not is_finite(float(item[key])) or item[key]<0: return false
	for field in ["weapons","passives","damage_by_skill"]:
		if item.has(field) and not item[field] is Dictionary: return false
	if item.get("weapons",{}).size()>4 or item.get("passives",{}).size()>6 or item.get("damage_by_skill",{}).size()>30: return false
	for field in ["relics","evolved"]:
		if item.has(field) and not item[field] is Array: return false
	for key in item.get("weapons",{}):
		if not Content.skills.has(key) or not RunWorld.new().numeric(item.weapons[key],1,5,true): return false
	for key in item.get("passives",{}):
		if not Content.data.passives.has(key) or not RunWorld.new().numeric(item.passives[key],1,3,true): return false
	for key in item.get("damage_by_skill",{}):
		if not key is String or not RunWorld.new().numeric(item.damage_by_skill[key],0): return false
	for key in item.get("relics",[]):
		if item.get("ruleset") in ["chapter_one","nightroad_campaign"]:
			if not load("res://content/chapter_content.gd").RELICS.has(key): return false
		elif not Content.data.relics.has(key): return false
	for key in item.get("evolved",[]):
		if not Content.data.evolutions.has(key): return false
	for field in ["damage_taken","achievement_reward","reward_total"]:
		if item.has(field) and not RunWorld.new().numeric(item[field],0): return false
	if item.has("date") and (not item.date is String or item.date.length()>40): return false
	if item.has("oath") and (not item.oath is String or (item.oath!="none" and not Content.data.oaths.has(item.oath))): return false
	return true

func load_profile() -> void:
	profile = defaults()
	var raw = read_json("profile.json")
	if not raw.is_empty() and int(raw.get("version", 0)) == 3:
		for key in profile:
			if not raw.has(key): continue
			if profile[key] is int: profile[key] = int(raw[key])
			else: profile[key] = raw[key]
	for key in defaults().camp:
		profile.camp[key] = clampi(int(profile.camp.get(key, 0)), 0, 8)
	for key in defaults().settings:
		if not profile.settings.has(key):
			profile.settings[key] = defaults().settings[key]
	for key in ["music", "sfx"]:
		var value = profile.settings[key]
		profile.settings[key] = clampf(float(value),0,1) if (value is float or value is int) and is_finite(float(value)) else defaults().settings[key]
	for key in ["shake", "particles", "fullscreen", "motion", "numbers"]:
		if not profile.settings[key] is bool: profile.settings[key] = defaults().settings[key]
	for key in ["embers", "kills", "bosses", "victories", "shrines"]:
		profile[key] = maxi(0,int(profile[key]))

func write_json(name: String, raw: Dictionary) -> bool:
	return write_value(name, raw, false)

func write_value(name: String, raw: Dictionary, binary: bool) -> bool:
	error = ""
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory)) != OK:
		error = "无法创建存档目录。"
		return false
	var path = directory + name
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null:
		error = "无法写入存档，请检查目录权限。"
		return false
	if binary: file.store_var(raw)
	else: file.store_string(JSON.stringify(raw, "", true, true))
	file.flush()
	var result = file.get_error()
	file.close()
	if result != OK:
		error = "存档写入失败。"
		return false
	if FileAccess.file_exists(path):
		var valid_primary = true
		if name=="profile.json":
			var existing = JSON.parse_string(FileAccess.get_file_as_string(path))
			valid_primary = existing is Dictionary and valid_profile(existing)
		elif binary:
			var existing = read_binary(path)
			valid_primary = existing is Dictionary and valid_run(existing)
		if valid_primary and DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak")) != OK:
			error = "无法保留存档备份。"
			return false
		if not valid_primary:
			var archive = path+".corrupt-"+str(Time.get_unix_time_from_system())+"-"+str(Time.get_ticks_usec())
			if DirAccess.copy_absolute(ProjectSettings.globalize_path(path),ProjectSettings.globalize_path(archive))!=OK:
				error = "无法保留损坏记录，原文件未替换。"
				return false
	result = DirAccess.rename_absolute(ProjectSettings.globalize_path(path + ".tmp"), ProjectSettings.globalize_path(path))
	if result != OK:
		error = "无法替换存档。"
	return result == OK

func save_profile() -> bool:
	return write_json("profile.json", profile)

func save_run(world) -> bool:
	return write_value("expedition.save", world.snapshot(), true)

func read_run() -> Dictionary:
	for suffix in ["", ".bak"]:
		var raw = read_binary(directory + "expedition.save" + suffix)
		if raw is Dictionary and valid_run(raw): return raw
	return {}

func read_binary(path: String):
	var file=FileAccess.open(path,FileAccess.READ)
	if file==null: return null
	var length=file.get_length()
	if length<8 or length>16*1024*1024:
		file.close(); return null
	var payload_size=file.get_32()
	var kind=file.get_32() & 0xff
	if payload_size!=length-4 or kind!=TYPE_DICTIONARY:
		file.close(); return null
	file.seek(0)
	var raw=file.get_var(false)
	file.close()
	return raw

func valid_run(raw: Dictionary) -> bool:
	if raw.get("ruleset")=="nightroad_campaign": return load("res://systems/campaign_world.gd").new().valid_snapshot(raw)
	if raw.get("ruleset")=="chapter_one": return load("res://systems/chapter_world.gd").new().valid_snapshot(raw)
	return RunWorld.new().valid_snapshot(raw)

func clear_run() -> void:
	for suffix in ["", ".bak"]:
		var path = directory + "expedition.save" + suffix
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func camp_cost(key: String) -> int:
	return 20 + int(profile.camp.get(key, 0)) * 16

func buy_camp(key: String) -> bool:
	if not profile.camp.has(key) or profile.camp[key] >= 8 or profile.embers < camp_cost(key):
		return false
	var previous = profile.duplicate(true)
	profile.embers -= camp_cost(key)
	profile.camp[key] += 1
	if save_profile(): return true
	profile = previous
	return false

func settle(world) -> Dictionary:
	var result = world.result()
	if result.run_id in profile.settled:
		for record in profile.history:
			if record.get("run_id","")==result.run_id: return record.duplicate(true)
		return result
	var previous = profile.duplicate(true)
	profile.settled.append(result.run_id)
	profile.embers += result.reward
	profile.kills += world.kills
	profile.bosses += world.bosses
	profile.shrines += world.shrines
	profile.victories += int(world.victory)
	profile.history.push_front(result)
	profile.history = profile.history.slice(0, 20)
	var tests = {"first_boss": profile.bosses > 0, "victory": world.victory, "kills500": profile.kills >= 500, "kills2000": profile.kills >= 2000, "evolve": not world.evolved.is_empty(), "shrines": profile.shrines >= 8, "relics": world.relics.size() >= 4, "nohit": world.nohit, "ascend": world.victory and world.difficulty > 0, "contract": world.victory and world.contract != "none"}
	if world is ChapterWorld: tests.evolve=world.gear_mod>=0 or world.skill_mod>=0
	result["unlocked"] = []
	result["achievement_reward"] = 0
	for achievement in Content.data.achievements:
		if tests.get(achievement.id, false) and achievement.id not in profile.achievements:
			profile.achievements.append(achievement.id)
			profile.embers += achievement.reward
			result.achievement_reward += achievement.reward
			result.unlocked.append(achievement.name)
	result["reward_total"] = result.reward+result.achievement_reward
	if world.mode in ["daily","endless"]:
		var key = "daily:"+str(world.rng.seed) if world.mode=="daily" else "endless:"+world.character
		if result.get("ruleset")=="chapter_one": key="daily:chapter_one:"+str(world.rng.seed)
		if result.get("ruleset")=="nightroad_campaign": key="daily:nightroad_campaign:"+str(world.rng.seed)
		var previous_best = profile.records.get(key,{})
		if previous_best.is_empty() or record_score(result)>record_score(previous_best) or (record_score(result)==record_score(previous_best) and result.time<previous_best.time):
			profile.records[key] = result.duplicate(true)
		var prefix="daily:chapter_one:" if result.get("ruleset")=="chapter_one" else "daily:"
		if result.get("ruleset")=="nightroad_campaign": prefix="daily:nightroad_campaign:"
		var daily_keys = profile.records.keys().filter(func(id): return id.begins_with(prefix) and (prefix!="daily:" or not id.begins_with("daily:chapter_one:")))
		daily_keys.sort()
		while daily_keys.size()>30: profile.records.erase(daily_keys.pop_front())
	if save_profile():
		clear_run()
	else:
		profile = previous
		result["save_error"] = error
	return result

func record_score(result: Dictionary) -> int:
	return int(result.stage)*1000 + int(result.bosses)*250 + int(result.kills) + (10000 if result.victory else 0)

func import_legacy_profile(path: String) -> bool:
	error = ""
	var file = FileAccess.open(path,FileAccess.READ)
	if file==null:
		error = "无法打开旧版营地记录。"
		return false
	var size = file.get_length()
	file.close()
	if size>16*1024*1024:
		error = "文件过大，请选择旧版营地 profile.json。"
		return false
	var raw = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not raw is Dictionary or int(raw.get("version",0)) != 2:
		error = "请选择旧版 save_data 目录中的 profile.json。"
		return false
	if not raw.get("camp") is Dictionary or not raw.get("stats") is Dictionary:
		error = "旧版营地记录缺少必要字段。"
		return false
	for key in ["embers"]:
		if not (raw.get(key) is float or raw.get(key) is int) or not is_finite(float(raw[key])) or raw[key]<0:
			error = "旧版营地数值无效。"
			return false
	for key in defaults().camp:
		var value = raw.camp.get(key,0)
		if not (value is float or value is int) or not is_finite(float(value)) or value<0 or value>5:
			error = "旧版营地成长无效。"
			return false
	for key in ["kills","bosses","shrines","wins"]:
		var value = raw.stats.get(key,0)
		if not (value is float or value is int) or not is_finite(float(value)) or value<0:
			error = "旧版夜行统计无效。"
			return false
	var previous = profile.duplicate(true)
	profile.embers = maxi(int(profile.embers),int(raw.embers))
	for key in defaults().camp: profile.camp[key] = maxi(int(profile.camp[key]),int(raw.camp.get(key,0)))
	for key in ["kills","bosses","shrines"]: profile[key] = maxi(int(profile[key]),int(raw.stats.get(key,0)))
	profile.victories = maxi(int(profile.victories),int(raw.stats.get("wins",0)))
	var known = Content.data.achievements.map(func(item): return item.id)
	if raw.get("achievements") is Array:
		for key in raw.achievements:
			if key in known and key not in profile.achievements: profile.achievements.append(key)
	if not save_profile():
		profile = previous
		return false
	return true
