extends SceneTree
var failures: int = 0
var checks: int = 0
func _initialize() -> void: _run.call_deferred()
func check(value: bool,label: String) -> void:
	checks+=1
	print(("PASS: " if value else "FAIL: ")+label)
	if not value: failures+=1
func _run() -> void:
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(app)
	app.profile.path = "user://flow-test/profile.json"
	app.profile.data = RallyProfileStore.fresh()
	app.show_home()
	check(app.screen=="home","Game opens at main menu")
	app.show_stages()
	app.show_vehicles()
	app.show_settings()
	app.show_bindings()
	app.show_records()
	check(app.screen=="records","All front-end pages build")
	app.chosen_vehicle = "F160"
	app.start_race()
	check(app.screen=="loading" and app.progress_bar!=null,"Vehicle confirmation opens briefing inside actual loading page")
	while app.loading: await process_frame
	check(app.screen=="race","Menu loads a complete playable challenge")
	check(app.race.vehicle.drivetrain.config.drive_layout=="FWD","Selected vehicle physics survive settings application")
	check(app.race.vehicle.config.body_mass==1000,"Selected mass applied")
	check(app.race.session.split_gates.size()==3,"Three splits configured")
	app.race._setting_changed("brake_bias",0.69)
	check(is_equal_approx(app.race.vehicle.config.front_brake_bias,app.race.challenge.vehicle.physics_config().front_brake_bias),"Official challenge locks mechanical tuning")
	app.race._toggle_mode()
	check(not app.race.session.practice,"Practice cannot be toggled into an eligible run")
	app.race._toggle_pause()
	check(paused,"Pause works")
	app.race._toggle_pause()
	await app.leave_race()
	await process_frame
	check(not paused and app.screen=="stages","Return frees race and resumes menu")
	app.profile.data.unlocked_power_tier = 2
	app.show_vehicles()
	var options := app.ui.find_children("*","Button",true,false).filter(func(button: Button): return button.has_meta("power_tier"))
	check(options.size()==9,"Each of three car cards contains its own three power choices")
	for option: Button in options:
		check(option.get_parent().get_parent().get_meta("vehicle_id")==option.get_meta("vehicle_id"),"Power choice is grouped inside its owning car card")
	options[1].pressed.emit()
	check(app.chosen_power_tier==1,"Manual +50% selection survives the page rebuild")
	app.ui.find_children("*","Button",true,false).filter(func(button: Button): return button.has_meta("power_tier"))[2].pressed.emit()
	check(app.chosen_power_tier==2,"Manual +100% selection survives the page rebuild")
	app._select_vehicle_variant("R200",1)
	check(app.chosen_vehicle=="R200" and app.chosen_power_tier==1 and app.vehicle_power_choices.F160==2,"Another card changes the active car and retains the previous car's power choice")
	app._select_vehicle_variant("F160",2)
	await app.start_race()
	check(app.race.vehicle.drivetrain.config.rated_power_ps==384 and app.race.challenge.vehicle.power_tier==2,"Selected +100% F160 actually loads 384 PS into gameplay")
	check(app.profile.data.last_power_tier==2,"The loaded variant is the saved recent selection")
	await app.leave_race()
	await process_frame
	app.profile.data = RallyProfileStore.fresh()
	app.show_vehicles()
	options = app.ui.find_children("*","Button",true,false).filter(func(button: Button): return button.has_meta("power_tier"))
	check(not options[0].disabled and options[1].disabled and options[2].disabled and app.chosen_power_tier==0,"Fresh profiles cannot select locked power, even after a previous boosted session")
	app.free()
	print("TEST RESULT: %d checks, %d failures"%[checks,failures])
	quit(failures)
