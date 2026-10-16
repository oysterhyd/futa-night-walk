extends Node

var data: Dictionary = {}
var skills: Dictionary = {}
var textures: Dictionary = {}
var animations: Dictionary = {}
var actor_material: ShaderMaterial
var body_font: Font
var title_font: Font
var atlas_regions: Dictionary = {}
const NATIVE = preload("res://content/native_content.gd")

const ELEMENTS = {
	"fire_talisman": "fire", "blast_pill": "fire", "starfall": "fire",
	"thunder_mark": "thunder", "shock_ring": "thunder",
	"frost_sand": "frost", "frost_ring": "frost", "lag_seal": "frost",
	"poison_mist": "poison", "binding_hex": "poison",
}
const COLORS = {
	"fire": Color("ad3527"), "thunder": Color("8e692e"),
	"frost": Color("396376"), "poison": Color("516849"),
	"spirit": Color("243e54"), "enemy": Color("c23a2b"),
}

func _ready() -> void:
	actor_material = ShaderMaterial.new()
	actor_material.shader = preload("res://shaders/actor.gdshader")
	data = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/content.json"))
	data["oaths"] = NATIVE.OATHS
	data.camp.vigor.desc = "初始生命上限 +3 / 级"
	data.camp.focus.desc = "所有伤害 +2% / 级"
	data.camp.stride.desc = "角色移动速度 +1.5% / 级"
	for achievement in data.achievements:
		if achievement.id=="evolve": achievement.name="攻法初成"; achievement.desc="完成一次装备或技能改造。"
	data.characters.alchemist.trait = "火毒持续伤害 +60%；过关额外回复 15 点生命。"
	for item in data.routes:
		if item.id=="relic": item.effect = "从三件未持有的遗物中选择一件；槽位已满时可替换。"
	atlas_regions = JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/atlas_regions.json"))
	for raw in JSON.parse_string(FileAccess.get_file_as_string("res://assets/data/skills.json")):
		skills[raw.id] = raw
	body_font = load("res://assets/fonts/NightRoadNotes.ttf")
	title_font = load("res://assets/fonts/NightRoadInscription.ttf")
	title_font.fallbacks = [body_font]
	for key in ["title","arena","arena-fox","arena-temple","arena-tower","environment-props","chapter-icons"]:
		textures[key] = load("res://assets/images/"+key+"-print.png")

func chapter_icon(kind: String, key: String) -> AtlasTexture:
	var cache_key="icon:"+kind+":"+key
	if textures.has(cache_key): return textures[cache_key]
	var index=ChapterContent.GEAR.keys().find(key) if kind=="gear" else 6+ChapterContent.SKILLS.keys().find(key)
	var cut=atlas_regions["chapter-icons-print"][int(index/4)].frames[index%4]
	var icon=AtlasTexture.new()
	icon.atlas=textures["chapter-icons"]
	icon.region=Rect2(cut[0],cut[1],cut[2],cut[3]); icon.filter_clip=true
	textures[cache_key]=icon
	return icon

func element(key: String) -> String:
	return ELEMENTS.get(key, "spirit")

func color_for(key: String) -> Color:
	return COLORS.get(element(key), COLORS.spirit) if key != "enemy" else COLORS.enemy

func sprite(index: int) -> AtlasTexture:
	return actor_frames(index).get_frame_texture("idle",0)

func route(key: String) -> Dictionary:
	for item in data.routes:
		if item.id == key:
			return item
	return {}

func prop(index: int) -> AtlasTexture:
	var atlas = AtlasTexture.new()
	atlas.atlas = textures["environment-props"]
	var cell = atlas.atlas.get_size() / Vector2(4,2)
	atlas.region = Rect2(Vector2(index%4,int(index/4))*cell,cell)
	return atlas

func actor_frames(index: int) -> SpriteFrames:
	if animations.has(index): return animations[index]
	var print_path = ["keeper","swordswoman","alchemist"][index] if index<3 else ("enemy" if index<8 else "boss")
	var path = "enemy-print-v2" if index>=3 and index<8 else print_path+"-print"
	var sheet = load("res://assets/images/"+path+".png")
	var grid = Vector2(6,4 if index>=8 else 5)
	var cell = sheet.get_size()/grid
	var frames = SpriteFrames.new()
	frames.remove_animation("default")
	if index<3:
		var names = ["idle","walk","dash","cast","death"]
		for row in range(5):
			frames.add_animation(names[row])
			frames.set_animation_speed(names[row],[6,11,30,18,9][row])
			frames.set_animation_loop(names[row],row<2)
			for column in range(6):
				if row==3:
					var cast_name = print_path+"-cast-print"
					frames.add_frame(names[row],measured_frame(load("res://assets/images/"+cast_name+".png"),cast_name,0,column))
				else: frames.add_frame(names[row],print_atlas_frame(sheet,column,row,print_path) if path.ends_with("-print") else atlas_frame(sheet,Vector2(column,row),cell))
	else:
		var row = index-8 if index>=8 else index-3
		var spec = {"idle":[0,1],"walk":[0,1],"windup":[2,3],"attack":[4,5]} if index>=8 else {"idle":[0],"walk":[0,1,2,3],"windup":[4],"attack":[5,0]}
		for name in spec:
			frames.add_animation(name)
			frames.set_animation_loop(name,name in ["idle","walk"])
			frames.set_animation_speed(name,(3 if name=="windup" else 6) if index>=8 else 9)
			for column in spec[name]: frames.add_frame(name,measured_frame(sheet,path,row,column) if path in ["enemy-print-v2","boss-print"] else (print_atlas_frame(sheet,column,row,print_path) if path.ends_with("-print") else atlas_frame(sheet,Vector2(column,row),cell)))
	animations[index] = frames
	return frames

