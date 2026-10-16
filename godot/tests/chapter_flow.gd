extends Node

var app
var failures: Array=[]
var checks=0

func _ready() -> void:
	get_tree().create_timer(55).timeout.connect(func(): push_error("Chapter GUI flow timed out"); get_tree().quit(1))
	call_deferred("run")

func frames(count: int=3) -> void:
	for i in range(count): await get_tree().process_frame

func expect(value: bool, label_text: String) -> void:
	checks+=1
	if not value: failures.append(label_text); push_error(label_text)

func key(code: int, held: int=2) -> void:
	var event=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=true
	Input.parse_input_event(event); await frames(held)
	var release=event.duplicate(); release.pressed=false; Input.parse_input_event(release); await frames()

func click(parent: Control, prefix: String) -> void:
	var matches=parent.get_children().filter(func(node): return node is Button and node.text.begins_with(prefix))
	if matches.is_empty(): expect(false,"button exists: "+prefix); return
	await mouse(matches[0].get_global_rect().get_center(),MOUSE_BUTTON_LEFT)

func mouse(point: Vector2, button: int, held: int=2) -> void:
	var motion=InputEventMouseMotion.new(); motion.position=point; motion.global_position=point; Input.parse_input_event(motion)
	var event=InputEventMouseButton.new(); event.position=point; event.global_position=point; event.button_index=button; event.pressed=true
	Input.parse_input_event(event); await frames(held)
	var release=event.duplicate(); release.pressed=false; Input.parse_input_event(release); await frames()

func capture(name: String) -> void:
	await frames(4); await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-output/chapter-"+name+".png")

func joy_axis(axis: int, value: float, held: int=8) -> void:
	var event=InputEventJoypadMotion.new(); event.device=1; event.axis=axis; event.axis_value=value
	Input.parse_input_event(event); await frames(held)

func joy_button(button: int) -> void:
	var event=InputEventJoypadButton.new(); event.device=1; event.button_index=button; event.pressed=true
	Input.parse_input_event(event); await frames(8)
	event.pressed=false; Input.parse_input_event(event); await frames()

