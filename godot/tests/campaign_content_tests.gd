extends Node

var checks=0
var failures: Array=[]

func expect(value: bool, label_text: String) -> void:
	checks+=1
	if not value: failures.append(label_text); push_error(label_text)

func fresh(stage_number: int=1, options: Dictionary={}) -> CampaignWorld:
	var w=CampaignWorld.new(); options=options.duplicate(); options.seed=4242; options.choose_oath=false; w.begin(options)
	w.stage=stage_number
	for i in range(1,stage_number): w.chapter_log.append({"stage":i,"kills":0,"seconds":0.0,"rooms":1})
	w.enter_room(0)
	return w

func target(w: CampaignWorld) -> Dictionary:
	var mob=w.spawn("stone_guard"); mob.hp=1000; mob.max_hp=1000; mob.cooldown=999; mob.speed=0
	w.set_pos(mob,w.pos(w.player)+Vector2(90,0)); w.rebuild_index()
	return mob

func run_events() -> void:
	for stage_number in range(2,5):
		for event in range(2):
			for branch in range(3):
				var w=fresh(stage_number); w.event_id=event; w.coins=100; w.player.hp=50; w.skill_rank=2; w.skill_mod=0
				w.enter_room(10); w.interact_nearby()
				var label="chapter event %d/%d/%d" % [stage_number,event,branch]
				expect(w.offer_title==CampaignContent.EVENTS[stage_number-2][event].name,label+" has its own authored text")
				var before=w.snapshot(); var copy=CampaignWorld.new()
				expect(copy.restore(before) and copy.snapshot()==before,label+" pending choice restores exactly")
				var cost=w.choice_cost("event:"+str(branch)); var expected_relic=w._event_relic(branch)
				expect(w.choose(branch) and w.room().claimed,label+" commits one choice")
				var income=70 if stage_number==4 and event==0 and branch==0 else 0
				expect(w.coins==100-cost+income,label+" charges the displayed price")
				if not expected_relic.is_empty():
					expect(w.choices==["r:"+expected_relic] and w.choose(0) and expected_relic in w.relics,label+" grants the named relic")
				elif stage_number==3 and event==1 and branch==1:
					expect(w.offer_kind=="skill_mod" and w.choose(1) and w.skill_mod==1,label+" changes skill form at retained rank")
				if stage_number==2 and event==0 and branch==0: expect(w.player.hp==35,label+" spends current health")
				if stage_number in [2,3] and event==1 and branch==0: expect(w.player.max_hp==95,label+" spends max health")
				if stage_number==3 and event==0 and branch==1 or stage_number==4 and event==0 and branch==0: expect(w.extra_elite,label+" schedules its risk")
				if stage_number==4 and event==1 and branch==0: expect(w.curse_damage and w.player.hp==30,label+" applies both costs")
				if stage_number==4 and event==1 and branch==1: expect(w.player.hp==94,label+" heals stated percentage")
				expect(w.valid_snapshot(w.snapshot()),label+" result remains saveable")
				var stable=w.snapshot(); w.interact_nearby()
				expect(w.snapshot()==stable,label+" cannot be collected twice")
	var poor=fresh(2); poor.event_id=0; poor.coins=34
	poor._offer("event","","",["event:1"]); var before=poor.snapshot()
	expect(not poor.choose(0) and poor.snapshot()==before,"unaffordable chapter trade is atomic")
	poor.relics=["river_coin"]; poor.coins=100
	expect(not poor.can_choose("event:1"),"unique relic cannot be bought twice")
	var silence=fresh(4,{"contract":"silence"}); silence.event_id=1; silence.player.hp=30; silence.coins=100
	expect(not silence.can_choose("event:1"),"tower healing obeys silence contract")
	var crowded=fresh(3); crowded.event_id=0; crowded.coins=100; crowded.relics=["fox_tooth","silver","map","old_wick","red_thread","green_lamp"]
	crowded.enter_room(10); crowded.interact_nearby(); crowded.choose(0); crowded.choose(0)
	expect(crowded.offer_kind=="replace_relic" and crowded.valid_snapshot(crowded.snapshot()),"chapter relic supports full inventory and pending save")
	crowded.choose(0)
	expect(crowded.relics.size()==6 and "bell_shard" in crowded.relics,"chapter relic replacement preserves six-slot cap")

