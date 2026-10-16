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
	backdrop = UI.image(ui_root,Content.textures.title,Rect2(0,0,1600,900))
	backdrop.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	var fade = ColorRect.new()
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
	menu_fog.material.set_shader_parameter("strength",0.03)
	backdrop.add_child(menu_fog)
	page = Control.new()
	page.size = Vector2(1600,900)
	page.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(page)
	modal = Control.new()
	modal.size = Vector2(1600,900)
	modal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui_root.add_child(modal)
	show_menu()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--screenshot="): screenshot_path = arg.trim_prefix("--screenshot=")
		if arg == "--arena-preview": start_run({"seed": 4242,"choose_oath":false})
	if not screenshot_path.is_empty(): capture_later()

func setup_input() -> void:
	var keys = {"move_left": [KEY_A,KEY_LEFT], "move_right": [KEY_D,KEY_RIGHT], "move_up": [KEY_W,KEY_UP], "move_down": [KEY_S,KEY_DOWN], "dash": [KEY_SPACE], "pulse": [KEY_Q], "interact": [KEY_E], "pause": [KEY_ESCAPE], "inventory": [KEY_B], "map": [KEY_TAB], "attack": [], "aim_left": [], "aim_right": [], "aim_up": [], "aim_down": [], "fullscreen": [KEY_F11]}
	for action in keys:
		if not InputMap.has_action(action): InputMap.add_action(action)
		for key in keys[action]:
			var event = InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(action,event)
	var buttons = {"dash": JOY_BUTTON_A, "pulse": JOY_BUTTON_X, "interact": JOY_BUTTON_Y, "pause": JOY_BUTTON_START, "inventory": JOY_BUTTON_BACK, "map": JOY_BUTTON_LEFT_SHOULDER}
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
	if not name.is_empty():
		var paper = ColorRect.new()
		paper.color = Color(UI.PARCHMENT,0.94)
		paper.size = Vector2(1600,900)
		paper.mouse_filter = Control.MOUSE_FILTER_IGNORE
		page.add_child(paper)
	UI.label(page,"燃灯夜行  /  夜渡",Rect2(70,35,600,40),20,UI.GOLD,true)
	UI.label(page,name,Rect2(80,90,1200,65),42,UI.TEXT,true)
	UI.label(page,sub,Rect2(82,160,1250,40),20,UI.MUTED)
	UI.button(page,"返回渡口",Rect2(1310,38,200,48),show_menu)
	backdrop.visible = true
	arena.visible = false
	arena.post.visible = false
	Sound.play_music("night")

func show_menu() -> void:
	screen = "menu"
	paused = false
	shell("", "")
	clear_control(page)
	UI.label(page,"国风动作肉鸽",Rect2(100,75,600,40),19,UI.GOLD)
	var title_art = CarvedTitle.new()
	title_art.position = Vector2(100,135)
	title_art.size = Vector2(540,150)
	title_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	page.add_child(title_art)
	UI.seal(page,"夜渡",Rect2(102,286,155,62))
	UI.paragraph(page,"长夜漫漫，百鬼横行。\n持辟邪古灯破夜诛邪，穿巷渡江，直登古塔之巅。",Rect2(106,370,620,90),23,UI.MUTED)
	UI.button(page,"启程夜行    →",Rect2(106,492,330,65),show_prepare,true)
	var resume = UI.button(page,"继续对局",Rect2(106,575,330,57),resume_run)
	resume.disabled = Save.read_run().is_empty()
	UI.button(page,"渡口营地",Rect2(106,650,155,54),show_camp)
	UI.button(page,"夜行手记",Rect2(281,650,155,54),show_journal)
	UI.button(page,"设置",Rect2(106,724,155,50),func(): show_settings(false))
	UI.button(page,"退出游戏",Rect2(281,724,155,50),exit_game)
	UI.label(page,"灯烬：%d   /   已完成对局：%d 次" % [Save.profile.embers,Save.profile.settled.size()],Rect2(108,820,650,35),17,UI.MUTED)
	focus_first()

