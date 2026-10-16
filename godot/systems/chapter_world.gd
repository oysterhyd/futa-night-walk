class_name ChapterWorld
extends RunWorld

const C = preload("res://content/chapter_content.gd")
const CHAPTER_KEYS = ["rooms","room_id","room_bounds","decorations","gear","skill","gear_rank","skill_rank","gear_mod","skill_mod","sigils","attributes","skill_cd","attack_cd","attack_buffer","attack_count","attack_windup","attack_aim","aim","dash_charges","dash_recharge","counter_time","echo_ready","coin_ready","shield","shadow_time","wind_time","wind_stacks","proc_timers","wave_index","wave_count","room_age","clear_delay","offer_kind","offer_title","offer_subtitle","shop_bought","event_id","shrine_started","shrine_round","extra_elite","curse_damage","pending_sigil","pending_relic"]
var rooms: Array = []
var room_id = 0
var room_bounds = Rect2(120,180,1360,590)
var decorations: Array = []
var gear = "seal"
var skill = "pulse"
var gear_rank = 1
var skill_rank = 1
var gear_mod = -1
var skill_mod = -1
var sigils: Dictionary = {}
var attributes: Dictionary = {}
var skill_cd = 0.0
var attack_cd = 0.0
var attack_buffer = 0.0
var attack_count = 0
var attack_windup = 0.0
var attack_aim = Vector2.RIGHT
var aim = Vector2.RIGHT
var attack_held = false
var dash_charges = 2
var dash_recharge = 0.0
var counter_time = 0.0
var echo_ready = false
var coin_ready = false
var shield = 0.0
var shadow_time = 0.0
var wind_time = 0.0
var wind_stacks = 0
var proc_timers: Dictionary = {}
var wave_index = 0
var wave_count = 0
var room_age = 0.0
var clear_delay = 0.0
var offer_kind = ""
var offer_title = ""
var offer_subtitle = ""
var shop_bought: Array = []
var event_id = 0
var shrine_started = false
var shrine_round = 0
var extra_elite = false
var curse_damage = false
var pending_sigil = ""
var pending_relic = ""

func begin(options: Dictionary = {}) -> void:
	character = options.get("character","keeper")
	mode = options.get("mode","campaign")
	difficulty = int(options.get("difficulty",0))
	contract = options.get("contract","none")
	camp = options.get("camp",{}).duplicate(true)
	if mode == "daily": character = "keeper"; difficulty = 0; contract = "none"; camp = {}
	if options.has("seed"): rng.seed = int(options.seed)
	else: rng.randomize()
	run_id = "chapter-%s-%s" % [Time.get_ticks_usec(),rng.randi()]
	var hero = Content.data.characters[character]
	var health = float(hero.hp) + mini(int(camp.get("vigor",0)),8)*3
	if contract == "fragile": health *= 0.7
	player = {"x":800.0,"y":480.0,"hp":health,"max_hp":health,"radius":15.0,"facing":1.0,"invulnerable":1.0,"dash_time":0.0,"dash_cd":0.0,"dash_dx":0.0,"dash_dy":1.0,"moving":false,"fox_ready":false,"cast":0.0}
	if character == "swordswoman": gear = "sword"; skill = "binding"
	elif character == "alchemist": gear = "needle"; skill = "blast"
	weapons = {C.GEAR[gear].source:1}
	coins = 25
	rerolls = 2 + mini(int(camp.get("fortune",0)),8)
	_make_map()
	event_id = rng.randi_range(0,C.EVENT_TEXT.size()-1)
	enter_room(0)
	if options.get("choose_oath",true):
		phase = "oath"
		choices = ["o:cinder","o:tide","o:script","o:none"]
		offer_title = "出发誓愿"
		offer_subtitle = "选定本局偏向，也可以不立誓。"

func _shuffle(items: Array) -> Array:
	items = items.duplicate()
	for i in range(items.size()-1,0,-1):
		var j = rng.randi_range(0,i)
		var value = items[i]; items[i] = items[j]; items[j] = value
	return items

func _make_map() -> void:
	var definitions = C.MAP.duplicate(true)
	var free: Array=[]
	for x in range(1,6):
		for y in [-1,1]: free.append(Vector2(x,y))
	for id in [7,8,9,10,11,12]:
		var options=free.filter(func(p): return (id==7 and p.x==1) or (id==8 and p.x==2) or (id==9 and p.x<=3) or (id==10 and p.x>=2 and p.x<=4) or (id in [11,12] and p.x>=3))
		var selected=options[rng.randi_range(0,options.size()-1)]
		free.erase(selected); definitions[id][0]=int(selected.x); definitions[id][1]=int(selected.y)
	for definition in definitions:
		rooms.append({"id":rooms.size(),"gx":definition[0],"gy":definition[1],"type":definition[2],"rank":definition[3],"layout":rng.randi_range(0,3),"visited":false,"cleared":definition[2] not in ["combat","elite","boss"],"claimed":false})

func room() -> Dictionary:
	return rooms[room_id]

func doors() -> Array:
	var found: Array = []
	for other in rooms:
		var offset = Vector2(other.gx-room().gx,other.gy-room().gy)
		if absf(offset.x)+absf(offset.y) != 1: continue
		if other.type=="secret" and not secret_revealed(): continue
		var point = room_bounds.get_center()+offset*room_bounds.size*0.5
		found.append({"id":other.id,"direction":offset,"position":point,"open":room().cleared and clear_delay<=0,"name":display_room_name(other),"reward":"已清理 · 可返回" if other.visited and other.claimed else room_reward(other)})
	return found

func secret_revealed() -> bool:
	return kills>=35 or "map" in relics

func enter_room(target: int, from_direction: Vector2 = Vector2.ZERO) -> bool:
	if target < 0 or target >= rooms.size() or phase != "active": return false
	if not rooms.is_empty() and room().visited and (not room().cleared or clear_delay>0): return false
	room_id = target
	room_age = 0; clear_delay = 0; wave_index = 0; shrine_started = false; shrine_round = 0
	mobs.clear(); bolts.clear(); zones.clear(); drops.clear(); shrine.clear(); hazards.clear(); events.clear()
	attack_windup = 0; shadow_time = 0
	_configure_room()
	var p = room_bounds.get_center()-from_direction*(room_bounds.size*0.5-Vector2(105,105))
	set_pos(player,p)
	player.invulnerable = 0.8
	player.cast = 0
	var first_visit = not room().visited
	room().visited = true
	wave_count = 2 if room().rank <= 2 else 3
	if first_visit and room().type in ["combat","elite"]: _spawn_wave()
	if first_visit and room().type == "boss": _spawn_boss()
	if room().type == "shrine" and not room().claimed:
		shrine = {"x":room_bounds.get_center().x,"y":room_bounds.get_center().y,"progress":0.0,"life":9999.0}
	emit("room",{"text":room_name(),"room_id":room_id})
	return true

func room_name() -> String:
	return display_room_name(room())

func display_room_name(target: Dictionary) -> String:
	if target.type=="combat": return ["","挂灯长巷","纸扎后院","断桥街口","旧市广场"][target.rank]
	return C.ROOM_TYPES[target.type].name

func room_reward(target: Dictionary) -> String:
	return C.ROOM_TYPES[target.type].reward

func _configure_room() -> void:
	var large = room().layout in [1,3] and room().type in ["combat","elite","boss"]
	room_bounds = Rect2(120,180,1720 if large else 1360,850 if large else 590)
	obstacles.clear(); decorations.clear()
	var center = room_bounds.get_center()
	var safe = room().type not in ["combat","elite","boss"]
	if not safe:
		var patterns = [[Vector2(-320,-130),Vector2(320,140)],[Vector2(-370,80),Vector2(330,-120),Vector2(60,240)],[Vector2(-260,0),Vector2(260,0)],[Vector2(-420,-190),Vector2(420,190),Vector2(-160,230)]]
		for offset in patterns[room().layout]:
			var p = center+offset
			obstacles.append({"x":p.x,"y":p.y,"radius":38.0})
			var sprite=10 if room().type=="boss" else [0,9,10,2][maxi(0,room().rank-1)%4]
			decorations.append({"x":p.x,"y":p.y,"sprite":sprite,"size":145.0})
	var sprite = {"gear":5,"skill":7,"shop":0,"event":4,"shrine":6,"rest":4,"secret":7}.get(room().type,-1)
	if sprite >= 0: decorations.append({"x":center.x,"y":center.y-35,"sprite":sprite,"size":200.0})
	if room().type=="entry":
		for side in [-1,1]: decorations.append({"x":center.x+side*260,"y":center.y-100,"sprite":11,"size":180.0})
	if room().layout == 3:
		hazards = [{"x":center.x-200,"y":center.y-140,"radius":95.0,"kind":"water"}]

