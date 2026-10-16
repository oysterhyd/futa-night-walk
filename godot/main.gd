extends Node

const WORLD = preload("res://systems/campaign_world.gd")
const ARENA = preload("res://presentation/chapter_arena.gd")
const CHAPTER_UI = preload("res://ui/chapter_ui.gd")
var world: RunWorld
var arena: ArenaView
var ui_root: Control
var page: Control
var modal: Control
var backdrop: TextureRect
var menu_fog: ColorRect
var screen = "menu"
var paused = false
var choice_phase = ""
var autosave = 0.0
var notice_label: Label
var notice_time = 0.0
var labels: Dictionary = {}
var bars: Dictionary = {}
var selected_character = "keeper"
var selected_mode = "campaign"
var selected_difficulty = 0
var selected_contract = "none"
var last_result: Dictionary = {}
var elapsed = 0.0
var screenshot_path = ""
var finish_seen = false
var result_delay = 0.0
var controller_input = false
var intro_stage = 0
var attack_needs_release = true
var trigger_latched: Dictionary = {}
var story: StoryView
var ending_played = false
var wipe: ColorRect
var embers: CPUParticles2D
var backdrop_dim = 0.0

func _ready() -> void:
	DisplayServer.window_set_title("燃灯夜行 · 夜渡")
	get_tree().auto_accept_quit = false
	if Array(OS.get_cmdline_user_args()).any(func(arg): return arg.begins_with("--screenshot=") or arg=="--arena-preview"):
		Save.directory = "user://verification/"
		Save.load_profile()
	setup_input()
	if Save.profile.settings.fullscreen: DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	arena = ARENA.new()
	add_child(arena)
	var layer = CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	ui_root = Control.new()
	ui_root.size = Vector2(1600,900)
	ui_root.theme = UI.theme()
	ui_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(ui_root)
	var night = UI.shade(ui_root,Color("05090b"))
	night.name = "Night"
	backdrop = UI.cover(ui_root,StoryView.texture("title"))
	backdrop.pivot_offset = Vector2(800,450)
	backdrop.visibility_changed.connect(func(): night.visible = backdrop.visible)
	var fade = ColorRect.new()
	fade.name = "Fade"
	fade.size = Vector2(1600,900)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.material = ShaderMaterial.new()
	fade.material.shader = preload("res://shaders/menu_fade.gdshader")
	backdrop.add_child(fade)
	menu_fog = ColorRect.new()
	menu_fog.size = Vector2(1600,900)
	menu_fog.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_fog.material = ShaderMaterial.new()
	menu_fog.material.shader = preload("res://shaders/atmosphere.gdshader")
	menu_fog.material.set_shader_parameter("strength",0.05)
	menu_fog.material.set_shader_parameter("fog_color",Color("1d3540"))
	backdrop.add_child(menu_fog)
	embers = CPUParticles2D.new()
	embers.amount = 46
	embers.lifetime = 9
	embers.preprocess = 9
	embers.position = Vector2(800,940)
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(820,20)
	embers.direction = Vector2(0.15,-1)
	embers.spread = 18
	embers.gravity = Vector2(6,0)
	embers.initial_velocity_min = 28
	embers.initial_velocity_max = 70
	embers.scale_amount_min = 1.2
	embers.scale_amount_max = 3.2
	var ember_fade = Gradient.new()
	ember_fade.set_color(0,Color(1,0.75,0.4,0.0))
	ember_fade.add_point(0.15,Color(1,0.72,0.36,0.9))
	ember_fade.set_color(ember_fade.get_point_count()-1,Color(0.9,0.3,0.15,0.0))
	embers.color_ramp = ember_fade
	backdrop.add_child(embers)
	page = Control.new()
	page.size = Vector2(1600,900)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(page)
	modal = Control.new()
	modal.size = Vector2(1600,900)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(modal)
	var wipe_layer = CanvasLayer.new()
	wipe_layer.layer = 20
	add_child(wipe_layer)
	wipe = ColorRect.new()
	wipe.size = Vector2(1600,900)
	wipe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wipe.material = ShaderMaterial.new()
	wipe.material.shader = preload("res://shaders/ink_wipe.gdshader")
	wipe.visible = false
	wipe_layer.add_child(wipe)
	show_menu()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="): screenshot_path = arg.trim_prefix("--screenshot=")
		if arg == "--arena-preview": start_run({"seed": 4242,"choose_oath":false})
	if not screenshot_path.is_empty(): capture_later()

func setup_input() -> void:
	var keys = {"move_left": [KEY_A,KEY_LEFT], "move_right": [KEY_D,KEY_RIGHT], "move_up": [KEY_W,KEY_UP], "move_down": [KEY_S,KEY_DOWN], "dash": [KEY_SPACE], "pulse": [KEY_Q], "interact": [KEY_E], "pause": [KEY_ESCAPE], "inventory": [KEY_B], "map": [KEY_TAB], "ignite": [KEY_F], "attack": [], "aim_left": [], "aim_right": [], "aim_up": [], "aim_down": [], "fullscreen": [KEY_F11]}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in keys[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)
	var buttons = {"dash": JOY_BUTTON_A, "pulse": JOY_BUTTON_X, "interact": JOY_BUTTON_Y, "pause": JOY_BUTTON_START, "inventory": JOY_BUTTON_BACK, "map": JOY_BUTTON_LEFT_SHOULDER, "ignite": JOY_BUTTON_RIGHT_STICK}
	for action in buttons:
		var event = InputEventJoypadButton.new()
		event.device = -1
		event.button_index = buttons[action]
		InputMap.action_add_event(action,event)
	for mapping in [["move_left",JOY_AXIS_LEFT_X,-1.0],["move_right",JOY_AXIS_LEFT_X,1.0],["move_up",JOY_AXIS_LEFT_Y,-1.0],["move_down",JOY_AXIS_LEFT_Y,1.0]]:
		var event = InputEventJoypadMotion.new()
		event.device = -1
		event.axis = mapping[1]
		event.axis_value = mapping[2]
		InputMap.action_add_event(mapping[0],event)
	for action in ["move_left","move_right","move_up","move_down"]: InputMap.action_set_deadzone(action,0.2)
	for spec in [["ui_accept",JOY_BUTTON_A],["ui_cancel",JOY_BUTTON_B],["ui_left",JOY_BUTTON_DPAD_LEFT],["ui_right",JOY_BUTTON_DPAD_RIGHT],["ui_up",JOY_BUTTON_DPAD_UP],["ui_down",JOY_BUTTON_DPAD_DOWN]]:
		var event = InputEventJoypadButton.new()
		event.device = -1
		event.button_index = spec[1]
		if not InputMap.action_has_event(spec[0],event): InputMap.action_add_event(spec[0],event)
	for spec in [["ui_left",JOY_AXIS_LEFT_X,-1.0],["ui_right",JOY_AXIS_LEFT_X,1.0],["ui_up",JOY_AXIS_LEFT_Y,-1.0],["ui_down",JOY_AXIS_LEFT_Y,1.0]]:
		var event = InputEventJoypadMotion.new()
		event.device = -1
		event.axis = spec[1]
		event.axis_value = spec[2]
		if not InputMap.action_has_event(spec[0],event): InputMap.action_add_event(spec[0],event)
	for spec in [["move_left",JOY_BUTTON_DPAD_LEFT],["move_right",JOY_BUTTON_DPAD_RIGHT],["move_up",JOY_BUTTON_DPAD_UP],["move_down",JOY_BUTTON_DPAD_DOWN]]:
		var event = InputEventJoypadButton.new()
		event.device = -1
		event.button_index = spec[1]
		InputMap.action_add_event(spec[0],event)
	var right = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	InputMap.action_add_event("pulse",right)
	var left = InputEventMouseButton.new()
	left.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event("attack",left)
	for spec in [["attack",JOY_AXIS_TRIGGER_RIGHT],["dash",JOY_AXIS_TRIGGER_LEFT]]:
		var trigger = InputEventJoypadMotion.new()
		trigger.device = -1; trigger.axis = spec[1]; trigger.axis_value = 1.0
		InputMap.action_add_event(spec[0],trigger)
	var shoulder = InputEventJoypadButton.new()
	shoulder.device = -1; shoulder.button_index = JOY_BUTTON_RIGHT_SHOULDER
	InputMap.action_add_event("pulse",shoulder)
	for mapping in [["aim_left",JOY_AXIS_RIGHT_X,-1.0],["aim_right",JOY_AXIS_RIGHT_X,1.0],["aim_up",JOY_AXIS_RIGHT_Y,-1.0],["aim_down",JOY_AXIS_RIGHT_Y,1.0]]:
		var event = InputEventJoypadMotion.new()
		event.device = -1; event.axis = mapping[1]; event.axis_value = mapping[2]
		InputMap.action_add_event(mapping[0],event)
		InputMap.action_set_deadzone(mapping[0],0.2)