func show_prepare() -> void:
	screen = "prepare"
	if selected_mode=="daily":
		selected_character = "keeper"
		selected_difficulty = 0
		selected_contract = "none"
	shell("挑选出战夜行者","穿过灯市、白狐渡与沉钟寺，攻入无明塔。四章连续探索，构筑全程保留。")
	var i = 0
	for key in Content.data.characters:
		var char_def = Content.data.characters[key]
		var unlocked = Save.profile.bosses >= char_def.unlock
		var x = 85 + i*475
		UI.panel(page,Rect2(x,225,445,390),UI.GOLD if selected_character == key else Color("40574f"))
		UI.image(page,Content.sprite(int(char_def.sprite)),Rect2(x+120,235,205,205))
		UI.label(page,char_def.name,Rect2(x+28,440,380,45),31,UI.TEXT,true)
		UI.paragraph(page,{"keeper":"初始火符与镇魂印；清房获得 8 点护盾。","swordswoman":"初始桃木剑与缚地咒；闪避后的首次普攻伤害 +15%。","alchemist":"初始毒针与爆焰丸；持续伤害 +60%，清房回复 6 点生命。"}[key],Rect2(x+28,492,380,62),19,UI.MUTED)
		var button = UI.button(page,"已出战" if selected_character == key else ("选定出战" if unlocked else "击败 %d 位首领解锁" % char_def.unlock),Rect2(x+25,553,395,46),func(): selected_character = key; show_prepare(),selected_character == key)
		button.disabled = not unlocked or selected_mode=="daily"
		i += 1
	UI.label(page,"游戏模式",Rect2(85,650,160,35),20,UI.GOLD)
	option(["四章夜行","每日挑战"],Rect2(85,695,310,52),["campaign","daily"].find(selected_mode),func(index): selected_mode = ["campaign","daily"][index]; show_prepare())
	UI.label(page,"关卡难度",Rect2(425,650,160,35),20,UI.GOLD)
	option(["难度一 · 寻常","难度二 · 险途","难度三 · 恶刹","难度四 · 绝境"],Rect2(425,695,260,52),selected_difficulty,func(index): selected_difficulty = index).disabled = selected_mode=="daily"
	UI.label(page,"附加契约",Rect2(715,650,160,35),20,UI.GOLD)
	option(["标准夜行","百鬼夜涌","命如悬丝","枯泉禁疗"],Rect2(715,695,300,52),["none","swarm","fragile","silence"].find(selected_contract),func(index): selected_contract = ["none","swarm","fragile","silence"][index]).disabled = selected_mode=="daily"
	UI.button(page,"启程出发    →",Rect2(1160,690,350,62),request_start,true)
	UI.paragraph(page,"每日挑战固定提灯人、难度一与无契约，不生效营地加成。" if selected_mode == "daily" else "WASD 移动  ·  左键 攻击  ·  右键 技能  ·  空格 闪避  ·  E 交互  ·  Tab 地图",Rect2(85,790,1250,45),19)
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
	if not Save.profile.tutorial_seen and screenshot_path.is_empty(): show_tutorial()
	else: update_phase()

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
	var paper = UI.panel(page,Rect2(480,240,640,142),UI.TEXT)
	UI.seal(paper,world.biome().chapter,Rect2(28,26,88,88))
	UI.label(paper,world.biome().name,Rect2(145,21,455,51),37,UI.TEXT,true)
	UI.label(paper,world.biome().subtitle,Rect2(147,85,455,38),22,UI.MUTED)
	var tween = paper.create_tween()
	tween.tween_interval(1.8)
	tween.tween_property(paper,"modulate:a",0.0,0.7)
	tween.tween_callback(paper.queue_free)

func modal_base(title: String, subtitle: String = "") -> void:
	clear_control(modal)
	var dim = ColorRect.new()
	dim.color = Color(UI.TEXT,0.35)
	dim.size = Vector2(1600,900)
	modal.add_child(dim)
	UI.panel(modal,Rect2(365,250,870,420),UI.GOLD)
	UI.label(modal,title,Rect2(410,294,780,65),37,UI.TEXT,true)
	UI.paragraph(modal,subtitle,Rect2(412,376,780,130),22,UI.MUTED)

func show_tutorial() -> void:
	if world is ChapterWorld: CHAPTER_UI.show_tutorial(self); return
	paused = true
	modal_base("新手操作指南","符术将自动朝敌群施放，熟练走位是生存通关的关键。\nWASD / 左摇杆：控制移动    空格 / A：冲刺闪避\nQ / X：释放镇魂绝技，大范围消弹击退    E / Y：长按点亮神灯\nB / View：查看当前行囊与属性    Esc / Start：暂停对局\n【元素反应】火 + 霜：融霜额外伤害    火 + 毒：燃瘴范围爆燃    雷 + 霜/水：引雷传导麻痹")
	for node in modal.get_children():
		if node is Label and node.text.begins_with("符术将自动"): node.size.y = 174
	UI.button(modal,"掌握要领，开始战斗！",Rect2(520,580,560,60),func(): Save.profile.tutorial_seen = true; Save.save_profile(); paused = false; clear_control(modal),true)
	focus_first(modal)

