extends "res://tests/test_suite.gd"

func result(seconds: float = 100) -> Dictionary:
	return {"elapsed":seconds,"penalty":0.0,"total_time":seconds,"source":"human_keyboard","practice":false,"splits":[seconds/3,seconds*2/3,seconds],"resets":0}

func ghost(key: String,seconds: float = 100) -> Dictionary:
	return {"version":1,"key":key,"duration":seconds,"complete":true,"gaps":[],"frames":[[0,0,0,0,0,0,0,1,0,0,0,0,0,0.4,0.4,0.4,0.4],[seconds,10,0,0,0,0,0,1,0.1,10,10,10,10,0.5,0.5,0.5,0.5]]}

func _run() -> void:
	var directory := "user://fp-tests-"+str(Time.get_ticks_usec())
	var store := RallyProfileStore.new()
	store.path = directory+"/profile.json"
	check(store.load_file()==OK and not store.read_only,"Missing profile starts with safe defaults")
	var challenge := RallyContentCatalog.challenge("sunset_ridge","F160")
	var key := challenge.key()
	var recording := ghost(key)
	var timed := result()
	timed.gate_times = [0.0,25.0,100.0]
	check(RallyProfileStore.valid_result(timed),"Checkpoint clocks are optional and valid within the result timeline")
	for bad: Array in [[-0.5,100.0],[0.0,NAN],[0.0,30.0,20.0],[0.0,101.0]]:
		timed.gate_times = bad
		check(not RallyProfileStore.valid_result(timed),"Corrupt checkpoint clocks cannot enter saved bests")
	check(RallyGhostRecording.valid(recording,key),"Finite versioned trajectory accepted")
	check(not RallyGhostRecording.valid(recording,key+"changed"),"Ghost rejects wrong challenge or calibration version")
	var middle := RallyGhostRecording.sample(recording,50)
	check(middle.pose.origin.is_equal_approx(Vector3(5,0,0)) and is_equal_approx(middle.steer,0.05),"Ghost interpolates pose and wheel steering without physics")
	var broken := recording.duplicate(true)
	broken.frames[1][4] = NAN
	check(not RallyGhostRecording.valid(broken,key),"Nonfinite ghost frame rejected")
	broken = recording.duplicate(true)
	broken.frames[1][0] = 0
	check(not RallyGhostRecording.valid(broken,key),"Nonmonotonic ghost clock rejected")
	var recovery := recording.duplicate(true)
	recovery.gaps = [[40.0,45.0]]
	recovery.frames.insert(1,[40,4,0,0,0,0,0,1,0,0,0,0,0,0.4,0.4,0.4,0.4])
	recovery.frames.insert(2,[45,8,0,0,0,0,0,1,0,0,0,0,0,0.4,0.4,0.4,0.4])
	check(RallyGhostRecording.sample(recovery,42).is_empty(),"Penalty interval hides ghost")
	check(RallyGhostRecording.sample(recovery,45).pose.origin.is_equal_approx(Vector3(8,0,0)),"Ghost resumes at recovery pose without crossing the gap")
	check(RallyGhostRecording.sample(recording,101).is_empty(),"Ghost disappears after finish")
	var saved := store.record(challenge,result(),recording)
	check(saved.saved and saved.new_best,"First player result and ghost save together")
	var reloaded := RallyProfileStore.new()
	reloaded.path = store.path
	check(reloaded.load_file()==OK and reloaded.result_for(key).best.total_time==100,"Fresh process restores personal best")
	check(not reloaded.load_ghost(challenge).is_empty(),"Fresh process restores matching ghost")
	check(not reloaded.record(challenge,result(),recording).new_best,"Equal times do not replace the existing best")
	var human := result()
	for source: String in ["autopilot_vkeyboard","autopilot_vgamepad","mixed_takeover"]:
		human.source = source
		check(not reloaded.record(challenge,human,recording).eligible,"Nonhuman source cannot award medals: "+source)
	human = result()
	human.practice = true
	check(not reloaded.record(challenge,human,recording).eligible,"Practice cannot award medals")
	var invalid := result()
	invalid.total_time = 90
	check(not reloaded.record(challenge,invalid,recording).eligible,"Time inconsistent with penalty rejected")
	check(reloaded.record(challenge,result(80),ghost(key,80)).new_best,"Strictly faster valid run replaces best")
	var good_file := FileAccess.get_file_as_string(store.path)
	var file := FileAccess.open(store.path,FileAccess.WRITE)
	file.store_string("broken")
	file.close()
	check(reloaded.load_file()==OK and reloaded.loaded_from_backup,"Damaged main profile restores valid backup")
	check(reloaded.result_for(key).best.total_time==100,"Backup still has a consistent previous score")
	check(not reloaded.load_ghost(challenge).is_empty(),"Backup-referenced ghost survives new-best cleanup")
	check(reloaded.save_file()==OK and RallyProfileStore.valid(RallyProfileStore.read_json(store.path+".bak")),"Recovery never replaces a valid backup with corrupt main data")
	var blocked := FileAccess.open(directory+"/blocked",FileAccess.WRITE)
	blocked.store_string("not a directory")
	blocked.close()
	var before := reloaded.data.duplicate(true)
	reloaded.path = directory+"/blocked/profile.json"
	var failure := reloaded.record(challenge,result(70),ghost(key,70))
	check(not failure.saved and reloaded.data==before,"Write failure preserves in-memory previous best")
	file = FileAccess.open(store.path,FileAccess.WRITE)
	file.store_string('{"version":999}')
	file.close()
	DirAccess.remove_absolute(store.path+".bak")
	reloaded.path = store.path
	check(reloaded.load_file()!=OK and reloaded.read_only,"Unknown or corrupt profile remains protected")
	check(reloaded.save_file()!=OK and FileAccess.get_file_as_string(store.path)=='{"version":999}',"Failed load never silently overwrites original save")
	for sub: String in [directory+"/ghosts",directory]:
		var access := DirAccess.open(sub)
		if access!=null:
			for filename: String in access.get_files(): access.remove(filename)
		DirAccess.remove_absolute(sub)
	finish()
