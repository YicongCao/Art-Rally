class_name SimpleDrivetrain
extends RefCounted

var gear: int = 1


func step(command: DriverCommand, speed: float) -> PackedFloat64Array:
	if command.shift != 0 and absf(speed) < 1.0:
		gear = clampi(gear + command.shift, -1, 1)
	var torque := command.throttle * 720.0 * gear
	return PackedFloat64Array([torque, torque, torque, torque])


func reset() -> void:
	gear = 1
