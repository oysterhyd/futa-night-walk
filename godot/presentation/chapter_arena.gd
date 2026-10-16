class_name ChapterArena
extends ArenaView

var camera: Camera2D
var room_shown = -1
var room_props: Array = []
var pillar_views: Dictionary = {}
var market_atlas: Texture2D
var campaign_atlas: Texture2D
var floor_textures: Array=[]
var floor_stage=0
var floor_cut: AtlasTexture
var transition = 0.0
var prop_cache: Dictionary = {}
var ghosts: Array = []
var ghost_timer = 0.0
var light_list := PackedVector4Array()
var light_tints := PackedVector4Array()
var light_origin = Vector2.ZERO
var night_level = 0.6
const C = preload("res://content/chapter_content.gd")

func _ready() -> void:
	super._ready()
	vfx_front.set_meta("combat_art",combat_batch)
	background.visible=false
	fog.visible=false
	fireflies.emitting=false
	market_atlas=load("res://assets/images/market-props-print.png")
	campaign_atlas=load("res://assets/images/campaign-props-print-v2.png")
	for name in ["market","river","temple","tower"]: floor_textures.append(load("res://assets/images/"+name+"-floor-print.png"))
	floor_cut=AtlasTexture.new()
	floor_cut.atlas=load("res://assets/images/market-floor-print.png")
	var size=floor_cut.atlas.get_size()
	floor_cut.region=Rect2(Vector2.ZERO,size)
	camera=Camera2D.new()
	camera.position=Vector2(800,450)
	add_child(camera)

func _process(_dt: float) -> void:
	if camera: camera.enabled=visible

func prop_texture(index: int, atlas_name: String="market") -> AtlasTexture:
	var key=atlas_name+str(index)
	if prop_cache.has(key): return prop_cache[key]
	var texture=AtlasTexture.new()
	texture.atlas=campaign_atlas if atlas_name=="campaign" else market_atlas
	var sheet="campaign-props-print-v2" if atlas_name=="campaign" else "market-props-print"
	var cut=Content.atlas_regions[sheet][int(index/4)].frames[index%4]
	texture.region=Rect2(cut[0],cut[1],cut[2],cut[3])
	texture.filter_clip=true
	prop_cache[key]=texture
	return texture

func bind(run: RunWorld) -> void:
	room_shown=-1
	for view in pillar_views.values(): view.queue_free()
	pillar_views.clear()
	super.bind(run)

func sync(dt: float) -> void:
	if not world is ChapterWorld: super.sync(dt); return
	var changed=room_shown!=world.room_id or floor_stage!=world.stage
	if room_shown!=world.room_id:
		effects.clear(); numbers.clear()
		# Dissolves belong to the room where an enemy died.
		for view in actors.get_children():
			if view is ActorView and view!=player_view: view.queue_free()
		enemy_views.clear()
		for view in pillar_views.values(): view.queue_free()
		pillar_views.clear()
	stage_shown=world.stage
	super.sync(dt)
	fireflies.emitting=false
	var chapter=world as ChapterWorld
	if floor_stage!=chapter.stage:
		floor_stage=chapter.stage
		floor_cut.atlas=floor_textures[clampi(chapter.stage-1,0,3)]
		floor_cut.region=Rect2(Vector2.ZERO,floor_cut.atlas.get_size())
	if changed:
		room_shown=chapter.room_id; transition=0.35
		for view in room_props: view.queue_free()
		room_props.clear()
		for prop in chapter.decorations:
			var sprite=Sprite2D.new()
			sprite.texture=prop_texture(prop.sprite,prop.get("atlas","market"))
			sprite.scale=Vector2.ONE*prop.size/sprite.texture.get_height()
			sprite.position=Vector2(prop.x,prop.y-prop.size*0.5+5)
			sprite.z_index=int(prop.y)
			actors.add_child(sprite); room_props.append(sprite)
		camera.position=_camera_target(chapter)
	camera.position=camera.position.lerp(_camera_target(chapter),1.0-exp(-dt*8))
	# Base class shakes the whole node, which the child camera cancels out.
	# Shake the camera offset instead so impacts are actually felt.
	position=Vector2.ZERO
	camera.offset=Vector2(presentation_rng.randf_range(-shake,shake),presentation_rng.randf_range(-shake,shake)) if Save.profile.settings.shake else Vector2.ZERO
	transition=maxf(0,transition-dt)
	ghost_timer-=dt
	if chapter.player.get("dash_time",0)>0 and ghost_timer<=0 and dt>0:
		ghost_timer=0.035
		var anim=player_view.animated
		ghosts.append({"x":chapter.player.x,"y":chapter.player.y,"life":0.3,"tex":anim.sprite_frames.get_frame_texture(anim.animation,anim.frame),"offset":anim.offset,"scale":anim.scale,"flip":anim.flip_h})
	for ghost in ghosts: ghost.life-=dt
	ghosts=ghosts.filter(func(g): return g.life>0)
	_update_lights(chapter,dt)
	actors.modulate.a=clampf(1-transition*2,0.3,1)
	var live: Dictionary={}
	for mob in chapter.mobs:
		if not mob.get("pillar",false) or mob.hp<=0: continue
		live[mob.uid]=true
		if enemy_views.has(mob.uid): enemy_views[mob.uid].visible=false
		if not pillar_views.has(mob.uid):
			var sprite=Sprite2D.new()
			sprite.texture=prop_texture(11); sprite.scale=Vector2.ONE*165/sprite.texture.get_height()
			actors.add_child(sprite); pillar_views[mob.uid]=sprite
		pillar_views[mob.uid].position=chapter.pos(mob)-Vector2(0,77.5)
		pillar_views[mob.uid].z_index=int(mob.y)
	for key in pillar_views.keys():
		if not live.has(key): pillar_views[key].queue_free(); pillar_views.erase(key)
	queue_redraw()

