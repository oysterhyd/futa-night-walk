class_name CampaignContent
extends RefCounted

const CHAPTERS=[
	{"name":"灯市旧巷","entry":"灯市入口","boss_room":"百灯院","rest":"古道茶摊","gear":"兵器铺","skill":"废亭符谱","shop":"夜市货郎","event":"巷中奇遇","shrine":"祭灯台","elite":"血契院","secret":"封门小巷","combat":["挂灯长巷","纸扎后院","断桥街口","旧市广场"],"rule":"击破灯柱，削弱灯魁。","hp":2700.0,"environment":"none"},
	{"name":"白狐渡","entry":"白狐渡口","boss_room":"望月水榭","rest":"河边茶棚","gear":"渡口兵器棚","skill":"水榭符谱","shop":"摆渡货郎","event":"渡口奇遇","shrine":"河灯祭台","elite":"猎狐滩","secret":"芦苇暗汊","combat":["芦苇浅滩","旧船栈桥","狐火河岸","望月长堤"],"rule":"涨潮前离开水纹；狐姬突进时向侧面闪避。","hp":4100.0,"environment":"tide"},
	{"name":"沉钟寺","entry":"沉钟山门","boss_room":"大钟殿","rest":"寺中斋堂","gear":"武僧兵刃架","skill":"藏经阁","shop":"山门行商","event":"古寺奇遇","shrine":"供灯台","elite":"护法院","secret":"地藏暗室","combat":["断碑石阶","回廊钟庭","护法禅院","残钟广场"],"rule":"钟声落下前离开预警；重击与控制可打断守卫。","hp":5700.0,"environment":"bell"},
	{"name":"无明塔","entry":"封妖塔门","boss_room":"无明天台","rest":"守塔歇脚处","gear":"守塔兵库","skill":"镇塔符谱","shop":"塔中行商","event":"塔中奇遇","shrine":"镇塔灯阵","elite":"镇守回廊","secret":"夹层密库","combat":["封印底层","倒悬回廊","焚符高阁","无明长阶"],"rule":"封印轮流爆发；塔主换招时留出闪避。","hp":7600.0,"environment":"seal"},
]
const BOONS=[
	{"name":"整备再行","glyph":"备","desc":"回复 35% 最大生命，刷新次数 +1。"},
	{"name":"破敌之法","glyph":"攻","desc":"所有伤害额外增加 10%。"},
	{"name":"精研符术","glyph":"术","desc":"技能冷却额外缩短 8%，仍受 40% 上限约束。"},
]

const EVENTS = [
	[
		{"name":"河灯漂来","text":"一盏河灯卡在栈桥下面，灯内藏着干净的草履。摆渡人也愿意出售一枚旧铜钱。","choices":["当前生命减少 15 点（最低保留 1 点），获得芦苇草履。","花费 35 铜钱，获得摆渡铜钱：商店价格降低 20%。","离开栈桥。"]},
		{"name":"狐祠照影","text":"狐祠里供着一面铜镜。取镜须以气血相换；留下铜钱，也能换来两张改运符。","choices":["最大生命减少 15 点，获得狐纹铜镜。","花费 30 铜钱，获得两次刷新。","离开狐祠。"]},
	],
	[
		{"name":"残钟裂隙","text":"守钟僧出售一片旧钟铜。敲响残钟可以求符，也会惊动下一处守卫。","choices":["花费 40 铜钱，获得残钟铜片，降低首领失衡阈值。","获得两次刷新；下一间战斗额外出现一名精英。","绕过残钟。"]},
		{"name":"藏经旧砚","text":"抄经人的旧砚能加深符印。旁边留有改写符谱的方法，可以重新选择技能形态。","choices":["最大生命减少 15 点，获得旧砚：新获得的符印直接达到二级。","花费 25 铜钱，重新选择主动技能改造。技能须达到二阶。","合上经书。"]},
	],
	[
		{"name":"封塔密库","text":"密库外系着示警铜铃。拆下钱袋会惊动守卫；守库人另售一把专门镇压塔主的铜钥。","choices":["获得 70 铜钱；下一间战斗额外出现一名精英。","花费 45 铜钱，获得封塔铜钥：对首领伤害 +20%，对其他敌人伤害 -8%。","离开密库。"]},
		{"name":"焚符炉","text":"炉中留着一张余烬面具。取面具会受到炉火侵蚀，守炉人也出售疗伤药。","choices":["当前生命减少 20 点（最低保留 1 点），获得余烬面具；下一间战斗敌人伤害 +15%。","花费 30 铜钱，回复 40% 最大生命。","离开焚符炉。"]},
	],
]

static func room_name(chapter: int, room: Dictionary) -> String:
	var definition=CHAPTERS[clampi(chapter-1,0,3)]
	if room.type=="combat": return definition.combat[room.rank-1]
	if room.type=="boss": return definition.boss_room
	return definition[room.type]
