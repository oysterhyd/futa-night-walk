class_name ArenaView
extends Node2D

const ACTOR = preload("res://presentation/actor_view.gd")
const SPRITES = {"paper_spirit": 3, "lantern_wisp": 4, "mist_fox": 5, "stone_guard": 6, "archer": 7, "boss0": 8, "boss1": 9, "boss2": 10, "boss3": 11}
var world: RunWorld
var background: Sprite2D
var actors: Node2D
var player_view: ActorView
var enemy_views: Dictionary = {}
var fog: ColorRect
var effects: Array = []
var numbers: Array = []
var age = 0.0
var shake = 0.0
var hurt = 0.0
var stage_shown = 0
var presentation_rng = RandomNumberGenerator.new()
var fireflies: CPUParticles2D
var post: ColorRect
var vfx_front: Node2D
var prop_views: Array = []
var shrine_view: Sprite2D
var combat_batch: CombatBatch
var interact_hint = "长按 E · 点灯"
var hitstop = 0.0
var hitstop_cd = 0.0
var slow_time = 0.0
var slow_scale = 1.0
var flash = 0.0
var desat = 0.0

func tick(dt: float) -> void:
	hitstop = maxf(0,hitstop-dt)
	hitstop_cd = maxf(0,hitstop_cd-dt)
	slow_time = maxf(0,slow_time-dt)
	flash = maxf(0,flash-dt*2.2)
	desat = move_toward(desat,1.0 if slow_time>0 and UI.motion() else 0.0,dt*6)

func time_scale() -> float:
	if hitstop > 0: return 0.0
	if slow_time > 0 and UI.motion(): return slow_scale
	return 1.0

func add_hitstop(seconds: float, force: bool = false) -> void:
	if hitstop_cd > 0 and not force: return
	hitstop = maxf(hitstop,seconds)
	hitstop_cd = seconds+0.14

func add_slowmo(seconds: float, scale: float) -> void:
	slow_time = maxf(slow_time,seconds)
	slow_scale = scale

func _ready() -> void:
	presentation_rng.randomize()
	background = Sprite2D.new()
	background.position = Vector2(800, 450)
	background.texture = Content.textures.arena
	background.scale = Vector2(1600, 900) / background.texture.get_size()
	background.modulate = Color.WHITE
	background.z_index = -100
	add_child(background)
	actors = Node2D.new()
	add_child(actors)
	shrine_view = Sprite2D.new()
	shrine_view.texture = Content.prop(6)
	shrine_view.scale = Vector2.ONE * 110 / shrine_view.texture.get_height()
	shrine_view.visible = false
	actors.add_child(shrine_view)
	fog = ColorRect.new()
	fog.size = Vector2(1600,900)
	fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fog.material = ShaderMaterial.new()
	fog.material.shader = preload("res://shaders/atmosphere.gdshader")
	fog.z_index = 1000
	add_child(fog)
	fireflies = CPUParticles2D.new()
	fireflies.amount = 65
	fireflies.lifetime = 8
	fireflies.preprocess = 8
	fireflies.position = Vector2(800, 480)
	fireflies.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	fireflies.emission_rect_extents = Vector2(720, 300)
	fireflies.direction = Vector2(-0.3, -1)
	fireflies.spread = 100
	fireflies.gravity = Vector2.ZERO
	fireflies.initial_velocity_min = 4
	fireflies.initial_velocity_max = 15
	fireflies.scale_amount_min = 1
	fireflies.scale_amount_max = 2.2
	fireflies.color = Color(0.68,0.21,0.15,0.45)
	fireflies.z_index = 1100
	add_child(fireflies)
	combat_batch = CombatBatch.new()
	combat_batch.z_index = 1150
	add_child(combat_batch)
	vfx_front = Node2D.new()
	vfx_front.z_index = 1200
	vfx_front.draw.connect(draw_front)
	add_child(vfx_front)
	var layer = CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	post = ColorRect.new()
	post.size = Vector2(1600,900)
	post.mouse_filter = Control.MOUSE_FILTER_IGNORE
	post.material = ShaderMaterial.new()
	post.material.shader = preload("res://shaders/grade.gdshader")
	layer.add_child(post)

func bind(run: RunWorld) -> void:
	world = run
	if player_view: player_view.queue_free()
	for view in enemy_views.values(): view.queue_free()
	enemy_views.clear()
	effects.clear()
	numbers.clear()
	player_view = ACTOR.new()
	player_view.setup(int(Content.data.characters[world.character].sprite), 95, true)
	actors.add_child(player_view)
	stage_shown = 0
	sync(0)

