class_name CombatVfx
extends RefCounted

# Turns combat events into layered effects:
#   ground  (world, under actors, night-graded): seals, scorch, cracks, ink stains
#   air     (CanvasLayer above the night grade): slashes, fire, sparks, smoke, glow
# Every effect is built from three reads: a dark ink silhouette so it holds on
# paper floors, a coloured glow for energy, and a white-hot core for impact.

const INK = Color(0.05,0.07,0.09,0.9)
const INK_SOFT = Color(0.08,0.1,0.12,0.55)
const FIRE = Color(1.0,0.45,0.14)
const EMBER = Color(1.0,0.62,0.25)
const GOLD = Color(1.0,0.8,0.4)
const JADE = Color(0.45,0.95,0.82)
const PEACH = Color(1.0,0.74,0.66)
const FROST = Color(0.58,0.86,1.0)
const POISON = Color(0.52,0.95,0.32)
const MIASMA = Color(0.26,0.4,0.12,0.62)
const VIOLET = Color(0.7,0.55,1.0)
const THUNDER = Color(1.0,0.88,0.5)
const HOSTILE = Color(1.0,0.3,0.18)
const BODY = Vector2(0,-38)

# effect families spawned this session (tests check the real art fired)
var fired: Dictionary = {}
var arena
var ground: VfxLayer
var air: VfxLayer
var rng = RandomNumberGenerator.new()
var last_slash_radius = 145.0
var flights: Array = []
var hits_this_frame = 0
var seen_mobs: Dictionary = {}
var age = 0.0

func _init(owner, ground_layer: VfxLayer, air_layer: VfxLayer) -> void:
	arena = owner
	ground = ground_layer
	air = air_layer
	rng.randomize()

func clear() -> void:
	ground.clear(); air.clear(); flights.clear(); seen_mobs.clear()

func lite() -> bool:
	return not Save.profile.settings.get("particles",true)

func n(count: int) -> int:
	# Decorative particle count; reduced when particle effects are turned off.
	return maxi(1,int(count*0.35)) if lite() else count

# ---------- building blocks ----------

func flare(p: Vector2, size: float, color: Color, life: float = 0.18, hot: float = 0.8, cell: String = "flare") -> VfxLayer.Particle:
	var f = air.sprite(cell,p,life,size*0.6,color,true)
	f.size1 = Vector2.ONE*size; f.size_ease = 0.3; f.hot = hot; f.rot = rng.randf()*0.4-0.2
	return f

func glow(p: Vector2, size: float, color: Color, life: float = 0.3) -> VfxLayer.Particle:
	var g = air.sprite("glow",p,life,size,color,true)
	g.size1 = Vector2.ONE*size*1.25
	return g

func sparks(p: Vector2, count: int, color: Color, speed: Vector2, length: float, life: float, direction: float = 0.0, cone: float = PI) -> void:
	for i in range(n(count)):
		var a = direction+rng.randf_range(-cone,cone)
		var s = air.sprite("thin_streak",p,life*rng.randf_range(0.7,1.2),1.0,color,true)
		s.vel = Vector2.from_angle(a)*rng.randf_range(speed.x,speed.y)
		s.drag = 5.0; s.align = true; s.hot = 0.6
		s.size0 = Vector2(length,length*0.22); s.size1 = Vector2(length*0.3,length*0.1)

func embers(p: Vector2, count: int, color: Color, spread: float, rise: float = 70.0, life: float = 0.9) -> void:
	for i in range(n(count)):
		var e = air.sprite("glow",p+Vector2(rng.randf_range(-spread,spread),rng.randf_range(-spread,spread)*0.6),life*rng.randf_range(0.6,1.3),rng.randf_range(6,13),color,true)
		e.vel = Vector2(rng.randf_range(-40,40),-rng.randf_range(rise*0.5,rise*1.4))
		e.acc = Vector2(rng.randf_range(-20,20),-20); e.drag = 0.6; e.hot = 0.9
		e.size1 = Vector2.ONE*2

func smoke_burst(p: Vector2, count: int, color: Color, size: float, speed: float, life: float = 0.9, rise: float = 0.0, layer: VfxLayer = null, add: bool = false) -> void:
	var target = layer if layer else air
	for i in range(n(count)):
		var a = rng.randf()*TAU
		var s = target.smoke(p+Vector2.from_angle(a)*size*0.15,life*rng.randf_range(0.75,1.25),size*rng.randf_range(0.7,1.2),color,add)
		s.vel = Vector2.from_angle(a)*speed*rng.randf_range(0.4,1.0)+Vector2(0,-rise)
		s.drag = 2.4

func shock(p: Vector2, radius: float, color: Color, life: float = 0.45, ink: bool = true, thick: float = 0.12) -> void:
	air.ring(p,radius,thick,life,color,true)
	if ink: air.ring(p,radius*1.02,thick*1.3,life*1.05,INK_SOFT,false)

func decal(cell: String, p: Vector2, size: float, color: Color, life: float = 1.6) -> VfxLayer.Particle:
	var d = ground.sprite(cell,p,life,size,color,false)
	d.c1 = Color(color,0.0); d.e0 = 0.0; d.e1 = 0.7
	d.size0 = Vector2.ONE*size*0.7; d.size1 = Vector2.ONE*size; d.size_ease = 0.15
	return d

func petals(p: Vector2, count: int, direction: float, spread: float, speed: float = 220.0) -> void:
	for i in range(n(count)):
		var cell = "blossom" if rng.randf()<0.3 else "petal"
		var s = air.sprite(cell,p,rng.randf_range(0.7,1.3),rng.randf_range(12,20),Color(1,1,1,0.95),false)
		s.vel = Vector2.from_angle(direction+rng.randf_range(-spread,spread))*rng.randf_range(speed*0.4,speed)
		s.acc = Vector2(rng.randf_range(-30,30),55); s.drag = 2.2; s.spin = rng.randf_range(-7,7)
		s.c1 = Color(1,1,1,0)

func debris(p: Vector2, count: int, cell: String, color: Color, speed: float, size: float = 16.0) -> void:
	for i in range(n(count)):
		var s = air.sprite(cell,p,rng.randf_range(0.5,0.9),size*rng.randf_range(0.7,1.3),color,false)
		s.vel = Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(speed*0.4,speed)+Vector2(0,-speed*0.5)
		s.acc = Vector2(0,520); s.drag = 1.2; s.spin = rng.randf_range(-9,9)
		s.c1 = Color(color,0)

