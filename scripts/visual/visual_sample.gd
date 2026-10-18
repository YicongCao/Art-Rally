extends "res://scripts/dev/driving_lab.gd"

var landscape: RallySampleLandscape
var styled_environment: Environment
var gray_environment: Environment
var sample_label: Label
var show_hud: bool = true
var sample_complete: bool = false
var projection_hint: int = -1
var scenery := RallySampleDressing.new()
var car_style := RallySampleCar.new()
var animation_time: float = 0
var saved_msaa: int = 0
var saved_sun_color: Color
var saved_sun_rotation: Vector3
var saved_sun_energy: float
var camera_history_valid: bool = false
var chase_position := Vector3.ZERO
var effects := RallySampleEffects.new()
var atmosphere := RallySampleAtmosphere.new()
var flare := RallySampleFlare.new()
var sun_view: bool = false
var gravel := RallySampleGravel.new()


func _ready() -> void:
	landscape = $Landscape
	super._ready()
	vehicle.config.contact_envelope = true
	telemetry_visible = false
	saved_msaa = get_viewport().msaa_3d
	saved_sun_color = $Sun.light_color
	saved_sun_energy = $Sun.light_energy
	saved_sun_rotation = $Sun.rotation_degrees
	controls.restart_requested.connect(_reset)
	atmosphere.build(landscape, $Sun)
	_setup_light()
	scenery.build(landscape)
	gravel.build(landscape)
	car_style.build(vehicle)
	effects.build(self)
	flare.build(camera)
	vehicle.reset_completed.connect(func(): camera_history_valid = false)
	controls.camera_requested.connect(func(): camera_history_valid = false)
	sample_label = readout
	notice.text = "WASD drive | SPACE handbrake | R restart | C camera\nG visual A/B | 1/2/3 views | V sun view | L lens flare\nTAB clean view | F7 lab | 200 m sample only"
	for label: Label in [readout, details, notice]: label.add_theme_font_size_override("font_size",14)
	readout.add_theme_font_override("font",RallyFonts.TEXT)
	readout.add_theme_font_size_override("font_size",18)
	notice.add_theme_font_size_override("font_size",12)


func _spawn_pose() -> Transform3D:
	return $Landscape.route.pose_at(RallySampleLandscape.START+3)


func _setup_light() -> void:
	gray_environment = $WorldEnvironment.environment.duplicate(true)
	styled_environment = Environment.new()
	styled_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/sample_sky.gdshader")
	material.set_shader_parameter("sun_direction", atmosphere.sun_direction)
	sky.sky_material = material
	styled_environment.sky = sky
	styled_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	styled_environment.ambient_light_color = Color("b8c5e2")
	styled_environment.ambient_light_energy = 0.52
	styled_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	styled_environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	styled_environment.fog_enabled = true
	styled_environment.fog_light_color = Color("b6b8d5")
	styled_environment.fog_light_energy = 0.75
	styled_environment.fog_density = 0.00065
	styled_environment.fog_sky_affect = 0.0
	styled_environment.ssao_enabled = true
	styled_environment.ssao_radius = 1.0
	styled_environment.ssao_intensity = 1.0
	$WorldEnvironment.environment = styled_environment
	atmosphere.apply_sun($Sun)
	$Sun.directional_shadow_max_distance = 170
	camera.far = 2800
	camera.fov = 62
	get_viewport().msaa_3d = Viewport.MSAA_4X


func _physics_process(_dt: float) -> void:
	if get_tree().paused: return
	recorder.capture(vehicle)
	var p := landscape.route.project(vehicle.position,projection_hint,35)
	projection_hint = p.index
	if float(p.s) >= RallySampleLandscape.END:
		sample_complete = true
	if float(p.distance) > 18 or float(p.height) < -12 or float(p.s) < RallySampleLandscape.BUFFER_START+3 or float(p.s) > RallySampleLandscape.BUFFER_END-8:
		_reset()


func _driver_command(speed: float, dt: float) -> DriverCommand:
	if sample_complete:
		var held := DriverCommand.new()
		held.brake = 1
		return held
	return controls.sample(speed,dt)


func _process(dt: float) -> void:
	super._process(dt)
	if not is_instance_valid(sample_label): return
	if camera_mode == 0:
		var pose := vehicle.get_global_transform_interpolated()
		var forward := -pose.basis.z
		forward.y = 0
		forward = forward.normalized()
		var desired := pose.origin-forward*6.6+Vector3.UP*2.55
		chase_position = chase_position.lerp(desired,1.0-exp(-9.0*dt)) if camera_history_valid else desired
		camera_history_valid = true
		camera.position = chase_position
		camera.look_at(pose.origin+forward*9+Vector3.UP*1.3)
	if sun_view:
		var horizontal := Vector3(atmosphere.sun_direction.x,0,atmosphere.sun_direction.z).normalized().rotated(Vector3.UP,deg_to_rad(20))
		camera.look_at(camera.global_position+(horizontal*cos(deg_to_rad(9))+Vector3.UP*sin(deg_to_rad(9)))*100)
	flare.update(camera,atmosphere.sun_direction,landscape.style_enabled,dt)
	if not get_tree().paused: animation_time += dt
	for i: int in range(scenery.animated_arms.size()):
		scenery.animated_arms[i].rotation.z = sin(animation_time*2.4+i)*0.2
	car_style.brake_material.emission_energy_multiplier = 1.5 if vehicle.command.brake > 0.1 else 0.15
	effects.update(vehicle,landscape.style_enabled)
	var p := landscape.route.project(vehicle.position,projection_hint,35)
	readout.text = "PINE RIDGE / 16:00 STUDY 02\n%03d km/h   %s   %03d / 200 m" % [vehicle.linear_velocity.length()*3.6,_gear_name(),clampf(float(p.s)-RallySampleLandscape.START,0,200)]
	if get_tree().paused: readout.text += "\nPAUSED - ENTER / START TO RESUME"
	elif sample_complete: readout.text += "\nSAMPLE COMPLETE - R TO RESTART"
	readout.get_parent().get_parent().visible = show_hud and not debug_panel.visible


func _reset() -> void:
	sample_complete = false
	projection_hint = landscape.route.index_at(RallySampleLandscape.START)
	super._reset()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_G:
			set_style(not landscape.style_enabled)
		KEY_TAB: show_hud = not show_hud
		KEY_1: jump_to(433)
		KEY_2: jump_to(515)
		KEY_3: jump_to(590)
		KEY_V: sun_view = not sun_view
		KEY_L: flare.enabled = not flare.enabled


func jump_to(s: float) -> void:
	sample_complete = false
	controls.clear()
	projection_hint = landscape.route.index_at(s)
	vehicle.request_reset(landscape.route.pose_at(s))
	camera_snap = true
	camera_history_valid = false


func set_style(enabled: bool) -> void:
	landscape.set_style(enabled)
	car_style.set_style(enabled)
	$WorldEnvironment.environment = styled_environment if enabled else gray_environment
	if enabled:
		atmosphere.apply_sun($Sun)
	else:
		$Sun.light_color = saved_sun_color
		$Sun.light_energy = saved_sun_energy
		$Sun.rotation_degrees = saved_sun_rotation


func _exit_tree() -> void:
	get_viewport().msaa_3d = saved_msaa
