extends Node

var music: AudioStreamPlayer
var previous_music: AudioStreamPlayer
var fade_progress = 1.0
var duck = 1.0
var target_duck = 1.0
var voices: Array[AudioStreamPlayer] = []
var streams: Dictionary = {}
var cooldowns: Dictionary = {}
var track = ""
var shutting_down = false

func _ready() -> void:
	music = AudioStreamPlayer.new()
	add_child(music)
	previous_music = AudioStreamPlayer.new()
	add_child(previous_music)
	for i in range(16):
		var voice = AudioStreamPlayer.new()
		add_child(voice)
		voices.append(voice)
	for key in ["cast", "hit", "hurt", "dash", "pulse", "upgrade", "heal", "shrine", "boss", "defeat", "victory","swing","hammer","needle","wheel","sand","bow","flame","ice","bell"]:
		streams[key] = load("res://assets/audio/" + key + ".wav")
	for key in ["night-print","battle-market","battle-fox","battle-temple","battle-tower","battle-boss"]:
		streams[key] = load("res://assets/audio/"+key+".wav")
		streams[key].loop_mode = AudioStreamWAV.LOOP_FORWARD
		streams[key].loop_end = int(streams[key].get_length()*streams[key].mix_rate)
	streams.ui = load("res://assets/audio/ui-print.wav")
	streams.pickup = load("res://assets/audio/pickup-print.wav")
	apply_settings()

func apply_settings() -> void:
	update_music_levels()
	for voice in voices:
		voice.volume_db = linear_to_db(maxf(0.0001, Save.profile.settings.sfx)) - 5.0

func update_music_levels() -> void:
	music.volume_db = linear_to_db(maxf(0.0001, Save.profile.settings.music*fade_progress*duck))
	previous_music.volume_db = linear_to_db(maxf(0.0001,Save.profile.settings.music*(1-fade_progress)*duck))

func play_music(key: String) -> void:
	if shutting_down: return
	if key=="night": key = "night-print"
	if key=="battle": key = "battle-market"
	if key == track:
		return
	track = key
	var swap = previous_music
	previous_music = music
	music = swap
	music.stop()
	music.stream = streams[key]
	fade_progress = 0.0 if previous_music.playing else 1.0
	apply_settings()
	music.play()

func battle_state(stage: int, boss: bool, paused: bool, choosing: bool) -> void:
	play_music("battle-boss" if boss else ["battle-market","battle-fox","battle-temple","battle-tower"][(stage-1)%4])
	target_duck = 0.45 if paused else (0.7 if choosing else 1.0)

func _process(dt: float) -> void:
	if not music or streams.is_empty(): return
	if track=="night-print": target_duck = 1.0
	if fade_progress<1:
		fade_progress = minf(1,fade_progress+dt/1.4)
		if fade_progress>=1: previous_music.stop()
	duck = lerpf(duck,target_duck,1-exp(-dt*5))
	update_music_levels()

func play(key: String, pitch: float = 1.0) -> void:
	if not streams.has(key) or Save.profile.settings.sfx <= 0:
		return
	var now = Time.get_ticks_msec()
	var interval = 65 if key in ["hit", "cast", "pickup"] else 30
	if now - int(cooldowns.get(key, -1000)) < interval:
		return
	cooldowns[key] = now
	var critical = key in ["hurt","pulse","boss","victory","defeat","shrine","upgrade","ui","bell"]
	var pool = voices.slice(12,16) if critical else voices.slice(0,12)
	for voice in pool:
		if not voice.playing:
			voice.stream = streams[key]
			voice.pitch_scale = pitch
			voice.play()
			return
	if critical:
		var voice = pool[0]
		voice.stop()
		voice.stream = streams[key]
		voice.pitch_scale = pitch
		voice.play()

func shutdown() -> void:
	shutting_down = true
	if music:
		music.stop()
		music.stream = null
	if previous_music:
		previous_music.stop()
		previous_music.stream = null
	for voice in voices:
		voice.stop()
		voice.stream = null
	streams.clear()

func shutdown_delay() -> float:
	# Let the audio driver consume stop commands before the tree is destroyed.
	return maxf(0.35,AudioServer.get_output_latency()*2+0.05)

func _exit_tree() -> void:
	shutdown()
