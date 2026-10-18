class_name RallyInputController
extends Node

signal pause_requested
signal safety_pause_requested
signal focus_returned
signal reset_requested
signal camera_requested
signal telemetry_requested
signal debug_requested
signal autopilot_requested
signal human_drive_input(device: int)
signal transmission_requested
signal profile_requested
signal export_requested
signal contact_requested
signal restart_requested
signal mode_requested
signal stage_requested
signal lab_requested

var filter := DriverInputFilter.new()
var active_device: int = -1
var blocked: bool = false
var pending_shift: int = 0
var keys: Dictionary = {}
var bindings: Dictionary = {}
var allow_mechanical_shortcuts: bool = true
var buttons: Dictionary = {}
var axes: Dictionary = {}
var last_raw := DriverCommand.new()
var virtual_active: bool = false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_joy_connection_changed)


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_IN and is_inside_tree(): focus_returned.emit()
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_inside_tree():
		suspend()
		safety_pause_requested.emit()


func _joy_connection_changed(device: int, connected: bool) -> void:
	if device == active_device and not connected:
		suspend()
		active_device = -1
		safety_pause_requested.emit()


func suspend() -> void:
	blocked = true
	clear()


func resume() -> void:
	clear()
	blocked = false


func clear() -> void:
	keys.clear()
	buttons.clear()
	axes.clear()
	pending_shift = 0
	filter.reset()
	last_raw = DriverCommand.new()
	virtual_active = false


func _select_device(device: int) -> void:
	if active_device != device:
		clear()
		active_device = device


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.echo:
			return
		var code: int = event.physical_keycode
		var remapped := false
		for original: String in bindings:
			if int(bindings[original])==event.physical_keycode:
				code = int(original)
				remapped = true
				break
		if not remapped and bindings.has(str(code)) and int(bindings[str(code)])!=code: return
		if not allow_mechanical_shortcuts and code==KEY_F3: return
		if event.pressed and code in [KEY_ESCAPE, KEY_ENTER]:
			pause_requested.emit()
			return
		# Presentation shortcuts must not switch away from a connected gamepad or clear its axes.
		if code == KEY_T:
			if event.pressed: telemetry_requested.emit()
			return
		if code == KEY_F10:
			if event.pressed: autopilot_requested.emit()
			return
		if event.pressed and code in [KEY_F4, KEY_F5, KEY_F6, KEY_F7]:
			match code:
				KEY_F4: mode_requested.emit()
				KEY_F5: restart_requested.emit()
				KEY_F6: stage_requested.emit()
				KEY_F7: lab_requested.emit()
			return
		if blocked:
			return
		if code not in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_Q, KEY_E, KEY_R, KEY_C, KEY_T, KEY_M, KEY_F2, KEY_F3, KEY_F8]:
			return
		if event.pressed:
			if code in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_SPACE, KEY_Q, KEY_E]:
				human_drive_input.emit(-1)
			_select_device(-1)
		if active_device != -1:
			return
		keys[code] = event.pressed
		if event.pressed:
			match code:
				KEY_E: pending_shift = 1
				KEY_Q: pending_shift = -1
				KEY_R: reset_requested.emit()
				KEY_C: camera_requested.emit()
				KEY_M: transmission_requested.emit()
				KEY_F2: profile_requested.emit()
				KEY_F3: contact_requested.emit()
				KEY_F8: export_requested.emit()
	elif event is InputEventJoypadMotion:
		if blocked or event.axis not in [JOY_AXIS_LEFT_X, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			return
		var active: bool = absf(event.axis_value) > 0.18 if event.axis == JOY_AXIS_LEFT_X else event.axis_value > 0.18
		if active:
			human_drive_input.emit(event.device)
			_select_device(event.device)
		if event.device == active_device:
			axes[event.axis] = event.axis_value
	elif event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_START and event.pressed:
			pause_requested.emit()
			return
		if event.button_index == JOY_BUTTON_BACK and event.pressed:
			restart_requested.emit()
			return
		if blocked:
			return
		if event.pressed:
			if event.button_index in [JOY_BUTTON_A, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER]:
				human_drive_input.emit(event.device)
			_select_device(event.device)
		if active_device != event.device:
			return
		buttons[event.button_index] = event.pressed
		if event.pressed:
			match event.button_index:
				JOY_BUTTON_RIGHT_SHOULDER: pending_shift = 1
				JOY_BUTTON_LEFT_SHOULDER: pending_shift = -1
				JOY_BUTTON_Y: reset_requested.emit()
				JOY_BUTTON_X: camera_requested.emit()


func sample(speed: float, dt: float) -> DriverCommand:
	if blocked:
		return DriverCommand.new()
	virtual_active = false
	var raw := DriverCommand.new()
	if active_device == -1:
		raw.steer = float(keys.get(KEY_D, false) or keys.get(KEY_RIGHT, false)) - float(keys.get(KEY_A, false) or keys.get(KEY_LEFT, false))
		raw.throttle = float(keys.get(KEY_W, false) or keys.get(KEY_UP, false))
		raw.brake = float(keys.get(KEY_S, false) or keys.get(KEY_DOWN, false))
		raw.handbrake = float(keys.get(KEY_SPACE, false))
	else:
		raw.steer = filter.stick(axes.get(JOY_AXIS_LEFT_X, 0.0))
		raw.throttle = maxf(0, axes.get(JOY_AXIS_TRIGGER_RIGHT, 0.0))
		raw.brake = maxf(0, axes.get(JOY_AXIS_TRIGGER_LEFT, 0.0))
		raw.handbrake = float(buttons.get(JOY_BUTTON_A, false))
	raw.shift = pending_shift
	pending_shift = 0
	last_raw = raw
	return filter.step(raw, speed, dt, active_device == -1)


func sample_virtual(device_raw: DriverCommand, speed: float, dt: float, keyboard: bool) -> DriverCommand:
	if blocked:
		return DriverCommand.new()
	virtual_active = true
	var raw := _copy_command(device_raw)
	if not keyboard:
		raw.steer = filter.stick(raw.steer)
	last_raw = raw
	return filter.step(raw, speed, dt, keyboard)


func rumble_device() -> int:
	return -1 if virtual_active else active_device


static func _copy_command(source: DriverCommand) -> DriverCommand:
	var result := DriverCommand.new()
	result.steer = source.steer
	result.throttle = source.throttle
	result.brake = source.brake
	result.handbrake = source.handbrake
	result.shift = source.shift
	return result
