class_name ChapterContent
extends RefCounted

# Values are shared by the simulation and UI. Descriptions state the actual rules.
const GEAR = {
	"seal": {"name":"朱砂符匣","glyph":"符","desc":"连续掷出火符，命中造成 22 点伤害，并附带灼烧。","damage":22.0,"interval":0.35,"reach":650.0,"source":"fire_talisman","tags":["投射","火"],"mods":["散射：一次发射三枚火符，每枚伤害为 55%。","穿透：火符穿透两名敌人，伤害提升 15%。"]},
	"sword": {"name":"桃木剑","glyph":"剑","desc":"向前连斩，前两击造成 30 点伤害，第三击造成 45 点伤害。","damage":30.0,"interval":0.36,"reach":145.0,"source":"piercing_spike","tags":["近战"],"mods":["剑气：第三击追加一道贯穿剑气。","横扫：斩击范围扩大 35%，击退距离增加。"]},
	"needle": {"name":"毒针筒","glyph":"针","desc":"连续发射毒针，命中造成 14 点伤害，并附带 3 秒剧毒。","damage":14.0,"interval":0.22,"reach":750.0,"source":"poison_mist","tags":["投射","毒"],"mods":["连针：一次发射两枚毒针，每枚伤害为 70%。","蚀甲：毒针穿透一名敌人，毒伤提升 40%。"]},
	"hammer": {"name":"伏魔槌","glyph":"槌","desc":"向前重砸，造成 68 点范围伤害，并打断普通敌人的蓄力。","damage":68.0,"interval":0.78,"reach":175.0,"source":"armor_breaker","tags":["近战","重击"],"mods":["震地：重砸产生 220 像素的圆形震波。","破甲：命中使敌人受到的伤害增加 25%，持续 3 秒。"]},
	"wheel": {"name":"雷纹轮","glyph":"轮","desc":"掷出雷轮，命中造成 25 点伤害，穿透三名敌人并短暂麻痹。","damage":25.0,"interval":0.48,"reach":650.0,"source":"thunder_mark","tags":["投射","雷"],"mods":["双轮：掷出两枚雷轮，每枚伤害为 70%。","引雷：雷轮命中后，额外电击附近两名敌人。"]},
	"sand": {"name":"寒砂壶","glyph":"砂","desc":"向前喷出三道霜砂，每道造成 13 点伤害，命中使敌人减速。","damage":13.0,"interval":0.46,"reach":380.0,"source":"frost_sand","tags":["投射","霜"],"mods":["碎冰：命中减速敌人时，霜砂伤害增加 35%。","寒潮：每次喷出五道霜砂，射程增加 25%。"]},
}
const SKILLS = {
	"pulse": {"name":"镇魂印","glyph":"镇","desc":"震退周围 270 像素内的敌人，造成 75 点伤害，清除范围内敌弹。冷却 9 秒。","cooldown":9.0,"source":"pulse","tags":["控制"],"mods":["震慑：范围增加 25%，普通敌人眩晕延长至 1.5 秒。","护身：释放后获得 20 点护盾。"]},
	"poison": {"name":"毒雾符","glyph":"毒","desc":"在瞄准方向铺下毒池，半径 150 像素，持续 5 秒。每次毒雾伤害为 12 点。冷却 8 秒。","cooldown":8.0,"source":"poison_mist","tags":["毒","范围"],"mods":["毒潭：持续时间增加 3 秒，范围增加 20%。","聚毒：毒池将普通敌人拉向中心。"]},
	"shadow": {"name":"影分符","glyph":"影","desc":"召出两道残影，持续 5 秒。普攻时各射出穿透符弹，造成 35% 普攻伤害，不触发符印。冷却 11 秒。","cooldown":11.0,"source":"shadow_twin","tags":["召唤"],"mods":["三影：额外召出一道残影。","余影：残影持续时间增加 3 秒。"]},
	"binding": {"name":"缚地咒","glyph":"缚","desc":"在瞄准方向布下缚地阵，造成 45 点伤害，将普通敌人拉向中心并定身 1.5 秒。冷却 8 秒。","cooldown":8.0,"source":"binding_hex","tags":["控制","毒"],"mods":["压阵：阵内敌人受到的伤害增加 25%，持续 3 秒。","回阵：技能范围增加 35%。"]},
	"blast": {"name":"爆焰丸","glyph":"爆","desc":"向瞄准方向投出丹丸，落地爆炸，造成 110 点范围伤害并附带灼烧。冷却 7 秒。","cooldown":7.0,"source":"blast_pill","tags":["火","范围"],"mods":["连爆：爆炸后追加两次小范围爆炸。","烈焰：爆炸范围增加 30%，灼烧伤害翻倍。"]},
	"frost": {"name":"霜环","glyph":"霜","desc":"释放 240 像素的霜环，造成 55 点伤害，冻结普通敌人 1 秒。冷却 8 秒。","cooldown":8.0,"source":"frost_ring","tags":["霜","控制"],"mods":["冰封：冻结延长至 1.8 秒，范围增加 20%。","裂冰：命中使敌人受到的伤害增加 25%，持续 2.5 秒。"]},
}
const SIGILS = {
	"counter": {"name":"回身斩","glyph":"斩","desc":"每级：闪避后 2 秒内，首次普攻伤害 +30%，近战范围 +10%。","tags":["近战","闪避"]},
	"fire": {"name":"朱砂火引","glyph":"火","desc":"每级：普攻附带 3 秒灼烧，每秒造成 4 点伤害。","tags":["火","普攻"]},
	"toxin": {"name":"蚀骨毒","glyph":"毒","desc":"每级：剧毒持续伤害 +25%，剧毒持续时间 +0.5 秒。","tags":["毒"]},
	"ember": {"name":"余烬回响","glyph":"烬","desc":"每级：普攻命中燃烧敌人时，技能冷却减少 0.2 秒。每 0.5 秒触发一次。","tags":["火","技能"]},
	"execution": {"name":"断祟","glyph":"断","desc":"每级：对生命低于 35% 的敌人，伤害 +20%。","tags":["普攻"]},
	"precision": {"name":"定心","glyph":"定","desc":"每级：暴击率 +8%。暴击造成 180% 伤害。","tags":["普攻"]},
	"wind": {"name":"踏风","glyph":"风","desc":"每级：击杀后移速 +8%，持续 4 秒，可叠加三层。","tags":["击杀"]},
	"ward": {"name":"护魂","glyph":"护","desc":"每级：击败减速或眩晕敌人时获得 5 点护盾。护盾上限 30 点。","tags":["控制"]},
	"cleave": {"name":"破阵","glyph":"破","desc":"每级：每第四次普攻追加一次 160 像素范围斩击，造成 18 点伤害。","tags":["普攻","范围"]},
	"echo": {"name":"符法余势","glyph":"势","desc":"每级：发动技能后的首次普攻伤害 +35%。","tags":["技能","普攻"]},
	"leech": {"name":"回元","glyph":"元","desc":"每级：普攻命中精英或首领时回复 1 点生命。每秒触发一次。","tags":["普攻"]},
	"reaction": {"name":"三才符","glyph":"才","desc":"每级：燃瘴、融霜、引雷的伤害 +25%。","tags":["火","毒","雷","霜"]},
	"reach": {"name":"长锋","glyph":"锋","desc":"每级：近战攻击范围与普攻弹道射程 +8%。","tags":["普攻"]},
	"pierce": {"name":"穿云","glyph":"穿","desc":"每级：投射普攻额外穿透一名敌人。剑气也可生效。","tags":["投射"]},
	"frozen": {"name":"碎寒","glyph":"寒","desc":"每级：对减速或眩晕中的敌人，所有伤害 +12%。","tags":["控制"]},
	"focus": {"name":"凝神","glyph":"凝","desc":"每级：主动技能伤害 +8%。","tags":["技能"]},
}
const RELICS = {
	"fox_tooth": {"name":"灵狐尖牙","glyph":"牙","desc":"闪避后的首次普攻伤害 +50%。"},
	"silver": {"name":"清音银铃","glyph":"铃","desc":"普攻命中精英或首领时，技能冷却减少 0.4 秒。每 0.8 秒触发一次。"},
	"map": {"name":"夜行舆图","glyph":"图","desc":"揭示整章房间类型，并显示隐藏巷道。移动速度 +8%。"},
	"old_wick": {"name":"不灭灯芯","glyph":"芯","desc":"本局首次受到致命伤害时，回复 30% 最大生命并获得 3 秒无敌。"},
	"red_thread": {"name":"赤绳同心","glyph":"结","desc":"生命低于 50% 时，所有伤害 +30%。"},
	"green_lamp": {"name":"青铜古灯","glyph":"灯","desc":"祭灯引导速度翻倍。祭灯成功额外获得 20 铜钱。"},
	"broken_coin": {"name":"辟邪铜钱","glyph":"钱","desc":"每次清房额外获得 8 铜钱。拾取铜钱后的首次普攻伤害 +25%。"},
	"drum": {"name":"醒魂木","glyph":"木","desc":"发动技能时，清除身周 180 像素内的普通敌弹。技能伤害 +15%。"},
	"river_coin": {"name":"摆渡铜钱","glyph":"渡","desc":"商店商品价格降低 20%。奇遇交易不打折。"},
	"reed_sandal": {"name":"芦苇草履","glyph":"履","desc":"闪避速度与距离 +20%，无敌时长不变。"},
	"bell_shard": {"name":"残钟铜片","glyph":"钟","desc":"首领失衡阈值降低 25%，失衡持续时间增加 0.4 秒。"},
	"inkstone": {"name":"旧砚","glyph":"砚","desc":"新获得的符印直接达到二级。已有符印每次仍升一级。"},
	"temple_beads": {"name":"断绳念珠","glyph":"珠","desc":"发动技能时回复 2 点生命，每 3 秒触发一次。禁疗时不生效。"},
	"tower_key": {"name":"封塔铜钥","glyph":"钥","desc":"对首领伤害 +20%，对其他敌人伤害 -8%。"},
	"fox_mirror": {"name":"狐纹铜镜","glyph":"镜","desc":"影分符额外召出一道残影；携带其他技能时，普攻伤害 +10%。"},
	"cinder_mask": {"name":"余烬面具","glyph":"面","desc":"生命低于 50% 时，火属性伤害 +25%。"},
}
const ATTRIBUTES = {
	"power": {"name":"攻击强化","glyph":"攻","desc":"所有伤害 +10%。"},
	"speed": {"name":"攻速强化","glyph":"速","desc":"普通攻击速度 +8%。"},
	"health": {"name":"体魄强化","glyph":"命","desc":"生命上限 +15，并回复 15 点生命。"},
	"haste": {"name":"技能强化","glyph":"术","desc":"技能冷却缩短 8%，最多缩短 40%。"},
}
const ROOM_TYPES = {
	"entry":{"name":"灯市入口","glyph":"入","reward":"前方四间战斗房，尽头是灯魁。"},
	"combat":{"name":"清理街巷","glyph":"战","reward":"属性或符印三选一"},
	"gear":{"name":"兵器铺","glyph":"兵","reward":"更换唯一装备"},
	"skill":{"name":"废亭符谱","glyph":"术","reward":"更换唯一技能"},
	"shop":{"name":"夜市货郎","glyph":"市","reward":"铜钱购买回复、强化与遗物"},
	"event":{"name":"巷中奇遇","glyph":"遇","reward":"选择收益与代价"},
	"shrine":{"name":"祭灯台","glyph":"灯","reward":"抵挡两波敌潮，选择遗物"},
	"elite":{"name":"血契院","glyph":"险","reward":"击败精英，选择遗物"},
	"rest":{"name":"古道茶摊","glyph":"茶","reward":"回复生命或强化装备"},
	"boss":{"name":"百灯院","glyph":"魁","reward":"击败百目灯魁，完成第一章"},
	"secret":{"name":"封门小巷","glyph":"藏","reward":"击败 35 名敌人后开启"},
}
const MAP = [[0,0,"entry",0],[1,0,"combat",1],[2,0,"combat",2],[3,0,"combat",3],[4,0,"combat",4],[5,0,"rest",0],[6,0,"boss",5],[1,-1,"gear",0],[2,1,"skill",0],[2,-1,"shop",0],[3,1,"event",0],[3,-1,"shrine",3],[4,-1,"elite",4],[0,1,"secret",0]]