func lightning(a: Vector2, b: Vector2, color: Color, width: float = 26.0, life: float = 0.2) -> void:
	for cell in ["bolt_a","bolt_b"]:
		var s = air.segment(cell,a,b,width*rng.randf_range(0.8,1.2),life,color,true)
		s.hot = 0.8; s.flip = -1.0 if rng.randf()<0.5 else 1.0
	flare(a,40,color,0.12); flare(b,60,color,0.16)
	air.flash(b,140,0.7,color,0.15)

# ---------- events ----------

func consume(event: Dictionary) -> void:
	var p = Vector2(event.get("x",800),event.get("y",450))
	match event.kind:
		"slash": last_slash_radius = event.get("radius",145.0)
		"attack_art": attack(event,p)
		"hit": hit(event,p)
		"death": death(event,p)
		"skill": skill(event,p)
		"ring": ring_event(event,p)
		"chain": lightning(p+BODY,Vector2(event.tx,event.ty)+BODY,Color(0.7,0.78,1.0),24.0)
		"reaction": reaction(event,p)
		"dash": dash(event,p)
		"perfect_dodge": perfect(p)
		"ignite": ignite(event,p)
		"ignite_chain": ignite_cut(p,Vector2(event.tx,event.ty))
		"wind_trail":
			var b = Vector2(event.tx,event.ty)
			for i in range(3):
				var o = (b-p).normalized().orthogonal()*(i-1)*14
				var s = air.segment("streak",p+o+BODY,b+o+BODY,14-i*3,0.4,Color(JADE,0.8),true)
				s.hot = 0.4
		"flame_ready":
			for i in range(n(14)):
				var a = -PI/2+rng.randf_range(-1.2,1.2)
				var f = air.sprite("flame_tongue",p+Vector2(rng.randf_range(-26,26),-10),0.6,rng.randf_range(26,44),EMBER,true)
				f.vel = Vector2.from_angle(a)*rng.randf_range(80,160); f.rot = 0; f.hot = 0.6; f.drag = 2.0
			air.ring(p+BODY,120,0.1,0.55,GOLD,true)
			flare(p+BODY,160,GOLD,0.35,0.6,"soft_star")
		"hurt":
			flare(p+BODY,90,HOSTILE,0.2,0.4,"burst")
			decal("ink_spray",p+Vector2(rng.randf_range(-20,20),rng.randf_range(-6,10)),70,Color(0.42,0.06,0.04,0.6),1.4)
			sparks(p+BODY,6,HOSTILE,Vector2(160,320),28,0.25)
		"heal","upgrade","shrine":
			embers(p,18,Color(0.6,1.0,0.75),30,110,1.1)
			air.ring(p+BODY,90,0.12,0.6,JADE,true)
		"enemy_attack": enemy_swipe(event,p)
		"enemy_blast", "boss_art": pass
		"clear":
			for i in range(n(40)):
				var q = Vector2(event.x+rng.randf_range(-600,600),event.y+rng.randf_range(-260,260))
				embers(q,1,GOLD,10,60,1.6)
		"enrage":
			shock(p+Vector2(0,-60),260,HOSTILE,0.7)
			smoke_burst(p,8,Color(0.25,0.03,0.02,0.6),110,140,1.0)

func attack(event: Dictionary, p: Vector2) -> void:
	var angle: float = event.angle
	var dir = Vector2.from_angle(angle)
	var center = p+BODY*0.6
	var crit: bool = event.get("critical",false)
	match event.gear:
		"sword":
			var combo = int(event.get("combo",1))
			var finisher = combo == 0
			var r = last_slash_radius*(1.12 if finisher else 1.0)
			var span = 1.7 if finisher else 1.42
			var flip = combo == 2
			# dry-brush ink stroke behind, luminous qi crescent, white-hot edge, lagging afterimage
			air.arc(center,angle,r*1.05,span,0.3,1,0.3,Color(0.07,0.09,0.15,0.78),false,flip)
			air.arc(center,angle,r,span,0.28,0,0.27,Color(PEACH,0.95),true,flip)
			air.arc(center,angle,r*1.01,span,0.1,0,0.24,Color(1,0.97,0.9),true,flip)
			var ghost = air.arc(center,angle,r*0.86,span*0.92,0.2,0,0.26,Color(PEACH,0.4),true,flip)
			ghost.delay = 0.035
			if finisher:
				var second = air.arc(center,angle+0.12,r*1.2,span*0.85,0.18,0,0.3,Color(JADE,0.9),true,not flip)
				second.delay = 0.05
				var ink2 = air.arc(center,angle+0.12,r*1.22,span*0.85,0.22,1,0.32,INK,false,not flip)
				ink2.delay = 0.05
				flare(center+dir*r*0.8,150,Color(1,0.95,0.85),0.2,1.0,"burst")
				petals(center+dir*r*0.6,10,angle,1.3,320)
				arena.shake = maxf(arena.shake,4.0)
			else:
				petals(center+dir*r*0.7,3,angle,1.0,200)
			# tangential sparks shed from the blade edge
			for i in range(n(5)):
				var a = angle+rng.randf_range(-span,span)*0.8
				var q = center+Vector2.from_angle(a)*r
				var s = air.sprite("thin_streak",q,0.22,1.0,Color(1,0.9,0.75),true)
				s.vel = Vector2.from_angle(a+(-PI/2 if flip else PI/2)*0.6)*rng.randf_range(160,320)
				s.align = true; s.drag = 6; s.size0 = Vector2(30,6); s.size1 = Vector2(6,2); s.hot = 0.7
			air.flash(center+dir*r*0.5,r*1.4,0.55,PEACH,0.14)
			if crit: flare(center+dir*r*0.85,130,GOLD,0.2,1.0,"burst")
		"hammer":
			var r = last_slash_radius
			var quake = arena.world.gear_mod == 0
			air.arc(center,angle,r*1.05,1.0,0.5,1,0.3,INK,false)
			air.arc(center,angle,r,1.0,0.38,0,0.26,Color(GOLD,0.95),true)
			var hit_at = p+dir*r*0.62 if not quake else p
			var size = r*1.3 if not quake else 380.0
			decal("crack",hit_at,size,Color(0.06,0.07,0.08,0.85),1.6)
			decal("scorch_b",hit_at,size*0.8,Color(0.1,0.08,0.06,0.35),1.2)
			shock(hit_at,size*0.55,GOLD,0.42)
			smoke_burst(hit_at,9,Color(0.42,0.36,0.28,0.5),70,200,0.8)
			debris(hit_at,7,"dirt_a",Color(0.3,0.25,0.2),260,22)
			sparks(hit_at,8,GOLD,Vector2(220,420),34,0.3)
			flare(hit_at,170,Color(1,0.9,0.7),0.18,1.0,"burst")
			air.flash(hit_at,260,1.0,GOLD,0.2)
			arena.shake = maxf(arena.shake,6.0)
		"seal":
			var muzzle = center+dir*34
			flare(muzzle,54,FIRE,0.12,0.8)
			for i in range(n(3)):
				var e = air.sprite("glow",muzzle,0.3,8,EMBER,true)
				e.vel = Vector2.from_angle(angle+rng.randf_range(-0.7,0.7))*rng.randf_range(90,200); e.drag = 4; e.hot = 1.0
		"needle":
			flare(center+dir*30,40,POISON,0.1,0.7)
		"wheel":
			var c = air.sprite(["crackle_a","crackle_b","crackle_c"][rng.randi_range(0,2)],center+dir*30,0.12,70,Color(0.75,0.8,1.0),true)
			c.hot = 0.6
		"sand":
			for i in range(n(8)):
				var a = angle+rng.randf_range(-0.45,0.45)
				var s = air.sprite("snowflake",center+dir*28,rng.randf_range(0.35,0.6),rng.randf_range(7,13),Color(0.85,0.95,1.0,0.95),true)
				s.vel = Vector2.from_angle(a)*rng.randf_range(160,380); s.drag = 3.5; s.spin = rng.randf_range(-6,6)
			var m = air.smoke(center+dir*50,0.5,60,Color(0.75,0.9,1.0,0.25),true)
			m.vel = dir*120