func sync(dt: float) -> void:
	if world == null: return
	age += dt
	if stage_shown != world.stage:
		stage_shown = world.stage
		background.texture = Content.textures[["arena", "arena-fox", "arena-temple", "arena-tower"][(world.stage - 1) % 4]]
		background.scale = Vector2(1600, 900) / background.texture.get_size()
		fog.material.set_shader_parameter("fog_color", Color("183544"))
		for view in prop_views: view.queue_free()
		prop_views.clear()
		for obstacle in world.obstacles:
			var view = Sprite2D.new()
			view.texture = Content.prop([0,1,3,2][(world.stage-1)%4])
			view.scale = Vector2.ONE * 135 / view.texture.get_height()
			view.position = world.pos(obstacle)-Vector2(0,48)
			view.z_index = int(obstacle.y)
			actors.add_child(view)
			prop_views.append(view)
		for decoration in [[Vector2(200,200),4],[Vector2(1380,740),7],[Vector2(1420,230),5],[Vector2(230,760),5]]:
			var view = Sprite2D.new()
			view.texture = Content.prop(decoration[1])
			view.scale = Vector2.ONE * (125 if decoration[1]!=5 else 110) / view.texture.get_height()
			view.position = decoration[0]-Vector2(0,40)
			view.z_index = int(decoration[0].y)
			actors.add_child(view)
			prop_views.append(view)
	shrine_view.visible = not world.shrine.is_empty()
	if shrine_view.visible:
		shrine_view.position = world.pos(world.shrine)-Vector2(0,40)
		shrine_view.z_index = int(world.shrine.y)
	player_view.sync(world.player, dt)
	var living: Dictionary = {}
	for mob in world.mobs:
		if mob.hp<=0: continue
		living[mob.uid] = true
		if not enemy_views.has(mob.uid):
			var view = ACTOR.new()
			var size = 180 if mob.boss else (105 if mob.kind == "stone_guard" else 82)
			view.setup(SPRITES[mob.kind], size * (1.18 if mob.elite else 1.0))
			actors.add_child(view)
			enemy_views[mob.uid] = view
		enemy_views[mob.uid].sync(mob, dt)
	for id in enemy_views.keys():
		if not living.has(id):
			enemy_views[id].retire()
			enemy_views.erase(id)
	for event in world.events: consume(event)
	world.events.clear()
	for effect in effects: effect.life -= dt
	effects = effects.filter(func(e): return e.life > 0)
	for number in numbers:
		number.life -= dt
		number.age = number.get("age",0.0)+dt
		number.y -= dt * (60.0 if number.age < 0.15 else 18.0)
		number.x += dt * number.get("vx",0.0)
	numbers = numbers.filter(func(n): return n.life > 0)
	shake = maxf(0, shake - dt * 20)
	hurt = maxf(0, hurt - dt * 2.5)
	position = Vector2(presentation_rng.randf_range(-shake,shake), presentation_rng.randf_range(-shake,shake)).round() if Save.profile.settings.shake else Vector2.ZERO
	fog.material.set_shader_parameter("age", age)
	post.material.set_shader_parameter("hurt", hurt)
	fireflies.emitting = Save.profile.settings.particles
	combat_batch.sync(world,effects,Save.profile.settings.particles,age)
	queue_redraw()
	vfx_front.queue_redraw()

func consume(event: Dictionary) -> void:
	var p = Vector2(event.get("x", 800), event.get("y", 450))
	var color = Content.color_for(event.get("source", "spirit"))
	match event.kind:
		"hit":
			if event.amount >= 1 and numbers.size() < 70 and Save.profile.settings.get("numbers",true):
				numbers.append({"x": p.x + presentation_rng.randf_range(-14,14), "y": p.y - 48, "text": str(event.amount)+("!" if event.critical else ""), "life": 0.75 if event.critical else 0.6, "age": 0.0, "color": Color("ffc35a") if event.critical else Color("f3e9d2"), "size": 30 if event.critical else 20, "crit": event.critical, "vx": presentation_rng.randf_range(-18,18)})
			if event.critical and event.amount >= 1: add_hitstop(0.035)
			if event.amount >= 1:
				Sound.play("hit", presentation_rng.randf_range(0.9,1.15))
				add_effect("spark", p, 0.2, 20, color)
		"death":
			add_effect("death", p, 0.6, 40 if not event.boss else 120, color)
			if event.boss: shake = 10
		"dash":
			Sound.play("dash")
			add_effect("dash", p, 0.4, 45, Color("183544"))
		"pulse":
			Sound.play("pulse")
			shake = 7
			add_effect("pulse", p, 0.75, event.radius, Color("ad3527"))
		"ring": add_effect("ring", p, 0.45, event.radius, color)
		"chain":
			var effect = {"kind": "chain", "x": p.x, "y": p.y, "tx": event.tx, "ty": event.ty, "life": 0.22, "max_life": 0.22, "color": color, "radius": 0}
			effects.append(effect)
		"reaction":
			add_effect("ring", p, 0.6, event.radius, color)
			numbers.append({"x": p.x - 24, "y": p.y - 70, "text": event.text, "life": 1.0, "age": 0.0, "color": color.lightened(0.25), "size": 24, "crit": true, "vx": 0.0})
			shake = maxf(shake, 2.5)
		"hurt":
			Sound.play("hurt")
			shake = 7
			hurt = 1
		"cast": Sound.play("cast", presentation_rng.randf_range(0.92,1.08))
		"upgrade", "shrine", "heal":
			Sound.play(event.kind)
			add_effect("pulse", p, 0.8, 115, Color("516849"))
		"pickup": Sound.play("pickup", 1.25 if event.kind_drop == "xp" else 0.9)
		"boss", "enrage":
			Sound.play("boss")
			shake = 5
		"victory", "defeat": Sound.play(event.kind)

