extends "res://scripts/dev/driving_lab.gd"

const NOTE_TEXT := {
	"LEFT_MEDIUM": "左弯 3", "RIGHT_MEDIUM": "右弯 3",
	"LEFT_TIGHT": "左急弯 / 减速", "RIGHT_TIGHT": "右急弯 / 减速",
	"MUD_NARROW": "泥地 · 路面收窄", "WATER": "前方积水 · 减速直行",
	"ASPHALT": "进入柏油", "GRAVEL": "进入砂石", "CREST_JUMP": "坡顶跳跃 · 保持直线",
	"FINISH": "终点 · 通过后减速",
}

var generator: RallyStageGenerator
var session := RallyStageSession.new()
var game_hud: RallyHUD
var game_hud_clock: float = 0
var checkpoint_visual: MeshInstance3D
var respawn_wait: bool = false
var result_safety_reset: bool = false
var presentation := RallyStagePresentation.new()
var preferences := RallyGameSettings.new()
var pause_menu: RallyPauseMenu
var feedback := RallyVehicleFeedback.new()
var recovery_notice: String = ""
var recovery_notice_time: float = 0
var has_driven: bool = false
var startup_focus_pause: bool = false
var reverse_assist := RallyReverseAssist.new()
var selecting_vehicle: bool = false
var vehicle_selector: RallyVehicleSelector
var auto_driver := RallyAutoDriver.new()
var result_store := RallyStageResultStore.new()
var result_summary: Dictionary = {}
var finish_record: Dictionary = {}
var finish_recorded: bool = false
var result_persistence_enabled: bool = false


func _ready() -> void:
	generator = $Stage
	session.setup(generator.route)
	super._ready()
	vehicle.config.contact_envelope = true
	telemetry_visible = false
	controls.restart_requested.connect(_restart)
	controls.mode_requested.connect(_toggle_mode)
	controls.focus_returned.connect(_restore_launch_focus)
	controls.autopilot_requested.connect(_cycle_autopilot)
	controls.human_drive_input.connect(_human_drive_input)
	vehicle.reset_completed.connect(func(): respawn_wait = false)
	var layer := CanvasLayer.new()
	layer.layer = 5
	add_child(layer)
	game_hud = RallyHUD.new()
	layer.add_child(game_hud)
	game_hud.set_route(generator.route)
	readout.get_parent().get_parent().visible = false
	checkpoint_visual = MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(6.6, 0.025, 0.18)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("e9bf64")
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mesh.material = material
	checkpoint_visual.mesh = mesh
	add_child(checkpoint_visual)
	presentation.build(self)
	if DisplayServer.get_name()!="headless" and not "--test-defaults" in OS.get_cmdline_user_args(): preferences.load_file()
	pause_menu = RallyPauseMenu.new()
	add_child(pause_menu)
	pause_menu.build(preferences)
	pause_menu.resume_requested.connect(_toggle_pause)
	pause_menu.restart_requested.connect(_restart)
	pause_menu.practice_requested.connect(_toggle_mode)
	pause_menu.vehicle_requested.connect(func(): _open_vehicle_selection(true))
	pause_menu.autopilot_changed.connect(_set_autopilot_mode_name)
	pause_menu.setting_changed.connect(_setting_changed)
	pause_menu.defaults_requested.connect(_reset_preferences)
	controls.transmission_requested.connect(func(): preferences.set_value("automatic",vehicle.drivetrain.automatic); _save_preferences())
	_apply_preferences()
	vehicle.drivetrain.config.drive_layout = preferences.values.drive_layout
	feedback.build(self)
	vehicle.reset_completed.connect(feedback.reset)
	vehicle.reset_completed.connect(reverse_assist.reset)
	vehicle_selector = RallyVehicleSelector.new()
	add_child(vehicle_selector)
	vehicle_selector.power_ps = vehicle.drivetrain.config.rated_power_ps
	vehicle_selector.build()
	vehicle_selector.confirmed.connect(_confirm_vehicle)
	vehicle_selector.cancelled.connect(_cancel_vehicle_selection)
	auto_driver.begin_run(generator.route,vehicle.position)
	pause_menu.set_autopilot_mode(auto_driver.mode_name())
	result_persistence_enabled = DisplayServer.get_name()!="headless" and not "--test-defaults" in OS.get_cmdline_user_args()
	if result_persistence_enabled:
		var result_error := result_store.load_file()
		if result_error!=OK: pause_menu.message.text = "成绩读取失败，本次仍可驾驶"
	_refresh_result_summary()
	if get_tree().paused: pause_menu.show_menu(true)
	# Physics tests and capture tools deliberately bypass the front-end, using defaults.
	if DisplayServer.get_name()!="headless" and not "--test-defaults" in OS.get_cmdline_user_args(): _open_vehicle_selection()


