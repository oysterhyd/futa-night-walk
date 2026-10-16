extends Node

var app
var failures: Array = []
var captures: Array = []

func _ready() -> void:
	call_deferred("run")

func capture(name: String) -> void:
	for i in range(6): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path = "res://test-output/"+name+".png"
	var result = get_viewport().get_texture().get_image().save_png(path)
	if result != OK: failures.append("Screenshot failed: "+name)
	captures.append(name)

func run() -> void:
	await get_tree().process_frame
	Save.directory = "user://visual-audit/"
	Save.profile = Save.defaults()
	Save.profile.tutorial_seen = true
	Save.profile.bosses = 6
	Save.profile.embers = 230
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await capture("audit-menu")
	app.show_prepare()
	await capture("audit-prepare")
	Save.profile.bosses = 0
	app.show_prepare()
	await capture("audit-prepare-locked")
	Save.profile.bosses = 6
	app.selected_mode = "daily"
	app.show_prepare()
	await capture("audit-prepare-daily")
	app.selected_mode = "campaign"
	app.show_camp()
	await capture("audit-camp")
	app.show_journal()
	await capture("audit-journal")
	app.show_settings(false)
	if app.ui_root.theme.get_stylebox("slider","HSlider").get_minimum_size().y<6: failures.append("Audio slider has no visible track")
	if app.ui_root.theme.get_stylebox("scroll","VScrollBar").get_minimum_size().x<6: failures.append("Inventory scrollbar has no visible track")
	await capture("audit-settings")
	app.start_run({"seed": 421,"choose_oath":false})
	app.show_tutorial()
	await capture("audit-tutorial")
	app.clear_control(app.modal)
	app.paused = false
	app.world.phase = "oath"
	app.world.choices = Content.data.oaths.keys().map(func(key): return "o:"+key)
	app.show_choices()
	await capture("audit-oath")
	app.world.choose_oath(1)
	app.clear_control(app.modal)
	app.paused = true
	app.world.weapons = {"fire_talisman":3,"thunder_mark":3,"frost_sand":2,"ward_shard":2}
	app.world.passives = {"cinnabar":1,"jade":1,"bell":1}
	for i in range(25):
		var mob = app.world.spawn(["paper_spirit","lantern_wisp","mist_fox","stone_guard","archer"][i%5])
		mob.x = 250+(i%7)*160
		mob.y = 280+int(i/7)*110
	app.world.player.x = 800.0
	app.world.player.y = 530.0
	app.world.player.invulnerable = 0.0
	app.world.spawn("boss0",false,true)
	app.world.make_zone(Vector2(900,570),85,22,"enemy",0.6,1.25,true,true)
	app.world.make_zone(Vector2(530,410),100,12,"poison_mist")
	app.world.rebuild_index()
	for key in app.world.weapons: app.world.cast(key)
	app.arena.sync(0.016)
	app.update_hud()
	await get_tree().create_timer(2.7).timeout
	await capture("audit-battle")
	for stage in range(2,5):
		app.world.stage = stage
		app.world.start_sector()
		app.world.spawn("boss"+str(stage-1),false,true)
		app.arena.sync(0)
		app.update_hud()
		app.arena.sync(0.7)
		await get_tree().create_timer(0.7).timeout
		await capture("audit-stage-"+str(stage))
	if app.bars.hp.size.y > 14 or app.bars.xp.size.y > 10: failures.append("HUD bars have excessive minimum height: %s / %s" % [app.bars.hp.size,app.bars.xp.size])
	app.world.pending_levels = 1
	app.world.roll_choices()
	app.show_choices()
	await capture("audit-upgrade")
	app.world.phase = "route"
	app.world.routes = ["tea","curse","study"]
	app.show_choices()
	await capture("audit-route")
	app.world.pending_relics = 1
	app.world.open_relic_draft()
	app.show_choices()
	await capture("audit-relic")
	app.world.relics = ["red_thread","old_wick","bamboo","silver"]
	app.world.choose_relic(0)
	app.show_choices()
	await capture("audit-relic-replace")
	app.world.choose_relic(-1)
	app.show_pause()
	await capture("audit-pause")
	app.show_settings(true)
	await capture("audit-run-settings")
	app.world.passives = {"cinnabar":3,"jade":3,"bell":3,"boots":3,"armor":3,"mirror":3}
	app.world.relics = ["red_thread","old_wick","bamboo","silver"]
	app.show_inventory()
	await capture("audit-inventory")
	app.world.finish(true)
	app.last_result = Save.settle(app.world)
	app.show_result()
	await capture("audit-result")
	app.show_journal("history")
	await capture("audit-history")
	JournalView.show_detail(app,Save.profile.history[0])
	await capture("audit-history-detail")
	app.show_journal("records")
	await capture("audit-records-empty")
	var record = app.last_result.duplicate(true)
	record.mode = "daily"
	Save.profile.records["daily:20261014"] = record
	app.show_journal("records")
	await capture("audit-records")
	app.world.phase = "active"
	app.world.mobs.clear()
	app.world.bolts.clear()
	app.world.zones.clear()
	app.world.player.x = 100.0
	app.world.player.y = 700.0
	app.world.weapons = {"ward_shard":3,"shadow_twin":3}
	app.screen = "run"
	app.paused = true
	app.intro_stage = app.world.stage
	app.show_hud()
	app.arena.sync(0.7)
	app.arena.sync(0.7)
	var projectile_keys = ["fire_talisman","thunder_mark","piercing_spike","armor_breaker","soul_arrow","frost_sand","lag_seal","spirit_orb","blast_pill","echo_mark","soul_lantern","enemy"]
	for i in range(projectile_keys.size()):
		var p = Vector2(190+(i%6)*245,330+int(i/6)*250)
		app.world.make_bolt(p,Vector2.RIGHT*400,10,projectile_keys[i],projectile_keys[i]=="enemy")
		UI.label(app.page,Content.skills[projectile_keys[i]].name if projectile_keys[i]!="enemy" else "敌方弹幕",Rect2(p.x-90,p.y+35,200,38),23,UI.TEXT,true)
	app.arena.effects.clear()
	app.arena.numbers.clear()
	app.arena.sync(0)
	await capture("audit-projectile-shapes")
	var report = {"captures":captures,"failures":failures,"passed":failures.is_empty()}
	var file = FileAccess.open("res://test-output/visual-audit.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"))
	file.close()
	print(JSON.stringify(report))
	Sound.shutdown()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
