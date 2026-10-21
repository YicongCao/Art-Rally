extends "res://tests/test_suite.gd"
# Read-only calibration probe: overrides affect in-memory resources only; production files are never saved.
func _run() -> void:
	var cases: Array[Dictionary]=[]
	for surface: int in [0,1,2]:
		for grade: float in [0.0,.10]: cases.append({"id":"F160","surface":surface,"grade":grade})
	for id: String in ["R200","A240"]: cases.append({"id":id,"surface":2,"grade":.10})
	cases.append({"id":"F160","surface":2,"grade":.10,"water":.015})
	cases.append({"id":"F160","surface":2,"grade":.10,"assist":false})
	cases.append({"id":"F160","surface":2,"grade":.10,"rolling_extra":0.0})
	for grade: float in [0.0,.10]:
		cases.append({"id":"F160","surface":2,"grade":grade,"replace_damping":true})
	cases.append({"id":"F160","surface":2,"grade":.10,"water":.015,"replace_damping":true})
	var reports: Array=[]
	for scenario: Dictionary in cases:
		var world := Node3D.new()
		root.add_child(world)
		var field := RallySurfaceField.new()
		field.base_id=scenario.surface
		world.add_child(field)
		if scenario.has("water"): field.water=[{"bounds":AABB(Vector3(-100,-1000,-2000),Vector3(200,2000,4000)),"depth":scenario.water}]
		var grade := Basis(Vector3.RIGHT,atan(float(scenario.grade)))
		var body := GrayboxGeometry.box(world,"Test surface",Vector3(160,1,3000),grade*Vector3(0,-.5,-900),Color.GRAY,true)
		body.basis=grade
		field.attach(body)
		# The shared surface is duplicated for this diagnostic-only counterfactual.
		var original := RallySurfaceQuery.PROFILES[scenario.surface].rolling_extra
		if scenario.has("rolling_extra"): RallySurfaceQuery.PROFILES[scenario.surface].rolling_extra=scenario.rolling_extra
		var definition := RallyContentCatalog.vehicle(scenario.id)
		var car := RallyVehicle.new()
		car.config=definition.physics_config()
		car.drivetrain.config=definition.drivetrain_config()
		car.drivetrain.config.loose_surface_assist=scenario.get("assist",true)
		car.transform=Transform3D(grade,grade*Vector3(0,.85,0))
		world.add_child(car)
		if scenario.get("replace_damping",false): car.linear_damp_mode=RigidBody3D.DAMP_MODE_REPLACE
		car.command.brake=1
		await ticks(240)
		car.command.brake=0
		car.command.throttle=1
		var trace: Array=[]
		var time30 := -1.0
		var time60 := -1.0
		for frame: int in range(4800):
			await ticks(1)
			var speed := car.linear_velocity.dot(-grade.z)*3.6
			if speed>=30 and time30<0: time30=(frame+1)/120.0
			if speed>=60 and time60<0: time60=(frame+1)/120.0
			if frame%12!=11: continue
			var fx := 0.0
			var roll := 0.0
			var water := 0.0
			var front_load := 0.0
			for i: int in range(4):
				var wheel := car.wheels[i]
				fx+=wheel.longitudinal_force
				roll+=(car.config.rolling_resistance+wheel.surface.rolling_extra)*wheel.load*tanh(wheel.longitudinal_speed/.5)
				water+=wheel.water_force.length()
				if i<2: front_load+=wheel.load
			trace.append({"t":(frame+1)/120.0,"kmh":speed,"rpm":car.drivetrain.rpm(),"gear":car.drivetrain.gear,"slip":car.drivetrain.wheelspin,"throttle":car.drivetrain.effective_throttle,"traction_scale":car.drivetrain.traction_scale,"front_load_N":front_load,"tire_force_N":fx,"rolling_N":roll,"water_N":water,"clutch":car.drivetrain.clutch,"effective_damping":PhysicsServer3D.body_get_direct_state(car.get_rid()).total_linear_damp})
		var result := {"scenario":scenario,"power_ps":definition.power_ps,"t30":time30,"t60":time60,"at10":trace[99],"at20":trace[199],"at40":trace[-1],"trace":trace}
		reports.append(result)
		var summary := result.duplicate();summary.erase("trace")
		print("MUD DIAGNOSTIC ",JSON.stringify(summary))
		RallySurfaceQuery.PROFILES[scenario.surface].rolling_extra=original
		world.free()
		await ticks(2)
	var output := FileAccess.open("res://docs/brushline/vehicle-polish/mud-diagnostic.json",FileAccess.WRITE)
	output.store_string("[\n")
	for index: int in range(reports.size()):
		var report: Dictionary=reports[index].duplicate()
		var trace: Array=report.trace
		report.erase("trace")
		output.store_string(JSON.stringify(report).trim_suffix("}")+",\"trace\":[\n")
		for sample: int in range(trace.size()):
			output.store_string(JSON.stringify(trace[sample])+(",\n" if sample<trace.size()-1 else "\n"))
		output.store_string("]}"+(",\n" if index<reports.size()-1 else "\n"))
	output.store_string("]\n")
	quit()
