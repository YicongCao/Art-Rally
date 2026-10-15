extends "res://tests/test_suite.gd"

var scene: Node3D
var hint: int = 0
var max_lateral: float = 0
var samples := 0
var peak_cost: int = 0
var costs := PackedInt64Array()
var input_mode: String = "vgamepad"
var layout: String = "AWD"


func _run() -> void:
	for argument: String in OS.get_cmdline_user_args():
		if argument == "--keyboard": input_mode = "vkeyboard"
		elif argument.begins_with("--input="): input_mode = argument.trim_prefix("--input=")
		elif argument.begins_with("--layout="): layout = argument.trim_prefix("--layout=").to_upper()
	if input_mode not in ["vkeyboard","vgamepad"] or layout not in ["FWD","AWD","RWD"]:
		check(false,"Stage drive arguments select a supported layout and virtual input")
		finish()
		return
	scene = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	scene.vehicle.drivetrain.config.drive_layout = layout
	scene._set_autopilot_mode_name(input_mode)
	scene.set_process(false)
	var suffix := "_%s_%s"%[layout.to_lower(),input_mode]
	var trace := FileAccess.open("res://logs/stage_drive%s.csv"%suffix, FileAccess.WRITE)
	trace.store_line("tick,s,lateral,speed,gate,phase")
	var last_progress := 0.0
	var stalled_ticks := 0
	var stalled := false
	for i: int in range(120 * 650):
		await ticks(1)
		var projection: Dictionary = scene.generator.route.project(scene.vehicle.position,hint,35)
		hint = int(projection.index)
		max_lateral = maxf(max_lateral,absf(float(projection.lateral)))
		if i % 120 == 0:
			trace.store_line("%d,%.3f,%.3f,%.3f,%d,%d" % [i, scene.session.progress, scene.session.projection.get("lateral", 0), scene.vehicle.linear_velocity.length(), scene.session.next_gate, scene.session.phase])
			if scene.session.phase == RallyStageSession.Phase.RUNNING:
				if scene.session.progress > last_progress + 0.2:
					last_progress = scene.session.progress
					stalled_ticks = 0
				else:
					stalled_ticks += 120
					if stalled_ticks >= 120 * 30:
						stalled = true
						break
		peak_cost = maxi(peak_cost, scene.vehicle.physics_usec)
		costs.append(scene.vehicle.physics_usec)
		if scene.session.phase == RallyStageSession.Phase.FINISHED: break
		if scene.session.reset_count > 0 or not scene.vehicle.position.is_finite(): break
	trace.close()
	check(scene.session.phase == RallyStageSession.Phase.FINISHED, "Physical controller drives every checkpoint from start to finish")
	check(scene.session.reset_count == 0, "End-to-end stage needs no recovery or teleportation")
	check(max_lateral < 2.8, "Automated shakedown remains within road width")
	check(not stalled,"Automated shakedown keeps making route progress")
	costs.sort()
	var p95 := costs[int(costs.size() * 0.95)] / 1000.0 if not costs.is_empty() else INF
	var report := {"finished": scene.session.phase == RallyStageSession.Phase.FINISHED, "elapsed": scene.session.elapsed, "max_lateral_m": max_lateral, "gates": scene.session.next_gate, "progress_m": scene.session.progress, "peak_vehicle_callback_ms": peak_cost / 1000.0, "p95_vehicle_callback_ms": p95}
	report["input_mode"] = input_mode
	report["drive_layout"] = layout
	report["driver_source"] = scene.auto_driver.source_name(scene.controls.active_device)
	report["recoveries"] = scene.session.reset_count
	var output := FileAccess.open("res://logs/stage_drive%s_metrics.json"%suffix, FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print("STAGE DRIVE: ", report)
	scene.queue_free()
	await process_frame
	finish()
