extends Node

var app
var elapsed = 0.0
var frame_times: Array = []
var draw_calls: Array = []
var mob_counts: Array = []
var bolt_counts: Array = []
var finished = false
var sample_seconds = 30.0
var simulation_times: Array = []
var presentation_times: Array = []
var autosave_time = 0.0
var autosave_failures: Array = []
var chapter_frames: Dictionary = {1:[],2:[],3:[],4:[]}

func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	call_deferred("setup")

func setup() -> void:
	await get_tree().process_frame
	Save.directory = "user://chapter-performance/"
	Save.profile = Save.defaults()
	Save.profile.tutorial_seen = true
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	app.start_run({"seed":7001,"choose_oath":false})
	app.set_process(false)
	app.set_physics_process(false)
	app.paused = true
	var world = app.world
	world.player.hp = 100000.0
	world.player.max_hp = 100000.0
	world.gear="seal"; world.gear_rank=3; world.gear_mod=0
	world.skill="shadow"; world.skill_rank=3; world.skill_mod=0
	world.weapons={"fire_talisman":3}
	world.sigils={"fire":3,"precision":3,"cleave":3,"ember":3,"ward":3,"reaction":3}
	world.relics=["old_wick","silver","drum","fox_tooth","map","green_lamp"]
	world.set_controls(Vector2.RIGHT,true)
	world.boss_spawned = true
	world.elite_spawned = true
	for i in range(170):
		var mob = world.spawn(["paper_spirit","lantern_wisp","mist_fox","stone_guard","archer"][i%5])
		mob.x = 200+(i%17)*70
		mob.y = 220+int(i/17)*48
		mob.hp = 100000.0
		mob.max_hp = 100000.0
	world.rebuild_index()
	for i in range(400):
		world.make_bolt(Vector2(200+(i%20)*60,250+int(i/20)*20),Vector2.from_angle(i)*120,1,"enemy",true)
	for i in range(14): world.make_zone(Vector2(260+i*85,370+(i%2)*180),65,1,"enemy",0.6,3,true,true)
	for i in range(150): world.drops.append({"x":220.0+(i%20)*65,"y":240.0+int(i/20)*60,"kind":"coin","value":1,"age":0.0})

func _process(dt: float) -> void:
	if app==null or finished: return
	elapsed += dt
	var world = app.world
	var desired_stage=mini(4,1+int(elapsed/8))
	if world.stage!=desired_stage:
		world.stage=desired_stage; world.chapter_log.clear()
		for i in range(1,desired_stage): world.chapter_log.append({"stage":i,"kills":0,"seconds":0.0,"rooms":1})
		world._configure_room()
	var started = Time.get_ticks_usec()
	world.set_controls(Vector2.from_angle(elapsed*0.7),true)
	if world.skill_cd<=0: world.pulse()
	world.update(minf(dt,1.0/60),Vector2.from_angle(elapsed*0.8),false)
	if world.phase=="upgrade": world.choose(0)
	while world.bolts.size()<400: world.make_bolt(Vector2(world.rng.randf_range(220,1380),world.rng.randf_range(240,730)),Vector2.from_angle(world.rng.randf()*TAU)*120,1,"enemy",true)
	while world.zones.size()<14: world.make_zone(Vector2(world.rng.randf_range(240,1360),world.rng.randf_range(260,710)),65,1,"enemy",0.6,3,true,true)
	while world.drops.size()<150: world.drops.append({"x":world.rng.randf_range(240,1360),"y":world.rng.randf_range(240,730),"kind":"coin","value":1,"age":0.0})
	var simulation_ms = (Time.get_ticks_usec()-started)/1000.0
	started = Time.get_ticks_usec()
	app.arena.sync(dt)
	app.update_hud()
	var presentation_ms = (Time.get_ticks_usec()-started)/1000.0
	autosave_time += dt
	if autosave_time>=12:
		autosave_time = 0
		if not Save.save_run(world): autosave_failures.append(Save.error)
		elif Save.read_run().is_empty(): autosave_failures.append("Saved chapter snapshot failed validation")
	if elapsed>2:
		frame_times.append(dt*1000)
		chapter_frames[world.stage].append(dt*1000)
		draw_calls.append(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
		mob_counts.append(world.mobs.size())
		bolt_counts.append(world.bolts.size())
		simulation_times.append(simulation_ms)
		presentation_times.append(presentation_ms)
	if elapsed>=sample_seconds+2: finish()

func average(values: Array) -> float:
	var total = 0.0
	for value in values: total += value
	return total/maxi(1,values.size())

func percentile(values: Array, fraction: float) -> float:
	var sorted = values.duplicate()
	sorted.sort()
	return sorted[mini(sorted.size()-1,int(sorted.size()*fraction))]

func finish() -> void:
	finished = true
	var report = {"ruleset":app.world.result().ruleset,"stage":app.world.stage,"renderer":RenderingServer.get_video_adapter_name(),"engine":Engine.get_version_info().string,"viewport":get_viewport().get_visible_rect().size,"vsync":false,"sample_seconds":sample_seconds,"frames":frame_times.size(),"mean_frame_ms":average(frame_times),"p95_frame_ms":percentile(frame_times,0.95),"p99_frame_ms":percentile(frame_times,0.99),"average_fps":1000/average(frame_times),"average_draw_calls":average(draw_calls),"average_mobs":average(mob_counts),"average_projectiles":average(bolt_counts),"target_60fps_passed":percentile(frame_times,0.95)<=16.67,"scope":"Campaign rules in chapter-one scene with one manual weapon, one active shadow skill, full sigils/relics, native animation/shaders/audio/UI; synthetic high-health dense workload"}
	report["mean_simulation_ms"] = average(simulation_times)
	report["scope"] = "Four chapter scenes, eight seconds per chapter, one manual weapon, shadow skill, full build, 170 high-health enemies, 400 hostile projectiles, 14 repeating telegraphed impacts and autosave. Synthetic workload, not a full gameplay average."
	report["chapters"] = []
	for stage_number in chapter_frames:
		var frames: Array=chapter_frames[stage_number]
		var p95=percentile(frames,0.95) if not frames.is_empty() else INF
		report.chapters.append({"stage":stage_number,"frames":frames.size(),"average_fps":1000/average(frames) if not frames.is_empty() else 0,"p95_frame_ms":p95})
		if p95>16.67: report.target_60fps_passed=false
	report["mean_presentation_ms"] = average(presentation_times)
	report["autosave_failures"] = autosave_failures
	report["target_60fps_passed"] = report.target_60fps_passed and autosave_failures.is_empty()
	var file = FileAccess.open("res://test-output/performance.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print(JSON.stringify(report))
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-output/performance.png")
	Sound.shutdown()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit(0 if report.target_60fps_passed else 1)
