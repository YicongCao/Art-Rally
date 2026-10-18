extends "res://tests/test_suite.gd"


func _run() -> void:
	var keys: Array[String] = []
	for stage_id: String in RallyContentCatalog.STAGES:
		var stage := RallyContentCatalog.stage(stage_id)
		var route := RallyStageRoute.new()
		route.build(stage)
		var errors := route.validate()
		if not errors.is_empty(): print(stage_id," geometry: ",errors.slice(0,10))
		check(errors.is_empty(),stage_id+" is a nonintersecting driveable route")
		check(absf(route.length-stage.target_length)<10,stage_id+" meets authored length")
		for note: Dictionary in route.notes:
			check(float(note.s)>=0 and float(note.s)<=route.length,stage_id+" note inside route")
		for car_id: String in RallyContentCatalog.VEHICLES:
			var challenge := RallyContentCatalog.challenge(stage_id,car_id)
			check(challenge!=null and challenge.key() not in keys,"Unique challenge "+stage_id+" / "+car_id)
			keys.append(challenge.key())
			var targets := challenge.thresholds()
			check(challenge.medal(targets[2])==3 and challenge.medal(targets[2]+0.001)==2,"Inclusive gold boundary")
			check(challenge.medal(targets[1])==2 and challenge.medal(targets[0])==1 and challenge.medal(targets[0]+0.001)==0,"Silver and bronze boundaries")
			check(challenge.medal(NAN)==0 and challenge.medal(-1)==0,"Invalid times cannot earn medals")
			check(not challenge.human_calibrated,"Unmeasured targets explicitly remain provisional")
	var coast := RallyContentCatalog.stage("sunlit_cape")
	check(coast.surface_id(1300)==0 and coast.water_depth(1280,0)==0,"Coast does not inherit sunset mud or puddles")
	check(coast.width_at(1300)==6 and coast.crests.is_empty(),"Coast does not inherit sunset narrowing or jump")
	for id: String in RallyContentCatalog.VEHICLES:
		var a := RallyContentCatalog.vehicle(id)
		var b := RallyContentCatalog.vehicle(id)
		var config := a.physics_config()
		check(config.body_mass==a.mass_kg and config.wheelbase==a.wheelbase,"Vehicle geometry and dynamics share dimensions")
		var power := a.drivetrain_config()
		check(power.drive_layout==a.drive_layout and power.rated_power_ps==a.power_ps,"Each car owns its power and drivetrain")
		a.mass_kg = 99
		check(b.mass_kg!=99,"Catalog resources are isolated per session")
	check(RallyContentCatalog.challenge("missing","F160")==null,"Unknown content rejected")
	finish()
