extends Node

var failures: Array=[]
var checks=0

func expect(condition: bool, label_text: String) -> void:
	checks+=1
	if not condition: failures.append(label_text); push_error(label_text)

func _ready() -> void:
	get_tree().create_timer(25).timeout.connect(func(): get_tree().quit(1))
	call_deferred("run")

func run() -> void:
	Save.directory="user://vfx-regressions/"; Save.profile=Save.defaults()
	Save.profile.tutorial_seen=true; Save.profile.story_seen=true; Save.profile.settings.motion=false
	var app=load("res://scenes/main.tscn").instantiate()
	add_child(app); app.set_process(false); app.set_physics_process(false)
	app.start_run({"seed":777,"choose_oath":false})
	var w=app.world as CampaignWorld
	for kind in ["paper_spirit","lantern_wisp","mist_fox","stone_guard","archer"]:
		w.mobs.clear(); w.events.clear(); app.arena.vfx.clear()
		var mob=w.spawn(kind)
		w.hit(mob,100000,"pulse")
		var deaths=w.events.filter(func(event): return event.kind=="death")
		expect(deaths.size()==1 and deaths[0].get("enemy_kind")==kind,"death event preserves monster identity: "+kind)
		app.arena.sync(0.016)
		if kind=="lantern_wisp":
			expect(app.arena.vfx_air.particles.any(func(p): return p.cell==VfxLayer.CELL.fire_b),"real lantern death emits its fire burst")
		elif kind=="stone_guard":
			expect(app.arena.vfx_air.particles.any(func(p): return p.cell==VfxLayer.CELL.dirt_b),"real stone guard death emits stone debris")
	w.mobs.clear(); w.events.clear()
	var boss=w.spawn("boss0",false,true)
	w.spawn("mist_fox")
	w.hit(boss,100000,"pulse")
	var boss_deaths=w.events.filter(func(event): return event.kind=="death")
	expect(boss_deaths.any(func(event): return event.get("enemy_kind")=="boss0" and event.boss),"boss death retains identity")
	expect(boss_deaths.any(func(event): return event.get("enemy_kind")=="mist_fox" and not event.boss),"boss cleanup retains surviving monster identity")
	w.events.clear(); w.mobs.clear(); w.bolts.clear(); app.arena.vfx.clear()
	for i in range(400): w.make_bolt(Vector2(200+i%20*50,260+int(i/20)*20),Vector2.RIGHT*120,1,"enemy",true)
	for particles_enabled in [true,false]:
		Save.profile.settings.particles=particles_enabled
		app.arena.sync(0)
		expect(app.arena.combat_batch.batches.hostile.multimesh.visible_instance_count==400,"all hostile cores survive dense VFX, particles="+str(particles_enabled))
		expect(app.arena.combat_batch.batches.danger_trail.multimesh.visible_instance_count==400,"all danger trails survive dense VFX, particles="+str(particles_enabled))
		expect(app.arena.vfx_air.pools[VfxLayer.ADD_POOL].multimesh.visible_instance_count<=192,"decorative projectile glow stays bounded")
	var viewport=SubViewport.new()
	viewport.size=Vector2i(96,64); viewport.world_2d=World2D.new()
	viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var swatch=Image.create(1,1,false,Image.FORMAT_RGBA8)
	swatch.fill(Color(0.8,0.6,0.4,0.5))
	var texture=ImageTexture.create_from_image(swatch)
	var reference=Sprite2D.new()
	reference.texture=texture; reference.position=Vector2(24,32); reference.scale=Vector2.ONE*32
	viewport.add_child(reference)
	var layer=VfxLayer.new(); viewport.add_child(layer)
	layer.pools[VfxLayer.MIX_POOL].texture=texture
	layer.pools[VfxLayer.MIX_POOL].material.set_shader_parameter("grid",1.0)
	layer.sprite("glow",Vector2(72,32),1.0,32,Color.WHITE,false)
	layer.step(0)
	for i in range(3): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixels=viewport.get_texture().get_image()
	var expected=pixels.get_pixel(24,32)
	var actual=pixels.get_pixel(72,32)
	expect(expected.r>0.2,"reference swatch rendered")
	expect(absf(actual.r-expected.r)<0.03 and absf(actual.g-expected.g)<0.03 and absf(actual.b-expected.b)<0.03,"batched sprite preserves texture color and alpha without squaring them")
	pixels.save_png("res://test-output/vfx-color-regression.png")
	var report={"passed":failures.is_empty(),"checks":checks,"failures":failures,"reference":str(expected),"batched":str(actual)}
	var file=FileAccess.open("res://test-output/vfx-regressions.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close(); print(JSON.stringify(report))
	Sound.shutdown(); await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