func _light(p: Vector2, radius: float, intensity: float, color: Color) -> void:
	if light_list.size()>=32 or intensity<=0.01: return
	var s=p-light_origin
	if s.x<-radius or s.y<-radius or s.x>1600+radius or s.y>900+radius: return
	light_list.append(Vector4(s.x,s.y,radius,intensity))
	light_tints.append(Vector4(color.r,color.g,color.b,1.0))

func _update_lights(chapter: ChapterWorld, dt: float) -> void:
	light_origin=camera.get_screen_center_position()-Vector2(800,450)
	light_list.clear(); light_tints.clear()
	var lamp=Color(1.0,0.76,0.44)
	var danger=Color(1.0,0.32,0.2)
	var target_night=[0.8,0.86,0.84,0.9][clampi(chapter.stage-1,0,3)]
	if chapter.room().cleared: target_night*=0.62
	if chapter.ignite_time>0: target_night*=0.55
	night_level=lerpf(night_level,target_night,1.0-exp(-dt*2.5)) if dt>0 else target_night
	var p=chapter.pos(chapter.player)
	var flicker=0.94+0.06*sin(age*11.0)+0.03*sin(age*23.0)
	var radius=290.0+130.0*chapter.flame/chapter.FLAME_MAX
	if chapter.ignite_time>0: radius=470.0
	_light(p+Vector2(0,-30),radius*flicker,1.0 if chapter.ignite_time<=0 else 1.35,lamp)
	for zone in chapter.zones:
		if zone.hostile and zone.warning>0: _light(chapter.pos(zone),zone.radius*1.5,0.75,danger)
	for mob in chapter.mobs:
		if mob.hp<=0: continue
		if mob.boss: _light(chapter.pos(mob)+Vector2(0,-60),240,0.55,danger.lerp(lamp,0.3))
		elif mob.kind=="lantern_wisp": _light(chapter.pos(mob)+Vector2(0,-30),150,0.6,lamp)
		elif mob.get("elite",false): _light(chapter.pos(mob),130,0.4,danger)
	var bolt_count=0
	for bolt in chapter.bolts:
		if bolt_count>=10: break
		if bolt.get("hostile",false): _light(chapter.pos(bolt),80,0.55,danger); bolt_count+=1
	for zone in chapter.zones:
		if not zone.hostile and zone.warning<=0: _light(chapter.pos(zone),zone.radius*1.4,0.5,Content.color_for(zone.source).lightened(0.3))
	for effect in effects:
		if effect.kind in ["pulse","ignite","detonation","enemy_blast","flame_ready"]:
			var t=1.0-effect.life/effect.max_life
			_light(Vector2(effect.x,effect.y),effect.get("radius",200.0)*(0.6+t*0.8),(1.0-t)*1.2,lamp if effect.kind!="enemy_blast" else danger)
	if not chapter.shrine.is_empty(): _light(chapter.pos(chapter.shrine)+Vector2(0,-30),230,0.75+0.4*chapter.shrine.get("progress",0.0),lamp)
	for door in chapter.doors():
		if door.open: _light(door.position+Vector2(0,-40),170,0.5,lamp)
	if chapter.room().cleared:
		var b=chapter.room_bounds
		for corner in [b.position,b.position+Vector2(b.size.x,0),b.position+Vector2(0,b.size.y),b.end]:
			_light(corner+Vector2(-10,-50),240,0.6*flicker,lamp)
	post.material.set_shader_parameter("night",night_level)
	post.material.set_shader_parameter("light_count",light_list.size())
	var padded=light_list.duplicate(); var tints=light_tints.duplicate()
	while padded.size()<32: padded.append(Vector4.ZERO); tints.append(Vector4.ZERO)
	post.material.set_shader_parameter("lights",padded)
	post.material.set_shader_parameter("light_colors",tints)
	post.material.set_shader_parameter("desaturate",desat)
	post.material.set_shader_parameter("flash",flash)
	post.material.set_shader_parameter("age",age)