func set_controls(direction: Vector2, held: bool) -> void:
	if direction.length_squared() > 0.01: aim = direction.normalized()
	attack_held = held

func request_attack() -> void:
	if phase=="active" and player.hp>0: attack_buffer=0.12

func calculate_stats() -> Dictionary:
	var damage = 1.0 + attributes.get("power",0)*0.1 + mini(int(camp.get("focus",0)),8)*0.02
	if contract == "fragile": damage *= 1.25
	if "red_thread" in relics and not player.is_empty() and player.hp < player.max_hp*0.5: damage *= 1.3
	return {"damage":damage,"haste":minf(0.4,attributes.get("haste",0)*0.08),"attack_speed":minf(0.65,attributes.get("speed",0)*0.08),"speed":1.0+mini(int(camp.get("stride",0)),8)*0.015+(0.08 if "map" in relics else 0)+sigils.get("wind",0)*0.08*wind_stacks,"crit":minf(0.65,0.05+sigils.get("precision",0)*0.08),"magnet":1.0,"armor":0.0,"burn":1.6 if character=="alchemist" else 1.0,"xp":1.0,"regen":0.0,"dash":0.25 if character=="swordswoman" else 0.0,"pulse":1.15 if "drum" in relics else 1.0}

func stat(key: String) -> float:
	var value=float((step_stats if inside_step else calculate_stats())[key])
	return value*(1+sigils.get("focus",0)*0.08) if key=="pulse" else value

func dash(move: Vector2) -> bool:
	if phase != "active" or dash_charges <= 0 or player.hp <= 0: return false
	if move.length_squared() < 0.01: move = aim
	move = move.normalized()
	dash_charges -= 1
	if dash_recharge <= 0: dash_recharge = _dash_interval()
	player.dash_dx = move.x; player.dash_dy = move.y
	player.dash_time = 0.2; player.invulnerable = maxf(player.invulnerable,0.22)
	attack_windup = 0
	counter_time = 2.0
	emit("dash",{"x":player.x,"y":player.y})
	return true

func _dash_interval() -> float:
	return 3.0*(0.75 if character=="swordswoman" else 1.0)*(0.8 if oath=="tide" else 1.0)

func move_entity(entity: Dictionary, delta: Vector2) -> void:
	var p = pos(entity)+delta
	var radius = float(entity.radius)
	p = p.clamp(room_bounds.position+Vector2.ONE*radius,room_bounds.end-Vector2.ONE*radius)
	for obstacle in obstacles:
		var away = p-pos(obstacle)
		if away.length() < radius+obstacle.radius:
			p = pos(obstacle)+(away.normalized() if away.length()>0.01 else Vector2.RIGHT)*(radius+obstacle.radius)
	set_pos(entity,p.clamp(room_bounds.position+Vector2.ONE*radius,room_bounds.end-Vector2.ONE*radius))

func navigation_direction(entity: Dictionary, movement: Vector2) -> Vector2:
	if movement.length_squared()<0.001: return Vector2.ZERO
	var heading=movement.normalized()
	var p=pos(entity)
	var nearest=INF
	var blocker: Dictionary={}
	for obstacle in obstacles:
		var offset=pos(obstacle)-p
		var clearance=entity.radius+obstacle.radius+18
		if offset.dot(heading)<=0 or offset.length()>clearance+130: continue
		var projected=Geometry2D.get_closest_point_to_segment(pos(obstacle),p,p+heading*150)
		if projected.distance_to(pos(obstacle))<clearance and offset.length_squared()<nearest:
			nearest=offset.length_squared(); blocker=obstacle
	if not blocker.is_empty():
		var cross=heading.cross(pos(blocker)-p)
		var side=-signf(cross) if absf(cross)>0.01 else (1.0 if int(entity.get("uid",0))%2==0 else -1.0)
		heading=(heading*0.45+Vector2(-heading.y,heading.x)*side*0.9).normalized()
	return heading*minf(1,movement.length())

func _attack() -> void:
	attack_count += 1
	var item = C.GEAR[gear]
	var amount = item.damage*stat("damage")*(1.0+0.2*(gear_rank-1))
	if "fox_mirror" in relics and skill!="shadow": amount*=1.1
	var boosted = counter_time > 0
	if boosted: amount *= 1.0+0.3*sigils.get("counter",0)+(0.5 if "fox_tooth" in relics else 0)+(0.15 if character=="swordswoman" else 0)
	if echo_ready: amount *= 1.0+0.35*sigils.get("echo",0)
	if coin_ready and "broken_coin" in relics: amount *= 1.25
	counter_time = 0; echo_ready = false; coin_ready = false
	var critical = rng.randf()<stat("crit")
	if critical: amount *= 1.8
	var p = pos(player)
	player.cast = 0.2
	if gear in ["sword","hammer"]:
		if gear=="sword" and attack_count%3==0: amount *= 1.5
		var reach = item.reach*(1.35 if gear=="sword" and gear_mod==1 else 1.0)*(1.0+0.1*sigils.get("counter",0) if boosted else 1.0)
		if gear=="hammer" and gear_mod==0: reach = 220
		reach*=1+sigils.get("reach",0)*0.08
		for mob in near(p,reach+45):
			var toward = pos(mob)-p
			if toward.length() <= reach+mob.radius and (gear=="hammer" and gear_mod==0 or toward.normalized().dot(attack_aim)>-0.15):
				if gear=="hammer": _control(mob,0.4)
				if gear=="hammer" and gear_mod==1: mob["vulnerable"] = 3.0
				_primary_hit(mob,amount,item.source,critical)
		emit("slash",{"x":p.x,"y":p.y,"angle":attack_aim.angle(),"radius":reach,"heavy":gear=="hammer","source":item.source})
		if gear=="sword" and gear_mod==0 and attack_count%3==0: _projectile(p,attack_aim,amount*0.8,item.source,8,critical)
	else:
		var count = 1
		var pierce = 0
		if gear=="seal" and gear_mod==0: count=3; amount*=0.55
		if gear=="seal" and gear_mod==1: pierce=2; amount*=1.15
		if gear=="needle" and gear_mod==0: count=2; amount*=0.7
		if gear=="needle" and gear_mod==1: pierce=1
		if gear=="wheel": pierce=3
		if gear=="wheel" and gear_mod==0: count=2; amount*=0.7
		if gear=="sand": count=5 if gear_mod==1 else 3
		if oath=="script": count+=1; amount*=0.8
		for i in range(count): _projectile(p,attack_aim.rotated((i-(count-1)*0.5)*0.14),amount,item.source,pierce,critical)
	if sigils.get("cleave",0)>0 and attack_count%4==0:
		for mob in near(p,160): hit(mob,18*sigils.cleave*stat("damage"),"echo_mark",35)
		emit("ring",{"x":p.x,"y":p.y,"radius":160,"source":"echo_mark"})
	if shadow_time > 0:
		var count = (3 if skill_mod==0 else 2)+(1 if "fox_mirror" in relics else 0)
		for i in range(count):
			var offset = attack_aim.orthogonal()*(i-(count-1)*0.5)*70-attack_aim*35
			_projectile(p+offset,attack_aim,amount*0.35*(1.0+0.2*(skill_rank-1))*stat("pulse"),"shadow_twin",1,false,false)
	emit("attack_art",{"x":p.x,"y":p.y,"source":item.source,"gear":gear,"angle":attack_aim.angle(),"combo":attack_count%3,"critical":critical})
	emit("cast",{"x":p.x,"y":p.y,"source":item.source})