func hit(event: Dictionary, p: Vector2) -> void:
	if event.get("amount",0) < 1: return
	hits_this_frame += 1
	var source: String = event.get("source","spirit")
	var color: Color = Content.color_for(source).lightened(0.35)
	var crit: bool = event.get("critical",false)
	var q = p+BODY+Vector2(rng.randf_range(-8,8),rng.randf_range(-8,8))
	flare(q,(110 if crit else 64),color,0.14,0.9)
	if hits_this_frame > 10: return
	sparks(q,4 if not crit else 9,color,Vector2(140,320),24,0.2)
	if crit:
		flare(q,150,Color(1,0.95,0.8),0.2,1.0,"burst")
		air.ring(q,70,0.16,0.25,Color(1,0.9,0.6),true)
	match source:
		"fire_talisman","blast_pill","ignite_lamp","ignite_furnace","school_blast":
			var f = air.sprite(["fire_a","fire_b"][rng.randi_range(0,1)],q,0.3,44,FIRE,true)
			f.size1 = Vector2.ONE*70; f.hot = 0.5; f.e1 = 0.8
			embers(q,3,EMBER,10,90,0.6)
		"poison_mist":
			var s = air.sprite("ink_spray",q,0.35,46,Color(0.5,0.9,0.3,0.85),false)
			s.size1 = Vector2.ONE*60; s.e1 = 0.9
		"thunder_mark","shock_ring":
			var c = air.sprite(["crackle_a","crackle_b"][rng.randi_range(0,1)],q,0.14,80,Color(0.8,0.85,1.0),true)
			c.hot = 0.7
		"frost_sand","frost_ring":
			debris(q,3,"ice_shard",Color(1,1,1,0.95),200,18)
		"piercing_spike","armor_breaker","ignite_blade":
			var a = rng.randf()*TAU
			var cut = air.segment("streak",q-Vector2.from_angle(a)*55,q+Vector2.from_angle(a)*55,10 if not crit else 16,0.16,Color(1,0.96,0.9),true)
			cut.hot = 1.0; cut.size1 = Vector2(150,2)
			if hits_this_frame <= 4: decal(["ink_a","ink_b"][rng.randi_range(0,1)],p+Vector2(rng.randf_range(-12,12),4),46,Color(0.06,0.07,0.08,0.45),1.2)

func death(event: Dictionary, p: Vector2) -> void:
	var kind: String = event.get("enemy_kind","")
	var boss: bool = event.get("boss",false)
	var elite: bool = event.get("elite",false)
	var scale = 2.4 if boss else (1.4 if elite else 1.0)
	var q = p+BODY*scale
	smoke_burst(q,5,Color(0.07,0.09,0.11,0.6),60*scale,120*scale,0.8)
	if elite or boss: air.ring(q,70*scale,0.14,0.35,INK_SOFT,false)
	decal("ink_a" if rng.randf() < 0.5 else "ink_b",p,64*scale,Color(0.06,0.07,0.09,0.22),1.4)
	# charred paper ash curling upward while the body burns away
	for i in range(n(int(7*scale))):
		var ash = air.sprite("paper_b" if i%2 else "paper_a",q+Vector2(rng.randf_range(-20,20),rng.randf_range(-24,16))*scale,rng.randf_range(0.7,1.2),rng.randf_range(8,14),Color(0.16,0.12,0.1,0.9),false)
		ash.vel = Vector2(rng.randf_range(-50,50),-rng.randf_range(60,140)); ash.drag = 1.2; ash.spin = rng.randf_range(-7,7); ash.acc = Vector2(rng.randf_range(-30,30),-10)
	embers(q,6,EMBER,18*scale,120,0.8)
	var soul = air.sprite("flame_tongue",q,0.9,34*scale,Color(0.6,0.9,1.0,0.8),true)
	soul.vel = Vector2(0,-90); soul.rot = 0; soul.size1 = Vector2(10,40)*scale; soul.hot = 0.4
	match kind:
		"paper_spirit","archer":
			debris(q,7,["paper_a","paper_b"][rng.randi_range(0,1)],Color(1,1,1,1),240,20)
		"lantern_wisp":
			var f = air.sprite("fire_b",q,0.4,60,FIRE,true); f.size1 = Vector2.ONE*120; f.hot = 0.5; f.e1 = 0.9
			embers(q,10,EMBER,20,120,0.9)
		"mist_fox":
			smoke_burst(q,6,Color(0.8,0.9,1.0,0.35),70,120,1.0,30,null,true)
			for i in range(n(3)):
				var w = air.sprite("flame_tongue",q,0.9,28,Color(0.5,0.8,1.0,0.85),true)
				w.vel = Vector2(rng.randf_range(-90,90),-rng.randf_range(40,120)); w.rot = 0; w.hot = 0.5
		"stone_guard":
			debris(q,9,"dirt_b",Color(0.32,0.3,0.28),280,26)
			smoke_burst(p,6,Color(0.45,0.4,0.33,0.45),80,160,0.8)
	if elite or boss:
		flare(q,260*scale*0.6,Color(1,0.92,0.75),0.35,1.0,"burst")
		var rays = air.sprite("rays",q,0.6,120*scale,Color(1,0.85,0.6,0.7),true); rays.size1 = Vector2.ONE*300*scale; rays.spin = 0.6
		shock(q,180*scale,GOLD,0.6)
		air.flash(q,300*scale,1.2,GOLD,0.4)
	if boss:
		for i in range(6):
			var b = flare(q+Vector2.from_angle(i*TAU/6)*rng.randf_range(40,120),220,[FIRE,GOLD,Color(1,1,1)][i%3],0.35,1.0,"burst")
			b.delay = 0.12*i
		debris(q,24,"paper_a",Color(1,1,1,1),420,24)
		decal("scorch_a",p,420,Color(0.05,0.05,0.06,0.5),3.0)