func run_builds() -> void:
	var w=fresh(); w.relics=["river_coin"]; w.event_id=0
	expect(w.choice_cost("shop:relic")==40 and w.choice_cost("shop:gear")==28 and w.choice_cost("event:1")==20,"shop discount excludes event prices")
	w.relics=["inkstone"]; w._offer("growth","","",["p:focus"])
	expect("0 → 2" in w.chapter_choice_info("p:focus").tag and w.choose(0) and w.sigils.focus==2,"inkstone preview matches actual acquisition rank")
	w._offer("growth","","",["p:focus"]); w.choose(0)
	expect(w.sigils.focus==3,"inkstone upgrades existing sigil by one")
	w.sigils={"fire":1,"counter":1,"echo":1,"ward":1,"wind":1,"reach":1}; w._offer("growth","","",["p:focus"]); w.choose(0); w.choose(0)
	expect(w.sigils.size()==6 and w.sigils.focus==2,"inkstone also applies on full-slot replacement")
	w=fresh(); w.sigils={"reach":3,"pierce":2}; w._projectile(w.pos(w.player),Vector2.RIGHT,10,"fire_talisman",0,false)
	expect(w.bolts[0].pierce==2 and is_equal_approx(w.bolts[0].life*660,650*1.24),"range and pierce affect primary projectiles")
	w._projectile(w.pos(w.player),Vector2.RIGHT,10,"shadow_twin",1,false,false)
	expect(w.bolts[1].pierce==1 and is_equal_approx(w.bolts[1].life*660,650),"shadow projectiles do not inherit primary sigils")
	w=fresh(); w.sigils={"frozen":2}; var mob=target(w); mob.slow=2; w.hit(mob,100,"pulse")
	expect(is_equal_approx(mob.hp,876),"frozen damage requires the target status")
	w=fresh(); w.relics=["tower_key"]; mob=target(w); w.hit(mob,100,"pulse")
	expect(is_equal_approx(mob.hp,908),"tower key reduces non-boss damage")
	mob.boss=true; mob.hp=1000; w.hit(mob,100,"pulse")
	expect(is_equal_approx(mob.hp,880),"tower key increases boss damage")
	w=fresh(); w.relics=["cinder_mask"]; w.player.hp=40; mob=target(w); w.hit(mob,100,"fire_talisman")
	expect(is_equal_approx(mob.hp,875),"cinder mask boosts low-health fire")
	w.player.hp=w.player.max_hp; mob.hp=1000; w.hit(mob,100,"fire_talisman")
	expect(is_equal_approx(mob.hp,900),"cinder mask does not boost at full health")
	w=fresh(); w.relics=["temple_beads"]; w.skill="shadow"; w.player.hp=50; w.pulse(); w.skill_cd=0; w.pulse()
	expect(w.player.hp==52 and w.proc_timers.beads==3 and w.valid_snapshot(w.snapshot()),"beads heal once and persist their cooldown")
	w.contract="silence"; w.proc_timers.clear(); w.skill_cd=0; w.pulse()
	expect(w.player.hp==52,"beads respect silence")
	var a=fresh(); var b=fresh(); b.relics=["reed_sandal"]; a.dash(Vector2.RIGHT); b.dash(Vector2.RIGHT)
	var origin=a.player.x
	for i in range(6): a.update(1.0/60); b.update(1.0/60)
	expect(is_equal_approx((b.player.x-origin)/(a.player.x-origin),1.2) and is_equal_approx(a.player.invulnerable,b.player.invulnerable),"sandals extend distance without extending invulnerability")
	w=fresh(); w.relics=["bell_shard"]; mob=target(w); mob.boss=true; mob.windup=1; mob.charging=1
	w._control(mob,1); w._control(mob,1)
	expect(mob.stun==1.6 and mob.windup==0 and mob.charging==0,"bell shard breaks boss poise and cancels the committed attack")
	a=fresh(); b=fresh(); a.skill="shadow"; b.skill="shadow"; b.sigils={"focus":2}; b.relics=["fox_mirror"]
	for world in [a,b]: world.pulse(); world._attack()
	var ghosts_a=a.bolts.filter(func(bolt): return bolt.source=="shadow_twin")
	var ghosts_b=b.bolts.filter(func(bolt): return bolt.source=="shadow_twin")
	expect(ghosts_a.size()==2 and ghosts_b.size()==3,"fox mirror adds one actual shadow projectile")
	expect(is_equal_approx(ghosts_b[0].damage/ghosts_a[0].damage,1.16),"focus scales shadow skill damage")
	a=fresh(); b=fresh(); b.relics=["fox_mirror"]; a._attack(); b._attack()
	expect(is_equal_approx(b.bolts[0].damage/a.bolts[0].damage,1.1),"fox mirror fallback boosts ordinary primary damage")
	for key in ChapterContent.RELICS:
		w=fresh(); w.relics=[key]
		expect(Save.valid_result(w.result()) and w.valid_snapshot(w.snapshot()),"new relic accepted by history and run save: "+key)

