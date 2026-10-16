extends Node

var reports: Array=[]
var shops_finished: Dictionary={}

func _ready() -> void:
	call_deferred("run")

func _path(w: ChapterWorld, target: int) -> Array:
	var queue: Array=[w.room_id]
	var previous: Dictionary={w.room_id:-1}
	while not queue.is_empty():
		var here=int(queue.pop_front())
		if here==target: break
		var r=w.rooms[here]
		for next in w.rooms:
			if abs(next.gx-r.gx)+abs(next.gy-r.gy)==1 and not previous.has(next.id): previous[next.id]=here; queue.append(next.id)
	var path: Array=[target]
	while path.front()!=w.room_id: path.push_front(previous[path.front()])
	return path

func choose(w: ChapterWorld) -> void:
	if w.phase=="oath": w.choose_oath(3); return
	var wanted: Array=[]
	if w.offer_kind=="shop":
		if w.player.hp<w.player.max_hp*0.6: wanted.append("shop:heal")
		if w.gear_rank<3: wanted.append("shop:gear")
		if w.skill_rank<3: wanted.append("shop:skill")
		if w.relics.size()<6: wanted.append("shop:relic")
		wanted.append("leave:0")
	elif w.offer_kind=="gear": wanted=["leave:0"]
	elif w.offer_kind=="skill": wanted=["s:poison"] if w.gear=="seal" else ["s:shadow"]
	elif w.offer_kind=="event": wanted=["event:1","event:2"]
	elif w.offer_kind=="rest": wanted=["rest:heal"] if w.player.hp<w.player.max_hp*0.7 else ["rest:gear","rest:heal"]
	elif w.offer_kind=="growth":
		if w.player.hp<w.player.max_hp*0.7: wanted.append("a:health")
		wanted.append_array(["p:fire","p:precision","p:cleave","p:execution","p:counter","p:echo","p:toxin","a:power"])
	else: wanted=["r:old_wick","r:fox_tooth","r:silver","r:drum","gm:0","sm:0"]
	for token in wanted:
		if token in w.choices and w.can_choose(token):
			if w.offer_kind=="shop" and token=="leave:0": shops_finished[str(w.stage)+":"+str(w.room_id)]=true
			w.choose(w.choices.find(token)); return
	for i in range(w.choices.size()):
		if w.can_choose(w.choices[i]): w.choose(i); return

func make_world() -> ChapterWorld:
	return ChapterWorld.new()

func tick_limit() -> int:
	return 54000

func simulate(hero: String, seed_value: int) -> Dictionary:
	shops_finished.clear()
	var w=make_world(); w.begin({"seed":seed_value,"character":hero,"camp":{},"choose_oath":false})
	var itinerary: Array=[1,7,9,2,8,3,10,11,4,12,5,6]
	var route_index=0
	var seen_stage=w.stage
	var ticks=0
	while ticks<tick_limit() and w.phase!="finished":
		ticks+=1
		if w.stage!=seen_stage: seen_stage=w.stage; route_index=0
		if w is CampaignWorld and w.chapter_exit_timer>0:
			w.set_controls(w.aim,false); w.update(1.0/60.0,Vector2.ZERO,false); continue
		if w.phase in ["upgrade","oath"]: choose(w); continue
		var p=w.pos(w.player)
		var enemies=w.mobs.filter(func(m): return m.hp>0)
		var move=Vector2.ZERO
		var interacting=false
		if not enemies.is_empty():
			var aim_target=enemies[0]
			for enemy in enemies:
				if w.pos(enemy).distance_squared_to(p)<w.pos(aim_target).distance_squared_to(p): aim_target=enemy
			var toward=w.pos(aim_target)-p
			var desired=100 if w.gear in ["sword","hammer"] else 290
			move=toward.normalized()*clampf((toward.length()-desired)/140,-1,1)+toward.normalized().orthogonal()*0.55
			for enemy in enemies:
				var away=p-w.pos(enemy)
				if away.length()<110: move+=away.normalized()*(110-away.length())/70
			for zone in w.zones:
				if zone.hostile:
					var away=p-w.pos(zone)
					if away.length()<zone.radius+100: move+=away.normalized()*2.0
			w.set_controls(toward,true)
			if w.skill_cd<=0: w.pulse()
			if toward.length()<75 and w.dash_charges>0: w.dash(-toward)
		else:
			w.set_controls(w.aim,false)
			if w.room().type=="shrine" and not w.room().claimed or w.room().type in ["gear","skill","event","rest"] and not w.room().claimed:
				move=(w.room_bounds.get_center()-p).normalized(); interacting=p.distance_to(w.room_bounds.get_center())<100
			elif w.room().type=="shop" and not shops_finished.has(str(w.stage)+":"+str(w.room_id)):
				move=(w.room_bounds.get_center()-p).normalized(); interacting=p.distance_to(w.room_bounds.get_center())<100
			else:
				if route_index<itinerary.size() and w.room_id==itinerary[route_index]: route_index+=1
				if route_index>=itinerary.size(): break
				var route=_path(w,itinerary[route_index])
				if route.size()>1:
					var doors=w.doors().filter(func(d): return d.id==route[1])
					if not doors.is_empty():
						move=(doors[0].position-p).normalized(); interacting=p.distance_to(doors[0].position)<85
		w.update(1.0/60.0,w.navigation_direction(w.player,move),interacting)
	var output={"character":hero,"seed":seed_value,"victory":w.victory,"time":w.time,"ticks":ticks,"room":w.room_id,"stage":w.stage,"bosses":w.bosses,"kills":w.kills,"hp":w.player.hp,"gear":w.gear,"skill":w.skill,"sigils":w.sigils,"relics":w.relics,"rooms_visited":w.result().rooms_cleared,"shrines":w.shrines,"damage_taken":w.total_damage_taken}
	if not w.victory:
		output["diagnostic"]={"phase":w.phase,"offer":w.offer_kind,"choices":w.choices,"player":w.pos(w.player),"alive":w.mobs.filter(func(m): return m.hp>0).map(func(m): return {"kind":m.kind,"hp":m.hp,"position":w.pos(m)}),"route_index":route_index}
	return output

func run() -> void:
	for hero in ["keeper","swordswoman","alchemist"]:
		for seed_value in [4242,8731]:
			var result=simulate(hero,seed_value); reports.append(result); print(JSON.stringify(result))
	var file=FileAccess.open("res://test-output/chapter-playtest.json",FileAccess.WRITE); file.store_string(JSON.stringify(reports,"\t")); file.close()
	var passed=reports.all(func(r): return r.victory and r.rooms_visited>=10 and r.shrines==1)
	Sound.shutdown(); await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if passed else 1)
