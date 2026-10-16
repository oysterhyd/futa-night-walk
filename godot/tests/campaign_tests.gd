extends Node

var checks=0
var failures: Array=[]

func expect(condition: bool, label_text: String) -> void:
	checks+=1
	if not condition: failures.append(label_text); push_error(label_text)

func advance(w: CampaignWorld, seconds: float) -> void:
	for i in range(ceili(seconds*60)): w.update(1.0/60,Vector2.ZERO,false)

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	Save.directory="user://campaign-rules/"; Save.profile=Save.defaults(); Save.clear_run()
	var w=CampaignWorld.new(); w.begin({"seed":4242,"choose_oath":false})
	w.gear="sword"; w.gear_rank=3; w.gear_mod=0; w.weapons={"piercing_spike":3}
	w.skill="shadow"; w.skill_rank=3; w.skill_mod=1; w.sigils={"echo":2,"cleave":1}; w.relics=["fox_tooth"]
	for stage_number in range(1,5):
		expect(w.stage==stage_number,"chapter sequence: "+str(stage_number))
		expect(w.rooms.size()==14,"full exploration map: "+str(stage_number))
		expect(w.display_room_name(w.rooms[1])==CampaignContent.CHAPTERS[stage_number-1].combat[0],"destination names match actual room: "+str(stage_number))
		expect(w.enter_room(6),"enter boss room: "+str(stage_number))
		var boss=w.mobs.filter(func(m): return m.boss)[0]
		expect(boss.kind=="boss"+str(stage_number-1),"chapter boss identity: "+str(stage_number))
		if stage_number>1:
			boss.dx=1; boss.dy=0; boss.attack=0; w.boss_attack(boss)
			if stage_number==2: expect(boss.charging>0,"fox boss has committed dash")
			if stage_number==3: expect(w.zones.size()==3,"bell boss lays three delayed slams")
			if stage_number==4: expect(w.bolts.size()==16,"tower boss opens with radial seal pattern")
			w.environment_clock=8.99; var count=w.zones.size(); w.update(0.02,Vector2.ZERO,false)
			expect(w.zones.size()>count,"chapter environment produces telegraphed danger: "+str(stage_number))
		expect(w.valid_snapshot(w.snapshot()),"live boss snapshot valid: "+str(stage_number))
		expect(Save.save_run(w) and Save.valid_run(Save.read_run()),"actual store accepts chapter: "+str(stage_number))
		var restored=CampaignWorld.new()
		expect(restored.restore(w.snapshot()) and restored.snapshot()==w.snapshot(),"chapter snapshot exact restore: "+str(stage_number))
		var stable=restored.snapshot()
		for field in ["stage","environment_clock","chapter_log","mobs"]:
			var bad=stable.duplicate(true)
			match field:
				"stage": bad.stage=9
				"environment_clock": bad.environment_clock=INF
				"chapter_log": bad.chapter_log=[{"stage":4}]
				"mobs": bad.mobs="invalid"
			expect(not restored.restore(bad) and restored.snapshot()==stable,"atomic rejection: "+str(stage_number)+"/"+field)
		w.hit(boss,1000000,"pulse")
		expect(w.phase=="active" and w.chapter_exit_timer>0,"boss defeat animation has time to finish: "+str(stage_number))
		expect(w.doors().all(func(door): return not door.open),"cannot leave during boss defeat: "+str(stage_number))
		advance(w,1.1)
		if stage_number<4:
			expect(w.phase=="upgrade" and w.offer_kind=="chapter_clear" and not w.victory,"boss gives chapter reward instead of final victory: "+str(stage_number))
			expect(w.valid_snapshot(w.snapshot()),"pending chapter reward is saveable: "+str(stage_number))
			expect(w.choose(1),"chapter reward advances journey: "+str(stage_number))
			expect(w.gear_rank==3 and w.gear_mod==0 and w.skill_rank==3 and w.sigils.echo==2 and "fox_tooth" in w.relics,"build survives chapter: "+str(stage_number))
			expect(w.room_id==0 and w.shop_bought.is_empty() and w.skill_cd==0 and w.dash_charges==2,"new chapter resets local state: "+str(stage_number))
		else:
			expect(w.phase=="finished" and w.victory and w.bosses==4,"only final boss completes all four chapters")
			expect(w.chapter_log.size()==4 and w.result().chapters.size()==4,"four chapter records retained")
	var old=ChapterWorld.new(); old.begin({"seed":8731,"choose_oath":false})
	old.obstacles=[{"x":800.0,"y":475.0,"radius":38.0}]; old.set_pos(old.player,Vector2(1000,475))
	for i in range(600):
		var direction=old.navigation_direction(old.player,Vector2(500,475)-old.pos(old.player))
		old.move_entity(old.player,direction*3.0)
	expect(old.pos(old.player).distance_to(Vector2(500,475))<15,"navigation escapes a collinear obstacle without pushing against it")
	var migrated=CampaignWorld.new()
	expect(migrated.restore(old.snapshot()) and migrated.stage==1 and migrated.valid_snapshot(migrated.snapshot()),"2.0 active run migrates into full journey")
	var result=Save.settle(w)
	expect(Save.valid_result(result) and Save.profile.victories==1,"campaign result settles to persistent profile")
	var embers=Save.profile.embers; Save.settle(w)
	expect(Save.profile.embers==embers,"campaign settlement is idempotent")
	var report={"checks":checks,"passed":failures.is_empty(),"failures":failures,"scope":"Four chapter lifecycle, distinct boss patterns, environment telegraphs, build carry, native save/migration and atomic invalid-state rejection. State fixtures; not a natural playthrough."}
	var file=FileAccess.open("res://test-output/campaign-tests.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); print(JSON.stringify(report))
	Sound.shutdown(); await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
