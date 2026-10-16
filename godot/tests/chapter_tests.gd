extends Node

var checks=0
var failures: Array=[]

func expect(value: bool, label_text: String) -> void:
	checks+=1
	if not value: failures.append(label_text); push_error(label_text)

func fresh(seed_value: int=4242) -> ChapterWorld:
	var w=ChapterWorld.new()
	w.begin({"seed":seed_value,"choose_oath":false})
	return w

func steps(w: ChapterWorld, count: int) -> void:
	for i in range(count): w.update(1.0/60.0)

func target(w: ChapterWorld, health: float=1000) -> Dictionary:
	var mob=w.spawn("stone_guard")
	mob.hp=health; mob.max_hp=health; mob.speed=0; mob.cooldown=999
	w.set_pos(mob,w.pos(w.player)+Vector2(110,0)); w.rebuild_index()
	return mob

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	for seed_value in range(24):
		var w=fresh(seed_value)
		var found: Array=[0]
		var cursor=0
		while cursor<found.size():
			var r=w.rooms[found[cursor]]
			for other in w.rooms:
				if abs(other.gx-r.gx)+abs(other.gy-r.gy)==1 and other.id not in found: found.append(other.id)
			cursor+=1
		expect(found.size()==14,"seed %d: all rooms connected" % seed_value)
		expect(w.rooms.filter(func(r): return r.type=="combat").size()==4,"seed %d: four main encounters" % seed_value)
	var w=fresh()
	var mob=target(w)
	steps(w,30)
	expect(mob.hp==mob.max_hp,"no automatic attacks without input")
	w.request_attack(); steps(w,10)
	expect(w.attack_count==1,"brief click is buffered without requiring held attack")
	w.set_controls(Vector2.RIGHT,true); steps(w,30)
	expect(mob.hp<mob.max_hp,"held manual attack damages target")
	w.set_controls(Vector2.RIGHT,false)
	expect(w.dash(Vector2.RIGHT) and w.dash(Vector2.LEFT),"two independent dash charges")
	expect(not w.dash(Vector2.RIGHT),"third dash rejected")
	steps(w,181)
	expect(w.dash_charges==1,"dash charge replenishes over time")
	w.skill_cd=0
	expect(w.pulse() and not w.pulse(),"skill cooldown prevents duplicate casts")
	for key in ChapterContent.GEAR:
		w=fresh(); w.gear=key; w.weapons={ChapterContent.GEAR[key].source:1}
		mob=target(w); w.set_controls(Vector2.RIGHT,true); steps(w,70)
		expect(mob.hp<mob.max_hp,"gear works: "+key)
		for mod in [0,1]:
			w=fresh(); w.gear=key; w.gear_rank=2; w.gear_mod=mod
			mob=target(w); w.set_controls(Vector2.RIGHT,true); steps(w,90)
			expect(mob.hp<mob.max_hp,"gear modifier works: %s/%d" % [key,mod])
	for key in ChapterContent.SKILLS:
		for mod in [-1,0,1]:
			w=fresh(); w.skill=key; w.skill_mod=mod; mob=target(w)
			expect(w.pulse(),"skill casts: %s/%d" % [key,mod])
			w.set_controls(Vector2.RIGHT,true); steps(w,75)
			expect(mob.hp<mob.max_hp,"skill/attack interaction works: %s/%d" % [key,mod])
	w=fresh(); w.skill="shadow"; mob=target(w); w.pulse(); steps(w,20)
	expect(mob.hp==mob.max_hp and w.bolts.is_empty(),"shadows never attack without player input")
	w._attack()
	expect(w.bolts.filter(func(b): return b.source=="shadow_twin" and not b.primary).size()==2,"shadow skill adds two nonrecursive copies of manual attack")
	w=fresh(); mob=target(w); w.sigils={"fire":1}; w._primary_hit(mob,22,"fire_talisman",false)
	expect(mob.burn_dps>=8,"fire sigil adds damage even to an existing fire weapon")
	w=fresh(); w.gear="sword"; w.skill="shadow"; w.skill_rank=3; w.pulse(); w._attack()
	var copies=w.bolts.filter(func(b): return b.source=="shadow_twin")
	expect(is_equal_approx(copies[0].damage,30*0.35*1.4) and copies[0].life*660>=360,"shadow rank increases real damage and grants useful ranged reach")
	w=fresh(); w.skill="poison"; w.skill_rank=2; w.skill_mod=0; w.pulse()
	expect(w.zones.size()==1 and w.zones[0].radius==180 and w.zones[0].life==8,"poison upgrade changes both duration and area")
	w=fresh(); w.skill="blast"; w.skill_rank=2; w.skill_mod=0; w.pulse()
	expect(w.zones.size()==3 and w.zones[1].warning>w.zones[0].warning,"blast upgrade adds delayed secondary explosions")
	w=fresh(); w.skill_rank=2; w.skill_mod=1; w.pulse()
	expect(w.shield==20,"defensive pulse upgrade grants actual shield")
	w=fresh(); w.skill="binding"; mob=target(w); mob.windup=0.4; var original_position=w.pos(mob); w.pulse()
	expect(mob.stun>=1.5 and mob.windup==0 and w.pos(mob)!=original_position,"binding pulls enemies and cancels pending attack")
	w=fresh(); w.enter_room(6); var boss=w.mobs.filter(func(m): return m.boss)[0]
	w._control(boss,1.5); w._control(boss,1.5)
	expect(boss.stun>=1.2 and boss.vulnerable>0,"control creates a boss damage window instead of infinite freeze")
	w=fresh(); w.gear="sword"; w.skill="shadow"
	for i in range(12):
		w.roll_choices()
		expect(w.choices.any(func(token): return token.begins_with("p:") and w._sigil_compatible(token.get_slice(":",1))),"growth always includes one applicable mechanic")
	w=fresh(); w.skill="shadow"; w.pulse(); w._offer("skill","","",["s:blast"]); w.choose(0)
	expect(w.shadow_time==0 and w.skill=="blast","skill replacement cancels old skill output")
	w=fresh(); mob=target(w)
	w.apply_element(mob,"poison_mist",25); w.apply_element(mob,"fire_talisman",25)
	expect(w.reactions.get("燃瘴",0)==1,"fire and poison reaction")
	mob.reaction_cd=0; w.apply_element(mob,"frost_sand",25); mob.reaction_cd=0; w.apply_element(mob,"thunder_mark",25)
	expect(w.reactions.get("引雷",0)>0,"frost and thunder reaction")
	w=fresh(); w.player.invulnerable=0; w.shield=20; var before=w.player.hp
	w.hurt(12)
	expect(w.player.hp==before and w.shield==8,"shield absorbs actual damage")
	w.player.invulnerable=0; w.relics=["old_wick"]; w.hurt(500)
	expect(w.player.hp>0 and w.resurrected,"wick rescues fatal damage once")
	w.player.invulnerable=0; w.hurt(500)
	expect(w.phase=="finished" and not w.victory,"wick cannot rescue twice")
	w=fresh(); w.enter_room(1)
	expect(not w.enter_room(0),"battle doors locked before clearance")
	for i in range(8):
		for enemy in w.mobs: w.hit(enemy,100000,"pulse")
		w.update(1.0/60.0)
		if w.phase=="upgrade": break
	steps(w,45)
	expect(w.room().cleared and w.phase=="upgrade","finite enemy waves produce one clear reward")
	w.choose(0); w.enter_room(0); w.enter_room(1)
	expect(w.mobs.is_empty() and w.phase=="active","cleared room never respawns reward or enemies")
	w=fresh(); w.coins=0; w._shop_offer()
	expect(not w.choose(w.choices.find("shop:gear")) and w.coins==0,"shop cannot charge missing money")
	w.coins=100
	expect(not w.can_choose("shop:heal"),"full health never wastes money on healing")
	w.coins=100; expect(w.choose(w.choices.find("shop:gear")),"shop gear purchase")
	expect(w.coins==65 and w.gear_rank==2 and w.offer_kind=="gear_mod","purchase pays once and opens modifier choice")
	w.choose(0); w._shop_offer()
	expect("shop:gear" not in w.choices,"purchased product cannot be bought repeatedly")
	w._offer("gear","","",["g:sword"]); w.choose(0)
	expect(w.gear=="sword" and w.gear_rank==2 and w.weapons.size()==1,"gear replacement preserves rank and one slot")
	w.choose(1)
	expect(w.gear_mod==1,"replacement chooses the new weapon modifier")
	w=fresh(); w.sigils={"counter":1,"fire":1,"toxin":1,"ember":1,"execution":1,"precision":1}
	w._offer("growth","","",["p:wind"]); w.choose(0)
	expect(w.sigils.size()==6 and w.offer_kind=="replace_sigil","seventh sigil requires replacement")
	w.choose(0)
	expect(w.sigils.size()==6 and w.sigils.has("wind"),"sigil replacement respects cap")
	w=fresh(); w.relics=ChapterContent.RELICS.keys().slice(0,6)
	w._offer("relic","","",["r:broken_coin"]); w.choose(0)
	expect(w.relics.size()==6 and w.offer_kind=="replace_relic","seventh relic requires replacement")
	w.choose(0)
	expect(w.relics.size()==6 and "broken_coin" in w.relics,"relic replacement respects cap")
	w=fresh(); w.enter_room(1); w.set_controls(Vector2(1,0.3),true); steps(w,25)
	var ritual=fresh(); ritual.enter_room(11); ritual.shrine_started=true; ritual.shrine_round=2
	ritual.update(1.0/60.0); ritual.choose(ritual.choices.find("coin:25"))
	var ritual_coins=ritual.coins
	steps(ritual,180)
	expect(ritual.shrines==1 and ritual.coins==ritual_coins and ritual.phase=="active","completed shrine cannot repeatedly grant rewards")
	var snap=w.snapshot(); var restored=ChapterWorld.new()
	expect(w.valid_snapshot(snap) and restored.restore(snap),"combat snapshot validates and restores")
	w.set_controls(Vector2.RIGHT,false); restored.set_controls(Vector2.RIGHT,false)
	steps(w,40); steps(restored,40)
	expect(w.snapshot()==restored.snapshot(),"RNG and combat state resume deterministically")
	var corrupt=snap.duplicate(true); corrupt.sigils={"unknown":3}
	var stable=restored.snapshot()
	expect(not restored.restore(corrupt) and restored.snapshot()==stable,"invalid restore is atomic")
	for field in ["bad_room","bad_choice","bad_bolt","bad_timer","bad_vector"]:
		corrupt=snap.duplicate(true)
		match field:
			"bad_room": corrupt.rooms[2].gx=corrupt.rooms[1].gx
			"bad_choice": corrupt.phase="upgrade"; corrupt.offer_kind="growth"; corrupt.choices=["p:unknown"]
			"bad_bolt": corrupt.bolts=[{"x":0}]
			"bad_timer": corrupt.proc_timers={"ember":"broken"}
			"bad_vector": corrupt.aim=Vector2(INF,0)
		expect(not restored.restore(corrupt) and restored.snapshot()==stable,"nested corruption rejected atomically: "+field)
	Save.directory="user://chapter-rules/"; Save.clear_run()
	expect(Save.save_run(w) and not Save.read_run().is_empty(),"new ruleset saved through real store")
	var output={"passed":failures.is_empty(),"checks":checks,"failures":failures}
	var file=FileAccess.open("res://test-output/chapter-tests.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(output,"\t")); file.close()
	print(JSON.stringify(output))
	Sound.shutdown(); await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
