extends "res://tests/test_suite.gd"


func _run() -> void:
	var generator := RallyStageGenerator.new()
	root.add_child(generator)
	await ticks(3)
	var route := generator.route
	check(route.length > 2950 and route.length < 3150, "Stage length is approximately three kilometers")
	check(route.validate().is_empty(), "Route passes slope continuity and nonadjacent clearance checks")
	check(generator.chunk_bodies.size() > 50, "Collision chunks exist before driving begins")
	var space := generator.get_world_3d().direct_space_state
	var misses := 0
	var bad_height := 0
	for i: int in range(0, route.points.size(), 10):
		for lateral: float in [-2.2, 0, 2.2]:
			# Avoid exact triangle vertices where ray/edge ownership is numerically ambiguous.
			var p := route.points[i] + route.rights[i] * lateral + route.tangents[i] * 0.01
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3.UP * 5, p - Vector3.UP * 5, 1))
			if hit.is_empty(): misses += 1
			elif absf(hit.position.y - p.y) > 0.02 or hit.normal.y < 0.8: bad_height += 1
	print("GEOMETRY PROBES: misses=", misses, " bad_height=", bad_height)
	check(misses == 0 and bad_height == 0, "Road center edges and chunk seams share continuous visual collision geometry")
	for s: float in [200, 1300, 1800, 2200]:
		check(generator.surface_at(route.position_at(s)).surface_id == generator.definition.surface_id(s), "Stage surface zone at %d m" % s)
	check(generator.surface_at(route.position_at(1280)).water_depth > 0, "Stage puddle overlays muddy road")
	check(generator.surface_at(route.position_at(1280) + route.rights[route.index_at(1280)] * 6).surface_id == 3, "Off-road soil is distinct from main road")
	var again := RallyStageRoute.new()
	again.build(generator.definition)
	check(again.points == route.points, "Fixed definition regenerates identical road samples")
	check(route.notes.size() > 10, "Route includes turns and explicit surface hazard notes")
	var recoveries_valid := true
	for s: int in range(14, int(route.length - 60), 100):
		var pose := route.pose_at(s)
		for offset: Vector3 in [Vector3(-0.8, 0, -1.3), Vector3(0.8, 0, -1.3), Vector3(-0.8, 0, 1.3), Vector3(0.8, 0, 1.3)]:
			var mount := pose * offset
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(mount, mount - pose.basis.y * 1.2, 1))
			recoveries_valid = recoveries_valid and not hit.is_empty()
	check(recoveries_valid, "Every checkpoint recovery pose has support under all four wheels")
	print("STAGE GEOMETRY: length=", route.length, " samples=", route.points.size(), " chunks=", generator.chunk_bodies.size())
	generator.queue_free()
	await process_frame
	finish()
