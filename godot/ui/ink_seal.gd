class_name InkSeal
extends Control

var color = Color("ad3527")

func _draw() -> void:
	var w = size.x
	var h = size.y
	draw_colored_polygon(PackedVector2Array([Vector2(2,3),Vector2(w-4,2),Vector2(w-2,h-5),Vector2(4,h-2)]),color)
	draw_rect(Rect2(8,8,w-16,h-16),Color("e8dfc5"),false,2)
	draw_line(Vector2(2,h*0.6),Vector2(7,h*0.6-1),Color("e8dfc5"),2)
	draw_line(Vector2(w-8,h*0.25),Vector2(w,h*0.25+1),Color("e8dfc5"),2)
