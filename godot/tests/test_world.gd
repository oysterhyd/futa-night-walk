extends Node

var failures: Array = []
var checks = 0

func _ready() -> void:
	call_deferred("run")

func expect(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
		push_error(description)

func new_world(seed_value: int = 421) -> RunWorld:
	var world = RunWorld.new()
	world.begin({"seed": seed_value})
	world.events.clear()
	return world

func run() -> void:
	await get_tree().process_frame
	expect(Content.skills.size() == 20, "All twenty skills loaded")
	for index in range(3):
		var oath_world = RunWorld.new()
		oath_world.begin({"seed":421,"choose_oath":true})
		expect(oath_world.phase=="oath" and oath_world.choices.size()==3,"Three starting oaths offered")
		var initial_hp = oath_world.player.max_hp
		oath_world.choose_oath(index)
		expect(oath_world.oath==Content.data.oaths.keys()[index] and oath_world.phase=="active","Oath selected: "+oath_world.oath)
		if index==0: expect(is_equal_approx(oath_world.player.max_hp,initial_hp*0.9),"Cinder oath pays its health cost")
		if index==1: expect(is_equal_approx(oath_world.stat("dash"),0.2),"Tide oath improves dash cooldown")
		if index==2:
			var mob = oath_world.spawn("stone_guard")
			oath_world.rebuild_index()
			oath_world.cast("fire_talisman")
			expect(oath_world.bolts.size()==2,"Script oath grants another projectile")
	var reward_world = new_world()
	reward_world.relics = ["red_thread","old_wick","bamboo","silver"]
	reward_world.pending_relics = 1
	reward_world.open_relic_draft()
	var selected_relic = reward_world.choices[0].substr(2)
	reward_world.choose_relic(0)
	expect(reward_world.phase=="relic_replace","Full relic slots require replacement choice")
	var restored_reward = RunWorld.new()
	expect(restored_reward.restore(reward_world.snapshot()),"Pending replacement is resumable")
	restored_reward.choose_relic(0)
	expect(restored_reward.relics.size()==4 and selected_relic in restored_reward.relics,"Relic replaces one slot without overflow")
	reward_world.choose_relic(-1)
	expect(reward_world.relics.size()==4 and reward_world.coins==30,"Relic can be sold without losing held items")
	for key in Content.data.passives:
		var passive_world = new_world()
		passive_world.passives = {key:1}
		expect(passive_world.stat("damage") > 0, "Passive stats safely aggregate: "+key)
	var a = new_world()
	var b = new_world()
	for i in range(600):
		a.update(1.0/60,Vector2.RIGHT)
		b.update(1.0/60,Vector2.RIGHT)
	var state_a = a.snapshot()
	var state_b = b.snapshot()
	state_a.erase("run_id")
	state_b.erase("run_id")
	expect(state_a == state_b, "Same seed and input produce identical simulation")
	a = new_world()
	expect(a.dash(Vector2.RIGHT), "Dash starts")
	expect(not a.dash(Vector2.RIGHT), "Dash cooldown blocks repeats")
	var hp = a.player.hp
	a.hurt(100)
	expect(a.player.hp == hp, "Dash prevents damage")
	a.update(1.0/60)
	expect(a.player.x > 800, "Dash moves without held input")
	a = new_world()
	b = new_world()
	a.update(1.0/60,Vector2.RIGHT)
	b.update(1.0/60,Vector2.ONE)
	expect(is_equal_approx(a.pos(a.player).distance_to(Vector2(800,500)), b.pos(b.player).distance_to(Vector2(800,500))), "Diagonal movement normalized")
	var slow_walk = new_world()
	slow_walk.update(1.0/60,Vector2.RIGHT*0.5)
	expect(absf(slow_walk.pos(slow_walk.player).distance_to(Vector2(800,500))*2-a.pos(a.player).distance_to(Vector2(800,500)))<0.001,"Analog half strength produces half movement speed")
	for key in Content.skills:
		var w = new_world()
		w.weapons = {key: 3}
		w.player.hp = 70
		var target = w.spawn("stone_guard")
		target.x = 895.0
		target.y = 500.0
		target.hp = 100000.0
		target.max_hp = 100000.0
		target.speed = 0.0
		w.rebuild_index()
		w.cast(key)
		for i in range(120):
			w.update_bolts(1.0/60)
			w.update_zones(1.0/60)
		expect(w.damage_by_skill.get(key,0) > 0 or (key == "healing_mark" and w.player.hp > 70), "Skill behavior works: " + key)
	a = new_world()
	a.weapons.fire_talisman = 5
	a.passives.ember = 1
	a.pending_levels = 1
	a.roll_choices()
	expect("e:fire_talisman" in a.choices, "Eligible evolution is always offered")
	a.choose(a.choices.find("e:fire_talisman"))
	expect("fire_talisman" in a.evolved, "Evolution selected")
	var target = a.spawn("stone_guard")
	target.x = 900.0
	target.y = 500.0
	a.rebuild_index()
	a.cast("fire_talisman")
	expect(a.bolts.size() == 3, "Fire evolution shoots three bolts")
	for pair in [["frost_sand","fire_talisman","融霜"],["poison_mist","fire_talisman","燃瘴"],["frost_sand","thunder_mark","引雷"]]:
		var w = new_world()
		var mob = w.spawn("stone_guard")
		mob.hp = 10000
		w.rebuild_index()
		w.apply_element(mob,pair[0],20)
		w.apply_element(mob,pair[1],20)
		expect(w.reactions.get(pair[2],0) == 1, "Element reaction: " + pair[2])
	for stage_index in range(1,5):
		var w = new_world()
		w.stage = stage_index
		w.start_sector()
		var boss = w.spawn("boss"+str(stage_index-1),false,true)
		w.hit(boss,100000,"fire_talisman")
		expect(w.bosses == 1, "Boss defeat counted: " + str(stage_index))
		expect(w.phase == ("finished" if stage_index == 4 else "relic"), "Stage transition: " + str(stage_index))
		if stage_index<4:
			w.choose_relic(0)
			expect(w.phase=="route", "Boss reward leads to route choice: "+str(stage_index))
	a = new_world()
	for i in range(900):
		a.update(1.0/60,Vector2.from_angle(i*0.01))
		if a.phase == "upgrade": a.choose(0)
		if a.phase == "finished": break
	var restored = RunWorld.new()
	var raw = bytes_to_var(var_to_bytes(a.snapshot()))
	expect(restored.restore(raw), "Native typed snapshot restores")
	if restored.phase == "active" and not restored.player.is_empty():
		for i in range(200):
			a.update(1.0/60,Vector2.LEFT)
			restored.update(1.0/60,Vector2.LEFT)
		expect(a.snapshot() == restored.snapshot(), "Restored simulation continues identically")
	Save.directory = "user://tests/"
	Save.profile = Save.defaults()
	expect(Save.save_run(a), "Atomic run save writes")
	expect(Save.read_run() == a.snapshot(), "On-disk run snapshot preserves exact types and floats")
	a.finish(true)
	Save.settle(a)
	var embers = Save.profile.embers
	expect(Save.profile.history[0].reward_total==embers,"Settlement display includes newly earned achievement rewards")
	Save.settle(a)
	expect(Save.profile.embers == embers, "Settlement is idempotent")
	expect(Save.read_run().is_empty(), "Settled run cannot resume")
	var legacy = {"version":2,"embers":321,"camp":{"vigor":3,"focus":2,"stride":1,"fortune":0},"stats":{"kills":901,"bosses":4,"shrines":2,"wins":1},"achievements":["victory"]}
	var legacy_file = FileAccess.open("user://tests/legacy-profile.json",FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy))
	legacy_file.close()
	var before_legacy = FileAccess.get_file_as_bytes("user://tests/legacy-profile.json")
	expect(Save.import_legacy_profile("user://tests/legacy-profile.json"), "Legacy camp imports")
	expect(Save.profile.embers == 321 and Save.profile.camp.vigor == 3 and Save.profile.bosses == 4, "Legacy camp preserves progression")
	expect(FileAccess.get_file_as_bytes("user://tests/legacy-profile.json") == before_legacy, "Import leaves original save untouched")
	Save.load_profile()
	expect(Save.profile.embers == 321 and Save.profile.bosses == 4 and Save.profile.victories == 1, "Profile numbers survive JSON reload")
	Save.profile.embers = 345
	Save.save_profile()
	var corrupt = FileAccess.open("user://tests/profile.json",FileAccess.WRITE)
	corrupt.store_string('{"version":3,"embers":"invalid"}')
	corrupt.close()
	Save.load_profile()
	expect(Save.profile.embers == 321, "Malformed primary profile falls back to valid backup")
	expect(not RunWorld.new().restore({"version": 3}), "Reject incomplete snapshot")
	var safe_world = new_world()
	safe_world.spawn("stone_guard")
	var safe_raw = safe_world.snapshot()
	for mutation in ["player_hp","enemy_kind","enemy_radius","enemy_flag","weapon_level","phase_choice","random_state","drop_value"]:
		var bad = safe_raw.duplicate(true)
		match mutation:
			"player_hp": bad.player.hp = "broken"
			"enemy_kind": bad.mobs[0].kind = "missing"
			"enemy_radius": bad.mobs[0].radius = NAN
			"enemy_flag": bad.mobs[0].boss = "no"
			"weapon_level": bad.weapons.fire_talisman = "five"
			"phase_choice": bad.phase = "upgrade"; bad.choices = ["w:missing"]
			"random_state": bad.rng_state = "not-an-integer"
			"drop_value": bad.drops = [{"x":800.0,"y":500.0,"kind":"coin","value":{},"age":0.0}]
		var unchanged = safe_world.snapshot()
		expect(not safe_world.restore(bad) and unchanged==safe_world.snapshot(),"Reject malformed nested state without mutation: "+mutation)
	Save.clear_run()
	Save.save_run(safe_world)
	safe_world.time = 2.0
	Save.save_run(safe_world)
	var broken_run = FileAccess.open("user://tests/expedition.save",FileAccess.WRITE)
	var malformed = safe_raw.duplicate(true)
	malformed.mobs[0].radius = "broken"
	broken_run.store_var(malformed)
	broken_run.close()
	expect(Save.read_run()==safe_raw,"Semantically damaged run falls back to valid backup")
	for skill in Content.data.evolutions:
		var w = new_world()
		w.weapons = {skill:5}
		w.passives = {Content.data.evolutions[skill].passive:1}
		w.pending_levels = 1
		w.roll_choices()
		expect("e:"+skill in w.choices,"Evolution offered: "+skill)
		w.choose(w.choices.find("e:"+skill))
		var mob = w.spawn("stone_guard")
		mob.x = 885.0; mob.y = 500.0; mob.hp = 100000.0; mob.max_hp = mob.hp
		w.rebuild_index()
		w.cast(skill)
		expect(RunWorld.new().restore(w.snapshot()),"Evolution state resumes: "+skill)
		if skill=="thunder_mark":
			for i in range(6):
				var next = w.spawn("stone_guard")
				next.x = 930.0+i*25; next.y = 500.0; next.hp = 100000.0; next.max_hp = next.hp
			w.rebuild_index()
			w.bolt_hit(w.bolts[0],mob)
			expect(w.damage_by_skill.thunder_mark>100,"Thunder evolution chains through nearby targets")
		elif skill=="piercing_spike": expect(w.bolts.size()==5,"Sword evolution creates five piercing blades")
		elif skill=="frost_sand": expect(w.bolts.size()==12,"Frost evolution creates a full radial volley")
		elif skill=="poison_mist": expect(w.zones[0].life==4.0 and w.zones[0].radius>100,"Poison evolution leaves a wider lasting pool")
		elif skill=="ward_shard": expect(w.damage_by_skill.get(skill,0)>0,"Ward evolution attacks with six orbital shards")
	var fragile = RunWorld.new()
	fragile.begin({"contract":"fragile","seed":421})
	expect(is_equal_approx(fragile.player.max_hp,77.0) and is_equal_approx(fragile.stat("damage"),1.25),"Fragile contract trades health for damage")
	var silence = RunWorld.new()
	silence.begin({"contract":"silence","seed":421})
	silence.player.hp = 40.0
	silence.heal(100)
	expect(silence.player.hp==40,"Silence contract forbids healing")
	var swarm = RunWorld.new()
	swarm.begin({"contract":"swarm","seed":421})
	swarm.spawn_timer = 0
	swarm.director(0)
	expect(swarm.mobs.size()==2,"Swarm contract increases opening wave")
	var daily_a = RunWorld.new()
	var daily_b = RunWorld.new()
	daily_a.begin({"mode":"daily","seed":20261013,"camp":{"vigor":8,"focus":8}})
	daily_b.begin({"mode":"daily","seed":20261013})
	expect(daily_a.camp.is_empty() and daily_a.player==daily_b.player and daily_a.rng.state==daily_b.rng.state,"Daily challenge ignores camp and keeps identical seeded start")
	var endless = new_world()
	endless.mode = "endless"; endless.stage = 4; endless.start_sector()
	endless.hit(endless.spawn("boss3",false,true),100000,"fire_talisman")
	endless.choose_relic(0)
	endless.take_route(endless.routes.filter(func(key): return endless.route_available(key))[0])
	expect(endless.stage==5 and not endless.victory,"Endless mode continues past the fourth boss")
	var relic = new_world()
	relic.relics = ["old_wick","wine","red_thread","fox_tooth"]
	relic.player.invulnerable = 0; relic.player.hp = 5.0
	relic.hurt(100)
	expect(relic.player.hp==1 and relic.resurrected and relic.charge==15,"Wick saves the player once and wine charges the pulse")
	expect(is_equal_approx(relic.stat("damage"),1.35),"Red thread is active below half health")
	relic.dash(Vector2.RIGHT)
	expect(relic.player.fox_ready,"Fox tooth arms the next cast after a dash")
	relic.relics = ["crow_feather","silver","map","bamboo"]
	expect(is_equal_approx(relic.stat("crit"),0.17) and is_equal_approx(relic.stat("haste"),0.12) and relic.stat("speed")>1,"Feather, silver and map alter their actual stats")
	var before_hp = relic.player.hp
	relic.gain_xp(100)
	expect(relic.player.hp>before_hp,"Bamboo heals on level gain")
	relic.relics = ["broken_coin","prayer","drum","green_lamp"]
	relic.drops = [{"x":relic.player.x,"y":relic.player.y,"kind":"coin","value":1,"age":0.0}]
	before_hp = relic.player.hp; relic.update_drops(0)
	expect(relic.player.hp==before_hp+1,"Broken coin heals on coin pickup")
	relic.kills = 29; before_hp = relic.player.hp
	relic.hit(relic.spawn("paper_spirit"),100000,"fire_talisman")
	expect(relic.player.hp==before_hp+5,"Prayer heals every thirtieth kill")
	relic.make_bolt(Vector2(200,200),Vector2.ZERO,10,"enemy",true)
	relic.charge = 30; relic.pulse()
	expect(relic.bolts.is_empty(),"Drum clears distant hostile bullets")
	relic.player.dash_time = 0
	relic.shrine = {"x":relic.player.x,"y":relic.player.y,"progress":2.55,"life":24.0}
	relic.update(0.03,Vector2.ZERO,true)
	expect(relic.shrines==1 and relic.coins>=34,"Green lamp doubles ritual progress and adds coins")
	Save.profile = Save.defaults()
	Save.directory = "user://tests/"
	daily_a.finish(true)
	Save.settle(daily_a)
	expect(Save.profile.records.has("daily:20261013"),"Daily best record persists separately from recent history")
	Save.load_profile()
	expect(Save.profile.records.has("daily:20261013"),"Daily record survives profile reload")
	var obstruction = FileAccess.open("user://tests/write-blocker",FileAccess.WRITE)
	obstruction.store_string("Test obstruction"); obstruction.close()
	Save.directory = "user://tests/write-blocker/"
	Save.profile.embers = 100
	var before_profile = Save.profile.duplicate(true)
	expect(not Save.buy_camp("vigor") and Save.profile==before_profile,"Failed camp write rolls back currency and upgrade")
	var unsettled = new_world(); unsettled.finish(true)
	expect(Save.settle(unsettled).has("save_error") and Save.profile==before_profile,"Failed settlement rolls back history, rewards and records")
	Save.directory = "user://tests/"
	var ink_base = new_world()
	var ink_boost = new_world()
	ink_base.charge = 0; ink_boost.charge = 0
	ink_boost.passives.ink = 3
	ink_base.hit(ink_base.spawn("paper_spirit"),100000,"fire_talisman")
	ink_boost.hit(ink_boost.spawn("paper_spirit"),100000,"fire_talisman")
	expect(ink_boost.charge>ink_base.charge and is_equal_approx(ink_boost.charge,1.0/0.7),"Ink reduces required kills rather than slowing pulse charge")
	var aimed = new_world()
	var archer = aimed.spawn("archer")
	archer.x = 400.0; archer.y = 500.0; archer.cooldown = 0.0
	aimed.player.x = 800.0; aimed.player.y = 500.0
	aimed.update_mobs(0.01)
	aimed.player.y = 300.0
	aimed.update_mobs(0.5)
	expect(aimed.bolts.size()==1 and absf(aimed.bolts[0].vy)<0.01 and aimed.bolts[0].skin=="arrow","Archer shoots along the warned direction after player moves")
	var frozen = new_world()
	var guard = frozen.spawn("stone_guard")
	guard.x = frozen.player.x; guard.y = frozen.player.y
	guard.windup = 0.1; guard.stun = 0.4
	frozen.player.invulnerable = 0
	var untouched_hp = frozen.player.hp
	frozen.update_mobs(0.05)
	expect(is_equal_approx(guard.windup,0.1) and frozen.zones.is_empty() and frozen.player.hp==untouched_hp,"Stun pauses a windup and prevents contact damage")
	var report = {"checks":checks,"failures":failures,"passed":failures.is_empty()}
	DirAccess.make_dir_recursive_absolute("res://test-output")
	var file = FileAccess.open("res://test-output/world-tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print(JSON.stringify(report))
	get_tree().quit(0 if failures.is_empty() else 1)
