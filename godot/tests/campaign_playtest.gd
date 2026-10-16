extends "res://tests/chapter_playtest.gd"

func make_world() -> ChapterWorld:
	return CampaignWorld.new()

func tick_limit() -> int:
	return 225000

func choose(w: ChapterWorld) -> void:
	if w.offer_kind=="chapter_clear":
		w.choose(0 if w.player.hp<w.player.max_hp*0.7 and w.contract!="silence" else 1)
		return
	super.choose(w)

func run() -> void:
	for hero in ["keeper","swordswoman","alchemist"]:
		for seed_value in [4242,8731]:
			if "--probe" in OS.get_cmdline_user_args() and (hero=="alchemist" or seed_value!=4242): continue
			var result=simulate(hero,seed_value); reports.append(result); print(JSON.stringify(result))
	var passed=reports.all(func(r): return r.victory and r.stage==4 and r.bosses==4 and r.rooms_visited>=48 and r.shrines==4)
	var report={"passed":passed,"runs":reports,"scope":"Natural four-chapter bot runs, three characters and two seeds, no camp or health/damage overrides; omniscient tactical controller, not human difficulty measurement."}
	var file=FileAccess.open("res://test-output/campaign-playtest.json",FileAccess.WRITE); file.store_string(JSON.stringify(report,"\t")); file.close()
	Sound.shutdown(); await get_tree().create_timer(0.15).timeout
	get_tree().quit(0 if passed else 1)
