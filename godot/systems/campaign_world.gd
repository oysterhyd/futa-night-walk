class_name CampaignWorld
extends ChapterWorld

const CAMPAIGN=preload("res://content/campaign_content.gd")
const CAMPAIGN_KEYS=["chapter_log","chapter_start_kills","chapter_start_time","environment_clock","chapter_exit_timer"]
var chapter_log: Array=[]
var chapter_start_kills=0
var chapter_start_time=0.0
var environment_clock=0.0
var chapter_exit_timer=0.0

func secret_revealed() -> bool:
	return kills-chapter_start_kills>=35 or "map" in relics

func interaction_hint() -> String:
	if chapter_exit_timer>0: return "首领已败 · 等待战利品"
	return super.interaction_hint()

func doors() -> Array:
	var found=super.doors()
	if chapter_exit_timer>0:
		for door in found: door.open=false
	return found

func display_room_name(target: Dictionary) -> String:
	return CAMPAIGN.room_name(stage,target)

func room_reward(target: Dictionary) -> String:
	if target.type=="boss": return "击败 "+biome().boss+("，完成夜行" if stage==4 else "，进入 "+CAMPAIGN.CHAPTERS[stage].name)
	if target.type=="entry": return CAMPAIGN.CHAPTERS[stage-1].rule
	return super.room_reward(target)

func enter_room(target: int, from_direction: Vector2=Vector2.ZERO) -> bool:
	var entered=super.enter_room(target,from_direction)
	if entered: environment_clock=0
	return entered

func _configure_room() -> void:
	super._configure_room()
	if stage>1:
		for prop in decorations:
			if room().type in ["combat","elite","boss"]:
				prop.sprite={2:[2,1,3,0],3:[6,7,4,5],4:[8,10,11,8]}[stage][maxi(0,room().rank-1)%4]
				prop["atlas"]="campaign"
			elif room().type in ["entry","shrine","skill"]:
				prop.sprite=10 if room().type=="skill" else {2:3,3:5,4:8}[stage]
				prop["atlas"]="campaign"
	if stage==2 and room().type in ["combat","elite","boss"]:
		var center=room_bounds.get_center()
		hazards=[{"x":center.x-260,"y":center.y+80,"radius":100.0,"kind":"water"},{"x":center.x+260,"y":center.y-90,"radius":100.0,"kind":"water"}]

func _spawn_wave() -> void:
	if stage==1: super._spawn_wave(); return
	wave_index+=1
	var pool=biome().enemies
	var count=10+room().rank*2+stage
	if contract=="swarm": count=ceili(count*1.35)
	for i in range(count): spawn(pool[rng.randi_range(0,pool.size()-1)],room().type=="elite" and i==0 and wave_index==1)
	if extra_elite and wave_index==1: spawn("stone_guard",true); extra_elite=false
	emit("notice",{"text":"敌潮 %d / %d" % [wave_index,wave_count]})

func _spawn_boss() -> void:
	if stage==1: super._spawn_boss(); return
	var boss=spawn("boss"+str(stage-1),false,true)
	boss.hp=CAMPAIGN.CHAPTERS[stage-1].hp*(1+difficulty*0.2); boss.max_hp=boss.hp
	boss.speed=65 if stage==2 else 38; boss.cooldown=2.8
	set_pos(boss,room_bounds.get_center()+Vector2(0,-180))
	boss_spawned=true
	emit("boss",{"text":biome().boss+" · "+CAMPAIGN.CHAPTERS[stage-1].rule})

