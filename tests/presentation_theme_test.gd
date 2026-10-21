extends "res://tests/test_suite.gd"


func _run() -> void:
	for id: String in RallyContentCatalog.STAGES:
		var scene: Node3D = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
		scene.get_node("Stage").definition = RallyContentCatalog.stage(id)
		root.add_child(scene)
		await ticks(2)
		var sun: DirectionalLight3D = scene.get_node("Sun")
		var direction: Vector3 = scene.presentation.atmosphere.sun_direction
		var sky: ShaderMaterial = scene.presentation.environment.sky.sky_material
		check(sun.global_basis.z.is_equal_approx(direction) and sky.get_shader_parameter("sun_direction").is_equal_approx(direction),id+" sky and shadows share the actual light direction")
		check(sky.get_shader_parameter("painted_banks") == true,id+" painted sky is enabled in the actual driving scene")
		check(scene.presentation.atmosphere.near_clouds.is_empty() and scene.presentation.atmosphere.far_clouds.is_empty(),id+" no legacy cloud meshes intersect the painted sky")
		var before: float = sky.get_shader_parameter("cloud_drift")
		scene.presentation.update(.6)
		check(float(sky.get_shader_parameter("cloud_drift"))>before,id+" cloud banks drift in the running scene")
		paused = true
		before = sky.get_shader_parameter("cloud_drift")
		scene.presentation.update(.6)
		check(is_equal_approx(float(sky.get_shader_parameter("cloud_drift")),before),id+" cloud drift pauses with the race")
		paused = false
		if id == "sunset_ridge":
			check(rad_to_deg(asin(direction.y)) > 8 and rad_to_deg(asin(direction.y)) < 16,"Sunset uses low oblique light for long shadows")
			check(sun.light_color.r > sun.light_color.b and scene.presentation.environment.ambient_light_color.b > scene.presentation.environment.ambient_light_color.r,"Sunset combines warm direct light with cooler shade")
		elif id == "sunlit_cape":
			var sea := scene.presentation.scenery.dressing.get_node("CoastalOcean") as MeshInstance3D
			check(sea.material_override.get_shader_parameter("sun_direction").is_equal_approx(direction),"Ocean glints use the actual coastal sun")
		elif id=="misty_highlands":
			var environment: Environment = scene.presentation.environment
			check(environment.fog_enabled and environment.fog_height < scene.generator.route.points[0].y,"Morning mist occupies the lower valley")
			check(environment.fog_density <= .0007 and direction.y > 0,"Morning mist retains nearby road visibility and daylight")
		scene.free()
		await process_frame
	finish()