func _camera_target(chapter: ChapterWorld) -> Vector2:
	var center=chapter.room_bounds.get_center()
	var p=chapter.pos(chapter.player)
	if UI.motion(): p+=chapter.aim.normalized()*36
	var extent=(chapter.room_bounds.size-Vector2(1280,650))*0.5
	var vertical=center.y-35 if chapter.room_bounds.size.y<650 else clampf(p.y,chapter.room_bounds.position.y+260,chapter.room_bounds.end.y-280)
	return Vector2(center.x+clampf(p.x-center.x,-maxf(0,extent.x),maxf(0,extent.x)),vertical)

func consume(event: Dictionary) -> void:
	var at=Vector2(event.get("x",800),event.get("y",450))
	match event.kind:
		"perfect_dodge":
			add_slowmo(0.5,0.3); add_hitstop(0.05,true)
			Sound.play("bell",1.6)
			add_effect("perfect",at,0.5,90,UI.JADE)
			if numbers.size()<70: numbers.append({"x":at.x,"y":at.y-80,"text":"识破","life":0.9,"age":0.0,"color":Color("bfe8df"),"size":30,"crit":true,"vx":0.0})
			return
		"ignite":
			add_hitstop(0.09,true); add_slowmo(0.35,0.45); flash=1.0; shake=maxf(shake,12.0)
			Sound.play("flame",0.8); Sound.play("boss",1.3)
			add_effect("ignite",at,0.9,event.get("radius",360.0),UI.AMBER)
			if numbers.size()<70: numbers.append({"x":at.x,"y":at.y-110,"text":Lore.CHARACTERS.get(event.get("character","keeper"),{}).get("ultimate","燃灯"),"life":1.3,"age":0.0,"color":Color("ffd27a"),"size":40,"crit":true,"vx":0.0})
			return
		"ignite_chain":
			if effects.size()<180: effects.append({"kind":"ignite_chain","x":at.x,"y":at.y,"tx":event.tx,"ty":event.ty,"life":0.4,"max_life":0.4,"radius":0,"color":UI.AMBER})
			Sound.play("swing",1.25)
			return
		"wind_trail":
			if effects.size()<180: effects.append({"kind":"wind_trail","x":at.x,"y":at.y,"tx":event.tx,"ty":event.ty,"life":0.45,"max_life":0.45,"radius":0,"color":UI.JADE})
			return
		"flame_ready":
			Sound.play("upgrade",1.3)
			add_effect("flame_ready",at,0.7,140,UI.AMBER)
			return
		"death":
			if event.get("boss",false): add_hitstop(0.16,true); add_slowmo(0.9,0.25); flash=0.5
			elif event.get("elite",false): add_hitstop(0.07,true)
	if event.kind=="cast":
		Sound.play({"seal":"cast","sword":"swing","hammer":"hammer","needle":"needle","wheel":"wheel","sand":"sand"}[world.gear],presentation_rng.randf_range(0.95,1.05))
		return
	if event.kind=="bell": Sound.play("bell"); return
	if event.kind=="ring" and event.get("source")=="blast_pill":
		Sound.play("flame"); shake=maxf(shake,3.0)
		if effects.size()<160:
			var burst=event.duplicate(); burst.kind="detonation"; burst.life=0.55; burst.max_life=0.55; burst.color=Color("ad3527")
			effects.append(burst)
	if event.kind=="ring" and event.get("source")=="enemy" and effects.size()<160:
		var burst=event.duplicate(); burst.kind="enemy_blast"; burst.life=0.65; burst.max_life=0.65; burst.color=Color("ad3527"); burst.stage=world.stage
		effects.append(burst)
		shake=maxf(shake,2.5 if world.stage==3 else 1.0)
	if event.kind=="hit" and event.amount>=4 and effects.size()<160:
		var impact=event.duplicate()
		impact.kind="impact"; impact.life=0.20; impact.max_life=0.20; impact.color=Content.color_for(event.get("source","spirit"))
		effects.append(impact)
	if event.kind in ["slash","skill","clear","attack_art","enemy_attack","boss_art"]:
		if event.kind=="attack_art" and event.gear in ["sword","hammer"]: return
		var value=event.duplicate()
		value["life"]=0.28 if event.kind in ["slash","attack_art","enemy_attack"] else 0.75
		value["max_life"]=value.life
		value["color"]=Content.color_for(event.get("source","spirit"))
		if effects.size()<180: effects.append(value)
		if event.kind=="slash": shake=maxf(shake,3 if event.heavy else 1.0)
		if event.kind=="skill": Sound.play("ice" if event.skill=="frost" else "cast")
		if event.kind=="enemy_attack": Sound.play("bow" if event.get("enemy_kind")=="archer" else "swing",0.8)
		if event.kind=="boss_art": Sound.play("bell" if event.stage==3 else ("flame" if event.stage==4 else "swing"),0.85)
		if event.kind=="clear": Sound.play("upgrade")
	else: super.consume(event)

