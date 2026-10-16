class_name HudView
extends Control

# Procedural combat HUD: portrait medallion with the 燃灯 flame ring, health with
# a trailing ghost bar, dash pips, skill cooldown dials, boss bar, school chips.
const C = preload("res://content/chapter_content.gd")
var app
var world: ChapterWorld
var portrait: Texture2D
var age = 0.0
var hp_ghost = 1.0
var boss_ghost = 1.0
var last_hp = -1.0
var hurt_flash = 0.0
var flame_was_ready = false
var ready_pulse = 0.0
var boss_name = ""
var boss_epithet = ""
var boss_fraction = 1.0
var boss_enraged = false
var has_boss = false
var notice_alpha = 0.0
var notice_width = 0.0

func setup(owner_app) -> void:
	app = owner_app
	world = app.world
	size = Vector2(1600,900)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	portrait = Content.sprite(int(Content.data.characters[world.character].sprite))
	hp_ghost = world.player.hp/maxf(1,world.player.max_hp)

func _process(dt: float) -> void:
	if world == null: return
	age += dt
	var fraction = clampf(world.player.hp/maxf(1,world.player.max_hp),0,1)
	if last_hp >= 0 and world.player.hp < last_hp: hurt_flash = 1.0
	last_hp = world.player.hp
	hp_ghost = fraction if fraction>hp_ghost else move_toward(hp_ghost,fraction,dt*0.45)
	boss_ghost = boss_fraction if boss_fraction>boss_ghost else move_toward(boss_ghost,boss_fraction,dt*0.3)
	hurt_flash = maxf(0,hurt_flash-dt*3)
	var ready = world.can_ignite()
	if ready and not flame_was_ready: ready_pulse = 1.0
	flame_was_ready = ready
	ready_pulse = maxf(0,ready_pulse-dt*1.4)
	queue_redraw()

func _bar(rect: Rect2, fraction: float, ghost: float, color: Color, ghost_color: Color) -> void:
	draw_rect(rect.grow(2),Color(0,0,0,0.55))
	draw_rect(rect,Color("1a2a30"))
	if ghost>fraction: draw_rect(Rect2(rect.position,Vector2(rect.size.x*ghost,rect.size.y)),ghost_color)
	if fraction>0:
		draw_rect(Rect2(rect.position,Vector2(rect.size.x*fraction,rect.size.y)),color)
		draw_rect(Rect2(rect.position,Vector2(rect.size.x*fraction,rect.size.y*0.35)),Color(1,1,1,0.14))
	for i in range(1,10): draw_line(rect.position+Vector2(rect.size.x*i/10.0,0),rect.position+Vector2(rect.size.x*i/10.0,rect.size.y),Color(0,0,0,0.22),1)
	draw_rect(rect.grow(2),Color(UI.BRASS,0.5),false,1)

func _diamond(p: Vector2, r: float, color: Color, filled: bool = true) -> void:
	var points = PackedVector2Array([p+Vector2(0,-r),p+Vector2(r,0),p+Vector2(0,r),p+Vector2(-r,0)])
	if filled: draw_colored_polygon(points,color)
	else:
		points.append(points[0])
		draw_polyline(points,color,1.5,true)

func _dial(center: Vector2, radius: float, fraction: float) -> void:
	# dark wedge sweeping clockwise over a skill icon while it recharges
	if fraction <= 0.001: return
	var points = PackedVector2Array([center])
	var steps = 28
	for i in range(steps+1):
		var angle = -PI/2 + TAU*fraction*float(i)/steps
		points.append(center+Vector2.from_angle(angle)*radius)
	if points.size()>=3: draw_colored_polygon(points,Color(0.02,0.04,0.05,0.62))