func _spawn_pose() -> Transform3D:
	return generator.route.pose_at(8)


func _driver_command(speed: float, dt: float) -> DriverCommand:
	if selecting_vehicle or respawn_wait or session.phase==RallyStageSession.Phase.FINISHED:
		var held := DriverCommand.new()
		held.brake = 1
		return held
	var command := auto_driver.sample(generator.route,vehicle,controls,speed,dt)
	var contacts := 0
	for wheel: RallyWheelState in vehicle.wheels:
		if wheel.grounded: contacts += 1
	command = reverse_assist.apply(command,controls.last_raw,vehicle.drivetrain,speed,contacts>=2,dt,preferences.values.reverse_assist)
	if command.throttle>0.01 or absf(command.steer)>0.01 or command.handbrake>0.01: has_driven = true
	if session.phase==RallyStageSession.Phase.COUNTDOWN:
		if command.throttle>0.01 and command.brake<0.05 and command.handbrake<0.05:
			session.countdown = 0
			session.phase = RallyStageSession.Phase.ARMED
		else: command.brake = 1
	return command


func _physics_process(dt: float) -> void:
	if get_tree().paused or selecting_vehicle: return
	recorder.capture(vehicle,auto_driver.telemetry(controls.active_device))
	if respawn_wait: return
	presentation.tire_marks.update(vehicle,dt)
	if RallyStageBounds.outside(generator.route,vehicle.position,vehicle.linear_velocity,dt,session.projection_hint):
		if session.phase==RallyStageSession.Phase.FINISHED:
			respawn_wait = true
			vehicle.request_reset(generator.route.pose_at(session.gates[-1]+8))
		else: _recover(10,"越界复位")
		return
	var previous_phase := session.phase
	session.step(vehicle.position, vehicle.linear_velocity.length(), dt)
	if previous_phase!=RallyStageSession.Phase.FINISHED and session.phase==RallyStageSession.Phase.FINISHED:
		_record_finish()
	if session.phase == RallyStageSession.Phase.FINISHED:
		if vehicle.position.y < generator.route.position_at(generator.route.length).y - 12 and not result_safety_reset:
			result_safety_reset = true
			vehicle.request_reset(generator.route.pose_at(session.gates[-1] + 8))
		return
	if presentation.scenery.spectator_intrusion(vehicle.position):
		_reset()


func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(game_hud): return
	readout.get_parent().get_parent().visible = telemetry_visible
	game_hud.visible = not telemetry_visible and not debug_panel.visible and not selecting_vehicle
	checkpoint_visual.visible = (telemetry_visible or debug_panel.visible) and session.next_gate < session.gates.size()
	if checkpoint_visual.visible:
		checkpoint_visual.transform = generator.route.pose_at(session.gates[session.next_gate],0.025)
	game_hud_clock += dt
	if not get_tree().paused: recovery_notice_time = maxf(0,recovery_notice_time-dt)
	if game_hud_clock >= 0.05:
		game_hud_clock = 0
		var data := RallyHUD.data_for(vehicle,session,get_tree().paused)
		data["camera_mode"] = camera_mode
		data["reverse_remaining"] = reverse_assist.remaining()
		data["returning_forward"] = reverse_assist.returning_forward
		data["reverse_assist"] = preferences.values.reverse_assist
		data.merge(auto_driver.telemetry(controls.active_device),true)
		data.merge(_result_hud_data(),true)
		if recovery_notice_time>0: data["warning"] = recovery_notice
		game_hud.refresh(data)
		debug_panel.set_driver_state(auto_driver.telemetry(controls.active_device))
	presentation.update(dt)
	feedback.update(vehicle,preferences,controls,get_tree().paused,dt)


func _exit_tree() -> void:
	feedback.dispose()
	presentation.dispose()


