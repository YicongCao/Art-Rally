extends "res://tests/test_suite.gd"

func _run() -> void:
	for side: String in ["LEFT","RIGHT"]:
		var seen_colors: Array[Color]=[]
		for grade: int in range(1,7):
			var turn := RallyComicHUDArt.turn(side+"_"+str(grade))
			check(turn.grade==grade and turn.right==(side=="RIGHT"),"Numeric grade and side match the spoken code")
			check(not seen_colors.has(turn.color),"Every severity has a distinct colour")
			seen_colors.append(turn.color)
		check(RallyComicHUDArt.turn(side+"_MEDIUM").grade==3 and RallyComicHUDArt.turn(side+"_TIGHT").grade==1,"Legacy note codes remain compatible")
	# Radius, rather than accumulated turning angle or altitude, determines grade.
	for radius: float in [20,32,52,80,130,200]:
		var route := RallyStageRoute.new()
		route.spacing=2
		route.length=400
		for i: int in range(201):
			var theta := i*2/radius
			route.points.append(Vector3(radius*cos(theta),i*.1,radius*sin(theta)))
			route.distances.append(i*2.0)
			route.tangents.append(Vector3(-sin(theta),.05,cos(theta)).normalized())
		var left := route.tangents[90].signed_angle_to(route.tangents[110],Vector3.UP)>0
		var bend := route.bend_profile(200,left)
		check(is_equal_approx(bend.radius,radius),"Smoothed horizontal curvature recovers radius %s"%radius)
		check(bend.grade==[20,32,52,80,130,200].find(int(radius))+1,"Six radius bands produce six grades")
	for boundary: float in [25,40,65,100,160]:
		check(RallyStageRoute.grade_for_radius(boundary-.01)+1==RallyStageRoute.grade_for_radius(boundary),"Grade boundary has a single deterministic transition")
	for id: String in RallyContentCatalog.STAGES:
		var route := RallyStageRoute.new()
		route.build(RallyContentCatalog.stage(id))
		var grades: Dictionary={}
		var valid := true
		for note: Dictionary in route.notes:
			if not (note.code.begins_with("LEFT_") or note.code.begins_with("RIGHT_")): continue
			var turn := RallyComicHUDArt.turn(note.code,note.degrees)
			valid=valid and turn.grade==note.grade and note.grade==RallyStageRoute.grade_for_radius(note.radius)
			grades[note.grade]=int(grades.get(note.grade,0))+1
		check(valid and not grades.is_empty(),id+" route, HUD and spoken code share the grade")
		print("GRADES ",id," ",grades)
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://menu-polish-%d/profile.json"%OS.get_process_id()
	root.add_child(app)
	app.prefs.values.reduced_motion=true
	for pixels: Vector2i in [Vector2i(1280,720),Vector2i(1920,1080),Vector2i(2560,1080)]:
		root.size=pixels
		app.show_home()
		await process_frame
		await process_frame
		var buttons: Dictionary={}
		for button: Button in app.ui.find_children("*","Button",true,false): buttons[button.text]=button
		check(buttons.size()==10,"Ten title actions, without a separate full-width garage button")
		var garage: Button=buttons["改装车库"]
		var practice: Button=buttons["自由练习"]
		check(garage.get_parent()==practice.get_parent() and garage.get_index()==0,"Garage is the first tile in the secondary row")
		check(garage.get_global_rect().position.x<practice.get_global_rect().position.x,"Garage precedes free practice at %s"%pixels)
		for button: Button in buttons.values():
			check(app.ui.get_global_rect().encloses(button.get_global_rect()),"%s %s fits"%[pixels,button.text])
		var icons := app.ui.find_children("*","RallyMenuVectorIcon",true,false)
		check(icons.size()==10,"Every title tile uses directly drawn vector geometry")
	# Follow the real GUI focus/activation route rather than calling show_garage.
	buttons_for_focus(app,"改装车库").grab_focus()
	var confirm := InputEventJoypadButton.new()
	confirm.button_index=JOY_BUTTON_A
	confirm.pressed=true
	root.push_input(confirm)
	await process_frame
	confirm=confirm.duplicate()
	confirm.pressed=false
	root.push_input(confirm)
	await process_frame
	check(app.screen=="garage","Gamepad south button activates the new garage tile")
	app.free()
	await process_frame
	finish()

func buttons_for_focus(app: RallyGameApp,title: String) -> Button:
	for button: Button in app.ui.find_children("*","Button",true,false):
		if button.text==title: return button
	return null
