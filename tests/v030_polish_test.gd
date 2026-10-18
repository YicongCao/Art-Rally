extends "res://tests/test_suite.gd"

func motion(controller: RallyInputController,axis: JoyAxis,value: float,device: int = 7) -> void:
	var event := InputEventJoypadMotion.new()
	event.device=device
	event.axis=axis
	event.axis_value=value
	root.push_input(event)

func _run() -> void:
	var controls := RallyInputController.new()
	root.add_child(controls)
	motion(controls,JOY_AXIS_TRIGGER_RIGHT,.8)
	motion(controls,JOY_AXIS_LEFT_X,.4)
	var before := controls.axes.duplicate()
	var takeovers: Array[int]=[]
	controls.human_drive_input.connect(func(device: int): takeovers.append(device))
	motion(controls,JOY_AXIS_RIGHT_X,.8)
	motion(controls,JOY_AXIS_RIGHT_Y,-.6)
	check(controls.look_vector().x>.4 and controls.look_vector().y<-.3,"Right stick reaches view input through Viewport events")
	check(controls.active_device==7 and controls.axes==before and takeovers.is_empty(),"Looking preserves throttle, steering and driving source")
	motion(controls,JOY_AXIS_RIGHT_X,0)
	motion(controls,JOY_AXIS_RIGHT_Y,.1)
	check(controls.look_vector()==Vector2.ZERO,"Radial deadzone removes camera drift")
	motion(controls,JOY_AXIS_RIGHT_X,1)
	controls.suspend()
	check(controls.look_vector()==Vector2.ZERO,"Pause clears held look input")
	controls.resume()
	motion(controls,JOY_AXIS_RIGHT_X,1)
	controls._joy_connection_changed(7,false)
	check(controls.look_vector()==Vector2.ZERO,"Disconnect clears held look input")
	controls.free()
	var car := RallyVehicle.new()
	root.add_child(car)
	var camera := Camera3D.new()
	root.add_child(camera)
	var rig := RallyCameraRig.new()
	rig.build(camera)
	for mode: int in [0,1,2]:
		rig.update(camera,car,mode,false,false,.01)
		var original := camera.transform
		for i: int in range(60): rig.update(camera,car,mode,false,false,1.0/60,Vector2(.7,-.4))
		check(not camera.transform.is_equal_approx(original),"Right stick changes camera pose in mode "+str(mode))
		var angles := rig.view_angles
		rig.update(camera,car,mode,false,true,1,Vector2.ONE)
		check(rig.view_angles==angles,"Pause freezes orbit in mode "+str(mode))
		rig.reset()
		rig.update(camera,car,mode,false,false,.01)
		check(camera.transform.is_equal_approx(original),"View reset restores original framing in mode "+str(mode))
	for wheel: Node3D in car.wheel_visuals:
		check(wheel.get_child(0).mesh==RallyWheelMeshes.tire(car.config.wheel_radius),"AT casing retains existing spin and deformation node")
		check(wheel.get_child(1).has_node("WhiteFiveSpoke") and wheel.get_child(2).has_node("WhiteFiveSpoke"),"Open five-spoke rims exist on both wheel faces")
	check(car.find_children("*","CollisionShape3D",true,false).size()==1,"Wheel decoration adds no collision or physics changes")
	car.free()
	camera.free()
	var button := Button.new()
	root.add_child(button)
	RallySelectionStyle.apply(button,true)
	check(button.get_node("SelectionPatina").visible and button.icon!=null and button.button_pressed,"Selected button keeps checkmark, fill and patina")
	RallySelectionStyle.apply(button,false)
	check(not button.get_node("SelectionPatina").visible and not button.button_pressed,"Deselection removes the patina")
	RallySelectionStyle.apply(button,true)
	check(button.get_node("SelectionPatina").mouse_filter==Control.MOUSE_FILTER_IGNORE and button.get_child_count()==1,"Selection ornament never captures input or duplicates")
	button.free()
	var settings := RallyGameSettings.new()
	var panel := RallySettingsPanel.new()
	root.add_child(panel)
	panel.build(settings)
	settings.set_value("automatic",false)
	panel.sync()
	check(not panel.widgets.automatic.get_node("SelectionPatina").visible,"Settings sync removes stale selected ornament")
	panel.free()
	var progress := RallyLoadingProgress.new()
	progress.size=Vector2(1100,26)
	root.add_child(progress)
	for value: float in [0,45,100]:
		progress.value=value
		var previous := progress.visual_ratio
		progress.advance_visual(.016)
		check(progress.visual_ratio<=value/100 and progress.visual_ratio>=previous,"Animated fill never overshoots actual loading progress "+str(value))
		if value>0: check(progress.visual_ratio<value/100,"Progress width grows rather than jumping "+str(value))
		for i: int in range(60): progress.advance_visual(1.0/60)
		check(is_equal_approx(progress.visual_ratio,value/100),"Animated fill settles on actual progress "+str(value))
	progress.free()
	await process_frame
	finish()