static func damage_name(source: String) -> String:
	if source=="fire_talisman": return "火符与灼烧"
	if source=="poison_mist": return "毒针与毒雾"
	if source=="pulse": return "镇魂印"
	if source=="echo_mark": return "破阵斩击"
	for key in GEAR:
		if GEAR[key].source==source: return GEAR[key].name
	for key in SKILLS:
		if SKILLS[key].source==source: return SKILLS[key].name
	return source.trim_prefix("reaction:")
const EVENT_TEXT = [
	{"name":"纸扎铺","text":"铺主把一张护身纸符推到桌边。要拿它，得用气血换。","choices":["最大生命 -15，获得一件遗物。","花费 20 铜钱，回复 35 点生命。","离开纸扎铺。"]},
	{"name":"落锁的箱子","text":"箱上缠着一圈红线。砸开锁能取钱，也会惊动巷里的妖鬼。","choices":["取走 45 铜钱，下一间战斗额外出现一名精英。","拆下符纸，获得一次刷新。","不碰箱子。"]},
	{"name":"残页符谱","text":"石桌上压着两页符谱。墨迹尚清，只能带走一页。","choices":["获得一次符印选择，下间战斗敌人伤害 +15%。","获得攻击强化，当前生命减少 15 点。","离开石桌。"]},
	{"name":"旧灯换芯","text":"老灯匠坐在巷口。他能换掉焦黑灯芯，也能替兵器刻一道符。","choices":["花费 25 铜钱，回复全部生命。","花费 30 铜钱，装备升一阶。","继续赶路。"]},
]
