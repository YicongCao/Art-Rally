extends "res://tests/test_suite.gd"

const WARMUP_FRAMES := 120
const MAX_RUN_SECONDS := 420.0
const FRAME_BUDGET_MS := 16.7
const TIMER_TOLERANCE_MS := 0.05

var scene: Node3D
var sampling: bool = false
var frame_intervals := PackedFloat64Array()
var process_times := PackedFloat64Array()
var physics_times := PackedFloat64Array()
var vehicle_times := PackedFloat64Array()
var draw_calls := PackedFloat64Array()
var primitives := PackedFloat64Array()
var slow_frames: Array[Dictionary] = []
var previous_frame_usec: int = 0


func _run() -> void:
	if DisplayServer.get_name()=="headless":
		check(false,"M6 performance check requires Metal / Forward+ window rendering")
		finish()
		return
	var run_count := 3
	var max_seconds := MAX_RUN_SECONDS
	var low_detail := false
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--runs="): run_count = clampi(int(argument.trim_prefix("--runs=")),1,3)
		elif argument.begins_with("--probe-seconds="):
			max_seconds = maxf(5.0,float(argument.trim_prefix("--probe-seconds=")))
			run_count = 1
		elif argument=="--low-detail": low_detail = true
	root.size = Vector2i(1920,1080)
	DisplayServer.window_set_size(Vector2i(1920,1080))
	scene = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	scene.preferences.set_value("volume",0)
	scene.preferences.set_value("low_detail",low_detail)
	scene._apply_preferences()
	scene.vehicle.drivetrain.config.drive_layout = "AWD"
	scene._set_autopilot_mode_name("vgamepad")
	physics_frame.connect(_capture_physics)
	var reports: Array[Dictionary] = []
	for run_index: int in range(run_count):
		var scenario: String = ["default_chase","cockpit","debug_panel"][run_index]
		_configure_scenario(scenario)
		reports.append(await _measure_run(run_index,scenario,max_seconds))
		if run_index+1<run_count:
			scene._restart()
			for i: int in range(30):
				paused = false
				await process_frame
	var report := {
		"engine":Engine.get_version_info()["string"],
		"os":OS.get_name()+" "+OS.get_version(),
		"display_server":DisplayServer.get_name(),
		"renderer":RenderingServer.get_current_rendering_driver_name(),
		"adapter":RenderingServer.get_video_adapter_name(),
		"resolution":"1920x1080",
		"physics_hz":Engine.physics_ticks_per_second,
		"frame_budget_ms":FRAME_BUDGET_MS,
		"timer_tolerance_ms":TIMER_TOLERANCE_MS,
		"frame_cap":Engine.max_fps,
		"vsync_mode":DisplayServer.window_get_vsync_mode(),
		"probe_seconds":max_seconds,
		"low_detail":low_detail,
		"anti_aliasing":"FXAA",
		"ssao":scene.presentation.environment.ssao_enabled,
		"runs":reports,
	}
	var output := FileAccess.open("res://logs/m6_performance.json",FileAccess.WRITE)
	output.store_string(JSON.stringify(report,"\t"))
	output.close()
	print("M6 PERFORMANCE: ",report)
	for run: Dictionary in reports:
		if max_seconds>=MAX_RUN_SECONDS:
			check(run.finished and run.recoveries==0,"%s completes the full rendered stage without recovery"%run.scenario)
		else:
			check(run.sampled_frames>100,"%s short probe collects enough rendered frames"%run.scenario)
		check(float(run.vehicle_p95_ms)<=2.0,"%s vehicle callback P95 stays within 2 ms"%run.scenario)
	check(not reports.is_empty() and reports[0].frame_budget_pass,"Default 1080p one-second paced frame-time P95 meets the 16.7 ms target")
	scene.queue_free()
	paused = false
	for i: int in range(10): await process_frame
	finish()


func _configure_scenario(scenario: String) -> void:
	scene.debug_panel.set_enabled(false)
	scene.camera_mode = 0
	scene.camera_snap = true
	if scenario=="cockpit":
		scene.camera_mode = 2
	elif scenario=="debug_panel":
		scene.debug_panel.set_enabled(true)