func _format_time(seconds: float) -> String:
	return "%02d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60)]


func _record_finish() -> void:
	if finish_recorded: return
	finish_recorded = true
	var source := auto_driver.source_name(controls.active_device)
	finish_record = result_store.record({
		"stage_id":generator.definition.stage_id,
		"drive_layout":vehicle.drivetrain.config.drive_layout,
		"calibration_version":vehicle.drivetrain.config.calibration_version,
		"driver_source":source,
		"eligible_for_human_best":source in ["human_keyboard","human_gamepad"],
		"elapsed":session.elapsed,
		"penalty":session.penalty,
		"total_time":session.total_time(),
		"reset_count":session.reset_count,
		"takeover_count":auto_driver.takeover_count,
		"practice":session.practice,
		"recorded_at":Time.get_unix_time_from_system(),
	})
	if bool(finish_record.get("saved",false)) and result_persistence_enabled:
		var error := result_store.save_file()
		if error!=OK:
			finish_record["save_error"] = error
			if is_instance_valid(pause_menu): pause_menu.message.text = "完赛有效，但成绩保存失败"
	_refresh_result_summary()


func _refresh_result_summary() -> void:
	result_summary = result_store.summary(generator.definition.stage_id,vehicle.drivetrain.config.drive_layout,vehicle.drivetrain.config.calibration_version)


func _result_hud_data() -> Dictionary:
	var category := str(finish_record.get("category","")) if session.phase==RallyStageSession.Phase.FINISHED else ""
	if category.is_empty():
		match auto_driver.source(controls.active_device):
			RallyAutoDriver.Source.AUTOPILOT_VKEYBOARD: category = "autopilot_vkeyboard"
			RallyAutoDriver.Source.AUTOPILOT_VGAMEPAD: category = "autopilot_vgamepad"
			RallyAutoDriver.Source.MIXED_TAKEOVER: category = "mixed"
			_: category = "human"
	var best: Dictionary = result_summary.get(category,{}) if category in ["autopilot_vkeyboard","autopilot_vgamepad"] else result_summary.get("human_best",{})
	var label := "个人最佳"
	if category=="autopilot_vkeyboard": label = "自动键盘参考"
	elif category=="autopilot_vgamepad": label = "自动手柄参考"
	elif category=="mixed": label = "混合驾驶 · 不计榜"
	return {
		"elapsed":session.elapsed,
		"best_time":float(best.get("total_time",-1.0)),
		"best_label":label,
		"new_record":bool(finish_record.get("new_record",false)),
		"result_category":category,
		"result_saved":bool(finish_record.get("saved",false)),
	}


func _reset() -> void:
	_recover(5,"车辆恢复")


func _recover(seconds: float,reason: String) -> void:
	if selecting_vehicle or respawn_wait or session.phase == RallyStageSession.Phase.FINISHED: return
	reverse_assist.reset()
	controls.clear()
	respawn_wait = true
	var old_penalty := session.penalty
	var pose := session.recover(seconds)
	auto_driver.reset_navigation(generator.route,pose.origin)
	vehicle.request_reset(pose)
	recovery_notice = "%s · +%d 秒"%[reason,session.penalty-old_penalty]
	recovery_notice_time = 3
	camera_snap = true


func _restart() -> void:
	if selecting_vehicle: return
	reverse_assist.reset()
	get_tree().paused = false
	controls.resume()
	respawn_wait = true
	var pose := session.restart()
	auto_driver.begin_run(generator.route,pose.origin)
	finish_record.clear()
	finish_recorded = false
	_refresh_result_summary()
	vehicle.request_reset(pose)
	result_safety_reset = false
	recovery_notice_time = 0
	has_driven = false
	startup_focus_pause = false
	recorder = VehicleTelemetryRecorder.new()
	presentation.tire_marks.clear()
	camera_snap = true
	if is_instance_valid(pause_menu): pause_menu.show_menu(false)


func _toggle_mode() -> void:
	if selecting_vehicle: return
	session.practice = not session.practice
	_restart()


func _apply_preferences() -> void:
	light_assist = preferences.values.keyboard_light
	preferences.apply_input(controls,light_assist)
	vehicle.drivetrain.automatic = preferences.values.automatic
	vehicle.config.front_brake_bias = preferences.values.brake_bias
	vehicle.config.static_compression = 0.13/float(preferences.values.spring_scale)
	presentation.flare.enabled = preferences.values.lens_flare
	presentation.scenery.set_quality(preferences.values.low_detail)
	presentation.environment.ssao_enabled = not preferences.values.low_detail


