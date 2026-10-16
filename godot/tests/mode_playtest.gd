extends "res://tests/playtest.gd"

func run() -> void:
	await get_tree().process_frame
	var cases = [
		{"character":"keeper","difficulty":1,"contract":"swarm","seed":911},
		{"character":"swordswoman","difficulty":2,"contract":"fragile","seed":912},
		{"character":"alchemist","difficulty":1,"contract":"silence","seed":913},
		{"character":"keeper","difficulty":3,"seed":914},
		{"character":"keeper","mode":"daily","seed":20261013},
		{"character":"keeper","mode":"daily","seed":20261013},
		{"character":"swordswoman","mode":"endless","seed":915,"target_stage":6},
	]
	for options in cases:
		var world = RunWorld.new()
		options["choose_oath"] = true
		world.begin(options)
		var started = Time.get_ticks_msec()
		var frames = 0
		while world.phase!="finished" and world.time<1300 and world.stage<options.get("target_stage",10000):
			if world.phase=="oath": world.choose_oath(1); continue
			if world.phase in ["relic","relic_replace"]: world.choose_relic(0 if world.phase=="relic" else -1); continue
			if world.phase=="upgrade":
				var best = 0
				for i in range(world.choices.size()):
					if choice_score(world,world.choices[i])>choice_score(world,world.choices[best]): best = i
				world.choose(best)
				continue
			if world.phase=="route":
				var available = world.routes.filter(func(key): return world.route_available(key))
				var pick = available[0]
				for key in available:
					if key in ["tea","spring"] and world.player.hp<world.player.max_hp*0.75: pick = key
				world.take_route(pick)
				continue
			var move = bot_move(world)
			var nearest = world.nearest(world.pos(world.player))
			if not nearest.is_empty() and world.pos(nearest).distance_to(world.pos(world.player))<105: world.dash(move)
			var close_boss = world.mobs.any(func(mob): return mob.boss and mob.hp>0 and world.pos(mob).distance_to(world.pos(world.player))<250)
			if world.charge>=30 and (close_boss or world.near(world.pos(world.player),240).size()>=4): world.pulse()
			world.update(1.0/60,move,true)
			world.events.clear()
			frames += 1
		var result = world.result()
		result["audit_stopped"] = world.phase!="finished"
		result["simulation_frames"] = frames
		result["simulation_ms"] = Time.get_ticks_msec()-started
		result["remaining_hp"] = world.player.hp
		reports.append(result)
		print(JSON.stringify(result))
	var daily_a = reports[4].duplicate(true)
	var daily_b = reports[5].duplicate(true)
	for key in ["run_id","date","simulation_ms"]:
		daily_a.erase(key); daily_b.erase(key)
	var completed = reports.all(func(item): return not item.audit_stopped or (item.mode=="endless" and item.stage>=6))
	var report = {"cases":reports,"daily_repeat_identical":daily_a==daily_b,"no_unfinished_campaign":completed,"scope":"Bot simulation with natural combat, leveling, oaths, relics and routes; harder contracts may end in defeat.","passed":completed and daily_a==daily_b and reports[6].stage>=6}
	var file = FileAccess.open("res://test-output/mode-playtest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print("MODE_PLAYTEST ",JSON.stringify({"passed":report.passed,"daily_repeat_identical":report.daily_repeat_identical,"endless_stage":reports[6].stage}))
	get_tree().quit(0 if report.passed else 1)
