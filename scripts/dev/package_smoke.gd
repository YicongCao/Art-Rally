class_name RallyPackageSmoke
extends RefCounted


static func run(scene: Node3D) -> void:
	var failures := PackedStringArray()
	if ProjectSettings.get_setting("application/config/version","")!="0.3.0-dev":
		failures.append("application version")
	if scene.generator.route.length<3000 or scene.vehicle.wheels.size()!=4:
		failures.append("main stage resources")
	if not scene.feedback.players.has("engine") or RallySynthAudio.stream("engine").data.size()<1000:
		failures.append("synthesized audio")
	if not RallyFonts.TEXT.has_char("夕".unicode_at(0)) or not RallyFonts.MONO.has_char("0".unicode_at(0)):
		failures.append("bundled fonts")
	var suffix := str(Time.get_ticks_usec())
	var settings_path := "user://package_smoke_settings_"+suffix+".cfg"
	var settings := RallyGameSettings.new()
	settings.path = settings_path
	settings.set_value("drive_layout","RWD")
	if settings.save_file()!=OK:
		failures.append("settings write")
	else:
		var loaded_settings := RallyGameSettings.new()
		loaded_settings.path = settings_path
		loaded_settings.load_file()
		if loaded_settings.values.drive_layout!="RWD": failures.append("settings read")
	DirAccess.remove_absolute(settings_path)
	var result_path := "user://package_smoke_results_"+suffix+".cfg"
	var results := RallyStageResultStore.new()
	results.path = result_path
	results.record({
		"stage_id":"sunset_ridge","drive_layout":"AWD","calibration_version":"200ps-v2-patch1",
		"driver_source":"human_keyboard","eligible_for_human_best":true,
		"elapsed":120.0,"penalty":5.0,"total_time":125.0,
		"reset_count":1,"takeover_count":0,"recorded_at":Time.get_unix_time_from_system(),
	})
	if results.save_file()!=OK:
		failures.append("results write")
	else:
		var loaded_results := RallyStageResultStore.new()
		loaded_results.path = result_path
		if loaded_results.load_file()!=OK or loaded_results.summary("sunset_ridge","AWD","200ps-v2-patch1").human_best.get("total_time",-1)!=125.0:
			failures.append("results read")
	DirAccess.remove_absolute(result_path)
	if failures.is_empty():
		print("PACKAGE SMOKE PASSED")
		scene.get_tree().quit(0)
	else:
		printerr("PACKAGE SMOKE FAILED: ",failures)
		scene.get_tree().quit(1)


static func run_app(app: Node) -> void:
	var failures: Array[String] = []
	app.profile.path = "user://package-smoke/profile.json"
	app.profile.data = RallyProfileStore.fresh()
	if app.profile.set_plate("PACK-160") != OK: failures.append("player plate save")
	if app.screen!="home": failures.append("main menu")
	for stage: String in RallyContentCatalog.STAGES:
		for vehicle: String in RallyContentCatalog.VEHICLES:
			if RallyContentCatalog.challenge(stage,vehicle)==null: failures.append("content catalog")
	for vehicle: String in RallyContentCatalog.VEHICLES:
		if not ResourceLoader.exists(RallyContentCatalog.vehicle(vehicle).model_path): failures.append(vehicle+" model")
		if RallyAudioDirector.asset(vehicle+"_mid").data.size()<1000: failures.append(vehicle+" audio")
	if not RallyFonts.TEXT.has_char("驶".unicode_at(0)): failures.append("bundled Chinese font")
	app.chosen_stage = "sunset_ridge"
	app.chosen_vehicle = "F160"
	await app.start_race()
	app.race._set_autopilot_mode_name("vgamepad")
	for i: int in range(240):
		if app.get_tree().paused or app.race.controls.blocked:
			app.get_tree().paused = false
			app.race.controls.resume()
		await app.get_tree().process_frame
	if app.race.vehicle.linear_velocity.length()<.5: failures.append("packaged physics driving")
	var plates := app.race.presentation.car_style.body.get_node_or_null("PlayerLicensePlates") as RallyVehiclePlate
	if plates == null or plates.plate_text != "PACK-160" or app.race.game_hud.player_plate != "PACK-160": failures.append("player plate in game")
	if app.race.feedback.engine_layers.size()!=5: failures.append("layered engine playback")
	if AudioServer.get_bus_peak_volume_left_db(AudioServer.get_bus_index("Engine"),0)<-70: failures.append("engine output signal")
	if AudioServer.get_driver_name()=="Dummy": failures.append("real audio driver")
	if app.profile.save_file()!=OK: failures.append("profile write")
	var restored := RallyProfileStore.new()
	restored.path = app.profile.path
	if restored.load_file()!=OK: failures.append("profile read")
	app.leave_race()
	await app.get_tree().process_frame
	if app.screen!="stages": failures.append("return flow")
	print("PACKAGE SMOKE PASSED" if failures.is_empty() else "PACKAGE SMOKE FAILED: "+str(failures))
	app.get_tree().quit.call_deferred(0 if failures.is_empty() else 1)
