extends "res://tests/test_suite.gd"
func _run() -> void:
	var settings := RallyGameSettings.new()
	check(settings.values.voice=="female" and not settings.values.show_fps,"Female co-driver defaults on and FPS defaults off")
	settings.set_value("voice","invalid")
	check(settings.values.voice=="female","Invalid voice restores a supported default")
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	app.profile.path = "user://experience-test-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data = RallyProfileStore.fresh()
	app.show_settings()
	var categories: RallySettingsPanel = app.ui.find_children("*","RallySettingsPanel",true,false)[0]
	check(categories.pages.size()==5 and categories.widgets.size()==RallyGameSettings.DEFAULTS.size()-1,"All configurable fields have one categorized widget")
	categories.select(2)
	check(categories.pages[2].visible and not categories.pages[0].visible and categories.tabs[2].button_pressed,"Settings category has a persistent selected state")
	app.prefs.set_value("voice","male")
	app.prefs.set_value("show_fps",true)
	app._save()
	var restored := RallyProfileStore.new()
	restored.path = app.profile.path
	restored.load_file()
	check(restored.data.settings.voice=="male" and restored.data.settings.show_fps,"Voice and FPS survive a profile reload")
	for voice: String in ["female","male"]:
		app.prefs.set_value("voice",voice)
		app.audio.apply_settings(app.prefs)
		for code: String in RallyHUD.NOTE_TEXT:
			app.audio.speak_note(code)
			check(app.audio.last_note==code and app.audio.voice.stream!=null and app.audio.voice.stream.resource_path=="res://assets/audio/voice/%s/%s.wav"%[voice,code] and app.audio.voice.stream.get_length()>.2,voice+" has a bundled "+code+" call")
	app.prefs.set_value("voice","off")
	app.audio.apply_settings(app.prefs)
	app.audio.speak_note("LEFT_MEDIUM")
	check(not app.audio.voice.playing,"Voice off immediately cancels playback")
	await app.start_race()
	var scene: Node3D = app.race
	check(scene.wildlife.events.size() in [2,3] and scene.river_audio.size()==scene.challenge.stage.river_crossings.size(),"Forest contains two or three wildlife events and one sound source per river")
	scene.session.phase = RallyStageSession.Phase.RUNNING
	scene.session.progress = scene.wildlife.events[0].s-100
	scene.wildlife.advance(.1)
	check(scene.wildlife.active and scene.wildlife.deer.visible,"Crossing animal appears with adequate advance distance")
	scene.wildlife.advance(8)
	check(scene.wildlife.active and scene.wildlife.deer.visible,"Animal remains visible through the middle of its crossing")
	scene.wildlife.advance(16)
	check(not scene.wildlife.active and not scene.wildlife.deer.visible and scene.wildlife.fade==1,"Animal fully fades only after departing far beyond the road")
	scene.vehicle.position = scene.river_audio[0].position+Vector3.UP*3
	scene._update_river_audio(1)
	var near_gain: float = scene.river_audio[0].volume_linear
	scene.vehicle.position += Vector3(500,0,0)
	scene._update_river_audio(1)
	check(near_gain>.6 and scene.river_audio[0].volume_linear<.02,"River sound rises nearby and fades away with distance")
	var hud: RallyHUD = scene.game_hud
	var data := RallyHUD.data_for(scene.vehicle,scene.session,false)
	data.gate_times=[0.0,2.0,4.0]
	hud.refresh(data)
	check(hud.sector.is_empty(),"Ordinary checkpoints do not create sector popups")
	data.split_times = [8.5]
	data.best_splits = [9.0]
	hud.refresh(data)
	check(hud.sector.number==1 and hud.sector.seconds==8.5 and hud.sector.delta==-.5,"First sector shows its time and fastest-run sector delta")
	hud.sector_clock=2.0
	data.gate_times.append(10.0)
	hud.refresh(data)
	check(hud.sector_clock==2.0,"An intermediate checkpoint cannot restart a sector notification")
	data.split_times = [8.5,18.0]
	data.best_splits = [9.0,18.0]
	hud.refresh(data)
	check(hud.sector.seconds==9.5 and hud.sector.delta==.5,"Second sector compares its own time, not cumulative elapsed time")
	data.speed = 40
	hud.refresh(data)
	hud._process(.2)
	check(hud.hint_alpha==0,"Bottom controls fade out when moving")
	data.speed=0
	hud.refresh(data)
	hud._process(.2)
	check(hud.hint_alpha==1,"Bottom controls fade in when stopped")
	data.split_times=[]
	hud.refresh(data)
	check(hud.sector.is_empty(),"Restart clears the previous segment notification")
	await app.leave_race()
	app.free()
	await process_frame
	finish()
