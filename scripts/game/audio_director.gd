class_name RallyAudioDirector
extends Node

const ROOT := "res://assets/audio/first_playable/"
var music := AudioStreamPlayer.new()
var ambience := AudioStreamPlayer.new()
var cues: Array[AudioStreamPlayer] = []
var settings := RallyGameSettings.new()
var duck: float = 0
var driving: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus: String in ["Engine","Road","Environment","Interface","Music"]:
		if AudioServer.get_bus_index(bus)<0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count-1,bus)
			AudioServer.set_bus_send(AudioServer.bus_count-1,"Master")
	music.bus = "Music"
	music.stream = asset("menu_music",true)
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
		audio.loop_end = audio.data.size()/2
	return audio


func apply_settings(prefs: RallyGameSettings) -> void:
	settings = prefs
	for pair: Array in [["Engine","engine_volume"],["Road","road_volume"],["Environment","environment_volume"],["Interface","interface_volume"],["Music","music_volume"]]:
		var index := AudioServer.get_bus_index(pair[0])
		if index>=0: AudioServer.set_bus_volume_db(index,linear_to_db(maxf(0.0001,settings.values[pair[1]])))
	AudioServer.set_bus_volume_db(0,linear_to_db(maxf(0.0001,settings.values.volume)))


func set_scene(environment_id: String = "") -> void:
	driving = not environment_id.is_empty()
	music.stream_paused = driving
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
	ambience.stream_paused = get_tree().paused and driving
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
