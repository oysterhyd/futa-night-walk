class_name ChapterUI
extends RefCounted

const C=preload("res://content/chapter_content.gd")

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
					draw_line(p,(Vector2(other.gx,other.gy+1)+Vector2(0.5,0.5))*cell,UI.MUTED,2)
			var extent=Vector2(68,32) if detailed else Vector2(10,9)
			draw_rect(Rect2(p-extent,extent*2),UI.GOLD if room.id==chapter.room_id else (UI.TEXT if room.visited else UI.MUTED))
			draw_rect(Rect2(p-extent,extent*2),UI.PARCHMENT,false,1)
			var text=chapter.display_room_name(room) if detailed else C.ROOM_TYPES[room.type].glyph
			draw_string(Content.body_font,p-Vector2(extent.x,0)+Vector2(0,6),text,HORIZONTAL_ALIGNMENT_CENTER,extent.x*2,19 if detailed else 13,UI.PARCHMENT)
			if detailed:
				var status="当前" if room.id==chapter.room_id else ("已清理" if room.visited and room.cleared else "已发现")
				draw_string(Content.body_font,p+Vector2(-68,54),status,HORIZONTAL_ALIGNMENT_CENTER,136,16,UI.MUTED)

static func show_hud(app) -> void:
	app.clear_control(app.page); app.clear_control(app.modal)
	app.labels.clear(); app.bars.clear()
	app.backdrop.visible=false; app.arena.visible=true; app.arena.post.visible=true
	UI.panel(app.page,Rect2(28,23,435,90))
	app.labels.chapter=UI.label(app.page,"",Rect2(48,32,400,37),26,UI.TEXT,true)
	app.labels.subtitle=UI.label(app.page,"",Rect2(49,75,390,28),17,UI.MUTED)
	UI.panel(app.page,Rect2(1190,23,382,112))
	app.labels.counters=UI.label(app.page,"",Rect2(1210,28,345,28),17)
	var map=MapView.new(); map.chapter=app.world; map.position=Vector2(1210,58); map.size=Vector2(342,66)
	app.page.add_child(map); app.labels.map=map
	UI.panel(app.page,Rect2(28,803,330,74))
	app.labels.hp=UI.label(app.page,"",Rect2(46,810,290,28),19)
	app.bars.hp=UI.bar(app.page,Rect2(46,851,290,8),UI.GOLD)
	UI.panel(app.page,Rect2(385,803,275,74))
	app.labels.gear_icon=UI.image(app.page,Content.chapter_icon("gear",app.world.gear),Rect2(398,813,55,54))
	app.labels.gear=UI.label(app.page,"",Rect2(465,808,180,33),24,UI.TEXT,true)
	app.labels.gear_note=UI.label(app.page,"",Rect2(465,846,180,25),16,UI.MUTED)
	UI.panel(app.page,Rect2(680,803,275,74))
	app.labels.skill_icon=UI.image(app.page,Content.chapter_icon("skill",app.world.skill),Rect2(693,813,55,54))
	app.labels.skill=UI.label(app.page,"",Rect2(760,808,180,33),24,UI.TEXT,true)
	app.labels.skill_note=UI.label(app.page,"",Rect2(760,846,180,25),16,UI.MUTED)
	app.bars.skill=UI.bar(app.page,Rect2(701,875,236,3),UI.JADE)
	UI.panel(app.page,Rect2(975,803,185,74))
	app.labels.dash=UI.label(app.page,"",Rect2(994,811,155,29),24,UI.TEXT,true)
	app.labels.dash_note=UI.label(app.page,"",Rect2(994,847,155,23),16,UI.MUTED)
	UI.button(app.page,"B · 行囊",Rect2(1190,817,168,54),app.show_inventory)
	UI.button(app.page,"暂停",Rect2(1380,817,192,54),app.show_pause)
	UI.panel(app.page,Rect2(400,770,800,31))
	app.labels.hint=UI.label(app.page,"",Rect2(415,771,770,27),18,UI.TEXT)
	app.labels.hint.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	app.labels.buff_panel=UI.panel(app.page,Rect2(28,752,245,36))
	app.labels.buffs=UI.label(app.page,"",Rect2(46,756,208,27),16,UI.JADE)
	app.notice_label=UI.label(app.page,"",Rect2(400,143,800,40),23,UI.GOLD,true)
	app.notice_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	UI.panel(app.page,Rect2(555,27,490,69)).name="BossPanel"
	app.labels.boss=UI.label(app.page,"",Rect2(575,32,450,31),24,UI.GOLD,true)
	app.bars.boss=UI.bar(app.page,Rect2(575,77,450,7),UI.GOLD)
	update_hud(app)

