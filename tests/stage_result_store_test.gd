extends "res://tests/test_suite.gd"


func _run() -> void:
	var store := RallyStageResultStore.new()
	store.path = "user://m6_results_test_%d.cfg"%Time.get_ticks_usec()
	var human := result("AWD","200ps-v1","human_keyboard",120,5,true)
	var status := store.record(human)
	check(status.saved and status.new_record and status.category=="human","First eligible human finish creates a personal best")
	status = store.record(result("AWD","200ps-v1","human_gamepad",130,0,true))
	check(status.saved and not status.new_record and store.summary("sunset_ridge","AWD","200ps-v1").human_best.total_time==125,"A slower human finish remains in history without replacing the best")
	status = store.record(result("AWD","200ps-v1","autopilot_vkeyboard",150,0,false))
	check(status.new_record and status.category=="autopilot_vkeyboard","Virtual keyboard reference has an independent best")
	store.record(result("AWD","200ps-v1","autopilot_vgamepad",130,0,false))
	var summary := store.summary("sunset_ridge","AWD","200ps-v1")
	check(summary.autopilot_vkeyboard.total_time==150 and summary.autopilot_vgamepad.total_time==130,"Two automatic input references remain separated")
	var mixed := result("AWD","200ps-v1","mixed_takeover",110,0,false)
	mixed.takeover_count = 1
	status = store.record(mixed)
	check(status.category=="mixed" and not status.new_record and store.summary("sunset_ridge","AWD","200ps-v1").human_best.total_time==125,"Mixed takeover is retained but cannot enter a best list")
	store.record(result("FWD","200ps-v1","human_keyboard",100,0,true))
	store.record(result("AWD","200ps-v2","human_keyboard",90,0,true))
	check(store.summary("sunset_ridge","AWD","200ps-v1").human_best.total_time==125,"Drive layout and calibration version isolate result buckets")
	var practice := result("AWD","200ps-v1","human_keyboard",80,0,true)
	practice.practice = true
	check(not store.record(practice).saved,"Practice finish never enters persistent history")
	var invalid := result("AWD","200ps-v1","human_keyboard",80,5,true)
	invalid.total_time = 80
	check(store.record(invalid).reason=="invalid","Inconsistent elapsed penalty and total time are rejected")
	for i: int in range(RallyStageResultStore.MAX_RECENT+5):
		store.record(result("RWD","200ps-v1","human_keyboard",200+i,0,true))
	check(store.summary("sunset_ridge","RWD","200ps-v1").recent.size()==RallyStageResultStore.MAX_RECENT,"Recent completion history has a fixed bound")
	check(store.save_file()==OK,"Result store saves a versioned local file")
	var loaded := RallyStageResultStore.new()
	loaded.path = store.path
	check(loaded.load_file()==OK and loaded.summary("sunset_ridge","AWD","200ps-v1").human_best.total_time==125,"Results survive a new store instance")
	DirAccess.remove_absolute(store.path)
	finish()


func result(layout: String,version: String,source: String,elapsed: float,penalty: float,eligible: bool) -> Dictionary:
	return {
		"stage_id":"sunset_ridge",
		"drive_layout":layout,
		"calibration_version":version,
		"driver_source":source,
		"eligible_for_human_best":eligible,
		"elapsed":elapsed,
		"penalty":penalty,
		"total_time":elapsed+penalty,
		"reset_count":int(penalty/5),
		"takeover_count":0,
		"recorded_at":123456,
	}