func skill(event: Dictionary, p: Vector2) -> void:
	var r: float = event.get("radius",160.0)
	var from = Vector2(event.get("from_x",p.x),event.get("from_y",p.y))
	match event.skill:
		"pulse":
			var c = p+BODY*0.4
			var s = air.seal("bagua",c,1.0,r*0.6,r*2.1,Color(GOLD,0.72),true); s.spin = 0.8; s.size_ease = 0.18
			var g = ground.seal("bagua",p,1.6,r*1.6,r*2.0,Color(0.55,0.32,0.05,0.65),false); g.spin = 0.35
			shock(c,r,GOLD,0.5,true,0.16)
			var second = air.ring(c,r*0.7,0.1,0.45,Color(1,0.95,0.8),true); second.delay = 0.06
			var pillar = air.sprite("streak",c+Vector2(0,-120),0.5,1.0,Color(GOLD,0.85),true)
			pillar.rot = PI/2; pillar.size0 = Vector2(420,120); pillar.size1 = Vector2(520,10); pillar.hot = 0.7
			flare(c,200,Color(1,0.85,0.55,0.8),0.3,0.6,"burst")
			sparks(c,22,GOLD,Vector2(300,700),44,0.45)
			embers(p,16,GOLD,r*0.6,120,1.2)
			air.flash(c,r*1.6,0.9,GOLD,0.45)
			arena.shake = maxf(arena.shake,7.0)
		"poison":
			flights.append({"kind":"talisman","from":from,"to":p,"t":0.0,"dur":0.28,"height":70.0,"radius":r})
		"blast":
			flights.append({"kind":"pill","from":from,"to":p,"t":0.0,"dur":0.3,"height":95.0,"radius":r})
		"shadow":
			smoke_burst(p+BODY,10,Color(0.04,0.06,0.08,0.75),80,220,0.9)
			flare(p+BODY,180,JADE,0.3,0.6,"soft_star")
			air.ring(p+BODY,140,0.12,0.45,JADE,true)
			for i in range(n(3)):
				var t = air.sprite("talisman_b",p+BODY,0.5,40,Color(1,1,1,1),false)
				t.vel = Vector2.from_angle(-PI/2+(i-1)*0.9)*260; t.drag = 4; t.spin = rng.randf_range(-8,8); t.e1 = 1.0
		"binding":
			var s = air.seal("bind",p,1.3,r*2.6,r*2.0,Color(1.0,0.45,0.22,0.95),true); s.spin = -0.9; s.size_ease = 0.2
			var g = ground.seal("bind",p,2.0,r*2.0,r*2.05,Color(0.5,0.08,0.04,0.7),false); g.spin = -0.25
			air.arc(p,0,r*1.3,PI,0.12,5,0.45,Color(1.0,0.55,0.3),true)
			for k in range(8):
				var a = k*TAU/8+0.2
				for j in range(6):
					var at = p+Vector2.from_angle(a)*r*(1.25-j*0.17)
					var link = air.sprite("chain",at,0.9-j*0.04,26,Color(1.0,0.78,0.45),true)
					link.rot = a+(PI/2 if j%2 else 0.0); link.delay = 0.02*j; link.hot = 0.3
					link.size0 = Vector2(30,15); link.size1 = Vector2(26,13)
			smoke_burst(p,6,Color(0.35,0.28,0.2,0.4),70,60,0.8)
			flare(p,180,Color(1,0.7,0.4),0.25,1.0,"burst")
			air.flash(p,r*1.3,1.1,Color(1,0.5,0.25),0.4)
		"frost":
			var c = p+BODY*0.3
			air.ring(c,r,0.16,0.6,Color(FROST,0.7),true)
			air.ring(c,r*1.04,0.24,0.65,Color(0.1,0.2,0.3,0.5),false)
			var g = ground.seal("frost",p,1.8,r*1.2,r*2.0,Color(0.25,0.5,0.7,0.6),false); g.spin = 0.2
			var s = air.seal("frost",c,0.7,r*0.8,r*2.0,Color(FROST,0.7),true); s.spin = 0.4
			var count = n(22)
			for i in range(count):
				var a = i*TAU/count+rng.randf_range(-0.1,0.1)
				var at = p+Vector2(cos(a),sin(a)*0.8)*r*rng.randf_range(0.82,1.0)
				var spike = air.sprite("ice_spike",at+Vector2(0,-24),0.9,1.0,Color(0.72,0.88,1.0,0.95),false)
				spike.rot = rng.randf_range(-0.35,0.35); spike.size0 = Vector2(20,8); spike.size1 = Vector2(38,92)
				spike.size_ease = 0.12; spike.delay = 0.12*(i%3)*0.3+0.08; spike.e0 = 0.0; spike.e1 = 0.95
			for i in range(n(20)):
				var flake = air.sprite("snowflake",c,rng.randf_range(0.5,0.9),rng.randf_range(8,16),Color(0.9,0.97,1.0),true)
				flake.vel = Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(r*0.8,r*1.8); flake.drag = 3; flake.spin = rng.randf_range(-5,5)
			smoke_burst(c,8,Color(0.8,0.92,1.0,0.3),90,r*1.2,0.9,0,null,true)
			flare(c,170,Color(0.8,0.92,1.0,0.75),0.25,0.5,"burst")
			decal("glow",p,r*2.2,Color(0.55,0.75,0.95,0.35),1.6)
			air.flash(c,r*1.4,0.9,FROST,0.4)

