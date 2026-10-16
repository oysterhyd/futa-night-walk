class_name PrintButton
extends Button

var primary = false
var face: Node2D

func _ready() -> void:
	face = Node2D.new()
	face.show_behind_parent = true
	add_child(face)
	face.draw.connect(draw_face)
	mouse_entered.connect(face.queue_redraw)
	mouse_exited.connect(face.queue_redraw)
	focus_entered.connect(face.queue_redraw)
	focus_exited.connect(face.queue_redraw)
	button_down.connect(face.queue_redraw)
	button_up.connect(face.queue_redraw)
	resized.connect(face.queue_redraw)

func draw_face() -> void:
	var w = size.x
	var h = size.y
	var active = not disabled and (is_hovered() or has_focus())
	var ink = UI.GOLD if primary or active else UI.TEXT
	if disabled: ink = Color("879087")
	var points = PackedVector2Array([Vector2(13,3),Vector2(w-19,2),Vector2(w-7,10),Vector2(w-4,h*0.48),Vector2(w-12,h-8),Vector2(w-23,h-3),Vector2(w*0.62,h-5),Vector2(w*0.6,h-2),Vector2(10,h-4),Vector2(4,h-13),Vector2(7,h*0.5),Vector2(4,12)])
	face.draw_colored_polygon(points, ink if primary and not disabled else Color("eee5cf"))
	points.append(points[0])
	face.draw_polyline(points,ink,2 if active else 1.5,false)
	var cut_color = UI.PARCHMENT if primary and not disabled else ink
	# The thin paired rails and corner cuts belong to the carved sign itself.
	face.draw_line(Vector2(20,9),Vector2(w-26,9),Color(cut_color,0.65),1,false)
	face.draw_line(Vector2(18,h-11),Vector2(w-25,h-11),Color(cut_color,0.65),1,false)
	for i in range(3):
		face.draw_line(Vector2(10+i*3,17),Vector2(12+i*3,22),cut_color,1,false)
	if active:
		var arrow = PackedVector2Array([Vector2(w-21,h/2-6),Vector2(w-13,h/2),Vector2(w-21,h/2+6)])
		face.draw_colored_polygon(arrow,cut_color)
