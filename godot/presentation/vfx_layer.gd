class_name VfxLayer
extends Node2D

# Batched particle layer. Every sprite, seal and procedural arc is a MultiMesh
# instance, so a full screen of effects costs six draw calls. Particles are
# simulated here; CombatVfx decides what to spawn.

const ATLAS = preload("res://assets/vfx/vfx-atlas.png")
const SEALS = preload("res://assets/vfx/vfx-seals.png")
const NOISE = preload("res://assets/vfx/vfx-noise.png")
const SPRITE_ADD = preload("res://shaders/vfx_sprite_add.gdshader")
const SPRITE_MIX = preload("res://shaders/vfx_sprite_mix.gdshader")
const ARC_ADD = preload("res://shaders/vfx_arc_add.gdshader")
const ARC_MIX = preload("res://shaders/vfx_arc_mix.gdshader")
# Mirrors tools/make_vfx_textures.py.
const CELL = {
	"glow":0,"flare":1,"burst":2,"star":3,"soft_star":4,"streak":5,"thin_streak":6,"bolt_a":7,
	"bolt_b":8,"bolt_c":9,"crackle_a":10,"crackle_b":11,"crackle_c":12,"smoke_a":13,"smoke_b":14,"smoke_c":15,
	"smoke_d":16,"smoke_e":17,"smoke_f":18,"smoke_ring":19,"fire_a":20,"fire_b":21,"flame_wisp":22,"flame_tongue":23,
	"flame_lick":24,"muzzle_a":25,"muzzle_b":26,"scorch_a":27,"scorch_b":28,"dirt_a":29,"dirt_b":30,"twirl_a":31,
	"twirl_b":32,"ring":33,"rays":34,"claw":35,"crescent":36,"cross_star":37,
	"talisman":40,"talisman_b":41,"petal":42,"blossom":43,"paper_a":44,"paper_b":45,"ice_shard":46,"ice_spike":47,
	"snowflake":48,"chain":49,"ink_a":50,"ink_b":51,"ink_spray":52,"crack":53,"bubble":54,"brush":55,"pill":56,
}
const SEAL = {"bagua":0,"bind":1,"sun":2,"frost":3}
const SMOKES = ["smoke_a","smoke_b","smoke_c","smoke_d","smoke_e","smoke_f"]
enum {ARC_MIX_POOL, SEAL_MIX_POOL, MIX_POOL, ARC_ADD_POOL, SEAL_ADD_POOL, ADD_POOL}
const CAPACITY = [96, 24, 1400, 160, 24, 1800]

class Particle:
	var pool = 0
	var cell = 0.0
	var pos = Vector2.ZERO
	var vel = Vector2.ZERO
	var acc = Vector2.ZERO
	var drag = 0.0
	var life = 1.0
	var max_life = 1.0
	var delay = 0.0
	var rot = 0.0
	var spin = 0.0
	var align = false
	var size0 = Vector2.ONE
	var size1 = Vector2.ONE
	var size_ease = 1.0
	var c0 = Color.WHITE
	var c1 = Color(1,1,1,0)
	var fade_in = 0.0
	var e0 = 0.0
	var e1 = 0.0
	var seed = 0.0
	var hot = 0.0
	var span = 1.0
	var thick = 0.2
	var style = 0.0
	var flip = 1.0

var pools: Array = []
var particles: Array = []
var once_list: Array = []
var flashes: Array = []
var rng = RandomNumberGenerator.new()
var reduced = false
var budget = 2600

