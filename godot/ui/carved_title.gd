class_name CarvedTitle
extends Control

func _draw() -> void:
	var glyphs = ["燃","灯","夜","行"]
	var offsets = [Vector2(0,121),Vector2(124,116),Vector2(251,128),Vector2(371,118)]
	for i in range(4):
		draw_set_transform(offsets[i],[-0.045,0.024,-0.028,0.038][i])
		draw_string(Content.title_font,Vector2.ZERO,glyphs[i],HORIZONTAL_ALIGNMENT_LEFT,-1,128,UI.TEXT)
	draw_set_transform(Vector2.ZERO)
	# Short missing-ink incisions retain the legibility of the carved letterforms.
	for stroke in [[Vector2(48,59),Vector2(54,62)],[Vector2(166,87),Vector2(171,86)],[Vector2(298,46),Vector2(302,48)],[Vector2(426,93),Vector2(431,91)]]:
		draw_line(stroke[0],stroke[1],UI.PARCHMENT,1.2,false)