func clear_control(control: Control) -> void:
	for node in control.get_children():
		control.remove_child(node)
		node.queue_free()

func shell(name: String, sub: String = "") -> void:
	clear_control(page)
	clear_control(modal)
	labels.clear()
	bars.clear()
	set_backdrop(StoryView.texture("title"),0.0 if name.is_empty() else 0.8)
	if not name.is_empty():
		UI.gradient(page,Rect2(0,0,1600,230),Color(0.02,0.04,0.05,0.75),Color(0.02,0.04,0.05,0.0),false)
		UI.label(page,"燃灯夜行  ·  夜渡",Rect2(80,38,600,30),19,Color(UI.AMBER,0.85),true)
		var head = UI.label(page,name,Rect2(78,74,1200,72),50,UI.BRIGHT,true)
		UI.shadowed(head)
		UI.paragraph(page,sub,Rect2(82,150,1250,60),20,UI.MUTED)
		UI.button(page,"返回渡口",Rect2(1330,40,190,50),show_menu)
	backdrop.visible = true
	arena.visible = false
	arena.post.visible = false
	Sound.play_music("night")
	transition()

func set_backdrop(texture: Texture2D, dim: float) -> void:
	backdrop.texture = texture
	backdrop_dim = dim
	var fade: ColorRect = backdrop.get_node("Fade")
	fade.material.set_shader_parameter("base",dim)
	fade.material.set_shader_parameter("left_strength",0.0 if dim>0.0 else 0.9)
	embers.emitting = Save.profile.settings.particles
	embers.visible = Save.profile.settings.particles

func transition() -> void:
	# Ink washes off the new screen: a short dissolve from black.
	if not UI.motion() or wipe == null: return
	wipe.visible = true
	wipe.material.set_shader_parameter("progress",0.0)
	var tween = wipe.create_tween()
	tween.tween_method(func(v): wipe.material.set_shader_parameter("progress",v),0.0,1.0,0.5).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tween.tween_callback(func(): wipe.visible = false)

func show_menu() -> void:
	screen = "menu"
	paused = false
	shell("", "")
	clear_control(page)
	var night = Lore.night_number(Save.profile)
	UI.label(page,"长夜  ·  第 %s 夜" % _numeral(night),Rect2(100,74,500,32),22,UI.AMBER,true)
	var title_art = CarvedTitle.new()
	title_art.position = Vector2(96,112)
	title_art.size = Vector2(540,150)
	title_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(title_art)
	UI.seal(page,"夜渡",Rect2(102,282,140,58))
	UI.label(page,"国风动作肉鸽",Rect2(260,296,300,30),19,UI.MUTED)
	var tagline = UI.paragraph(page,Lore.TAGLINE,Rect2(104,362,620,90),26,UI.TEXT)
	UI.shadowed(tagline)
	var y = 478
	var entries = [["启程夜行",show_prepare],["继续对局",resume_run],["渡口茶摊",show_camp],["夜行手记",show_journal],["设置",func(): show_settings(false)],["退出游戏",exit_game]]
	for entry in entries:
		var item = UI.button(page,entry[0],Rect2(96,y,360,54),entry[1],false,"menu")
		if entry[0]=="继续对局": item.disabled = Save.read_run().is_empty()
		y += 56
	UI.label(page,"灯烬 %d    ·    已夜行 %d 次" % [Save.profile.embers,Save.profile.settled.size()],Rect2(100,830,650,30),17,UI.MUTED)
	var version = UI.label(page,"v"+str(ProjectSettings.get_setting("application/config/version","")),Rect2(1380,846,190,26),15,Color(UI.MUTED,0.6))
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	UI.stagger(page,0,0.05,0.05)
	focus_first()

func _numeral(value: int) -> String:
	var digits = ["零","一","二","三","四","五","六","七","八","九"]
	if value < 10: return digits[value]
	if value < 20: return "十"+(digits[value%10] if value%10>0 else "")
	if value < 100: return digits[value/10]+"十"+(digits[value%10] if value%10>0 else "")
	return str(value)

