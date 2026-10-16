class_name PrintPaper
extends Panel

var edge_color = Color("183544")
var talisman = false
var paper_color = Color("e8dfc5")

func _draw() -> void:
	var w = size.x
	var h = size.y
	var points = PackedVector2Array([Vector2(15,3),Vector2(w*0.55,4),Vector2(w*0.56,2),Vector2(w-17,3),Vector2(w-4,16),Vector2(w-6,h*0.47),Vector2(w-3,h*0.48),Vector2(w-5,h-16),Vector2(w-17,h-5),Vector2(w*0.64,h-3),Vector2(w*0.62,h-6),Vector2(15,h-4),Vector2(4,h-17),Vector2(6,16)])
	if talisman:
		points = PackedVector2Array([Vector2(16,3),Vector2(w-16,3),Vector2(w-5,16),Vector2(w-6,h-16),Vector2(w-16,h-4),Vector2(w*0.5+16,h-4),Vector2(w*0.5,h-21),Vector2(w*0.5-16,h-4),Vector2(16,h-4),Vector2(5,h-16),Vector2(6,16)])
	draw_colored_polygon(points,paper_color)
	points.append(points[0])
	draw_polyline(points,Color(edge_color,0.7),1.5,false)
	if talisman:
		draw_line(Vector2(18,18),Vector2(w-18,18),edge_color,2,false)
		draw_line(Vector2(18,22),Vector2(w-18,22),Color(edge_color,0.45),1,false)
		for side in [18,w-18]: draw_line(Vector2(side,18),Vector2(side,45),edge_color,2,false)
		# Two cord holes make a tall choice card read as a hanging paper talisman.
		for side in [28,w-28]:
			draw_circle(Vector2(side,12),2,edge_color)
			draw_line(Vector2(side,2),Vector2(side,12),edge_color,1,false)
	elif w>500 and h>100:
		# Thread-bound pages instead of generic rectangular cards.
		draw_line(Vector2(12,25),Vector2(12,h-24),Color(edge_color,0.5),1,false)
		for fraction in [0.23,0.5,0.77]:
			var y = h*fraction
			draw_line(Vector2(6,y-5),Vector2(18,y+5),edge_color,1.5,false)
			draw_line(Vector2(6,y+5),Vector2(18,y-5),edge_color,1.5,false)
