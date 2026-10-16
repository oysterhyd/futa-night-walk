class_name JournalView
extends RefCounted

const MODES = {"campaign":"主线闯关","endless":"无尽长夜","daily":"每日挑战"}

static func render(app, tab: String = "codex", page_index: int = 0) -> void:
	app.screen = "journal"
	app.shell("夜行手记","累计击杀 %d · 击败首领 %d · 成功通关 %d · 激活祭灯 %d" % [Save.profile.kills,Save.profile.bosses,Save.profile.victories,Save.profile.shrines])
	var tabs = [["codex","见闻"],["achievements","成就"],["history","历史战绩"],["records","挑战榜单"]]
	for i in range(tabs.size()):
		var spec = tabs[i]
		UI.button(app.page,spec[1],Rect2(85+i*200,214,180,50),func(): app.show_journal(spec[0]),tab==spec[0],"tab")
	if tab=="codex":
		render_codex(app,page_index)
		UI.stagger(app.page,0,0.03)
		app.focus_first()
		return
	if tab=="achievements":
		for i in range(Content.data.achievements.size()):
			var item = Content.data.achievements[i]
			var x = 85+(i%2)*750
			var y = 290+int(i/2)*100
			var achieved = item.id in Save.profile.achievements
			UI.panel(app.page,Rect2(x,y,680,87),UI.AMBER if achieved else UI.TEXT)
			UI.label(app.page,item.name+(" · 已达成" if achieved else ""),Rect2(x+22,y+9,430,35),24,UI.AMBER if achieved else UI.TEXT,true)
			UI.label(app.page,item.desc,Rect2(x+22,y+47,600,28),19,UI.MUTED)
			UI.label(app.page,"+%d灯烬" % item.reward,Rect2(x+505,y+12,145,34),19,UI.AMBER)
		UI.label(app.page,"元素反应 ·  火 + 霜 → 融霜增伤    火 + 毒 → 燃瘴爆燃    雷 + 水/霜 → 引雷传导",Rect2(85,823,1390,42),20,UI.JADE)
	else:
		var items: Array = Save.profile.history if tab=="history" else Save.profile.records.values()
		if tab=="records":
			items.sort_custom(func(a,b): return str(a.get("date",""))>str(b.get("date","")))
			UI.label(app.page,"每日挑战与无尽长夜的本机历史最佳战绩",Rect2(745,220,750,35),20,UI.MUTED)
		if items.is_empty():
			UI.seal(app.page,"灯",Rect2(730,380,130,130))
			UI.label(app.page,"暂无历史战绩记录。开启一场对局吧！",Rect2(350,560,950,60),26,UI.TEXT,true)
		else:
			var count = ceili(items.size()/6.0)
			page_index = clampi(page_index,0,count-1)
			for i in range(page_index*6,mini(items.size(),page_index*6+6)):
				var item = items[i]
				var y = 292+(i%6)*80
				UI.panel(app.page,Rect2(85,y,1410,71))
				UI.label(app.page,Content.data.characters[item.character].name+" · "+MODES[item.mode],Rect2(110,y+9,460,35),24,UI.TEXT,true)
				UI.label(app.page,"%s  /  第%d关  /  %d击杀  /  %02d:%02d" % ["通关" if item.victory else "惜败",item.stage,item.kills,int(item.time)/60,int(item.time)%60],Rect2(555,y+10,590,32),20,UI.GOLD)
				UI.label(app.page,str(item.get("date","")).replace("T","  "),Rect2(112,y+43,750,25),16,UI.MUTED)
				UI.button(app.page,"查看详情",Rect2(1260,y+12,205,49),func(): show_detail(app,item))
			UI.label(app.page,"%d / %d页" % [page_index+1,count],Rect2(730,817,200,40),22)
			if page_index>0: UI.button(app.page,"上一页",Rect2(480,810,190,52),func(): app.show_journal(tab,page_index-1))
			if page_index<count-1: UI.button(app.page,"下一页",Rect2(955,810,190,52),func(): app.show_journal(tab,page_index+1))
	app.focus_first()