func ring_event(event: Dictionary, p: Vector2) -> void:
	var r: float = event.get("radius",120.0)
	match event.get("source",""):
		"blast_pill","ignite_furnace": explosion(p,r,event.get("source","")=="ignite_furnace")
		"school_blast": explosion(p,r*0.8,false)
		"echo_mark":
			shock(p+BODY*0.5,r,JADE,0.4)
			sparks(p+BODY*0.5,10,JADE,Vector2(200,420),30,0.3)
		"ignite_lamp": pass
		"enemy":
			shock(p,r,HOSTILE,0.5)
			smoke_burst(p,6,Color(0.2,0.05,0.04,0.5),70,r,0.7)
			decal("scorch_a",p,r*1.6,Color(0.08,0.05,0.05,0.4),1.4)
		"pulse","frost_ring","binding_hex": pass
		_:
			var color = Content.color_for(event.get("source","spirit")).lightened(0.3)
			shock(p,r,color,0.45)

func explosion(p: Vector2, r: float, alchemy: bool) -> void:
	fired["detonation"] = int(fired.get("detonation",0))+1
	var c = p+Vector2(0,-12)
	var hue = Color(0.6,1.0,0.35) if alchemy else FIRE
	flare(c,r*1.5,Color(1,0.85,0.6,0.85),0.2,0.7,"burst")
	# opaque fire body keeps its colour on light floors; additive tongues add the heat on top
	var body = Color(0.45,0.75,0.15,0.9) if alchemy else Color(0.92,0.36,0.08,0.92)
	for i in range(n(6)):
		var f = air.sprite(["fire_a","fire_b","smoke_c"][i%3],c+Vector2.from_angle(rng.randf()*TAU)*r*0.3,rng.randf_range(0.4,0.6),r*0.7,body,false)
		f.size1 = Vector2.ONE*r*1.5; f.size_ease = 0.3; f.e0 = 0.05; f.e1 = 0.95; f.c1 = Color(0.15,0.08,0.05,0.0)
	for i in range(n(6)):
		var f = air.sprite(["fire_a","fire_b","muzzle_a"][i%3],c+Vector2.from_angle(rng.randf()*TAU)*r*0.25,rng.randf_range(0.3,0.45),r*0.6,hue if i%2 else EMBER,true)
		f.size1 = Vector2.ONE*r*1.3; f.size_ease = 0.3; f.hot = 0.35; f.e1 = 0.9; f.rot = rng.randf()*TAU
	shock(c,r*1.15,EMBER,0.45,true,0.18)
	smoke_burst(c,10,Color(0.12,0.1,0.09,0.65),r*0.9,r*1.4,1.2,60)
	embers(c,18,EMBER,r*0.4,160,1.1)
	debris(c,5,"dirt_a",Color(0.2,0.15,0.12),300,18)
	decal("scorch_a",p,r*2.0,Color(0.06,0.05,0.04,0.6),2.4)
	if alchemy: decal("ink_spray",p,r*1.6,Color(0.18,0.3,0.1,0.5),2.0)
	air.flash(c,r*2.2,1.1,EMBER,0.35)
	arena.shake = maxf(arena.shake,5.0)

func reaction(event: Dictionary, p: Vector2) -> void:
	var text: String = event.get("text","")
	var q = p+BODY
	if text.contains("瘴"):
		smoke_burst(q,8,Color(0.35,0.5,0.15,0.5),70,140,0.9,30)
		var f = air.sprite("fire_b",q,0.45,80,Color(0.9,0.75,0.2),true); f.size1 = Vector2.ONE*150; f.e1 = 0.9; f.hot = 0.4
	elif text.contains("霜"):
		smoke_burst(q,8,Color(0.95,0.97,1.0,0.45),80,160,1.0,40,null,true)
		debris(q,6,"ice_shard",Color(1,1,1,0.95),260,20)
	elif text.contains("雷"):
		lightning(q+Vector2(rng.randf_range(-40,40),-420),q,Color(0.75,0.8,1.0),34.0,0.24)
		flare(q,200,Color(0.85,0.9,1.0),0.25,1.0,"burst")
	shock(q,event.get("radius",140.0),Content.color_for(event.get("source","spirit")).lightened(0.4),0.5)

func dash(event: Dictionary, p: Vector2) -> void:
	var dir = Vector2(event.get("dx",0),event.get("dy",0))
	if dir.length_squared() < 0.01: dir = Vector2.RIGHT
	dir = dir.normalized()
	smoke_burst(p,4,Color(0.5,0.45,0.38,0.35),40,60,0.6)
	for i in range(n(5)):
		var o = dir.orthogonal()*rng.randf_range(-24,24)
		var s = air.sprite("streak",p+BODY+o,0.28,1.0,Color(0.85,1.0,0.95,0.6),true)
		s.rot = dir.angle(); s.vel = -dir*rng.randf_range(60,180)
		s.size0 = Vector2(rng.randf_range(70,120),8); s.size1 = Vector2(10,2)

func perfect(p: Vector2) -> void:
	var c = p+BODY
	air.ring(c,150,0.1,0.55,JADE,true)
	var big = air.ring(c,420,0.04,0.8,Color(0.8,1.0,0.95,0.6),true); big.delay = 0.04
	air.ring(c,160,0.16,0.6,INK_SOFT,false)
	flare(c,220,Color(0.85,1,0.95),0.3,1.0,"burst")
	for i in range(n(8)):
		var s = air.sprite("star",c+Vector2.from_angle(i*TAU/8)*70,0.5,36,JADE,true)
		s.vel = Vector2.from_angle(i*TAU/8)*120; s.drag = 3; s.hot = 0.7
	if arena.world.character == "swordswoman": petals(c,10,-PI/2,PI,260)
	air.flash(c,300,1.0,JADE,0.4)