func _projectile(p: Vector2, direction: Vector2, amount: float, source: String, pierce: int, critical: bool, primary: bool = true) -> void:
	if primary: pierce+=sigils.get("pierce",0)
	make_bolt(p,direction*(480 if source=="frost_sand" else 660),amount,source,false,pierce)
	bolts.back()["critical"] = critical
	bolts.back()["primary"] = primary
	var reach=C.GEAR[gear].reach
	if source=="shadow_twin": reach=maxf(360,reach)
	elif source=="piercing_spike" and gear=="sword": reach=520
	if primary: reach*=1+sigils.get("reach",0)*0.08
	bolts.back().life = reach/(480.0 if source=="frost_sand" else 660.0)*(1.25 if gear=="sand" and gear_mod==1 else 1.0)

func _primary_hit(mob: Dictionary, amount: float, source: String, critical: bool) -> void:
	if gear=="sand" and gear_mod==0 and mob.slow>0: amount*=1.35
	apply_element(mob,source,amount)
	if sigils.get("fire",0)>0:
		mob.burn = maxf(mob.burn,3.0)
		mob["sigil_burn_dps"]=4.0*sigils.fire*stat("damage")*stat("burn")
		mob.burn_dps = mob.get("innate_burn_dps",0.0)+mob.sigil_burn_dps
	if source=="thunder_mark" and gear_mod==1 and _proc("wheel",0.4):
		var targets = near(pos(mob),190).filter(func(other): return other.uid!=mob.uid)
		for other in targets.slice(0,2):
			hit(other,amount*0.45,"shock_ring")
			emit("chain",{"x":mob.x,"y":mob.y,"tx":other.x,"ty":other.y,"source":source})
	if mob.burn>0 and sigils.get("ember",0)>0 and _proc("ember",0.5): skill_cd=maxf(0,skill_cd-0.2*sigils.ember)
	if mob.elite or mob.boss:
		if "silver" in relics and _proc("silver",0.8): skill_cd=maxf(0,skill_cd-0.4)
		if sigils.get("leech",0)>0 and _proc("leech",1.0): heal(sigils.leech)
	hit(mob,amount,source,45 if gear in ["hammer","sword"] else 12,critical)

func _proc(key: String, interval: float) -> bool:
	if proc_timers.get(key,0)>0: return false
	proc_timers[key] = interval
	return true

func pulse() -> bool:
	if phase != "active" or skill_cd>0 or player.hp<=0: return false
	var item = C.SKILLS[skill]
	skill_cd = item.cooldown*(1.0-stat("haste"))
	echo_ready = true
	player.cast = 0.32
	var p = pos(player)
	var target = (p+aim*260).clamp(room_bounds.position+Vector2(60,60),room_bounds.end-Vector2(60,60))
	var scale_value = stat("damage")*(1.0+0.2*(skill_rank-1))*stat("pulse")
	match skill:
		"pulse":
			var radius = 337.5 if skill_mod==0 else 270.0
			_area(p,radius,75*scale_value,"pulse",1.5 if skill_mod==0 else 0.7)
			bolts = bolts.filter(func(b): return not b.hostile or pos(b).distance_to(p)>radius)
			if skill_mod==1: shield=minf(30,shield+20)
			if character=="keeper": heal(5)
			emit("pulse",{"x":p.x,"y":p.y,"radius":radius})
		"poison":
			make_zone(target,180 if skill_mod==0 else 150,12*scale_value,"poison_mist",8 if skill_mod==0 else 5)
			zones.back()["pull"] = skill_mod==1
		"shadow": shadow_time = 8.0 if skill_mod==1 else 5.0
		"binding":
			var radius = 216.0 if skill_mod==1 else 160.0
			for mob in near(target,radius):
				if not mob.boss: move_entity(mob,(target-pos(mob))*0.55)
				if skill_mod==0: mob["vulnerable"] = 3.0
			_area(target,radius,45*scale_value,"binding_hex",1.5)
		"blast":
			make_zone(target,175 if skill_mod==1 else 135,110*scale_value,"blast_pill",0.3,0.35,false,true)
			if skill_mod==0:
				for offset in [-70,70]: make_zone(target+aim.orthogonal()*offset,100,45*scale_value,"blast_pill",0.3,0.75,false,true)
		"frost":
			var radius = 288.0 if skill_mod==0 else 240.0
			_area(p,radius,55*scale_value,"frost_ring",1.8 if skill_mod==0 else 1.0)
			if skill_mod==1:
				for mob in near(p,radius): mob["vulnerable"] = 2.5
	if "drum" in relics: bolts=bolts.filter(func(b): return not b.hostile or pos(b).distance_to(p)>180)
	if "temple_beads" in relics and _proc("beads",3): heal(2)
	var art_radius={"pulse":337.5 if skill_mod==0 else 270.0,"poison":180.0 if skill_mod==0 else 150.0,"shadow":100.0,"binding":216.0 if skill_mod==1 else 160.0,"blast":175.0 if skill_mod==1 else 135.0,"frost":288.0 if skill_mod==0 else 240.0}[skill]
	emit("skill",{"x":target.x if skill in ["poison","blast","binding"] else p.x,"y":target.y if skill in ["poison","blast","binding"] else p.y,"from_x":p.x,"from_y":p.y-25,"skill":skill,"radius":art_radius,"source":item.source})
	return true

func _area(p: Vector2, radius: float, amount: float, source: String, stun: float = 0) -> void:
	for mob in near(p,radius):
		if stun>0: _control(mob,stun)
		apply_element(mob,source,amount)
		hit(mob,amount,source,65)
	emit("ring",{"x":p.x,"y":p.y,"radius":radius,"source":source})

func _control(mob: Dictionary, duration: float) -> void:
	if mob.boss:
		mob["poise"]=mob.get("poise",0.0)+duration*25
		if mob.poise<(45 if "bell_shard" in relics else 60): return
		mob.poise=0; mob.stun=maxf(mob.stun,1.6 if "bell_shard" in relics else 1.2); mob["vulnerable"]=2.5
		mob.windup=0; mob.charging=0; mob.cooldown=maxf(mob.cooldown,1.8)
		emit("notice",{"text":"首领失衡 · 趁机攻击"})
	else:
		mob.stun=maxf(mob.stun,duration); mob.windup=0; mob.charging=0
		mob.cooldown=maxf(mob.cooldown,1.0)

func apply_element(mob: Dictionary, source: String, amount: float) -> void:
	if mob.hp<=0: return
	var element = Content.element(source)
	var reaction = ""
	if mob.reaction_cd<=0:
		if element=="fire" and mob.poison>0 or element=="poison" and mob.burn>0: reaction="燃瘴"
		elif element=="thunder" and (mob.wet>0 or mob.slow>0): reaction="引雷"
		elif element=="fire" and mob.slow>0 or element=="frost" and mob.burn>0: reaction="融霜"
	if not reaction.is_empty():
		mob.reaction_cd = 1.0
		reactions[reaction] = int(reactions.get(reaction,0))+1
		var damage = amount*(1.0+sigils.get("reaction",0)*0.25)
		hit(mob,damage,"reaction:"+reaction)
		if reaction!="融霜":
			for other in near(pos(mob),140):
				if other.uid!=mob.uid: hit(other,damage*0.55,"reaction:"+reaction)
		mob.burn *= 0.5; mob.poison *= 0.5; mob.slow *= 0.5
		if reaction=="燃瘴" and oath=="cinder": heal(2)
		emit("reaction",{"x":mob.x,"y":mob.y,"radius":140,"source":source,"text":reaction})
	match element:
		"fire":
			mob.burn = maxf(mob.burn,3.0)
			mob["innate_burn_dps"] = maxf(mob.get("innate_burn_dps",0.0),maxf(4,amount*0.18)*stat("burn")*(2.0 if skill=="blast" and skill_mod==1 and source=="blast_pill" else 1.0))
			mob.burn_dps = mob.innate_burn_dps+mob.get("sigil_burn_dps",0.0)
			mob.burn_source = source
		"poison":
			mob.poison = maxf(mob.poison,3.0+sigils.get("toxin",0)*0.5)
			mob.poison_dps = maxf(mob.poison_dps,6.0*stat("damage")*stat("burn")*(1.0+sigils.get("toxin",0)*0.25)*(1.4 if gear=="needle" and gear_mod==1 else 1.0))
		"frost": mob.slow=maxf(mob.slow,3.0 if oath=="tide" else 2.0)
		"thunder": mob.stun=maxf(mob.stun,0.08 if mob.boss else 0.2)