static func update_hud(app) -> void:
	if app.labels.is_empty() or not app.labels.has("gear"): return
	var w=app.world as ChapterWorld
	app.labels.chapter.text=w.biome().chapter+" / "+w.room_name()
	var room_state="街巷已清" if w.room().cleared else ("首领战" if w.room().type=="boss" else "敌潮 %d / %d" % [w.wave_index,w.wave_count])
	app.labels.subtitle.text="%02d:%02d  ·  %s" % [int(w.time)/60,int(w.time)%60,room_state]
	app.labels.counters.text="铜钱 %d   斩祟 %d   难度 %d" % [w.coins,w.kills,w.difficulty+1]
	app.labels.hp.text="生命 %d / %d%s" % [maxi(0,int(w.player.hp)),int(w.player.max_hp),"  护盾 %d" % w.shield if w.shield>0 else ""]
	app.bars.hp.value=maxf(0,w.player.hp)/w.player.max_hp*100
	app.labels.gear.text=C.GEAR[w.gear].name
	app.labels.gear_icon.texture=Content.chapter_icon("gear",w.gear)
	app.labels.gear_note.text="RT · 普攻 / %d 阶" % w.gear_rank if app.controller_input else "左键 · 普攻 / %d 阶" % w.gear_rank
	app.labels.skill.text=C.SKILLS[w.skill].name
	app.labels.skill_icon.texture=Content.chapter_icon("skill",w.skill)
	app.labels.skill_note.text=("RB" if app.controller_input else "右键")+" · "+("就绪" if w.skill_cd<=0 else "%.1f 秒" % w.skill_cd)+" / %d 阶" % w.skill_rank
	app.bars.skill.value=100*(1-w.skill_cd/C.SKILLS[w.skill].cooldown)
	app.labels.dash.text="闪避 %d / 2" % w.dash_charges
	app.labels.dash_note.text=("LT" if app.controller_input else "空格")+" · "+("就绪" if w.dash_charges==2 else "%.1f 秒" % maxf(0,w.dash_recharge))
	app.labels.hint.text=w.interaction_hint()
	if app.controller_input:
		app.labels.hint.text=app.labels.hint.text.replace("长按 E","长按 Y").replace("E ·","Y ·").replace("左键攻击  ·  右键技能  ·  空格闪避  ·  Tab 地图","RT 攻击  ·  RB 技能  ·  LT 闪避  ·  LB 地图")
	var buffs: Array=[]
	if w.shadow_time>0: buffs.append("影分 %.1f秒" % w.shadow_time)
	if w.counter_time>0 and (w.sigils.get("counter",0)>0 or "fox_tooth" in w.relics or w.character=="swordswoman"): buffs.append("反击强化")
	if w.echo_ready and w.sigils.get("echo",0)>0: buffs.append("符法余势")
	if w.wind_time>0 and w.sigils.get("wind",0)>0: buffs.append("踏风 ×%d" % w.wind_stacks)
	app.labels.buffs.text=" · ".join(buffs.slice(0,2)); app.labels.buffs.tooltip_text=" / ".join(buffs)
	app.labels.buffs.visible=not buffs.is_empty(); app.labels.buff_panel.visible=not buffs.is_empty()
	app.labels.map.queue_redraw()
	var bosses=w.mobs.filter(func(m): return m.boss and m.hp>0)
	var has_boss=not bosses.is_empty()
	app.page.get_node("BossPanel").visible=has_boss; app.labels.boss.visible=has_boss; app.bars.boss.visible=has_boss
	if has_boss:
		app.labels.boss.text=w.biome().boss+(" · 狂暴" if bosses[0].enraged else "")
		app.bars.boss.value=bosses[0].hp/bosses[0].max_hp*100
	Sound.battle_state(w.stage,has_boss,app.paused,w.phase!="active")
	app.arena.interact_hint="长按 E · 点灯" if w.shrine_started else "E · 开始祭灯"
	app.notice_label.visible=app.notice_time>0; app.notice_label.modulate.a=minf(1,app.notice_time)
	if w.phase=="active" and not app.paused and app.intro_stage!=w.stage: app.show_chapter_banner()

