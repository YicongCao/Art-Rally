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
var sky_life := RallySkyLife.new()
var tail_streaks := RallyTailStreaks.new()
var road_posts := RallyBreakablePosts.new()


func build(owner_scene: Node3D) -> void:
	scene = owner_scene
	scene.add_child(scenery)
	scenery.build(scene.generator)
	scene.add_child(road_posts)
	road_posts.build(scenery,scene.vehicle)
	scene.add_child(sky_life)
	sky_life.build(scenery)
	checkpoints.build(scene,scenery.route,scene.session.gates)
	tire_marks.build(scene)
	scene.vehicle.reset_completed.connect(tire_marks.break_trails)
	# Painted sky replaces intersecting 3D cloud blobs. Keep the light convention.
	atmosphere.sun_direction = Vector3(-.6,.4,-.6).normalized()
	scenery.dressing.add_child(atmosphere.cloud_root)
	car_style.build(scene.vehicle,scene.vehicle_definition)
	tail_streaks.build(scene,scene.vehicle.config.body_size,scene.vehicle_definition.vehicle_id if scene.vehicle_definition!=null else "A240",car_style.body)
	scene.vehicle.reset_completed.connect(tail_streaks.clear)
	camera_rig.definition = scene.vehicle_definition
	camera_rig.appearance_body = car_style.body
	camera_rig.build(scene.camera)
	scene.vehicle.reset_completed.connect(camera_rig.reset)
	scene.controls.view_reset_requested.connect(camera_rig.reset)
	flare.build(scene.camera)
	environment = Environment.new()
	environment.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/sample_sky.gdshader")
	material.set_shader_parameter("painted_banks",true)
	material.set_shader_parameter("cloud_atlas",preload("res://assets/sky/comic/cloud-banks.png"))
	material.set_shader_parameter("cloud_drift",0.0)
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
	if not scene.get_tree().paused:
		elapsed += dt
		# Slow bank drift; update only twice per second to amortize sky radiance updates.
		if int(elapsed*2)!=int((elapsed-dt)*2):
			environment.sky.sky_material.set_shader_parameter("cloud_drift",elapsed*.00035)
		sky_life.advance(dt)
		tail_streaks.update(scene.vehicle.get_global_transform_interpolated(),scene.vehicle.linear_velocity.length(),dt,scene.camera)
	camera_rig.update(scene.camera,scene.vehicle,scene.camera_mode,scene.preferences.values.camera_motion,scene.get_tree().paused,dt,scene.controls.look_vector())
	for i: int in range(scenery.foliage.animated_arms.size()):
		scenery.foliage.animated_arms[i].rotation.z = sin(elapsed*2.4+i)*0.2
	for boat: Dictionary in scenery.sailboats:
		boat.node.position = boat.origin+boat.direction*fmod(elapsed*.65,600.0)+Vector3.UP*sin(elapsed*1.2)*.12
	car_style.brake_material.emission_energy_multiplier = 1.5 if scene.vehicle.command.brake>0.1 else 0.15
	flare.update(scene.camera,atmosphere.sun_direction,true,dt)


func dispose() -> void:
	if is_instance_valid(scene) and scene.is_inside_tree():
		scene.get_viewport().msaa_3d = previous_msaa
		scene.get_viewport().screen_space_aa = previous_screen_aa


