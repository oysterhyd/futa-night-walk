extends Node

var failures: Array=[]
var checks=0

func expect(value: bool, label_text: String) -> void:
	checks+=1
	if not value: failures.append(label_text); push_error(label_text)

func fresh(options: Dictionary={}) -> ChapterWorld:
	var w=ChapterWorld.new(); options=options.duplicate(true); options["seed"]=8731; options["choose_oath"]=false; w.begin(options)
	return w

func _ready() -> void:
	call_deferred("run")

func run() -> void:
	var base=fresh(); base.enter_room(1)
	var swarm=fresh({"contract":"swarm"}); swarm.enter_room(1)
	expect(swarm.mobs.size()==ceili(base.mobs.size()*1.35),"swarm contract increases actual wave size by 35 percent")
	var fragile=fresh({"contract":"fragile"})
	expect(is_equal_approx(fragile.player.max_hp,77) and is_equal_approx(fragile.stat("damage"),1.25),"fragile trades max health for damage")
	var silence=fresh({"contract":"silence"}); silence.player.hp=30; silence.heal(50)
	expect(silence.player.hp==30,"silence blocks all healing")
	var hard=fresh({"difficulty":3}); hard.enter_room(1)
	expect(hard.mobs[0].max_hp>base.mobs[0].max_hp and hard.mobs[0].damage>base.mobs[0].damage,"higher difficulty scales real enemies")
	var daily_a=fresh({"mode":"daily","character":"alchemist","difficulty":3,"contract":"fragile","camp":{"vigor":8,"focus":8,"stride":8,"fortune":8}})
	var daily_b=fresh({"mode":"daily"})
	expect(daily_a.character=="keeper" and daily_a.difficulty==0 and daily_a.contract=="none" and daily_a.camp.is_empty(),"daily overrides character, difficulty, contract and camp")
	expect(daily_a.player.max_hp==daily_b.player.max_hp and daily_a.rooms==daily_b.rooms,"daily starts with identical stats and map")
	daily_a.enter_room(1); daily_b.enter_room(1)
	for i in range(900):
		for w in [daily_a,daily_b]:
			w.set_controls(Vector2.from_angle(i*0.01),true)
			w.update(1.0/60,Vector2.from_angle(i*0.002),false)
			if w.phase=="upgrade": w.choose(0)
	var a=daily_a.snapshot(); var b=daily_b.snapshot(); a.erase("run_id"); b.erase("run_id")
	expect(a==b,"same daily inputs preserve identical full simulation and RNG")
	var geometries: Dictionary={}
	for seed_value in range(20):
		var w=ChapterWorld.new(); w.begin({"seed":seed_value,"choose_oath":false})
		geometries[str(w.rooms.map(func(r): return [r.gx,r.gy]))]=true
	expect(geometries.size()>10,"branch connections vary across seeds")
	var secret=fresh()
	expect(not secret.doors().any(func(d): return d.id==13),"secret passage hidden before unlock")
	secret.kills=35
	expect(secret.doors().any(func(d): return d.id==13),"secret passage revealed by kill threshold")
	secret.enter_room(13); secret.interact_nearby(); secret.choose(0)
	var secret_coins=secret.coins; var secret_relics=secret.relics.duplicate()
	secret.interact_nearby()
	expect(secret.room().claimed and secret.coins==secret_coins and secret.relics==secret_relics and not secret_relics.is_empty(),"secret treasure grants exactly one reward")
	for event_id in range(4):
		for branch in range(3):
			var w=fresh(); w.event_id=event_id; w.coins=100; w.player.hp=50
			w._offer("event","","",["event:"+str(branch)])
			expect(w.choose(0),"event has working choice: %d/%d" % [event_id,branch])
			expect(w.player.hp>0 and w.coins>=0 and w.valid_snapshot(w.snapshot()),"event state remains valid: %d/%d" % [event_id,branch])
	Save.directory="user://chapter-modes/"; Save.profile=Save.defaults(); Save.clear_run()
	var pending=fresh(); pending.roll_choices()
	expect(Save.save_run(pending),"pending card choices saved")
	var copy=ChapterWorld.new()
	expect(copy.restore(Save.read_run()) and copy.choices==pending.choices and copy.offer_kind==pending.offer_kind,"pending card choices restore exactly")
	Save.save_run(pending)
	var primary=FileAccess.open(Save.directory+"expedition.save",FileAccess.WRITE); primary.store_string("corrupt"); primary.close()
	expect(not Save.read_run().is_empty(),"corrupted primary falls back to valid chapter backup")
	var result=fresh({"mode":"daily"}); result.finish(true)
	var settled=Save.settle(result); var embers=Save.profile.embers
	Save.settle(result)
	expect(Save.profile.embers==embers and Save.profile.history.size()==1,"settlement stays idempotent")
	expect(Save.profile.records.has("daily:chapter_one:8731"),"new daily record isolated from legacy campaign records")
	expect(Save.valid_result(settled) and Save.valid_profile(Save.profile),"chapter result validates inside persisted profile")
	Save.load_profile()
	expect(Save.profile.history[0].get("gear")==result.gear,"new build details survive profile reload")
	var report={"checks":checks,"failures":failures,"passed":failures.is_empty(),"map_geometries":geometries.size(),"scope":"First-chapter daily/contract rules, all event branches, save backup, deterministic RNG and settlement."}
	var file=FileAccess.open("res://test-output/chapter-modes.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); print(JSON.stringify(report))
	Sound.shutdown(); await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
