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
		check(scene.presentation.atmosphere.near_clouds[0].mesh.surface_get_material(0).get_shader_parameter("sun_direction").is_equal_approx(direction),id+" clouds follow the same light direction")
		if id == "sunset_ridge":
			check(rad_to_deg(asin(direction.y)) > 8 and rad_to_deg(asin(direction.y)) < 16,"Sunset uses low oblique light for long shadows")
			check(sun.light_color.r > sun.light_color.b and scene.presentation.environment.ambient_light_color.b > scene.presentation.environment.ambient_light_color.r,"Sunset combines warm direct light with cooler shade")
		elif id == "sunlit_cape":
			var sea := scene.presentation.scenery.dressing.get_node("CoastalOcean") as MeshInstance3D
			check(sea.material_override.get_shader_parameter("sun_direction").is_equal_approx(direction),"Ocean glints use the actual coastal sun")
		else:
			var environment: Environment = scene.presentation.environment
			check(environment.fog_enabled and environment.fog_height < scene.generator.route.points[0].y,"Morning mist occupies the lower valley")
			check(environment.fog_density <= .0007 and direction.y > 0,"Morning mist retains nearby road visibility and daylight")
		scene.free()
		await process_frame
	finish()
