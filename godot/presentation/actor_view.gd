class_name ActorView
extends Node2D

var material_fx: ShaderMaterial
var entity: Dictionary = {}
var player_actor = false
var age = 0.0
var target_size = 85.0
var animated: AnimatedSprite2D
var casting_time = 0.0
var retiring = false
var last_flash=-1.0
var last_frozen=-1.0
var last_burning=-1.0

func setup(index: int, size: float, is_player: bool = false) -> void:
	player_actor = is_player
	target_size = size
	material_fx = Content.actor_material
	animated = AnimatedSprite2D.new()
	animated.sprite_frames = Content.actor_frames(index)
	animated.centered = false
	animated.scale = Vector2.ONE*size/animated.sprite_frames.get_frame_texture("idle",0).get_height()
	animated.position = Vector2.ZERO
	animated.material = material_fx
	add_child(animated)
	animated.frame_changed.connect(align_frame)
	animated.animation_changed.connect(align_frame)
	animated.play("idle")
	align_frame()

func sync(raw: Dictionary, dt: float) -> void:
	if retiring: return
	var first=entity.is_empty()
	entity = raw
	age += dt
	casting_time = maxf(0,casting_time-dt)
	position = Vector2(raw.x, raw.y).round()
	z_index = int(raw.y)
	var moving = raw.get("moving", false) if player_actor else raw.get("stun", 0) <= 0 and raw.get("windup", 0) <= 0
	var flash_value=clampf(raw.get("flash",0)*8,0,1)
	var frozen_value=1.0 if raw.get("slow",0)>0 else 0.0
	var burning_value=1.0 if raw.get("burn",0)>0 else 0.0
	if burning_value>0: animated.set_instance_shader_parameter("age",age)
	if last_flash!=flash_value: animated.set_instance_shader_parameter("flash",flash_value); last_flash=flash_value
	if last_frozen!=frozen_value: animated.set_instance_shader_parameter("frozen",frozen_value); last_frozen=frozen_value
	if last_burning!=burning_value: animated.set_instance_shader_parameter("burning",burning_value); last_burning=burning_value
	if animated:
		animated.speed_scale = 1.0 if dt>0 and (player_actor or raw.get("stun",0)<=0) else 0.0
		animated.flip_h = raw.get("facing",1)<0
		animated.modulate.a = 0.58+sin(age*35)*0.2 if player_actor and raw.invulnerable>0.4 else 1.0
		animated.position = Vector2.ZERO
		var next = "walk" if moving else "idle"
		if player_actor:
			if raw.hp <= 0: next = "death"
			elif raw.dash_time > 0: next = "dash"
			elif animated.animation=="cast" and animated.is_playing(): next = "cast"
			elif raw.get("cast",0)>0 and casting_time<=0:
				next = "cast"
				casting_time = 0.25
		else:
			if raw.windup > 0 or raw.get("preparing",0)>0: next = "windup"
			elif raw.charging > 0 or raw.get("cast",0)>0: next = "attack"
		if next != animated.animation:
			animated.play(next)
	if first or player_actor or raw.get("elite",false): queue_redraw()

func align_frame() -> void:
	var texture = animated.sprite_frames.get_frame_texture(animated.animation,animated.frame)
	var reference = animated.sprite_frames.get_frame_texture(animated.animation,0)
	animated.scale = Vector2.ONE*target_size/reference.get_height()
	animated.offset = Vector2(-texture.get_width()*0.5,-texture.get_height()+5)

func retire() -> void:
	retiring = true
	animated.pause()
	animated.set_instance_shader_parameter("flash",0.0)
	var duration = 0.95 if entity.get("boss",false) else 0.55
	var tween = create_tween().set_parallel()
	# the burning-paper dissolve carries the exit; fade only the last stretch
	tween.tween_method(func(value): animated.set_instance_shader_parameter("dissolve",value),0.0,1.0,duration)
	tween.tween_property(self,"modulate:a",0.0,duration*0.35).set_delay(duration*0.65)
	tween.chain().tween_callback(queue_free)

func _draw() -> void:
	if entity.is_empty(): return
	if player_actor:
		draw_arc(Vector2.ZERO, 22, 0, TAU, 40, Color("ad3527"), 1.5, true)
	elif entity.elite:
		draw_arc(Vector2.ZERO, entity.radius + 5, age, age + TAU * 0.8, 40, Color("ad3527"), 2, true)
