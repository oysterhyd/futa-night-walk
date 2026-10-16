class_name StoryView
extends Control

# Full-screen illustrated story panels. Lines fade in one at a time over a slow
# Ken Burns drift. Accept advances; the skip button (owned by caller) ends it.
signal finished

var panels: Array = []
var final_line = ""
var index = -1
var shown_lines = 0
var line_timer = 0.0
var age = 0.0
var art_tween: Tween
var art: TextureRect
var art_next: TextureRect
var lines_box: Control
var prompt: Label
var counter: Label
var done = false
var line_nodes: Array = []
var caption = ""

static var _cache: Dictionary = {}

static func texture(key: String) -> Texture2D:
	if not Lore.IMAGES.has(key): key = "title"
	if not _cache.has(key): _cache[key] = load(Lore.IMAGES[key])
	return _cache[key]

func setup(items: Array, last: String = "", title: String = "") -> void:
	panels = items
	final_line = last
	caption = title
	size = Vector2(1600,900)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var black = UI.shade(self,Color("05090b"))
	black.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art = TextureRect.new()
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.size = Vector2(1600,900)
	art.pivot_offset = Vector2(800,450)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(art)
	UI.gradient(self,Rect2(0,430,1600,300),Color(0.02,0.04,0.05,0.0),Color(0.02,0.04,0.05,0.82),false)
	UI.shade(self,Color(0.02,0.04,0.05,0.82),Rect2(0,730,1600,170))
	UI.gradient(self,Rect2(0,0,1600,160),Color(0.02,0.04,0.05,0.7),Color(0.02,0.04,0.05,0.0),false)
	lines_box = Control.new()
	lines_box.size = Vector2(1600,900)
	lines_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(lines_box)
	if not caption.is_empty():
		var head = UI.label(self,caption,Rect2(70,44,700,40),22,Color(UI.AMBER,0.85),true)
		UI.shadowed(head)
	counter = UI.label(self,"",Rect2(70,836,300,30),17,Color(UI.MUTED,0.8))
	prompt = UI.label(self,"点击 / 回车 继续",Rect2(1180,836,350,30),18,Color(UI.TEXT,0.6))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_next_panel()

func _next_panel() -> void:
	index += 1
	for node in line_nodes: node.queue_free()
	line_nodes.clear()
	shown_lines = 0
	line_timer = 0.25
	if index >= panels.size():
		if not final_line.is_empty() and index == panels.size():
			_final_card()
			return
		_finish()
		return
	var panel: Dictionary = panels[index]
	art.texture = texture(panel.get("image","title"))
	art.scale = Vector2.ONE*1.0
	art.position = Vector2.ZERO
	art.modulate.a = 0.0 if UI.motion() else 1.0
	if art_tween and art_tween.is_valid(): art_tween.kill()
	if UI.motion():
		art_tween = create_tween().set_parallel()
		var tween = art_tween
		tween.tween_property(art,"modulate:a",1.0,0.8)
		var drift = Vector2([-24,24,-16][index%3],[10,-8,14][index%3])
		tween.tween_property(art,"scale",Vector2.ONE*1.07,14.0).set_trans(Tween.TRANS_SINE)
		tween.tween_property(art,"position",drift,14.0).set_trans(Tween.TRANS_SINE)
	counter.text = "%d / %d" % [index+1,panels.size()+(1 if not final_line.is_empty() else 0)]
	var lines: Array = panel.get("lines",[])
	var top = 820-lines.size()*58
	for i in range(lines.size()):
		var node = UI.paragraph(lines_box,lines[i],Rect2(240,top+i*58,1120,56),29,UI.PARCHMENT)
		node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		node.add_theme_font_override("font",Content.body_font)
		UI.shadowed(node,0.9)
		node.modulate.a = 0.0
		line_nodes.append(node)

func _final_card() -> void:
	art.texture = texture("dawn")
	if art_tween and art_tween.is_valid(): art_tween.kill()
	art.scale = Vector2.ONE
	art.position = Vector2.ZERO
	var tween = create_tween()
	art_tween = tween
	art.modulate.a = 0.35
	tween.tween_property(art,"modulate:a",0.55,1.2)
	counter.text = "%d / %d" % [index+1,panels.size()+1]
	var node = UI.label(lines_box,final_line,Rect2(0,370,1600,140),88,UI.BRIGHT,true)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.shadowed(node,0.9)
	node.modulate.a = 0.0
	line_nodes.append(node)
	shown_lines = 0
	line_timer = 0.5

