extends Node

var app
var failures: Array = []
var observed: Array = []

func _ready() -> void:
	get_tree().create_timer(45).timeout.connect(func(): push_error("Animation audit timed out"); get_tree().quit(1))
	call_deferred("run")

func wait_pose(view: ActorView, pose: String, seconds: float) -> bool:
	var deadline = Time.get_ticks_msec()+int(seconds*1000)
	while Time.get_ticks_msec()<deadline:
		await get_tree().process_frame
		if view.animated.animation==pose:
			observed.append(pose)
			return true
	failures.append("Missing pose: "+pose)
	return false

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-output/"+name+".png")

func run() -> void:
	await get_tree().process_frame
	Save.directory = "user://animation-flow/"
	Save.profile = Save.defaults()
	Save.profile.tutorial_seen = true
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	app.start_run({"seed":810,"choose_oath":false})
	for stage in range(1,5):
		app.world.stage = stage
		app.world.start_sector()
		app.world.player.hp = 100000.0
		app.world.player.max_hp = 100000.0
		var boss = app.world.spawn("boss"+str(stage-1),false,true)
		boss.hp *= 0.45
		boss.cooldown = 0.05
		app.world.boss_spawned = true
		var deadline = Time.get_ticks_msec()+2000
		while not app.arena.enemy_views.has(boss.uid) and Time.get_ticks_msec()<deadline: await get_tree().process_frame
		if not app.arena.enemy_views.has(boss.uid):
			failures.append("Boss view missing: "+str(stage))
			continue
		var view = app.arena.enemy_views[boss.uid]
		if await wait_pose(view,"windup",2): await capture("boss-%d-windup" % stage)
		if await wait_pose(view,"attack",3): await capture("boss-%d-attack" % stage)
		if not boss.enraged: failures.append("Boss phase failed: "+str(stage))
		if stage==1: await wait_pose(app.arena.player_view,"cast",2)
	app.world.player.invulnerable = 0
	app.world.hurt(1e9)
	if await wait_pose(app.arena.player_view,"death",1): await capture("player-death-runtime")
	await get_tree().create_timer(1.2).timeout
	if app.screen!="result": failures.append("Death animation did not lead to settled result")
	var report = {"observed":observed,"failures":failures,"passed":failures.is_empty(),"scope":"Actual native GUI, physics ticks, sprite animation clocks, boss windup/attack/enrage and player cast/death."}
	var file = FileAccess.open("res://test-output/animation-flow.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print(JSON.stringify(report))
	Sound.shutdown()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
