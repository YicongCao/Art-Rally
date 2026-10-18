class_name RallyRoutePilot
extends RefCounted

var hint: int = 0
var progress: float = 0.0
var lateral_error: float = 0.0
var lookahead: float = 5.0
var wanted_speed: float = 0.0
var target_point := Vector3.ZERO


func reset(route: RallyStageRoute, position: Vector3) -> void:
	var projection := route.project(position)
	hint = int(projection.index)
	progress = float(projection.s)
	lateral_error = float(projection.lateral)
	lookahead = 5.0
	wanted_speed = 0.0
	target_point = route.position_at(progress)


func step(route: RallyStageRoute, vehicle: RallyVehicle, speed: float, speed_cap: float = 15.0) -> DriverCommand:
	var projection := route.project(vehicle.position, hint, 35)
	if float(projection.distance) > 30.0:
		projection = route.project(vehicle.position)
	hint = int(projection.index)
	progress = float(projection.s)
	lateral_error = float(projection.lateral)
	lookahead = clampf(3.0 + speed * 0.55, 5.0, 13.0)
	target_point = route.position_at(minf(progress + lookahead, route.length))
	var local := vehicle.to_local(target_point)
	var target_angle := atan2(local.x, -local.z)
	var steering_angle := atan2(vehicle.config.wheelbase * 2.0 * sin(target_angle), lookahead)
	var command := DriverCommand.new()
	command.steer = clampf(steering_angle / vehicle.config.max_steer_radians, -1.0, 1.0)
	wanted_speed = minf(15.0, speed_cap)
	if route.definition.surface_id(progress)==2: wanted_speed = minf(wanted_speed,10.0)
	for crest: Vector3 in route.definition.crests:
		if absf(progress-crest.x)<35: wanted_speed = minf(wanted_speed,10.0)
	for ahead: float in [0.0, 10.0, 25.0, 45.0]:
		var station := minf(progress + ahead, route.length - 0.01)
		var after_station := minf(station + 8.0, route.length - 0.001)
		var curvature := route.tangent_at(station).angle_to(route.tangent_at(after_station)) / maxf(after_station - station, 0.001)
		var turn_speed := sqrt(2.8 / maxf(curvature, 0.001))
		wanted_speed = minf(wanted_speed, sqrt(turn_speed * turn_speed + 4.0 * ahead))
		if route.definition.water_depth(station, 0.0) > 0.005:
			wanted_speed = minf(wanted_speed, 8.5)
	command.throttle = clampf(0.25 + (wanted_speed - speed) * 0.22, 0.0, 1.0)
	command.brake = clampf((speed - wanted_speed - 0.3) * 0.22, 0.0, 0.7)
	return command
