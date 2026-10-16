class_name ChapterUI
extends RefCounted

const C=preload("res://content/chapter_content.gd")
const HUD=preload("res://ui/hud_view.gd")

class MapView extends Control:
	var chapter: ChapterWorld
	var detailed=false
	func _draw() -> void:
		if chapter==null: return
		var cell=size/Vector2(7,3)
		var known: Dictionary={}
		for room in chapter.rooms:
			var adjacent=abs(room.gx-chapter.room().gx)+abs(room.gy-chapter.room().gy)==1
			if room.type=="secret" and not chapter.secret_revealed(): continue
			if room.visited or adjacent or "map" in chapter.relics: known[room.id]=true
		for room in chapter.rooms:
			if not known.has(room.id): continue
			var p=(Vector2(room.gx,room.gy+1)+Vector2(0.5,0.5))*cell
			for other in chapter.rooms:
				if known.has(other.id) and other.id>room.id and abs(other.gx-room.gx)+abs(other.gy-room.gy)==1:
					draw_line(p,(Vector2(other.gx,other.gy+1)+Vector2(0.5,0.5))*cell,Color(UI.BRASS,0.45),2 if detailed else 1.5)
		for room in chapter.rooms:
			if not known.has(room.id): continue
			var p=(Vector2(room.gx,room.gy+1)+Vector2(0.5,0.5))*cell
			var extent=Vector2(70,32) if detailed else Vector2(10,8)
			var current=room.id==chapter.room_id
			var rect=Rect2(p-extent,extent*2)
			if current: draw_texture_rect(UI.glow(),rect.grow(extent.x*0.8),false,Color(UI.AMBER,0.45))
			var fill=UI.GOLD if current else (UI.LACQUER_HI if room.visited else Color("0e1a1f"))
			if room.type=="boss" and not current: fill=Color("4a1d18")
			draw_rect(rect,fill)
			draw_rect(rect,Color(UI.AMBER,0.9) if current else Color(UI.BRASS,0.55 if room.visited else 0.3),false,1.5 if detailed else 1.0)
			var text=chapter.display_room_name(room) if detailed else C.ROOM_TYPES[room.type].glyph
			var text_color=UI.BRIGHT if current or room.visited else UI.MUTED
			draw_string(Content.body_font,p-Vector2(extent.x,0)+Vector2(0,7 if detailed else 5),text,HORIZONTAL_ALIGNMENT_CENTER,extent.x*2,20 if detailed else 12,text_color)
			if detailed:
				var status="当前" if current else ("已清理" if room.visited and room.cleared else "已发现")
				draw_string(Content.body_font,p+Vector2(-70,56),status,HORIZONTAL_ALIGNMENT_CENTER,140,16,UI.AMBER if current else UI.MUTED)

static func accent(token: String, info: Dictionary) -> Color:
	var prefix=token.get_slice(":",0)
	if prefix in ["p","drop_sigil"] and C.SCHOOLS.has(info.get("school","")): return Color(C.SCHOOLS[info.school].color)
	match prefix:
		"g","gm": return UI.AMBER
		"s","sm": return UI.JADE
		"a","coin","shop": return UI.BRASS
		"r","drop_relic": return Color("d9a066")
		"event": return Color("a99ad0")
		"rest": return UI.AMBER
	return Color("d8573a")

