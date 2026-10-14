extends "res://tests/test_suite.gd"

var scene: Node3D
var hint: int = 0
var max_lateral: float = 0
var samples := 0
var peak_cost: int = 0


func _run() -> void:
	scene = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	scene.vehicle.command_source = drive
	var trace := FileAccess.open("res://logs/stage_drive.csv", FileAccess.WRITE)
	trace.store_line("tick,s,lateral,speed,gate,phase")
	for i: int in range(120 * 650):
		await ticks(1)
		if i % 120 == 0:
			trace.store_line("%d,%.3f,%.3f,%.3f,%d,%d" % [i, scene.session.progress, scene.session.projection.get("lateral", 0), scene.vehicle.linear_velocity.length(), scene.session.next_gate, scene.session.phase])
		peak_cost = maxi(peak_cost, scene.vehicle.physics_usec)
		if scene.session.phase == RallyStageSession.Phase.FINISHED: break
		if scene.session.reset_count > 0 or not scene.vehicle.position.is_finite(): break
	trace.close()
	check(scene.session.phase == RallyStageSession.Phase.FINISHED, "Physical controller drives every checkpoint from start to finish")
	check(scene.session.reset_count == 0, "End-to-end stage needs no recovery or teleportation")
	check(max_lateral < 2.8, "Automated shakedown remains within road width")
	var report := {"finished": scene.session.phase == RallyStageSession.Phase.FINISHED, "elapsed": scene.session.elapsed, "max_lateral_m": max_lateral, "gates": scene.session.next_gate, "progress_m": scene.session.progress, "peak_vehicle_callback_ms": peak_cost / 1000.0}
	var output := FileAccess.open("res://logs/stage_drive_metrics.json", FileAccess.WRITE)
	output.store_string(JSON.stringify(report, "\t"))
	print("STAGE DRIVE: ", report)
	scene.queue_free()
	await process_frame
	finish()


func drive(speed: float, _dt: float) -> DriverCommand:
	var command := DriverCommand.new()
	if not scene.session.accepts_input():
		command.brake = 1
		return command
	var route: RallyStageRoute = scene.generator.route
	var p := route.project(scene.vehicle.position, hint, 35)
	hint = p.index
	max_lateral = maxf(max_lateral, absf(p.lateral))
	var lookahead := clampf(3.0 + speed * 0.55, 5, 13)
	var target := route.position_at(p.s + lookahead)
	var local: Vector3 = scene.vehicle.to_local(target)
	var angle := atan2(local.x, -local.z)
	command.steer = clampf(atan2(2.6 * 2 * sin(angle), lookahead) / 0.55, -1, 1)
	var wanted := 15.0
	if p.s > 1110 and p.s < 1650: wanted = 10.0
	if absf(p.s - 2650) < 50: wanted = 10.0
	for ahead: float in [0, 10, 25, 45]:
		var s: float = p.s + ahead
		var before := route.tangent_at(s)
		var after := route.tangent_at(s + 8)
		var curvature := before.angle_to(after) / 8.0
		var turn_speed := sqrt(2.8 / maxf(curvature, 0.001))
		wanted = minf(wanted, sqrt(turn_speed * turn_speed + 2.0 * 2.0 * ahead))
	command.throttle = clampf(0.25 + (wanted - speed) * 0.22, 0, 1)
	command.brake = clampf((speed - wanted - 0.3) * 0.22, 0, 0.7)
	return command