func run_modes() -> void:
	for stage_number in range(1,5):
		var a=fresh(stage_number,{"mode":"daily","difficulty":3,"character":"alchemist","contract":"fragile","camp":{"vigor":8}})
		var b=fresh(stage_number,{"mode":"daily"})
		a.enter_room(1); b.enter_room(1)
		for i in range(120):
			for w in [a,b]: w.set_controls(Vector2.RIGHT,true); w.update(1.0/60,Vector2.DOWN)
		var sa=a.snapshot(); var sb=b.snapshot(); sa.erase("run_id"); sb.erase("run_id")
		expect(sa==sb,"daily deterministic chapter "+str(stage_number))
		var base=fresh(stage_number); base.enter_room(1)
		var swarm=fresh(stage_number,{"contract":"swarm"}); swarm.enter_room(1)
		expect(swarm.mobs.size()==ceili(base.mobs.size()*1.35),"swarm chapter "+str(stage_number))
		for difficulty in range(4):
			var hard=fresh(stage_number,{"difficulty":difficulty}); hard.enter_room(6)
			var boss=hard.mobs.filter(func(m): return m.boss)[0]
			if stage_number>1: expect(is_equal_approx(boss.max_hp,CampaignContent.CHAPTERS[stage_number-1].hp*(1+difficulty*0.2)),"boss health difficulty %d/%d" % [stage_number,difficulty])
			boss.hp=boss.max_hp*0.3; boss.dx=1; boss.dy=0
			for attack in range(4): hard.boss_attack(boss)
			expect(boss.enraged and hard.valid_snapshot(hard.snapshot()),"all enraged boss attacks remain saveable %d/%d" % [stage_number,difficulty])
		var malformed=base.snapshot(); malformed.decorations=7
		expect(not base.restore(malformed),"malformed chapter props rejected safely "+str(stage_number))

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Save.directory="user://campaign-content-tests/"; Save.profile=Save.defaults()
	run_events(); run_builds(); run_modes()
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"scope":"All six new chapter events and branches; prices/costs/one-time claims/full-slot/save; new sigils and relic effects; four-chapter daily determinism, swarm and boss patterns at all difficulties. State fixtures, not human balance evidence."}
	var file=FileAccess.open("res://test-output/campaign-content-tests.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); print(JSON.stringify(report))
	Sound.shutdown(); await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