func atlas_frame(sheet: Texture2D, coordinate: Vector2, cell: Vector2) -> AtlasTexture:
	var frame = AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(coordinate*cell,cell)
	return frame

func measured_frame(sheet: Texture2D, name: String, row: int, column: int) -> AtlasTexture:
	var entry = atlas_regions[name][row]
	var cut = entry.frames[column]
	var canvas = Vector2(entry.canvas[0],entry.canvas[1])
	var frame = AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(cut[0],cut[1],cut[2],cut[3])
	frame.margin = Rect2(Vector2((canvas.x-cut[2])/2,canvas.y-cut[3]),canvas-Vector2(cut[2],cut[3]))
	frame.filter_clip = true
	return frame

func print_atlas_frame(sheet: Texture2D, column: int, row: int, name: String) -> AtlasTexture:
	# The authored pose rows are optically spaced. These cuts keep neighboring
	# heads/feet out of a frame; actors anchor every pose to its lower edge.
	var rows = {
		"enemy":[0.0,0.195,0.391,0.561,0.790,1.0],
		"keeper":[0.0,0.195,0.392,0.590,0.792,1.0],
		"swordswoman":[0.0,0.226,0.440,0.615,0.825,1.0],
		"alchemist":[0.0,0.198,0.390,0.578,0.780,1.0],
		"boss":[0.0,0.25,0.5,0.75,1.0],
	}[name]
	var frame = AtlasTexture.new()
	frame.atlas = sheet
	frame.region = Rect2(column*sheet.get_width()/6.0,roundf(rows[row]*sheet.get_height()),sheet.get_width()/6.0,roundf(rows[row+1]*sheet.get_height())-roundf(rows[row]*sheet.get_height()))
	frame.filter_clip = true
	return frame

func choice_info(choice: String, world) -> Dictionary:
	if world is ChapterWorld: return world.chapter_choice_info(choice)
	var parts = choice.split(":")
	var kind = parts[0]
	var key = parts[1]
	if kind == "o":
		var item = data.oaths[key]
		return {"name":item.name,"desc":item.desc,"tag":"出发誓愿 · 本局永久生效","glyph":item.glyph,"note":item.note,"color":item.color}
	if kind in ["r","d"]:
		var item = data.relics[key]
		var note = "遗物栏 %d / 4 · 同一种遗物只能带一件" % world.relics.size()
		if kind == "d": note = "弃置此遗物，换取 " + data.relics[world.pending_replacement].name
		return {"name":item.name,"desc":item.desc,"tag":"拾取遗物" if kind=="r" else "弃置遗物","glyph":item.glyph,"note":note,"color":Color("ad3527")}
	if kind == "w":
		var lv = world.weapons.get(key, 0)
		var recipe = data.evolutions.get(key, {})
		var note = ""
		if not recipe.is_empty():
			note = "进阶需求：5级 + " + data.passives[recipe.passive].name + " → " + recipe.name
		return {"name": skills[key].name, "desc": data.spell_text[key], "tag": "符术 · %s → %s级" % [lv, lv + 1], "glyph": data.spell_glyphs[key], "note": note, "color": color_for(key)}
	if kind == "p":
		var item = data.passives[key]
		return {"name": item.name, "desc": item.desc, "tag": "秘卷 · %s → %s级" % [world.passives.get(key, 0), world.passives.get(key, 0) + 1], "glyph": item.glyph, "note": "提升整体能力", "color": Color("3f6877")}
	if kind == "e":
		var item = data.evolutions[key]
		return {"name": item.name, "desc": item.desc, "tag": "符法蜕变", "glyph": data.spell_glyphs[key], "note": "大幅质变符术形态与效果", "color": Color("ad3527")}
	return {"name": "行囊疗伤" if key == "heal" else "银两入袋", "desc": "回复 25 点生命" if key == "heal" else "获得 30 铜钱", "tag": "补给", "glyph": "灯" if key == "heal" else "钱", "note": "符法已升满", "color": Color("ad3527")}
