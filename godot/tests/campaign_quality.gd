extends Node

var app
var captures: Array=[]
var failures: Array=[]

func _ready() -> void:
	get_tree().create_timer(75).timeout.connect(func(): push_error("Campaign quality capture timed out"); get_tree().quit(1))
	call_deferred("run")

func capture(name: String) -> void:
	app.arena.sync(0.08); app.update_hud()
	app.arena.transition=0; app.arena.actors.modulate.a=1
	for i in range(5): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png("res://test-output/campaign-quality-"+name+".png")!=OK: failures.append("Capture failed: "+name)
	captures.append(name)

func reset_combat() -> void:
	var w=app.world
	w.mobs.clear(); w.bolts.clear(); w.zones.clear(); w.events.clear(); app.arena.effects.clear(); app.arena.numbers.clear()
	w.attack_held=false; w.player.invulnerable=0; w.skill_cd=0; w.attack_cd=0; w.attack_windup=0; w.shadow_time=0
	w.set_pos(w.player,w.room_bounds.get_center()); w.aim=Vector2.RIGHT; w.attack_aim=Vector2.RIGHT

func advance(seconds: float) -> void:
	for i in range(ceili(seconds*60)):
		app.world.update(1.0/60,Vector2.ZERO,false); app.arena.sync(1.0/60)

func run() -> void:
	await get_tree().process_frame
	Save.directory="user://campaign-quality/"; Save.profile=Save.defaults(); Save.profile.tutorial_seen=true; Save.profile.bosses=8
	app=load("res://scenes/main.tscn").instantiate(); add_child(app)
	app.set_process(false); app.set_physics_process(false)
	app.start_run({"seed":4242,"choose_oath":false}); app.intro_stage=1; app.show_hud()
	var w=app.world as CampaignWorld
	for key in ChapterContent.GEAR:
		reset_combat()
		w.gear=key; w.gear_rank=3; w.gear_mod=0; w.weapons={ChapterContent.GEAR[key].source:3}; w.attack_count=2
		var archer=w.spawn("archer"); w.set_pos(archer,Vector2(1200,365)); w.hostile_fan(archer,3,240,false,Vector2.LEFT)
		var target=w.spawn("stone_guard"); w.set_pos(target,w.pos(w.player)+Vector2(110,0)); target.hp=9999; target.max_hp=9999
		w._attack()
		for i in range(9): w.update(1.0/60,Vector2.ZERO,false)
		w.player.invulnerable=0
		await capture("gear-"+key)
		if app.arena.combat_batch.batches.danger_arrow.multimesh.visible_instance_count!=3: failures.append("Distinct hostile arrow batch missing: "+key)
	for key in ChapterContent.SKILLS:
		reset_combat(); w.skill=key; w.skill_rank=3; w.skill_mod=0
		w.pulse(); await capture("skill-"+key)
		if key=="blast":
			advance(0.40); await capture("skill-blast-impact")
			if not app.arena.effects.any(func(e): return e.kind=="detonation"): failures.append("Actual timed detonation art missing")
	Save.profile.settings.particles=false
	reset_combat(); var archer=w.spawn("archer"); w.set_pos(archer,Vector2(1150,400)); w.hostile_fan(archer,3,240,false,Vector2.LEFT)
	for i in range(12): w.update(1.0/60,Vector2.ZERO,false)
	await capture("arrows-particles-off")
	if app.arena.combat_batch.batches.danger_arrow.multimesh.visible_instance_count!=3: failures.append("Hostile arrows disappear with particles disabled")
	for i in range(30):
		w.update(1.0/60,Vector2.ZERO,false); app.arena.sync(1.0/60)
	await capture("arrows-flight")
	Save.profile.settings.particles=true
	for stage_number in range(1,5):
		w.stage=stage_number; w.phase="active"; w.clear_delay=0; w.room().cleared=true
		w.rooms.clear(); w.room_id=0; w._make_map()
		app.intro_stage=stage_number
		w.enter_room(6); app.show_hud(); w.player.invulnerable=0
		await capture("chapter-"+str(stage_number)+"-boss")
		if stage_number>1:
			var boss=w.mobs.filter(func(m): return m.boss)[0]
			boss.dx=0; boss.dy=1; boss.attack=1 if stage_number==4 else 0
			w.boss_attack(boss); w.player.invulnerable=10
			await capture("chapter-"+str(stage_number)+"-cast")
			if stage_number==2: w.environment_clock=8.99; advance(0.02)
			advance(0.55); await capture("chapter-"+str(stage_number)+"-warning")
			advance(0.9 if stage_number==2 else (0.65 if stage_number==4 else 0.45)); await capture("chapter-"+str(stage_number)+"-impact")
			if not app.arena.effects.any(func(e): return e.kind=="enemy_blast"): failures.append("Chapter impact art missing: "+str(stage_number))
		w.room().cleared=true; w.clear_delay=0; w.enter_room(1); app.show_hud(); w.player.invulnerable=0
		await capture("chapter-"+str(stage_number)+"-combat")
		w.room().cleared=true; w.clear_delay=0; w.enter_room(5); app.show_hud(); w.player.invulnerable=0
		var door=w.doors()[0]; w.set_pos(w.player,door.position-door.direction*65)
		await capture("chapter-"+str(stage_number)+"-door")
		if stage_number>1:
			w.enter_room(10); w.coins=100; w.skill_rank=2; w.player.hp=50
			for event in range(2):
				w.event_id=event; w.room().claimed=false; w.phase="active"; w.interact_nearby(); app.update_phase()
				await capture("chapter-"+str(stage_number)+"-event-"+str(event))
				w.phase="active"; w.choices.clear(); app.clear_control(app.modal); app.choice_phase=""
	var report={"passed":failures.is_empty(),"captures":captures,"failures":failures,"scope":"Native renderer fixtures for all weapon/skill illustrations, hostile arrow silhouettes with particles on/off, four chapter scenes and door signs. Requires inspection of PNGs; not natural playthrough proof."}
	var file=FileAccess.open("res://test-output/campaign-quality.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); print(JSON.stringify(report))
	Sound.shutdown(); await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
