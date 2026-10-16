extends Node

var app
var failures: Array = []
var checks = 0
var joy_device = 0

func _ready() -> void:
	get_tree().create_timer(45).timeout.connect(func(): push_error("Input flow timed out"); get_tree().quit(1))
	call_deferred("run")

func expect(value: bool, label_text: String) -> void:
	checks += 1
	if not value: failures.append(label_text); push_error(label_text)

func frames(count: int = 3) -> void:
	for i in range(count): await get_tree().process_frame

func key(code: int) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event.pressed = false
	Input.parse_input_event(event)
	await frames()

func joy(button: int, held: int = 2) -> void:
	var event = InputEventJoypadButton.new()
	event.device = joy_device
	event.button_index = button
	event.pressed = true
	Input.parse_input_event(event)
	Input.flush_buffered_events()
	await frames(held)
	event.pressed = false
	Input.parse_input_event(event)
	await frames()

func click(parent: Control, text_value: String) -> void:
	var matches = parent.get_children().filter(func(node): return node is Button and (node.text.begins_with(text_value) or (text_value=="提灯出发" and node.text.begins_with("启程出发")) or (text_value=="保存并回到渡口" and node.text.begins_with("保存并退出")) or (text_value=="继续夜行" and node.text.begins_with("继续对局")) or (text_value=="回到渡口" and node.text.begins_with("返回渡口")) or (text_value=="足迹" and node.text.begins_with("历史战绩")) or (text_value=="翻阅" and node.text.begins_with("查看详情")) or (text_value=="镜头震动" and node.text.begins_with("受击震屏")) or (text_value=="添灯" and node.text.begins_with("升级"))))
	if matches.is_empty(): expect(false,"Button missing: "+text_value); return
	var button = matches[0]
	var event = InputEventMouseButton.new()
	event.position = button.get_global_rect().get_center()
	event.global_position = event.position
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	Input.parse_input_event(event)
	await frames(2)
	event.pressed = false
	Input.parse_input_event(event)
	await frames()

