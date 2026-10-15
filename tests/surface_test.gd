extends "res://tests/test_suite.gd"

var world: Node3D
var field: RallySurfaceField
var car: RallyVehicle
var metrics: Dictionary = {}
var compliant: bool = false


func _run() -> void:
	compliant = "--compliant" in OS.get_cmdline_user_args()
	world = Node3D.new()
	root.add_child(world)
	field = RallySurfaceField.new()
	world.add_child(field)
	var floor_body := GrayboxGeometry.box(world, "Ground", Vector3(300, 1, 1500), Vector3(0, -0.5, -400), Color.GRAY, true)
	field.attach(floor_body)
	field.patches = [{"bounds": AABB(Vector3(0, -2, -100), Vector3(20, 4, 200)), "id": 1}]
	var blend := RallySurfaceQuery.footprint(floor_body, Vector3.ZERO, Vector3.FORWARD, Vector3.RIGHT)
	check(blend.friction_scale < 1 and blend.friction_scale > 0.76, "Surface blending is limited to tire footprint at boundary")
	check(field.surface_at(Vector3(-1, 0, 0)).surface_id == 0 and field.surface_at(Vector3(1, 0, 0)).surface_id == 1, "Left/right wheels can sample independent materials")
	field.patches.clear()
	for id: int in range(3):
		field.base_id = id
		await fresh()
		car.command.throttle = 1
		var count := 0
		while car.linear_velocity.length() < 15 and count < 2400:
			await ticks(1)
			count += 1
		check(count < 2400, "Surface %d reaches controlled braking speed" % id)
		car.command.throttle = 0
		car.command.brake = 1
		var start := car.position
		count = 0
		while car.linear_velocity.length() > 0.15 and count < 1800:
			await ticks(1)
			count += 1
		metrics[RallySurfaceQuery.PROFILES[id].label] = start.distance_to(car.position)
		check(count < 1800 and car.position.is_finite(), "Surface %d brakes without instability" % id)
	check(metrics.Gravel > metrics.Asphalt and metrics.Mud > metrics.Gravel, "Baseline material curves produce distinct braking distances")
	field.base_id = 0
	var dry_speed := await water_run(0, false)
	var wet_speed := await water_run(0.10, false)
	check(wet_speed < dry_speed and absf(car.angular_velocity.y) < 0.03, "Symmetric water slows vehicle without unilateral yaw")
	await water_run(0.10, true)
	check(car.angular_velocity.y > 0.005, "Left-side immersion causes yaw toward drag side")
	var sample := RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[1], 0.08)
	var drag := sample.water_resistance(Vector3(2, 0, -20), 3000, 1.0 / 120, 312.5)
	check(drag.dot(Vector3(2, 0, -20)) < 0 and sample.grip(30) < sample.friction_scale, "Water drag dissipates energy and wet grip decreases")
	check(sample.water_resistance(Vector3.FORWARD, 0, 0.01, 312.5) == Vector3.ZERO, "Airborne wheel cannot receive water resistance")
	field.water.clear()
	field.base_id = 3
	await fresh()
	car.command.throttle = 0.8
	await ticks(480)
	check(car.linear_velocity.length() > 2 and car.wheels[0].surface.surface_id == 3, "Grass and soil remain driveable rather than an invisible barrier")
	field.base_id = 0
	await fresh()
	car.command.throttle = 1
	await ticks(480)
	car.command.throttle = 0
	field.patches = [{"bounds": AABB(Vector3(-100, -2, -1200), Vector3(100, 4, 1400)), "id": 2}]
	await ticks(1)
	check(car.wheels[0].surface.surface_id == 2 and car.wheels[1].surface.surface_id == 0, "Physical left and right tire contacts retain split-surface identity")
	car.command.brake = 0.7
	await ticks(48)
	check(car.angular_velocity.y < -0.01 and car.position.is_finite(), "Split-surface braking yaws toward high-grip side")
	field.patches.clear()
	await fresh()
	field.patches = [{"bounds": AABB(Vector3(-100, -2, -1200), Vector3(200, 4, 1180)), "id": 1}]
	car.command.throttle = 0.8
	var crossed := false
	var bounded := true
	for i: int in range(900):
		await ticks(1)
		crossed = crossed or car.wheels[0].surface.surface_id == 1
		bounded = bounded and car.position.is_finite() and car.position.y > 0.4 and car.position.y < 1.1
	check(crossed and bounded, "Material transition is continuous without geometry-induced launch")
	DirAccess.make_dir_recursive_absolute("res://logs")
	var output := FileAccess.open("res://logs/surface_metrics_compliant.json" if compliant else "res://logs/surface_metrics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(metrics, "\t"))
	print("SURFACE METRICS: ", metrics)
	world.queue_free()
	await process_frame
	finish()


func fresh() -> void:
	if is_instance_valid(car):
		car.queue_free()
		await ticks(2)
	car = RallyVehicle.new()
	car.config = car.config.duplicate()
	car.config.tire_contact_model = "COMPLIANT_PATCH" if compliant else "LEGACY"
	car.position = Vector3(0, 0.8, 0)
	world.add_child(car)
	await ticks(360)


func water_run(depth: float, left_only: bool) -> float:
	field.water.clear()
	await fresh()
	car.command.throttle = 1
	await ticks(480)
	car.command.throttle = 0
	if depth > 0:
		field.water = [{"bounds": AABB(Vector3(-100, -2, -1200), Vector3(100 if left_only else 200, 4, 1400)), "depth": depth}]
	await ticks(60)
	return car.linear_velocity.length()
