class_name Lore
extends RefCounted

# 世界观、剧情与见闻。所有剧情文字集中在这里，便于统一语气。
# 语气约定：短句，具体的物件和动作，不用四字堆砌，不替玩家抒情。

const IMAGES = {
	"title": "res://assets/images/story/title-night.jpg",
	"ferry": "res://assets/images/story/prologue-ferry.jpg",
	"market": "res://assets/images/story/chapter-market.jpg",
	"fox": "res://assets/images/story/chapter-fox.jpg",
	"temple": "res://assets/images/story/chapter-temple.jpg",
	"tower": "res://assets/images/story/chapter-tower.jpg",
	"dawn": "res://assets/images/story/ending-dawn.jpg",
}

const TAGLINE = "冬至夜，江对岸的塔灯灭了。\n天再没亮过。"

const PROLOGUE = [
	{"image":"ferry","lines":["渡口镇有条老规矩：冬至这一夜，江对岸无明塔顶的长明灯，要点到天亮。","灯照着江面。镇上的人说，走了的亲人会借这点光，回家看一眼。"]},
	{"image":"market","lines":["今年冬至，灯在子时前灭了。","天没有亮。到第三夜，扎纸铺里的纸人自己走上了街。"]},
	{"image":"tower","lines":["守塔的是宿灯。他守那盏灯三十年，从没让它灭过。","塔门从里面锁着。喊了三夜，没有人应。"]},
]

const PROLOGUE_CHARACTER = {
	"keeper": {"image":"ferry","lines":["你是宿灯唯一的徒弟。","灯油、火种、一盏旧提灯。他教你的，够用了。"]},
	"swordswoman": {"image":"temple","lines":["听雨的剑还留在沉钟寺。","她要上山去取。顺路，把灯点上。"]},
	"alchemist": {"image":"fox","lines":["昨夜，葛翁在江边看见了过世四十年的妻子。","她站在雾里，像在等船。"]},
}

const PROLOGUE_END = {"image":"title","lines":["从灯市走，过白狐渡，经沉钟寺，上无明塔。","把火种带到塔顶。"]}

const CHAPTERS = [
	{"image":"market","numeral":"壹","name":"灯市旧巷","line":"灯笼没人点了，就自己睁开眼睛找人。"},
	{"image":"fox","numeral":"贰","name":"白狐渡","line":"渡口只剩一条船。撑船的不收铜钱。"},
	{"image":"temple","numeral":"叁","name":"沉钟寺","line":"钟落进地里很多年了。守钟的还在数时辰。"},
	{"image":"tower","numeral":"肆","name":"无明塔","line":"塔里每一层都挂着灯，一盏也没点。"},
]

const BOSSES = [
	{"name":"百目灯魁","epithet":"灯市的旧灯笼","quote":"这么多年，你们只在过节时看我一眼。","defeat":"灯笼一盏接一盏暗下去。巷子里第一次安静下来。","tip":"击碎两侧灯柱，灯魁会变得脆弱。"},
	{"name":"渡月狐姬","epithet":"白狐渡的摆渡人","quote":"过江要给船钱。没有铜钱，就留下名字。","defeat":"她把竹篙递给你：「船钱免了。替我把灯点上。」","tip":"她蓄力后会直线突进，向侧面闪开。"},
	{"name":"沉钟守将","epithet":"沉钟寺的护法","quote":"钟还没敲完。天，不能亮。","defeat":"最后一声钟响完了。守将跪下去，没有再起来。","tip":"钟声落下前离开红圈；重击能打断他。"},
	{"name":"无明塔主","epithet":"守塔人 · 宿灯","quote":"再等一夜。就一夜。他们还没看够。","defeat":"","tip":"他换招时有停顿。留一次闪避给半血之后。"},
]

const ENDING = [
	{"image":"tower","lines":["「灯是我吹灭的。」宿灯说，「天一亮，他们就得回去。」","「三十年了。我每年只能远远看他们一夜。」"]},
	{"image":"tower","lines":["你把火种放进灯里。","长明灯亮起来的时候，他没有拦。"]},
	{"image":"dawn","lines":["江上起了雾。纸人一个接一个停下，转身，朝对岸走。","岸上站了很多人。没有人喊。"]},
]

const ENDING_CHARACTER = {
	"keeper": "后来，塔上换了守灯人。每年冬至，你把灯点到天亮。",
	"swordswoman": "听雨在过江的人里看见了哥哥。他回头看了她一眼，和小时候一样。",
	"alchemist": "葛翁没有追上去。他放下药篓，在岸边站到了天亮。",
}

const ENDING_LAST = "天亮了。"