func show_prepare() -> void:
	screen = "prepare"
	if selected_mode=="daily":
		selected_character = "keeper"
		selected_difficulty = 0
		selected_contract = "none"
	shell("选一位夜行者","从灯市走到无明塔，四章一路打上去。拿到的东西整局都在。")
	var i = 0
	for key in Content.data.characters:
		var char_def = Content.data.characters[key]
		var lore = Lore.CHARACTERS.get(key,{})
		var unlocked = Save.profile.bosses >= char_def.unlock
		var chosen = selected_character == key
		var x = 80 + i*490
		var card = UI.panel(page,Rect2(x,222,460,418),UI.GOLD if chosen else UI.TEXT)
		card.modulate = Color.WHITE if unlocked else Color(0.62,0.64,0.66)
		UI.panel(page,Rect2(x+20,240,150,150),Color(UI.BRASS),0.7)
		var portrait = UI.image(page,Content.sprite(int(char_def.sprite)),Rect2(x+24,244,142,142))
		if not unlocked: portrait.modulate = Color(0.25,0.28,0.3)
		UI.label(page,char_def.name,Rect2(x+188,248,250,48),38,UI.BRIGHT,true)
		UI.label(page,lore.get("title",""),Rect2(x+190,298,250,26),18,UI.AMBER)
		UI.paragraph(page,lore.get("style",""),Rect2(x+190,330,250,60),16,UI.MUTED)
		UI.paragraph(page,lore.get("story",""),Rect2(x+24,404,412,80),18,UI.TEXT)
		UI.rule(page,Rect2(x+24,490,412,12))
		UI.label(page,"燃灯 · "+lore.get("ultimate",""),Rect2(x+24,508,412,32),22,UI.AMBER,true)
		UI.paragraph(page,lore.get("ultimate_desc",""),Rect2(x+24,544,412,84),16,UI.TEXT)
		var button = UI.button(page,"已出战" if chosen else ("选定出战" if unlocked else "击败 %d 位首领解锁" % char_def.unlock),Rect2(x+30,652,400,50),func(): selected_character = key; show_prepare(),chosen)
		button.disabled = not unlocked or selected_mode=="daily"
		i += 1
	UI.heading(page,"游戏模式",Rect2(80,716,200,30),19)
	option(["四章夜行","每日挑战"],Rect2(80,752,300,52),["campaign","daily"].find(selected_mode),func(index): selected_mode = ["campaign","daily"][index]; show_prepare())
	UI.heading(page,"难度",Rect2(410,716,200,30),19)
	option(["难度一 · 寻常","难度二 · 险途","难度三 · 恶刹","难度四 · 绝境"],Rect2(410,752,270,52),selected_difficulty,func(index): selected_difficulty = index).disabled = selected_mode=="daily"
	UI.heading(page,"契约",Rect2(710,716,200,30),19)
	option(["不立契","百鬼夜涌","命如悬丝","枯泉禁疗"],Rect2(710,752,290,52),["none","swarm","fragile","silence"].find(selected_contract),func(index): selected_contract = ["none","swarm","fragile","silence"][index]).disabled = selected_mode=="daily"
	UI.button(page,"启程出发    →",Rect2(1170,746,350,62),request_start,true)
	UI.paragraph(page,"每日挑战固定提灯人、难度一、不立契，营地加成不生效。" if selected_mode == "daily" else "WASD 移动  ·  左键 攻击  ·  右键 技能  ·  空格 闪避  ·  F 燃灯  ·  E 交互  ·  Tab 地图",Rect2(80,830,1250,40),18)
	UI.stagger(page,0,0.035)
	focus_first()

func option(items: Array, rect: Rect2, selected: int, callback: Callable) -> OptionButton:
	var node = OptionButton.new()
	node.position = rect.position
	node.size = rect.size
	for item in items: node.add_item(item)
	node.select(selected)
	node.item_selected.connect(callback)
	page.add_child(node)
	return node

func request_start() -> void:
	if not Save.read_run().is_empty():
		modal_base("已有进行中的对局","开始新的夜行将会覆盖当前未完成的对局存档。")
		UI.button(modal,"覆盖并开始",Rect2(480,570,300,60),launch_selected,true)
		UI.button(modal,"保留旧存档",Rect2(820,570,300,60),func(): clear_control(modal); focus_first())
		focus_first(modal)
	else: launch_selected()

func launch_selected() -> void:
	var options = {"character": selected_character, "mode": selected_mode, "difficulty": selected_difficulty, "contract": selected_contract, "camp": Save.profile.camp}
	if selected_mode == "daily":
		var datetime = Time.get_datetime_dict_from_unix_time(int(Time.get_unix_time_from_system()) + 8*3600)
		options.seed = int(datetime.year)*10000+int(datetime.month)*100+int(datetime.day)
		options.character = "keeper"
		options.difficulty = 0
		options.contract = "none"
	start_run(options)

func start_run(options: Dictionary) -> void:
	attack_needs_release = true
	intro_stage = 0
	finish_seen = false
	ending_played = false
	result_delay = 0.0
	world = WORLD.new()
	if not options.has("choose_oath"): options["choose_oath"] = true
	world.begin(options)
	arena.bind(world)
	screen = "run"
	paused = false
	choice_phase = ""
	autosave = 0
	show_hud()
	Save.save_run(world)
	if not Save.profile.get("story_seen",false) and screenshot_path.is_empty() and options.choose_oath and options.get("mode","campaign")=="campaign":
		intro_stage = world.stage
		var panels: Array = Lore.PROLOGUE.duplicate()
		if Lore.PROLOGUE_CHARACTER.has(world.character): panels.append(Lore.PROLOGUE_CHARACTER[world.character])
		panels.append(Lore.PROLOGUE_END)
		play_story(panels,"","序  ·  冬至夜",func():
			Save.profile.story_seen = true
			Save.save_profile()
			intro_stage = 0
			after_intro())
	else: after_intro()

func after_intro() -> void:
	if not Save.profile.tutorial_seen and screenshot_path.is_empty(): show_tutorial()
	else:
		paused = false
		update_phase()

func play_story(panels: Array, last: String, title: String, done: Callable) -> void:
	paused = true
	clear_control(modal)
	story = StoryView.new()
	modal.add_child(story)
	story.setup(panels,last,title)
	var skip = UI.button(modal,"跳过  ›",Rect2(1390,34,170,48),func(): if story: story.skip())
	skip.focus_mode = Control.FOCUS_NONE
	story.finished.connect(func():
		story = null
		clear_control(modal)
		done.call(), CONNECT_ONE_SHOT)
	if UI.motion(): UI.reveal(story,0.0,Vector2.ZERO,0.5)

func resume_run() -> void:
	attack_needs_release = true
	var candidate = WORLD.new()
	if not candidate.restore(Save.read_run()):
		modal_base("对局存档无法恢复","存档数据不兼容或文件损坏，已为你保留原始文件。")
		UI.button(modal,"返回",Rect2(620,580,360,58),func(): clear_control(modal))
		return
	world = candidate
	intro_stage = 1
	finish_seen = false
	result_delay = 0.0
	arena.bind(world)
	screen = "run"
	paused = false
	choice_phase = ""
	autosave = 0
	show_hud()
	update_phase()

