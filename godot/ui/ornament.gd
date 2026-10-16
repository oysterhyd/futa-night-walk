class_name Ornament
extends Control

var kind = "rule"
var color = Color("b8945a")

func _draw() -> void:
	var w = size.x
	var h = size.y
	match kind:
		"rule":
			var y = h*0.5
			draw_line(Vector2(0,y),Vector2(w*0.5-9,y),Color(color,0.55),1.0,true)
			draw_line(Vector2(w*0.5+9,y),Vector2(w,y),Color(color,0.55),1.0,true)
			draw_colored_polygon(PackedVector2Array([Vector2(w*0.5,y-5),Vector2(w*0.5+5,y),Vector2(w*0.5,y+5),Vector2(w*0.5-5,y)]),color)
		"tick":
			draw_colored_polygon(PackedVector2Array([Vector2(w*0.5,0),Vector2(w,h*0.5),Vector2(w*0.5,h),Vector2(0,h*0.5)]),color)
		"diamond":
			draw_colored_polygon(PackedVector2Array([Vector2(w*0.5,0),Vector2(w,h*0.5),Vector2(w*0.5,h),Vector2(0,h*0.5)]),color)
			draw_colored_polygon(PackedVector2Array([Vector2(w*0.5,h*0.3),Vector2(w*0.7,h*0.5),Vector2(w*0.5,h*0.7),Vector2(w*0.3,h*0.5)]),Color("0b1519"))