func _process(dt: float) -> void:
	if done: return
	age += dt
	line_timer -= dt
	if line_timer <= 0 and shown_lines < line_nodes.size():
		var node: Control = line_nodes[shown_lines]
		if UI.motion():
			var t = create_tween().set_parallel()
			var y = node.position.y
			node.position.y = y+10
			t.tween_property(node,"modulate:a",1.0,0.7)
			t.tween_property(node,"position:y",y,0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		else: node.modulate.a = 1.0
		shown_lines += 1
		line_timer = 1.1
	prompt.modulate.a = (0.45+0.35*sin(age*3.0)) if shown_lines >= line_nodes.size() else 0.15

func advance() -> void:
	if done: return
	if shown_lines < line_nodes.size():
		for node in line_nodes: node.modulate.a = 1.0
		shown_lines = line_nodes.size()
		return
	_next_panel()

func skip() -> void:
	_finish()

func _finish() -> void:
	if done: return
	done = true
	finished.emit()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()
		accept_event()


class ChapterCard extends Control:
	# Non-blocking chapter title card that plays over the entry room.
	var life = 0.0
	var total = 3.6
	func setup(stage: int) -> void:
		var info: Dictionary = Lore.CHAPTERS[clampi(stage-1,0,3)]
		size = Vector2(1600,900)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		var band = Control.new()
		band.position = Vector2(0,270); band.size = Vector2(1600,300); band.clip_contents = true
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(band)
		var art = UI.cover(band,StoryView.texture(info.image),Rect2(0,-300,1600,900))
		art.modulate = Color(0.8,0.82,0.86,0.9)
		UI.gradient(band,Rect2(0,0,1600,300),Color(0.03,0.06,0.07,0.92),Color(0.03,0.06,0.07,0.15))
		UI.gradient(self,Rect2(0,230,1600,40),Color(0,0,0,0),Color(0.03,0.06,0.07,0.85),false)
		UI.gradient(self,Rect2(0,570,1600,40),Color(0.03,0.06,0.07,0.85),Color(0,0,0,0),false)
		UI.label(self,"第%s章" % info.numeral,Rect2(150,318,300,40),26,UI.AMBER,true)
		UI.seal(self,info.numeral,Rect2(150,368,96,96))
		var name_label = UI.label(self,info.name,Rect2(275,360,900,110),92,UI.BRIGHT,true)
		UI.shadowed(name_label,0.8)
		var line_label = UI.label(self,info.line,Rect2(280,478,1100,44),26,UI.TEXT)
		UI.shadowed(line_label,0.8)
		modulate.a = 0.0
	func _process(dt: float) -> void:
		life += dt
		var a = clampf(life/0.45,0,1)*clampf((total-life)/0.7,0,1)
		modulate.a = a
		if UI.motion(): position.x = (1.0-ease(clampf(life/0.6,0,1),0.3))*-40
		if life >= total: queue_free()


class BossCard extends Control:
	# Letterbox intro for a boss: bars slide in, name/epithet/quote, then retract.
	var life = 0.0
	var total = 3.4
	var top: ColorRect
	var bottom: ColorRect
	var text_root: Control
	func setup(stage: int) -> void:
		var info: Dictionary = Lore.BOSSES[clampi(stage-1,0,3)]
		size = Vector2(1600,900)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		top = UI.shade(self,Color(0.01,0.02,0.03,0.96),Rect2(0,-110,1600,110))
		bottom = UI.shade(self,Color(0.01,0.02,0.03,0.96),Rect2(0,900,1600,150))
		text_root = Control.new(); text_root.size = Vector2(1600,900); text_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(text_root)
		UI.label(text_root,info.epithet,Rect2(120,770,600,34),22,UI.AMBER,true)
		var name_label = UI.label(text_root,info.name,Rect2(116,800,700,80),64,UI.BRIGHT,true)
		UI.shadowed(name_label)
		var quote = UI.label(text_root,"「%s」" % info.quote,Rect2(760,812,780,44),25,UI.TEXT)
		quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		UI.seal(text_root,"首",Rect2(40,800,58,58))
		text_root.modulate.a = 0.0
	func _process(dt: float) -> void:
		life += dt
		var inn = ease(clampf(life/0.45,0,1),0.4)
		var out = ease(clampf((total-life)/0.5,0,1),0.4)
		var k = minf(inn,out)
		top.position.y = -110+110*k
		bottom.position.y = 900-150*k
		text_root.modulate.a = clampf((life-0.3)/0.4,0,1)*out
		if life >= total: queue_free()