static func show_hud(app) -> void:
	app.clear_control(app.page); app.clear_control(app.modal)
	app.labels.clear(); app.bars.clear()
	app.backdrop.visible=false; app.arena.visible=true; app.arena.post.visible=true
	var w=app.world as ChapterWorld
	var hud=HUD.new(); hud.setup(app); app.page.add_child(hud); app.labels.hud=hud
	# top-left: chapter plate
	UI.panel(app.page,Rect2(24,20,450,92))
	app.labels.seal=UI.seal(app.page,Lore.CHAPTERS[clampi(w.stage-1,0,3)].numeral,Rect2(40,34,62,62))
	app.labels.chapter=UI.label(app.page,"",Rect2(118,29,345,38),26,UI.BRIGHT,true)
	app.labels.subtitle=UI.label(app.page,"",Rect2(119,71,345,26),17,UI.MUTED)
	# top-right: map, counters, school resonance
	UI.panel(app.page,Rect2(1166,20,410,124))
	var map=MapView.new(); map.chapter=w; map.position=Vector2(1182,24); map.size=Vector2(378,66)
	app.page.add_child(map); app.labels.map=map
	app.labels.counters=UI.label(app.page,"",Rect2(1184,86,376,22),16,UI.TEXT)
	var x=1202
	for key in ["yan","feng","zhen","you"]:
		app.labels["school_"+key]=UI.label(app.page,"",Rect2(x,113,74,22),15,Color(C.SCHOOLS[key].color))
		x+=92
	# bottom-left: health / dash / flame (gauges drawn by HudView)
	app.labels.hp=UI.label(app.page,"",Rect2(160,782,330,26),18,UI.TEXT)
	UI.shadowed(app.labels.hp)
	app.labels.dash=UI.label(app.page,"",Rect2(252,838,240,24),15,UI.MUTED)
	app.labels.flame=UI.label(app.page,"",Rect2(160,862,330,24),16,UI.AMBER,true)
	UI.shadowed(app.labels.flame)
	# bottom-centre: gear & skill plates
	UI.panel(app.page,Rect2(510,788,258,90))
	app.labels.gear_icon=UI.image(app.page,Content.chapter_icon("gear",w.gear),Rect2(522,801,64,64))
	app.labels.gear=UI.label(app.page,"",Rect2(596,800,165,32),23,UI.BRIGHT,true)
	app.labels.gear_note=UI.label(app.page,"",Rect2(596,838,165,24),15,UI.MUTED)
	UI.panel(app.page,Rect2(778,788,258,90))
	app.labels.skill_icon=UI.image(app.page,Content.chapter_icon("skill",w.skill),Rect2(788,804,60,60))
	app.labels.skill=UI.label(app.page,"",Rect2(860,800,170,32),23,UI.BRIGHT,true)
	app.labels.skill_note=UI.label(app.page,"",Rect2(860,838,170,24),15,UI.MUTED)
	app.labels.buff_panel=UI.panel(app.page,Rect2(1048,796,232,74))
	app.labels.buffs=UI.paragraph(app.page,"",Rect2(1062,804,208,60),16,UI.JADE)
	UI.button(app.page,"B · 行囊",Rect2(1292,806,136,56),app.show_inventory)
	UI.button(app.page,"暂停",Rect2(1440,806,136,56),app.show_pause)
	app.labels.hint=UI.label(app.page,"",Rect2(380,748,840,30),17,UI.TEXT)
	app.labels.hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	UI.shadowed(app.labels.hint,0.9)
	app.notice_label=UI.label(app.page,"",Rect2(380,146,840,48),28,UI.AMBER,true)
	app.notice_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	UI.shadowed(app.notice_label,0.9)
	var boss_panel=Control.new(); boss_panel.name="BossPanel"; boss_panel.mouse_filter=Control.MOUSE_FILTER_IGNORE
	app.page.add_child(boss_panel)
	app.labels.boss=UI.label(app.page,"",Rect2(450,24,700,44),32,UI.BRIGHT,true)
	app.labels.boss.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	UI.shadowed(app.labels.boss)
	app.labels.boss_note=UI.label(app.page,"",Rect2(450,90,700,24),17,UI.AMBER)
	app.labels.boss_note.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	UI.shadowed(app.labels.boss_note)
	for node in app.page.get_children():
		if node is Button: node.focus_mode=Control.FOCUS_NONE
	update_hud(app)

