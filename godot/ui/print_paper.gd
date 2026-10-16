class_name PrintPaper
extends Panel

# Lacquer plate: chamfered dark panel, brass hairlines, cloud-corner brackets.
# edge_color doubles as accent: a non-default colour draws an accent band on top;
# UI.GOLD marks a selected/highlighted panel with a warm glow.
var edge_color = Color("ece2c8")
var talisman = false
var paper_color = Color("13222a")
var glow_strength = 0.0

func _chamfer(w: float, h: float, c: float, inset: float = 0.0) -> PackedVector2Array:
	var i = inset
	return PackedVector2Array([Vector2(c+i,i),Vector2(w-c-i,i),Vector2(w-i,c+i),Vector2(w-i,h-c-i),Vector2(w-c-i,h-i),Vector2(c+i,h-i),Vector2(i,h-c-i),Vector2(i,c+i)])

func _draw() -> void:
	var w = size.x
	var h = size.y
	var accent = edge_color != UI.TEXT and edge_color != Color("183544")
	var selected = edge_color == UI.GOLD
	var c = 12.0 if w>120 and h>60 else 6.0
	if selected or glow_strength>0:
		draw_texture_rect(UI.glow(),Rect2(-60,-60,w+120,h+120),false,Color(UI.AMBER,0.16+glow_strength*0.2))
	# drop shadow
	var shadow = _chamfer(w,h,c)
	for i in range(shadow.size()): shadow[i] += Vector2(0,5)
	draw_colored_polygon(shadow,Color(0,0,0,0.28))
	draw_colored_polygon(_chamfer(w,h,c),paper_color)
	# subtle top-light and paper grain
	draw_rect(Rect2(c,1,w-c*2,minf(h*0.4,90)),Color(1,1,1,0.018))
	draw_texture_rect(UI.grain(),Rect2(4,4,w-8,h-8),true,Color(1,0.95,0.85,0.06))
	var outer = _chamfer(w,h,c); outer.append(outer[0])
	var line = UI.AMBER if selected else (Color(edge_color,0.7) if accent else Color(UI.BRASS,0.5))
	draw_polyline(outer,line,2.0 if selected else 1.2,true)
	if w>90 and h>50:
		var inner = _chamfer(w,h,c,6); inner.append(inner[0])
		draw_polyline(inner,Color(UI.BRASS,0.14),1.0,true)
		# cloud-corner brackets
		var b = 16.0
		for corner in [[Vector2(10,10),Vector2(1,1)],[Vector2(w-10,10),Vector2(-1,1)],[Vector2(10,h-10),Vector2(1,-1)],[Vector2(w-10,h-10),Vector2(-1,-1)]]:
			var p: Vector2 = corner[0]; var d: Vector2 = corner[1]
			draw_line(p+Vector2(0,d.y*4),p+Vector2(0,d.y*b),Color(UI.BRASS,0.6),1.5,true)
			draw_line(p+Vector2(d.x*4,0),p+Vector2(d.x*b,0),Color(UI.BRASS,0.6),1.5,true)
			draw_circle(p+d*3,1.8,Color(UI.BRASS,0.7))
	if accent and not selected and h>40:
		draw_rect(Rect2(c+4,0,w-c*2-8,3),Color(edge_color,0.95))
	if talisman and h>200:
		# Hanging cord + bottom notch reads as a talisman slip.
		draw_line(Vector2(w*0.5,-14),Vector2(w*0.5,0),Color(UI.BRASS,0.6),1.5,true)
		draw_circle(Vector2(w*0.5,-15),3,Color(UI.BRASS,0.8))
		draw_colored_polygon(PackedVector2Array([Vector2(w*0.5-10,h),Vector2(w*0.5,h-9),Vector2(w*0.5+10,h)]),Color(UI.NIGHT,0.9))
