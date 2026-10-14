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


func _ready() -> void:
	generator = $Stage
	session.setup(generator.route)
	super._ready()
	vehicle.config.contact_envelope = true
	telemetry_visible = false
	controls.restart_requested.connect(_restart)
	controls.mode_requested.connect(_toggle_mode)
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
	pause_menu.setting_changed.connect(_setting_changed)
	pause_menu.defaults_requested.connect(func(): preferences.reset(); _apply_preferences(); _save_preferences())
	controls.transmission_requested.connect(func(): preferences.set_value("automatic",vehicle.drivetrain.automatic); _save_preferences())
	_apply_preferences()
	feedback.build(self)
	vehicle.reset_completed.connect(feedback.reset)
	if get_tree().paused: pause_menu.show_menu(true)


func _spawn_pose() -> Transform3D:
	return generator.route.pose_at(8)


func _driver_command(speed: float, dt: float) -> DriverCommand:
	if not session.accepts_input() or respawn_wait:
		var held := DriverCommand.new()
		held.brake = 1
		return held
	return controls.sample(speed, dt)


func _physics_process(dt: float) -> void:
	if get_tree().paused: return
	recorder.capture(vehicle)
	if respawn_wait: return
	session.step(vehicle.position, vehicle.linear_velocity.length(), dt)
	if session.phase == RallyStageSession.Phase.FINISHED:
		if vehicle.position.y < generator.route.position_at(generator.route.length).y - 12 and not result_safety_reset:
			result_safety_reset = true
			vehicle.request_reset(generator.route.pose_at(session.gates[-1] + 8))
		return
	if vehicle.position.y < generator.route.position_at(session.progress).y - 12 or float(session.projection.get("distance", 0)) > 35:
		_reset()
	elif presentation.scenery.spectator_intrusion(vehicle.position):
		_reset()


func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(game_hud): return
	readout.get_parent().get_parent().visible = telemetry_visible
	game_hud.visible = not telemetry_visible
	checkpoint_visual.visible = telemetry_visible and session.next_gate < session.gates.size()
	if checkpoint_visual.visible:
		checkpoint_visual.transform = generator.route.pose_at(session.gates[session.next_gate],0.025)
	game_hud_clock += dt
	if game_hud_clock >= 0.05:
		game_hud_clock = 0
		game_hud.refresh(RallyHUD.data_for(vehicle,session,get_tree().paused))
	presentation.update(dt)
	feedback.update(vehicle,preferences,controls,get_tree().paused,dt)


func _exit_tree() -> void:
	feedback.dispose()
	presentation.dispose()


func _format_time(seconds: float) -> String:
	return "%02d:%05.2f" % [int(seconds) / 60, fmod(seconds, 60)]


func _reset() -> void:
	if respawn_wait or session.phase == RallyStageSession.Phase.FINISHED: return
	controls.clear()
	respawn_wait = true
	vehicle.request_reset(session.recover())
	camera_snap = true


func _restart() -> void:
	get_tree().paused = false
	controls.resume()
	respawn_wait = true
	vehicle.request_reset(session.restart())
	result_safety_reset = false
	recorder = VehicleTelemetryRecorder.new()
	camera_snap = true
	if is_instance_valid(pause_menu): pause_menu.show_menu(false)


func _toggle_mode() -> void:
	session.practice = not session.practice
	_restart()


func _apply_preferences() -> void:
	preferences.apply_input(controls,light_assist)
	vehicle.drivetrain.automatic = preferences.values.automatic
	vehicle.config.front_brake_bias = preferences.values.brake_bias
	vehicle.config.static_compression = 0.13/float(preferences.values.spring_scale)
	presentation.flare.enabled = preferences.values.lens_flare
	presentation.scenery.set_quality(preferences.values.low_detail)
	presentation.environment.ssao_enabled = not preferences.values.low_detail


func _setting_changed(key: String,value: Variant) -> void:
	preferences.set_value(key,value)
	_apply_preferences()
	_save_preferences()


func _save_preferences() -> void:
	if DisplayServer.get_name()=="headless" or "--test-defaults" in OS.get_cmdline_user_args(): return
	if preferences.save_file()!=OK and is_instance_valid(pause_menu): pause_menu.message.text = "设置已生效，但本机保存失败"


func _toggle_profile() -> void:
	light_assist = not light_assist
	preferences.apply_input(controls,light_assist)


func _toggle_pause() -> void:
	super._toggle_pause()
	if is_instance_valid(pause_menu): pause_menu.show_menu(get_tree().paused)


func _safety_pause() -> void:
	super._safety_pause()
	if is_instance_valid(pause_menu): pause_menu.show_menu(true)


func _export() -> void:
	super._export()
	if is_instance_valid(pause_menu):
		pause_menu.show_menu(true)
		pause_menu.message.text = "遥测已导出至 user://telemetry/，继续驾驶前请确认"


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode==KEY_L:
		_setting_changed("lens_flare",not preferences.values.lens_flare)