func boss_attack(mob: Dictionary) -> void:
	if stage==1: super.boss_attack(mob); return
	mob.attack+=1; mob["cast"]=0.45
	var angry=mob.hp<mob.max_hp*0.5
	if angry and not mob.enraged:
		mob.enraged=true
		emit("enrage",{"x":mob.x,"y":mob.y,"text":biome().boss+" · 狂暴"})
	match stage:
		2:
			if mob.attack%3!=0:
				mob.charging=0.6 if angry else 0.48
				emit("enemy_attack",{"x":mob.x,"y":mob.y,"angle":Vector2(mob.dx,mob.dy).angle(),"source":"enemy"})
			else:
				hostile_fan(mob,14 if angry else 10,155,true)
				for i in range(3 if angry else 2): spawn("mist_fox")
		3:
			if mob.attack%3==1:
				var direction=Vector2(mob.dx,mob.dy)
				for i in range(3): make_zone((pos(mob)+direction*(110+i*140)).clamp(room_bounds.position+Vector2.ONE*65,room_bounds.end-Vector2.ONE*65),85,mob.damage,"enemy",0.35,0.95+i*0.18,true,true)
			elif mob.attack%3==2: hostile_fan(mob,20 if angry else 14,140,true)
			else:
				make_zone(pos(player),140,mob.damage*1.1,"enemy",0.3,1.15,true,true)
				if angry: spawn("stone_guard")
		4:
			var final_phase=mob.hp<mob.max_hp*0.33
			if mob.attack%4==1: hostile_fan(mob,22 if final_phase else 16,145,true)
			elif mob.attack%4==2:
				var p=pos(player)
				for i in range(5 if angry else 3):
					var target=(p+Vector2.from_angle(i*TAU/5)*120*(0 if i==0 else 1)).clamp(room_bounds.position+Vector2.ONE*70,room_bounds.end-Vector2.ONE*70)
					make_zone(target,80,mob.damage,"enemy",0.35,1.1+i*0.12,true,true)
			elif mob.attack%4==3: hostile_fan(mob,7 if angry else 5,215)
			else:
				for i in range(3): spawn("paper_spirit" if i<2 else "stone_guard")
				if final_phase: hostile_fan(mob,12,120,true)
	mob.cooldown=(2.1 if angry else 3.1)*(1-difficulty*0.04)
	emit("boss_art",{"x":mob.x,"y":mob.y,"stage":stage,"angle":Vector2(mob.dx,mob.dy).angle(),"radius":100.0,"attack":mob.attack})

func update_step(dt: float, move: Vector2, interact: bool) -> void:
	super.update_step(dt,move,interact)
	if chapter_exit_timer>0:
		chapter_exit_timer=maxf(0,chapter_exit_timer-dt)
		if chapter_exit_timer==0: _complete_chapter()
		return
	if phase!="active" or room().cleared or room().type not in ["combat","elite","boss"]: return
	environment_clock+=dt
	if environment_clock<9.0: return
	environment_clock=0
	match stage:
		2:
			for water in hazards: make_zone(pos(water),water.radius+15,9+stage*2,"enemy",0.35,1.4,true,true)
			emit("notice",{"text":"涨潮 · 离开水纹区域"})
		3:
			make_zone(pos(player),95,12,"enemy",0.3,1.35,true,true)
			emit("bell",{"x":player.x,"y":player.y})
			emit("notice",{"text":"钟声将落 · 移出红圈"})
		4:
			var center=room_bounds.get_center()
			var side=1 if int(room_age/9)%2==0 else -1
			for i in range(3): make_zone(center+Vector2(side*240,(i-1)*160),95,14,"enemy",0.3,1.5,true,true)
			emit("notice",{"text":"封印爆发 · 避开红圈"})

func finish(won: bool) -> void:
	if not won: super.finish(false); return
	if phase=="finished" or chapter_exit_timer>0 or offer_kind=="chapter_clear" and phase=="upgrade": return
	chapter_exit_timer=1.0; bolts.clear(); zones.clear()

func _complete_chapter() -> void:
	chapter_log.append({"stage":stage,"kills":kills-chapter_start_kills,"seconds":time-chapter_start_time,"rooms":rooms.filter(func(r): return r.visited).size()})
	if stage==4: super.finish(true); return
	bolts.clear(); zones.clear(); mobs.clear()
	_offer("chapter_clear",biome().name+" · 首领已败","下一章："+CAMPAIGN.CHAPTERS[stage].name+"。保留全部构筑，选择一项战利品。",["chapter:0","chapter:1","chapter:2"])

