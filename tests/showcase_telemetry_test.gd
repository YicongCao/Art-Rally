extends "res://tests/test_suite.gd"

func _run() -> void:
	var fps := RallyShowcaseMetrics.new()
	fps.tick(1000000,0)
	fps.tick(1020000,.02)
	fps.tick(1030000,.03)
	var report := fps.report()
	check(is_equal_approx(report.average,2/.03),"Average uses frame count / wall time, not mean of instantaneous FPS")
	check(is_equal_approx(report.minimum,50) and is_equal_approx(report.maximum,100),"Single-frame minimum and maximum")
	fps.break_interval()
	fps.tick(10000000,1)
	check(fps.frames.size()==2,"Pause/loading interval excluded")
	fps.tick(10020000,1.02)
	check(fps.frames.size()==3,"Resumed frames recorded")
	fps.tick(10020000,1.02)
	check(fps.frames.size()==3,"Duplicate timestamp cannot divide by zero")
	fps.enabled=false
	fps.tick(11000000,2)
	check(fps.frames.size()==3,"Offline rendering can disable statistics")
	fps.reset()
	check(fps.report().is_empty(),"Replay clears previous performance")
	fps.enabled=true
	fps.tick(0,0)
	fps.tick(2000000,2)
	check(is_equal_approx(fps.report().minimum,.5),"Long frame stalls are retained")
	var record := {"duration":2.0,"frames":[],"gaps":[],"unwrapped_spins":true}
	for i: int in range(121):
		var t := i/60.0
		record.frames.append([t,4.905*t*t,0,-20*t,0,0,0,1,0,0,0,0,0,.2,.2,.2,.2])
	var g := RallyShowcaseInstruments.acceleration(record,1)
	check(absf(g.x-1)<.001 and absf(g.z)<.001,"Known acceleration returns one lateral G, no longitudinal G")
	check(g.is_equal_approx(RallyShowcaseInstruments.acceleration(record,1)),"Seek sampling is deterministic")
	for vehicle: String in ["R200","F160","A240"]:
		var config := RallyContentCatalog.vehicle(vehicle).drivetrain_config()
		check(config.torque_at(4500)>0,"Original torque curve: "+vehicle)
	finish()
