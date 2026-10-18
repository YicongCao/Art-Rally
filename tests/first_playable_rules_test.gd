extends "res://tests/test_suite.gd"
func _run() -> void:
	var route := RallyStageRoute.new()
	route.build(RallyContentCatalog.stage("sunset_ridge"))
	var session := RallyStageSession.new()
	session.setup(route)
	session.phase = RallyStageSession.Phase.ARMED
	for i: int in range(session.gates.size()):
		var gate := session.gates[i]
		var center := route.position_at(gate)
		var forward := route.tangent_at(gate)
		session.step(center-forward,5,.1)
		session.step(center+forward,5,.1)
		if i==3: session.recover(5)
	check(session.phase==RallyStageSession.Phase.FINISHED,"Ordered physical gate crossings finish the challenge")
	check(session.split_times.size()==3,"Exactly three splits emitted")
	check(session.penalty==5 and session.split_times[0]>=5,"Recovery penalty is part of split clock")
	check(is_equal_approx(session.split_times[-1],session.total_time()),"Final split equals scored total")
	session.restart()
	check(session.split_times.is_empty() and session.penalty==0,"Restart clears all split and penalty state")
	session.practice=true
	session.phase=RallyStageSession.Phase.RUNNING
	session.recover(10)
	check(session.penalty==0,"Practice recovery carries no score penalty")
	var controls := RallyInputController.new()
	root.add_child(controls)
	controls.bindings = {str(KEY_W):KEY_J,str(KEY_S):KEY_K}
	var event := InputEventKey.new()
	event.physical_keycode=KEY_W
	event.pressed=true
	controls._unhandled_input(event)
	check(controls.sample(0,.1).throttle==0,"Remapped original key no longer activates action")
	event.physical_keycode=KEY_J
	controls._unhandled_input(event)
	check(controls.sample(0,.1).throttle>0,"Mapped throttle reaches the actual driving filter")
	controls.clear()
	event.physical_keycode=KEY_K
	controls._unhandled_input(event)
	check(controls.sample(0,.1).brake>0,"Mapped brake reaches the actual driving filter")
	var mechanical_changes := [0]
	controls.allow_mechanical_shortcuts=false
	controls.contact_requested.connect(func(): mechanical_changes[0]+=1)
	event.physical_keycode=KEY_F3
	controls._unhandled_input(event)
	check(mechanical_changes[0]==0,"Official challenge blocks mechanical developer shortcut")
	controls.queue_free()
	await process_frame
	finish()