func _apply_biome(sky: ShaderMaterial) -> void:
	var biome: String = scene.generator.definition.environment_id
	var sun: DirectionalLight3D = scene.get_node("Sun")
	var palette: Array[Color]
	var cloud_light := Color("fff3d9")
	var cloud_shadow := Color("bdc9cd")
	if biome=="autumn":
		palette = [Color("ffca86"),Color("ed9aa9"),Color("487dc4")]
		var forward: Vector3 = scene.generator.route.tangent_at(430)
		forward.y = 0
		var horizontal: Vector3 = forward.normalized().rotated(Vector3.UP,deg_to_rad(-65))
		atmosphere.sun_direction = horizontal*cos(deg_to_rad(12.5))+Vector3.UP*sin(deg_to_rad(12.5))
		sun.light_color = Color("ffe1b5")
		sun.light_energy = 1.80
		environment.ambient_light_color = Color("809ac3")
		environment.ambient_light_energy = .36
		environment.fog_light_color = Color("bdafcf")
		environment.fog_density = .00032
		cloud_light = Color("ffe6ac")
		cloud_shadow = Color("a18abd")
	elif biome=="coast":
		palette = [Color("fff0d4"),Color("d6e8e4"),Color("7eb7d2")]
		sun.light_color = Color("fff3d9")
		sun.light_energy = 1.35
		environment.ambient_light_color = Color("c9dce5")
		environment.fog_light_color = Color("d0e1dd")
		environment.fog_density = .00035
		atmosphere.sun_direction = Vector3(-.4,.78,-.48).normalized()
		var sea := scenery.dressing.get_node("CoastalOcean") as MeshInstance3D
		sea.material_override.set_shader_parameter("sun_direction",atmosphere.sun_direction)
	else:
		palette = [Color("f4e7c9"),Color("c0d5d9"),Color("8daebd")]
		sun.light_color = Color("ffe5bb")
		sun.light_energy = 1.1
		environment.ambient_light_color = Color("a4b6cb")
		environment.ambient_light_energy = .65
		environment.fog_light_color = Color("bed2d2")
		environment.fog_light_energy = .85
		environment.fog_density = .00065
		environment.fog_height = scene.generator.route.points[0].y-12
		environment.fog_height_density = .002
		var morning := Vector3(.35,0,-.85).normalized()
		atmosphere.sun_direction = morning*cos(deg_to_rad(18))+Vector3.UP*sin(deg_to_rad(18))
		cloud_light = Color("f0ebd9")
		cloud_shadow = Color("a6bdc7")
	for backdrop: Node in scenery.dressing.get_children():
		if backdrop is MeshInstance3D and str(backdrop.name).begins_with("MountainLayer"):
			var painted := ShaderMaterial.new()
			painted.shader = preload("res://assets/shaders/anime_mountain.gdshader")
			painted.set_shader_parameter("sun_direction",atmosphere.sun_direction)
			painted.set_shader_parameter("layer",float(str(backdrop.name).trim_prefix("MountainLayer")))
			painted.set_shader_parameter("shade_color",Color("646da2"))
			painted.set_shader_parameter("lit_color",Color("efc391"))
			if biome=="highland":
				painted.set_shader_parameter("shade_color",Color("526485"))
				painted.set_shader_parameter("lit_color",Color("adb4b6"))
			if biome=="coast":
				painted.set_shader_parameter("shade_color",Color("629ba4"))
				painted.set_shader_parameter("lit_color",Color("ede1bf"))
			backdrop.material_override = painted
	sun.basis = Basis.looking_at(-atmosphere.sun_direction,Vector3.UP)
	sky.set_shader_parameter("cloud_atlas_warmth",1.0 if biome=="autumn" else .10)
	sky.set_shader_parameter("cloud_light",cloud_light)
	sky.set_shader_parameter("cloud_shadow",cloud_shadow)
	sky.set_shader_parameter("cloud_mid",cloud_light.lerp(cloud_shadow,.45))
	sky.set_shader_parameter("sun_direction",atmosphere.sun_direction)
	for i: int in range(3):
		var key: String = ["horizon_sun","horizon_away","zenith_color"][i]
		sky.set_shader_parameter(key,palette[i])
	for cloud: MeshInstance3D in atmosphere.near_clouds+atmosphere.far_clouds:
		var material := cloud.mesh.surface_get_material(0) as ShaderMaterial
		if material == null: continue
		material = material.duplicate()
		for i: int in range(3): material.set_shader_parameter(["horizon_sun","horizon_away","zenith_color"][i],palette[i])
		material.set_shader_parameter("cloud_shadow",cloud_shadow)
		material.set_shader_parameter("cloud_light",cloud_light)
		material.set_shader_parameter("sun_direction",atmosphere.sun_direction)
		cloud.mesh.surface_set_material(0,material)
