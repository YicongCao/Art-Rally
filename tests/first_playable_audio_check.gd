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