static func update_hud(app) -> void:
	if app.labels.is_empty() or not app.labels.has("gear"): return
	var w=app.world as ChapterWorld
	var pad=app.controller_input
	app.labels.chapter.text=w.biome().name+" · "+w.room_name()
	var room_state="已清理" if w.room().cleared else ("首领战" if w.room().type=="boss" else "敌潮 %d / %d" % [w.wave_index,w.wave_count])
	app.labels.subtitle.text="%02d:%02d  ·  %s" % [int(w.time)/60,int(w.time)%60,room_state]
	app.labels.counters.text="铜钱 %d    斩祟 %d    难度 %d" % [w.coins,w.kills,w.difficulty+1]
	for key in ["yan","feng","zhen","you"]:
		app.labels["school_"+key].text="%s %d" % [C.SCHOOLS[key].name,w.school_count(key)]
		app.labels["school_"+key].modulate.a=1.0 if w.school_count(key)>0 else 0.45
	app.labels.hp.text="生命 %d / %d%s" % [maxi(0,int(w.player.hp)),int(w.player.max_hp),"   护盾 %d" % w.shield if w.shield>0 else ""]
	var dash_key="LT" if pad else "空格"
	app.labels.dash.text=("%s · 闪避" % dash_key) if w.dash_charges>=w.dash_max() else ("%s · %.1f 秒" % [dash_key,maxf(0,w.dash_recharge)])
	if w.perfect_time>0: app.labels.dash.text="识破 · 下一击必暴"
	var ignite_key="R3" if pad else "F"
	var ultimate=Lore.CHARACTERS[w.character].ultimate
	if w.ignite_time>0: app.labels.flame.text="%s · 燃烧中 %.1f 秒" % [ultimate,w.ignite_time]
	elif w.can_ignite(): app.labels.flame.text="%s · %s 燃灯！" % [ignite_key,ultimate]
	else: app.labels.flame.text="灯焰 %d%%" % int(w.flame/w.FLAME_MAX*100)
	app.labels.flame.add_theme_color_override("font_color",UI.BRIGHT if w.can_ignite() or w.ignite_time>0 else Color(UI.AMBER,0.8))
	app.labels.gear.text=C.GEAR[w.gear].name
	app.labels.gear_icon.texture=Content.chapter_icon("gear",w.gear)
	app.labels.gear_note.text=("RT" if pad else "左键")+" · 普攻 · %d 阶" % w.gear_rank
	app.labels.skill.text=C.SKILLS[w.skill].name
	app.labels.skill_icon.texture=Content.chapter_icon("skill",w.skill)
	app.labels.skill_note.text=("RB" if pad else "右键")+" · "+("就绪" if w.skill_cd<=0 else "%.1f 秒" % w.skill_cd)+" · %d 阶" % w.skill_rank
	app.labels.skill_icon.modulate=Color.WHITE if w.skill_cd<=0 else Color(0.7,0.72,0.74)
	app.labels.hint.text=w.interaction_hint()
	if pad:
		app.labels.hint.text=app.labels.hint.text.replace("长按 E","长按 Y").replace("E ·","Y ·").replace("左键攻击  ·  右键技能  ·  空格闪避  ·  Tab 地图","RT 攻击  ·  RB 技能  ·  LT 闪避  ·  LB 地图")
	var buffs: Array=[]
	if w.ignite_time>0: buffs.append(ultimate)
	if w.perfect_time>0: buffs.append("识破")
	if w.shadow_time>0: buffs.append("影分 %.1f秒" % w.shadow_time)
	if w.counter_time>0 and (w.sigils.get("counter",0)>0 or "fox_tooth" in w.relics or w.character=="swordswoman"): buffs.append("反击强化")
	if w.echo_ready and w.sigils.get("echo",0)>0: buffs.append("符法余势")
	if w.wind_time>0 and w.sigils.get("wind",0)>0: buffs.append("踏风 ×%d" % w.wind_stacks)
	app.labels.buffs.text=" · ".join(buffs.slice(0,4)); app.labels.buffs.tooltip_text=" / ".join(buffs)
	app.labels.buffs.visible=not buffs.is_empty(); app.labels.buff_panel.visible=not buffs.is_empty()
	app.labels.map.queue_redraw()
	var bosses=w.mobs.filter(func(m): return m.boss and m.hp>0)
	var has_boss=not bosses.is_empty()
	var hud: HudView=app.labels.hud
	hud.has_boss=has_boss
	app.labels.boss.visible=has_boss; app.labels.boss_note.visible=has_boss
	if has_boss:
		var lore=Lore.BOSSES[clampi(w.stage-1,0,3)]
		app.labels.boss.text=w.biome().boss
		app.labels.boss_note.text=lore.epithet+("  ·  狂暴" if bosses[0].enraged else "")
		hud.boss_fraction=clampf(bosses[0].hp/bosses[0].max_hp,0,1); hud.boss_enraged=bosses[0].enraged
	Sound.battle_state(w.stage,has_boss,app.paused,w.phase!="active")
	app.arena.interact_hint="长按 E · 点灯" if w.shrine_started else "E · 开始祭灯"
	app.notice_label.visible=app.notice_time>0; app.notice_label.modulate.a=minf(1,app.notice_time*1.5)
	hud.notice_alpha=app.notice_label.modulate.a if app.notice_label.visible and not app.notice_label.text.is_empty() else 0.0
	hud.notice_width=Content.title_font.get_string_size(app.notice_label.text,HORIZONTAL_ALIGNMENT_LEFT,-1,28).x
	if w.phase=="active" and not app.paused and app.intro_stage!=w.stage: app.show_chapter_banner()

