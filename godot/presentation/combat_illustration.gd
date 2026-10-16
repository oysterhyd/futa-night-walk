class_name CombatIllustration
extends RefCounted

const INK=Color("183544")
const PAPER=Color("f8efd5")
const RED=Color("ad3527")

static func bell(canvas: Node2D, p: Vector2, size: float, alpha: float) -> void:
	var outline=PackedVector2Array([Vector2(-0.62,0.45),Vector2(-0.45,0.2),Vector2(-0.4,-0.45),Vector2(-0.22,-0.7),Vector2(0.22,-0.7),Vector2(0.4,-0.45),Vector2(0.45,0.2),Vector2(0.62,0.45)])
	for i in range(outline.size()): outline[i]=p+outline[i]*size
	canvas.draw_colored_polygon(outline,Color(INK,alpha))
	canvas.draw_polyline(outline,Color(PAPER,alpha),2.0)
	canvas.draw_line(p+Vector2(-0.48,0.30)*size,p+Vector2(0.48,0.30)*size,Color(RED,alpha),3)
	canvas.draw_arc(p+Vector2(0,-0.72)*size,size*0.16,-PI,0,12,Color(INK,alpha),3)
	for i in range(3): canvas.draw_line(p+Vector2(-0.22,-0.35+i*0.17)*size,p+Vector2(0.22,-0.35+i*0.17)*size,Color(PAPER,alpha),2)

static func paper_seal(canvas: Node2D, p: Vector2, angle: float, size: float, alpha: float) -> void:
	if canvas.has_meta("combat_art"):
		canvas.get_meta("combat_art").art("paper",p,angle,Vector2(size*0.34,size*0.65),Color(INK,alpha))
		return
	canvas.draw_set_transform(p,angle)
	canvas.draw_rect(Rect2(-size*0.34,-size*0.65,size*0.68,size*1.3),Color(INK,alpha))
	canvas.draw_rect(Rect2(-size*0.27,-size*0.58,size*0.54,size*1.16),Color(PAPER,alpha))
	for i in range(3):
		canvas.draw_line(Vector2(-size*0.17,(i-1)*size*0.24),Vector2(size*0.17,(i-1)*size*0.24),Color(RED,alpha),2)
	canvas.draw_line(Vector2(0,-size*0.43),Vector2(0,size*0.43),Color(RED,alpha),2)
	canvas.draw_set_transform(Vector2.ZERO)

static func warning(canvas: Node2D, zone: Dictionary, stage: int) -> void:
	var p=Vector2(zone.x,zone.y)
	var progress=clampf(1-zone.warning/maxf(0.01,zone.warning_max),0,1)
	var radius=zone.radius
	var opacity=0.38+progress*0.5
	match stage:
		2:
			if canvas.has_meta("combat_art"):
				canvas.get_meta("combat_art").art("water",p,0,Vector2(radius*0.65,radius*0.4),Color(progress,0,0,opacity))
				return
			for i in range(3):
				var wave=PackedVector2Array()
				for x in range(17): wave.append(p+Vector2((x-8)*radius*0.075,(i-1)*radius*0.25+sin(x*0.65+progress*TAU)*7))
				canvas.draw_polyline(wave,Color(INK,opacity),2)
		3: bell(canvas,p-Vector2(0,24+(1-progress)*70),45+progress*12,opacity)
		4:
			for i in range(4): paper_seal(canvas,p+Vector2.from_angle(i*PI/2+PI/4)*radius*0.58,i*PI/2+progress*0.2,25,opacity)

