class_name RallyDrivingRuntime
extends Node3D

var vehicle: RallyVehicle
var controls: RallyInputController
var recorder := VehicleTelemetryRecorder.new()
var camera: Camera3D
var readout: Label
var details: Label
var notice: Label
var debug_mesh := ImmediateMesh.new()
var debug_visual: MeshInstance3D
var hud_clock: float = 0.0
var camera_mode: int = 0
var camera_snap: bool = true
var telemetry_visible: bool = true
var light_assist: bool = false
var debug_panel: RallyDebugPanel


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	vehicle = RallyVehicle.new()
	vehicle.config = vehicle.config.duplicate()
	_configure_vehicle(vehicle)
	vehicle.name = "Vehicle"
	vehicle.transform = _spawn_pose()
	vehicle.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(vehicle)
	vehicle.reset_completed.connect(func(): camera_snap = true)
	controls = RallyInputController.new()
	add_child(controls)
	vehicle.command_source = _driver_command
	controls.pause_requested.connect(_toggle_pause)
	controls.safety_pause_requested.connect(_safety_pause)
	controls.reset_requested.connect(_reset)
	controls.camera_requested.connect(_cycle_camera)
	controls.telemetry_requested.connect(_toggle_telemetry)
	controls.debug_requested.connect(_toggle_debug)
	controls.profile_requested.connect(_toggle_profile)
	controls.export_requested.connect(_export)
	controls.transmission_requested.connect(func(): vehicle.drivetrain.automatic = not vehicle.drivetrain.automatic)
	controls.contact_requested.connect(func(): vehicle.config.contact_envelope = not vehicle.config.contact_envelope)
	camera = $Camera
	camera.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	_build_hud()
	var debug_layer := CanvasLayer.new()
	debug_layer.layer = 10
	add_child(debug_layer)
	debug_panel = RallyDebugPanel.new()
	debug_layer.add_child(debug_panel)
	debug_panel.bind_vehicle(vehicle)
	debug_visual = MeshInstance3D.new()
	debug_visual.mesh = debug_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	debug_visual.material_override = material
	add_child(debug_visual)
	controls.stage_requested.connect(func(): _switch_scene("res://scenes/stages/sunset_ridge.tscn"))
	controls.lab_requested.connect(func(): _switch_scene("res://scenes/dev/driving_lab.tscn"))


func _spawn_pose() -> Transform3D:
	return Transform3D(Basis.IDENTITY, TestGround.SPAWN)


func _cycle_camera() -> void:
	camera_mode = (camera_mode+1)%2
	camera_snap = true


func _driver_command(speed: float, dt: float) -> DriverCommand:
	return controls.sample(speed, dt)


func _switch_scene(path: String) -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(path)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var panel := PanelContainer.new()
	panel.position = Vector2(22, 22)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.09, 0.12, 0.91)
	style.border_width_left = 4
	style.border_color = Color("e09b4f")
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	panel.add_theme_stylebox_override("panel", style)
	layer.add_child(panel)
	var column := VBoxContainer.new()
	panel.add_child(column)
	readout = Label.new()
	readout.add_theme_font_size_override("font_size", 23)
	column.add_child(readout)
	details = Label.new()
	details.add_theme_font_size_override("font_size", 15)
	column.add_child(details)
	notice = Label.new()
	notice.text = "W/S throttle/brake | A/D steer | SPACE handbrake\nQ/E shift (1 > N > R at rest) | R reset | C camera | T telemetry / debug\nF2 keyboard assist | F8 export | ESC pause"
	notice.add_theme_font_size_override("font_size", 15)
	column.add_child(notice)


func _physics_process(_dt: float) -> void:
	if get_tree().paused: return
	recorder.capture(vehicle,{
		"source_id": RallyAutoDriver.Source.HUMAN_KEYBOARD if controls.active_device < 0 else RallyAutoDriver.Source.HUMAN_GAMEPAD,
	})
	if vehicle.position.y < -15: _reset()


