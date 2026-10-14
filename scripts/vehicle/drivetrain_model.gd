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
var auto_shift_cut: bool = false
var wheelspin: float = 0
var rolling_rpm: float = 0
var output_torque: float = 0
var effective_throttle: float = 0


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
	auto_shift_cut = false
	wheelspin = 0
	rolling_rpm = 0
	output_torque = 0
	effective_throttle = 0


func road_rpm(speed: float, target: int, wheel_radius: float = 0.34) -> float:
	if target <= 0: return 0
	return maxf(speed, 0) / wheel_radius * config.ratios[target - 1] * config.final_drive * 60 / TAU


func driven_omega(wheels: Array[RallyWheelState], handbrake: bool = false) -> float:
	if wheels.is_empty(): return 0
	if config.drive_layout == "FWD" or (config.drive_layout == "AWD" and handbrake): return (wheels[0].omega + wheels[1].omega) * 0.5
	if config.drive_layout == "RWD": return (wheels[2].omega + wheels[3].omega) * 0.5
	return (wheels[0].omega + wheels[1].omega + wheels[2].omega + wheels[3].omega) * 0.25


func begin_tick(command: DriverCommand, speed: float, wheel_radius: float = 0.34, wheels: Array[RallyWheelState] = [], forward_speed: float = NAN) -> void:
	auto_shift_cut = false
	var travel := maxf(forward_speed if is_finite(forward_speed) else speed, 0)
	rolling_rpm = road_rpm(travel, gear, wheel_radius)
	wheelspin = absf(driven_omega(wheels) * wheel_radius - travel) / maxf(travel, 3) if not wheels.is_empty() else 0.0
	if command.shift != 0:
		request_shift(gear + command.shift, speed)
		return
	if not automatic or gear <= 0 or cooldown > 0 or shift_remaining > 0 or command.handbrake > 0.1: return
	if not wheels.is_empty():
		var supported := false
		for i: int in range(4):
			if (config.drive_layout == "FWD" and i >= 2) or (config.drive_layout == "RWD" and i < 2): continue
			supported = supported or (wheels[i].grounded and wheels[i].load > 50)
		if not supported: return
	# Road speed determines useful gearing; engine RPM alone can be inflated by wheelspin.
	if rolling_rpm < config.downshift_rpm and gear > 1:
		var target := gear - 1
		var recovery_rpm := config.downshift_target_rpm if command.throttle > 0.25 else 3200.0
		while target > 1 and road_rpm(travel, target - 1, wheel_radius) <= recovery_rpm: target -= 1
		var shaft := absf(driven_omega(wheels)) if not wheels.is_empty() else travel / wheel_radius
		var predicted := maxf(road_rpm(travel, target, wheel_radius), shaft * config.ratios[target - 1] * config.final_drive * 60 / TAU)
		if predicted < config.redline_rpm * 0.97:
			request_shift(target, speed, predicted)
		else:
			# Briefly lift to remove spin before a safe downshift; do not falsify RPM or wheel speed.
			auto_shift_cut = true
		return
	var coupling_slip := absf(engine_omega - driven_omega(wheels) * ratio()) / maxf(engine_omega, 100) if not wheels.is_empty() else 0.0
	if gear < 6 and command.brake < 0.1 and rpm() > config.upshift_rpm and rolling_rpm > config.upshift_rpm * config.upshift_road_fraction and wheelspin < config.max_upshift_slip and coupling_slip < 0.28:
		request_shift(gear + 1, speed)


func request_shift(target: int, speed: float, synchronized_rpm: float = NAN) -> bool:
	if shift_remaining > 0 or target < -1 or target > 6 or target == gear: return false
	if (target <= 0 or gear <= 0) and absf(speed) > 1.0: return false
	if target > 0 and gear > 0:
		var predicted := synchronized_rpm if is_finite(synchronized_rpm) else rpm() * config.ratios[target - 1] / config.ratios[gear - 1]
		if predicted > config.redline_rpm: return false
	gear = target
	shift_remaining = config.shift_seconds
	cooldown = 0.5
	return true


static func distribute(total: float, omega: PackedFloat64Array, handbrake: bool, settings: RallyDrivetrainConfig) -> PackedFloat64Array:
	var front_lock := clampf((omega[1]-omega[0])*settings.diff_lock_gain,-settings.axle_lock_limit,settings.axle_lock_limit)
	var rear_lock := clampf((omega[3]-omega[2])*settings.diff_lock_gain,-settings.axle_lock_limit,settings.axle_lock_limit)
	if settings.drive_layout=="FWD":
		return PackedFloat64Array([total*0.5+front_lock,total*0.5-front_lock,0,0])
	if settings.drive_layout=="RWD":
		var rear_drive := 0.0 if handbrake else total
		return PackedFloat64Array([0,0,rear_drive*0.5+rear_lock,rear_drive*0.5-rear_lock])
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
	var shaft_speed := driven_omega(wheels,handbrake)
	var gearing := ratio()
	var engaged_speed := shaft_speed * gearing
	var launch := smoothstep(1400, 2600, rpm())
	var running := smoothstep(700, 1500, absf(engaged_speed) * 60 / TAU)
	clutch = maxf(launch, running) if gear != 0 and shift_remaining <= 0 else 0.0
	if config.drive_layout=="RWD" and handbrake: clutch = 0
	var capacity := config.clutch_capacity * clutch
	clutch_torque = clampf((engine_omega - engaged_speed) * config.clutch_coupling, -capacity, capacity)
	effective_throttle = command.throttle if shift_remaining <= 0 and rpm() < config.redline_rpm and not auto_shift_cut else 0.0
	var idle_governor := clampf((config.idle_rpm - rpm()) * 0.5, 0, 130)
	var drag := 20.0 + engine_omega * 0.045
	# The published torque curve is net shaft torque; retain closed-throttle engine braking.
	output_torque = (config.torque_at(rpm()) + drag) * effective_throttle + idle_governor - drag
	var engine_torque := output_torque - clutch_torque
	engine_omega = maxf(0, engine_omega + engine_torque / config.engine_inertia * dt)
	return distribute(clutch_torque * gearing, omega, handbrake, config)
