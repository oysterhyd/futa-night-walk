class_name CombatBatch
extends Node2D

const MAX_INSTANCES = 700
const PROJECTILE_SHAPES = {"piercing_spike":"blade","armor_breaker":"blade","spirit_orb":"pearl","soul_lantern":"lantern","frost_sand":"frost","echo_mark":"echo","blast_pill":"pill","soul_arrow":"arrow","thunder_mark":"thunder"}
var batches: Dictionary = {}
var sparks: MultiMeshInstance2D
var shadows: MultiMeshInstance2D
var health_bg: MultiMeshInstance2D
var health_fg: MultiMeshInstance2D
var art_batches: Dictionary = {}
var art_counts: Dictionary = {}
var drop_batches: Dictionary = {}

func _ready() -> void:
	for spec in [["hostile",Vector2(30,30),14],["danger_arrow",Vector2(48,24),13],["danger_trail",Vector2(46,20),15],["blade",Vector2(36,9),1],["talisman",Vector2(20,14),2],["trail",Vector2(42,12),3],["pearl",Vector2(23,23),6],["lantern",Vector2(24,29),7],["frost",Vector2(23,23),8],["echo",Vector2(25,25),9],["pill",Vector2(22,22),10],["arrow",Vector2(34,12),11],["thunder",Vector2(23,23),12]]:
		batches[spec[0]] = make_batch(spec[1],spec[2],MAX_INSTANCES)
	sparks = make_batch(Vector2(9,3),1,2200)
	shadows = make_batch(Vector2(60,20),4,260)
	shadows.z_index = -1240
	health_bg = make_batch(Vector2(64,4),5,250)
	health_fg = make_batch(Vector2(64,4),5,250)
	for spec in [["shard",16],["paper",17],["crest",18],["water",19]]:
		var batch=make_batch(Vector2(2,2),spec[1],3000)
		batch.z_index=80
		art_batches[spec[0]]=batch
		art_counts[spec[0]]=0
	for spec in [["coin",20],["other",21]]:
		var batch=make_batch(Vector2(12,12),spec[1],512)
		batch.z_index=-1149
		drop_batches[spec[0]]=batch

func begin_art() -> void:
	for key in art_counts: art_counts[key]=0

func art(key: String, p: Vector2, angle: float, size: Vector2, color: Color) -> void:
	var count=int(art_counts[key])
	if count>=3000: return
	put(art_batches[key],count,p,angle,color,size)
	art_counts[key]=count+1

func end_art() -> void:
	for key in art_counts: art_batches[key].multimesh.visible_instance_count=art_counts[key]

func make_batch(size: Vector2, shape: int, capacity: int) -> MultiMeshInstance2D:
	var node = MultiMeshInstance2D.new()
	var mesh = QuadMesh.new()
	mesh.size = size
	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_2D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = capacity
	multimesh.visible_instance_count = 0
	node.multimesh = multimesh
	var material = ShaderMaterial.new()
	material.shader = preload("res://shaders/bolt_batch.gdshader")
	material.set_shader_parameter("shape",shape)
	node.material = material
	add_child(node)
	return node

func put(batch: MultiMeshInstance2D, index: int, p: Vector2, angle: float, color: Color, scale_value: Vector2 = Vector2.ONE) -> void:
	var transform = Transform2D(angle,p).scaled_local(scale_value)
	batch.multimesh.set_instance_transform_2d(index,transform)
	batch.multimesh.set_instance_color(index,color)

func sync(world: RunWorld, effects: Array, particles: bool, visual_age: float=0.0) -> void:
	var drop_counts={"coin":0,"other":0}
	for drop in world.drops:
		var group="coin" if drop.kind=="coin" else "other"
		var batch=drop_batches[group]
		if batch.multimesh.instance_count<world.drops.size(): batch.multimesh.instance_count=world.drops.size()
		var p=world.pos(drop)+Vector2(0,sin(visual_age*4+drop.x)*2)
		var color=Color("8e692e") if group=="coin" else (Color("396376") if drop.kind=="xp" else Color("ad3527"))
		put(batch,drop_counts[group],p,0,color)
		drop_counts[group]+=1
	for key in drop_counts: drop_batches[key].multimesh.visible_instance_count=drop_counts[key]
	var shadow_count = 0
	var health_count = 0
	put(shadows,shadow_count,world.pos(world.player)+Vector2(0,4),0,Color(0,0,0,0.4),Vector2.ONE*0.95)
	shadow_count += 1
	for mob in world.mobs:
		if mob.hp<=0: continue
		var size = (180 if mob.boss else (105 if mob.kind=="stone_guard" else 82))*(1.18 if mob.elite else 1.0)
		put(shadows,shadow_count,world.pos(mob)+Vector2(0,4),0,Color(0,0,0,0.4),Vector2.ONE*size/100.0)
		shadow_count += 1
		if mob.hp<mob.max_hp and not mob.boss:
			var p = world.pos(mob)+Vector2(0,-size-9)
			var width = 60.0 if mob.elite else 42.0
			var fraction = clampf(mob.hp/mob.max_hp,0,1)
			put(health_bg,health_count,p,0,Color("183544"),Vector2(width/64.0,1))
			put(health_fg,health_count,p+Vector2(-width*(1-fraction)*0.5,0),0,Color("ad3527"),Vector2(width*fraction/64.0,1))
			health_count += 1
	shadows.multimesh.visible_instance_count = shadow_count
	health_bg.multimesh.visible_instance_count = health_count
	health_fg.multimesh.visible_instance_count = health_count
	var counts = {}
	for key in batches: counts[key] = 0
	for bolt in world.bolts:
		var p = world.pos(bolt)
		var direction = Vector2(bolt.vx,bolt.vy).normalized()
		var color = Content.color_for(bolt.source)
		var group = ("danger_arrow" if bolt.get("skin","")=="arrow" else "hostile") if bolt.hostile else PROJECTILE_SHAPES.get(bolt.source,"talisman")
		put(batches[group],counts[group],p,direction.angle(),color)
		counts[group] += 1
		var trail_group="danger_trail" if bolt.hostile else "trail"
		put(batches[trail_group],counts[trail_group],p-direction*27,direction.angle(),Color(color,0.85 if bolt.hostile else 0.6))
		counts[trail_group] += 1
	for key in batches: batches[key].multimesh.visible_instance_count = counts[key]
	var count = 0
	if particles:
		for effect in effects:
			if effect.kind not in ["spark","death","dash"]: continue
			var t = 1.0-effect.life/effect.max_life
			var color = Color(effect.color,1.0-t)
			for i in range(6 if effect.kind=="spark" else 12):
				if count>=2200: break
				var angle = i*2.399+effect.x
				var p = Vector2(effect.x,effect.y)+Vector2.from_angle(angle)*effect.radius*t
				put(sparks,count,p,angle,color,Vector2(maxf(0.2,1.0-t),1))
				count += 1
	sparks.multimesh.visible_instance_count = count
