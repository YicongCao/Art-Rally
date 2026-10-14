extends SceneTree

const MAIN_SCENE: PackedScene = preload("res://scenes/dev/environment_check.tscn")
const ACTIONS: Array[StringName] = [
	&"throttle", &"brake", &"steer_left", &"steer_right", &"handbrake",
	&"shift_up", &"shift_down", &"reset_vehicle", &"change_camera", &"toggle_telemetry",
]

var failures: int = 0


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	_check(Engine.physics_ticks_per_second == 120, "Fixed physics step is 120 Hz")
	_check(ProjectSettings.get_setting("physics/3d/physics_engine") == "Jolt Physics", "Jolt backend is configured")
	_check(ProjectSettings.get_setting("physics/common/physics_interpolation"), "Physics interpolation is enabled")
	for action: StringName in ACTIONS:
		_check(InputMap.has_action(action) and not InputMap.action_get_events(action).is_empty(), "Input action: %s" % action)

	var scene: Node3D = MAIN_SCENE.instantiate() as Node3D
	root.add_child(scene)
	var probe: RigidBody3D = scene.get_node("Probe") as RigidBody3D
	_check(is_equal_approx(probe.position.y, 4.0), "Collision probe starts above ground")
	for tick: int in range(240):
		await physics_frame

	# The server singleton can be a wrapper; inspect the actual contact backend.
	_check(scene.get_world_3d().direct_space_state.get_class() == "JoltPhysicsDirectSpaceState3D", "Jolt backend is active")
	_check(is_finite(probe.position.y) and absf(probe.position.y - 0.5) < 0.08, "Rigid body rests on the ground")
	_check(probe.linear_velocity.length() < 0.1, "Rigid body settles without continuous movement")
	var query := PhysicsRayQueryParameters3D.create(Vector3(3, 5, 0), Vector3(3, -2, 0), 1)
	var hit: Dictionary = scene.get_world_3d().direct_space_state.intersect_ray(query)
	_check(not hit.is_empty(), "Terrain raycast reports contact")
	if not hit.is_empty():
		_check(absf(hit["position"].y) < 0.01, "Terrain contact matches the visual surface")

	scene.queue_free()
	await process_frame
	if failures == 0:
		print("SMOKE TEST PASSED")
	else:
		printerr("SMOKE TEST FAILED: %d checks" % failures)
	quit(0 if failures == 0 else 1)


func _check(condition: bool, message: String) -> void:
	if condition:
		print("PASS: %s" % message)
	else:
		failures += 1
		printerr("FAIL: %s" % message)