func _draw() -> void:
	if not world is ChapterWorld: super._draw(); return
	var chapter=world as ChapterWorld
	var bounds=chapter.room_bounds
	draw_rect(bounds.grow(800),Color("183544"))
	draw_texture_rect(floor_cut,bounds,false,Color(0.98,0.97,0.93))
	draw_rect(bounds,Color("ad3527"),false,3)
	draw_rect(bounds.grow(10),Color("e8dfc5"),false,2)
	# A continuous carved roof band, with authored masonry only at the corners.
	for x in range(int(bounds.position.x),int(bounds.end.x),42):
		draw_line(Vector2(x,bounds.position.y-35),Vector2(x+16,bounds.position.y-9),Color("e8dfc5"),2)
		draw_line(Vector2(x+6,bounds.position.y-35),Vector2(x+22,bounds.position.y-9),Color(0.91,0.87,0.77,0.35),1)
	for p in [bounds.position,bounds.position+Vector2(bounds.size.x,0)]:
		var theme_index=[2,2,6,8][clampi(chapter.stage-1,0,3)]
		draw_texture_rect(prop_texture(theme_index,"market" if chapter.stage==1 else "campaign"),Rect2(p-Vector2(100,135),Vector2(180,150)),false)
	for p in [bounds.position+Vector2(0,bounds.size.y),bounds.end]:
		var theme_index=[1,0,7,11][clampi(chapter.stage-1,0,3)]
		draw_texture_rect(prop_texture(theme_index,"market" if chapter.stage==1 else "campaign"),Rect2(p-Vector2(100,65),Vector2(180,140)),false)
	for door in chapter.doors():
		var p: Vector2=door.position
		var rect=Rect2(p-Vector2(74,105),Vector2(148,150))
		draw_texture_rect(prop_texture(9,"campaign") if chapter.stage==4 and not door.open else prop_texture(8 if door.open else 3),rect,false)
	super._draw()
	for mob in chapter.mobs:
		if mob.windup>0 and not Rect2(camera.position-Vector2(710,285),Vector2(1420,570)).has_point(chapter.pos(mob)):
			var direction=(chapter.pos(mob)-camera.position).normalized()
			var anchor=camera.position+direction*minf(690/maxf(0.01,absf(direction.x)),270/maxf(0.01,absf(direction.y)))
			var side=direction.orthogonal()
			draw_colored_polygon(PackedVector2Array([anchor+direction*12,anchor-direction*8+side*8,anchor-direction*8-side*8]),Color("ad3527"))
		if mob.spawn_age<0.65 and mob.hp>0:
			var p=chapter.pos(mob)
			draw_arc(p,28+12*mob.spawn_age,0,TAU,32,Color(0.68,0.21,0.15,0.7),2)
			for i in range(4):
				var edge=Vector2.from_angle(i*PI/2+age)*34
				draw_line(p+edge*0.65,p+edge,Color("ad3527"),2)

