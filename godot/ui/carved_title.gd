class_name CarvedTitle
extends Control

# Brush title "燃灯夜行" — paper-white strokes with a warm lamp glow behind "灯".
var flicker = 0.0

func _process(dt: float) -> void:
	flicker += dt
	queue_redraw()

func _draw() -> void:
	var glyphs = ["燃","灯","夜","行"]
	var offsets = [Vector2(0,121),Vector2(124,116),Vector2(251,128),Vector2(371,118)]
	var f = 0.82+0.1*sin(flicker*2.3)+0.05*sin(flicker*7.1)
	draw_texture_rect(UI.glow(),Rect2(70,-40,230,230),false,Color(UI.AMBER,0.32*f))
	for i in range(4):
		draw_set_transform(offsets[i]+Vector2(3,5),[-0.045,0.024,-0.028,0.038][i])
		draw_string(Content.title_font,Vector2.ZERO,glyphs[i],HORIZONTAL_ALIGNMENT_LEFT,-1,128,Color(0,0,0,0.55))
		draw_set_transform(offsets[i],[-0.045,0.024,-0.028,0.038][i])
		var tint = UI.PARCHMENT if i!=1 else UI.PARCHMENT.lerp(UI.AMBER,0.35*f)
		draw_string(Content.title_font,Vector2.ZERO,glyphs[i],HORIZONTAL_ALIGNMENT_LEFT,-1,128,tint)
	draw_set_transform(Vector2.ZERO)