func _draw() -> void:
	if world == null: return
	var w = world
	# --- portrait medallion & flame ring ---
	var center = Vector2(88,820)
	draw_texture_rect(UI.glow(),Rect2(center-Vector2(110,110),Vector2(220,220)),false,Color(UI.AMBER,0.10+0.25*ready_pulse+(0.18 if w.ignite_time>0 else 0.0)))
	draw_circle(center,50,Color(0,0,0,0.55))
	draw_circle(center,45,Color("1a2c33"))
	if portrait: draw_texture_rect(portrait,Rect2(center-Vector2(44,50),Vector2(88,88)),false)
	draw_arc(center,46,0,TAU,48,Color(UI.BRASS,0.7),1.5,true)
	var flame_fraction = clampf(w.flame/w.FLAME_MAX,0,1)
	draw_arc(center,53,0,TAU,64,Color(0,0,0,0.5),6,true)
	if w.ignite_time>0:
		var total = {"swordswoman":4.0,"alchemist":5.0}.get(w.character,8.0)
		draw_arc(center,53,-PI/2,-PI/2+TAU*clampf(w.ignite_time/total,0,1),64,UI.BRIGHT,5,true)
	elif flame_fraction>0:
		var ready = w.can_ignite()
		var color = UI.AMBER if ready else UI.GOLD.lerp(UI.AMBER,flame_fraction*0.6)
		if ready: color = color.lerp(UI.BRIGHT,0.25+0.25*sin(age*6))
		draw_arc(center,53,-PI/2,-PI/2+TAU*flame_fraction,64,color,5 if ready else 4,true)
		if ready:
			draw_arc(center,60+4*sin(age*6),0,TAU,64,Color(UI.AMBER,0.35),2,true)
			# little flame tongues around the ring
			for i in range(8):
				var a = age*0.8+i*TAU/8
				var p = center+Vector2.from_angle(a)*58
				_diamond(p,3+sin(age*9+i)*1.2,Color(UI.AMBER,0.85))
	if ready_pulse>0: draw_arc(center,53+40*(1-ready_pulse),0,TAU,64,Color(UI.AMBER,ready_pulse*0.8),3*ready_pulse+1,true)
	# --- health ---
	var hp_rect = Rect2(160,812,330,14)
	var fraction = clampf(w.player.hp/maxf(1,w.player.max_hp),0,1)
	var hp_color = UI.GOLD.lerp(Color("ff8a5c"),0.3*sin(age*10)*float(fraction<0.3)) if fraction>0 else UI.GOLD
	_bar(hp_rect,fraction,hp_ghost,hp_color,Color(1,0.92,0.8,0.55))
	if w.shield>0:
		var sfrac = clampf(w.shield/maxf(1,w.player.max_hp),0,1)
		draw_rect(Rect2(hp_rect.position+Vector2(0,-5),Vector2(hp_rect.size.x*sfrac,4)),UI.JADE)
	if hurt_flash>0: draw_rect(hp_rect.grow(3),Color(1,0.85,0.7,hurt_flash*0.6),false,2)
	# --- dash pips ---
	var dash_max = w.dash_max()
	for i in range(dash_max):
		var p = Vector2(176+i*24,850)
		_diamond(p,8,Color(0,0,0,0.5))
		if i < w.dash_charges: _diamond(p,7,UI.JADE.lerp(UI.BRIGHT,0.15))
		elif i == w.dash_charges:
			var k = 1.0-clampf(w.dash_recharge/maxf(0.01,w._dash_interval()),0,1)
			_diamond(p,7*k,Color(UI.JADE,0.55))
			_diamond(p,7,Color(UI.JADE,0.6),false)
		else: _diamond(p,7,Color(UI.JADE,0.35),false)
	if w.perfect_time>0:
		draw_texture_rect(UI.glow(),Rect2(150,820,140,60),false,Color(UI.JADE,0.35*clampf(w.perfect_time,0,1)))
	# --- skill dials ---
	var skill_center = Vector2(818,834)
	var cooldown = C.SKILLS[w.skill].cooldown
	_dial(skill_center,30,clampf(w.skill_cd/maxf(0.01,cooldown),0,1))
	if w.skill_cd<=0: draw_arc(skill_center,33,0,TAU,40,Color(UI.AMBER,0.55+0.2*sin(age*4)),1.5,true)
	# --- school chips ---
	var x = 1190.0
	for key in ["yan","feng","zhen","you"]:
		var count = w.school_count(key)
		var tier = w.school_tier(key)
		var color = Color(C.SCHOOLS[key].color)
		var p = Vector2(x,112)
		_diamond(p,7,Color(color,0.25 if count==0 else 0.95),true)
		if tier>=1: draw_arc(p,11,0,TAU,20,Color(color,0.8),1.5,true)
		if tier>=2: draw_arc(p,14,0,TAU,24,Color(UI.BRIGHT,0.6+0.3*sin(age*4)),1,true)
		x += 92
	# --- boss bar ---
	if has_boss:
		var rect = Rect2(450,72,700,12)
		draw_texture_rect(UI.brush(),Rect2(380,8,840,100),false,Color(0.02,0.04,0.05,0.7))
		_bar(rect,boss_fraction,boss_ghost,UI.GOLD.lerp(Color("ff5a3a"),0.5+0.5*sin(age*8)) if boss_enraged else UI.GOLD,Color(1,0.9,0.75,0.5))
		for edge in [rect.position+Vector2(-14,6),rect.end+Vector2(14,-6)]:
			_diamond(edge,6,UI.AMBER)
	# --- notice backdrop ---
	if notice_alpha>0.01:
		draw_texture_rect(UI.brush(),Rect2(800-notice_width*0.5-70,140,notice_width+140,58),false,Color(0.02,0.04,0.05,0.72*notice_alpha))
