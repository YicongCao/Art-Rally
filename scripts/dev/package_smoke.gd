class_name RallyPackageSmoke
extends RefCounted


static func run(scene: Node3D) -> void:
	var failures := PackedStringArray()
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
		"stage_id":"sunset_ridge","drive_layout":"AWD","calibration_version":"200ps-v1",
		"driver_source":"human_keyboard","eligible_for_human_best":true,
		"elapsed":120.0,"penalty":5.0,"total_time":125.0,
		"reset_count":1,"takeover_count":0,"recorded_at":Time.get_unix_time_from_system(),
	})
	if results.save_file()!=OK:
		failures.append("results write")
	else:
		var loaded_results := RallyStageResultStore.new()
		loaded_results.path = result_path
		if loaded_results.load_file()!=OK or loaded_results.summary("sunset_ridge","AWD","200ps-v1").human_best.get("total_time",-1)!=125.0:
			failures.append("results read")
	DirAccess.remove_absolute(result_path)
	if failures.is_empty():
		print("PACKAGE SMOKE PASSED")
		scene.get_tree().quit(0)
	else:
		printerr("PACKAGE SMOKE FAILED: ",failures)
		scene.get_tree().quit(1)
