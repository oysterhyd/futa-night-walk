class_name UI
extends RefCounted

const TEXT = Color("183544")
const MUTED = Color("526161")
const GOLD = Color("ad3527")
const PARCHMENT = Color("e8dfc5")
const JADE = Color("3f6877")

static func theme() -> Theme:
	var result = Theme.new()
	result.default_font = Content.body_font
	result.default_font_size = 23
	for type in ["Button", "OptionButton"]:
		result.set_color("font_color", type, TEXT)
		result.set_color("font_hover_color", type, GOLD)
		result.set_color("font_focus_color", type, GOLD)
		result.set_color("font_pressed_color", type, GOLD)
		result.set_color("font_disabled_color", type, Color("8b8d80"))
		var normal = box(Color(0,0,0,0), TEXT, 0)
		normal.border_width_bottom = 1
		result.set_stylebox("normal", type, normal)
		result.set_stylebox("hover", type, box(Color(0.68,0.21,0.15,0.08), GOLD, 1))
		result.set_stylebox("pressed", type, box(Color(0.68,0.21,0.15,0.12), GOLD, 2))
		result.set_stylebox("disabled", type, box(Color(0,0,0,0), Color("989b8a"), 0))
		result.set_stylebox("focus", type, box(Color(0,0,0,0), GOLD, 2,0))
	result.set_color("font_color", "Label", TEXT)
	var option_paper = StyleBoxTexture.new()
	option_paper.texture = load("res://ui/paper_option.svg")
	option_paper.set_texture_margin_all(14)
	option_paper.content_margin_left = 20
	option_paper.content_margin_right = 24
	for state in ["normal","hover","pressed"]:
		result.set_stylebox(state,"OptionButton",option_paper)
	result.set_font("font","OptionButton",Content.title_font)
	result.set_font_size("font_size","OptionButton",27)
	result.set_color("font_color", "CheckButton", TEXT)
	for state in ["normal","hover","pressed","hover_pressed","disabled"]:
		result.set_stylebox(state,"CheckButton",StyleBoxEmpty.new())
	for name in ["font_hover_color","font_pressed_color","font_hover_pressed_color","font_focus_color"]:
		result.set_color(name,"CheckButton",GOLD)
	result.set_stylebox("focus","CheckButton",box(Color(0,0,0,0),GOLD,1))
	result.set_icon("checked","CheckButton",load("res://ui/mark_checked.svg"))
	result.set_icon("unchecked","CheckButton",load("res://ui/mark_unchecked.svg"))
	result.set_icon("grabber","HSlider",load("res://ui/slider_seal.svg"))
	result.set_icon("grabber_highlight","HSlider",load("res://ui/slider_seal.svg"))
	result.set_stylebox("slider","HSlider",rail_box(Color("7d887b")))
	result.set_stylebox("grabber_area","HSlider",rail_box(GOLD))
	result.set_stylebox("grabber_area_highlight","HSlider",rail_box(GOLD))
	result.set_stylebox("scroll","VScrollBar",rail_box(Color("c3c2a9"),true))
	result.set_stylebox("grabber","VScrollBar",rail_box(TEXT,true))
	result.set_stylebox("grabber_highlight","VScrollBar",rail_box(GOLD,true))
	result.set_stylebox("grabber_pressed","VScrollBar",rail_box(GOLD,true))
	result.set_stylebox("background", "ProgressBar", bar_box(Color("c3c2a9")))
	result.set_stylebox("fill", "ProgressBar", bar_box(JADE))
	result.set_stylebox("panel", "PopupMenu", box(PARCHMENT, TEXT, 1))
	result.set_color("font_color", "PopupMenu", TEXT)
	return result

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

static func paragraph(parent: Node, text: String, rect: Rect2, size: int = 21, color: Color = MUTED) -> Label:
	var node = label(parent,text,rect,size,color)
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.size = rect.size
	return node

static func button(parent: Node, text: String, rect: Rect2, callback: Callable, primary: bool = false) -> Button:
	var node = PrintButton.new()
	node.primary = primary
	node.clip_text = true
	node.text = text
	node.position = rect.position
	node.size = rect.size
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state in ["normal","hover","pressed","disabled","focus"]:
		var empty = StyleBoxEmpty.new()
		empty.content_margin_left = 24
		empty.content_margin_right = 26
		node.add_theme_stylebox_override(state,empty)
	node.add_theme_font_override("font",Content.title_font)
	var font_size = 29 if rect.size.y>=57 else 25
	while font_size>19 and Content.title_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x>rect.size.x-64: font_size -= 1
	node.add_theme_font_size_override("font_size",font_size)
	if primary:
		node.add_theme_color_override("font_disabled_color",MUTED)
		node.add_theme_color_override("font_color",PARCHMENT)
		node.add_theme_color_override("font_focus_color",PARCHMENT)
		node.add_theme_color_override("font_hover_color",PARCHMENT)
		node.add_theme_color_override("font_pressed_color",PARCHMENT)
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
	var text = label(node,glyph,Rect2(7,3,rect.size.x-14,rect.size.y-6),int(rect.size.y*0.59),PARCHMENT,true)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return node

static func panel(parent: Node, rect: Rect2, border: Color = TEXT, alpha: float = 0.95) -> Panel:
	var node = PrintPaper.new()
	node.position = rect.position
	node.size = rect.size
	node.edge_color = border
	node.talisman = rect.size.x<500 and rect.size.y>200
	node.paper_color = Color(PARCHMENT,maxf(alpha,0.98))
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