func hit(mob: Dictionary, amount: float, source: String, knockback: float = 0, critical: bool = false) -> void:
	if mob.hp<=0: return
	if mob.slow>0 or mob.stun>0: amount*=1+sigils.get("frozen",0)*0.12
	if "tower_key" in relics: amount*=1.2 if mob.boss else 0.92
	if "cinder_mask" in relics and player.hp<player.max_hp*0.5 and Content.element(source)=="fire": amount*=1.25
	if mob.hp<mob.max_hp*0.35: amount*=1.0+sigils.get("execution",0)*0.2
	if mob.get("vulnerable",0)>0: amount*=1.25
	if oath=="cinder" and Content.element(source)=="fire": amount*=1.25
	if oath=="tide" and Content.element(source) not in ["frost","thunder"]: amount*=0.92
	if mob.boss and mobs.any(func(other): return other.hp>0 and other.get("pillar",false)): amount*=0.7
	amount = maxf(0,amount)
	damage_by_skill[source] = damage_by_skill.get(source,0.0)+minf(amount,mob.hp)
	mob.hp -= amount
	if amount>=2: mob.flash=0.12
	if knockback>0: move_entity(mob,(pos(mob)-pos(player)).normalized()*knockback*(0.15 if mob.boss else 1.0))
	emit("hit",{"x":mob.x,"y":mob.y,"amount":int(amount),"source":source,"critical":critical})
	if mob.hp>0: return
	kills+=1; combo+=1; combo_time=3.0
	wind_time=4.0; wind_stacks=mini(3,wind_stacks+1)
	if sigils.get("ward",0)>0 and (mob.stun>0 or mob.slow>0): shield=minf(30,shield+5*sigils.ward)
	if oath=="script" and kills%45==0: rerolls+=1
	if rng.randf()<0.25 or mob.elite: drops.append({"x":mob.x,"y":mob.y,"value":7 if mob.elite else 2,"kind":"coin","age":0.0})
	emit("death",{"x":mob.x,"y":mob.y,"source":source,"boss":mob.boss})
	if mob.get("pillar",false):
		for boss in mobs.filter(func(other): return other.hp>0 and other.boss): hit(boss,95,"pulse")
	if mob.boss:
		bosses+=1; nohit=sector_damage==0
		for other in mobs:
			if other.hp>0: other.hp=0; emit("death",{"x":other.x,"y":other.y,"source":source,"boss":false})
		room().cleared=true; room().claimed=true
		coins+=45
		_collect_all()
		finish(true)

func hurt(amount: float) -> void:
	if phase!="active" or player.invulnerable>0 or player.hp<=0: return
	var absorbed = minf(shield,amount)
	shield-=absorbed; amount-=absorbed
	player.hp-=amount; player.invulnerable=0.65
	sector_damage+=amount; total_damage_taken+=amount
	emit("hurt",{"x":player.x,"y":player.y,"amount":int(amount),"shield":absorbed})
	if player.hp<=0 and "old_wick" in relics and not resurrected:
		resurrected=true; player.hp=player.max_hp*0.3; player.invulnerable=3.0
		emit("notice",{"text":"不灭灯芯生效 · 回复 30% 生命"})
	if player.hp<=0: finish(false)

func spawn(kind: String, elite: bool = false, boss: bool = false) -> Dictionary:
	var mob = super.spawn(kind,elite,boss)
	if mob.is_empty(): return mob
	var p = room_bounds.get_center()
	for i in range(35):
		p = Vector2(rng.randf_range(room_bounds.position.x+70,room_bounds.end.x-70),rng.randf_range(room_bounds.position.y+70,room_bounds.end.y-70))
		if p.distance_to(pos(player))>280 and not obstacles.any(func(o): return pos(o).distance_to(p)<o.radius+mob.radius+20): break
	set_pos(mob,p)
	mob.hp*=1.0+room().rank*0.07; mob.max_hp=mob.hp
	mob.speed*=0.85; mob.damage*=0.65*(1.15 if curse_damage else 1.0)
	mob["vulnerable"]=0.0; mob["melee_pending"]=false
	return mob

func _spawn_wave() -> void:
	wave_index+=1
	var pool = ["paper_spirit","lantern_wisp","archer"]
	if room().rank>=2: pool.append("mist_fox")
	if room().rank>=3: pool.append("stone_guard")
	var count = 9+room().rank*2
	if contract=="swarm": count=ceili(count*1.35)
	for i in range(count): spawn(pool[rng.randi_range(0,pool.size()-1)],room().type=="elite" and i==0 and wave_index==1)
	if extra_elite and wave_index==1: spawn("stone_guard",true); extra_elite=false
	emit("notice",{"text":"敌潮 %d / %d" % [wave_index,wave_count]})

func _spawn_boss() -> void:
	var boss=spawn("boss0",false,true)
	boss.hp=2700*(1+difficulty*0.2); boss.max_hp=boss.hp; boss.speed=45; boss.cooldown=2.5
	set_pos(boss,room_bounds.get_center()+Vector2(0,-180))
	boss_spawned=true
	_spawn_pillars()
	emit("boss",{"text":"百目灯魁 · 击破灯柱可削弱灯魁"})

func _spawn_pillars() -> void:
	for side in [-1,1]:
		var pillar=spawn("stone_guard")
		set_pos(pillar,room_bounds.get_center()+Vector2(side*380,-80))
		pillar.hp=140; pillar.max_hp=140; pillar.speed=0; pillar["pillar"]=true

func boss_attack(mob: Dictionary) -> void:
	mob.attack+=1; mob["cast"]=0.4
	var angry=mob.hp<mob.max_hp*0.5
	if angry and not mob.enraged:
		mob.enraged=true; _spawn_pillars()
		emit("enrage",{"x":mob.x,"y":mob.y,"text":"灯魁狂暴 · 灯柱重新点燃"})
	var lit=mobs.filter(func(m): return m.hp>0 and m.get("pillar",false)).size()
	if mob.attack%3==1:
		for i in range(2+lit):
			var target=pos(player) if i==0 else room_bounds.get_center()+Vector2(rng.randf_range(-420,420),rng.randf_range(-210,210))
			make_zone(target,75,mob.damage*1.4,"enemy",0.35,1.05,true,true)
	elif mob.attack%3==2: hostile_fan(mob,8+lit*3+(4 if angry else 0),155,true)
	else:
		hostile_fan(mob,5+lit,210)
		for i in range(3): spawn("paper_spirit")
	mob.cooldown=2.7 if angry else 3.5