static func show_detail(app, item: Dictionary) -> void:
	if item.get("ruleset") in ["chapter_one","nightroad_campaign"]: ChapterUI.show_record(app,item); return
	app.clear_control(app.modal)
	var paper = UI.shade(app.modal,Color(0.03,0.06,0.075,0.95))
	paper.mouse_filter = Control.MOUSE_FILTER_STOP
	UI.label(app.modal,Content.data.characters[item.character].name+" · 对局详情",Rect2(90,65,1300,65),44,UI.TEXT,true)
	UI.label(app.modal,"%s · 第%d关 · 击杀 %d · 耗时 %02d:%02d" % [MODES[item.mode],item.stage,item.kills,int(item.time)/60,int(item.time)%60],Rect2(95,152,1400,45),23,UI.MUTED)
	UI.panel(app.modal,Rect2(85,240,650,495))
	UI.label(app.modal,"本局配置",Rect2(115,264,580,45),30,UI.AMBER,true)
	var y = 331
	for key in item.get("weapons",{}):
		if not Content.skills.has(key): continue
		UI.label(app.modal,Content.skills[key].name+" · "+("已进阶" if key in item.get("evolved",[]) else "%d级" % item.weapons[key]),Rect2(117,y,565,38),25,Content.color_for(key),true)
		y += 48
	var names: Array = []
	for key in item.get("relics",[]):
		if Content.data.relics.has(key): names.append(Content.data.relics[key].name)
	UI.paragraph(app.modal,"持有遗物："+("、".join(names) if not names.is_empty() else "无"),Rect2(117,570,565,110),23)
	if item.get("oath","none") in Content.data.oaths:
		UI.label(app.modal,Content.data.oaths[item.oath].name,Rect2(117,681,565,35),24,UI.GOLD,true)
	UI.label(app.modal,"伤害统计",Rect2(820,246,650,48),30,UI.GOLD,true)
	var damages = item.get("damage_by_skill",{})
	var keys = damages.keys()
	keys.sort_custom(func(a,b): return damages[a]>damages[b])
	y = 318
	for key in keys.slice(0,7):
		UI.label(app.modal,Content.skills[key].name if Content.skills.has(key) else ("镇魂" if key=="pulse" else key.trim_prefix("reaction:")),Rect2(825,y,410,39),24)
		UI.label(app.modal,str(int(damages[key])),Rect2(1295,y,195,39),23,UI.GOLD)
		y += 53
	UI.label(app.modal,"承受伤害 %d · 结算灯烬 %d" % [item.get("damage_taken",0),item.get("reward_total",item.reward)],Rect2(825,720,665,40),23,UI.MUTED)
	UI.button(app.modal,"返回记录列表",Rect2(1165,811,340,58),func(): app.clear_control(app.modal); app.focus_first(),true)
	app.focus_first(app.modal)

static func render_codex(app, selected: int) -> void:
	var entries: Array = Lore.CODEX
	var unlocked: Array = []
	for i in range(entries.size()):
		if Lore.codex_unlocked(entries[i],Save.profile): unlocked.append(i)
	UI.label(app.page,"已记下 %d / %d 条" % [unlocked.size(),entries.size()],Rect2(905,224,300,30),18,UI.MUTED)
	UI.button(app.page,"重温序章",Rect2(1300,214,220,50),func(): replay_prologue(app))
	if not selected in unlocked: selected = unlocked[0] if not unlocked.is_empty() else 0
	UI.panel(app.page,Rect2(85,286,430,520))
	for i in range(entries.size()):
		var open = i in unlocked
		var y = 302+i*41
		var item = UI.button(app.page,entries[i].name if open else "？？？",Rect2(100,y,400,38),func(): app.show_journal("codex",i),i==selected,"menu")
		item.disabled = not open
		item.add_theme_font_size_override("font_size",22)
	UI.panel(app.page,Rect2(545,286,975,520),UI.GOLD)
	var entry: Dictionary = entries[selected]
	var art_key = {"boss0":"market","boss1":"fox","boss2":"temple","boss3":"tower","fox":"fox","bell":"temple","dawn":"dawn","lamp":"tower","town":"ferry","host":"ferry","paper":"market","sigils":"title"}.get(entry.id,"title")
	var strip = Control.new()
	strip.position = Vector2(560,301); strip.size = Vector2(945,190); strip.clip_contents = true
	strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	app.page.add_child(strip)
	var art = UI.cover(strip,StoryView.texture(art_key),Rect2(0,-260,945,700))
	art.modulate = Color(0.85,0.85,0.88)
	UI.gradient(strip,Rect2(0,110,945,80),Color(0.07,0.13,0.16,0.0),Color(0.07,0.13,0.16,1.0),false)
	UI.label(app.page,entry.name,Rect2(590,500,860,56),40,UI.BRIGHT,true)
	UI.rule(app.page,Rect2(590,560,260,12))
	UI.paragraph(app.page,entry.text,Rect2(590,584,880,200),22,UI.TEXT)

static func replay_prologue(app) -> void:
	var panels: Array = Lore.PROLOGUE.duplicate()
	panels.append(Lore.PROLOGUE_END)
	app.play_story(panels,"","序  ·  冬至夜",func(): app.show_journal("codex"))