func add_effect(kind: String, p: Vector2, life: float, radius: float, color: Color) -> void:
	if effects.size() < 180: effects.append({"kind": kind, "x": p.x, "y": p.y, "life": life, "max_life": life, "radius": radius, "color": color})

func _draw() -> void:
	if world == null: return
	for hazard in world.hazards:
		var p = world.pos(hazard)
		draw_set_transform(p, 0, Vector2(1,0.55))
		draw_circle(Vector2.ZERO, hazard.radius, Color(0.22,0.39,0.46,0.14))
		for i in range(3): draw_arc(Vector2.ZERO, hazard.radius * (0.3 + fmod(age * 0.12 + i * 0.25, 0.7)), 0, TAU, 60, Color(0.22,0.39,0.46,0.28), 1, true)
		draw_set_transform(Vector2.ZERO)
	for obstacle in world.obstacles:
		var p = world.pos(obstacle)
		draw_set_transform(p + Vector2(5,8), 0, Vector2(1.3,0.5))
		draw_circle(Vector2.ZERO, obstacle.radius, Color(0,0,0,0.32))
		draw_set_transform(Vector2.ZERO)
	for zone in world.zones:
		var p = world.pos(zone)
		var color = Content.color_for(zone.source)
		if zone.warning>0 and not zone.hostile: color=Color("8e692e")
		if zone.warning > 0:
			draw_circle(p, zone.radius, Color(color, 0.10))
			draw_arc(p, zone.radius, 0, TAU, 64, Color(color, 0.75), 2, true)
			var fraction = 1.0 - zone.warning / maxf(0.01, zone.warning_max)
			draw_arc(p, zone.radius * 0.88, -PI/2, -PI/2 + TAU * fraction, 64, Color(color, 0.95), 4, true)
			if zone.hostile:
				draw_line(p - Vector2(10,0), p + Vector2(10,0), color, 2, true)
				draw_line(p - Vector2(0,10), p + Vector2(0,10), color, 2, true)
			else: draw_colored_polygon(PackedVector2Array([p+Vector2(0,-9),p+Vector2(6,0),p+Vector2(0,9),p+Vector2(-6,0)]),color)
		else:
			draw_circle(p, zone.radius, Color(color, 0.14 + sin(age * 9) * 0.025))
			draw_arc(p, zone.radius, age, age + TAU, 60, Color(color, 0.35), 2, true)
			for i in range(6):
				var angle = TAU * i / 6 + age * 0.25
				draw_line(p + Vector2.from_angle(angle) * zone.radius * 0.6, p + Vector2.from_angle(angle + PI / 3) * zone.radius * 0.6, Color(color,0.3), 1.5, true)
	if not world.shrine.is_empty():
		var p = world.pos(world.shrine)
		draw_arc(p, 35, 0, TAU, 48, Color("183544"), 1.5, true)
		var required=2.0 if world is ChapterWorld else 2.6
		if world.shrine.progress > 0: draw_arc(p, 43, -PI/2, -PI/2 + TAU * world.shrine.progress / required, 48, Color("ad3527"), 4, true)
		draw_string(Content.body_font, p + Vector2(-64,32), interact_hint, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("183544"))
	for mob in world.mobs:
		if mob.windup > 0:
			var p = world.pos(mob)
			var direction = Vector2(mob.dx,mob.dy)
			if world is ChapterWorld and mob.kind in ["paper_spirit","lantern_wisp"]:
				draw_circle(p,100,Color(0.68,0.21,0.15,0.08))
				draw_arc(p,100,-PI/2,-PI/2+TAU*clampf(1-mob.windup/0.5,0,1),48,Color("ad3527"),2,true)
				continue
			if world is ChapterWorld and mob.boss and mob.kind!="boss1":
				var radius=45+6*sin(age*18)
				draw_arc(p,radius,0,TAU,36,Color("ad3527"),2,true)
				for i in range(4):
					var v=Vector2.from_angle(i*PI/2)*radius
					draw_line(p+v,p+v*1.18,Color("ad3527"),3,true)
				continue
			if mob.kind=="stone_guard" and not mob.boss:
				draw_circle(p,95,Color(0.68,0.21,0.15,0.12))
				draw_arc(p,95,0,TAU,64,Color("ad3527"),2,true)
				draw_arc(p,88,-PI/2,-PI/2+TAU*clampf(1-mob.windup/0.8,0,1),64,Color("ad3527"),3,true)
				continue
			if mob.kind=="archer" and not mob.boss:
				for offset in [-0.17,0.0,0.17] if mob.elite else [0.0]:
					var tip = p+direction.rotated(offset)*450
					draw_line(p,tip,Color(0.68,0.21,0.15,0.65),2,true)
					var head = PackedVector2Array([tip,tip-direction.rotated(offset-0.25)*17,tip-direction.rotated(offset+0.25)*17])
					draw_colored_polygon(head,Color("ad3527"))
				continue
			var reach=216.0 if world is ChapterWorld and mob.kind=="mist_fox" else (324.0 if world is ChapterWorld and mob.kind=="boss1" else 350.0)
			var end = p + direction * reach
			var side = direction.orthogonal() * (mob.radius + 8)
			draw_colored_polygon(PackedVector2Array([p-side,p+side,end+side,end-side]),Color(0.68,0.21,0.15,0.16))
			draw_line(p,end,Color(0.68,0.21,0.15,0.85),2,true)