func update_mobs(dt: float) -> void:
	var active_threats=mobs.filter(func(m): return m.hp>0 and m.windup>0).size()
	for mob in mobs.duplicate():
		if mob.hp<=0: continue
		mob.spawn_age+=dt
		for field in ["slow","stun","flash","wet","reaction_cd","vulnerable","cast"]: mob[field]=maxf(0,mob.get(field,0)-dt)
		if mob.get("poise",0)>0: mob.poise=maxf(0,mob.poise-dt*2)
		for hazard in hazards:
			if pos(mob).distance_to(pos(hazard))<hazard.radius: mob.wet=0.5
		if mob.burn>0:
			mob.burn=maxf(0,mob.burn-dt); hit(mob,mob.burn_dps*dt,mob.burn_source)
			if mob.burn==0: mob["innate_burn_dps"]=0.0; mob["sigil_burn_dps"]=0.0; mob.burn_dps=0
		if mob.poison>0: mob.poison=maxf(0,mob.poison-dt); hit(mob,mob.poison_dps*dt,"poison_mist")
		if mob.hp<=0 or phase!="active" or mob.stun>0 or mob.spawn_age<0.65: continue
		if mob.get("pillar",false): continue
		var direction=(pos(player)-pos(mob)).normalized()
		if absf(direction.x)>0.1: mob.facing=signf(direction.x)
		mob.cooldown-=dt
		if mob.windup>0:
			mob.windup=maxf(0,mob.windup-dt)
			if mob.windup==0:
				if not mob.boss and mob.kind!="archer": emit("enemy_attack",{"x":mob.x,"y":mob.y,"angle":Vector2(mob.dx,mob.dy).angle(),"source":"enemy","enemy_kind":mob.kind})
				if mob.boss: boss_attack(mob)
				elif mob.kind=="archer": hostile_fan(mob,3 if mob.elite else 1,240,false,Vector2(mob.dx,mob.dy))
				elif mob.kind=="mist_fox": mob.charging=0.4
				else:
					mob["cast"]=0.25
					if pos(mob).distance_to(pos(player))<100+player.radius: hurt(mob.damage)
					emit("ring",{"x":mob.x,"y":mob.y,"radius":100,"source":"enemy"})
			continue
		if mob.charging>0:
			mob.charging=maxf(0,mob.charging-dt)
			move_entity(mob,Vector2(mob.dx,mob.dy)*dt*540)
			if pos(mob).distance_to(pos(player))<mob.radius+player.radius: hurt(mob.damage)
			continue
		var distance=pos(player).distance_to(pos(mob))
		if mob.kind=="archer" and not mob.boss:
			if distance<220: direction=-direction
			elif distance<450: direction=Vector2.ZERO
		move_entity(mob,navigation_direction(mob,direction)*mob.speed*(0.5 if mob.slow>0 else 1.0)*dt)
		if mob.cooldown<=0 and active_threats<3:
			if mob.boss or mob.kind in ["archer","mist_fox"] or distance<105:
				var locked_aim=(pos(player)-pos(mob)).normalized()
				mob.dx=locked_aim.x; mob.dy=locked_aim.y
				mob.windup=0.8 if mob.boss else (0.65 if mob.kind=="mist_fox" else 0.5)
				mob.cooldown=3.0 if mob.boss else (2.5 if mob.kind in ["archer","mist_fox"] else 1.3)
				active_threats+=1

func update_bolts(dt: float) -> void:
	for bolt in bolts:
		bolt.life-=dt
		var before=pos(bolt)
		set_pos(bolt,before+Vector2(bolt.vx,bolt.vy)*dt)
		if obstacles.any(func(o): return Geometry2D.get_closest_point_to_segment(pos(o),before,pos(bolt)).distance_to(pos(o))<o.radius): bolt.life=0; continue
		if bolt.hostile:
			if Geometry2D.get_closest_point_to_segment(pos(player),before,pos(bolt)).distance_to(pos(player))<player.radius+bolt.radius: hurt(bolt.damage); bolt.life=0
		else:
			for mob in near((before+pos(bolt))*0.5,before.distance_to(pos(bolt))*0.5+50):
				if mob.uid in bolt.hits: continue
				if Geometry2D.get_closest_point_to_segment(pos(mob),before,pos(bolt)).distance_to(pos(mob))<mob.radius+bolt.radius:
					bolt.hits.append(mob.uid)
					if bolt.get("primary",false): _primary_hit(mob,bolt.damage,bolt.source,bolt.get("critical",false))
					else: hit(mob,bolt.damage,bolt.source)
					bolt.pierce-=1
					if bolt.pierce<0: bolt.life=0; break
	bolts=bolts.filter(func(b): return b.life>0 and room_bounds.grow(20).has_point(pos(b)))

func update_zones(dt: float) -> void:
	for zone in zones:
		if zone.warning>0:
			zone.warning=maxf(0,zone.warning-dt)
			if zone.warning==0: emit("ring",{"x":zone.x,"y":zone.y,"radius":zone.radius,"source":zone.source})
			continue
		zone.life-=dt; zone.tick-=dt
		if zone.tick>0: continue
		zone.tick=0.4
		if zone.hostile:
			if pos(player).distance_to(pos(zone))<zone.radius+player.radius: hurt(zone.damage)
		else:
			for mob in near(pos(zone),zone.radius):
				if zone.get("pull",false) and not mob.boss: move_entity(mob,(pos(zone)-pos(mob))*0.2)
				apply_element(mob,zone.source,zone.damage)
				hit(mob,zone.damage,zone.source)
		if zone.once: zone.life=0
	zones=zones.filter(func(z): return z.life>0)

func update_drops(dt: float) -> void:
	for drop in drops:
		drop.age+=dt
		var direction=pos(player)-pos(drop)
		if direction.length()<150 or drop.age>5: set_pos(drop,pos(drop)+direction.normalized()*minf(direction.length(),dt*600))
		if direction.length()<24:
			coins+=int(drop.value); coin_ready=true; drop["taken"]=true
			emit("pickup",{"x":drop.x,"y":drop.y,"kind_drop":"coin"})
	drops=drops.filter(func(d): return not d.get("taken",false))

func _collect_all() -> void:
	for drop in drops: coins+=int(drop.value)
	if not drops.is_empty(): coin_ready=true
	drops.clear()

func update_step(dt: float, move: Vector2, interact: bool) -> void:
	dt=clampf(dt,0,0.05)
	time+=dt; room_age+=dt
	for field in ["invulnerable","cast"]: player[field]=maxf(0,player[field]-dt)
	for key in proc_timers: proc_timers[key]=maxf(0,proc_timers[key]-dt)
	attack_cd=maxf(0,attack_cd-dt); attack_buffer=maxf(0,attack_buffer-dt); skill_cd=maxf(0,skill_cd-dt)
	counter_time=maxf(0,counter_time-dt); shadow_time=maxf(0,shadow_time-dt)
	wind_time=maxf(0,wind_time-dt); combo_time=maxf(0,combo_time-dt)
	if wind_time==0: wind_stacks=0
	if combo_time==0: combo=0
	if dash_charges<2:
		dash_recharge-=dt
		if dash_recharge<=0: dash_charges+=1; dash_recharge=_dash_interval() if dash_charges<2 else 0
	player.dash_cd=0 if dash_charges>0 else dash_recharge
	var speed=Content.data.characters[character].speed*stat("speed")
	if player.dash_time>0:
		player.dash_time=maxf(0,player.dash_time-dt); move=Vector2(player.dash_dx,player.dash_dy); speed=780*(1.2 if "reed_sandal" in relics else 1.0)
	player.moving=move.length_squared()>0.01
	if absf(aim.x)>0.1: player.facing=signf(aim.x)
	move_entity(player,move.limit_length(1)*speed*dt)
	update_mobs(dt)
	if phase!="active": return
	rebuild_index()
	if attack_windup>0:
		attack_windup=maxf(0,attack_windup-dt)
		if attack_windup==0: _attack()
	elif (attack_held or attack_buffer>0) and attack_cd<=0 and player.dash_time<=0:
		attack_aim=aim; attack_windup=0.12 if gear=="hammer" else 0.055
		attack_buffer=0
		attack_cd=C.GEAR[gear].interval/(1+stat("attack_speed"))
	update_bolts(dt)
	if phase!="active": return
	update_zones(dt); update_drops(dt)
	mobs=mobs.filter(func(m): return m.hp>0)
	if phase!="active": return
	if room().type in ["combat","elite"] and not room().cleared and mobs.is_empty():
		if wave_index<wave_count: _spawn_wave()
		else: _clear_room()
	if clear_delay>0:
		clear_delay=maxf(0,clear_delay-dt)
		if clear_delay==0:
			room().claimed=true
			if room().type=="elite": _relic_offer()
			else: roll_choices()
	if room().type=="shrine" and shrine_started and not room().claimed:
		if not mobs.is_empty(): pass
		elif shrine_round<2:
			if interact and pos(player).distance_to(pos(shrine))<100: shrine.progress+=dt*(2 if "green_lamp" in relics else 1)
			if shrine.progress>=2:
				shrine_round+=1; shrine.progress=0; _spawn_wave()
		else:
			room().cleared=true; room().claimed=true; shrine_started=false; shrine.clear(); shrines+=1
			coins+=25+(20 if "green_lamp" in relics else 0); _collect_all(); _relic_offer()
	if phase=="active" and interact and _proc("interact",0.3): interact_nearby()

