class_name RallyDrivetrain
extends RefCounted

var config: RallyDrivetrainConfig = preload("res://resources/vehicles/drivetrain.tres")
var gear: int = 1
var automatic: bool = true
var engine_omega: float = 100.0
var shift_remaining: float = 0
var cooldown: float = 0
var clutch: float = 0
var clutch_torque: float = 0


func rpm() -> float:
	return engine_omega * 60.0 / TAU


func ratio() -> float:
	if gear == 0: return 0
	return (config.reverse_ratio if gear < 0 else config.ratios[gear - 1]) * config.final_drive


func reset() -> void:
	gear = 1
	engine_omega = config.idle_rpm * TAU / 60
	shift_remaining = 0
	cooldown = 0
	clutch = 0
	clutch_torque = 0


func begin_tick(command: DriverCommand, speed: float) -> void:
	if command.shift != 0:
		request_shift(gear + command.shift, speed)
	elif automatic and gear > 0 and cooldown <= 0:
		if rpm() > config.upshift_rpm and gear < 6:
			request_shift(gear + 1, speed)
		elif rpm() < config.downshift_rpm and gear > 1:
			request_shift(gear - 1, speed)


func request_shift(target: int, speed: float) -> bool:
	if shift_remaining > 0 or target < -1 or target > 6 or target == gear: return false
	if (target <= 0 or gear <= 0) and absf(speed) > 1.0: return false
	if target > 0 and gear > 0:
		var predicted := rpm() * config.ratios[target - 1] / config.ratios[gear - 1]
		if predicted > config.redline_rpm: return false
	gear = target
	shift_remaining = config.shift_seconds
	cooldown = 0.5
	return true


static func distribute(total: float, omega: PackedFloat64Array, handbrake: bool, settings: RallyDrivetrainConfig) -> PackedFloat64Array:
	var front := (omega[0] + omega[1]) * 0.5
	var rear := (omega[2] + omega[3]) * 0.5
	var central := 0.0 if handbrake else clampf((rear - front) * settings.diff_lock_gain, -settings.center_lock_limit, settings.center_lock_limit)
	var front_total := total if handbrake else total * 0.5 + central
	var rear_total := 0.0 if handbrake else total * 0.5 - central
	var fl := clampf((omega[1] - omega[0]) * settings.diff_lock_gain, -settings.axle_lock_limit, settings.axle_lock_limit)
	var rl := clampf((omega[3] - omega[2]) * settings.diff_lock_gain, -settings.axle_lock_limit, settings.axle_lock_limit)
	return PackedFloat64Array([front_total * 0.5 + fl, front_total * 0.5 - fl, rear_total * 0.5 + rl, rear_total * 0.5 - rl])


func step(command: DriverCommand, wheels: Array[RallyWheelState], dt: float) -> PackedFloat64Array:
	shift_remaining = maxf(0, shift_remaining - dt)
	cooldown = maxf(0, cooldown - dt)
	var omega := PackedFloat64Array([wheels[0].omega, wheels[1].omega, wheels[2].omega, wheels[3].omega])
	var handbrake := command.handbrake > 0.1
	var shaft_speed := (omega[0] + omega[1]) * 0.5 if handbrake else (omega[0] + omega[1] + omega[2] + omega[3]) * 0.25
	var gearing := ratio()
	var engaged_speed := shaft_speed * gearing
	var launch := smoothstep(1400, 2600, rpm())
	var running := smoothstep(700, 1500, absf(engaged_speed) * 60 / TAU)
	clutch = maxf(launch, running) if gear != 0 and shift_remaining <= 0 else 0.0
	var capacity := config.clutch_capacity * clutch
	clutch_torque = clampf((engine_omega - engaged_speed) * config.clutch_coupling, -capacity, capacity)
	var throttle := command.throttle if shift_remaining <= 0 and rpm() < config.redline_rpm else 0.0
	var idle_governor := clampf((config.idle_rpm - rpm()) * 0.5, 0, 130)
	var drag := 20.0 + engine_omega * 0.045
	var engine_torque := config.torque_at(rpm()) * throttle + idle_governor - drag - clutch_torque
	engine_omega = maxf(0, engine_omega + engine_torque / config.engine_inertia * dt)
	return distribute(clutch_torque * gearing, omega, handbrake, config)