func _setting_changed(key: String,value: Variant) -> void:
	if key=="reverse_assist": reverse_assist.reset()
	preferences.set_value(key,value)
	_apply_preferences()
	_save_preferences()


func _save_preferences() -> void:
	if DisplayServer.get_name()=="headless" or "--test-defaults" in OS.get_cmdline_user_args(): return
	if preferences.save_file()!=OK and is_instance_valid(pause_menu): pause_menu.message.text = "设置已生效，但本机保存失败"


func _toggle_profile() -> void:
	light_assist = not light_assist
	preferences.set_value("keyboard_light",light_assist)
	preferences.apply_input(controls,light_assist)
	_save_preferences()


func _cycle_camera() -> void:
	camera_mode = (camera_mode+1)%3
	camera_snap = true


func _toggle_pause() -> void:
	if selecting_vehicle: return
	reverse_assist.reset()
	startup_focus_pause = false
	super._toggle_pause()
	if is_instance_valid(pause_menu): pause_menu.show_menu(get_tree().paused)


func _safety_pause() -> void:
	reverse_assist.reset()
	if selecting_vehicle:
		controls.suspend()
		get_tree().paused = true
		return
	if not get_tree().paused: startup_focus_pause = not has_driven and session.next_gate==0
	super._safety_pause()
	if is_instance_valid(pause_menu): pause_menu.show_menu(true)


func _restore_launch_focus() -> void:
	if startup_focus_pause and get_tree().paused:
		_toggle_pause()


func _export() -> void:
	if selecting_vehicle: return
	reverse_assist.reset()
	super._export()
	if is_instance_valid(pause_menu):
		pause_menu.show_menu(true)
		pause_menu.message.text = "遥测导出失败，请检查本机存储" if notice.text=="Export failed" else "遥测已导出至 user://telemetry/，继续驾驶前请确认"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_L:
		_setting_changed("lens_flare",not preferences.values.lens_flare)


func _reset_preferences() -> void:
	var chosen := vehicle.drivetrain.config.drive_layout
	preferences.reset()
	preferences.set_value("drive_layout",chosen)
	reverse_assist.reset()
	_apply_preferences()
	_save_preferences()


func _open_vehicle_selection(can_cancel: bool = false) -> void:
	debug_panel.set_enabled(false)
	selecting_vehicle = true
	startup_focus_pause = false
	reverse_assist.reset()
	controls.suspend()
	get_tree().paused = true
	pause_menu.show_menu(false)
	vehicle_selector.open(vehicle.drivetrain.config.drive_layout,can_cancel)


func _toggle_debug() -> void:
	if selecting_vehicle: return
	super._toggle_debug()


func _cycle_autopilot() -> void:
	if selecting_vehicle: return
	auto_driver.cycle()
	controls.clear()
	auto_driver.reset_navigation(generator.route,vehicle.position)
	if is_instance_valid(pause_menu): pause_menu.set_autopilot_mode(auto_driver.mode_name())


func _set_autopilot_mode_name(mode: String) -> void:
	if selecting_vehicle: return
	auto_driver.set_mode_name(mode)
	controls.clear()
	auto_driver.reset_navigation(generator.route,vehicle.position)
	if is_instance_valid(pause_menu): pause_menu.set_autopilot_mode(auto_driver.mode_name())


func _human_drive_input(_device: int) -> void:
	if not auto_driver.human_takeover(): return
	controls.filter.reset()
	controls.virtual_active = false
	if is_instance_valid(pause_menu): pause_menu.set_autopilot_mode(auto_driver.mode_name())


func _confirm_vehicle(layout: String) -> void:
	if layout not in ["FWD","AWD","RWD"]: return
	vehicle.drivetrain.config.drive_layout = layout
	preferences.set_value("drive_layout",layout)
	_save_preferences()
	selecting_vehicle = false
	vehicle_selector.close()
	_restart()


func _cancel_vehicle_selection() -> void:
	if not vehicle_selector.allow_cancel: return
	selecting_vehicle = false
	vehicle_selector.close()
	pause_menu.show_menu(true)