func ignite(event: Dictionary, p: Vector2) -> void:
	var r: float = event.get("radius",360.0)
	var c = p+BODY*0.5
	match event.get("character","keeper"):
		"swordswoman":
			flare(c,320,Color(0.9,1,0.95,0.85),0.35,0.6,"burst")
			petals(c,n(36),0,PI,520)
			air.ring(c,r*0.6,0.08,0.5,JADE,true)
			air.flash(c,600,1.2,JADE,0.5)
		"alchemist":
			var s = air.seal("sun",c,1.2,r*0.6,r*1.6,Color(0.75,1.0,0.45,0.65),true); s.spin = 1.2
			var g = ground.seal("sun",p,2.0,r*1.4,r*1.6,Color(0.2,0.35,0.05,0.6),false); g.spin = 0.3
			smoke_burst(c,12,Color(0.35,0.55,0.2,0.45),110,240,1.3,40,null,true)
			flare(c,300,Color(0.9,1,0.7,0.85),0.35,0.6,"burst")
			air.flash(c,600,1.1,Color(0.7,1.0,0.4),0.5)
		_:
			var s = air.seal("sun",c,1.3,r*0.5,r*2.1,Color(GOLD,0.7),true); s.spin = 0.9
			var g = ground.seal("sun",p,2.4,r*1.8,r*2.0,Color(0.55,0.25,0.02,0.6),false); g.spin = 0.2
			shock(c,r,EMBER,0.7,true,0.12)
			var count = n(30)
			for i in range(count):
				var a = i*TAU/count
				var f = air.sprite("flame_tongue",c+Vector2.from_angle(a)*40,0.75,rng.randf_range(40,70),EMBER if i%2 else FIRE,true)
				f.vel = Vector2.from_angle(a)*r*2.6; f.drag = 3.2; f.rot = 0; f.hot = 0.6
				f.size1 = Vector2(20,60)
			var rays = air.sprite("rays",c,0.9,r*0.8,Color(1,0.8,0.5,0.8),true); rays.size1 = Vector2.ONE*r*2.4; rays.spin = 0.5
			flare(c,360,Color(1,0.9,0.7,0.85),0.4,0.6,"burst")
			embers(c,40,EMBER,r*0.6,150,1.6)
			air.flash(c,700,1.3,GOLD,0.6)

func ignite_cut(a: Vector2, b: Vector2) -> void:
	var s = air.segment("streak",a+BODY,b+BODY,26,0.35,Color(0.9,1.0,0.96),true); s.hot = 1.0
	s.size1 = Vector2(s.size0.x,3)
	var ink = air.segment("brush",a+BODY,b+BODY,40,0.45,INK,false); ink.size1 = Vector2(ink.size0.x,10); ink.e1 = 0.9
	flare(b+BODY,180,Color(0.9,1,0.95),0.22,1.0,"burst")
	petals(b+BODY,4,(b-a).angle(),0.8,260)
	air.flash(b+BODY,220,1.0,JADE,0.2)

func enemy_swipe(event: Dictionary, p: Vector2) -> void:
	var angle: float = event.get("angle",0.0)
	var at = p+BODY*0.7+Vector2.from_angle(angle)*42
	var claw = air.sprite("claw",at,0.26,90,Color(1.0,0.35,0.2,0.9),true)
	claw.rot = angle+PI/4; claw.size0 = Vector2.ONE*60; claw.size1 = Vector2.ONE*100; claw.hot = 0.4
	var ink = air.sprite("claw",at,0.3,94,Color(0.12,0.02,0.02,0.6),false)
	ink.rot = angle+PI/4; ink.size0 = Vector2.ONE*66; ink.size1 = Vector2.ONE*104

# ---------- per frame ----------

func update(dt: float) -> void:
	hits_this_frame = 0
	age += dt
	var world = arena.world
	if world == null: return
	_flights(dt)
	_bolts(world,dt)
	_zones(world,dt)
	_auras(world,dt)
	_mobs(world,dt)
	ground.step(dt)
	air.step(dt)

func _flights(dt: float) -> void:
	var keep: Array = []
	for f in flights:
		f.t += dt
		var k = clampf(f.t/f.dur,0,1)
		var q: Vector2 = f.from.lerp(f.to,k)-Vector2(0,sin(k*PI)*f.height)
		if f.kind == "pill":
			air.once("glow",q,0,Vector2.ONE*70,Color(FIRE,0.8),true)
			air.once("pill",q,age*8.0,Vector2.ONE*30,Color.WHITE,false)
			if dt > 0:
				var e = air.sprite("fire_b",q,0.3,26,EMBER,true); e.size1 = Vector2.ONE*8; e.hot = 0.5
				var sm = air.smoke(q,0.6,26,Color(0.15,0.12,0.1,0.4)); sm.vel = Vector2(0,-20)
		else:
			air.once("glow",q,0,Vector2.ONE*60,Color(POISON,0.6),true)
			air.once("talisman",q,age*10.0,Vector2.ONE*44,Color.WHITE,false)
			if dt > 0:
				var e = air.sprite("glow",q,0.4,12,POISON,true); e.vel = Vector2(rng.randf_range(-20,20),30); e.hot = 0.6
		if k >= 1.0:
			if f.kind == "talisman":
				var r: float = f.radius
				smoke_burst(f.to,10,MIASMA,r*0.7,r*1.2,1.2,0)
				smoke_burst(f.to,5,Color(0.55,0.95,0.35,0.35),r*0.6,r,1.0,0,null,true)
				decal("glow",f.to,r*2.2,Color(0.25,0.4,0.08,0.4),1.6)
				air.ring(f.to,r,0.1,0.5,Color(0.6,1.0,0.35,0.8),true)
				flare(f.to+Vector2(0,-10),170,POISON,0.25,0.8,"burst")
				air.flash(f.to,r*1.4,1.0,POISON,0.35)
			continue
		keep.append(f)
	flights = keep

