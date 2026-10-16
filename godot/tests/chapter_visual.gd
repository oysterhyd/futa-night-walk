extends Node

var app
var captures: Array=[]
var failures: Array=[]

func _ready() -> void:
	get_tree().create_timer(50).timeout.connect(func(): push_error("Chapter visual audit timed out"); get_tree().quit(1))
	call_deferred("run")

func check_labels(node: Node, label_text: String) -> void:
	if node is Label and node.visible:
		if node.autowrap_mode==TextServer.AUTOWRAP_OFF and not node.text.is_empty():
			var font=node.get_theme_font("font")
			var width=font.get_string_size(node.text,HORIZONTAL_ALIGNMENT_LEFT,-1,node.get_theme_font_size("font_size")).x
			if width>node.size.x+1: failures.append(label_text+": clipped text "+node.text)
	for child in node.get_children(): check_labels(child,label_text)

func capture(name: String) -> void:
	app.arena.sync(0.016)
	if app.screen=="run": app.update_hud()
	for i in range(5): await get_tree().process_frame
	if name.begins_with("room-"):
		var enemies=app.arena.actors.get_children().filter(func(view): return view is ActorView and not view.player_actor)
		if enemies.size()!=app.arena.enemy_views.size(): failures.append(name+": actors retained from previous room")
	check_labels(app.page,name); check_labels(app.modal,name)
	await RenderingServer.frame_post_draw
	if get_viewport().get_texture().get_image().save_png("res://test-output/chapter-audit-"+name+".png")!=OK: failures.append("Failed capture: "+name)
	captures.append(name)

func run() -> void:
	await get_tree().process_frame
	Save.directory="user://chapter-visual/"; Save.profile=Save.defaults(); Save.profile.tutorial_seen=true; Save.profile.bosses=8; Save.profile.embers=220
	app=load("res://scenes/main.tscn").instantiate(); add_child(app)
	app.set_process(false); app.set_physics_process(false)
	await capture("menu")
	app.show_prepare(); await capture("prepare")
	app.selected_mode="daily"; app.show_prepare(); await capture("daily"); app.selected_mode="campaign"
	app.show_camp(); await capture("camp")
	app.show_settings(false); await capture("settings")
	app.start_run({"seed":4242,"choose_oath":false}); app.intro_stage=1; app.show_hud()
	app.show_tutorial(); await capture("tutorial"); app.clear_control(app.modal); app.paused=false
	var w=app.world as ChapterWorld
	for type in ["entry","combat","gear","skill","shop","event","shrine","elite","rest","boss","secret"]:
		w.phase="active"; w.room().cleared=true; w.clear_delay=0
		var r=w.rooms.filter(func(room): return room.type==type)[0]
		w.enter_room(r.id); app.show_hud(); app.arena.sync(0.4); app.arena.actors.modulate.a=1
		w.player.invulnerable=0
		await capture("room-"+type)
		if type in ["gear","skill","shop","event","rest"]:
			w.set_pos(w.player,w.room_bounds.get_center()); w.interact_nearby(); app.show_choices()
			await capture("offer-"+type); app.clear_control(app.modal)
	w.phase="active"; w.room().cleared=true; w.clear_delay=0; w.enter_room(0)
	w._offer("growth","清房奖励 · 选择强化","当前配置可使用的符印优先出现。",["p:ember","p:cleave","a:health"])
	app.show_choices(); await capture("growth")
	w.phase="active"; w.gear="sword"; w.gear_rank=2; w.gear_mod=-1; w._gear_mod_offer(); app.show_choices(); await capture("gear-mod")
	w.phase="active"; w.sigils={"counter":3,"fire":2,"toxin":2,"ember":2,"execution":1,"precision":2}; w.relics=ChapterContent.RELICS.keys().slice(0,6)
	w._offer("growth","","",["p:wind"]); w.choose(0); app.show_choices(); await capture("sigil-replacement")
	w.phase="active"; w._offer("relic","","",["r:broken_coin"]); w.choose(0); app.show_choices(); await capture("relic-replacement")
	w.phase="active"; app.show_hud(); app.show_inventory(); await capture("inventory"); app.clear_control(app.modal)
	ChapterUI.show_map(app); await capture("map"); app.clear_control(app.modal)
	app.show_pause(); await capture("pause")
	app.show_settings(true); await capture("run-settings"); app.clear_control(app.modal)
	w.gear_mod=0; w.weapons={"piercing_spike":2}; w.pending_sigil=""; w.pending_relic=""; w.choices.clear(); w.phase="active"
	w.damage_by_skill={"piercing_spike":1250.0,"shadow_twin":490.0,"reaction:燃瘴":330.0}
	w.stage=4; w.bosses=4; w.kills=1038
	w.chapter_log=[{"stage":1,"kills":200,"seconds":180.0,"rooms":13},{"stage":2,"kills":250,"seconds":210.0,"rooms":13},{"stage":3,"kills":280,"seconds":240.0,"rooms":13}]
	w.finish(true)
	for i in range(66): w.update(1.0/60,Vector2.ZERO,false)
	app.last_result=Save.settle(w); app.show_result(); await capture("result")
	ChapterUI.show_record(app,app.last_result); await capture("record"); app.clear_control(app.modal)
	app.show_journal("history"); await capture("history")
	DisplayServer.window_set_size(Vector2i(1280,720)); await get_tree().create_timer(0.2).timeout
	app.show_prepare(); await capture("minimum-window")
	var report={"captures":captures,"failures":failures,"passed":failures.is_empty(),"scope":"All first-chapter room types, item/card/replacement/record screens, minimum window and single-line font fit. Requires visual review of saved PNGs."}
	var file=FileAccess.open("res://test-output/chapter-visual.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); print(JSON.stringify(report))
	Sound.shutdown(); await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