func _ready() -> void:
	rng.randomize()
	var quad = ArrayMesh.new()
	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector2Array([Vector2(-0.5,-0.5),Vector2(0.5,-0.5),Vector2(0.5,0.5),Vector2(-0.5,0.5)])
	arrays[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0,0),Vector2(1,0),Vector2(1,1),Vector2(0,1)])
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array([0,1,2,0,2,3])
	quad.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays,[],{},Mesh.ARRAY_FLAG_USE_2D_VERTICES)
	var specs = [[ARC_MIX,null,1.0],[SPRITE_MIX,SEALS,2.0],[SPRITE_MIX,ATLAS,8.0],[ARC_ADD,null,1.0],[SPRITE_ADD,SEALS,2.0],[SPRITE_ADD,ATLAS,8.0]]
	for i in range(specs.size()):
		var node = MultiMeshInstance2D.new()
		var mm = MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_2D
		mm.use_colors = true
		mm.use_custom_data = true
		mm.mesh = quad
		mm.instance_count = CAPACITY[i]
		mm.visible_instance_count = 0
		node.multimesh = mm
		if specs[i][1] != null: node.texture = specs[i][1]
		node.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		var material = ShaderMaterial.new()
		material.shader = specs[i][0]
		material.set_shader_parameter("noise_tex",NOISE)
		material.set_shader_parameter("grid",specs[i][2])
		node.material = material
		add_child(node)
		pools.append(node)

func clear() -> void:
	particles.clear(); once_list.clear(); flashes.clear()
	for node in pools: node.multimesh.visible_instance_count = 0

func full() -> bool:
	return particles.size() >= budget

# ---------- spawning ----------

func sprite(cell: String, p: Vector2, life: float, size: float, color: Color, add: bool = true) -> Particle:
	var item = Particle.new()
	item.pool = ADD_POOL if add else MIX_POOL
	item.cell = CELL.get(cell,0)
	item.pos = p
	item.life = life; item.max_life = life
	item.size0 = Vector2.ONE*size; item.size1 = item.size0
	item.c0 = color; item.c1 = Color(color,0.0)
	item.seed = rng.randf()
	item.rot = rng.randf()*TAU
	if particles.size() < budget: particles.append(item)
	return item

func smoke(p: Vector2, life: float, size: float, color: Color, add: bool = false) -> Particle:
	var item = sprite(SMOKES[rng.randi_range(0,SMOKES.size()-1)],p,life,size*0.6,color,add)
	item.size1 = Vector2.ONE*size
	item.size_ease = 0.4
	item.e0 = 0.05; item.e1 = 0.85
	item.spin = rng.randf_range(-0.8,0.8)
	item.fade_in = 0.12
	return item

func seal(key: String, p: Vector2, life: float, size0: float, size1: float, color: Color, add: bool = true) -> Particle:
	var item = Particle.new()
	item.pool = SEAL_ADD_POOL if add else SEAL_MIX_POOL
	item.cell = SEAL.get(key,0)
	item.pos = p
	item.life = life; item.max_life = life
	item.size0 = Vector2.ONE*size0; item.size1 = Vector2.ONE*size1
	item.size_ease = 0.25
	item.c0 = color; item.c1 = Color(color,0.0)
	item.seed = rng.randf()
	particles.append(item)
	return item

func arc(p: Vector2, angle: float, radius: float, span: float, thick: float, style: int, life: float, color: Color, add: bool = true, flip: bool = false) -> Particle:
	var item = Particle.new()
	item.pool = ARC_ADD_POOL if add else ARC_MIX_POOL
	item.pos = p
	item.rot = angle
	item.life = life; item.max_life = life
	item.size0 = Vector2.ONE*radius*2.0; item.size1 = item.size0
	item.c0 = color; item.c1 = color
	item.span = span; item.thick = thick; item.style = style
	item.flip = -1.0 if flip else 1.0
	particles.append(item)
	return item

func ring(p: Vector2, radius: float, thick: float, life: float, color: Color, add: bool = true, style: int = -1) -> Particle:
	return arc(p,rng.randf()*TAU,radius,PI,thick,(2 if add else 3) if style<0 else style,life,color,add)

func segment(cell: String, a: Vector2, b: Vector2, width: float, life: float, color: Color, add: bool = true) -> Particle:
	var item = sprite(cell,(a+b)*0.5,life,1.0,color,add)
	var length = a.distance_to(b)
	item.rot = (b-a).angle()
	item.size0 = Vector2(length,width); item.size1 = item.size0
	return item

