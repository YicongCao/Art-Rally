extends "res://tests/test_suite.gd"

var scene: Node3D
var hint: int = -1
var max_lateral: float = 0


func _run() -> void:
	scene = load("res://scenes/dev/visual_sample.tscn").instantiate()
	root.add_child(scene)
	scene.set_process(false)
	scene.vehicle.command_source = drive
	var first_finish := Vector3.ZERO
	for styled: bool in [true,false]:
		scene.vehicle.command_source = Callable()
		scene.set_style(styled)
		scene._reset()
		await ticks(3)
		hint = scene.landscape.route.index_at(RallySampleLandscape.START)
		scene.vehicle.command_source = drive
		var duration := 0
		for i: int in range(120*60):
			await ticks(1)
			duration = i
			if scene.sample_complete: break
		check(scene.sample_complete, "200m sample can be driven with style=%s"%styled)
		await ticks(600)
		check(scene.vehicle.linear_velocity.length() < 0.2, "Sample finish automatically stops vehicle safely")
		if styled: first_finish = scene.vehicle.position
		else: check(scene.vehicle.position.distance_to(first_finish) < 0.15,"Visual A/B leaves physical driving result unchanged")
		print("PREVIEW DRIVE: styled=",styled," elapsed=",duration/120.0," lateral=",max_lateral)
	check(max_lateral < 1.0, "Sample is driveable without leaving road")
	scene.queue_free()
	await process_frame
	finish()


func drive(speed: float,_dt: float) -> DriverCommand:
	var command := DriverCommand.new()
	if scene.sample_complete:
		command.brake = 1
		return command
	var route: RallyStageRoute = scene.landscape.route
	var p := route.project(scene.vehicle.position,hint,35)
	hint = p.index
	max_lateral = maxf(max_lateral,absf(p.lateral))
	var lookahead := 7.0
	var local: Vector3 = scene.vehicle.to_local(route.position_at(float(p.s)+lookahead))
	command.steer = clampf(atan2(5.2*sin(atan2(local.x,-local.z)),lookahead)/0.55,-1,1)
	command.throttle = clampf(0.25+(10-speed)*0.25,0,0.8)
	command.brake = clampf((speed-10.3)*0.3,0,0.7)
	return command