func run() -> void:
	await frames()
	Save.directory="user://chapter-gui/"; Save.clear_run(); Save.profile=Save.defaults(); Save.profile.settings.motion=false; Save.profile.bosses=8
	app=load("res://scenes/main.tscn").instantiate(); add_child(app)
	app.arena.add_hitstop(0.1,true)
	expect(app.arena.time_scale()==1.0,"reduced motion disables hit-stop")
	app.arena.add_slowmo(0.5,0.3)
	expect(app.arena.time_scale()==1.0,"reduced motion disables slow motion")
	app.arena.tick(1.0)
	await frames(); await key(KEY_ENTER)
	expect(app.screen=="prepare","Enter opens character selection")
	await click(app.page,"启程出发")
	expect(app.story!=null,"first campaign start plays the prologue")
	await key(KEY_ENTER)
	expect(app.story.shown_lines==app.story.line_nodes.size(),"Enter reveals the current story text")
	await capture("prologue"); await click(app.modal,"跳过")
	expect(app.world is ChapterWorld and app.paused,"new first chapter opens tutorial")
	await capture("tutorial"); await click(app.modal,"进入灯市")
	expect(app.world.phase=="oath" and not app.paused,"tutorial closes into actual oath choices")
	await capture("oath"); await key(KEY_4)
	expect(app.world.oath=="none" and app.world.phase=="active","number key selects no oath")
	await get_tree().create_timer(2.7).timeout; await capture("entry")
	var before=app.world.attack_count
	app.world.attack_cd=0
	await mouse(Vector2(1100,430),MOUSE_BUTTON_LEFT,0)
	await get_tree().create_timer(0.18).timeout
	expect(app.world.attack_count>before,"brief mouse click buffered through native input")
	before=app.world.attack_count
	await mouse(Vector2(1100,430),MOUSE_BUTTON_LEFT,22)
	expect(app.world.attack_count>before,"mouse hold triggers manual attacks")
	await mouse(Vector2(1100,430),MOUSE_BUTTON_RIGHT)
	expect(app.world.skill_cd>0,"right mouse casts unique active skill")
	await key(KEY_SPACE)
	expect(app.world.dash_charges==1,"space consumes one dash charge")
	await key(KEY_TAB)
	expect(app.paused,"Tab opens map and pauses battle")
	await capture("map"); await key(KEY_ESCAPE)
	expect(not app.paused,"Escape closes map")
	app.world.dash_charges=2; app.world.dash_recharge=0
	await joy_axis(JOY_AXIS_TRIGGER_LEFT,0.8)
	expect(app.world.dash_charges==1,"controller LT triggers one dash")
	await joy_axis(JOY_AXIS_TRIGGER_LEFT,0.9)
	expect(app.world.dash_charges==1,"trigger jitter does not consume second dash")
	await joy_axis(JOY_AXIS_TRIGGER_LEFT,0.0)
	await joy_axis(JOY_AXIS_RIGHT_X,0.9)
	expect(app.world.aim.x>0.95,"controller right stick sets aim")
	before=app.world.attack_count
	await joy_axis(JOY_AXIS_TRIGGER_RIGHT,0.9,20)
	expect(app.world.attack_count>before,"controller RT performs manual attacks")
	await joy_axis(JOY_AXIS_TRIGGER_RIGHT,0.0)
	await joy_axis(JOY_AXIS_RIGHT_X,0.0)
	app.world.skill_cd=0; await joy_button(JOY_BUTTON_RIGHT_SHOULDER)
	expect(app.world.skill_cd>0,"controller RB casts active skill")
	await joy_button(JOY_BUTTON_LEFT_SHOULDER)
	expect(app.paused,"controller LB opens chapter map")
	await key(KEY_ESCAPE)
	await key(KEY_B)
	expect(app.paused,"B opens build inventory")
	await capture("inventory"); await click(app.modal,"返回战斗")
	var door=app.world.doors().filter(func(d): return d.id==1)[0]
	app.world.set_pos(app.world.player,door.position-Vector2(45,0))
	await key(KEY_E)
	expect(app.world.room_id==1 and not app.world.room().cleared,"E enters connected combat room")
	app.world.gear="sword"; app.world.weapons={"piercing_spike":1}; app.world.skill="shadow"; app.world.skill_cd=0
	await mouse(Vector2(1150,450),MOUSE_BUTTON_RIGHT)
	await mouse(Vector2(1150,450),MOUSE_BUTTON_LEFT,18)
	await capture("combat")
	app.paused=true
	app.world._offer("growth","清房奖励 · 选择强化","符印与基础属性。",["p:counter","p:fire","a:health"])
	app.paused=false; app.choice_phase=""; app.update_phase(); await capture("growth"); await key(KEY_1)
	expect(app.world.sigils.get("counter",0)==1,"number key applies sigil through UI")
	await key(KEY_ESCAPE); await click(app.modal,"保存并退出")
	expect(app.screen=="menu" and Save.read_run().get("ruleset")=="nightroad_campaign","pause saves actual campaign ruleset")
	await click(app.page,"继续对局")
	expect(app.screen=="run" and app.world.sigils.get("counter",0)==1,"menu resumes same chapter build")
	app.paused=true
	app.world.room().cleared=true; app.world.enter_room(9); app.world.coins=100; app.world._shop_offer()
	app.paused=false; app.choice_phase=""; app.update_phase(); await capture("shop")
	await key(KEY_2)
	expect(app.world.gear_rank==2 and app.world.offer_kind=="gear_mod","shop purchase opens real modifier choices")
	await capture("modifier"); await key(KEY_1)
	app.world.room().cleared=true; app.world.enter_room(6)
	app.world.skill="blast"; app.world.skill_cd=0; app.world.set_controls(Vector2.UP,false); app.world.pulse()
	await capture("boss")
	var first_boss=app.world.mobs.filter(func(m): return m.boss)[0]
	app.world.hit(first_boss,1000000,"pulse")
	await get_tree().create_timer(1.25).timeout
	expect(app.world.offer_kind=="chapter_clear" and Save.profile.victories==0,"first boss opens chapter reward without settling full victory")
	await capture("chapter-clear"); await key(KEY_2)
	expect(app.world.stage==2 and app.world.room_id==0 and app.screen=="run","native chapter reward advances to river crossing")
	expect(Sound.track=="battle-fox","chapter transition selects river music without resetting to market")
	app.world.stage=4; app.world.room().cleared=true; app.world.clear_delay=0; app.world.phase="active"
	app.world.chapter_log=[{"stage":1,"kills":100,"seconds":100.0,"rooms":13},{"stage":2,"kills":100,"seconds":100.0,"rooms":13},{"stage":3,"kills":100,"seconds":100.0,"rooms":13}]
	app.world.bosses=3; app.world.enter_room(6)
	var final_boss=app.world.mobs.filter(func(m): return m.boss)[0]
	app.world.hit(final_boss,1000000,"pulse")
	var result_deadline=Time.get_ticks_msec()+4000
	var ending_seen=false
	while app.screen!="result" and Time.get_ticks_msec()<result_deadline:
		if app.story!=null:
			ending_seen=true; await capture("ending"); app.story.skip()
		await get_tree().process_frame
	expect(ending_seen,"campaign victory plays the ending before the result")
	expect(app.screen=="result" and Save.profile.victories==1,"four chapter completion settles once")
	await capture("result")
	var report={"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Real Godot GUI render and synthetic native keyboard/mouse input; setup fixtures for card and boss captures."}
	var file=FileAccess.open("res://test-output/chapter-flow.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	print(JSON.stringify(report)); Save.clear_run(); Sound.shutdown()
	await get_tree().create_timer(0.2).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