func _measure_run(run_index: int,scenario: String,max_seconds: float) -> Dictionary:
	_clear_samples()
	var memory_start := float(Performance.get_monitor(Performance.MEMORY_STATIC))
	var objects_start := float(Performance.get_monitor(Performance.OBJECT_COUNT))
	var started := Time.get_ticks_usec()
	var rendered_frames := 0
	while scene.session.phase!=RallyStageSession.Phase.FINISHED and (Time.get_ticks_usec()-started)/1000000.0<max_seconds:
		if paused:
			paused = false
			scene.controls.resume()
			scene.pause_menu.show_menu(false)
		await process_frame
		rendered_frames += 1
		if rendered_frames==WARMUP_FRAMES:
			sampling = true
			previous_frame_usec = Time.get_ticks_usec()
		elif rendered_frames>WARMUP_FRAMES:
			_capture_frame()
	sampling = false
	var memory_end := float(Performance.get_monitor(Performance.MEMORY_STATIC))
	var objects_end := float(Performance.get_monitor(Performance.OBJECT_COUNT))
	var frame_stats := _stats(frame_intervals)
	var paced_frame_stats := _stats(_rolling_average(frame_intervals,60))
	var process_stats := _stats(process_times)
	var physics_stats := _stats(physics_times)
	var vehicle_stats := _stats(vehicle_times)
	var draw_stats := _stats(draw_calls)
	var primitive_stats := _stats(primitives)
	var result := {
		"run":run_index+1,
		"scenario":scenario,
		"finished":scene.session.phase==RallyStageSession.Phase.FINISHED,
		"elapsed_stage_s":scene.session.elapsed,
		"wall_seconds":(Time.get_ticks_usec()-started)/1000000.0,
		"recoveries":scene.session.reset_count,
		"rendered_frames":rendered_frames,
		"sampled_frames":frame_intervals.size(),
		"frame_interval_p50_ms":frame_stats.p50,
		"frame_interval_p95_ms":frame_stats.p95,
		"frame_interval_p99_ms":frame_stats.p99,
		"frame_interval_max_ms":frame_stats.maximum,
		"paced_frame_p95_ms":paced_frame_stats.p95,
		"paced_frame_p99_ms":paced_frame_stats.p99,
		"main_process_p95_ms":process_stats.p95,
		"total_physics_p95_ms":physics_stats.p95,
		"vehicle_p95_ms":vehicle_stats.p95,
		"vehicle_p99_ms":vehicle_stats.p99,
		"vehicle_max_ms":vehicle_stats.maximum,
		"draw_calls_p95":draw_stats.p95,
		"draw_calls_max":draw_stats.maximum,
		"primitives_p95":primitive_stats.p95,
		"memory_start_mb":memory_start/1048576.0,
		"memory_end_mb":memory_end/1048576.0,
		"memory_delta_mb":(memory_end-memory_start)/1048576.0,
		"objects_start":objects_start,
		"objects_end":objects_end,
		"objects_delta":objects_end-objects_start,
		"slow_frames":slow_frames.duplicate(true),
	}
	result["frame_budget_pass"] = float(result.paced_frame_p95_ms)<=FRAME_BUDGET_MS+TIMER_TOLERANCE_MS
	return result


func _capture_frame() -> void:
	var now := Time.get_ticks_usec()
	var interval := (now-previous_frame_usec)/1000.0
	previous_frame_usec = now
	frame_intervals.append(interval)
	process_times.append(float(Performance.get_monitor(Performance.TIME_PROCESS))*1000.0)
	physics_times.append(float(Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS))*1000.0)
	draw_calls.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
	primitives.append(float(Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)))
	if interval>33.0 and slow_frames.size()<100:
		slow_frames.append({
			"frame_ms":interval,
			"progress_m":scene.session.progress,
			"camera_mode":scene.camera_mode,
			"debug_panel":scene.debug_panel.visible,
		})


func _capture_physics() -> void:
	if sampling and is_instance_valid(scene) and is_instance_valid(scene.vehicle):
		vehicle_times.append(scene.vehicle.physics_usec/1000.0)


func _clear_samples() -> void:
	sampling = false
	frame_intervals.clear()
	process_times.clear()
	physics_times.clear()
	vehicle_times.clear()
	draw_calls.clear()
	primitives.clear()
	slow_frames.clear()
	previous_frame_usec = 0


static func _stats(values: PackedFloat64Array) -> Dictionary:
	if values.is_empty():
		return {"p50":INF,"p95":INF,"p99":INF,"maximum":INF}
	var sorted := values.duplicate()
	sorted.sort()
	return {
		"p50":_percentile(sorted,0.50),
		"p95":_percentile(sorted,0.95),
		"p99":_percentile(sorted,0.99),
		"maximum":sorted[-1],
	}


static func _percentile(sorted: PackedFloat64Array,fraction: float) -> float:
	return sorted[clampi(ceili((sorted.size()-1)*fraction),0,sorted.size()-1)]


static func _rolling_average(values: PackedFloat64Array,window: int) -> PackedFloat64Array:
	var result := PackedFloat64Array()
	if values.size()<window: return result
	var total := 0.0
	for i: int in range(values.size()):
		total += values[i]
		if i>=window: total -= values[i-window]
		if i>=window-1: result.append(total/window)
	return result