static func eruption(canvas: Node2D, p: Vector2, radius: float, stage: int, t: float) -> void:
	var alpha=1-t
	if stage==2:
		for i in range(8):
			var angle=i*TAU/8
			var center=p+Vector2.from_angle(angle)*radius*(0.3+t*0.55)
			if canvas.has_meta("combat_art"):
				canvas.get_meta("combat_art").art("crest",center,angle,Vector2.ONE*radius*0.24,Color(INK,alpha))
			else:
				canvas.draw_arc(center,radius*0.22,angle-PI,angle+PI*0.55,22,Color(INK,alpha),5)
				canvas.draw_arc(center,radius*0.18,angle-PI,angle+PI*0.4,20,Color(PAPER,alpha),2)
			shard(canvas,center-Vector2(0,35*sin(t*PI)),angle,18*alpha,5,Color(RED,alpha))
	elif stage==3:
		if t<0.45: bell(canvas,p-Vector2(0,25),70,1-t/0.45)
		for i in range(10):
			var direction=Vector2.from_angle(i*2.399)
			var points=PackedVector2Array([p+direction*radius*0.15,p+direction*radius*0.55+direction.orthogonal()*12,p+direction*radius*(0.65+t*0.3)])
			canvas.draw_polyline(points,Color(INK,alpha),3)
			shard(canvas,points[1]-Vector2(0,sin(t*PI)*35),i*2.399,16*alpha,6,Color(RED,alpha))
		canvas.draw_arc(p,radius*(0.2+t*0.8),0,TAU,48,Color(PAPER,alpha),5)
	else:
		var count=10 if stage==4 else 14
		for i in range(count):
			var angle=i*TAU/count
			var tip=p+Vector2.from_angle(angle)*radius*(0.25+t*0.75)
			if stage==4: paper_seal(canvas,tip,angle+t*1.2,27*(1-t*0.5),alpha)
			else:
				shard(canvas,tip,angle,40*alpha,13,Color(RED,alpha))
				shard(canvas,tip,angle,26*alpha,5,Color(PAPER,alpha))
		canvas.draw_arc(p,radius*(0.2+t*0.8),0,TAU,56,Color(INK,alpha),4)

static func shard(canvas: Node2D, p: Vector2, angle: float, length: float, width: float, color: Color) -> void:
	if length<0.6 or width<0.2 or color.a<0.03: return
	if canvas.has_meta("combat_art"):
		canvas.get_meta("combat_art").art("shard",p,angle,Vector2(length,width),color)
		return
	var forward=Vector2.from_angle(angle)
	var side=forward.orthogonal()
	canvas.draw_colored_polygon(PackedVector2Array([p+forward*length,p+side*width,p-forward*length*0.35,p-side*width*0.6]),color)