func draw_front() -> void:
	combat_batch.begin_art()
	super.draw_front()
	if not world is ChapterWorld: combat_batch.end_art(); return
	var chapter=world as ChapterWorld
	for zone in chapter.zones:
		if zone.hostile and zone.warning>0 and chapter.stage>1: CombatIllustration.warning(vfx_front,zone,chapter.stage)
	for door in chapter.doors():
		var point=door.position+Vector2(0,-72)
		var distance=chapter.pos(chapter.player).distance_to(door.position)
		if door.open or distance<220: _door_tag(door.name,point,16,Color("ad3527") if distance<145 else Color("183544"))
		if door.open and distance<145:
			var foot=door.position+Vector2(0,25)
			var direction=door.direction
			var side=direction.orthogonal()
			vfx_front.draw_colored_polygon(PackedVector2Array([foot+direction*12,foot-direction*10+side*8,foot-direction*10-side*8]),Color("ad3527"))
	for ghost in ghosts:
		var k=ghost.life/0.3
		vfx_front.draw_set_transform(Vector2(ghost.x,ghost.y),0,Vector2(-1 if ghost.flip else 1,1))
		var size_value: Vector2=ghost.tex.get_size()*ghost.scale
		vfx_front.draw_texture_rect(ghost.tex,Rect2(ghost.offset*ghost.scale,size_value),false,Color(0.5,0.85,0.8,0.45*k))
		vfx_front.draw_set_transform(Vector2.ZERO)
	var p=chapter.pos(chapter.player)
	if chapter.ignite_time>0:
		var aura=130.0+8*sin(age*7)
		vfx_front.draw_texture_rect(UI.glow(),Rect2(p-Vector2(aura,aura*0.7)*1.4,Vector2(aura,aura*0.7)*2.8),false,Color(1,0.7,0.35,0.25))
		for i in range(10):
			var a=age*1.8+i*TAU/10
			var q=p+Vector2(cos(a)*aura,sin(a)*aura*0.55)
			vfx_front.draw_colored_polygon(PackedVector2Array([q+Vector2(0,-14),q+Vector2(5,0),q+Vector2(0,6),q+Vector2(-5,0)]),Color(1,0.72,0.3,0.85))
	for mob in chapter.mobs:
		if mob.hp<=0 or not mob.get("elite",false) or not C.AFFIXES.has(mob.get("affix","")): continue
		var tag=C.AFFIXES[mob.affix].name
		var head=chapter.pos(mob)+Vector2(0,-112)
		var width=Content.body_font.get_string_size(tag,HORIZONTAL_ALIGNMENT_LEFT,-1,15).x
		vfx_front.draw_rect(Rect2(head-Vector2(width*0.5+8,16),Vector2(width+16,22)),Color(0.05,0.08,0.1,0.82))
		vfx_front.draw_rect(Rect2(head-Vector2(width*0.5+8,16),Vector2(width+16,22)),Color(1,0.4,0.28,0.85),false,1)
		vfx_front.draw_string(Content.body_font,head-Vector2(width*0.5,0),tag,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("ffb49a"))
	var cursor=p+chapter.aim*75
	vfx_front.draw_arc(cursor,7,0,TAU,20,Color("183544"),1.5)
	vfx_front.draw_line(p+chapter.aim*28,p+chapter.aim*58,Color(0.09,0.21,0.27,0.4),1)
	if chapter.shield>0:
		vfx_front.draw_arc(p,29,-PI,0,36,Color("396376"),2.5)
	for mob in chapter.mobs:
		if mob.hp<=0 or mob.charging<=0: continue
		var direction=Vector2(mob.dx,mob.dy).normalized()
		var side=Vector2(-direction.y,direction.x)
		for i in range(3):
			var point=chapter.pos(mob)-direction*(20+i*15)
			vfx_front.draw_line(point+side*12,point-direction*24+side*6,Color("e8dfc5"),3)
			vfx_front.draw_line(point-side*12,point-direction*24-side*6,Color("ad3527"),2)
	if chapter.shadow_time>0:
		var count=(3 if chapter.skill_mod==0 else 2)+(1 if "fox_mirror" in chapter.relics else 0)
		var frame=Content.actor_frames(int(Content.data.characters[chapter.character].sprite)).get_frame_texture("walk",int(age*9)%6)
		for i in range(count):
			var point=p+chapter.aim.orthogonal()*(i-(count-1)*0.5)*70-chapter.aim*35
			vfx_front.draw_texture_rect(frame,Rect2(point-Vector2(35,83),Vector2(70,88)),false,Color(0.15,0.25,0.32,0.48))
	for effect in effects:
		if effect.kind in ["slash","skill","attack_art","impact","enemy_attack","enemy_blast","detonation","boss_art"]:
			CombatIllustration.draw(vfx_front,effect)
			continue
		if effect.kind in ["ignite","perfect","flame_ready","ignite_chain","wind_trail"]:
			_draw_special(effect)
			continue
		if effect.kind!="clear": continue
		var point=Vector2(effect.x,effect.y)
		var t=1.0-effect.life/effect.max_life
		var color=Color(effect.color,1.0-t)
		if effect.kind=="slash":
			var start=effect.angle-1.7+t*0.65
			var radius=effect.radius*(0.6+t*0.4)
			vfx_front.draw_arc(point,radius,start,start+2.8,32,color,8 if effect.heavy else 4)
			vfx_front.draw_arc(point,radius*0.85,start+0.15,start+2.5,32,Color(Color("e8dfc5"),1.0-t),2)
			for i in range(7):
				var direction=Vector2.from_angle(start+i*0.4)
				vfx_front.draw_line(point+direction*radius*0.7,point+direction*radius,color,1.5)
		else:
			var radius=effect.get("radius",200.0)*(0.25+t*0.75)
			vfx_front.draw_arc(point,radius,age*0.15,age*0.15+TAU,64,color,2)
			for i in range(12):
				var direction=Vector2.from_angle(i*TAU/12)
				var side=direction.orthogonal()
				var tip=point+direction*radius
				vfx_front.draw_colored_polygon(PackedVector2Array([tip+direction*9,tip+side*4,tip-direction*9,tip-side*4]),color)
	combat_batch.end_art()