static func _paper(app,title: String,subtitle: String) -> void:
	app.clear_control(app.modal)
	var dim=UI.shade(app.modal,Color(0.03,0.06,0.075,0.9)); dim.mouse_filter=Control.MOUSE_FILTER_STOP
	UI.gradient(app.modal,Rect2(0,0,1600,260),Color(0.02,0.04,0.05,0.85),Color(0.02,0.04,0.05,0.0),false)
	var head=UI.label(app.modal,title,Rect2(80,52,1440,66),46,UI.BRIGHT,true)
	head.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	UI.shadowed(head)
	UI.rule(app.modal,Rect2(620,124,360,14))
	UI.paragraph(app.modal,subtitle,Rect2(180,142,1240,62),20).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

static func show_choices(app) -> void:
	var w=app.world as ChapterWorld
	var subtitle=w.offer_subtitle
	if w.offer_kind=="chapter_clear":
		var defeat=Lore.BOSSES[clampi(w.stage-1,0,3)].defeat
		if not defeat.is_empty(): subtitle=defeat+"\n"+subtitle
	_paper(app,w.offer_title,subtitle)
	var count=w.choices.size()
	var compact=count>4
	var columns=4 if count>=4 else count
	var width=340 if columns==4 else (420 if columns==3 else 500)
	var gap=28
	var stride=width+gap
	var left=(1600-(columns*width+(columns-1)*gap))*0.5
	var first_child=app.modal.get_child_count()
	for i in range(count):
		var info=w.chapter_choice_info(w.choices[i])
		var color=accent(w.choices[i],info)
		var row_items=mini(columns,count-int(i/columns)*columns)
		var row_left=(1600-(row_items*width+(row_items-1)*gap))*0.5
		var x=row_left+(i%columns)*stride
		var y=218+int(i/columns)*320 if compact else 236
		var height=258 if compact else 400
		var card=UI.panel(app.modal,Rect2(x,y,width,height),color)
		card.talisman=not compact
		UI.label(app.modal,info.tag,Rect2(x+22,y+20,width-44,25),16,color)
		var prefix=w.choices[i].get_slice(":",0)
		var key=w.choices[i].get_slice(":",1)
		var icon: Texture2D
		if prefix=="g": icon=Content.chapter_icon("gear",key)
		elif prefix=="s": icon=Content.chapter_icon("skill",key)
		elif prefix=="gm" or prefix=="shop" and key=="gear": icon=Content.chapter_icon("gear",w.gear)
		elif prefix=="sm" or prefix=="shop" and key=="skill": icon=Content.chapter_icon("skill",w.skill)
		elif prefix=="shop" and key=="relic": icon=app.arena.prop_texture(7)
		var school=info.get("school","")
		if not compact:
			if icon!=null:
				UI.panel(app.modal,Rect2(x+22,y+56,100,96),color,0.8)
				UI.image(app.modal,icon,Rect2(x+26,y+58,92,92))
			else: UI.seal(app.modal,info.glyph,Rect2(x+22,y+60,84,84),color.darkened(0.25) if prefix!="o" else UI.GOLD)
			if C.SCHOOLS.has(school):
				var sx=x+width-88
				UI.seal(app.modal,C.SCHOOLS[school].glyph,Rect2(sx+12,y+60,52,52),Color(C.SCHOOLS[school].color).darkened(0.2))
				var school_label=UI.label(app.modal,C.SCHOOLS[school].name,Rect2(sx-4,y+118,84,24),15,color)
				school_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
		elif icon!=null: UI.image(app.modal,icon,Rect2(x+width-57,y+20,34,34))
		elif C.SCHOOLS.has(school): UI.seal(app.modal,C.SCHOOLS[school].glyph,Rect2(x+width-56,y+18,34,34),Color(C.SCHOOLS[school].color).darkened(0.2))
		UI.label(app.modal,info.name,Rect2(x+22,y+(52 if compact else 164),width-44,40),28,UI.BRIGHT,true)
		UI.paragraph(app.modal,info.desc,Rect2(x+22,y+(98 if compact else 214),width-44,118 if compact else 112),17 if compact else 19,UI.TEXT)
		UI.paragraph(app.modal,info.note,Rect2(x+22,y+(220 if compact else 330),width-44,34 if compact else 56),15,UI.MUTED if w.can_choose(w.choices[i]) else UI.GOLD)
		var button=UI.button(app.modal,"%d · 选择" % (i+1),Rect2(x,y+height+14,width,46 if compact else 58),func(): app.select_choice(i),i==0)
		button.disabled=not w.can_choose(w.choices[i])
	if w.phase=="upgrade" and w.offer_kind=="growth":
		var refresh=UI.button(app.modal,"R · 刷新候选 / 剩余 %d 次" % w.rerolls,Rect2(565,812,470,52),func(): if w.reroll(): app.show_choices(); Save.save_run(w))
		refresh.disabled=w.rerolls<=0
	UI.stagger(app.modal,first_child,0.05,0.04)
	app.focus_first(app.modal)