func _process(dt: float) -> void:
	var pose := vehicle.get_global_transform_interpolated()
	var forward := -pose.basis.z
	forward.y = 0
	forward = forward.normalized()
	var target := pose.origin + Vector3.UP * 0.65
	var desired := target - forward * 7.5 + Vector3.UP * 3.0
	if camera_mode == 1:
		desired = pose * Vector3(0, 1.0, -0.9)
		target = desired + forward * 15
	if camera_snap or camera_mode == 1:
		camera.position = desired
		camera_snap = false
	else:
		camera.position = camera.position.lerp(desired, 1.0 - exp(-6.0 * dt))
	camera.look_at(target, Vector3.UP)
	hud_clock += dt
	if hud_clock < 0.05: return
	hud_clock = 0
	readout.text = "BRUSHLINE RALLY / DRIVING LAB\n%03d km/h    GEAR %s    %s" % [vehicle.linear_velocity.length() * 3.6, _gear_name(), "PAUSED - ENTER TO RESUME" if get_tree().paused else RallySurfaceQuery.PROFILES[vehicle.wheels[0].surface.surface_id].label]
	details.visible = telemetry_visible
	readout.get_parent().get_parent().visible = not debug_panel.visible
	debug_visual.visible = telemetry_visible or debug_panel.visible
	if telemetry_visible:
		details.text = "%s | %s assist | physics %.2f ms\nSTEER %+.2f   GAS %.2f   BRAKE %.2f\n" % ["Keyboard" if controls.active_device < 0 else "Gamepad %d" % controls.active_device, "Light" if light_assist else "Standard", vehicle.physics_usec / 1000.0, vehicle.command.steer, vehicle.command.throttle, vehicle.command.brake]
		details.text += "%d RPM | %s | clutch %.2f\n" % [vehicle.drivetrain.rpm(), "AUTO (M)" if vehicle.drivetrain.automatic else "MANUAL (M)", vehicle.drivetrain.clutch]
		details.text += "F3 contact: %s\n" % ("Envelope" if vehicle.config.contact_envelope else "Single ray")
		for i: int in range(4):
			var wheel := vehicle.wheels[i]
			details.text += "%s %4d N  slip %+.2f  %s  water %d mm\n" % [["FL", "FR", "RL", "RR"][i], wheel.load, wheel.slip, RallySurfaceQuery.PROFILES[wheel.surface.surface_id].label, wheel.surface.water_depth * 1000]
	if debug_visual.visible: _draw_forces()


func _toggle_debug() -> void:
	debug_panel.set_enabled(not debug_panel.visible)
	if debug_panel.visible: telemetry_visible = false


func _toggle_telemetry() -> void:
	_toggle_debug()


func _draw_forces() -> void:
	debug_mesh.clear_surfaces()
	debug_mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	for wheel: RallyWheelState in vehicle.wheels:
		if not wheel.grounded: continue
		debug_mesh.surface_set_color(Color("5bd2a8"))
		debug_mesh.surface_add_vertex(wheel.point)
		debug_mesh.surface_add_vertex(wheel.point + wheel.normal * wheel.load / 4000)
		debug_mesh.surface_set_color(Color("e6b564"))
		debug_mesh.surface_add_vertex(wheel.point + Vector3.UP * 0.05)
		debug_mesh.surface_add_vertex(wheel.point + Vector3.UP * 0.05 + (wheel.forward * wheel.longitudinal_force + wheel.right * wheel.lateral_force) / 3000)
	# An empty surface is invalid while airborne.
	debug_mesh.surface_add_vertex(Vector3(0, -2, 0))
	debug_mesh.surface_add_vertex(Vector3(0, -2, 0))
	debug_mesh.surface_end()


func _gear_name() -> String:
	return "R" if vehicle.drivetrain.gear < 0 else ("N" if vehicle.drivetrain.gear == 0 else str(vehicle.drivetrain.gear))


func _toggle_pause() -> void:
	if get_tree().paused:
		controls.resume()
		get_tree().paused = false
	else:
		controls.suspend()
		get_tree().paused = true


func _safety_pause() -> void:
	controls.suspend()
	get_tree().paused = true


func _reset() -> void:
	controls.clear()
	vehicle.request_reset(_spawn_pose())
	camera_snap = true


func _toggle_profile() -> void:
	light_assist = not light_assist
	controls.filter.profile = InputProfile.light_assist() if light_assist else InputProfile.new()


func _export() -> void:
	controls.suspend()
	get_tree().paused = true
	var path := recorder.export_csv(vehicle)
	notice.text = "Export failed" if path.is_empty() else "Telemetry exported. ENTER resumes.\n" + path
	print("Telemetry export: ", path)


func _configure_vehicle(_car: RallyVehicle) -> void:
	pass
