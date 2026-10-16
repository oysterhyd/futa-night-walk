class_name InkSeal
extends Control

var color = Color("e0603f")

func _draw() -> void:
	var w = size.x
	var h = size.y
	# Uneven stamp edge, inner border and two ink breaks.
	draw_colored_polygon(PackedVector2Array([Vector2(2,3),Vector2(w*0.5,1),Vector2(w-3,2),Vector2(w-1,h*0.5),Vector2(w-2,h-4),Vector2(w*0.45,h-1),Vector2(3,h-2),Vector2(1,h*0.48)]),color)
	draw_rect(Rect2(w*0.09,h*0.09,w*0.82,h*0.82),Color(1,0.96,0.86,0.75),false,maxf(1.0,w*0.025))
	draw_line(Vector2(1,h*0.62),Vector2(w*0.1,h*0.6),Color("0b1519"),2)
	draw_line(Vector2(w*0.88,h*0.24),Vector2(w,h*0.26),Color("0b1519"),2)
