class_name PrintButton
extends Button

# Brush-stroke buttons. primary: solid vermilion brush; secondary: lacquer plate,
# a brush stroke sweeps in on hover/focus; menu: bare text with sweep + lamp marker.
var primary = false
var style = "secondary"
var face: Node2D
var glow = 0.0
var press = 0.0

func _ready() -> void:
	face = Node2D.new()
	face.show_behind_parent = true
	add_child(face)
	face.draw.connect(draw_face)
	for sig in [mouse_entered,mouse_exited,focus_entered,focus_exited,button_down,button_up]:
		sig.connect(_wake)
	resized.connect(face.queue_redraw)
	pivot_offset = size*0.5
	glow = _target()
	set_process(false)

func _wake() -> void:
	set_process(true)

func _target() -> float:
	return 1.0 if not disabled and (is_hovered() or has_focus()) else 0.0

func _process(dt: float) -> void:
	var target = _target()
	var speed = 9.0 if UI.motion() else 60.0
	glow = move_toward(glow,target,dt*speed*(1.0 if target>glow else 0.7))
	press = move_toward(press,1.0 if button_pressed or (is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)) else 0.0,dt*20)
	face.queue_redraw()
	if glow==target and press==0.0: set_process(false)

func _notification(what: int) -> void:
	if what==NOTIFICATION_RESIZED: pivot_offset = size*0.5
	if what==NOTIFICATION_DRAW and face: face.queue_redraw()

func _chamfer(w: float, h: float, c: float) -> PackedVector2Array:
	return PackedVector2Array([Vector2(c,0),Vector2(w-c,0),Vector2(w,c),Vector2(w,h-c),Vector2(w-c,h),Vector2(c,h),Vector2(0,h-c),Vector2(0,c)])

func draw_face() -> void:
	var w = size.x
	var h = size.y
	var t = ease(glow,-1.8)
	var active = not disabled and (is_hovered() or has_focus())
	var brush = UI.brush()
	match style:
		"primary":
			var fill = Color("3b3f3e") if disabled else UI.GOLD.darkened(0.12).lerp(UI.GOLD.lightened(0.08),t)
			if t>0.01:
				face.draw_texture_rect(UI.glow(),Rect2(-w*0.18,-h*0.9,w*1.36,h*2.8),false,Color(UI.AMBER,0.22*t))
			face.draw_texture_rect(brush,Rect2(-10,-h*0.12,w+20,h*1.24),false,fill)
			face.draw_texture_rect(brush,Rect2(-4,h*0.06,w+8,h*0.9),false,Color(fill.lightened(0.05),0.9))
			face.draw_line(Vector2(16,h*0.2),Vector2(w*0.72,h*0.17),Color(1,0.9,0.7,0.16+0.12*t),1.5,true)
			if active: _marker(Vector2(w-22,h*0.5),UI.BRIGHT,1.0)
		"menu":
			if t>0.01:
				face.draw_texture_rect_region(brush,Rect2(14,h*0.08,(w-14)*t,h*0.84),Rect2(0,0,brush.get_width()*t,brush.get_height()),Color(UI.GOLD,0.78))
			var marker_color = UI.AMBER if active else Color(UI.BRASS,0.45)
			_marker(Vector2(24,h*0.5),marker_color,0.55+0.45*t)
		"tab":
			face.draw_colored_polygon(_chamfer(w,h,8),Color(UI.LACQUER_HI,0.7) if not primary else Color(UI.GOLD,0.88))
			if t>0.01 and not primary:
				face.draw_texture_rect_region(brush,Rect2(0,h*0.1,w*t,h*0.8),Rect2(0,0,brush.get_width()*t,brush.get_height()),Color(UI.GOLD,0.5))
			var outline = _chamfer(w,h,8); outline.append(outline[0])
			face.draw_polyline(outline,Color(UI.AMBER if active else UI.BRASS,0.75 if active else 0.35),1.5 if active else 1.0,true)
		_:
			var base = Color(UI.LACQUER_HI,0.82) if not disabled else Color(UI.LACQUER,0.55)
			face.draw_colored_polygon(_chamfer(w,h,9),base)
			if t>0.01:
				face.draw_texture_rect_region(brush,Rect2(2,h*0.08,(w-4)*t,h*0.84),Rect2(0,0,brush.get_width()*t,brush.get_height()),Color(UI.GOLD,0.62))
			var outline = _chamfer(w,h,9); outline.append(outline[0])
			face.draw_polyline(outline,Color(UI.AMBER,0.9) if active else Color(UI.BRASS,0.32 if not disabled else 0.15),1.5 if active else 1.0,true)
			# Brass corner pins keep the plate reading as a lacquered object.
			for p in [Vector2(9,9),Vector2(w-9,9),Vector2(9,h-9),Vector2(w-9,h-9)]:
				face.draw_circle(p,1.6,Color(UI.BRASS,0.55 if not disabled else 0.2))
			if active: _marker(Vector2(w-20,h*0.5),UI.BRIGHT,0.9)
	if press>0.01: face.draw_colored_polygon(_chamfer(w,h,9),Color(0,0,0,0.18*press))

func _marker(p: Vector2, color: Color, scale_value: float) -> void:
	var s = 6.0*scale_value
	face.draw_colored_polygon(PackedVector2Array([p+Vector2(0,-s),p+Vector2(s,0),p+Vector2(0,s),p+Vector2(-s,0)]),color)