func _clear_room() -> void:
	room().cleared=true; clear_delay=0.65
	_collect_all(); coins+=18+(8 if "broken_coin" in relics else 0)
	if character=="keeper": shield=minf(30,shield+8)
	if character=="alchemist": heal(6)
	curse_damage=false
	emit("clear",{"x":room_bounds.get_center().x,"y":room_bounds.get_center().y,"text":"街巷已清 · 选择强化"})

func interact_nearby() -> bool:
	if phase!="active": return false
	for door in doors():
		if door.open and pos(player).distance_to(door.position)<100: return enter_room(door.id,door.direction)
	if pos(player).distance_to(room_bounds.get_center())>130: return false
	var kind=room().type
	if kind=="shop": _shop_offer(); return true
	if room().claimed: return false
	match kind:
		"gear": _offer("gear","兵器铺 · 更换装备","装备只有一个槽位。强化阶数保留。",_shuffle(C.GEAR.keys().filter(func(k): return k!=gear)).slice(0,3).map(func(k): return "g:"+k)+["leave:0"])
		"skill": _offer("skill","废亭符谱 · 更换技能","主动技能只有一个槽位。强化阶数保留。",_shuffle(C.SKILLS.keys().filter(func(k): return k!=skill)).slice(0,3).map(func(k): return "s:"+k)+["leave:0"])
		"rest": _offer("rest","茶摊休整","回复与强化，只能选一项。",["rest:heal","rest:gear","leave:0"])
		"event": _offer("event",event_definition().name,event_definition().text,["event:0","event:1","event:2"])
		"secret": room().claimed=true; coins+=35; _relic_offer()
		"shrine": shrine_started=true; room().cleared=false; wave_count=2; emit("notice",{"text":"靠近古灯长按 E，抵挡两波敌潮。"})
		_: return false
	return true

func interaction_hint() -> String:
	for door in doors():
		if pos(player).distance_to(door.position)<145: return "E · 前往 "+door.name+"  /  "+door.reward if door.open else ("清房结算中" if clear_delay>0 else "击败本房敌人后开门")
	if pos(player).distance_to(room_bounds.get_center())<150:
		if room().type=="shrine" and not room().claimed: return "长按 E · 点灯" if shrine_started else "E · 开始祭灯挑战"
		if room().type=="shop" or room().type in ["gear","skill","rest","event","secret"] and not room().claimed: return "E · "+C.ROOM_TYPES[room().type].name
	return "左键攻击  ·  右键技能  ·  空格闪避  ·  Tab 地图"

func _offer(kind: String, title: String, subtitle: String, pool: Array) -> void:
	offer_kind=kind; offer_title=title; offer_subtitle=subtitle; choices=pool; phase="upgrade"
	attack_held=false
	attack_buffer=0; attack_windup=0

func roll_choices() -> void:
	var candidates: Array=[]
	var compatible: Array=[]
	for key in C.SIGILS:
		if key=="leech" and contract=="silence": continue
		if sigils.get(key,0)<3:
			candidates.append("p:"+key)
			if _sigil_compatible(key): compatible.append("p:"+key); candidates.append("p:"+key)
			if sigils.has(key): candidates.append("p:"+key)
	var pool: Array=["a:"+C.ATTRIBUTES.keys()[rng.randi_range(0,3)]]
	if not compatible.is_empty(): pool.append(compatible[rng.randi_range(0,compatible.size()-1)])
	for token in _shuffle(candidates):
		if token not in pool: pool.append(token)
		if pool.size()==3: break
	_offer("growth","清房奖励 · 选择强化","基础属性稳定提升；符印改变攻击与技能。",pool)

func _sigil_compatible(key: String) -> bool:
	var tags=C.GEAR[gear].tags+C.SKILLS[skill].tags
	if sigils.get("fire",0)>0: tags=tags+["火"]
	if key=="toxin": return "毒" in tags
	if key=="ember": return "火" in tags
	if key=="ward": return "控制" in tags or "霜" in tags or "雷" in tags
	if key=="frozen": return "控制" in tags or "霜" in tags or "雷" in tags
	if key=="pierce": return "投射" in C.GEAR[gear].tags or gear=="sword" and gear_mod==0
	if key=="reaction":
		var elements=["火","毒","雷","霜"].filter(func(element): return element in tags)
		return elements.size()>=2
	return true

func reroll() -> bool:
	if phase!="upgrade" or offer_kind!="growth" or rerolls<=0: return false
	rerolls-=1; roll_choices(); return true

func _relic_offer() -> void:
	var pool=_shuffle(C.RELICS.keys().filter(func(k): return k not in relics and not (k=="old_wick" and resurrected) and not (k=="temple_beads" and contract=="silence")))
	_offer("relic","选取遗物","最多携带六件。遗物提供独特效果，不占装备位。",pool.slice(0,3).map(func(k): return "r:"+k)+["coin:25"])

func _shop_offer() -> void:
	var pool: Array=[]
	for token in ["shop:heal","shop:gear","shop:skill","shop:relic"]:
		if token not in shop_bought: pool.append(token)
	pool.append("leave:0")
	_offer("shop","夜市货郎","铜钱用于回复、强化与遗物。每项商品只能购买一次。",pool)

func choice_cost(token: String) -> int:
	if token.begins_with("shop:"):
		var cost={"shop:heal":25,"shop:gear":35,"shop:skill":35,"shop:relic":50}.get(token,0)
		return int(cost*0.8) if "river_coin" in relics else cost
	if token.begins_with("event:"):
		var i=int(token.get_slice(":",1))
		if event_id==0 and i==1: return 20
		if event_id==3: return [25,30,0][i]
	return 0

func can_choose(token: String) -> bool:
	return unavailable_reason(token).is_empty()

func unavailable_reason(token: String) -> String:
	if coins<choice_cost(token): return "铜钱不足。"
	if token in ["shop:gear","rest:gear"] and gear_rank>=3: return "装备已达到三阶。"
	if token=="shop:skill" and skill_rank>=3: return "技能已达到三阶。"
	if token=="event:0" and event_id==0 and player.max_hp<=30: return "生命上限过低，无法交易。"
	if token=="event:1" and event_id==3 and gear_rank>=3: return "装备已达到三阶。"
	var heals=token in ["shop:heal","rest:heal"] or token=="event:1" and event_id==0 or token=="event:0" and event_id==3
	if heals and contract=="silence": return "禁疗契约已封印生命回复。"
	if heals and player.hp>=player.max_hp: return "生命已满。"
	return ""

func choose_oath(index: int) -> bool:
	if phase!="oath" or index<0 or index>=choices.size(): return false
	oath=choices[index].get_slice(":",1)
	if oath=="cinder": player.max_hp*=0.9; player.hp=minf(player.hp,player.max_hp)
	phase="active"; choices.clear()
	return true

func choose(index: int) -> bool:
	if phase!="upgrade" or index<0 or index>=choices.size(): return false
	var token=choices[index]
	if not can_choose(token): return false
	var kind=token.get_slice(":",0); var key=token.get_slice(":",1)
	var context=offer_kind
	coins-=choice_cost(token)
	phase="active"; choices.clear()
	if context in ["gear","skill","rest","event"]: room().claimed=true
	match kind:
		"a":
			attributes[key]=int(attributes.get(key,0))+1
			if key=="health": player.max_hp+=15; heal(15)
			level+=1
		"p":
			if not sigils.has(key) and sigils.size()>=6:
				pending_sigil=key; _offer("replace_sigil","符印已满 · 选择替换","选择一枚旧符印，换入 "+C.SIGILS[key].name,sigils.keys().map(func(k): return "drop_sigil:"+k)+["leave:0"])
			else: sigils[key]=int(sigils[key])+1 if sigils.has(key) else (2 if "inkstone" in relics else 1); level+=1
		"drop_sigil": sigils.erase(key); sigils[pending_sigil]=2 if "inkstone" in relics else 1; pending_sigil=""
		"r":
			if relics.size()>=6:
				pending_relic=key; _offer("replace_relic","遗物已满 · 选择替换","选择一件旧遗物，换入 "+C.RELICS[key].name,relics.map(func(k): return "drop_relic:"+k)+["coin:25"])
			else: relics.append(key)
		"drop_relic": relics.erase(key); relics.append(pending_relic); pending_relic=""
		"g": gear=key; gear_mod=-1; attack_windup=0; bolts=bolts.filter(func(b): return b.hostile); weapons={C.GEAR[gear].source:gear_rank}; _gear_mod_offer()
		"s": skill=key; skill_mod=-1; shadow_time=0; zones=zones.filter(func(z): return z.hostile); skill_cd=minf(skill_cd,C.SKILLS[skill].cooldown); _skill_mod_offer()
		"gm": gear_mod=int(key)
		"sm": skill_mod=int(key)
		"coin": coins+=int(key); pending_relic=""
		"rest":
			if key=="heal": heal(player.max_hp*0.5)
			else: _upgrade_gear()
		"shop":
			shop_bought.append(token)
			if key=="heal": heal(50)
			elif key=="gear": _upgrade_gear()
			elif key=="skill": skill_rank+=1; _skill_mod_offer()
			else: _relic_offer()
		"event": _choose_event(int(key))
		"leave": pending_sigil=""; pending_relic=""
	emit("upgrade",{"x":player.x,"y":player.y})
	return true