static func _paper(app,title: String,subtitle: String) -> void:
	app.clear_control(app.modal)
	var dim=ColorRect.new(); dim.color=Color(UI.PARCHMENT,0.97); dim.size=Vector2(1600,900); app.modal.add_child(dim)
	UI.label(app.modal,title,Rect2(80,60,1440,65),43,UI.TEXT,true).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	UI.paragraph(app.modal,subtitle,Rect2(180,136,1240,68),21).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER

static func show_choices(app) -> void:
	var w=app.world as ChapterWorld
	_paper(app,w.offer_title,w.offer_subtitle)
	var count=w.choices.size()
	var compact=count>4
	var columns=4 if count>=4 else count
	var width=340 if columns==4 else (430 if columns==3 else 530)
	var stride=width+25
	var left=(1600-(columns*width+(columns-1)*25))*0.5
	for i in range(count):
		var info=w.chapter_choice_info(w.choices[i])
		var x=left+(i%columns)*stride
		var y=218+int(i/columns)*320 if compact else 255
		var height=258 if compact else 375
		UI.panel(app.modal,Rect2(x,y,width,height),info.color)
		UI.label(app.modal,info.tag,Rect2(x+22,y+27,width-44,25),16,info.color)
		var prefix=w.choices[i].get_slice(":",0)
		var key=w.choices[i].get_slice(":",1)
		var icon: Texture2D
		if prefix=="g": icon=Content.chapter_icon("gear",key)
		elif prefix=="s": icon=Content.chapter_icon("skill",key)
		elif prefix=="gm" or prefix=="shop" and key=="gear": icon=Content.chapter_icon("gear",w.gear)
		elif prefix=="sm" or prefix=="shop" and key=="skill": icon=Content.chapter_icon("skill",w.skill)
		elif prefix=="shop" and key=="relic": icon=app.arena.prop_texture(7)
		if not compact:
			if icon!=null: UI.image(app.modal,icon,Rect2(x+22,y+57,96,92))
			else: UI.seal(app.modal,info.glyph,Rect2(x+22,y+61,78,78),info.color)
		elif icon!=null: UI.image(app.modal,icon,Rect2(x+width-57,y+29,34,34))
		UI.label(app.modal,info.name,Rect2(x+22,y+(52 if compact else 155),width-44,40),27,UI.TEXT,true)
		UI.paragraph(app.modal,info.desc,Rect2(x+22,y+(98 if compact else 213),width-44,120 if compact else 108),17 if compact else 18,UI.TEXT)
		UI.paragraph(app.modal,info.note,Rect2(x+22,y+(224 if compact else 328),width-44,30 if compact else 34),15)
		var button=UI.button(app.modal,"%d · 选择" % (i+1),Rect2(x,y+height+12,width,47 if compact else 57),func(): app.select_choice(i),i==0)
		button.disabled=not w.can_choose(w.choices[i])
	if w.phase=="upgrade" and w.offer_kind=="growth":
		var refresh=UI.button(app.modal,"R · 刷新候选 / 剩余 %d 次" % w.rerolls,Rect2(565,805,470,52),func(): if w.reroll(): app.show_choices(); Save.save_run(w))
		refresh.disabled=w.rerolls<=0
	app.focus_first(app.modal)

