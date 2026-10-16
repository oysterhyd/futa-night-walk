extends Node
# Developer tool: drives real combat calls with a fixed step and saves frames.
#   godot --path . res://tests/vfx_gallery.tscn            -> key frames (test-output/vfx/)
#   godot --path . res://tests/vfx_gallery.tscn -- --video  -> every frame for a preview video
var app
var w: ChapterWorld
var video = false
var only = ""  # -- --only=sword  captures only effects whose name starts with this
var frame_index = 0
var out = "res://test-output/vfx/"
const DT = 1.0/30.0

func _ready() -> void:
	video = "--video" in OS.get_cmdline_user_args()
	for arg in OS.get_cmdline_user_args(): if arg.begins_with("--only="): only = arg.substr(7)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	call_deferred("run")

func setup(character: String) -> void:
	if app: app.queue_free(); await get_tree().process_frame
	Save.directory="user://vfx-gallery/"; Save.profile=Save.defaults(); Save.profile.tutorial_seen=true; Save.profile.story_seen=true; Save.profile.settings.motion=false
	app=load("res://scenes/main.tscn").instantiate(); add_child(app)
	await get_tree().process_frame
	app.set_process(false); app.set_physics_process(false)
	app.start_run({"seed":777,"choose_oath":false,"character":character})
	app.intro_stage=1
	w=app.world
	for c in app.page.get_children(): if c is StoryView.ChapterCard: c.queue_free()
	var r=w.rooms.filter(func(room): return room.type=="combat")[0]
	w.room().cleared=true; w.clear_delay=0; w.enter_room(r.id)
	w.mobs.clear(); w.bolts.clear()
	w.wave_index=99; w.wave_count=99
	app.show_hud()

func dummies(kinds: Array, center: Vector2, radius: float) -> void:
	w.mobs.clear()
	for i in range(kinds.size()):
		var mob=w.spawn(kinds[i])
		var a=i*TAU/kinds.size()
		w.set_pos(mob,center+Vector2(cos(a),sin(a)*0.7)*radius)
		mob.hp=99999; mob.max_hp=99999; mob.stun=999; mob.spawn_age=5.0

func place_player(p: Vector2) -> void:
	w.set_pos(w.player,p); w.player.invulnerable=999; w.player.hp=w.player.max_hp
	app.arena.camera.position=app.arena._camera_target(w)

func steps(count: int, name: String, shots: Array) -> void:
	if only != "" and not name.begins_with(only): shots = []
	for i in range(count):
		w.update(DT,Vector2.ZERO,false)
		for mob in w.mobs: mob.stun=999; mob.hp=maxf(mob.hp,1000)
		app.arena.tick(DT)
		app.arena.sync(DT)
		app.update_hud()
		if (video and shots.size() > 0) or i in shots:
			await RenderingServer.frame_post_draw
			var image=get_viewport().get_texture().get_image()
			if video:
				image.save_jpg(out+"seq_%05d.jpg" % frame_index,0.9); frame_index+=1
			if i in shots: image.save_png(out+"%s_%02d.png" % [name,i])

func reset_fx() -> void:
	app.arena.vfx.clear(); app.arena.effects.clear(); app.arena.numbers.clear(); w.bolts.clear(); w.zones.clear()
	w.ignite_time=0; w.shadow_time=0

func attack(gear: String, name: String, combo_count: int, shots: Array, frames: int = 12, mod: int = -1) -> void:
	reset_fx()
	w.gear=gear; w.gear_mod=mod
	w.aim=Vector2.RIGHT; w.attack_aim=Vector2.RIGHT
	w.attack_count=combo_count
	w._attack()
	await steps(frames,name,shots)

func skill(key: String, name: String, shots: Array, frames: int = 24, mod: int = -1) -> void:
	reset_fx()
	w.skill=key; w.skill_mod=mod; w.skill_cd=0
	w.aim=Vector2.RIGHT
	w.pulse()
	await steps(frames,name,shots)

func run() -> void:
	await setup("swordswoman")
	var c=w.room_bounds.get_center()
	place_player(c-Vector2(160,0))
	dummies(["paper_spirit","lantern_wisp","mist_fox","archer"],c+Vector2(40,0),90)
	await attack("sword","sword-a",0,[2,4,7])
	await attack("sword","sword-b",1,[2,4])
	await attack("sword","sword-finisher",2,[2,4,6,9])
	await attack("hammer","hammer",0,[3,6,10],14)
	await attack("seal","seal",0,[3,6,9],14)
	await attack("needle","needle",0,[3,6],10)
	await attack("wheel","wheel",0,[3,6,9],14,1)
	await attack("sand","sand",0,[2,5,8],12)
	await skill("pulse","pulse",[2,5,10,18])
	place_player(c-Vector2(260,0))
	await skill("poison","poison",[4,9,16,30],36)
	await skill("binding","binding",[2,5,10,20])
	await skill("blast","blast",[4,10,13,20],26)
	place_player(c-Vector2(60,0))
	await skill("frost","frost",[2,5,9,16])
	await skill("shadow","shadow",[3,8,16])
	reset_fx(); w.flame=w.FLAME_MAX; w.ignite(); await steps(30,"ignite-sword",[3,8,14,28])
	reset_fx(); w.player.dash_time=0; w.dash(Vector2.RIGHT); w._perfect_dodge(); await steps(14,"dash-perfect",[2,6,10])
	reset_fx()
	for mob in w.mobs.duplicate(): mob.hp=1; w.hit(mob,50,"fire_talisman")
	await steps(16,"deaths",[2,6,12])
	await setup("keeper")
	c=w.room_bounds.get_center(); place_player(c)
	dummies(["paper_spirit","lantern_wisp","mist_fox","archer","stone_guard"],c,200)
	reset_fx(); w.flame=w.FLAME_MAX; w.ignite(); await steps(36,"ignite-keeper",[3,8,14,30])
	await setup("alchemist")
	c=w.room_bounds.get_center(); place_player(c)
	dummies(["paper_spirit","lantern_wisp","mist_fox","archer"],c,180)
	reset_fx(); w.flame=w.FLAME_MAX; w.ignite(); await steps(40,"ignite-alchemist",[4,12,20,34])
	get_tree().quit(0)