func _bolts(world, dt: float) -> void:
	var hostile_count = 0
	for bolt in world.bolts:
		var q: Vector2 = world.pos(bolt)
		var v = Vector2(bolt.vx,bolt.vy)
		var a = v.angle()
		if bolt.hostile:
			hostile_count += 1
			# CombatBatch always draws every hostile core and danger trail.
			# Bound only the extra glow/debris work in dense projectile fields.
			if hostile_count <= 128:
				air.once("glow",q,0,Vector2.ONE*40,Color(1.0,0.3,0.15,0.55),true)
				if hostile_count <= 64:
					air.once("streak",q-v.normalized()*14,a,Vector2(52,14),Color(1.0,0.4,0.2,0.6),true,0.4)
					air.once("glow",q,0,Vector2.ONE*14,Color(0.25,0.03,0.02,0.9),false)
			continue
		var dir = v.normalized()
		var spawn = dt > 0 and not lite()
		match bolt.source:
			"fire_talisman":
				air.once("glow",q,0,Vector2.ONE*64,Color(FIRE,0.7),true)
				air.once("talisman",q,a+PI/2+sin(age*30+bolt.x)*0.25,Vector2.ONE*40,Color.WHITE,false)
				air.once("flare",q,age*6,Vector2.ONE*34,Color(1,0.8,0.5,0.9),true,0.6)
				if spawn:
					var e = air.sprite("fire_b",q-dir*10,0.22,22,EMBER,true); e.size1 = Vector2.ONE*6; e.hot = 0.6
					e.vel = -dir*60+Vector2(rng.randf_range(-30,30),rng.randf_range(-40,0))
					if rng.randf() < 0.35:
						var s = air.smoke(q,0.5,22,Color(0.1,0.08,0.07,0.35)); s.vel = Vector2(0,-25)
			"piercing_spike":
				air.once_arc(q-dir*50,a,70,1.0,0.3,1,0.38,INK,false)
				air.once_arc(q-dir*50,a,66,1.0,0.22,0,0.38,Color(JADE,0.95),true)
				air.once("glow",q,0,Vector2.ONE*90,Color(JADE,0.35),true)
				if spawn and rng.randf() < 0.5: petals(q,1,a+PI,0.6,120)
			"poison_mist":
				air.once("streak",q-dir*16,a,Vector2(64,10),Color(POISON,0.9),true,0.7)
				air.once("glow",q,0,Vector2.ONE*30,Color(POISON,0.6),true)
				if spawn and rng.randf() < 0.6:
					var d = air.sprite("glow",q,0.35,7,POISON,true); d.vel = Vector2(rng.randf_range(-20,20),40); d.hot = 0.7
			"thunder_mark":
				air.once("glow",q,0,Vector2.ONE*80,Color(0.65,0.7,1.0,0.6),true)
				air.once("twirl_a",q,age*16.0,Vector2.ONE*58,Color(1.0,0.9,0.55,0.95),true,0.5)
				air.once("twirl_b",q,-age*12.0,Vector2.ONE*50,Color(0.7,0.75,1.0,0.9),true,0.4)
				air.once("flare",q,0,Vector2.ONE*30,Color.WHITE,true,1.0)
				if int(age*30+bolt.x)%3 == 0: air.once(["crackle_a","crackle_b","crackle_c"][int(age*50)%3],q,rng.randf()*TAU,Vector2.ONE*72,Color(0.8,0.85,1.0,0.9),true)
			"frost_sand":
				air.once("glow",q,0,Vector2.ONE*46,Color(FROST,0.6),true)
				air.once("ice_shard",q,a,Vector2(40,22),Color.WHITE,false)
				if spawn:
					var s = air.sprite("snowflake",q,0.4,8,Color(0.9,0.97,1.0),true); s.vel = -dir*40+Vector2(rng.randf_range(-30,30),rng.randf_range(-30,30)); s.spin = 5
			"shadow_twin":
				air.once("glow",q,0,Vector2.ONE*44,Color(JADE,0.45),true)
				air.once("streak",q-dir*14,a,Vector2(56,12),Color(0.04,0.06,0.08,0.85),false)
				air.once("thin_streak",q-dir*10,a,Vector2(50,6),Color(JADE,0.9),true,0.5)
			_:
				var color = Content.color_for(bolt.source).lightened(0.3)
				air.once("glow",q,0,Vector2.ONE*46,Color(color,0.6),true)
				air.once("streak",q-dir*12,a,Vector2(50,10),color,true,0.6)

func _zones(world, dt: float) -> void:
	for zone in world.zones:
		var q: Vector2 = world.pos(zone)
		var r: float = zone.radius
		if zone.hostile:
			if zone.warning > 0:
				var k = 1.0-zone.warning/maxf(0.01,zone.warning_max)
				air.once_arc(q,age*0.6,r,PI,0.05,4,age*0.1,Color(1.0,0.35,0.2,0.35+0.4*k),true)
			continue
		if zone.warning > 0:
			var k = 1.0-zone.warning/maxf(0.01,zone.warning_max)
			air.once_arc(q,age,r,PI,0.035,4,age*0.2,Color(1.0,0.75,0.35,0.12+0.3*k),true)
			air.once("glow",q,0,Vector2.ONE*r*1.6*k,Color(1.0,0.6,0.25,0.18*k),true)
			continue
		if zone.source == "poison_mist":
			ground.once_arc(q,age*0.4,r,PI,0.05,4,age*0.15,Color(0.3,0.55,0.12,0.6),false)
			ground.once("glow",q,0,Vector2(r*2.3,r*1.7),Color(0.28,0.42,0.08,0.4),false)
			air.once("glow",q,0,Vector2(r*2.2,r*1.4),Color(0.45,0.85,0.25,0.1),true)
			if dt > 0:
				var count = int(dt*(5 if lite() else 14)+rng.randf())
				for i in range(count):
					var at = q+Vector2.from_angle(rng.randf()*TAU)*Vector2(r,r*0.7)*sqrt(rng.randf())*0.85
					var s = air.smoke(at,rng.randf_range(1.2,2.0),r*rng.randf_range(0.5,0.8),MIASMA)
					s.e0 = 0.0; s.e1 = 0.25; s.fade_in = 0.3
					s.vel = Vector2(rng.randf_range(-15,15),-rng.randf_range(8,25)); s.spin = rng.randf_range(-0.6,0.6)
					if rng.randf() < 0.5:
						var b = air.sprite("bubble",at,0.7,1.0,Color(0.7,1.0,0.45,0.7),true)
						b.size0 = Vector2.ONE*4; b.size1 = Vector2.ONE*rng.randf_range(12,20); b.vel = Vector2(0,-30)