func show_hud() -> void:
	if world is ChapterWorld: CHAPTER_UI.show_hud(self); return
	clear_control(page)
	clear_control(modal)
	labels.clear()
	bars.clear()
	backdrop.visible = false
	arena.visible = true
	arena.post.visible = true
	Sound.play_music("battle")
	UI.panel(page,Rect2(35,26,460,101),Color("486053"),0.88)
	labels.chapter = UI.label(page,"",Rect2(57,40,420,38),25,UI.TEXT,true)
	labels.subtitle = UI.label(page,"",Rect2(58,83,420,28),17,UI.MUTED)
	UI.panel(page,Rect2(1265,26,300,101),Color("486053"),0.88)
	labels.counters = UI.label(page,"",Rect2(1290,43,250,66),19,UI.TEXT)
	UI.panel(page,Rect2(35,803,360,73),Color("486053"),0.95)
	labels.hp = UI.label(page,"",Rect2(52,811,315,28),18,UI.TEXT)
	bars.hp = UI.bar(page,Rect2(52,849,315,10),Color("ad3527"))
	for i in range(4):
		var x = 430+i*122
		UI.panel(page,Rect2(x,803,112,74))
		labels["skill%d" % i] = UI.label(page,"",Rect2(x+8,809,96,29),18,UI.TEXT)
		labels["lv%d" % i] = UI.label(page,"",Rect2(x+8,841,96,24),15,UI.GOLD)
	labels.dash_button = UI.button(page,"空格 · 闪避",Rect2(975,803,180,73),func(): if not paused: world.dash(movement()))
	labels.pulse_button = UI.button(page,"Q · 镇魂",Rect2(1170,803,180,73),func(): if not paused: world.pulse())
	labels.pause_button = UI.button(page,"暂停",Rect2(1370,803,195,73),show_pause)
	bars.xp = UI.bar(page,Rect2(36,785,1528,5),Color("396376"))
	labels.abilities = UI.label(page,"",Rect2(977,761,550,30),16,UI.TEXT)
	UI.panel(page,Rect2(565,35,470,65),Color("805b4c"),0.92).name = "BossPanel"
	labels.boss = UI.label(page,"",Rect2(580,42,440,29),20,UI.GOLD,true)
	bars.boss = UI.bar(page,Rect2(580,80,440,7),Color("ad3527"))
	page.get_node("BossPanel").visible = false
	labels.boss.visible = false
	bars.boss.visible = false
	notice_label = UI.label(page,"",Rect2(400,145,800,48),24,UI.GOLD,true)
	notice_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	labels.combo = UI.label(page,"",Rect2(1370,145,170,40),24,UI.GOLD)
	for button in page.get_children():
		if button is Button: button.focus_mode = Control.FOCUS_NONE
	update_hud()

func update_hud() -> void:
	if world is ChapterWorld: CHAPTER_UI.update_hud(self); return
	if world == null or labels.is_empty() or not labels.has("hp"): return
	labels.chapter.text = "%s  /  %s" % [world.biome().chapter,world.biome().name]
	labels.subtitle.text = "等级 %d级   ·   %02d:%02d   ·   %s" % [world.level,int(world.time)/60,int(world.time)%60,"首领现身！" if world.boss_spawned else "倒计时 %d 秒" % maxi(0,75-int(world.sector_time))]
	labels.counters.text = "斩祟  %d\n铜钱  %d    难度 %d" % [world.kills,world.coins,world.difficulty+1]
	labels.hp.text = "生命值    %d / %d" % [maxi(0,int(world.player.hp)),int(world.player.max_hp)]
	for spec in [["dash_button","A · 闪避" if controller_input else "空格 · 闪避"],["pulse_button","X · 镇魂" if controller_input else "Q · 镇魂"],["pause_button","Start · 暂停" if controller_input else "暂停"]]:
		if labels[spec[0]].text!=spec[1]:
			labels[spec[0]].text = spec[1]
			labels[spec[0]].add_theme_font_size_override("font_size",21 if controller_input else 23)
	arena.interact_hint = "按住 Y · 祭灯" if controller_input else "长按 E · 点灯"
	bars.hp.value = world.player.hp/world.player.max_hp*100
	bars.xp.value = world.xp/world.xp_next*100
	labels.abilities.text = "闪避 %s   ·   镇魂充能 %d / 30" % ["就绪" if world.player.dash_cd <= 0 else "%.1f秒" % world.player.dash_cd,int(world.charge)]
	labels.combo.text = "%d 连击" % world.combo if world.combo >= 5 else ""
	var i = 0
	for key in world.weapons:
		labels["skill%d" % i].text = Content.skills[key].name
		labels["lv%d" % i].text = "进阶" if key in world.evolved else "%d 级" % world.weapons[key]
		i += 1
	while i < 4:
		labels["skill%d" % i].text = "未习得"
		labels["lv%d" % i].text = "空槽"
		i += 1
	var bosses = world.mobs.filter(func(m): return m.boss and m.hp > 0)
	var has_boss = not bosses.is_empty()
	Sound.battle_state(world.stage,has_boss,paused,world.phase!="active")
	page.get_node("BossPanel").visible = has_boss
	labels.boss.visible = has_boss
	bars.boss.visible = has_boss
	if has_boss:
		labels.boss.text = world.biome().boss + ("  ·  狂暴" if bosses[0].enraged else "")
		bars.boss.value = bosses[0].hp/bosses[0].max_hp*100
	if is_instance_valid(notice_label):
		notice_label.visible = notice_time > 0
		notice_label.modulate.a = minf(1,notice_time)
	if world.phase=="active" and not paused and intro_stage!=world.stage: show_chapter_banner()

func show_chapter_banner() -> void:
	intro_stage = world.stage
	if labels.has("seal"):
		var numeral: Label = labels.seal.get_child(0)
		numeral.text = Lore.CHAPTERS[clampi(world.stage-1,0,3)].numeral
	var card = StoryView.ChapterCard.new()
	card.setup(world.stage)
	page.add_child(card)

func modal_base(title: String, subtitle: String = "") -> void:
	clear_control(modal)
	var dim = UI.shade(modal,Color(0.02,0.04,0.05,0.72))
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.panel(modal,Rect2(365,250,870,420))
	var head = UI.label(modal,title,Rect2(410,290,780,62),40,UI.BRIGHT,true)
	UI.shadowed(head)
	UI.rule(modal,Rect2(410,356,240,12))
	UI.paragraph(modal,subtitle,Rect2(412,376,780,130),21,UI.TEXT)

