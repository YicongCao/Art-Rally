extends "res://tests/test_suite.gd"

func _run() -> void:
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	app.profile.path = "user://transition-test-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data = RallyProfileStore.fresh()
	app.show_home()
	await process_frame
	check(app.ui.find_children("*","Button",true,false).all(func(b: Button): return b.text!="驾驶教学"),"Tutorial action is hidden from the title menu")
	app.show_stages()
	if DisplayServer.get_name()!="headless":
		check(app.ui.position.x>0,"Forward navigation enters from the right")
		await app.transitions.sliding.finished
	check(is_zero_approx(app.ui.position.x) and not app.transitions.wipe.visible,"Slide completes without leaving an input shield")
	app.show_home()
	if DisplayServer.get_name()!="headless":
		check(app.ui.position.x<0,"Back navigation enters from the left")
		await app.transitions.sliding.finished
	app.show_stages()
	app.show_vehicles()
	if DisplayServer.get_name()!="headless": await app.transitions.sliding.finished
	await process_frame
	check(app.ui.position.x==0 and app.layer.get_child_count()==1,"Interrupted navigation retires stale pages and restores the latest page")
	await app.transitions.cover(true)
	check(app.transitions.wipe.visible and app.transitions.wipe.phase==1 and app.transitions.busy,"Chequered flag completely covers the scene at the swap point")
	if DisplayServer.get_name()!="headless":
		var wind_before := app.transitions.wipe.wind_time
		create_timer(.08).timeout.connect(func():
			check(app.transitions.wipe.phase==1 and app.transitions.busy,"Flag pauses at full coverage before exiting")
			check(app.transitions.wipe.wind_time>wind_before,"Fabric keeps moving during the midpoint hold"))
	await app.transitions.reveal(true)
	check(not app.transitions.wipe.visible and not app.transitions.busy,"Flag exits and restores input")
	await app.transitions.cover(false)
	app.show_home()
	check(app.transitions.wipe.visible and app.transitions.wipe.black and app.transitions.wipe.phase==1,"Menu construction remains hidden under a fully black overlay")
	await app.transitions.reveal(false)
	check(app.ui.visible and not app.transitions.wipe.visible,"Menu fades in and accepts input again")
	app.free()
	await process_frame
	finish()