func choose(index: int) -> bool:
	if phase=="upgrade" and offer_kind=="chapter_clear":
		if index<0 or index>=choices.size() or not can_choose(choices[index]): return false
		var boon=int(choices[index].get_slice(":",1))
		if boon==0: heal(player.max_hp*0.35); rerolls+=1
		elif boon==1: attributes.power=int(attributes.get("power",0))+1
		else: attributes.haste=int(attributes.get("haste",0))+1
		stage+=1; sector_damage=0; boss_spawned=false; offer_kind=""; choices.clear(); phase="active"
		rooms.clear(); room_id=0; shop_bought.clear(); proc_timers.clear()
		chapter_start_kills=kills; chapter_start_time=time; clear_delay=0; environment_clock=0
		attack_cd=0; attack_buffer=0; attack_windup=0; shadow_time=0; skill_cd=0; dash_charges=2; dash_recharge=0
		_make_map(); event_id=rng.randi_range(0,3); enter_room(0)
		return true
	return super.choose(index)

func unavailable_reason(token: String) -> String:
	if stage>1 and token.begins_with("event:"):
		if coins<choice_cost(token): return "铜钱不足。"
		var branch=int(token.get_slice(":",1))
		var key=_event_relic(branch)
		if not key.is_empty() and key in relics: return "已持有此遗物。"
		if branch==0 and (stage==2 and event_id%2==1 or stage==3 and event_id%2==1) and player.max_hp<=30: return "生命上限过低，无法交易。"
		if stage==3 and event_id%2==1 and branch==1 and skill_rank<2: return "技能达到二阶后才能改造。"
		if stage==4 and event_id%2==1 and branch==1:
			if contract=="silence": return "禁疗契约已封印生命回复。"
			if player.hp>=player.max_hp: return "生命已满。"
		return ""
	if token=="chapter:0" and contract=="silence": return "禁疗契约封印整备回复，请选择其他战利品。"
	if token=="chapter:2" and attributes.get("haste",0)>=5: return "技能冷却已达到缩短上限。"
	return super.unavailable_reason(token)

func event_definition() -> Dictionary:
	return super.event_definition() if stage==1 else CAMPAIGN.EVENTS[stage-2][event_id%2]

func choice_cost(token: String) -> int:
	if stage>1 and token.begins_with("event:"):
		var branch=int(token.get_slice(":",1))
		return {2:[[0,35,0],[0,30,0]],3:[[40,0,0],[0,25,0]],4:[[0,45,0],[0,30,0]]}[stage][event_id%2][branch]
	return super.choice_cost(token)

func _event_relic(branch: int) -> String:
	return {2:[["reed_sandal","river_coin",""],["fox_mirror","",""]],3:[["bell_shard","",""],["inkstone","",""]],4:[["","tower_key",""],["cinder_mask","",""]]}[stage][event_id%2][branch]

func _choose_event(index: int) -> void:
	if stage==1: super._choose_event(index); return
	if index==2: return
	var event=event_id%2
	match stage:
		2:
			if event==0 and index==0: player.hp=maxf(1,player.hp-15)
			elif event==1 and index==0: player.max_hp-=15; player.hp=minf(player.hp,player.max_hp)
			elif event==1: rerolls+=2
		3:
			if event==0 and index==1: rerolls+=2; extra_elite=true
			elif event==1 and index==0: player.max_hp-=15; player.hp=minf(player.hp,player.max_hp)
			elif event==1: skill_mod=-1; _skill_mod_offer()
		4:
			if event==0 and index==0: coins+=70; extra_elite=true
			elif event==1 and index==0: player.hp=maxf(1,player.hp-20); curse_damage=true
			elif event==1: heal(player.max_hp*0.4)
	var key=_event_relic(index)
	if not key.is_empty(): _offer("relic","奇遇所得 · "+C.RELICS[key].name,"收入行囊；遗物满六件时可以替换，放弃可折算 25 铜钱。",["r:"+key])