func show_tutorial() -> void:
	if world is ChapterWorld: CHAPTER_UI.show_tutorial(self); return
	paused = true
	modal_base("新手操作指南","符术将自动朝敌群施放，熟练走位是生存通关的关键。\nWASD / 左摇杆：控制移动    空格 / A：冲刺闪避\nQ / X：释放镇魂绝技，大范围消弹击退    E / Y：长按点亮神灯\nB / View：查看当前行囊与属性    Esc / Start：暂停对局\n【元素反应】火 + 霜：融霜额外伤害    火 + 毒：燃瘴范围爆燃    雷 + 霜/水：引雷传导麻痹")
	for node in modal.get_children():
		if node is Label and node.text.begins_with("符术将自动"): node.size.y = 174
	UI.button(modal,"掌握要领，开始战斗！",Rect2(520,580,560,60),func(): Save.profile.tutorial_seen = true; Save.save_profile(); paused = false; clear_control(modal),true)
	focus_first(modal)

func show_pause() -> void:
	if screen != "run" or world.phase=="finished" or story != null: return
	paused = true
	modal_base("夜行暂歇","进度已经存下了。随时可以离开，下次从这个房间接着走。")
	if world is ChapterWorld:
		var tip = Lore.BOSSES[clampi(world.stage-1,0,3)]
		UI.label(modal,"沈婆说 · "+tip.name,Rect2(412,430,500,26),17,UI.AMBER,true)
		UI.paragraph(modal,"「"+tip.tip+"」",Rect2(412,456,780,30),18,UI.MUTED)
	UI.button(modal,"继续战斗",Rect2(420,508,360,57),close_pause,true)
	UI.button(modal,"查看行囊",Rect2(820,508,360,57),show_inventory)
	UI.button(modal,"声音与画面",Rect2(420,585,360,57),func(): show_settings(true))
	UI.button(modal,"保存并退出",Rect2(820,585,360,57),save_to_menu)
	UI.stagger(modal,1,0.03)
	focus_first(modal)

func close_pause() -> void:
	attack_needs_release = true
	paused = false
	choice_phase = ""
	clear_control(modal)
	update_phase()

func save_to_menu() -> void:
	if world.phase=="finished":
		last_result = Save.settle(world)
		if last_result.has("save_error"): show_settlement_error()
		else: show_menu()
		return
	if Save.save_run(world): show_menu()
	else: UI.paragraph(modal,Save.error,Rect2(420,612,760,40),18,UI.GOLD)

func show_inventory() -> void:
	if world is ChapterWorld: CHAPTER_UI.show_inventory(self); return
	if world == null: return
	paused = true
	modal_base("行囊 · 当前所学")
	clear_control(modal)
	var dim = ColorRect.new()
	dim.color = Color(UI.PARCHMENT,0.97)
	dim.size = Vector2(1600,900)
	modal.add_child(dim)
	UI.label(modal,"行囊 · 当前所学",Rect2(85,65,1100,65),42,UI.TEXT,true)
	UI.label(modal,"符术与进阶",Rect2(85,170,640,40),24,UI.GOLD)
	if world.oath!="none": UI.label(modal,Content.data.oaths[world.oath].name,Rect2(850,95,530,45),24,UI.JADE,true)
	var y = 230
	for key in world.weapons:
		var recipe = Content.data.evolutions.get(key,{})
		UI.panel(modal,Rect2(85,y,660,115))
		UI.label(modal,Content.skills[key].name+"   %d级" % world.weapons[key],Rect2(110,y+10,610,33),24,Content.color_for(key),true)
		UI.paragraph(modal,Content.data.spell_text[key],Rect2(110,y+50,610,34),18)
		if not recipe.is_empty(): UI.label(modal,"进阶需求：5级 + "+Content.data.passives[recipe.passive].name+" → "+recipe.name,Rect2(110,y+83,610,25),16,UI.GOLD)
		y += 135
	UI.label(modal,"秘卷与遗物",Rect2(825,170,640,40),24,UI.GOLD)
	var inventory_text = "[color=#ad3527]秘卷（被动强化）[/color]\n"
	for key in world.passives:
		var item = Content.data.passives[key]
		inventory_text += "[color=#183544]%s · %d级[/color]\n%s\n\n" % [item.name,world.passives[key],item.desc]
	if world.passives.is_empty(): inventory_text += "暂未习得秘卷。\n\n"
	inventory_text += "[color=#ad3527]遗物（常驻增益）[/color]\n"
	for key in world.relics:
		var item = Content.data.relics[key]
		inventory_text += "[color=#183544]%s[/color]\n%s\n\n" % [item.name,item.desc]
	if world.relics.is_empty(): inventory_text += "暂未持有遗物。"
	var details = RichTextLabel.new()
	details.bbcode_enabled = true
	details.text = inventory_text
	details.position = Vector2(830,230)
	details.size = Vector2(655,540)
	details.add_theme_font_override("normal_font",Content.body_font)
	details.add_theme_font_size_override("normal_font_size",20)
	details.add_theme_color_override("default_color",UI.MUTED)
	details.focus_mode = Control.FOCUS_ALL
	modal.add_child(details)
	UI.button(modal,"返回战斗",Rect2(1180,805,320,55),close_pause,true)
	focus_first(modal)

