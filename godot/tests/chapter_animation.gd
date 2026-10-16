extends Node

var app
var failures: Array=[]
var observed: Array=[]

func _ready() -> void:
	get_tree().create_timer(35).timeout.connect(func(): push_error("Chapter animation timed out"); get_tree().quit(1))
	call_deferred("run")

func wait_pose(view: ActorView, pose: String, seconds: float) -> bool:
	var deadline=Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if view.animated.animation==pose: observed.append(pose); return true
	failures.append("Missing pose: "+pose); return false

func key(code: int, pressed: bool) -> void:
	var event=InputEventKey.new(); event.physical_keycode=code; event.keycode=code; event.pressed=pressed; Input.parse_input_event(event)

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-output/chapter-animation-"+name+".png")

func run() -> void:
	await get_tree().process_frame
	Save.directory="user://chapter-animation/"; Save.profile=Save.defaults(); Save.profile.tutorial_seen=true
	app=load("res://scenes/main.tscn").instantiate(); add_child(app)
	app.start_run({"seed":810,"choose_oath":false}); app.intro_stage=1
	await get_tree().create_timer(0.4).timeout
	key(KEY_D,true)
	await wait_pose(app.arena.player_view,"walk",1)
	key(KEY_D,false)
	app.world.dash(Vector2.RIGHT)
	if await wait_pose(app.arena.player_view,"dash",1): await capture("dash")
	await get_tree().create_timer(0.3).timeout
	app.world.pulse()
	if await wait_pose(app.arena.player_view,"cast",1):
		var first_frame=app.arena.player_view.animated.frame
		await get_tree().create_timer(0.15).timeout
		if app.arena.player_view.animated.frame==first_frame: failures.append("Cast frame clock did not advance")
		await capture("cast")
	app.world.enter_room(6)
	var boss=app.world.mobs.filter(func(m): return m.boss)[0]
	boss.hp=boss.max_hp*0.45; boss.cooldown=0.01
	var deadline=Time.get_ticks_msec()+1500
	while not app.arena.enemy_views.has(boss.uid) and Time.get_ticks_msec()<deadline: await get_tree().process_frame
	if not app.arena.enemy_views.has(boss.uid): failures.append("Boss sprite missing")
	else:
		var view=app.arena.enemy_views[boss.uid]
		if await wait_pose(view,"windup",2): await capture("boss-windup")
		if await wait_pose(view,"attack",2): await capture("boss-attack")
		if not boss.enraged: failures.append("Boss enrage did not activate")
	for stage_number in range(2,5):
		app.world.phase="active"; app.world.room().cleared=true; app.world.clear_delay=0
		app.world.stage=stage_number; app.intro_stage=stage_number
		app.world.rooms.clear(); app.world.room_id=0; app.world._make_map(); app.world.enter_room(6)
		var next_boss=app.world.mobs.filter(func(m): return m.boss)[0]
		next_boss.hp=next_boss.max_hp*0.3; next_boss.cooldown=0.01
		app.world.player.invulnerable=10
		await get_tree().process_frame; await get_tree().process_frame
		if not app.arena.enemy_views.has(next_boss.uid): failures.append("Chapter boss view missing: "+str(stage_number)); continue
		var view=app.arena.enemy_views[next_boss.uid]
		if await wait_pose(view,"windup",2): await capture("chapter-"+str(stage_number)+"-windup")
		if await wait_pose(view,"attack",2): await capture("chapter-"+str(stage_number)+"-attack")
		if not next_boss.enraged: failures.append("Chapter boss enrage missing: "+str(stage_number))
	# Restore a valid chapter ledger before the real death-to-result path persists it.
	app.world.chapter_log=[{"stage":1,"kills":0,"seconds":0.0,"rooms":1},{"stage":2,"kills":0,"seconds":0.0,"rooms":1},{"stage":3,"kills":0,"seconds":0.0,"rooms":1}]
	app.world.player.invulnerable=0; app.world.hurt(10000)
	if await wait_pose(app.arena.player_view,"death",1): await capture("death")
	await get_tree().create_timer(1.1).timeout
	if app.screen!="result": failures.append("Death did not settle into result")
	var report={"observed":observed,"failures":failures,"passed":failures.is_empty(),"scope":"Native GUI clocks: walking, dash, manual skill casting, all four bosses windup/attack/enrage and death-to-result. Boss encounters are state fixtures."}
	var file=FileAccess.open("res://test-output/chapter-animation.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close(); print(JSON.stringify(report))
	Sound.shutdown(); await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