static func show_result(app) -> void:
	app.screen="result"; app.paused=false
	var w=app.world as ChapterWorld
	app.shell(("无明已破 · 四章通关" if w is CampaignWorld else "灯市已清 · 第一章通关") if w.victory else "夜行结束 · 战败结算","灯烬已存入营地。下一局可以更换角色、装备与技能。")
	UI.panel(app.page,Rect2(85,245,505,440))
	UI.label(app.page,"+ %d" % app.last_result.get("reward_total",app.last_result.reward),Rect2(120,270,440,95),69,UI.GOLD,true)
	UI.label(app.page,"获得灯烬",Rect2(125,365,410,45),26,UI.TEXT,true)
	UI.paragraph(app.page,"斩祟 %d   首领 %d\n探索 %d / %d 房间\n耗时 %02d:%02d\n承受伤害 %d" % [w.kills,w.bosses,app.last_result.get("rooms_cleared",w.rooms.filter(func(r): return r.visited).size()),56 if w is CampaignWorld else 14,int(w.time)/60,int(w.time)%60,w.total_damage_taken],Rect2(125,440,410,175),25,UI.TEXT)
	UI.label(app.page,"伤害来源",Rect2(690,242,750,45),28,UI.GOLD,true)
	var keys=w.damage_by_skill.keys()
	keys.sort_custom(func(a,b): return w.damage_by_skill[a]>w.damage_by_skill[b])
	for i in range(mini(7,keys.size())):
		UI.label(app.page,C.damage_name(keys[i]),Rect2(695,315+i*47,470,35),23)
		UI.label(app.page,str(int(w.damage_by_skill[keys[i]])),Rect2(1210,315+i*47,245,35),23,UI.GOLD)
	UI.label(app.page,"%s / %d 阶   +   %s / %d 阶" % [C.GEAR[w.gear].name,w.gear_rank,C.SKILLS[w.skill].name,w.skill_rank],Rect2(695,690,800,38),24,UI.TEXT,true)
	if not app.last_result.get("unlocked",[]).is_empty(): UI.label(app.page,"解锁成就："+"、".join(app.last_result.unlocked),Rect2(85,735,1400,37),20,UI.GOLD)
	UI.button(app.page,"再战一局",Rect2(85,805,300,58),app.show_prepare,true)
	UI.button(app.page,"查看本局构筑",Rect2(415,805,340,58),func(): show_record(app,app.last_result))
	UI.button(app.page,"返回渡口",Rect2(785,805,280,58),app.show_menu)
	app.focus_first()

static func show_record(app, item: Dictionary) -> void:
	_paper(app,Content.data.characters[item.character].name+" · 对局构筑详情","斩祟 %d   耗时 %02d:%02d   承受伤害 %d" % [item.kills,int(item.time)/60,int(item.time)%60,item.get("damage_taken",0)])
	var equipment=C.GEAR[item.gear]; var ability=C.SKILLS[item.skill]
	var text="[color=#ad3527]装备 · %s / %d 阶[/color]\n%s\n" % [equipment.name,item.get("gear_rank",1),equipment.desc]
	if item.get("gear_mod",-1)>=0: text+=equipment.mods[item.gear_mod]+"\n"
	text+="\n[color=#ad3527]技能 · %s / %d 阶[/color]\n%s\n" % [ability.name,item.get("skill_rank",1),ability.desc]
	if item.get("skill_mod",-1)>=0: text+=ability.mods[item.skill_mod]+"\n"
	text+="\n[color=#ad3527]基础强化[/color]\n"
	for key in item.get("attributes",{}): text+="%s × %d\n" % [C.ATTRIBUTES[key].name,item.attributes[key]]
	_details(app.modal,text,Rect2(105,225,610,525))
	var extras="[color=#ad3527]符印[/color]\n"
	for key in item.get("sigils",{}): extras+="%s · %d 级\n%s\n\n" % [C.SIGILS[key].name,item.sigils[key],C.SIGILS[key].desc]
	extras+="[color=#ad3527]遗物[/color]\n"
	for key in item.get("relics",[]): extras+=C.RELICS[key].name+"\n"+C.RELICS[key].desc+"\n\n"
	_details(app.modal,extras,Rect2(810,225,685,525))
	UI.button(app.modal,"返回结算" if app.screen=="result" else "返回记录列表",Rect2(1130,805,365,58),func(): app.clear_control(app.modal); app.focus_first(),true)
	app.focus_first(app.modal)

static func show_tutorial(app) -> void:
	app.paused=true
	_paper(app,"先清街巷，再破灯魁","移动、攻击、闪避和技能。其他操作都在安全房间完成。")
	var rows=[["攻","左键 / RT · 普通攻击","朝鼠标或右摇杆方向攻击，支持长按。"],["闪","空格 / LT · 闪避","共有两次充能。躲过红色预警，再抓空隙反击。"],["术","右键 / RB · 主动技能","装备一件、技能一个。技能冷却结束后即可再用。"]]
	for i in range(rows.size()):
		var y=245+i*120
		UI.seal(app.modal,rows[i][0],Rect2(350,y,78,78))
		UI.label(app.modal,rows[i][1],Rect2(470,y,780,41),28,UI.TEXT,true)
		UI.label(app.modal,rows[i][2],Rect2(472,y+48,790,35),21)
	UI.label(app.modal,"E / Y 交互与过门  ·  B 行囊  ·  Tab 地图  ·  Esc 暂停",Rect2(300,651,1000,39),21).horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	UI.button(app.modal,"进入灯市",Rect2(555,735,490,62),func(): Save.profile.tutorial_seen=true; Save.save_profile(); app.paused=false; app.clear_control(app.modal); app.choice_phase=""; app.update_phase(),true)
	app.focus_first(app.modal)

