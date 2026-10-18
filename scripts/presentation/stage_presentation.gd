class_name RallyStagePresentation
extends RefCounted

var scenery := RallyStageScenery.new()
var atmosphere := RallySampleAtmosphere.new()
var car_style := RallySampleCar.new()
var flare := RallySampleFlare.new()
var environment: Environment
var scene: Node3D
var previous_msaa: int = 0
var previous_screen_aa: int = 0
var elapsed: float = 0
var camera_rig := RallyCameraRig.new()
var checkpoints := RallyCheckpointMarkers.new()
var tire_marks := RallyTireMarks.new()


func build(owner_scene: Node3D) -> void:
	scene = owner_scene
	scene.add_child(scenery)
	scenery.build(scene.generator)
	checkpoints.build(scene,scenery.route,scene.session.gates)
	tire_marks.build(scene)
	scene.vehicle.reset_completed.connect(tire_marks.break_trails)
	atmosphere.build_at(scenery.dressing,scenery.route,scenery.center,scene.get_node("Sun"),1.8)
	car_style.build(scene.vehicle,scene.vehicle_definition)
	camera_rig.definition = scene.vehicle_definition
	camera_rig.build(scene.camera)
	scene.vehicle.reset_completed.connect(camera_rig.reset)
	flare.build(scene.camera)
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/sample_sky.gdshader")
	material.set_shader_parameter("sun_direction",atmosphere.sun_direction)
	sky.sky_material = material
	environment.sky = sky
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("b8c5e2")
	environment.ambient_light_energy = 0.52
	environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	environment.tonemap_mode = Environment.TONE_MAPPER_ACES
	environment.fog_enabled = true
	environment.fog_light_color = Color("b6b8d5")
	environment.fog_light_energy = 0.75
	environment.fog_density = 0.00065
	environment.fog_sky_affect = 0.0
	environment.ssao_enabled = false
	environment.ssao_radius = 1
	_apply_biome(material)
	scene.get_node("WorldEnvironment").environment = environment
	scene.get_node("Sun").directional_shadow_max_distance = 170
	scene.camera.far = 6200
	scene.camera.fov = 62
	previous_msaa = scene.get_viewport().msaa_3d
	previous_screen_aa = scene.get_viewport().screen_space_aa
	scene.get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	scene.get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA


func update(dt: float) -> void:
	checkpoints.update(scene.session.next_gate)
	if not scene.get_tree().paused: elapsed += dt
	camera_rig.update(scene.camera,scene.vehicle,scene.camera_mode,scene.preferences.values.camera_motion,scene.get_tree().paused,dt)
	for i: int in range(scenery.foliage.animated_arms.size()):
		scenery.foliage.animated_arms[i].rotation.z = sin(elapsed*2.4+i)*0.2
	car_style.brake_material.emission_energy_multiplier = 1.5 if scene.vehicle.command.brake>0.1 else 0.15
	flare.update(scene.camera,atmosphere.sun_direction,true,dt)


func dispose() -> void:
	if is_instance_valid(scene) and scene.is_inside_tree():
		scene.get_viewport().msaa_3d = previous_msaa
		scene.get_viewport().screen_space_aa = previous_screen_aa


func _apply_biome(sky: ShaderMaterial) -> void:
	var biome: String = scene.generator.definition.environment_id
	if biome=="autumn": return
	var sun: DirectionalLight3D = scene.get_node("Sun")
	var palette: Array[Color]
	if biome=="coast":
		palette = [Color("fff0d4"),Color("d6e8e4"),Color("7eb7d2")]
		sun.light_color = Color("fff3d9")
		sun.light_energy = 1.35
		environment.ambient_light_color = Color("c9dce5")
		environment.fog_light_color = Color("d0e1dd")
		environment.fog_density = .00035
		atmosphere.sun_direction = Vector3(-.4,.78,-.48).normalized()
	else:
		palette = [Color("e3d9bb"),Color("b6c8d1"),Color("91acbc")]
		sun.light_color = Color("f8e6c0")
		sun.light_energy = 1.10
		environment.ambient_light_color = Color("9fb8c5")
		environment.fog_light_color = Color("b7ccd3")
		environment.fog_density = .0011
		environment.fog_height = scenery.bounds.position.y-12
		environment.fog_height_density = .008
		atmosphere.sun_direction = Vector3(.35,.40,-.85).normalized()
	sun.basis = Basis.looking_at(-atmosphere.sun_direction,Vector3.UP)
	sky.set_shader_parameter("sun_direction",atmosphere.sun_direction)
	for i: int in range(3):
		var key: String = ["horizon_sun","horizon_away","zenith_color"][i]
		sky.set_shader_parameter(key,palette[i])
		for cloud: MeshInstance3D in atmosphere.near_clouds+atmosphere.far_clouds:
			var material := cloud.mesh.surface_get_material(0)
			if material is ShaderMaterial:
				material = material.duplicate()
				material.set_shader_parameter(key,palette[i])
				material.set_shader_parameter("cloud_shadow",Color("a6bdc7") if biome=="highland" else Color("bdc9cd"))
				material.set_shader_parameter("cloud_light",Color("edf0e6") if biome=="highland" else Color("fff3d9"))
				material.set_shader_parameter("sun_direction",atmosphere.sun_direction)
				cloud.mesh.surface_set_material(0,material)
