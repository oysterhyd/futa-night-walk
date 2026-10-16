extends Node

var canvas: Control

func _ready() -> void:
	call_deferred("run")

func capture_group(indices: Array, pose: String, filename: String) -> void:
	for node in canvas.get_children():
		canvas.remove_child(node)
		node.queue_free()
	for r in range(indices.size()):
		var frames = Content.actor_frames(indices[r])
		var animation = pose if frames.has_animation(pose) else "walk"
		for c in range(frames.get_frame_count(animation)):
			var x = 80+c*245
			var y = 40+r*int(800.0/indices.size())
			var picture = UI.image(canvas,frames.get_frame_texture(animation,c),Rect2(x,y,170,140 if indices.size()>4 else 190))
			if c==0: print("Atlas ",indices[r]," texture=",picture.texture.get_size()," control=",picture.size," mode=",picture.stretch_mode)
			UI.label(canvas,str(indices[r])+" / "+animation+" / "+str(c),Rect2(x,y+145 if indices.size()>4 else y+195,200,30),17)
	for i in range(4): await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-output/"+filename+".png")

func run() -> void:
	await get_tree().process_frame
	var paper = ColorRect.new()
	paper.size = Vector2(1600,900)
	paper.color = UI.PARCHMENT
	add_child(paper)
	canvas = Control.new()
	canvas.theme = UI.theme()
	add_child(canvas)
	await capture_group([0,1,2],"walk","atlas-player-walk")
	await capture_group([0,1,2],"cast","atlas-player-cast")
	await capture_group([0,1,2],"death","atlas-player-death")
	await capture_group([3,4,5,6,7],"walk","atlas-enemy-walk")
	await capture_group([8,9,10,11],"attack","atlas-boss-attack")
	Sound.shutdown()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit()
