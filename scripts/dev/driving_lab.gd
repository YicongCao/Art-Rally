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


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	vehicle = RallyVehicle.new()
	vehicle.name = "Vehicle"
	vehicle.position = TestGround.SPAWN
	vehicle.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(vehicle)
	vehicle.reset_completed.connect(func(): camera_snap = true)
	controls = RallyInputController.new()
	add_child(controls)
	vehicle.command_source = controls.sample
	controls.pause_requested.connect(_toggle_pause)
	controls.safety_pause_requested.connect(_safety_pause)
	controls.reset_requested.connect(_reset)
	controls.camera_requested.connect(func(): camera_mode = (camera_mode + 1) % 2; camera_snap = true)
	controls.telemetry_requested.connect(func(): telemetry_visible = not telemetry_visible)
	controls.profile_requested.connect(_toggle_profile)
	controls.export_requested.connect(_export)
	controls.transmission_requested.connect(func(): vehicle.drivetrain.automatic = not vehicle.drivetrain.automatic)
	camera = $Camera
	_build_hud()
	debug_visual = MeshInstance3D.new()
	debug_visual.mesh = debug_mesh
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.vertex_color_use_as_albedo = true
	debug_visual.material_override = material
	add_child(debug_visual)


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
	notice.text = "W/S throttle/brake | A/D steer | SPACE handbrake\nQ/E shift (1 > N > R at rest) | R reset | C camera | T telemetry\nF2 keyboard assist | F8 export | ESC pause | gamepad START resume"
	notice.add_theme_font_size_override("font_size", 15)
	column.add_child(notice)


func _physics_process(_dt: float) -> void:
	if get_tree().paused: return
	recorder.capture(vehicle)
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
	readout.text = "ART RALLY / DRIVING LAB\n%03d km/h    GEAR %s    %s" % [vehicle.linear_velocity.length() * 3.6, _gear_name(), "PAUSED - ENTER TO RESUME" if get_tree().paused else "ASPHALT"]
	details.visible = telemetry_visible
	debug_visual.visible = telemetry_visible
	if telemetry_visible:
		details.text = "%s | %s assist | physics %.2f ms\nSTEER %+.2f   GAS %.2f   BRAKE %.2f\n" % ["Keyboard" if controls.active_device < 0 else "Gamepad %d" % controls.active_device, "Light" if light_assist else "Standard", vehicle.physics_usec / 1000.0, vehicle.command.steer, vehicle.command.throttle, vehicle.command.brake]
		details.text += "%d RPM | %s | clutch %.2f\n" % [vehicle.drivetrain.rpm(), "AUTO (M)" if vehicle.drivetrain.automatic else "MANUAL (M)", vehicle.drivetrain.clutch]
		for i: int in range(4):
			var wheel := vehicle.wheels[i]
			details.text += "%s  %4d N  %3d mm  slip %+.2f  angle %+.1f\n" % [["FL", "FR", "RL", "RR"][i], wheel.load, wheel.length * 1000, wheel.slip, rad_to_deg(wheel.slip_angle)]
		_draw_forces()


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
	vehicle.request_reset(Transform3D(Basis.IDENTITY, TestGround.SPAWN))
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
