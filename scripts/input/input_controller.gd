class_name RallyInputController
extends Node

signal pause_requested
signal safety_pause_requested
signal reset_requested
signal camera_requested
signal telemetry_requested
signal transmission_requested
signal profile_requested
signal export_requested
signal contact_requested

var filter := DriverInputFilter.new()
var active_device: int = -1
var blocked: bool = false
var pending_shift: int = 0
var keys: Dictionary = {}
var buttons: Dictionary = {}
var axes: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_joy_connection_changed)


func _notification(what: int) -> void:
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


func _select_device(device: int) -> void:
	if active_device != device:
		clear()
		active_device = device


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey:
		if event.echo:
			return
		var code: int = event.physical_keycode
		if event.pressed and code in [KEY_ESCAPE, KEY_ENTER]:
			pause_requested.emit()
			return
		if blocked:
			return
		if code not in [KEY_W, KEY_S, KEY_A, KEY_D, KEY_SPACE, KEY_Q, KEY_E, KEY_R, KEY_C, KEY_T, KEY_M, KEY_F2, KEY_F3, KEY_F8]:
			return
		if event.pressed:
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
				KEY_T: telemetry_requested.emit()
				KEY_M: transmission_requested.emit()
				KEY_F2: profile_requested.emit()
				KEY_F3: contact_requested.emit()
				KEY_F8: export_requested.emit()
	elif event is InputEventJoypadMotion:
		if blocked or event.axis not in [JOY_AXIS_LEFT_X, JOY_AXIS_TRIGGER_LEFT, JOY_AXIS_TRIGGER_RIGHT]:
			return
		if absf(event.axis_value) > 0.18:
			_select_device(event.device)
		if event.device == active_device:
			axes[event.axis] = event.axis_value
	elif event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_START and event.pressed:
			pause_requested.emit()
			return
		if blocked:
			return
		if event.pressed:
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
	var raw := DriverCommand.new()
	if active_device == -1:
		raw.steer = float(keys.get(KEY_D, false)) - float(keys.get(KEY_A, false))
		raw.throttle = float(keys.get(KEY_W, false))
		raw.brake = float(keys.get(KEY_S, false))
		raw.handbrake = float(keys.get(KEY_SPACE, false))
	else:
		raw.steer = filter.stick(axes.get(JOY_AXIS_LEFT_X, 0.0))
		raw.throttle = maxf(0, axes.get(JOY_AXIS_TRIGGER_RIGHT, 0.0))
		raw.brake = maxf(0, axes.get(JOY_AXIS_TRIGGER_LEFT, 0.0))
		raw.handbrake = float(buttons.get(JOY_BUTTON_A, false))
	raw.shift = pending_shift
	pending_shift = 0
	return filter.step(raw, speed, dt, active_device == -1)