func _upgrade_gear() -> void:
	gear_rank=mini(3,gear_rank+1); weapons={C.GEAR[gear].source:gear_rank}; _gear_mod_offer()

func _gear_mod_offer() -> void:
	if gear_rank>=2 and gear_mod<0: _offer("gear_mod",C.GEAR[gear].name+" · 装备改造","选定一种攻击形态。本局装备强化阶数保留。",["gm:0","gm:1"])

func _skill_mod_offer() -> void:
	if skill_rank>=2 and skill_mod<0: _offer("skill_mod",C.SKILLS[skill].name+" · 技能改造","选定一种技能形态。主动技能仍只有一个。",["sm:0","sm:1"])

func _choose_event(index: int) -> void:
	if index==2: return
	match event_id:
		0:
			if index==0: player.max_hp-=15; player.hp=minf(player.hp,player.max_hp); _relic_offer()
			else: heal(35)
		1:
			if index==0: coins+=45; extra_elite=true
			else: rerolls+=1
		2:
			if index==0: curse_damage=true; roll_choices()
			else: attributes["power"]=int(attributes.get("power",0))+1; player.hp=maxf(1,player.hp-15)
		3:
			if index==0: heal(player.max_hp)
			else: _upgrade_gear()

func event_definition() -> Dictionary:
	return C.EVENT_TEXT[event_id]

func chapter_choice_info(token: String) -> Dictionary:
	var kind=token.get_slice(":",0); var key=token.get_slice(":",1)
	var item: Dictionary={"name":"继续前行","glyph":"行","desc":"保留当前配置，继续探索。"}
	var tag="选择"; var note=""; var color=Color("ad3527")
	match kind:
		"o":
			if key=="none": item={"name":"不立誓","glyph":"无","desc":"按基础规则出发，不附加收益或代价。"}
			else:
				item=Content.data.oaths[key].duplicate(); note=item.note
				if key=="cinder": item.desc="火伤 +25%；燃瘴回复 2 点生命。生命上限 -10%。"
				elif key=="tide": item.desc="霜减速延长 1 秒；闪避充能速度提升 25%。"
				else: item.desc="投射普攻多发一枚，单枚伤害 -20%；每击败 45 名敌人，刷新次数 +1。"
			tag="出发誓愿"
		"g": item=C.GEAR[key]; tag="装备 · 替换 "+C.GEAR[gear].name; note=" / ".join(item.tags)
		"s": item=C.SKILLS[key]; tag="技能 · 替换 "+C.SKILLS[skill].name; note=" / ".join(item.tags)
		"a": item=C.ATTRIBUTES[key]; tag="基础属性 · 本局生效"
		"p": item=C.SIGILS[key]; tag="符印 · %d → %d 级" % [sigils.get(key,0),sigils.get(key,0)+1 if sigils.has(key) else (2 if "inkstone" in relics else 1)]; note=" / ".join(item.tags)+(" · 当前可触发" if _sigil_compatible(key) else " · 当前缺少搭配")
		"r": item=C.RELICS[key]; tag="遗物 · %d / 6" % relics.size()
		"drop_sigil": item=C.SIGILS[key]; tag="移除此符印"
		"drop_relic": item=C.RELICS[key]; tag="移除此遗物"
		"gm": item={"name":"装备改造","glyph":C.GEAR[gear].glyph,"desc":C.GEAR[gear].mods[int(key)]}; tag="改变普通攻击"
		"sm": item={"name":"技能改造","glyph":C.SKILLS[skill].glyph,"desc":C.SKILLS[skill].mods[int(key)]}; tag="改变主动技能"
		"shop":
			item={"name":{"heal":"疗伤药","gear":"装备升阶","skill":"技能升阶","relic":"古物匣"}[key],"glyph":"市","desc":{"heal":"回复 50 点生命。","gear":"装备升一阶，每阶增加 20% 基础伤害；二阶可选择攻击改造。","skill":"技能升一阶，每阶增加 20% 本体伤害；二阶可选择技能改造。","relic":"从三件未持有的遗物中选择一件。"}[key]}; tag="购买 · %d 铜钱" % choice_cost(token)
		"event": item={"name":["接受交易","另作选择","继续前行"][int(key)],"glyph":"遇","desc":event_definition().choices[int(key)]}; tag="奇遇选择"
		"rest": item={"name":"喝茶疗伤" if key=="heal" else "磨砺装备","glyph":"茶","desc":"回复 50% 最大生命。" if key=="heal" else "装备升一阶；二阶可选择攻击改造。"}; tag="休整 · 只能选一项"
		"coin": item={"name":"折算铜钱","glyph":"钱","desc":"获得 %s 铜钱，保留当前遗物。" % key}; tag="补给"
	if not can_choose(token): note=unavailable_reason(token)
	return {"name":item.name,"desc":item.desc,"glyph":item.glyph,"tag":tag,"note":note,"color":color}

func result() -> Dictionary:
	var output=super.result()
	output["ruleset"]="chapter_one"; output["gear"]=gear; output["skill"]=skill; output["gear_rank"]=gear_rank; output["skill_rank"]=skill_rank; output["gear_mod"]=gear_mod; output["skill_mod"]=skill_mod; output["sigils"]=sigils.duplicate(); output["rooms_cleared"]=rooms.filter(func(r): return r.cleared and r.visited).size()
	output["reward"]=int((8+kills/18+bosses*20+(15 if victory else 0))*Content.data.contracts[contract].bonus)
	output["attributes"]=attributes.duplicate()
	return output

func snapshot() -> Dictionary:
	var raw=super.snapshot()
	raw.version=5; raw["ruleset"]="chapter_one"
	for key in CHAPTER_KEYS:
		var value=get(key)
		raw[key]=value.duplicate(true) if value is Array or value is Dictionary else value
	return raw

