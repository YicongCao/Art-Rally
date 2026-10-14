extends SceneTree

var car: RallyVehicle
var counter: int = 0
var start := Vector3.ZERO
var braking_start := Vector3.ZERO
var data := {}


func _initialize() -> void:
	_run.call_deferred()


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	GrayboxGeometry.box(world, "Flat", Vector3(100, 1, 1200), Vector3(0, -0.5, -400), Color.GRAY, true)
	car = RallyVehicle.new()
	car.position = Vector3(0, 0.8, 0)
	car.command_source = replay
	world.add_child(car)


func replay(_speed: float, _dt: float) -> DriverCommand:
	var command := DriverCommand.new()
	if counter == 360: start = car.position
	if counter >= 360 and counter < 960: command.throttle = 1
	if counter == 960:
		braking_start = car.position
		data["acceleration_distance"] = start.distance_to(car.position)
		data["acceleration_speed"] = car.linear_velocity.length()
	if counter >= 960: command.brake = 1
	if counter == 1920:
		data["braking_distance"] = braking_start.distance_to(car.position)
		print("FRAME_PROBE: ", JSON.stringify(data))
		quit.call_deferred()
	counter += 1
	return command
