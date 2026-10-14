extends "res://tests/test_suite.gd"


func _run() -> void:
	var generator := RallyStageGenerator.new()
	root.add_child(generator)
	var scenery := RallyStageScenery.new()
	root.add_child(scenery)
	scenery.build(generator)
	await ticks(2)
	check(generator.road_visuals.size() == generator.chunk_bodies.size(),"Every physical road chunk has a styled counterpart")
	check(scenery.foliage.placements.size()>20000 and scenery.gravel_batches>40,"Approved vegetation and gravel cover full stage")
	check(scenery.foliage.animated_arms.size()==28,"Four visible spectator groups are built")
	check(scenery.obstacles.size()>0,"Near-road tree trunks have simplified collision")
	var supported := true
	for s: int in range(20,3000,50):
		var p := generator.route.position_at(s)
		var hit := generator.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p+Vector3.UP*5,p-Vector3.UP*2,5))
		supported = supported and not hit.is_empty() and absf(hit.position.y-p.y)<0.08
	check(supported,"Scenery does not intrude into driveable road center")
	check(scenery.spectator_intrusion(scenery.spectator_zones[0]),"Spectator safety volume is active")
	check(not scenery.spectator_intrusion(generator.route.position_at(85)),"Spectator protection leaves normal road unobstructed")
	scenery.set_quality(true)
	check(not scenery.grass_batches[0].visible,"Low setting hides small detail without deleting collision")
	scenery.queue_free()
	generator.queue_free()
	await process_frame
	finish()
