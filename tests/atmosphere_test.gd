extends "res://tests/test_suite.gd"


func _run() -> void:
	var scene: Node3D = load("res://scenes/dev/visual_sample.tscn").instantiate()
	root.add_child(scene)
	await ticks(2)
	var atmosphere: RallySampleAtmosphere = scene.atmosphere
	check(atmosphere.near_clouds.size() > 8 and atmosphere.far_clouds.size() > 12, "Two finite-distance cloud layers provide near and far geometry")
	var direction: Vector3 = scene.get_node("Sun").global_basis.z
	check(direction.is_equal_approx(atmosphere.sun_direction), "Sky disc cloud shading and directional light share the sun vector")
	check(absf(rad_to_deg(asin(direction.y)) - 24) < 0.01, "Afternoon art direction uses a 24-degree solar elevation")
	var near := atmosphere.near_clouds[0]
	var far := atmosphere.far_clouds[0]
	var before_near := near.global_transform
	var before_far := far.global_transform
	scene.set_process(false)
	scene.camera.global_position += Vector3(60, 0, 0)
	scene.camera.rotate_y(0.5)
	check(near.global_transform == before_near and far.global_transform == before_far, "Clouds stay world anchored when camera moves and turns")
	var origin := scene.landscape.center as Vector3
	var motion := Vector3(50,0,0)
	var near_angle := (near.global_position-origin).angle_to(near.global_position-origin-motion)
	var far_angle := (far.global_position-origin).angle_to(far.global_position-origin-motion)
	check(near_angle > far_angle, "Lateral camera translation produces stronger near-layer parallax")
	var arrays := near.mesh.surface_get_arrays(0)
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	check(normals[0].is_equal_approx(normals[1]) and normals.size() > 500, "Clouds have flat triangle normals rather than billboard/noise surfaces")
	scene.set_style(false)
	check(not near.is_visible_in_tree(), "Graybox comparison hides finite cloud layers")
	scene.queue_free()
	await process_frame
	finish()
