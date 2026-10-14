extends "res://scripts/dev/driving_lab.gd"

var landscape: RallySampleLandscape
var styled_environment: Environment
var gray_environment: Environment
var sample_label: Label
var show_hud: bool = true
var sample_complete: bool = false
var projection_hint: int = -1


func _ready() -> void:
	landscape = $Landscape
	super._ready()
	vehicle.config.contact_envelope = true
	telemetry_visible = false
	controls.restart_requested.connect(_reset)
	_setup_light()
	sample_label = readout
	notice.text = "WASD drive | SPACE handbrake | R restart | C camera\nG visual A/B | 1/2/3 viewpoints | TAB clean view | F7 lab\n200 m sample only - full stage remains unchanged"
	for label: Label in [readout, details, notice]: label.add_theme_font_size_override("font_size",14)


func _spawn_pose() -> Transform3D:
	return $Landscape.route.pose_at(RallySampleLandscape.START+3)


func _setup_light() -> void:
	gray_environment = $WorldEnvironment.environment.duplicate(true)
	styled_environment = Environment.new()
	styled_environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/sample_sky.gdshader")
	sky.sky_material = material
	styled_environment.sky = sky
	styled_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	styled_environment.ambient_light_color = Color("aec4cd")
	styled_environment.ambient_light_energy = 0.48
	styled_environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	styled_environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	styled_environment.fog_enabled = true
	styled_environment.fog_light_color = Color("a5bbc3")
	styled_environment.fog_light_energy = 0.7
	styled_environment.fog_density = 0.00075
	styled_environment.ssao_enabled = true
	styled_environment.ssao_radius = 1.0
	styled_environment.ssao_intensity = 1.0
	$WorldEnvironment.environment = styled_environment
	$Sun.rotation_degrees = Vector3(-34,-65,0)
	$Sun.light_color = Color("ffe3b4")
	$Sun.light_energy = 1.15
	$Sun.directional_shadow_max_distance = 170
	camera.far = 2800


func _physics_process(_dt: float) -> void:
	if get_tree().paused: return
	recorder.capture(vehicle)
	var p := landscape.route.project(vehicle.position,projection_hint,35)
	projection_hint = p.index
	if float(p.s) >= RallySampleLandscape.END:
		sample_complete = true
	if float(p.distance) > 18 or float(p.height) < -12 or float(p.s) < RallySampleLandscape.BUFFER_START+3:
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
	var p := landscape.route.project(vehicle.position,projection_hint,35)
	readout.text = "PINE RIDGE / VISUAL STUDY 01\n%03d km/h   %s   %03d / 200 m" % [vehicle.linear_velocity.length()*3.6,_gear_name(),clampf(float(p.s)-RallySampleLandscape.START,0,200)]
	if get_tree().paused: readout.text += "\nPAUSED - ENTER / START TO RESUME"
	elif sample_complete: readout.text += "\nSAMPLE COMPLETE - R TO RESTART"
	readout.get_parent().get_parent().visible = show_hud


func _reset() -> void:
	sample_complete = false
	projection_hint = landscape.route.index_at(RallySampleLandscape.START)
	super._reset()


func _unhandled_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	match event.physical_keycode:
		KEY_G:
			landscape.set_style(not landscape.style_enabled)
			$WorldEnvironment.environment = styled_environment if landscape.style_enabled else gray_environment
		KEY_TAB: show_hud = not show_hud
		KEY_1: jump_to(433)
		KEY_2: jump_to(515)
		KEY_3: jump_to(590)


func jump_to(s: float) -> void:
	sample_complete = false
	controls.clear()
	projection_hint = landscape.route.index_at(s)
	vehicle.request_reset(landscape.route.pose_at(s))
	camera_snap = true
