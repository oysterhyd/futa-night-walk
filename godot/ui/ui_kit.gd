class_name UI
extends RefCounted

# 夜色漆面 + 灯火：深色漆盒为底，黄铜描边，朱砂为强调，灯火琥珀为能量。
# 旧常量名保持不变（TEXT/MUTED/GOLD/PARCHMENT/JADE），色值改为夜间主题。
const TEXT = Color("ece2c8")
const MUTED = Color("9aa39b")
const GOLD = Color("e0603f")
const PARCHMENT = Color("e8dfc5")
const JADE = Color("7fb3ad")
const NIGHT = Color("0b1519")
const LACQUER = Color("13222a")
const LACQUER_HI = Color("1d323b")
const BRASS = Color("b8945a")
const AMBER = Color("f0b85e")
const INK = Color("183544")
const BRIGHT = Color("fff4dc")
const DIM = Color("5d6a66")

static var _grain: Texture2D
static var _glow: Texture2D
static var _brush: Texture2D

static func grain() -> Texture2D:
	if _grain == null: _grain = load("res://assets/ui/paper-grain.png")
	return _grain

static func glow() -> Texture2D:
	if _glow == null: _glow = load("res://assets/ui/glow.png")
	return _glow

static func brush() -> Texture2D:
	if _brush == null: _brush = load("res://assets/ui/brush.png")
	return _brush

static func motion() -> bool:
	return bool(Save.profile.get("settings",{}).get("motion",true))

