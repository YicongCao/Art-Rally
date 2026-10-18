extends "res://tests/test_suite.gd"


func _run() -> void:
	var controls := RallyInputController.new()
	root.add_child(controls)
	key(controls,KEY_UP,true)
	key(controls,KEY_W,true)
	key(controls,KEY_UP,false)
	check(controls.sample(0,0.5).throttle==1,"Releasing an arrow does not cancel a held WASD alias")
	key(controls,KEY_LEFT,true)
	key(controls,KEY_D,true)
	check(is_zero_approx(controls.sample(0,0.5).steer),"Opposing arrow/WASD steering cancels without doubled input")
	controls.suspend()
	key(controls,KEY_DOWN,true)
	controls.resume()
	check(controls.sample(0,0.1).brake==0,"Menu arrows cannot latch vehicle braking")
	controls.queue_free()
	var scene: Node3D = load("res://scenes/stages/sunset_ridge.tscn").instantiate()
	root.add_child(scene)
	scene._safety_pause()
	scene._restore_launch_focus()
	check(not paused and not scene.controls.blocked,"Initial window focus return needs no hidden Space/handbrake acknowledgement")
	key(scene.controls,KEY_UP,true)
	await ticks(4)
	check(scene.session.phase==RallyStageSession.Phase.ARMED and scene.vehicle.command.brake==0 and scene.vehicle.command.handbrake==0,"Throttle alone releases launch hold without touching handbrake")
	await ticks(180)
	check(scene.vehicle.linear_velocity.length()>1,"Arrow throttle drives away immediately")
	scene._safety_pause()
	scene._restore_launch_focus()
	check(paused,"Focus loss after driving still requires explicit safe resume")
	scene._toggle_pause()
	scene.controls.clear()
	var route: RallyStageRoute = scene.generator.route
	var prestart := RallyStageSession.new()
	prestart.setup(route)
	prestart.recover(10)
	check(prestart.penalty==10,"Timed out-of-bounds penalty also applies before crossing the start gate")
	var pose := route.pose_at(500)
	check(not RallyStageBounds.outside(route,pose.origin+Vector3.UP*5,Vector3.ZERO,1.0/120,route.index_at(500)),"Legitimate airborne jump over road is not treated as out of bounds")
	check(RallyStageBounds.outside(route,pose.origin+pose.basis.x*18.5,Vector3.ZERO,1.0/120,route.index_at(500)),"Lateral edge triggers before the physical road ribbon ends")
	check(RallyStageBounds.outside(route,pose.origin+pose.basis.x*17.8,pose.basis.x*40,1.0/120,route.index_at(500)),"Prediction catches high-speed edge crossing before support is lost")
	scene.session.phase = RallyStageSession.Phase.RUNNING
	scene.session.next_gate = 5
	scene.vehicle.request_reset(Transform3D(pose.basis,pose.origin+pose.basis.x*20))
	await ticks(6)
	check(scene.session.penalty==10 and scene.session.reset_count==1,"Automatic boundary recovery charges exactly ten seconds once")
	check(scene.vehicle.position.distance_to(route.pose_at(414).origin)<1,"Boundary recovery occurs within a few physics ticks, before falling")
	scene.presentation.checkpoints.update(5)
	check(scene.presentation.checkpoints.symbols[5].visible and not scene.presentation.checkpoints.symbols[4].visible and scene.presentation.checkpoints.materials.size()==31,"Paired checkpoint markers highlight only the required symbol")
	check(scene.presentation.checkpoints.tube_multimesh.instance_count==62,"Inflatable checkpoint tubes share one instanced draw batch")
	check(scene.presentation.checkpoints.tube_multimesh.use_colors,"Batched checkpoint tubes carry per-instance highlight colors")
	var data := RallyHUD.data_for(scene.vehicle,scene.session,false)
	check(data.gate_number==6 and data.gate_distance>0,"HUD identifies the required checkpoint and distance after recovery")
	check(scene.presentation.camera_rig.shift_lights.size()==12,"Cockpit contains a live twelve-segment shift-light bank")
	var marks := RallyTireMarks.new()
	marks.build(scene)
	var car := RallyVehicle.new()
	root.add_child(car)
	for i: int in range(4):
		var wheel := car.wheels[i]
		wheel.grounded = true
		wheel.normal = Vector3.UP
		wheel.load = 3000
		wheel.longitudinal_speed = 5
		wheel.surface = RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[1])
		wheel.point = Vector3(i,0,0)
	marks.update(car,0.01)
	for wheel: RallyWheelState in car.wheels: wheel.point.z -= 0.5
	marks.update(car,0.01)
	check(marks.count==4,"Normal rolling on gravel leaves four subtle ground marks")
	marks.break_trails()
	for wheel: RallyWheelState in car.wheels: wheel.point.z -= 100
	marks.update(car,0.01)
	check(marks.count==4,"Recovery or teleport cannot draw long connecting skid strips")
	for step: int in range(RallyTireMarks.CAPACITY/4+10):
		for wheel: RallyWheelState in car.wheels: wheel.point.z -= 0.4
		marks.update(car,0.01)
	check(marks.count==RallyTireMarks.CAPACITY,"Tire-mark instance pool remains bounded")
	for wheel: RallyWheelState in car.wheels: wheel.grounded = false
	marks.update(car,80)
	for step: int in range(RallyTireMarks.CAPACITY/32): marks.update(car,0.01)
	check(marks.colors[0].a==0,"Old marks fade without changing road geometry")
	marks.clear()
	check(marks.mesh.visible_instance_count==0,"Full restart can clear all marks")
	car.queue_free()
	scene.queue_free()
	await process_frame
	finish()


func key(controller: RallyInputController,code: Key,pressed: bool) -> void:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	controller._unhandled_input(event)