func draw_front() -> void:
	if world == null: return
	for key in world.weapons:
		if key not in ["ward_shard", "shadow_twin"]: continue
		var radius = (80 if key == "ward_shard" else 120) + world.weapons[key]*3
		var count = 6 if key in world.evolved else maxi(2,int(world.effective(key).get("orbit_count",2)) + int(world.weapons[key]>=4))
		for i in range(count):
			var angle = world.time * (2.3 if key == "ward_shard" else -1.6) + TAU*i/count
			var p = world.pos(world.player)+Vector2.from_angle(angle)*radius
			if key=="shadow_twin":
				var frames = Content.actor_frames(int(Content.data.characters[world.character].sprite))
				var texture = frames.get_frame_texture("walk",int(age*9)%frames.get_frame_count("walk"))
				vfx_front.draw_texture_rect(texture,Rect2(p-Vector2(27,51),Vector2(54,54)),false,Color(0.18,0.31,0.39,0.6))
			else:
				vfx_front.draw_arc(world.pos(world.player),radius,angle-0.3,angle,12,Color(0.09,0.21,0.27,0.45),2,true)
				vfx_front.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-11),p+Vector2(8,0),p+Vector2(0,11),p+Vector2(-8,0)]),Color("243e54"))
				vfx_front.draw_line(p-Vector2(0,5),p+Vector2(0,5),Color("e8dfc5"),1.5,false)
	for effect in effects:
		var p = Vector2(effect.x,effect.y)
		var t = 1.0 - effect.life/effect.max_life
		var color = Color(effect.color,1.0-t)
		match effect.kind:
			"ring", "pulse":
				var radius = effect.radius * (0.2+t*0.8)
				vfx_front.draw_arc(p,radius,0,TAU,80,color,2.5*(1-t)+1,true)
				if effect.kind == "pulse":
					for i in range(12):
						var angle = TAU*i/12
						vfx_front.draw_line(p+Vector2.from_angle(angle)*radius*0.85,p+Vector2.from_angle(angle)*radius,color,2,true)
			"chain":
				var end = Vector2(effect.tx,effect.ty)
				var points = PackedVector2Array()
				for i in range(7):
					var point = p.lerp(end,i/6.0)
					if i > 0 and i < 6: point += (end-p).normalized().orthogonal()*sin(i*4+effect.life*50)*9
					points.append(point)
				vfx_front.draw_polyline(points,color,2.5,false)
	for number in numbers:
		var alpha = minf(1,number.life*4)
		var age_value = number.get("age",0.3)
		var pop = 1.0+(0.55 if number.get("crit",false) else 0.25)*maxf(0,1.0-age_value*7.0)
		var font_size = int(number.size*pop)
		var width = Content.title_font.get_string_size(number.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		var at = Vector2(number.x-width*0.5,number.y)
		vfx_front.draw_string_outline(Content.title_font,at,number.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,6,Color(0.03,0.05,0.06,alpha*0.85))
		vfx_front.draw_string(Content.title_font,at,number.text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,Color(number.color,alpha))
