extends "res://tests/test_suite.gd"
func _run() -> void:
	var app: RallyGameApp=load("res://scenes/game/game.tscn").instantiate()
	app.profile.path="user://brushline-menu-%d/profile.json"%Time.get_ticks_usec()
	root.add_child(app)
	app.profile.data=RallyProfileStore.fresh()
	app.profile.data.plate="MENU"
	app.test_mode=false
	app.show_stages()
	var unavailable := 0
	for button: Button in app.ui.find_children("*","Button",true,false):
		if button.disabled: unavailable+=1
	check(unavailable==2,"Fresh title presents two visibly locked stage cards")
	app.chosen_stage="sunlit_cape"
	await app.start_race()
	check(app.race==null and app.screen=="stages","Direct launch cannot bypass the same stage access rule")
	app.practice=true
	app.chosen_stage="sunlit_cape"
	await app.start_race()
	check(app.race!=null and app.race.session.practice,"The locked challenge is still available for free practice")
	await app.leave_race()
	app.prefs.values.reduced_motion=true
	app.show_home()
	check(app.transitions.reduced_motion,"Reduced-motion preference reaches shared page transitions")
	app.free()
	await process_frame
	finish()