static func _stat(parent: Control, caption: String, value: String, rect: Rect2, value_color: Color = UI.BRIGHT) -> void:
	UI.label(parent,caption,Rect2(rect.position,Vector2(rect.size.x,24)),16,UI.MUTED)
	UI.label(parent,value,Rect2(rect.position+Vector2(0,24),Vector2(rect.size.x,rect.size.y-24)),28,value_color,true)

static func show_result(app) -> void:
	app.screen="result"; app.paused=false
	var w=app.world as ChapterWorld
	app.shell(("长夜已尽 · 四章通关" if w is CampaignWorld else "灯市已清 · 第一章通关") if w.victory else "夜行中断 · 来日再战","灯烬已交给沈婆收着。下一夜可以换个人、换套打法。")
	var key="dawn" if w.victory else Lore.CHAPTERS[clampi(w.stage-1,0,3)].image
	app.set_backdrop(StoryView.texture(key),0.7)
	UI.panel(app.page,Rect2(80,232,520,470),UI.GOLD)
	UI.label(app.page,"本夜所得",Rect2(116,256,300,28),18,UI.AMBER,true)
	UI.label(app.page,"+ %d" % app.last_result.get("reward_total",app.last_result.reward),Rect2(112,284,440,96),76,UI.AMBER,true)
	UI.label(app.page,"灯烬",Rect2(118,380,300,36),24,UI.TEXT,true)
	UI.rule(app.page,Rect2(116,428,450,12))
	var rooms=app.last_result.get("rooms_cleared",w.rooms.filter(func(r): return r.visited).size())
	var stats=[["斩祟",str(w.kills)],["首领",str(w.bosses)],["探索","%d / %d" % [rooms,56 if w is CampaignWorld else 14]],["耗时","%02d:%02d" % [int(w.time)/60,int(w.time)%60]],["承受伤害",str(int(w.total_damage_taken))],["识破",str(w.perfect_count)]]
	for i in range(stats.size()):
		_stat(app.page,stats[i][0],stats[i][1],Rect2(118+(i%3)*155,452+int(i/3)*104,150,80))
	UI.panel(app.page,Rect2(632,232,888,470))
	UI.heading(app.page,"伤害来源",Rect2(664,254,400,40),26)
	var keys=w.damage_by_skill.keys()
	keys.sort_custom(func(a,b): return w.damage_by_skill[a]>w.damage_by_skill[b])
	var top=1.0
	if not keys.is_empty(): top=maxf(1.0,w.damage_by_skill[keys[0]])
	for i in range(mini(6,keys.size())):
		var y=312+i*52
		UI.label(app.page,C.damage_name(keys[i]),Rect2(668,y,330,32),21)
		var meter=UI.bar(app.page,Rect2(1000,y+12,330,8),UI.GOLD if i==0 else UI.BRASS)
		meter.value=w.damage_by_skill[keys[i]]/top*100
		var value_label=UI.label(app.page,str(int(w.damage_by_skill[keys[i]])),Rect2(1340,y,150,32),21,UI.AMBER)
		value_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_RIGHT
	UI.label(app.page,"%s · %d 阶   +   %s · %d 阶" % [C.GEAR[w.gear].name,w.gear_rank,C.SKILLS[w.skill].name,w.skill_rank],Rect2(668,640,820,40),24,UI.BRIGHT,true)
	if not app.last_result.get("unlocked",[]).is_empty(): UI.label(app.page,"解锁成就："+"、".join(app.last_result.unlocked),Rect2(82,722,1440,34),20,UI.AMBER)
	UI.button(app.page,"再战一局",Rect2(80,800,300,60),app.show_prepare,true)
	UI.button(app.page,"查看本局构筑",Rect2(400,800,320,60),func(): show_record(app,app.last_result))
	UI.button(app.page,"返回渡口",Rect2(740,800,260,60),app.show_menu)
	UI.stagger(app.page,0,0.04)
	app.focus_first()

