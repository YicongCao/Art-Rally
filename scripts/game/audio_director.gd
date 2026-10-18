class_name RallyAudioDirector
extends Node

const ROOT := "res://assets/audio/first_playable/"
var voice := AudioStreamPlayer.new()
var voice_is_preview: bool = false
var last_note: String = ""
var music := AudioStreamPlayer.new()
var ambience := AudioStreamPlayer.new()
var cues: Array[AudioStreamPlayer] = []
var settings := RallyGameSettings.new()
var duck: float = 0
var driving: bool = false
var playback: bool = false
var theme: String = ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in ["Engine","Road","Environment","Interface","Music","Voice"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	voice.bus = "Voice"
	add_child(voice)
	music.bus = "Music"
	music.stream = music_asset("menu")
	theme = "menu"
	add_child(music)
	ambience.bus = "Environment"
	add_child(ambience)
	for i: int in range(4):
		var player := AudioStreamPlayer.new()
		player.bus = "Interface"
		add_child(player)
		cues.append(player)
	apply_settings(settings)
	if DisplayServer.get_name()!="headless": music.play()


static func asset(kind: String, loop: bool = false) -> AudioStreamWAV:
	var path := ROOT+kind+".wav"
	if not ResourceLoader.exists(path): return RallySynthAudio.stream("impact")
	var audio: AudioStreamWAV = load(path).duplicate()
	if loop:
		audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
		audio.loop_begin = 0
		audio.loop_end = roundi(audio.get_length()*audio.mix_rate)
	return audio


func apply_settings(prefs: RallyGameSettings) -> void:
	settings = prefs
	if settings.values.voice=="off" or (voice.has_meta("kind") and voice.get_meta("kind")!=settings.values.voice): voice.stop()
	for pair: Array in [["Voice","voice_volume"],["Engine","engine_volume"],["Road","road_volume"],["Environment","environment_volume"],["Interface","interface_volume"],["Music","music_volume"]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index>=0: AudioServer.set_bus_volume_db(index,linear_to_db(maxf(0.0001,settings.values[pair[1]])))
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,settings.values.volume)))


func set_scene(environment_id: String = "") -> void:
	voice.stop()
	last_note = ""
	driving = not environment_id.is_empty()
	var next_theme := environment_id if driving else "menu"
	if theme!=next_theme:
		theme = next_theme
		music.stream = music_asset(theme)
		if DisplayServer.get_name()!="headless": music.play()
	music.volume_db = -5 if driving else -3
	music.stream_paused = false
	ambience.stop()
	if driving:
		ambience.stream = asset({"autumn":"forest","coast":"coast","highland":"highland"}.get(environment_id,"forest"),true)
		ambience.volume_db = -14
		if DisplayServer.get_name()!="headless": ambience.play()


func cue(kind: String) -> void:
	var player := cues[0]
	for candidate: AudioStreamPlayer in cues:
		if not candidate.playing:
			player = candidate
			break
	player.stream = asset(kind)
	player.volume_db = -9
	if DisplayServer.get_name()!="headless": player.play()
	if kind!="ui": duck = 0.65


func _process(dt: float) -> void:
	duck = maxf(0,duck-dt)
	voice.stream_paused = get_tree().paused and driving and not voice_is_preview
	if voice.playing and not voice.stream_paused: duck = maxf(duck,.12)
	ambience.stream_paused = get_tree().paused and driving
	music.stream_paused = get_tree().paused and driving and not playback
	for pair: Array in [["Environment","environment_volume"],["Music","music_volume"]]:
		var value: float = settings.values[pair[1]]*(0.55 if duck>0 else 1.0)
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index(pair[0]),linear_to_db(maxf(0.0001,value)))


func diagnostic() -> String:
	return "驱动：%s · 输出：%s · 主音量：%d%%"%[AudioServer.get_driver_name(),AudioServer.output_device,int(settings.values.volume*100)]


func _exit_tree() -> void:
	for child: Node in get_children():
		if child is AudioStreamPlayer:
			child.stop()
			child.stream = null


static func music_asset(kind: String) -> AudioStreamWAV:
	var audio: AudioStreamWAV = load("res://assets/audio/music/theme_"+kind+".wav").duplicate()
	audio.loop_mode = AudioStreamWAV.LOOP_FORWARD
	audio.loop_begin = 0
	audio.loop_end = roundi(audio.get_length()*audio.mix_rate)
	return audio


func speak_note(code: String,preview: bool = false) -> void:
	if settings.values.voice=="off": return
	var path := "res://assets/audio/voice/%s/%s.wav"%[settings.values.voice,code]
	if not ResourceLoader.exists(path): return
	# A new imminent call replaces stale speech; never accumulate an out-of-date queue.
	voice.stop()
	voice.stream = load(path)
	voice.volume_db = -3
	voice_is_preview = preview
	voice.stream_paused = false
	voice.set_meta("kind",settings.values.voice)
	last_note = code
	if DisplayServer.get_name()!="headless": voice.play()
	duck = .5