const CHARACTERS = {
	"keeper": {"title":"宿灯的徒弟","story":"跟着师父守了七年塔灯。灯灭那晚，塔门是从里面锁上的。","style":"远程火符，清房后得护盾。打法最稳。","ultimate":"百灯照夜","ultimate_desc":"爆开一圈灯火，清除敌弹并回复生命；之后 8 秒身周持续灼烧，伤害 +25%。"},
	"swordswoman": {"title":"沉钟寺的俗家弟子","story":"十二岁上山，十九岁下山，剑留在了寺里。她的哥哥死在白狐渡。","style":"近身连斩，闪避恢复更快。高风险，高回报。","ultimate":"一苇渡江","ultimate_desc":"瞬间斩过附近最多七名敌人，每次造成高额伤害；之后 4 秒攻速 +50%。"},
	"alchemist": {"title":"江边药铺的老郎中","story":"开了四十年药铺，没治好过自己的妻子。昨夜他在江边看见了她。","style":"毒与火叠加，越打越强。需要拉开距离。","ultimate":"九转丹炉","ultimate_desc":"在身周连环引爆九枚丹丸并回复生命；之后 5 秒灼烧与剧毒伤害 +50%。"},
}

const HOST = {
	"name":"沈婆",
	"place":"渡口茶摊",
	"intro":"沈婆的茶摊开在渡口，长夜里没收过摊。灯烬能在这儿换点东西。",
	"lines":[
		"趁热喝。路上冷。",
		"灯市那些灯笼，以前是我糊的。下手别太狠。",
		"白狐渡的船，你别自己撑。让她撑。",
		"沉钟寺的钟，我年轻时听过。很远都听得见。",
		"宿灯这孩子，打小就倔。",
		"又回来了？坐。",
	],
}

const CAMP = {
	"vigor": {"name":"一碗姜汤","glyph":"汤","line":"「趁热喝。」","desc":"初始生命上限 +3"},
	"focus": {"name":"旧火种","glyph":"火","line":"「宿灯留下的，你拿着。」","desc":"所有伤害 +2%"},
	"stride": {"name":"新编草鞋","glyph":"履","line":"「鞋底纳厚了，走夜路不滑。」","desc":"移动速度 +1.5%"},
	"fortune": {"name":"签筒","glyph":"签","line":"「抽一支。不灵不要钱。」","desc":"每局刷新次数 +1"},
}

# 见闻：随进度解锁。req 为 [字段, 数值]，字段取自存档。
const CODEX = [
	{"id":"town","name":"渡口镇","req":["always",0],"text":"江边的小镇，一半人家靠摆渡过活。冬至比过年还重，家家门口挂灯，桌上多摆一副碗筷。"},
	{"id":"lamp","name":"长明灯","req":["always",0],"text":"无明塔顶的铜灯。冬至夜点起，照着江面，好让对岸回来的人认得路。天亮时灯不灭，他们才能顺着光回去。"},
	{"id":"sigils","name":"四象灯","req":["always",0],"text":"长明灯四周原本围着四盏小灯：朱雀、白虎、玄武、青龙。长明灯灭时，四盏灯碎成了火星，散在夜路上——就是你拾到的符印。同一盏灯的符印凑得越多，火越旺。"},
	{"id":"paper","name":"纸人","req":["always",0],"text":"扎纸铺给过世的人扎的仆从。灯一灭，回家的人找不到路，就附在纸人身上在街上转。它们不是要害人，只是天太久没亮，忘了自己是谁。"},
	{"id":"host","name":"沈婆","req":["always",0],"text":"渡口茶摊的老板娘。年轻时在灯市糊灯笼，后来眼睛不好，改卖茶。宿灯小时候常来她摊上蹭糖。"},
	{"id":"boss0","name":"百目灯魁","req":["bosses",1],"text":"灯市里没人要的旧灯笼聚成的东西。每只眼睛都是一盏灯，都在等人来点。"},
	{"id":"boss1","name":"渡月狐姬","req":["bosses",2],"text":"白狐渡的摆渡人，比渡口镇还老。她收的船钱是名字：过了江的人忘了自己是谁，就不会再想回来。她觉得这样对谁都好。"},
	{"id":"boss2","name":"沉钟守将","req":["bosses",3],"text":"沉钟寺的护法石像。大钟落地那年，他接下了报时的差事。钟早就不响了，他还在一下一下地敲。"},
	{"id":"boss3","name":"宿灯","req":["victories",1],"text":"无明塔的守灯人，守了三十年。他父母都葬在江对岸。每年冬至，他只能隔着江远远看他们一夜——今年，他不想让天亮。"},
	{"id":"fox","name":"狐火","req":["bosses",2],"text":"白狐渡水面上漂的火。狐姬用它给船引路，也用它给不想过江的人引路——引到芦苇深处去。"},
	{"id":"bell","name":"沉钟","req":["bosses",3],"text":"寺里的大钟。从前一敲，江两岸都听得见，镇上的人照着钟声起床、收摊、关门。"},
	{"id":"dawn","name":"天亮以后","req":["victories",1],"text":"长明灯点着了。过了江的人顺着灯走了回去。渡口镇照常开船，沈婆照常卖茶。冬至还会再来。"},
]

static func codex_unlocked(entry: Dictionary, profile: Dictionary) -> bool:
	var field: String = entry.req[0]
	if field == "always": return true
	return int(profile.get(field, 0)) >= int(entry.req[1])

static func night_number(profile: Dictionary) -> int:
	return 3 + int(profile.get("settled", []).size())