func flash(p: Vector2, radius: float, intensity: float, color: Color, life: float = 0.25) -> void:
	if flashes.size() < 24: flashes.append({"pos":p,"radius":radius,"intensity":intensity,"color":color,"life":life,"max":life})

# One-frame instance (projectiles, auras). Drawn on the next flush only.
func once(cell: String, p: Vector2, rot: float, size: Vector2, color: Color, add: bool = true, hot: float = 0.0) -> void:
	if once_list.size() >= 900: return
	once_list.append([ADD_POOL if add else MIX_POOL,float(CELL.get(cell,0)),p,rot,size,color,0.0,hot,0.0,0.0,0.0])

func once_seal(key: String, p: Vector2, rot: float, size: float, color: Color, add: bool = true) -> void:
	once_list.append([SEAL_ADD_POOL if add else SEAL_MIX_POOL,float(SEAL.get(key,0)),p,rot,Vector2.ONE*size,color,0.0,0.0,0.0,0.0,0.0])

func once_arc(p: Vector2, angle: float, radius: float, span: float, thick: float, style: int, progress: float, color: Color, add: bool = true) -> void:
	once_list.append([ARC_ADD_POOL if add else ARC_MIX_POOL,progress,p,angle,Vector2.ONE*radius*2.0,color,span,thick,float(style),0.0,1.0])

# ---------- simulation ----------

func step(dt: float) -> void:
	var counts = [0,0,0,0,0,0]
	var alive: Array = []
	for item in particles:
		if item.delay > 0:
			item.delay -= dt
			alive.append(item)
			continue
		item.life -= dt
		if item.life <= 0: continue
		alive.append(item)
		if dt > 0:
			item.vel += item.acc*dt
			if item.drag > 0: item.vel *= exp(-item.drag*dt)
			item.pos += item.vel*dt
			item.rot += item.spin*dt
		var t = 1.0-item.life/item.max_life
		var pool = item.pool
		if counts[pool] >= CAPACITY[pool]: continue
		var size: Vector2 = item.size0.lerp(item.size1,pow(t,item.size_ease) if item.size_ease != 1.0 else t)
		var color: Color = item.c0.lerp(item.c1,t)
		if item.fade_in > 0 and t < item.fade_in: color.a *= t/item.fade_in
		var angle = item.vel.angle() if item.align and item.vel.length_squared() > 1.0 else item.rot
		var mm: MultiMesh = pools[pool].multimesh
		var index = counts[pool]
		mm.set_instance_transform_2d(index,Transform2D(angle,item.pos).scaled_local(Vector2(size.x,size.y*item.flip)))
		mm.set_instance_color(index,color)
		if pool == ARC_ADD_POOL or pool == ARC_MIX_POOL:
			mm.set_instance_custom_data(index,Color(t,item.span,item.thick,item.style))
		else:
			mm.set_instance_custom_data(index,Color(item.cell,lerpf(item.e0,item.e1,t),item.seed,item.hot))
		counts[pool] += 1
	particles = alive
	for entry in once_list:
		var pool: int = entry[0]
		if counts[pool] >= CAPACITY[pool]: continue
		var mm: MultiMesh = pools[pool].multimesh
		var index = counts[pool]
		mm.set_instance_transform_2d(index,Transform2D(entry[3],entry[2]).scaled_local(entry[4]))
		mm.set_instance_color(index,entry[5])
		if pool == ARC_ADD_POOL or pool == ARC_MIX_POOL: mm.set_instance_custom_data(index,Color(entry[1],entry[6],entry[7],entry[8]))
		else: mm.set_instance_custom_data(index,Color(entry[1],0.0,entry[9],entry[7]))
		counts[pool] += 1
	once_list.clear()
	for i in range(pools.size()): pools[i].multimesh.visible_instance_count = counts[i]
	for f in flashes: f.life -= dt
	flashes = flashes.filter(func(f): return f.life > 0)
