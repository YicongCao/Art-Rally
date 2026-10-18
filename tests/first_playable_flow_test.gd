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
	await app.start_race()
	check(app.screen=="race","Menu loads a complete playable challenge")
	check(app.race.vehicle.drivetrain.config.drive_layout=="FWD","Selected vehicle physics survive settings application")
	check(app.race.vehicle.config.body_mass==1000,"Selected mass applied")
	check(app.race.session.split_gates.size()==3,"Three splits configured")
	app.race._setting_changed("brake_bias",0.69)
	check(is_equal_approx(app.race.vehicle.config.front_brake_bias,0.62),"Official challenge locks mechanical tuning")
	app.race._toggle_mode()
	check(not app.race.session.practice,"Practice cannot be toggled into an eligible run")
	app.race._toggle_pause()
	check(paused,"Pause works")
	app.race._toggle_pause()
	app.leave_race()
	await process_frame
	check(not paused and app.screen=="stages","Return frees race and resumes menu")
	app.free()
	print("TEST RESULT: %d checks, %d failures"%[checks,failures])
	quit(failures)
