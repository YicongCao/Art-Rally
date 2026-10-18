extends "res://tests/test_suite.gd"


func _run() -> void:
	check(RallyHUD.GAUGE_RECT.position.x==RallyHUD.TIMER_RECT.position.x and RallyHUD.GAUGE_RECT.size.x==RallyHUD.TIMER_RECT.size.x,"Timer and speedometer panels share both side edges")
	var font := RallyFonts.plate()
	check(font.get_string_size("12:34.567",HORIZONTAL_ALIGNMENT_LEFT,-1,34).x<RallyHUD.TIMER_RECT.size.x-36,"Long race timer fits the narrower panel in the speedometer font")
	for pair: Array in [[0,"00"],[7,"07"],[99,"99"],[100,"100"],[236,"236"]]:
		check(RallyHUD.speed_text(pair[0])==pair[1],"Speed uses two digits below 100, three above: "+str(pair[0]))
	var car := RallyVehicle.new()
	root.add_child(car)
	var route := RallyStageRoute.new()
	route.build(load("res://resources/stages/sunset_ridge.tres"))
	var session := RallyStageSession.new()
	session.setup(route)
	session.phase = RallyStageSession.Phase.RUNNING
	session.next_gate = 18
	session.progress = 1710
	session.elapsed = 123.456
	session.penalty = 5
	session.current_note = "RIGHT_TIGHT"
	session.note_remaining = 4
	session.note_s = 1780
	car.linear_velocity = Vector3(0,0,-20)
	car.drivetrain.gear = 3
	car.drivetrain.engine_omega = 4000*TAU/60
	var data := RallyHUD.data_for(car,session,false)
	check(is_equal_approx(data.speed,72) and data.gear=="3" and is_equal_approx(data.rpm,4000),"Dashboard reads actual speed gear and engine RPM")
	check(data.note=="RIGHT_TIGHT" and data.note_distance==70,"Pacenote card uses actual route distance")
	car.drivetrain.wheelspin = 2
	car.command.throttle = 1
	car.drivetrain.auto_shift_cut = true
	data = RallyHUD.data_for(car,session,false)
	check(data.wheelspin and data.shift_sync,"Dashboard reports actual driven-wheel spin and safe downshift synchronization")
	car.drivetrain.wheelspin = 0
	car.drivetrain.auto_shift_cut = false
	var cockpit := RallyCockpitDisplay.new()
	cockpit.refresh(car)
	check(cockpit.drive_status=="","Cockpit clears synchronization warning when grip returns")
	cockpit.free()
	check(RallyHUD.time_text(data.time)=="02:08.456","Timer includes penalty without losing milliseconds")
	car.drivetrain.gear = -1
	check(RallyHUD.data_for(car,session,true).gear=="R","Dashboard renders reverse and pause state")
	for viewport: Vector2 in [Vector2(960,540),Vector2(1280,720),Vector2(1920,1080),Vector2(1024,768),Vector2(2560,1080)]:
		var layout := RallyHUD.layout_for(viewport)
		var corner: Vector2 = layout.offset+Vector2(1256,696)*float(layout.scale)
		check(corner.x<viewport.x and corner.y<viewport.y,"HUD remains inside viewport %s"%viewport)
	for code: String in ["LEFT_MEDIUM","RIGHT_MEDIUM","LEFT_TIGHT","RIGHT_TIGHT"]:
		var arrow := RallyHUD.pacenote_arrow(code)
		var path: PackedVector2Array = arrow.path
		var head: PackedVector2Array = arrow.head
		var base := (head[1]+head[2])*0.5
		var pointing := (head[0]-base).normalized()
		var terminal := (path[-1]-path[-2]).normalized()
		var expected_side := -1.0 if code.begins_with("LEFT") else 1.0
		check(pointing.dot(terminal)>0.999 and pointing.x*expected_side>0.7,code+" arrow tip follows the turn rather than its back edge")
		check(absf(pointing.y)<0.001 if code.ends_with("TIGHT") else pointing.y < -0.7,code+" distinguishes a right-angle bend from an upward diagonal")
	var left: PackedVector2Array = RallyHUD.pacenote_arrow("LEFT_MEDIUM").head
	var right: PackedVector2Array = RallyHUD.pacenote_arrow("RIGHT_MEDIUM").head
	check(left[0].is_equal_approx(Vector2(-right[0].x,right[0].y)),"Left and right pacenote tips are exact horizontal mirrors")
	car.queue_free()
	await process_frame
	finish()