static func show_inventory(app) -> void:
	app.paused=true
	var w=app.world as ChapterWorld
	_paper(app,"行囊 · 当前构筑","一个装备位，一个主动技能位。符印与遗物独立生效。")
	var text="[color=#ad3527]装备 · %s / %d 阶[/color]\n%s\n" % [C.GEAR[w.gear].name,w.gear_rank,C.GEAR[w.gear].desc]
	if w.gear_mod>=0: text+=C.GEAR[w.gear].mods[w.gear_mod]+"\n"
	text+="\n[color=#ad3527]技能 · %s / %d 阶[/color]\n%s\n" % [C.SKILLS[w.skill].name,w.skill_rank,C.SKILLS[w.skill].desc]
	if w.skill_mod>=0: text+=C.SKILLS[w.skill].mods[w.skill_mod]+"\n"
	text+="\n生命 %d / %d   护盾 %d\n伤害加成 %d%%   暴击率 %d%%\n攻速加成 %d%%   技能冷却缩短 %d%%\n闪避每 %.1f 秒恢复一次\n" % [w.player.hp,w.player.max_hp,w.shield,(w.stat("damage")-1)*100,w.stat("crit")*100,w.stat("attack_speed")*100,w.stat("haste")*100,w._dash_interval()]
	_details(app.modal,text,Rect2(105,225,610,530))
	var extras="[color=#ad3527]符印 · %d / 6[/color]\n" % w.sigils.size()
	for key in w.sigils: extras+="%s · %d 级\n%s\n\n" % [C.SIGILS[key].name,w.sigils[key],C.SIGILS[key].desc]
	extras+="[color=#ad3527]遗物 · %d / 6[/color]\n" % w.relics.size()
	for key in w.relics:
		extras+="%s%s\n%s\n\n" % [C.RELICS[key].name," · 已消耗" if key=="old_wick" and w.resurrected else "",C.RELICS[key].desc]
	if w.sigils.is_empty() and w.relics.is_empty(): extras+="清理战斗房获得符印，挑战精英与祭灯获得遗物。"
	_details(app.modal,extras,Rect2(810,225,685,530))
	UI.button(app.modal,"返回战斗",Rect2(1150,805,330,56),app.close_pause,true)
	app.focus_first(app.modal)

static func _details(parent: Control, text: String, rect: Rect2) -> void:
	var node=RichTextLabel.new(); node.bbcode_enabled=true; node.text=text; node.position=rect.position; node.size=rect.size
	node.add_theme_font_size_override("normal_font_size",21); node.add_theme_color_override("default_color",UI.TEXT)
	node.focus_mode=Control.FOCUS_ALL
	parent.add_child(node)

static func show_map(app) -> void:
	app.paused=true
	var w=app.world as ChapterWorld
	_paper(app,w.biome().name+" · 本章地图","朱红标记当前位置。已访问的安全房间可以快速返回。")
	var map=MapView.new(); map.chapter=w; map.detailed=true; map.position=Vector2(115,240); map.size=Vector2(1370,345)
	app.modal.add_child(map)
	var i=0
	if w.room().cleared:
		for room in w.rooms:
			if room.visited and room.cleared and room.id!=w.room_id and room.type not in ["combat","elite","boss"]:
				var target=int(room.id)
				UI.button(app.modal,"返回 "+w.display_room_name(room),Rect2(120+(i%4)*350,640+int(i/4)*64,320,48),func(): app.close_pause(); w.enter_room(target); Save.save_run(w))
				i+=1
	UI.button(app.modal,"返回战斗",Rect2(1150,817,330,55),app.close_pause,true)
	app.focus_first(app.modal)
