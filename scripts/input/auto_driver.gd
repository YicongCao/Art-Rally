class_name RallyAutoDriver
extends RefCounted

enum Mode { OFF, VIRTUAL_KEYBOARD, VIRTUAL_GAMEPAD }
enum Source { HUMAN_KEYBOARD, HUMAN_GAMEPAD, AUTOPILOT_VKEYBOARD, AUTOPILOT_VGAMEPAD, MIXED_TAKEOVER, TEST_HARNESS }

const MODE_NAMES := ["off", "vkeyboard", "vgamepad"]
const SOURCE_NAMES := ["human_keyboard", "human_gamepad", "autopilot_vkeyboard", "autopilot_vgamepad", "mixed_takeover", "test_harness"]

var mode: int = Mode.OFF
var pilot := RallyRoutePilot.new()
var raw_command := DriverCommand.new()
var filtered_command := DriverCommand.new()
var used_in_run: bool = false
var takeover_count: int = 0


func set_mode(next_mode: int) -> void:
	mode = clampi(next_mode,Mode.OFF,Mode.VIRTUAL_GAMEPAD)
	if mode != Mode.OFF:
		used_in_run = true


func set_mode_name(value: String) -> void:
	set_mode(clampi(MODE_NAMES.find(value), 0, MODE_NAMES.size() - 1))


func cycle() -> void:
	set_mode((mode + 1) % MODE_NAMES.size())


func mode_name() -> String:
	return MODE_NAMES[int(mode)]


func label() -> String:
	match mode:
		Mode.VIRTUAL_KEYBOARD: return "AUTO · KB"
		Mode.VIRTUAL_GAMEPAD: return "AUTO · PAD"
		_: return ""


func begin_run(route: RallyStageRoute, position: Vector3) -> void:
	pilot.reset(route, position)
	raw_command = DriverCommand.new()
	filtered_command = DriverCommand.new()
	used_in_run = mode != Mode.OFF
	takeover_count = 0


func reset_navigation(route: RallyStageRoute, position: Vector3) -> void:
	pilot.reset(route, position)
	raw_command = DriverCommand.new()
	filtered_command = DriverCommand.new()


func human_takeover() -> bool:
	if mode == Mode.OFF:
		return false
	mode = Mode.OFF
	takeover_count += 1
	raw_command = DriverCommand.new()
	filtered_command = DriverCommand.new()
	return true


func sample(route: RallyStageRoute, vehicle: RallyVehicle, controls: RallyInputController, speed: float, dt: float) -> DriverCommand:
	if mode == Mode.OFF:
		return controls.sample(speed, dt)
	var intent: DriverCommand = pilot.step(route, vehicle, speed, 10.0 if mode == Mode.VIRTUAL_KEYBOARD else 15.0)
	raw_command = _encode(intent, controls, speed,vehicle.drivetrain.config.power_multiplier)
	filtered_command = controls.sample_virtual(raw_command, speed, dt, mode == Mode.VIRTUAL_KEYBOARD)
	return filtered_command


func source(active_device: int) -> int:
	if used_in_run:
		if takeover_count > 0 or mode == Mode.OFF:
			return Source.MIXED_TAKEOVER
		return Source.AUTOPILOT_VKEYBOARD if mode == Mode.VIRTUAL_KEYBOARD else Source.AUTOPILOT_VGAMEPAD
	return Source.HUMAN_KEYBOARD if active_device < 0 else Source.HUMAN_GAMEPAD


func source_name(active_device: int) -> String:
	return SOURCE_NAMES[int(source(active_device))]


func telemetry(active_device: int) -> Dictionary:
	return {
		"source_id": int(source(active_device)),
		"source": source_name(active_device),
		"mode": mode_name(),
		"label": label(),
		"target_speed": pilot.wanted_speed,
		"lateral_error": pilot.lateral_error,
		"lookahead": pilot.lookahead,
		"raw_steer": raw_command.steer,
		"raw_throttle": raw_command.throttle,
		"raw_brake": raw_command.brake,
		"takeovers": takeover_count,
	}


func _encode(intent: DriverCommand, controls: RallyInputController, speed: float,power_multiplier: float = 1.0) -> DriverCommand:
	var raw := DriverCommand.new()
	if mode == Mode.VIRTUAL_KEYBOARD:
		var error := intent.steer - controls.filter.steering
		raw.steer = signf(error) if absf(error) > 0.015 else 0.0
		raw.throttle = 1.0 if speed < pilot.wanted_speed else 0.0
		if power_multiplier>1.0:
			# Close the loop around the shared asymmetric keyboard pedal ramp.
			# Fast key-release filtering makes open-loop duty cycling too weak.
			raw.throttle = 1.0 if controls.filter.throttle<raw.throttle/power_multiplier else 0.0
		raw.brake = 1.0 if speed > pilot.wanted_speed + 0.7 else 0.0
	else:
		raw.steer = _stick_axis(intent.steer, controls.filter.profile)
		raw.throttle = intent.throttle/maxf(1.0,power_multiplier)
		raw.brake = intent.brake
	return raw


static func _stick_axis(value: float, profile: InputProfile) -> float:
	if is_zero_approx(value):
		return 0.0
	var magnitude := profile.stick_deadzone + pow(clampf(absf(value), 0.0, 1.0), 1.0 / profile.stick_exponent) * (1.0 - profile.stick_deadzone)
	return signf(value) * clampf(magnitude, 0.0, 1.0)
