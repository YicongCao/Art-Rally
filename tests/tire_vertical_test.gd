extends "res://tests/test_suite.gd"


func _run() -> void:
	var config := RallyVehicleConfig.new()
	config.compression_damping = 0
	config.rebound_damping = 0
	config.bump_stiffness = 0
	var tire := RallyTireConfig.new()
	tire.radial_nonlinear_stiffness = 0
	tire.radial_damping = 0
	tire.bottoming_start = 1
	check(RallyTireVerticalModel.elastic_force(0,tire)==0,"Unloaded compliant tire produces no normal force")
	check(RallyTireVerticalModel.elastic_force(0.02,tire)>RallyTireVerticalModel.elastic_force(0.01,tire),"Radial force increases monotonically with deflection")
	var soft := tire.vertical_linear_stiffness()
	tire.inflation_pressure_pa = tire.reference_pressure_pa*1.2
	check(tire.vertical_linear_stiffness()>soft,"Higher pressure raises configured radial stiffness")
	tire.inflation_pressure_pa = tire.reference_pressure_pa
	var closure := 0.15
	var solved: Dictionary = RallyTireVerticalModel.solve(closure,0,0,1.0/120.0,config,tire)
	var ks := config.spring_rate()
	var expected_deflection := ks/(ks+tire.radial_stiffness)*closure
	var expected_compression := closure-expected_deflection
	check(absf(float(solved.deflection)-expected_deflection)<0.00002 and absf(float(solved.compression)-expected_compression)<0.00002,"Implicit series solve matches the linear analytic solution")
	check(absf(RallyTireVerticalModel.tire_force(solved.deflection,solved.deflection,1.0/120.0,tire)-RallyTireVerticalModel.suspension_force(solved.compression,solved.compression,1.0/120.0,config))<2.0,"Solved tire and suspension forces balance")
	var lighter: Dictionary = RallyTireVerticalModel.solve(0.08,0,0,1.0/120.0,config,tire)
	check(float(lighter.deflection)<float(solved.deflection) and float(lighter.load)<float(solved.load),"Deflection and load rise with total closure")
	var free_radius := RallyTireVerticalModel.unloaded_radius(config,tire)
	check(float(solved.loaded_radius)<=float(solved.effective_radius) and float(solved.effective_radius)<=free_radius,"Loaded and effective radii remain geometrically ordered")
	tire.radial_damping = 120
	var dynamic: Dictionary = RallyTireVerticalModel.solve(0.12,0.005,0.08,1.0/120.0,config,tire)
	check(float(dynamic.damping_power)<=0 and is_finite(float(dynamic.load)),"Radial damping is passive and finite")
	var released: Dictionary = RallyTireVerticalModel.solve(-0.01,0.01,0.05,1.0/120.0,config,tire)
	check(not released.grounded and released.load==0,"Negative closure releases unilateral tire contact")
	tire.radial_damping = 0
	tire.bottoming_start = 0.02
	var bottomed: Dictionary = RallyTireVerticalModel.solve(config.suspension_rest+tire.max_radial_deflection+0.02,0,0,1.0/120.0,config,tire)
	check(is_finite(float(bottomed.load)) and float(bottomed.deflection)<=tire.max_radial_deflection and int(bottomed.flags)!=0,"Excess closure is bounded and reported")
	var wheel := RallyWheelState.new()
	wheel.radial_deflection = 0.02
	wheel.effective_radius = 0.32
	wheel.reset(0.35)
	check(wheel.radial_deflection==0 and wheel.effective_radius==0.35,"Wheel reset clears compliance history and restores configured radius")
	finish()