func _draw_special(effect: Dictionary) -> void:
	var p=Vector2(effect.x,effect.y)
	var t=1.0-effect.life/effect.max_life
	match effect.kind:
		"ignite":
			var r=effect.radius*ease(t,0.35)
			vfx_front.draw_texture_rect(UI.glow(),Rect2(p-Vector2(r,r)*1.2,Vector2(r,r)*2.4),false,Color(1,0.75,0.4,0.55*(1-t)))
			vfx_front.draw_arc(p,r,0,TAU,96,Color(1,0.85,0.55,1-t),10*(1-t)+2,true)
			vfx_front.draw_arc(p,r*0.82,0,TAU,96,Color(1,0.55,0.25,0.7*(1-t)),3,true)
			for i in range(24):
				var d=Vector2.from_angle(i*TAU/24+t*0.6)
				vfx_front.draw_line(p+d*r*0.55,p+d*r*(1.0+0.12*sin(i*3.0)),Color(1,0.8,0.45,0.8*(1-t)),3,true)
		"perfect":
			var r=effect.radius*(1.0-0.6*t)
			vfx_front.draw_arc(p,r,0,TAU,64,Color(0.6,0.95,0.88,1-t),3,true)
			vfx_front.draw_arc(p,r*1.25,-t*2,-t*2+PI,48,Color(0.6,0.95,0.88,0.6*(1-t)),2,true)
		"flame_ready":
			var r=effect.radius*(0.3+t*0.9)
			vfx_front.draw_arc(p+Vector2(0,-30),r,0,TAU,64,Color(1,0.78,0.4,1-t),4*(1-t)+1,true)
		"ignite_chain":
			var end=Vector2(effect.tx,effect.ty)
			var width=14.0*(1-t)+2
			vfx_front.draw_line(p,end,Color(1,0.7,0.35,0.55*(1-t)),width*1.8,true)
			vfx_front.draw_line(p,end,Color(1,0.97,0.88,1-t),width*0.5,true)
			vfx_front.draw_circle(end,18*(1-t)+4,Color(1,0.9,0.7,0.8*(1-t)))
		"wind_trail":
			var end=Vector2(effect.tx,effect.ty)
			var side=(end-p).normalized().orthogonal()
			for i in range(3):
				var o=side*(i-1)*12
				vfx_front.draw_line(p+o,end+o*0.4,Color(0.6,0.92,0.85,(0.7-i*0.15)*(1-t)),4-i,true)

func _door_tag(text: String, baseline: Vector2, font_size: int, color: Color) -> void:
	var width=Content.body_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	var box=Rect2(baseline-Vector2(width*0.5+7,font_size+2),Vector2(width+14,font_size+8))
	vfx_front.draw_rect(box,Color("e8dfc5"))
	vfx_front.draw_line(box.position+Vector2(4,1),Vector2(box.end.x-4,box.position.y+1),Color("183544"),1)
	vfx_front.draw_string(Content.body_font,baseline-Vector2(width*0.5,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)