func run() -> void:
	await frames()
	Save.directory = "user://ui-flow/"
	Save.clear_run()
	Save.profile = Save.defaults()
	Save.profile.bosses = 8
	app = load("res://scenes/main.tscn").instantiate()
	add_child(app)
	await frames()
	await key(KEY_ENTER)
	expect(app.screen=="prepare","Keyboard Enter opens preparation")
	await click(app.page,"提灯出发")
	expect(app.screen=="run" and app.paused,"First run opens the tutorial")
	await joy(JOY_BUTTON_A)
	expect(Save.profile.tutorial_seen and not app.paused and app.world.phase=="oath","Controller A acknowledges tutorial and opens oath draft")
	await joy(JOY_BUTTON_DPAD_RIGHT)
	await joy(JOY_BUTTON_A)
	expect(app.world.oath=="tide" and app.world.phase=="active","Controller direction and A choose the second oath")
	joy_device = 1
	var before = app.world.player.x
	await joy(JOY_BUTTON_DPAD_RIGHT,18)
	expect(app.world.player.x>before,"Controller D-pad moves the player")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://test-output/ui-flow-controller.png")
	await joy(JOY_BUTTON_A)
	expect(app.world.player.dash_cd>0,"Controller A triggers dash during gameplay")
	app.world.charge = 30
	await joy(JOY_BUTTON_X)
	expect(app.world.charge<2,"Controller X triggers pulse")
	await joy(JOY_BUTTON_START)
	expect(app.paused,"Controller Start pauses")
	await click(app.modal,"查看行囊")
	expect(app.paused and app.modal.get_children().any(func(node): return node is Label and node.text.begins_with("行囊")),"Mouse opens inventory from pause")
	await joy(JOY_BUTTON_B)
	expect(not app.paused,"Controller B returns from inventory")
	app.world.pending_levels = 1
	app.world.roll_choices()
	await frames()
	await key(KEY_ESCAPE)
	expect(app.paused,"Escape pauses a draft")
	await joy(JOY_BUTTON_B)
	expect(not app.paused and app.choice_phase=="upgrade" and not app.modal.get_children().is_empty(),"Closing pause restores the pending draft")
	await key(KEY_1)
	expect(app.world.phase=="active","Number key selects an upgrade")
	await key(KEY_ESCAPE)
	await click(app.modal,"保存并回到渡口")
	expect(app.screen=="menu" and not Save.read_run().is_empty(),"Pause menu saves the current run")
	await click(app.page,"继续夜行")
	expect(app.screen=="run" and app.world.oath=="tide","Mouse resumes the same oath and run")
	app.world.finish(true)
	await key(KEY_ESCAPE)
	expect(not app.paused and app.world.phase=="finished","End transition cannot be paused into an unsettled menu")
	await get_tree().create_timer(1.6).timeout
	expect(app.screen=="result" and Save.profile.victories==1,"Finished run settles and opens result screen")
	await click(app.page,"回到渡口")
	await click(app.page,"夜行手记")
	await click(app.page,"足迹")
	expect(app.screen=="journal" and Save.profile.history.size()==1,"Journal shows settled run history")
	await click(app.page,"翻阅")
	expect(app.modal.get_children().any(func(node): return node is Label and (node.text=="今夜所学" or node.text=="本局配置")),"History opens its saved build details")
	await joy(JOY_BUTTON_B)
	expect(app.modal.get_children().is_empty(),"Controller B closes journal details")
	await key(KEY_ESCAPE)
	expect(app.screen=="menu","Escape returns to main menu")
	await click(app.page,"设置")
	expect(app.screen=="settings","Settings opens from menu")
	var initial_shake = Save.profile.settings.shake
	await click(app.page,"镜头震动")
	expect(Save.profile.settings.shake!=initial_shake,"Settings checkbox updates via mouse")
	var music_slider = app.page.get_children().filter(func(node): return node is HSlider)[0]
	var pointer = InputEventMouseButton.new()
	pointer.button_index = MOUSE_BUTTON_LEFT
	pointer.position = music_slider.get_global_rect().position+Vector2(330,16)
	pointer.pressed = true
	Input.parse_input_event(pointer); await frames(2)
	pointer.pressed = false
	Input.parse_input_event(pointer); await frames()
	var chosen_volume = Save.profile.settings.music
	Save.load_profile()
	expect(chosen_volume>0.7 and is_equal_approx(Save.profile.settings.music,chosen_volume),"Volume slider value survives profile reload")
	await key(KEY_F11)
	expect(Save.profile.settings.fullscreen and DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_FULLSCREEN,"F11 enables native fullscreen")
	await key(KEY_F11)
	expect(not Save.profile.settings.fullscreen and DisplayServer.window_get_mode()==DisplayServer.WINDOW_MODE_WINDOWED,"F11 returns to window mode")
	await key(KEY_ESCAPE)
	await click(app.page,"渡口营地")
	var initial_embers = Save.profile.embers
	await click(app.page,"添灯")
	expect(Save.profile.camp.vigor==1 and Save.profile.embers==initial_embers-20,"Camp purchase changes persisted growth and currency")
	app.selected_mode = "daily"
	app.selected_character = "swordswoman"
	app.selected_difficulty = 3
	app.selected_contract = "fragile"
	app.show_prepare()
	expect(app.selected_character=="keeper" and app.selected_difficulty==0 and app.selected_contract=="none","Daily preparation displays its actual fixed rules")
	await click(app.page,"提灯出发")
	expect(app.world.mode=="daily" and app.world.character=="keeper" and app.world.camp.is_empty(),"Daily launches the advertised shared starting point")
	Save.clear_run()
	var report = {"checks":checks,"failures":failures,"passed":failures.is_empty(),"scope":"Native GUI input dispatch using keyboard, mouse and simulated joypad events. No physical controller claim."}
	var file = FileAccess.open("res://test-output/ui-flow.json",FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t")); file.close()
	print(JSON.stringify(report))
	Sound.shutdown()
	await get_tree().create_timer(0.12).timeout
	get_tree().quit(0 if failures.is_empty() else 1)
