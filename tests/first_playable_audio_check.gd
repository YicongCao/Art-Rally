extends "res://tests/test_suite.gd"
func _run() -> void:
	if DisplayServer.get_name()=="headless":
		check(false,"Audio verification requires a real audio driver")
		finish()
		return
	var audio := RallyAudioDirector.new()
	root.add_child(audio)
	var capture := AudioEffectCapture.new()
	capture.buffer_length = 2
	AudioServer.add_bus_effect(0,capture)
	audio.cue("start")
	await create_timer(1.0).timeout
	var samples := capture.get_buffer(capture.get_frames_available())
	var peak := 0.0
	for sample: Vector2 in samples: peak=maxf(peak,maxf(absf(sample.x),absf(sample.y)))
	check(AudioServer.get_driver_name()!="Dummy","Real audio driver selected")
	check(peak>.001 and peak<.99,"Menu music and cue reach the output bus without clipping")
	print("AUDIO OUTPUT: ",audio.diagnostic()," peak=",peak)
	var profiles: Array[PackedByteArray] = []
	for id: String in RallyContentCatalog.VEHICLES:
		var stream := RallyAudioDirector.asset(id+"_mid",true)
		check(stream.data.size()>1000 and stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,id+" has a packaged engine loop")
		profiles.append(stream.data)
	check(profiles[0]!=profiles[1] and profiles[1]!=profiles[2] and profiles[0]!=profiles[2],"Three cars use different combustion waveforms")
	for environment_id: String in ["","autumn","coast","highland"]:
		audio.set_scene(environment_id)
		capture.clear_buffer()
		await create_timer(.65).timeout
		var measured := 0.0
		for sample: Vector2 in capture.get_buffer(capture.get_frames_available()): measured=maxf(measured,maxf(absf(sample.x),absf(sample.y)))
		check(measured>.0005 and measured<.99,"Theme "+audio.theme+" reaches the real output bus without clipping")
		check(audio.music.stream.loop_end==roundi(audio.music.stream.get_length()*audio.music.stream.mix_rate),"Compressed music uses its full decoded loop length")
	var voice_capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(AudioServer.get_bus_index("Voice"),voice_capture)
	for kind: String in ["female","male"]:
		audio.settings.set_value("voice",kind)
		audio.apply_settings(audio.settings)
		voice_capture.clear_buffer()
		audio.speak_note("preview",true)
		await create_timer(1.0).timeout
		var voice_peak := 0.0
		for sample: Vector2 in voice_capture.get_buffer(voice_capture.get_frames_available()): voice_peak=maxf(voice_peak,maxf(absf(sample.x),absf(sample.y)))
		check(voice_peak>.01 and voice_peak<.99,kind+" co-driver reaches the real audio mixer without clipping")
	audio.voice.stop()
	AudioServer.remove_bus_effect(AudioServer.get_bus_index("Voice"),0)
	var space := Node3D.new()
	root.add_child(space)
	var camera := Camera3D.new()
	space.add_child(camera)
	camera.current = true
	var source := AudioStreamPlayer3D.new()
	source.position=Vector3(0,0,-8)
	source.unit_size=20
	source.volume_db=-12
	space.add_child(source)
	for kind: String in ["helicopter","river","hooves"]:
		source.stream = RallyAudioDirector.asset(kind,true)
		source.play()
		capture.clear_buffer()
		await create_timer(.6).timeout
		check(source.playing and capture.get_frames_available()>0,kind+" spatial loop plays through CoreAudio")
	source.stop()
	space.free()
	paused = true
	await create_timer(.15,true).timeout
	check(audio.music.stream_paused,"Driving music freezes with pause")
	audio.playback = true
	await create_timer(.15,true).timeout
	check(not audio.music.stream_paused,"Playback music continues while vehicle physics remains paused")
	paused = false
	audio.playback = false
	audio.settings.set_value("volume",0)
	audio.apply_settings(audio.settings)
	capture.clear_buffer()
	await create_timer(.5).timeout
	check(AudioServer.get_bus_volume_db(0)<=-79,"Saved mute remains effective")
	AudioServer.remove_bus_effect(0,0)
	audio.queue_free()
	await process_frame
	finish()