static func draw(canvas: Node2D, effect: Dictionary) -> void:
	var p=Vector2(effect.x,effect.y)
	var t=clampf(1-effect.life/effect.max_life,0,1)
	var ink=Color(INK,1-t)
	var paper=Color(PAPER,1-t)
	var color=Color(effect.color,1-t)
	match effect.kind:
		"slash":
			var heavy=effect.heavy
			var radius=effect.radius*(0.75+t*0.25)
			var angle=effect.angle
			if heavy:
				var center=p+Vector2.from_angle(angle)*radius*0.4
				for ring in range(3):
					for i in range(8):
						var a=i*TAU/8+ring*0.12
						canvas.draw_arc(center,radius*(0.3+t*0.7)*(1-ring*0.16),a,a+0.56,8,ink,6-ring*1.5)
				for i in range(11): shard(canvas,center+Vector2.from_angle(i*2.399)*radius*t,i*2.399,12*(1-t),4,color)
			else:
				var start=angle-1.45+t*0.7
				var outer=PackedVector2Array()
				for i in range(25): outer.append(p+Vector2.from_angle(start+i*0.10)*radius)
				for i in range(24,-1,-1): outer.append(p+Vector2.from_angle(start+i*0.10)*(radius-10-sin(i*PI/24)*13))
				canvas.draw_colored_polygon(outer,ink)
				canvas.draw_arc(p,radius-5,start,start+2.35,36,paper,3)
				for i in range(5): shard(canvas,p+Vector2.from_angle(start+i*0.48)*radius,start+i*0.48,14,2,color)
		"attack_art":
			var direction=Vector2.from_angle(effect.angle)
			var side=direction.orthogonal()
			var center=p+direction*(30+t*35)-Vector2(0,25)
			match effect.gear:
				"seal":
					for i in range(3):
						var point=center+side*(i-1)*12+direction*i*8
						shard(canvas,point,effect.angle,16*(1-t),7,color)
						canvas.draw_line(point-direction*6,point+direction*7,paper,2)
				"needle":
					for i in range(3): canvas.draw_line(center+side*(i-1)*8-direction*10,center+side*(i-1)*8+direction*(30-t*20),ink,2)
				"wheel":
					canvas.draw_arc(center,23+t*15,0,TAU,36,color,3)
					for i in range(6): shard(canvas,center+Vector2.from_angle(i*TAU/6+t*4)*23,i*TAU/6+t*4,10,3,color)
				"sand":
					for i in range(7):
						var a=effect.angle+(i-3)*0.10
						shard(canvas,p-Vector2(0,20)+Vector2.from_angle(a)*(30+t*65),a,10*(1-t),3,color)
		"impact":
			var reach=effect.get("radius",28.0)
			for i in range(5 if not effect.get("critical",false) else 9):
				var a=i*2.399+effect.x
				var point=p+Vector2.from_angle(a)*reach*t
				shard(canvas,point,a,10*(1-t),3,ink)
				canvas.draw_line(point,point+Vector2.from_angle(a)*8,paper,1.5)
		"enemy_attack":
			var angle=effect.get("angle",0.0)
			for i in range(5):
				var a=angle+(i-2)*0.18
				shard(canvas,p+Vector2.from_angle(a)*(15+t*45),a,16*(1-t),4,Color(RED,1-t))
			canvas.draw_arc(p,20+t*28,angle-0.7,angle+0.7,18,paper,2)
		"enemy_blast":
			eruption(canvas,p,effect.radius,effect.get("stage",1),t)
		"detonation":
			eruption(canvas,p,effect.radius,1,t)
		"boss_art":
			if effect.stage==2:
				for i in range(7):
					var angle=effect.angle+PI+(i-3)*0.28
					var tip=p+Vector2.from_angle(angle)*(60+t*85)
					var tail=PackedVector2Array([p,tip+Vector2.from_angle(angle+PI/2)*12,tip+Vector2.from_angle(angle)*25,tip-Vector2.from_angle(angle+PI/2)*8])
					canvas.draw_colored_polygon(tail,ink)
					canvas.draw_line(p,tip,paper,3)
			elif effect.stage==3:
				bell(canvas,p-Vector2(0,75),85,1-t)
				for i in range(3): canvas.draw_arc(p,45+i*20+t*80,0,TAU,40,ink,3-i*0.5)
			else:
				for i in range(6): paper_seal(canvas,p+Vector2.from_angle(i*TAU/6+t*1.5)*(65+t*40),i*TAU/6+t,32,1-t)
		"skill":
			var radius=effect.get("radius",150.0)*(0.3+t*0.7)
			var kind=effect.skill
			if kind=="binding":
				for i in range(4):
					var a=i*PI/2+PI/4
					var v=Vector2.from_angle(a)*radius
					canvas.draw_line(p+v,p+v.rotated(PI/2),ink,4)
					shard(canvas,p+v,a,20,7,color)
			elif kind=="frost":
				for i in range(12):
					var a=i*TAU/12
					shard(canvas,p+Vector2.from_angle(a)*radius,a,28*(1-t),8,color)
					canvas.draw_line(p+Vector2.from_angle(a)*radius*0.3,p+Vector2.from_angle(a)*radius,paper,2)
			elif kind=="blast":
				if t<0.4667:
					var travel=t/0.4667
					var origin=Vector2(effect.get("from_x",p.x),effect.get("from_y",p.y))
					var point=origin.lerp(p,travel)-Vector2(0,sin(travel*PI)*80)
					canvas.draw_circle(point,11,INK)
					canvas.draw_circle(point,8,RED)
					canvas.draw_line(point-Vector2(4,0),point+Vector2(4,0),PAPER,2)
					canvas.draw_line(point-Vector2(0,4),point+Vector2(0,4),PAPER,2)
					return
				for i in range(14):
					var a=i*TAU/14
					shard(canvas,p+Vector2.from_angle(a)*radius*0.7,a,35*(1-t),12,color)
				canvas.draw_arc(p,radius,0,TAU,48,ink,3)
			elif kind=="poison":
				for i in range(7):
					var center=p+Vector2.from_angle(i*2.399)*radius*0.55
					canvas.draw_arc(center,radius*0.32,i,i+PI*1.6,20,color,3)
			elif kind=="pulse":
				canvas.draw_set_transform(p,t*0.15,Vector2.ONE)
				canvas.draw_rect(Rect2(Vector2.ONE*-radius*0.6,Vector2.ONE*radius*1.2),color,false,5)
				for i in range(4): canvas.draw_line(Vector2(-radius*0.35,(i-1.5)*radius*0.22),Vector2(radius*0.35,(i-1.5)*radius*0.22),paper,3)
				canvas.draw_set_transform(Vector2.ZERO)
			else:
				for i in range(8): shard(canvas,p+Vector2.from_angle(i*TAU/8)*radius,i*TAU/8,16,5,color)