static func show_record(app, item: Dictionary) -> void:
	_paper(app,Content.data.characters[item.character].name+" · 本局构筑","斩祟 %d   耗时 %02d:%02d   承受伤害 %d" % [item.kills,int(item.time)/60,int(item.time)%60,item.get("damage_taken",0)])
	var equipment=C.GEAR[item.gear]; var ability=C.SKILLS[item.skill]
	var text="[color=#f0b85e]装备 · %s / %d 阶[/color]\n%s\n" % [equipment.name,item.get("gear_rank",1),equipment.desc]
	if item.get("gear_mod",-1)>=0: text+=equipment.mods[item.gear_mod]+"\n"
	text+="\n[color=#f0b85e]技能 · %s / %d 阶[/color]\n%s\n" % [ability.name,item.get("skill_rank",1),ability.desc]
	if item.get("skill_mod",-1)>=0: text+=ability.mods[item.skill_mod]+"\n"
	text+="\n[color=#f0b85e]基础强化[/color]\n"
	for key in item.get("attributes",{}): text+="%s × %d\n" % [C.ATTRIBUTES[key].name,item.attributes[key]]
	UI.panel(app.modal,Rect2(80,222,680,560))
	_details(app.modal,text,Rect2(110,246,620,512))
	var extras="[color=#f0b85e]符印[/color]\n"
	for key in item.get("sigils",{}): extras+="%s · %d 级  [color=#9aa39b]%s[/color]\n%s\n\n" % [C.SIGILS[key].name,item.sigils[key],C.SCHOOLS[C.SIGILS[key].school].name,C.SIGILS[key].desc]
	extras+="[color=#f0b85e]遗物[/color]\n"
	for key in item.get("relics",[]): extras+=C.RELICS[key].name+"\n"+C.RELICS[key].desc+"\n\n"
	UI.panel(app.modal,Rect2(790,222,730,560))
	_details(app.modal,extras,Rect2(820,246,670,512))
	UI.button(app.modal,"返回结算" if app.screen=="result" else "返回记录列表",Rect2(1155,806,365,58),func(): app.clear_control(app.modal); app.focus_first(),true)
	app.focus_first(app.modal)