func show_pause() -> void:
	if screen != "run" or world.phase=="finished": return
	paused = true
	modal_base("对局已暂停","当前战斗进度已自动暂存，可随时退出或继续对局。")
	UI.button(modal,"继续战斗",Rect2(420,465,360,57),close_pause,true)
	UI.button(modal,"查看行囊",Rect2(820,465,360,57),show_inventory)
	UI.button(modal,"声音与画面",Rect2(420,543,360,57),func(): show_settings(true))
	UI.button(modal,"保存并退出",Rect2(820,543,360,57),save_to_menu)
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
			result_delay = 1.35 if world.victory else 0.85
			notice("诛邪破晓，凯旋通关！" if world.victory else "寡不敌众，对局结束。")
			return
		if result_delay > 0: return
		last_result = Save.settle(world)
		if last_result.has("save_error"):
			show_settlement_error()
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
	shell("渡口营地","当前持有灯烬：%d · 消耗灯烬强化永久天赋，提升初始属性与实战能力。" % Save.profile.embers)
	var i = 0
	for key in Content.data.camp:
		var item = Content.data.camp[key]
		var x = 85+(i%2)*750
		var y = 250+int(i/2)*265
		UI.panel(page,Rect2(x,y,680,220))
		UI.label(page,item.glyph,Rect2(x+28,y+20,100,85),61,UI.GOLD,true)
		UI.label(page,item.name,Rect2(x+150,y+25,460,46),30,UI.TEXT,true)
		UI.label(page,item.desc,Rect2(x+150,y+85,460,37),20,UI.MUTED)
		var lv = int(Save.profile.camp[key])
		UI.label(page,"%d / 8级" % lv,Rect2(x+28,y+153,165,38),21,UI.GOLD)
		var button = UI.button(page,"升级 · %d灯烬" % Save.camp_cost(key) if lv < 8 else "已达上限",Rect2(x+270,y+145,375,52),func():
			var ok = Save.buy_camp(key)
			show_camp()
			if not ok and Save.error!="": UI.label(page,Save.error,Rect2(85,765,1390,40),23,UI.GOLD)
		,true)
		button.disabled = lv >= 8 or Save.profile.embers < Save.camp_cost(key)
		i += 1
	UI.paragraph(page,"营地永久天赋对四章闯关生效；每日挑战使用统一初始属性，不生效营地加成。",Rect2(85,817,1300,40),20)
	focus_first()

func show_journal(tab: String = "achievements", page_index: int = 0) -> void:
	JournalView.render(self,tab,page_index)

func show_settings(in_run: bool) -> void:
	if in_run: paused = true
	var parent = modal if in_run else page
	if in_run:
		modal_base("声音与画面")
		var panels = modal.get_children().filter(func(node): return node is Panel)
		panels[0].position.y = 225
		panels[0].size.y = 535
	else:
		screen = "settings"
		shell("声音与画面","调节音量、画面特效与显示模式。")
	var x = 430 if in_run else 170
	var y = 370 if in_run else 300
	for key in ["music","sfx"]:
		UI.label(parent,"背景音乐" if key == "music" else "战斗音效",Rect2(x,y,180,36),23)
		var slider = HSlider.new()
		slider.position = Vector2(x+210,y+8)
		slider.size = Vector2(400,32)
		slider.max_value = 1
		slider.step = 0.01
		slider.value = Save.profile.settings[key]
		var percentage = UI.label(parent,"%d%%" % int(slider.value*100),Rect2(x+635,y,100,36),22,UI.GOLD)
		slider.value_changed.connect(func(value):
			percentage.text = "%d%%" % int(value*100)
			Save.profile.settings[key] = value
			Sound.apply_settings()
			if not Save.save_profile(): settings_save_error(parent)
		)
		parent.add_child(slider)
		y += 65
	for key in ["shake","particles","fullscreen"]:
		var check = CheckButton.new()
		check.text = {"shake":"受击震屏","particles":"粒子特效","fullscreen":"全屏显示"}[key]
		check.position = Vector2(x,y)
		check.size = Vector2(630,45)
		check.button_pressed = Save.profile.settings[key]
		check.toggled.connect(func(value):
			Save.profile.settings[key] = value
			if not Save.save_profile(): settings_save_error(parent)
			if key == "fullscreen": DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if value else DisplayServer.WINDOW_MODE_WINDOWED)
		)
		parent.add_child(check)
		y += 55
	if not in_run:
		UI.panel(page,Rect2(910,300,580,240))
		UI.label(page,"导入旧版存档",Rect2(940,323,520,42),25,UI.GOLD,true)
		UI.paragraph(page,"选择旧版 profile.json 文件，自动合并灯烬、营地等级与解锁进度，保留双方最高数值。",Rect2(940,378,520,75),19)
		UI.button(page,"选择存档文件",Rect2(940,465,520,55),open_legacy_import)
	if in_run: UI.button(parent,"返回战斗",Rect2(850,687,300,50),close_pause,true)
	focus_first(parent)

func settings_save_error(parent: Control) -> void:
	if parent.has_node("SettingsSaveError"): return
	var label = UI.paragraph(parent,"设置尚未存下："+Save.error,Rect2(430,744,760,65) if parent==modal else Rect2(170,740,1300,65),20,UI.GOLD)
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
		world.update(dt,movement(),Input.is_action_pressed("interact"))
		autosave += dt
		if autosave >= 12 and world.phase != "finished":
			autosave = 0
			if not Save.save_run(world): notice(Save.error)

func _process(dt: float) -> void:
	elapsed += dt
	menu_fog.material.set_shader_parameter("age",elapsed)
	if screen == "run" and world != null:
		for event in world.events:
			if event.kind in ["notice","boss","sector","enrage","boss_clear","room","clear"]: notice(event.get("text",""))
		arena.sync(dt if not paused else 0)
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