func show_choices() -> void:
	if world is ChapterWorld: CHAPTER_UI.show_choices(self); return
	clear_control(modal)
	var dim = ColorRect.new()
	dim.color = Color(UI.PARCHMENT,0.96)
	dim.size = Vector2(1600,900)
	modal.add_child(dim)
	var is_route = world.phase == "route"
	var title = {"route":"前路分岔 · 抉择路线","upgrade":"研习道法 · 技能升级","oath":"立誓立愿 · 抉择誓约","relic":"偶遇机缘 · 选取遗物","relic_replace":"遗物栏已满 · 遗物替换"}.get(world.phase,"研习道法 · 技能升级")
	var subtitle = {"route":"挑选下一阶段的遭遇，不同路线机缘各异。","oath":"誓愿将改变整场对局规则，收益与代价并存。","relic":"遗物最多携带 4 件，挑选能够补强核心套路的宝物。","relic_replace":"选择需要丢弃的旧遗物，换入新遗物："+Content.data.relics.get(world.pending_replacement,{}).get("name","")}.get(world.phase,"等级提升至 %d级 · 挑选一项升级增益" % world.level)
	UI.label(modal,title,Rect2(100,145,1400,80),46,UI.TEXT,true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	UI.label(modal,subtitle,Rect2(100,235,1400,45),22,UI.MUTED).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var pool = world.routes if is_route else world.choices
	var width = 330 if pool.size()==4 else 430
	var stride = 360 if pool.size()==4 else 460
	var left = 85 if pool.size()==4 else 120
	for i in range(pool.size()):
		var x = left+i*stride
		var info: Dictionary
		if is_route:
			var route = Content.route(pool[i])
			info = {"name": route.name, "tag": route.tag, "desc": route.effect, "glyph": route.glyph, "note": route.text, "color": UI.GOLD}
		else: info = Content.choice_info(pool[i],world)
		UI.panel(modal,Rect2(x,320,width,360),info.color)
		UI.label(modal,info.tag,Rect2(x+24,340,width-48,36),17,info.color)
		UI.seal(modal,info.glyph,Rect2(x+24,387,88,88),info.color)
		UI.label(modal,info.name,Rect2(x+24,490,width-48,43),27,UI.TEXT,true)
		UI.paragraph(modal,info.desc,Rect2(x+24,548,width-48,80),19,UI.TEXT)
		UI.paragraph(modal,info.note,Rect2(x+24,635,width-48,43),16,UI.MUTED)
		var button = UI.button(modal,"%d   选择" % (i+1),Rect2(x,700,width,58),func(): select_choice(i),i == 0)
		button.disabled = is_route and not world.route_available(pool[i])
	if world.phase=="relic_replace": UI.button(modal,"保留现有遗物 · 将新遗物折算为 30 铜钱",Rect2(510,792,580,52),func(): select_choice(-1))
	if world.phase=="upgrade":
		var reroll = UI.button(modal,"刷新候选 · 剩余 %d 次  [R]" % world.rerolls,Rect2(610,792,380,52),func(): if world.reroll(): show_choices(); Save.save_run(world))
		reroll.disabled = world.rerolls <= 0
	focus_first(modal)

func select_choice(index: int) -> void:
	var changed = false
	if world.phase == "route" and index >= 0 and index < world.routes.size(): changed = world.take_route(world.routes[index])
	elif world.phase == "upgrade": changed = world.choose(index)
	elif world.phase == "oath": changed = world.choose_oath(index)
	elif world.phase in ["relic","relic_replace"]: changed = world.choose_relic(index)
	if changed:
		attack_needs_release = true
		Sound.play("ui")
		Save.save_run(world)
		choice_phase = ""
		clear_control(modal)
		update_phase()

func update_phase() -> void:
	if screen != "run" or paused: return
	if world.phase == "finished":
		if not finish_seen:
			finish_seen = true
			result_delay = 1.6 if world.victory else 1.1
			notice("长明灯亮了。" if world.victory else "灯火熄了。")
			return
		if result_delay > 0: return
		last_result = Save.settle(world)
		if last_result.has("save_error"):
			show_settlement_error()
			return
		if world.victory and world is CampaignWorld and not ending_played and screenshot_path.is_empty():
			ending_played = true
			var panels: Array = Lore.ENDING.duplicate()
			panels.append({"image":"dawn","lines":[Lore.ENDING_CHARACTER.get(world.character,"")]})
			play_story(panels,Lore.ENDING_LAST,"终  ·  天亮以后",func(): paused = false; show_result())
			return
		show_result()
	elif world.phase in ["upgrade","route","oath","relic","relic_replace"]:
		if choice_phase != world.phase:
			choice_phase = world.phase
			show_choices()
	elif choice_phase != "":
		choice_phase = ""
		clear_control(modal)

func show_result() -> void:
	if world is ChapterWorld: CHAPTER_UI.show_result(self); return
	screen = "result"
	paused = false
	shell("对局胜利 · 破晓凯旋" if world.victory else "对局结束 · 战败结算","本局斩妖所收集的灯烬，可用于在营地强化永久天赋。")
	UI.panel(page,Rect2(85,240,570,440),UI.GOLD)
	UI.label(page,"+ %d" % last_result.get("reward_total",last_result.reward),Rect2(120,270,490,100),70,UI.GOLD,true)
	UI.label(page,"获取灯烬",Rect2(125,370,460,45),26,UI.TEXT)
	if last_result.get("achievement_reward",0)>0: UI.label(page,"含成就达成奖励 %d 灯烬" % last_result.achievement_reward,Rect2(125,417,460,30),19,UI.MUTED)
	UI.paragraph(page,"消灭妖魔 %d    击杀首领 %d\n角色等级 %d级    存活时间 %02d:%02d\n到达关卡 %s" % [world.kills,world.bosses,world.level,int(world.time)/60,int(world.time)%60,world.biome().name],Rect2(125,450,490,155),25,UI.TEXT)
	UI.label(page,"符术伤害统计",Rect2(735,245,730,45),27,UI.GOLD,true)
	var damage_keys = world.damage_by_skill.keys()
	damage_keys.sort_custom(func(a,b): return world.damage_by_skill[a] > world.damage_by_skill[b])
	var y = 310
	for key in damage_keys.slice(0,7):
		var title = Content.skills[key].name if Content.skills.has(key) else ("镇魂" if key == "pulse" else key.trim_prefix("reaction:"))
		UI.label(page,title,Rect2(738,y,380,36),22)
		UI.label(page,str(int(world.damage_by_skill[key])),Rect2(1190,y,250,36),22,UI.GOLD)
		y += 48
	var reactions = ""
	for key in world.reactions: reactions += "%s %d次   " % [key,world.reactions[key]]
	UI.label(page,reactions,Rect2(735,695,750,40),19,UI.JADE)
	if not last_result.get("unlocked",[]).is_empty(): UI.label(page,"解锁成就："+"、".join(last_result.unlocked),Rect2(85,715,900,50),20,UI.GOLD)
	UI.button(page,"再战一局",Rect2(85,805,350,58),show_prepare,true)
	UI.button(page,"返回渡口",Rect2(465,805,250,58),show_menu)
	focus_first()

func show_camp() -> void:
	screen = "camp"
	shell(Lore.HOST.place,Lore.HOST.intro)
	set_backdrop(StoryView.texture("ferry"),0.78)
	UI.panel(page,Rect2(80,228,430,560),UI.GOLD)
	UI.seal(page,"沈",Rect2(108,256,84,84))
	UI.label(page,Lore.HOST.name,Rect2(212,262,260,46),38,UI.BRIGHT,true)
	UI.label(page,"茶摊老板娘",Rect2(214,310,260,26),17,UI.MUTED)
	var lines: Array = Lore.HOST.lines
	var line = lines[(Save.profile.settled.size()+Save.profile.embers) % lines.size()]
	UI.paragraph(page,"「%s」" % line,Rect2(108,368,376,140),25,UI.TEXT)
	UI.rule(page,Rect2(108,540,376,12))
	UI.label(page,"手里的灯烬",Rect2(108,566,376,26),18,UI.MUTED)
	UI.label(page,str(Save.profile.embers),Rect2(106,594,376,80),68,UI.AMBER,true)
	UI.paragraph(page,"营地加成对四章夜行生效；每日挑战统一起点，不生效。",Rect2(108,700,376,64),16,UI.MUTED)
	var i = 0
	for key in Content.data.camp:
		var item = Content.data.camp[key]
		var lore = Lore.CAMP.get(key,{})
		var x = 540+(i%2)*500
		var y = 228+int(i/2)*286
		UI.panel(page,Rect2(x,y,475,266))
		UI.seal(page,item.glyph,Rect2(x+24,y+24,72,72),Color("9c3a26"))
		UI.label(page,item.name,Rect2(x+116,y+24,340,42),32,UI.BRIGHT,true)
		UI.label(page,item.desc,Rect2(x+118,y+70,340,26),17,UI.AMBER)
		UI.paragraph(page,lore.get("line",""),Rect2(x+26,y+112,425,56),19,UI.TEXT)
		var lv = int(Save.profile.camp[key])
		for k in range(8):
			var pip = Ornament.new()
			pip.kind = "diamond"
			pip.color = UI.AMBER if k < lv else Color("33403f")
			pip.position = Vector2(x+28+k*22,y+186)
			pip.size = Vector2(14,14)
			pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
			page.add_child(pip)
		UI.label(page,"%d / 8" % lv,Rect2(x+214,y+180,80,26),17,UI.MUTED)
		var button = UI.button(page,"添置 · %d 灯烬" % Save.camp_cost(key) if lv < 8 else "已经够了",Rect2(x+24,y+206,427,46),func():
			var ok = Save.buy_camp(key)
			show_camp()
			if not ok and Save.error!="": UI.label(page,Save.error,Rect2(540,800,980,40),21,UI.GOLD)
		)
		button.disabled = lv >= 8 or Save.profile.embers < Save.camp_cost(key)
		i += 1
	UI.stagger(page,0,0.035)
	focus_first()

func show_journal(tab: String = "codex", page_index: int = 0) -> void:
	JournalView.render(self,tab,page_index)

func show_settings(in_run: bool) -> void:
	if in_run: paused = true
	var parent = modal if in_run else page
	var x: float
	var y: float
	if in_run:
		clear_control(modal)
		var dim = UI.shade(modal,Color(0.02,0.04,0.05,0.78))
		dim.mouse_filter = Control.MOUSE_FILTER_STOP
		UI.panel(modal,Rect2(365,110,870,720))
		UI.label(modal,"声音与画面",Rect2(410,136,780,58),40,UI.BRIGHT,true)
		UI.rule(modal,Rect2(410,198,240,12))
		x = 420; y = 226
	else:
		screen = "settings"
		shell("设置","声音、画面和操作。改动会立刻生效并自动保存。")
		UI.panel(page,Rect2(80,228,700,214))
		UI.panel(page,Rect2(80,462,700,330))
		UI.panel(page,Rect2(820,228,700,356))
		UI.panel(page,Rect2(820,604,700,188))
		x = 112; y = 246
	UI.heading(parent,"声音",Rect2(x,y,300,34),23)
	y += 50
	for key in ["music","sfx"]:
		UI.label(parent,"背景音乐" if key == "music" else "战斗音效",Rect2(x,y,170,36),22)
		var slider = HSlider.new()
		slider.position = Vector2(x+190,y+8)
		slider.size = Vector2(360,32)
		slider.max_value = 1
		slider.step = 0.01
		slider.value = Save.profile.settings[key]
		var percentage = UI.label(parent,"%d%%" % int(slider.value*100),Rect2(x+570,y,90,36),22,UI.AMBER)
		slider.value_changed.connect(func(value):
			percentage.text = "%d%%" % int(value*100)
			Save.profile.settings[key] = value
			Sound.apply_settings()
			if not Save.save_profile(): settings_save_error(parent)
		)
		parent.add_child(slider)
		y += 58
	y = 524 if not in_run else y+16
	if not in_run: y = 480
	UI.heading(parent,"画面",Rect2(x,y,300,34),23)
	y += 46
	var toggles = [["shake","受击震屏","受击、重击与首领登场时镜头震动"],["particles","粒子特效","萤火、灯烬与命中火星"],["motion","动态效果","界面过场、慢放与镜头前探；关掉更安静"],["numbers","伤害数字","在敌人头顶显示伤害"],["fullscreen","全屏显示","F11 也可以切换"]]
	for spec in toggles:
		var key: String = spec[0]
		var check = CheckButton.new()
		check.text = spec[1]
		check.position = Vector2(x,y)
		check.size = Vector2(250,44)
		check.button_pressed = Save.profile.settings.get(key,true)
		check.toggled.connect(func(value):
			Save.profile.settings[key] = value
			if not Save.save_profile(): settings_save_error(parent)
			if key == "fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
			if key == "particles" and not in_run: set_backdrop(backdrop.texture,backdrop_dim)
		)
		parent.add_child(check)
		UI.label(parent,spec[2],Rect2(x+270,y+9,400,28),16,UI.MUTED)
		y += 46 if in_run else 50
	if not in_run:
		UI.heading(page,"操作",Rect2(852,246,300,34),23)
		var rows = [["移动","WASD / 方向键","左摇杆"],["普攻","鼠标左键","RT"],["技能","鼠标右键 / Q","RB / X"],["闪避","空格","LT / A"],["燃灯","F","按下右摇杆"],["交互","E（长按点灯）","Y"],["行囊 · 地图","B · Tab","View · LB"],["暂停","Esc","Start"]]
		UI.label(page,"键鼠",Rect2(1090,290,200,24),15,UI.AMBER)
		UI.label(page,"手柄",Rect2(1330,290,180,24),15,UI.AMBER)
		for i in range(rows.size()):
			var ry = 318+i*32
			UI.label(page,rows[i][0],Rect2(856,ry,220,28),18,UI.TEXT)
			UI.label(page,rows[i][1],Rect2(1090,ry,230,28),18,UI.BRIGHT)
			UI.label(page,rows[i][2],Rect2(1330,ry,180,28),18,UI.MUTED)
		UI.heading(page,"存档",Rect2(852,622,300,34),23)
		UI.paragraph(page,"选一份旧版 profile.json，合并灯烬、营地等级与解锁，各项取较高的一边。原文件不会改动。",Rect2(856,662,630,56),17)
		UI.button(page,"导入旧版存档",Rect2(856,724,300,52),open_legacy_import)
		UI.stagger(page,0,0.03)
	if in_run: UI.button(parent,"返回战斗",Rect2(860,746,330,56),close_pause,true)
	focus_first(parent)

func settings_save_error(parent: Control) -> void:
	if parent.has_node("SettingsSaveError"): return
	var label = UI.paragraph(parent,"设置没能存下："+Save.error,Rect2(420,650,760,50) if parent==modal else Rect2(80,800,1300,40),18,UI.GOLD)
	label.name = "SettingsSaveError"

func open_legacy_import() -> void:
	var dialog = FileDialog.new()
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.json ; 营地存档 profile.json"])
	dialog.title = "导入旧版营地 · 原存档保持不变"
	dialog.use_native_dialog = true
	dialog.file_selected.connect(func(path):
		var ok = Save.import_legacy_profile(path)
		show_settings(false)
		UI.paragraph(page,"营地进度已合并。旧文件保持不变。" if ok else Save.error,Rect2(940,560,520,90),19,UI.JADE if ok else UI.GOLD)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	add_child(dialog)
	dialog.popup_centered(Vector2i(900,600))

func focus_first(control: Control = null) -> void:
	if control == null: control = page
	for child in control.get_children():
		if child is Button and not child.disabled and child.text!="返回渡口":
			child.grab_focus()
			return
	for child in control.get_children():
		if child is Button and not child.disabled:
			child.grab_focus()
			return

func movement() -> Vector2:
	return Input.get_vector("move_left","move_right","move_up","move_down")

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_LEFT:
		var held = event.axis_value>0.5
		var was_held = trigger_latched.get(event.device,false)
		trigger_latched[event.device] = held
		if held and not was_held and screen=="run" and not paused and world!=null: world.dash(movement())
		get_viewport().set_input_as_handled()
	if event is InputEventJoypadButton and event.pressed: controller_input = true
	elif event is InputEventJoypadMotion and absf(event.axis_value)>0.3: controller_input = true
	elif (event is InputEventKey or event is InputEventMouseButton) and event.is_pressed(): controller_input = false

func _physics_process(dt: float) -> void:
	if screen == "run" and not paused and world != null:
		if world is ChapterWorld:
			if not Input.is_action_pressed("attack"): attack_needs_release = false
			var direction = arena.get_global_mouse_position()-world.pos(world.player)
			if controller_input:
				direction = Input.get_vector("aim_left","aim_right","aim_up","aim_down")
				if direction.length()<0.2: direction = movement()
			world.set_controls(direction,Input.is_action_pressed("attack") and not attack_needs_release)
		# Hit-stop freezes the simulation for a few frames; slow motion scales it.
		var scale = arena.time_scale() if arena.has_method("time_scale") else 1.0
		if scale > 0.0: world.update(dt*scale,movement(),Input.is_action_pressed("interact"))
		autosave += dt
		if autosave >= 12 and world.phase != "finished":
			autosave = 0
			if not Save.save_run(world): notice(Save.error)

func _process(dt: float) -> void:
	elapsed += dt
	menu_fog.material.set_shader_parameter("age",elapsed)
	if backdrop.visible and UI.motion():
		backdrop.scale = Vector2.ONE*(1.035+0.012*sin(elapsed*0.12))
		backdrop.position = Vector2(sin(elapsed*0.07)*10,cos(elapsed*0.05)*6)
	if screen == "run" and world != null:
		for event in world.events:
			if event.kind in ["notice","boss","sector","enrage","boss_clear","room","clear"]: notice(event.get("text",""))
			if event.kind == "boss" and world is ChapterWorld and story == null:
				var card = StoryView.BossCard.new()
				card.setup(world.stage)
				page.add_child(card)
			if event.kind == "flame_ready": notice("灯焰已满 · %s 燃灯" % ("R3" if controller_input else "F"))
		if arena.has_method("tick"): arena.tick(dt if not paused else 0.0)
		var scale = arena.time_scale() if arena.has_method("time_scale") else 1.0
		arena.sync(dt*scale if not paused else 0.0)
		if world.phase == "finished" and finish_seen: result_delay = maxf(0,result_delay-dt)
		notice_time = maxf(0,notice_time-dt)
		update_hud()
		update_phase()

func notice(text: String) -> void:
	if is_instance_valid(notice_label):
		notice_label.text = text
		notice_time = 3.5

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.echo: return
	if event.is_action_pressed("fullscreen"):
		Save.profile.settings.fullscreen = not Save.profile.settings.fullscreen
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if Save.profile.settings.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		Save.save_profile()
	if story != null:
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"): story.skip()
		elif event.is_action_pressed("ui_accept") or event.is_action_pressed("dash") or event.is_action_pressed("interact") or (event is InputEventKey and event.pressed and event.physical_keycode in [KEY_SPACE,KEY_ENTER,KEY_KP_ENTER]): story.advance()
		get_viewport().set_input_as_handled()
		return
	if screen != "run":
		if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
			if not modal.get_children().is_empty(): clear_control(modal); focus_first()
			else: show_menu()
		return
	if world.phase=="finished": return
	if event.is_action_pressed("pause") or event.is_action_pressed("ui_cancel"):
		if paused: close_pause()
		else: show_pause()
		return
	if event.is_action_pressed("inventory"):
		if paused: close_pause()
		else: show_inventory()
		return
	if event.is_action_pressed("map") and world is ChapterWorld:
		if paused: close_pause()
		else: CHAPTER_UI.show_map(self)
		return
	if paused: return
	if world.phase in ["upgrade","route","oath","relic","relic_replace"] and event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode <= KEY_9: select_choice(int(event.physical_keycode-KEY_1))
		elif event.physical_keycode == KEY_R and world.reroll(): show_choices(); Save.save_run(world)
		return
	if event.is_action_pressed("dash") and not (event is InputEventJoypadMotion and event.axis == JOY_AXIS_TRIGGER_LEFT): world.dash(movement())
	if event.is_action_pressed("pulse"): world.pulse()
	if event.is_action_pressed("ignite") and world is ChapterWorld: world.ignite()
	if event.is_action_pressed("attack") and world is ChapterWorld: world.request_attack()
	if event.is_action_pressed("interact") and world is ChapterWorld:
		world.interact_nearby()
		world.proc_timers["interact"] = 0.3

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST: exit_game()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and screen == "run" and not paused: show_pause()

func exit_game() -> void:
	if world != null and world.phase == "finished" and screen == "run":
		var result = Save.settle(world)
		if result.has("save_error"):
			show_settlement_error()
			return
	if screen == "run" and world != null and world.phase != "finished":
		if not Save.save_run(world):
			show_pause()
			notice(Save.error)
			return
	Save.save_profile()
	Sound.shutdown()
	await get_tree().create_timer(Sound.shutdown_delay()).timeout
	get_tree().quit()

func show_settlement_error() -> void:
	paused = true
	modal_base("存档写入失败","本次对局获得的灯烬未能写入本地磁盘。您可以重试保存，或直接退出放弃本次收益。")
	UI.button(modal,"重试保存",Rect2(425,555,350,60),func(): paused=false; update_phase(),true)
	UI.button(modal,"退出 · 放弃奖励",Rect2(820,555,350,60),quit_without_save)
	focus_first(modal)

func quit_without_save() -> void:
	Sound.shutdown()
	await get_tree().create_timer(Sound.shutdown_delay()).timeout
	get_tree().quit()

func capture_later() -> void:
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(screenshot_path)
	Sound.shutdown()
	await get_tree().create_timer(Sound.shutdown_delay()).timeout
	get_tree().quit()