static func show_tutorial(app) -> void:
	app.paused=true
	_paper(app,"先清街巷，再破灯魁","普攻、闪避、技能，再加一盏灯。别的事都能在安全的房间里做。")
	var rows=[["攻","左键 / RT · 普通攻击","朝鼠标或右摇杆方向出手，可以按住不放。"],["闪","空格 / LT · 闪避","两次充能。在红色预警落下的一瞬闪开，算作「识破」：短暂慢放，下一击必定暴击。"],["术","右键 / RB · 主动技能","一件装备，一个技能。冷却转完就能再放。"],["灯","F / R3 · 燃灯","打怪、识破都会攒灯焰。灯焰满了，放出角色的绝技。"]]
	for i in range(rows.size()):
		var y=232+i*112
		UI.panel(app.modal,Rect2(300,y-10,1000,98))
		UI.seal(app.modal,rows[i][0],Rect2(322,y+4,70,70),UI.GOLD if i<3 else Color("c98a2e"))
		UI.label(app.modal,rows[i][1],Rect2(420,y+2,860,40),27,UI.BRIGHT,true)
		UI.paragraph(app.modal,rows[i][2],Rect2(422,y+42,860,40),19,UI.TEXT)
	UI.label(app.modal,"E / Y 交互与过门  ·  B 行囊  ·  Tab 地图  ·  Esc 暂停",Rect2(300,688,1000,36),20,UI.MUTED).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	UI.button(app.modal,"进入灯市",Rect2(555,748,490,62),func(): Save.profile.tutorial_seen=true; Save.save_profile(); app.paused=false; app.clear_control(app.modal); app.choice_phase=""; app.update_phase(),true)
	UI.stagger(app.modal,0,0.04)
	app.focus_first(app.modal)

static func show_inventory(app) -> void:
	app.paused=true
	var w=app.world as ChapterWorld
	_paper(app,"行囊 · 当前构筑","一件装备，一个技能。符印凑齐同一盏四象灯，会有额外的火候。")
	# left column: gear / skill
	UI.panel(app.modal,Rect2(70,220,470,560))
	UI.image(app.modal,Content.chapter_icon("gear",w.gear),Rect2(92,242,64,64))
	UI.label(app.modal,C.GEAR[w.gear].name+" · %d 阶" % w.gear_rank,Rect2(170,246,350,34),25,UI.AMBER,true)
	UI.label(app.modal,"装备 · 普通攻击",Rect2(170,280,350,24),15,UI.MUTED)
	var gear_text=C.GEAR[w.gear].desc+("\n"+C.GEAR[w.gear].mods[w.gear_mod] if w.gear_mod>=0 else "")
	UI.paragraph(app.modal,gear_text,Rect2(92,316,428,150),17,UI.TEXT)
	UI.rule(app.modal,Rect2(92,474,428,12))
	UI.image(app.modal,Content.chapter_icon("skill",w.skill),Rect2(92,498,64,64))
	UI.label(app.modal,C.SKILLS[w.skill].name+" · %d 阶" % w.skill_rank,Rect2(170,502,350,34),25,UI.JADE,true)
	UI.label(app.modal,"主动技能 · 冷却 %.1f 秒" % C.SKILLS[w.skill].cooldown,Rect2(170,536,350,24),15,UI.MUTED)
	var skill_text=C.SKILLS[w.skill].desc+("\n"+C.SKILLS[w.skill].mods[w.skill_mod] if w.skill_mod>=0 else "")
	UI.paragraph(app.modal,skill_text,Rect2(92,572,428,190),17,UI.TEXT)
	# middle column: stats + ultimate
	UI.panel(app.modal,Rect2(560,220,430,560))
	UI.heading(app.modal,"属性",Rect2(584,238,300,34),23)
	var stats=[["生命","%d / %d" % [w.player.hp,w.player.max_hp]],["护盾",str(int(w.shield))],["伤害","+%d%%" % int(round((w.stat("damage")-1)*100))],["暴击率","%d%%" % int(round(w.stat("crit")*100))],["暴击伤害","%d%%" % int(round(w.crit_multiplier()*100))],["攻速","+%d%%" % int(round(w.stat("attack_speed")*100))],["技能急速","%d%%" % int(round(w.stat("haste")*100))],["闪避","%d 次 · %.1f 秒" % [w.dash_max(),w._dash_interval()]]]
	for i in range(stats.size()):
		var sx=588+(i%2)*200
		var sy=284+int(i/2)*66
		UI.label(app.modal,stats[i][0],Rect2(sx,sy,190,22),15,UI.MUTED)
		UI.label(app.modal,stats[i][1],Rect2(sx,sy+22,190,34),24,UI.BRIGHT,true)
	UI.rule(app.modal,Rect2(584,552,382,12))
	var lore=Lore.CHARACTERS[w.character]
	UI.label(app.modal,"燃灯 · "+lore.ultimate,Rect2(584,572,382,34),24,UI.AMBER,true)
	UI.paragraph(app.modal,lore.ultimate_desc,Rect2(584,610,382,110),17,UI.TEXT)
	UI.label(app.modal,"灯焰 %d%%" % int(w.flame/w.FLAME_MAX*100),Rect2(584,732,382,28),18,UI.AMBER)
	# right column: four symbols, sigils, relics
	UI.panel(app.modal,Rect2(1010,220,520,560))
	UI.heading(app.modal,"四象灯 · 符印 %d / 6" % w.sigils.size(),Rect2(1034,238,460,34),23)
	var y=282
	for key in ["yan","feng","zhen","you"]:
		var info=C.SCHOOLS[key]
		var count=w.school_count(key)
		var tier=w.school_tier(key)
		UI.seal(app.modal,info.glyph,Rect2(1034,y,40,40),Color(info.color).darkened(0.2) if count>0 else Color("33403f"))
		UI.label(app.modal,"%s · %s" % [info.name,info.theme],Rect2(1086,y-2,240,26),18,Color(info.color) if count>0 else UI.MUTED,true)
		for i in range(4):
			var pip=Ornament.new(); pip.kind="diamond"; pip.color=Color(info.color) if i<count else Color("33403f")
			pip.position=Vector2(1342+i*24,y+4); pip.size=Vector2(16,16); pip.mouse_filter=Control.MOUSE_FILTER_IGNORE
			app.modal.add_child(pip)
		var effect=("二："+info.tier1) if tier<2 else ("四："+info.tier2)
		UI.label(app.modal,effect,Rect2(1086,y+22,420,22),14,UI.TEXT if tier>0 else UI.DIM)
		y+=56
	var extras=""
	for key in w.sigils: extras+="[color=%s]%s · %d 级[/color]  %s\n" % ["#"+Color(C.SCHOOLS[C.SIGILS[key].school].color).to_html(false),C.SIGILS[key].name,w.sigils[key],C.SIGILS[key].desc]
	extras+="\n[color=#f0b85e]遗物 · %d / 6[/color]\n" % w.relics.size()
	for key in w.relics:
		extras+="%s%s  [color=#9aa39b]%s[/color]\n" % [C.RELICS[key].name," · 已消耗" if key=="old_wick" and w.resurrected else "",C.RELICS[key].desc]
	if w.sigils.is_empty() and w.relics.is_empty(): extras="清理战斗房获得符印，挑战精英与祭灯获得遗物。"
	var details=_details(app.modal,extras,Rect2(1034,512,476,254))
	details.add_theme_font_size_override("normal_font_size",16)
	UI.button(app.modal,"返回战斗",Rect2(1200,806,330,56),app.close_pause,true)
	app.focus_first(app.modal)