func valid_snapshot(raw: Dictionary) -> bool:
	if raw.get("version")!=5 or raw.get("ruleset")!="chapter_one": return false
	for key in SNAPSHOT_KEYS+CHAPTER_KEYS+["oath","pending_relics","relic_return_phase","pending_replacement"]:
		if not raw.has(key): return false
		if typeof(raw[key])!=typeof(get(key)) and not (numeric(raw[key]) and numeric(get(key))): return false
		if raw[key] is float or raw[key] is int:
			if not numeric(raw[key]): return false
	if raw.phase not in ["active","upgrade","oath","finished"]: return false
	if not C.GEAR.has(raw.gear) or not C.SKILLS.has(raw.skill): return false
	if not Content.data.characters.has(raw.character) or not Content.data.contracts.has(raw.contract): return false
	if raw.run_id.length()>120: return false
	for key in raw.camp:
		if not Content.data.camp.has(key) or not numeric(raw.camp[key],0,8,true): return false
	if not raw.passives.is_empty() or not raw.evolved.is_empty(): return false
	if raw.mode not in ["campaign","daily","endless"] or raw.oath not in ["none","cinder","tide","script"]: return false
	for key in ["rng_seed","rng_state"]:
		if not raw.get(key) is String or not raw[key].is_valid_int() or raw[key].length()>20: return false
	if raw.rooms.size()!=14 or not numeric(raw.room_id,0,13,true): return false
	var coordinates: Dictionary={}
	var types: Dictionary={}
	for i in range(raw.rooms.size()):
		var r=raw.rooms[i]
		if not record(r,["id","gx","gy","rank","layout"],["visited","cleared","claimed"],["type"]): return false
		if r.id!=i or not numeric(r.gx,0,6,true) or not numeric(r.gy,-1,1,true) or not numeric(r.layout,0,3,true) or r.rank!=C.MAP[i][3]: return false
		if i<=6 or i==13:
			if r.gx!=C.MAP[i][0] or r.gy!=C.MAP[i][1] or r.type!=C.MAP[i][2]: return false
		elif not numeric(r.gx,1,5,true) or abs(r.gy)!=1: return false
		if i in [7,8,10]:
			if r.type not in ["gear","skill","event"] or types.has(r.type): return false
			types[r.type]=true
		elif r.type!=C.MAP[i][2]: return false
		var coordinate=Vector2(r.gx,r.gy)
		if coordinates.has(coordinate) or r.claimed and not r.visited: return false
		coordinates[coordinate]=true
	var active_room=raw.rooms[raw.room_id]
	var large=active_room.layout in [1,3] and active_room.type in ["combat","elite","boss"]
	if raw.room_bounds!=Rect2(120,180,1720 if large else 1360,850 if large else 590): return false
	if raw.sigils.size()>6 or raw.relics.size()>6: return false
	for key in raw.sigils:
		if not C.SIGILS.has(key) or not numeric(raw.sigils[key],1,3,true): return false
	var unique: Dictionary={}
	for key in raw.relics:
		if not C.RELICS.has(key) or unique.has(key): return false
		unique[key]=true
	for key in raw.attributes:
		if not C.ATTRIBUTES.has(key) or not numeric(raw.attributes[key],0,100,true): return false
	if not numeric(raw.gear_rank,1,3,true) or not numeric(raw.skill_rank,1,3,true): return false
	if not numeric(raw.gear_mod,-1,1,true) or not numeric(raw.skill_mod,-1,1,true): return false
	if raw.weapons.size()!=1 or raw.weapons.get(C.GEAR[raw.gear].source)!=raw.gear_rank: return false
	if raw.gear_rank==1 and raw.gear_mod>=0 or raw.skill_rank==1 and raw.skill_mod>=0: return false
	if not numeric(raw.event_id,0,3,true) or not numeric(raw.shrine_round,0,2,true): return false
	for key in ["coins","kills","bosses","level","shrines","rerolls","uid","wave_index","wave_count","attack_count","wind_stacks"]:
		if not numeric(raw[key],0,100000000,true): return false
	if raw.stage!=1 or not numeric(raw.difficulty,0,3,true): return false
	for value in [raw.aim,raw.attack_aim]:
		if not value.is_finite() or absf(value.length_squared()-1)>0.1: return false
	for key in raw.proc_timers:
		if key not in ["interact","ember","silver","leech","wheel","beads"] or not numeric(raw.proc_timers[key],0,3): return false
	for key in raw.shop_bought:
		if key not in ["shop:heal","shop:gear","shop:skill","shop:relic"]: return false
	for prop in raw.decorations:
		if not record(prop,["x","y","sprite","size"]) or not numeric(prop.sprite,0,11,true): return false
	for obstacle in raw.obstacles:
		if not record(obstacle,["x","y","radius"]): return false
	for hazard in raw.hazards:
		if not record(hazard,["x","y","radius"],[],["kind"]) or hazard.kind!="water": return false
	if not raw.shrine.is_empty() and not record(raw.shrine,["x","y","progress","life"]): return false
	if raw.choices.size()>7: return false
	var contexts={"growth":["a","p"],"gear":["g","leave"],"skill":["s","leave"],"shop":["shop","leave"],"event":["event"],"rest":["rest","leave"],"relic":["r","coin"],"gear_mod":["gm"],"skill_mod":["sm"],"replace_sigil":["drop_sigil","leave"],"replace_relic":["drop_relic","coin"]}
	if raw.phase=="upgrade" and (raw.choices.is_empty() or not contexts.has(raw.offer_kind)): return false
	for token in raw.choices:
		if not token is String or token.count(":")!=1: return false
		var prefix=token.get_slice(":",0); var key=token.get_slice(":",1)
		if raw.phase=="oath" and (prefix!="o" or key not in ["none","cinder","tide","script"]): return false
		if raw.phase=="upgrade" and prefix not in contexts[raw.offer_kind]: return false
		match prefix:
			"a": if not C.ATTRIBUTES.has(key): return false
			"p": if not C.SIGILS.has(key): return false
			"r": if not C.RELICS.has(key): return false
			"g": if not C.GEAR.has(key): return false
			"s": if not C.SKILLS.has(key): return false
			"drop_sigil": if not raw.sigils.has(key) or not C.SIGILS.has(raw.pending_sigil): return false
			"drop_relic": if key not in raw.relics or not C.RELICS.has(raw.pending_relic): return false
			"shop": if key not in ["heal","gear","skill","relic"]: return false
			"rest": if key not in ["heal","gear"]: return false
			"event","gm","sm","coin","leave":
				if not key.is_valid_int(): return false
				var limit=2 if prefix=="event" else (1 if prefix in ["gm","sm"] else 1000)
				if not numeric(int(key),0,limit,true): return false
			"o": pass
			_: return false
	if not numeric(raw.dash_charges,0,2,true) or not numeric(raw.shield,0,30): return false
	if not numeric(raw.wind_stacks,0,3,true): return false
	if not record(raw.player,["x","y","hp","max_hp","radius","facing","invulnerable","dash_time","dash_cd","dash_dx","dash_dy","cast"],["moving","fox_ready"]): return false
	if raw.player.max_hp<=0 or not raw.room_bounds.grow(2).has_point(pos(raw.player)): return false
	if raw.player.hp>raw.player.max_hp or raw.phase!="finished" and raw.player.hp<=0: return false
	if raw.mobs.size()>180 or raw.bolts.size()>700 or raw.zones.size()>300: return false
	for mob in raw.mobs:
		if not record(mob,["uid","x","y","hp","max_hp","radius","speed","damage","cooldown","windup","charging","dx","dy","slow","stun","burn","burn_dps","poison","poison_dps","wet","reaction_cd","flash","facing","attack","xp","spawn_age"],["elite","boss","enraged"],["kind","burn_source"]): return false
		if not (MOB_STATS.has(mob.kind) or mob.kind=="boss0"): return false
		if not Content.skills.has(mob.burn_source) or not numeric(mob.uid,1,raw.uid,true) or mob.max_hp<=0: return false
		if mob.has("pillar") and not mob.pillar is bool: return false
		for field in ["poise","vulnerable","cast","innate_burn_dps","sigil_burn_dps"]:
			if mob.has(field) and not numeric(mob[field],0): return false
	for bolt in raw.bolts:
		if not record(bolt,["uid","x","y","vx","vy","damage","radius","life","pierce","homing"],["hostile"],["source","skin"]) or not bolt.get("hits") is Array: return false
		if not known_source(bolt.source) or bolt.hits.size()>180: return false
		for id in bolt.hits:
			if not numeric(id,1,raw.uid,true): return false
		for key in ["primary","critical"]:
			if bolt.has(key) and not bolt[key] is bool: return false
	for zone in raw.zones:
		if not record(zone,["x","y","radius","damage","life","warning","warning_max","tick"],["hostile","once"],["source"]): return false
		if not known_source(zone.source) or zone.has("pull") and not zone.pull is bool: return false
	for drop in raw.drops:
		if not record(drop,["x","y","value","age"],[],["kind"]): return false
		if drop.kind!="coin" or not numeric(drop.value,0,10000,true): return false
	for key in raw.damage_by_skill:
		if not key is String or not numeric(raw.damage_by_skill[key],0): return false
	return true

func restore(raw: Dictionary) -> bool:
	if not valid_snapshot(raw): return false
	raw=raw.duplicate(true)
	for key in SNAPSHOT_KEYS+CHAPTER_KEYS+["oath","pending_relics","relic_return_phase","pending_replacement"]: set(key,raw[key])
	rng.seed=int(raw.rng_seed); rng.state=int(raw.rng_state)
	attack_held=false; events.clear(); rebuild_index()
	return true
