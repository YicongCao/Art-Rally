extends "res://tests/test_suite.gd"


func _run() -> void:
	var scene := load("res://scenes/dev/driving_lab.tscn").instantiate() as Node3D
	root.add_child(scene)
	await ticks(2)
	var ground := scene.get_node("Ground")
	check(ground.has_node("Asphalt") and ground.has_node("Ramp"), "Test ground builds shared visual and collision geometry")
	var space := scene.get_world_3d().direct_space_state
	for at: Vector3 in [Vector3(0, 0, 12), Vector3(0, 0, -600), Vector3(90, 0, -80)]:
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(at + Vector3.UP * 10, at + Vector3.DOWN, 1))
		check(not hit.is_empty() and absf(hit.position.y) < 0.01, "Driveable surface at %s" % at)
	var bump := space.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(-65, 3, -30), Vector3(-65, -1, -30), 1))
	check(not bump.is_empty() and bump.position.y > 0.08, "Bump exists in collision geometry")
	await ticks(12)
	check(scene.recorder.frames.size() > 0, "Playable scene records telemetry on physics ticks")
	scene._toggle_pause()
	check(paused and scene.controls.blocked, "Pause blocks vehicle input")
	scene._toggle_pause()
	check(not paused and not scene.controls.blocked, "Explicit resume clears blocked state")
	var path: String = scene.recorder.export_csv(scene.vehicle)
	check(not path.is_empty() and FileAccess.file_exists(path), "Telemetry CSV and metadata export succeeds")
	if not path.is_empty():
		var csv := FileAccess.open(path, FileAccess.READ)
		check(csv.get_csv_line().size() == csv.get_csv_line().size(), "Telemetry header and sample columns match")
		csv.close()
		DirAccess.remove_absolute(path)
		DirAccess.remove_absolute(path.replace(".csv", ".json"))
	scene.queue_free()
	await process_frame
	finish()