func chapter_choice_info(token: String) -> Dictionary:
	if token.begins_with("chapter:"):
		var item=CAMPAIGN.BOONS[int(token.get_slice(":",1))]
		return {"name":item.name,"desc":item.desc,"glyph":item.glyph,"tag":"章节战利品 · 只能选一项","note":unavailable_reason(token),"color":Color("ad3527")}
	return super.chapter_choice_info(token)

func result() -> Dictionary:
	var output=super.result()
	output.ruleset="nightroad_campaign"; output["chapters"]=chapter_log.duplicate(true)
	output.rooms_cleared=rooms.filter(func(r): return r.visited).size()
	for record in chapter_log:
		if record.stage<stage: output.rooms_cleared+=record.rooms
	return output

func snapshot() -> Dictionary:
	var raw=super.snapshot()
	raw.version=6; raw.ruleset="nightroad_campaign"
	for key in CAMPAIGN_KEYS: raw[key]=get(key).duplicate(true) if get(key) is Array else get(key)
	return raw

func valid_snapshot(raw: Dictionary) -> bool:
	if raw.get("version")==5 and raw.get("ruleset")=="chapter_one": return super.valid_snapshot(raw)
	if raw.get("version")!=6 or raw.get("ruleset")!="nightroad_campaign" or not numeric(raw.get("stage"),1,4,true): return false
	if not raw.get("mobs") is Array or not raw.get("decorations") is Array or not raw.get("choices") is Array or not raw.get("phase") is String or not raw.get("offer_kind") is String or not raw.get("victory") is bool: return false
	if not raw.get("chapter_log") is Array or raw.chapter_log.size()>4: return false
	for i in range(raw.chapter_log.size()):
		var value=raw.chapter_log[i]
		if not record(value,["stage","kills","seconds","rooms"]) or value.stage!=i+1 or not numeric(value.rooms,1,14,true) or value.kills<0 or value.seconds<0: return false
	if not numeric(raw.get("chapter_start_kills"),0,raw.get("kills",0),true) or not numeric(raw.get("chapter_start_time"),0,raw.get("time",0)) or not numeric(raw.get("environment_clock"),0,9.1) or not numeric(raw.get("chapter_exit_timer"),0,1): return false
	if raw.chapter_log.size()!=raw.stage-1 and not (raw.phase=="finished" and raw.victory and raw.stage==4 and raw.chapter_log.size()==4) and not (raw.phase=="upgrade" and raw.offer_kind=="chapter_clear" and raw.chapter_log.size()==raw.stage): return false
	var normalized=raw.duplicate(true)
	normalized.version=5; normalized.ruleset="chapter_one"; normalized.stage=1
	if raw.get("offer_kind")=="chapter_clear" and raw.phase=="upgrade":
		if raw.stage>=4 or raw.choices!=["chapter:0","chapter:1","chapter:2"]: return false
		normalized.phase="active"; normalized.choices=[]; normalized.offer_kind=""
	for mob in normalized.get("mobs",[]):
		if not mob is Dictionary: return false
		if mob.get("boss",false):
			if mob.get("kind")!="boss"+str(raw.stage-1): return false
			mob.kind="boss0"
	for prop in raw.get("decorations",[]):
		if not prop is Dictionary or prop.get("atlas","market") not in ["market","campaign"]: return false
	return super.valid_snapshot(normalized)

func restore(raw: Dictionary) -> bool:
	if not valid_snapshot(raw): return false
	if not super.restore(raw): return false
	if raw.version==6:
		for key in CAMPAIGN_KEYS: set(key,raw[key].duplicate(true) if raw[key] is Array else raw[key])
	else:
		chapter_log=[]; chapter_start_kills=0; chapter_start_time=0; environment_clock=0; chapter_exit_timer=0
	return true
