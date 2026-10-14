extends "res://tests/test_suite.gd"


func _run() -> void:
	var raw := DriverCommand.new()
	raw.steer = 1
	raw.throttle = 1
	var slow := DriverInputFilter.new()
	var fast := DriverInputFilter.new()
	for i: int in range(120):
		slow.step(raw, 0, 1.0 / 120, true)
		fast.step(raw, 40, 1.0 / 120, true)
	check(slow.steering > 0.99 and fast.steering < 0.25, "Keyboard high-speed steering limit does not affect low-speed lock")
	check(is_equal_approx(slow.throttle, 1.0), "Throttle reaches full input")
	raw.steer = -1
	for i: int in range(20):
		slow.step(raw, 0, 1.0 / 120, true)
	check(slow.steering < 0, "Countersteer crosses zero promptly")
	var a := DriverInputFilter.new()
	var b := DriverInputFilter.new()
	for i: int in range(6): a.step(raw, 10, 1.0 / 60, true)
	for i: int in range(12): b.step(raw, 10, 1.0 / 120, true)
	check(absf(a.steering - b.steering) < 0.0001 and absf(a.throttle - b.throttle) < 0.0001, "Input ramps depend on elapsed time, not frame count")
	check(is_zero_approx(a.stick(0.1)) and is_equal_approx(a.stick(-1), -1), "Stick deadzone and full range")
	var controller := RallyInputController.new()
	root.add_child(controller)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_E
	key.pressed = true
	controller._unhandled_input(key)
	check(controller.sample(0, 0.01).shift == 1 and controller.sample(0, 0.01).shift == 0, "Shift edge is consumed only once")
	key.physical_keycode = KEY_W
	controller._unhandled_input(key)
	check(controller.sample(0, 0.01).throttle > 0, "Keyboard events feed command interface")
	var axis := InputEventJoypadMotion.new()
	axis.device = 7
	axis.axis = JOY_AXIS_LEFT_X
	axis.axis_value = 0.7
	controller._unhandled_input(axis)
	check(controller.active_device == 7 and is_zero_approx(controller.sample(0, 0.01).throttle), "Device switch clears held keyboard throttle, supports nonzero device ID")
	controller.suspend()
	controller._unhandled_input(key)
	controller.resume()
	check(is_zero_approx(controller.sample(0, 0.01).throttle), "Pause/resume does not retain held input")
	controller.queue_free()
	await process_frame
	finish()