func _auras(world, dt: float) -> void:
	var chapter = world as ChapterWorld
	if chapter == null: return
	var p: Vector2 = chapter.pos(chapter.player)
	var c = p+BODY*0.6
	if chapter.ignite_time > 0:
		match chapter.character:
			"swordswoman":
				air.once("glow",c,0,Vector2(220,170),Color(JADE,0.22),true)
				if dt > 0 and rng.randf() < dt*14:
					var a = rng.randf()*TAU
					var s = air.sprite("petal",c+Vector2.from_angle(a)*90,0.7,14,Color.WHITE,false)
					s.vel = Vector2.from_angle(a+PI/2)*220; s.drag = 1.5; s.spin = 6; s.acc = (c-s.pos)*2.0
			"alchemist":
				air.once("glow",c,0,Vector2(230,170),Color(0.6,1.0,0.35,0.2),true)
				if dt > 0 and rng.randf() < dt*10:
					var s = air.smoke(c+Vector2(rng.randf_range(-60,60),10),1.0,46,Color(0.4,0.7,0.2,0.3),true); s.vel = Vector2(0,-60)
			_:
				ground.once_seal("sun",p,age*0.5,250,Color(0.6,0.3,0.05,0.4),false)
				air.once("glow",c,0,Vector2(300,220),Color(1.0,0.65,0.3,0.25),true)
				if dt > 0:
					for i in range(int(dt*(8 if lite() else 26)+rng.randf())):
						var a = rng.randf()*TAU
						var f = air.sprite("flame_lick",p+Vector2(cos(a)*120,sin(a)*70)+Vector2(0,-10),0.5,rng.randf_range(22,38),EMBER if rng.randf()<0.5 else FIRE,true)
						f.rot = 0; f.vel = Vector2(0,-70); f.hot = 0.5; f.size1 = Vector2(8,30)
	if chapter.shield > 0:
		air.once_arc(c,age*1.5,44,PI,0.09,4,age*0.3,Color(0.55,0.8,1.0,0.5),true)
	if chapter.perfect_time > 0:
		air.once("soft_star",c,age*3,Vector2.ONE*(70+10*sin(age*20)),Color(JADE,0.6),true,0.4)
	if chapter.flame >= ChapterWorld.FLAME_MAX and dt > 0 and rng.randf() < dt*6:
		embers(p+Vector2(0,-20),1,GOLD,20,90,0.9)
	if chapter.player.get("dash_time",0) > 0 and dt > 0 and not lite():
		var s = air.smoke(p,0.5,30,Color(0.55,0.5,0.42,0.25)); s.vel = Vector2(0,-15)
	if chapter.shadow_time > 0 and dt > 0 and rng.randf() < dt*12:
		var count = (3 if chapter.skill_mod==0 else 2)+(1 if "fox_mirror" in chapter.relics else 0)
		var i = rng.randi_range(0,count-1)
		var at = p+chapter.aim.orthogonal()*(i-(count-1)*0.5)*70-chapter.aim*35+Vector2(0,-40)
		var s = air.smoke(at,0.8,40,Color(0.03,0.05,0.07,0.5)); s.vel = Vector2(0,-50)
		air.once("glow",at,0,Vector2(80,100),Color(JADE,0.18),true)

func _mobs(world, dt: float) -> void:
	if dt <= 0: return
	var live: Dictionary = {}
	var budget = 40
	for mob in world.mobs:
		if mob.hp <= 0 or mob.get("pillar",false): continue
		live[mob.uid] = true
		var q: Vector2 = world.pos(mob)
		if not seen_mobs.has(mob.uid):
			seen_mobs[mob.uid] = true
			if mob.get("spawn_age",1.0) < 0.3:
				smoke_burst(q,4,Color(0.06,0.08,0.1,0.55),50,80,0.7)
				air.ring(q+Vector2(0,-30),60,0.1,0.4,HOSTILE,true)
		if budget <= 0: continue
		var top = q+Vector2(0,-40*(2.0 if mob.boss else 1.0))
		if mob.get("burn",0) > 0 and rng.randf() < dt*5:
			budget -= 1
			var f = air.sprite("flame_lick",top+Vector2(rng.randf_range(-16,16),rng.randf_range(-10,16)),0.45,rng.randf_range(18,30),FIRE,true)
			f.rot = 0; f.vel = Vector2(0,-60); f.size1 = Vector2(6,24); f.hot = 0.5
		if mob.get("poison",0) > 0 and rng.randf() < dt*3:
			budget -= 1
			var b = air.sprite("bubble",top+Vector2(rng.randf_range(-16,16),rng.randf_range(-6,16)),0.6,1.0,Color(0.6,1.0,0.35,0.8),true)
			b.size0 = Vector2.ONE*4; b.size1 = Vector2.ONE*14; b.vel = Vector2(0,-30)
		if mob.get("slow",0) > 0 and rng.randf() < dt*2.5:
			budget -= 1
			var s = air.sprite("snowflake",top+Vector2(rng.randf_range(-20,20),rng.randf_range(-10,20)),0.7,9,Color(0.85,0.95,1.0,0.9),true)
			s.vel = Vector2(0,24); s.spin = 3
		if mob.get("stun",0) > 0.25 and not mob.boss and rng.randf() < dt*3:
			budget -= 1
			var a = rng.randf()*TAU
			var s = air.sprite("star",top+Vector2(cos(a)*18,-18+sin(a)*6),0.4,16,THUNDER,true); s.vel = Vector2(-sin(a),cos(a)*0.3)*60
	for id in seen_mobs.keys():
		if not live.has(id): seen_mobs.erase(id)

func add_lights(callback: Callable) -> void:
	for layer in [air]:
		for f in layer.flashes:
			var k = f.life/f.max
			callback.call(f.pos,f.radius,f.intensity*k,f.color)
