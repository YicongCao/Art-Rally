extends "res://tests/profile_ghost_test.gd"


func _run() -> void:
	var directory := "user://power-tests-"+str(Time.get_ticks_usec())
	var store := RallyProfileStore.new()
	store.path = directory+"/profile.json"
	check(store.unlocked_power_tier()==0,"New players start with standard power")
	var keys: Array[String] = []
	for stage: String in RallyContentCatalog.STAGES:
		for car: String in RallyContentCatalog.VEHICLES:
			for tier: int in range(3):
				var challenge := RallyContentCatalog.challenge(stage,car,tier)
				check(challenge.key() not in keys,"Separate challenge and ghost identity: "+challenge.key())
				keys.append(challenge.key())
				var vehicle := challenge.vehicle
				var standard := RallyContentCatalog.vehicle(car)
				check(is_equal_approx(vehicle.power_ps,standard.power_ps*[1,1.5,2][tier]) and is_equal_approx(vehicle.drivetrain_config().torque_values[3],standard.drivetrain_config().torque_values[3]*[1,1.5,2][tier]),"Rated power and actual torque scale together")
				check(vehicle.mass_kg==standard.mass_kg and vehicle.drive_layout==standard.drive_layout,"Power variants retain vehicle mass and drivetrain")
	var base := RallyContentCatalog.challenge("sunset_ridge","F160")
	var plus := RallyContentCatalog.challenge("sunlit_cape","R200",1)
	var max_power := RallyContentCatalog.challenge("misty_highlands","A240",2)
	check(not store.record(plus,result(),ghost(plus.key())).eligible,"Locked variants cannot award progression")
	for source: String in ["autopilot_vgamepad","mixed_takeover"]:
		var run := result()
		run.source = source
		check(not store.record(base,run,ghost(base.key())).eligible and store.unlocked_power_tier()==0,"Nonhuman gold cannot unlock power")
	var practice := result()
	practice.practice = true
	check(not store.record(base,practice,ghost(base.key())).eligible and store.unlocked_power_tier()==0,"Practice gold cannot unlock power")
	check(not store.record(base,result(),{}).saved and store.unlocked_power_tier()==0,"Incomplete ghost cannot unlock power")
	var first := store.record(base,result(),ghost(base.key()))
	check(first.saved and first.unlocked_tier==1 and store.unlocked_power_tier()==1,"Standard gold unlocks all three +50% cars")
	check(store.record(base,result(99),ghost(base.key(),99)).unlocked_tier==-1 and store.unlocked_power_tier()==1,"Repeated standard gold never skips to +100%")
	var before := store.data.duplicate(true)
	store.read_only = true
	check(not store.record(plus,result(),ghost(plus.key())).saved and store.data==before and store.unlocked_power_tier()==1,"Failed save cannot grant an unlock")
	store.read_only = false
	var second := store.record(plus,result(),ghost(plus.key()))
	check(second.saved and second.unlocked_tier==2 and store.unlocked_power_tier()==2,"Gold with another car/stage at +50% unlocks all +100% cars")
	check(store.record(max_power,result(),ghost(max_power.key())).saved and store.unlocked_power_tier()==2,"Top-tier gold is capped at +100%")
	check(not store.load_ghost(base).is_empty() and not store.load_ghost(plus).is_empty() and not store.load_ghost(max_power).is_empty(),"Three power tiers preserve independent best ghosts")
	store.data.last_power_tier = 2
	check(store.save_file()==OK,"Last chosen power tier persists")
	var restored := RallyProfileStore.new()
	restored.path = store.path
	check(restored.load_file()==OK and restored.unlocked_power_tier()==2 and restored.data.last_power_tier==2,"Restart restores unlocks and selection")
	var legacy := RallyProfileStore.new()
	legacy.data.erase("last_power_tier")
	legacy.data.erase("unlocked_power_tier")
	legacy.data.challenges["sunset_ridge@1|F160@fp1|time-trial-1"] = {"medal":3,"best":result(),"recent":[result()]}
	check(RallyProfileStore.valid(legacy.data) and legacy.unlocked_power_tier()==1,"Old earned gold migrates the +50% milestone without replacing old records")
	check(legacy.result_for(base.key()).is_empty(),"Changed surface rules isolate old times and ghosts")
	for sub: String in [directory+"/ghosts",directory]:
		var access := DirAccess.open(sub)
		if access!=null:
			for filename: String in access.get_files(): access.remove(filename)
		DirAccess.remove_absolute(sub)
	finish()
