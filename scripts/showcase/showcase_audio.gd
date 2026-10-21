class_name RallyShowcaseAudio
extends Node

var engines: Dictionary = {}
var road := AudioStreamPlayer.new()
var ambient := AudioStreamPlayer.new()
var rotor := AudioStreamPlayer.new()
var river := AudioStreamPlayer.new()
var music := AudioStreamPlayer.new()
var vehicle_id := ""
var biome := ""
var players: Array[AudioStreamPlayer] = []

func _ready() -> void:
	process_mode=Node.PROCESS_MODE_ALWAYS
	for layer: String in ["idle","low","mid","high","lift"]:
		var player := AudioStreamPlayer.new()
		player.bus="Engine"
		add_child(player)
		engines[layer]=player
		players.append(player)
	for pair: Array in [[road,"Road","gravel"],[ambient,"Environment","forest"],[rotor,"Environment","helicopter"],[river,"Environment","river"]]:
		var player: AudioStreamPlayer=pair[0]
		player.bus=pair[1]
		player.stream=RallySynthAudio.stream("gravel") if pair[2]=="gravel" else RallyAudioDirector.asset(pair[2],true)
		player.volume_db=-80
		add_child(player)
		players.append(player)
	music.bus="Music"
	music.stream=RallyAudioDirector.music_asset("autumn")
	music.volume_db=-13
	add_child(music)
	players.append(music)

func start() -> void:
	if DisplayServer.get_name()=="headless": return
	for player: AudioStreamPlayer in players:
		if player.stream!=null: player.play()

func sample(frame: Array,car: String,environment_id: String,shot: String,time: float,paused: bool) -> void:
	if vehicle_id!=car:
		vehicle_id=car
		for layer: String in engines:
			engines[layer].stream=RallyAudioDirector.asset(car+"_"+layer,true)
			if DisplayServer.get_name()!="headless": engines[layer].play()
	if biome!=environment_id:
		biome=environment_id
		ambient.stream=RallyAudioDirector.asset({"autumn":"forest","coast":"coast","highland":"highland"}[biome],true)
		road.stream=RallySynthAudio.stream("gravel") if biome!="coast" else RallySynthAudio.stream("asphalt")
		if DisplayServer.get_name()!="headless": ambient.play(); road.play()
	var rpm: float=frame[8]
	var throttle: float=frame[5]
	var gain := .32 if shot in ["establish","coast_wide","cliff","outro","animals","bridge","helicopter"] else .65
	gain*=1-smoothstep(73.8,75,time)
	var mix := {"idle":1-smoothstep(900,1800,rpm),"low":maxf(0,1-absf(rpm-2100)/1700)*throttle,"mid":maxf(0,1-absf(rpm-3800)/2200)*throttle,"high":smoothstep(4000,6500,rpm)*throttle,"lift":(1-throttle)*smoothstep(1000,2200,rpm)}
	for layer: String in engines:
		engines[layer].pitch_scale=clampf(rpm/3000,.28,2.65)
		engines[layer].volume_linear=maxf(.00001,mix[layer]*gain)
	road.volume_linear=gain*(.05+clampf(absf(frame[3])/25,0,1)*.22)*clampf(frame[2]/25,0,1)
	road.pitch_scale=.8+minf(frame[2]/50,.55)
	ambient.volume_db=-20
	rotor.volume_linear=.28 if shot=="helicopter" else 0
	river.volume_linear=.24 if shot=="bridge" else 0
	music.volume_linear=.20*(1-smoothstep(72,75,time))
	for player: AudioStreamPlayer in players: player.stream_paused=paused

func silence() -> void:
	for player: AudioStreamPlayer in players: player.stream_paused=true

func dispose() -> void:
	for player: AudioStreamPlayer in players:
		player.stop()
		player.stream=null
