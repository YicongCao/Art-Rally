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
	var unsafe := DriverCommand.new()
	unsafe.steer = NAN
	unsafe.throttle = INF
	unsafe.brake = -3
	unsafe.handbrake = 5
	unsafe.sanitize()
	check(unsafe.steer == 0 and unsafe.throttle == 0 and unsafe.brake == 0 and unsafe.handbrake == 1, "Invalid commands cannot inject NaN or out-of-range control")
	controller._unhandled_input(axis)
	controller._joy_connection_changed(7, false)
	check(controller.blocked and controller.active_device == -1 and controller.sample(0, 0.01).steer == 0, "Active controller disconnect blocks and clears commands")
	controller.resume()
	controller.bindings={str(KEY_R):KEY_BACKSPACE}
	var recoveries := [0]
	controller.reset_requested.connect(func(): recoveries[0]+=1)
	key.physical_keycode=KEY_R
	root.push_input(key)
	check(recoveries[0]==0,"Old reset key is inactive after rebinding")
	key.physical_keycode=KEY_BACKSPACE
	root.push_input(key)
	check(recoveries[0]==1,"Displayed rebound reset key works through viewport input")
	var button := InputEventJoypadButton.new()
	button.device=7
	button.button_index=JOY_BUTTON_Y
	button.pressed=true
	root.push_input(button)
	check(recoveries[0]==2 and controller.active_device==7,"Displayed gamepad Y recovers through viewport input")
	controller.queue_free()
	await process_frame
	finish()
