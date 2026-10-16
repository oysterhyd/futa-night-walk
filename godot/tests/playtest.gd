extends Node

var reports: Array = []

func _ready() -> void:
	call_deferred("run")

func choice_score(world: RunWorld, choice: String) -> float:
	var parts = choice.split(":")
	var key = parts[1]
	if parts[0] == "e": return 100
	if parts[0] == "w":
		if world.weapons.has(key): return 30 + world.weapons[key] * 2
		return {"thunder_mark":29,"piercing_spike":28,"frost_sand":27,"shock_ring":26,"ward_shard":24,"healing_mark":23,"poison_mist":22}.get(key,15)
	if parts[0] == "p":
		for skill in world.weapons:
			if Content.data.evolutions.has(skill) and Content.data.evolutions[skill].passive == key: return 29
		return {"cinnabar":25,"bell":24,"armor":23,"jade":22,"mirror":21,"boots":20}.get(key,12)
	return 5

func bot_move(world: RunWorld) -> Vector2:
	var p = world.pos(world.player)
	var target = Vector2(800,480)
	var best_drop = INF
	for drop in world.drops:
		var distance = world.pos(drop).distance_squared_to(p)
		if distance < best_drop:
			best_drop = distance
			target = world.pos(drop)
	if not world.shrine.is_empty() and world.player.hp < world.player.max_hp*0.7: target = world.pos(world.shrine)
	var bosses = world.mobs.filter(func(mob): return mob.boss and mob.hp>0)
	if not bosses.is_empty():
		var away = (p-world.pos(bosses[0])).normalized()
		target = world.pos(bosses[0])+(away if away.length_squared()>0 else Vector2.RIGHT)*220
	var best = Vector2.ZERO
	var best_score = -INF
	for i in range(17):
		var direction = Vector2.ZERO if i == 16 else Vector2.from_angle(TAU*i/16)
		var future = p+direction*105
		var score = -future.distance_to(target)*0.035
		if not Rect2(170,225,1260,505).has_point(future): score -= 150
		for mob in world.mobs:
			var distance = future.distance_to(world.pos(mob)) - mob.radius
			if distance < 230: score -= 8000/pow(maxf(10,distance),2)
			if mob.charging > 0: score -= 15000/pow(maxf(10,future.distance_to(world.pos(mob)+Vector2(mob.dx,mob.dy)*150)-mob.radius),2)
		for bolt in world.bolts:
			if not bolt.hostile: continue
			var ahead = world.pos(bolt)+Vector2(bolt.vx,bolt.vy)*0.35
			var distance = Geometry2D.get_closest_point_to_segment(future,world.pos(bolt),ahead).distance_to(future)
			if distance < 80: score -= 2500/pow(maxf(8,distance),2)
		for zone in world.zones:
			if zone.hostile and future.distance_to(world.pos(zone)) < zone.radius+30: score -= 90
		for obstacle in world.obstacles:
			if future.distance_to(world.pos(obstacle)) < obstacle.radius+35: score -= 100
		if score > best_score:
			best_score = score
			best = direction
	return best

func run() -> void:
	await get_tree().process_frame
	for character in ["keeper","swordswoman","alchemist"]:
		for seed_value in [1441,2083]:
			var world = RunWorld.new()
			world.begin({"character":character,"seed":seed_value,"choose_oath":true})
			var started = Time.get_ticks_msec()
			var frames = 0
			while world.phase != "finished" and world.time < 900:
				if world.phase=="oath":
					world.choose_oath(0 if character=="alchemist" else (2 if character=="swordswoman" else 1))
					continue
				if world.phase in ["relic","relic_replace"]:
					world.choose_relic(0 if world.phase=="relic" else -1)
					continue
				if world.phase == "upgrade":
					var best = 0
					for i in range(world.choices.size()):
						if choice_score(world,world.choices[i]) > choice_score(world,world.choices[best]): best = i
					world.choose(best)
					continue
				if world.phase == "route":
					var pick = world.routes[0]
					for key in world.routes:
						if key in ["tea","spring"] and world.player.hp < world.player.max_hp*0.65: pick = key
						elif key == "relic" and world.player.hp >= world.player.max_hp*0.65: pick = key
						if not world.route_available(pick): pick = key
					world.take_route(pick)
					continue
				var move = bot_move(world)
				var nearest = world.nearest(world.pos(world.player))
				if not nearest.is_empty() and world.pos(nearest).distance_to(world.pos(world.player)) < 105: world.dash(move)
				var close_boss = world.mobs.any(func(mob): return mob.boss and mob.hp>0 and world.pos(mob).distance_to(world.pos(world.player))<250)
				if world.charge>=30 and (close_boss or world.near(world.pos(world.player),240).size()>=4): world.pulse()
				world.update(1.0/60,move,true)
				world.events.clear()
				frames += 1
			var result = world.result()
			result["simulation_ms"] = Time.get_ticks_msec()-started
			result["simulation_frames"] = frames
			result["remaining_hp"] = world.player.hp
			reports.append(result)
			print(JSON.stringify(result))
	var file = FileAccess.open("res://test-output/playtest.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(reports,"\t"))
	file.close()
	get_tree().quit()