static func theme() -> Theme:
	var result = Theme.new()
	result.default_font = Content.body_font
	result.default_font_size = 23
	for type in ["Button", "OptionButton"]:
		result.set_color("font_color", type, TEXT)
		result.set_color("font_hover_color", type, BRIGHT)
		result.set_color("font_focus_color", type, BRIGHT)
		result.set_color("font_pressed_color", type, BRIGHT)
		result.set_color("font_hover_pressed_color", type, BRIGHT)
		result.set_color("font_disabled_color", type, DIM)
		result.set_stylebox("normal", type, box(Color(0,0,0,0), Color(BRASS,0.4), 0))
		result.set_stylebox("hover", type, box(Color(1,1,1,0.03), BRASS, 1))
		result.set_stylebox("pressed", type, box(Color(1,1,1,0.05), GOLD, 1))
		result.set_stylebox("disabled", type, box(Color(0,0,0,0), DIM, 0))
		result.set_stylebox("focus", type, box(Color(0,0,0,0), AMBER, 1))
	result.set_color("font_color", "Label", TEXT)
	var option = box(Color(LACQUER_HI,0.95), Color(BRASS,0.55), 1, 3)
	option.content_margin_left = 20
	option.content_margin_right = 30
	result.set_stylebox("normal","OptionButton",option)
	var option_hover = box(Color(LACQUER_HI.lightened(0.06),0.98), AMBER, 1, 3)
	option_hover.content_margin_left = 20
	option_hover.content_margin_right = 30
	result.set_stylebox("hover","OptionButton",option_hover)
	result.set_stylebox("pressed","OptionButton",option_hover)
	result.set_stylebox("focus","OptionButton",box(Color(0,0,0,0),AMBER,2,3))
	result.set_stylebox("disabled","OptionButton",box(Color(LACQUER,0.6),Color(DIM,0.5),1,3))
	result.set_font("font","OptionButton",Content.title_font)
	result.set_font_size("font_size","OptionButton",25)
	result.set_icon("arrow","OptionButton",_icon_arrow())
	result.set_color("font_color", "CheckButton", TEXT)
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		result.set_stylebox(state,"CheckButton",StyleBoxEmpty.new())
	for name in ["font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		result.set_color(name,"CheckButton",BRIGHT)
	result.set_stylebox("focus","CheckButton",box(Color(1,1,1,0.03),AMBER,1,3))
	result.set_icon("checked","CheckButton",_icon_toggle(true))
	result.set_icon("unchecked","CheckButton",_icon_toggle(false))
	result.set_icon("grabber","HSlider",load("res://ui/slider_seal.svg"))
	result.set_icon("grabber_highlight","HSlider",load("res://ui/slider_seal.svg"))
	result.set_stylebox("slider","HSlider",rail_box(Color("31444a")))
	result.set_stylebox("grabber_area","HSlider",rail_box(GOLD))
	result.set_stylebox("grabber_area_highlight","HSlider",rail_box(AMBER))
	result.set_stylebox("focus","HSlider",box(Color(0,0,0,0),Color(AMBER,0.7),1,3))
	result.set_stylebox("scroll","VScrollBar",rail_box(Color("23353c"),true))
	result.set_stylebox("grabber","VScrollBar",rail_box(BRASS,true))
	result.set_stylebox("grabber_highlight","VScrollBar",rail_box(AMBER,true))
	result.set_stylebox("grabber_pressed","VScrollBar",rail_box(AMBER,true))
	result.set_stylebox("background", "ProgressBar", bar_box(Color(0,0,0,0.45)))
	result.set_stylebox("fill", "ProgressBar", bar_box(JADE))
	var popup = box(Color("15252c"), BRASS, 1, 3)
	result.set_stylebox("panel", "PopupMenu", popup)
	result.set_stylebox("hover", "PopupMenu", box(Color(GOLD,0.35), Color(0,0,0,0), 0, 2))
	result.set_color("font_color", "PopupMenu", TEXT)
	result.set_color("font_hover_color", "PopupMenu", BRIGHT)
	result.set_font("font","PopupMenu",Content.body_font)
	result.set_font_size("font_size","PopupMenu",21)
	result.set_color("default_color","RichTextLabel",TEXT)
	result.set_stylebox("focus","RichTextLabel",box(Color(0,0,0,0),Color(AMBER,0.35),1,3))
	result.set_stylebox("panel","TooltipPanel",box(Color("15252c"),BRASS,1,3))
	result.set_color("font_color","TooltipLabel",TEXT)
	return result

static func _icon_toggle(on: bool) -> Texture2D:
	# A small lacquer toggle: a seal slides to the lit side.
	var image = Image.create(56,28,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	var rail = Color(GOLD,0.85) if on else Color("2a3b41")
	for x in range(56):
		for y in range(28):
			var dx = clampf(x,14,42)-x
			var d = sqrt(dx*dx+(y-14)*(y-14))
			if d <= 11.0: image.set_pixel(x,y,rail)
			elif d <= 12.5: image.set_pixel(x,y,Color(BRASS,0.7))
	var cx = 42 if on else 14
	for x in range(56):
		for y in range(28):
			var d = Vector2(x-cx,y-14).length()
			if d <= 8.0: image.set_pixel(x,y,BRIGHT if on else MUTED)
	return ImageTexture.create_from_image(image)

static func _icon_arrow() -> Texture2D:
	var image = Image.create(16,10,false,Image.FORMAT_RGBA8)
	image.fill(Color(0,0,0,0))
	for y in range(8):
		for x in range(y,16-y):
			if x>=y and x<16-y: image.set_pixel(x,y+1,AMBER)
	return ImageTexture.create_from_image(image)

static func box(fill: Color, border: Color, width: int = 1, radius: int = 0) -> StyleBoxFlat:
	var result = StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = border
	result.set_border_width_all(width)
	result.set_corner_radius_all(radius)
	result.content_margin_left = 18
	result.content_margin_right = 18
	result.content_margin_top = 12
	result.content_margin_bottom = 12
	return result

static func label(parent: Node, text: String, rect: Rect2, size: int = 21, color: Color = TEXT, serif: bool = false) -> Label:
	var node = Label.new()
	node.text = text
	node.position = rect.position
	node.clip_text = true
	node.add_theme_font_size_override("font_size", size)
	node.add_theme_color_override("font_color", color)
	if serif: node.add_theme_font_override("font", Content.title_font)
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func shadowed(node: Label, strength: float = 0.75) -> Label:
	node.add_theme_color_override("font_shadow_color",Color(0,0,0,strength))
	node.add_theme_constant_override("shadow_offset_x",0)
	node.add_theme_constant_override("shadow_offset_y",2)
	node.add_theme_constant_override("shadow_outline_size",6 if node.get_theme_font_size("font_size")>22 else 3)
	return node

static func paragraph(parent: Node, text: String, rect: Rect2, size: int = 21, color: Color = MUTED) -> Label:
	var node = label(parent,text,rect,size,color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size = rect.size
	node.add_theme_constant_override("line_spacing",4)
	return node

static func button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false, style: String = "") -> Button:
	var node = PrintButton.new()
	node.primary = primary
	node.style = style if not style.is_empty() else ("primary" if primary else "secondary")
	node.clip_text = true
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var left_pad = 46 if node.style=="menu" else 24
	for state in ["normal","hover","pressed","disabled","focus"]:
		var empty = StyleBoxEmpty.new()
		empty.content_margin_left = left_pad
		empty.content_margin_right = 26
		node.add_theme_stylebox_override(state,empty)
	if node.style=="menu": node.alignment = HORIZONTAL_ALIGNMENT_LEFT
	node.add_theme_font_override("font",Content.title_font)
	var font_size = 29 if rect.size.y>=57 else 25
	if node.style=="menu": font_size = 32 if rect.size.y>=54 else 28
	while font_size>17 and Content.title_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>rect.size.x-left_pad-40: font_size -= 1
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_disabled_color",DIM)
	if primary:
		for name in ["font_color","font_focus_color","font_hover_color","font_pressed_color","font_hover_pressed_color"]:
			node.add_theme_color_override(name,BRIGHT)
	elif node.style=="menu":
		node.add_theme_color_override("font_color",Color(TEXT,0.82))
	node.pressed.connect(func(): Sound.play("ui"); callback.call())
	node.size = rect.size
	parent.add_child(node)
	return node

static func seal(parent: Node, glyph: String, rect: Rect2, color: Color = GOLD) -> Control:
	var node = InkSeal.new()
	node.color = color
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	var text = label(node,glyph,Rect2(5,2,rect.size.x-10,rect.size.y-4),int(minf(rect.size.x,rect.size.y)*0.6),BRIGHT,true)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.clip_text = false
	return node

static func panel(parent: Node, rect: Rect2, border: Color = TEXT, alpha: float = 0.95) -> Panel:
	var node = PrintPaper.new()
	node.position = rect.position
	node.size = rect.size
	node.edge_color = border
	node.talisman = rect.size.x<500 and rect.size.y>200
	node.paper_color = Color(LACQUER,clampf(alpha,0.6,0.97))
	node.add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func image(parent: Node, texture: Texture2D, rect: Rect2) -> TextureRect:
	var node = TextureRect.new()
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.texture = texture
	node.position = rect.position
	node.size = rect.size
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func cover(parent: Node, texture: Texture2D, rect: Rect2 = Rect2(0,0,1600,900)) -> TextureRect:
	var node = image(parent,texture,rect)
	node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	return node

static func shade(parent: Node, color: Color = Color(NIGHT,0.9), rect: Rect2 = Rect2(0,0,1600,900)) -> ColorRect:
	var node = ColorRect.new()
	node.color = color
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func gradient(parent: Node, rect: Rect2, from: Color, to: Color, horizontal: bool = true) -> TextureRect:
	var g = Gradient.new()
	g.set_color(0,from); g.set_color(1,to)
	var tex = GradientTexture2D.new()
	tex.gradient = g
	tex.width = 64; tex.height = 64
	tex.fill_to = Vector2(1,0) if horizontal else Vector2(0,1)
	var node = TextureRect.new()
	node.texture = tex
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.stretch_mode = TextureRect.STRETCH_SCALE
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func rule(parent: Node, rect: Rect2, color: Color = BRASS) -> Control:
	# A brass hairline with a diamond in the middle — used as section divider.
	var node = Ornament.new()
	node.kind = "rule"
	node.color = color
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

static func heading(parent: Node, text: String, rect: Rect2, size: int = 25, color: Color = AMBER) -> Label:
	# Small-caps style section heading with a vermilion tick on the left.
	var tick = Ornament.new()
	tick.kind = "tick"
	tick.color = GOLD
	tick.position = rect.position+Vector2(0,rect.size.y*0.5-7)
	tick.size = Vector2(14,14)
	tick.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tick)
	return label(parent,text,Rect2(rect.position+Vector2(24,0),rect.size-Vector2(24,0)),size,color,true)

static func bar(parent: Node, rect: Rect2, color: Color) -> ProgressBar:
	var node = ProgressBar.new()
	node.position = rect.position
	node.size = rect.size
	node.show_percentage = false
	node.add_theme_stylebox_override("fill",bar_box(color))
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	node.size = rect.size
	return node

static func bar_box(color: Color) -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(0)
	return style

static func rail_box(color: Color, vertical: bool = false) -> StyleBoxFlat:
	var style = bar_box(color)
	# Slider and scrollbar themes derive track thickness from minimum size.
	# Progress bars instead use the explicit HUD rectangle.
	if vertical:
		style.content_margin_left = 3
		style.content_margin_right = 3
	else:
		style.content_margin_top = 3
		style.content_margin_bottom = 3
	return style

# ---------- motion ----------

static func reveal(node: CanvasItem, delay: float = 0.0, offset: Vector2 = Vector2(0,14), duration: float = 0.32) -> void:
	if not motion() or not is_instance_valid(node) or not node.is_inside_tree(): return
	var target = node.modulate.a
	node.modulate.a = 0.0
	var tween = node.create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	if node is Control and offset != Vector2.ZERO:
		var control = node as Control
		var final = control.position
		control.position = final+offset
		tween.set_parallel()
		tween.tween_property(control,"position",final,duration).set_delay(delay)
	tween.tween_property(node,"modulate:a",target,duration*0.8).set_delay(delay)

static func stagger(parent: Node, from_index: int = 0, step: float = 0.035, start: float = 0.0, max_delay: float = 0.45) -> void:
	# Fades in the children added after from_index, grouped by vertical position.
	if not motion(): return
	var children = parent.get_children().slice(from_index)
	for child in children:
		if child is CanvasItem and child.visible:
			var y = (child as Control).position.y if child is Control else 0.0
			reveal(child,minf(max_delay,start+y/900.0*step*12.0),Vector2(0,10),0.3)
