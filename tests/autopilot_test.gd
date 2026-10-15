extends "res://tests/test_suite.gd"


func _run() -> void:
	var controls := RallyInputController.new()
	root.add_child(controls)
	var raw := DriverCommand.new()
	raw.steer = RallyAutoDriver._stick_axis(0.5,controls.filter.profile)
	raw.throttle = 1.0
	var filtered := controls.sample_virtual(raw,0,1.0/120.0,false)
	check(controls.virtual_active and controls.active_device==-1,"Virtual gamepad uses the shared input filter without claiming a hardware device")
	check(filtered.steer>0 and filtered.throttle>0 and controls.rumble_device()==-1,"Virtual gamepad shapes axes and cannot vibrate a fake device")
	controls.clear()
	filtered = controls.sample_virtual(raw,0,1.0/120.0,true)
	check(controls.virtual_active and filtered.throttle>0,"Virtual keyboard uses the keyboard ramp path")
	var driver := RallyAutoDriver.new()
	driver.set_mode(RallyAutoDriver.Mode.VIRTUAL_GAMEPAD)
	check(driver.mode_name()=="vgamepad" and driver.source(-1)==RallyAutoDriver.Source.AUTOPILOT_VGAMEPAD,"Automatic source identifies the selected virtual device")
	check(driver.human_takeover() and driver.source(-1)==RallyAutoDriver.Source.MIXED_TAKEOVER,"Human takeover permanently marks a mixed run")
	check(not driver.human_takeover(),"Repeated human input cannot count a second takeover after automation is off")
	controls.queue_free()
	await process_frame

	paused = false
	var scene: Node3D = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	scene._set_autopilot_mode_name("vkeyboard")
	await ticks(480)
	check(scene.auto_driver.mode==RallyAutoDriver.Mode.VIRTUAL_KEYBOARD and scene.controls.virtual_active,"Stage feeds production automation through the virtual keyboard path")
	check(scene.auto_driver.pilot.progress>5 and scene.auto_driver.pilot.wanted_speed>0,"Route pilot publishes live progress and target speed")
	var mode_before_restart: int = scene.auto_driver.mode
	scene._restart()
	await ticks(5)
	check(scene.auto_driver.mode==mode_before_restart and scene.auto_driver.takeover_count==0,"Restart preserves the selected automation mode but starts fresh provenance")
	var key := InputEventKey.new()
	key.physical_keycode = KEY_W
	key.pressed = true
	scene.controls._unhandled_input(key)
	check(scene.auto_driver.mode==RallyAutoDriver.Mode.OFF and scene.auto_driver.takeover_count==1,"Real driving input immediately takes control")
	key.pressed = false
	scene.controls._unhandled_input(key)
	var shortcut := InputEventKey.new()
	shortcut.physical_keycode = KEY_F10
	shortcut.pressed = true
	scene.controls._unhandled_input(shortcut)
	check(scene.auto_driver.mode==RallyAutoDriver.Mode.VIRTUAL_KEYBOARD,"F10 enables virtual keyboard automation")
	scene.controls._unhandled_input(shortcut)
	check(scene.auto_driver.mode==RallyAutoDriver.Mode.VIRTUAL_GAMEPAD,"F10 cycles to virtual gamepad automation")
	scene._toggle_pause()
	scene.controls._unhandled_input(shortcut)
	check(scene.auto_driver.mode==RallyAutoDriver.Mode.OFF and scene.pause_menu.autopilot_selector.selected==0,"F10 remains available while paused and keeps the menu synchronized")
	scene._toggle_pause()
	scene.queue_free()
	paused = false
	await process_frame
	finish()