static func _details(parent: Control, text: String, rect: Rect2) -> RichTextLabel:
	var node=RichTextLabel.new(); node.bbcode_enabled=true; node.text=text; node.position=rect.position; node.size=rect.size
	node.add_theme_font_size_override("normal_font_size",20); node.add_theme_color_override("default_color",UI.TEXT)
	node.add_theme_constant_override("line_separation",4)
	node.focus_mode=Control.FOCUS_ALL
	parent.add_child(node)
	return node

static func show_map(app) -> void:
	app.paused=true
	var w=app.world as ChapterWorld
	_paper(app,w.biome().name+" · 本章地图","亮着的是你所在的位置。清理过的安全房间可以直接走回去。")
	UI.panel(app.modal,Rect2(90,220,1420,390))
	var map=MapView.new(); map.chapter=w; map.detailed=true; map.position=Vector2(115,236); map.size=Vector2(1370,345)
	app.modal.add_child(map)
	var i=0
	if w.room().cleared:
		for room in w.rooms:
			if room.visited and room.cleared and room.id!=w.room_id and room.type not in ["combat","elite","boss"]:
				var target=int(room.id)
				UI.button(app.modal,"返回 "+w.display_room_name(room),Rect2(120+(i%4)*350,640+int(i/4)*64,320,50),func(): app.close_pause(); w.enter_room(target); Save.save_run(w))
				i+=1
	UI.button(app.modal,"返回战斗",Rect2(1180,817,330,55),app.close_pause,true)
	app.focus_first(app.modal)
