extends "res://tests/test_suite.gd"
class Soil extends Node:
	var depth := 0.0
	func surface_at(_p: Vector3,_hint: int) -> RallySurfaceSample: return RallySurfaceQuery.road_sample(2,depth)
var report: Array=[]
func _run() -> void:
	var world := Node3D.new();root.add_child(world)
	var ground := GrayboxGeometry.box(world,"Road",Vector3(1000,1,3000),Vector3(0,-.5,-900),Color.GRAY,true)
	var soil := Soil.new();world.add_child(soil)
	ground.set_meta("surface_provider",soil)
	for id: String in RallyContentCatalog.VEHICLES:
		for depth: float in [0.0,.015,.07]:
			soil.depth=depth
			for mode: int in [0,1]:
				var definition := RallyContentCatalog.vehicle(id)
				var car := RallyVehicle.new();car.config=definition.physics_config();car.drivetrain.config=definition.drivetrain_config()
				car.drivetrain.tc_mode=mode
				world.add_child(car);car.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,.8,0)))
				await ticks(120)
				check(is_zero_approx(PhysicsServer3D.body_get_direct_state(car.get_rid()).total_linear_damp),id+" has no hidden global damping")
				var fraction := (car.wheels[0].load+car.wheels[1].load)/(car.config.body_mass*9.8)
				check(absf(fraction-(.5-car.config.center_of_mass.z/car.config.wheelbase))<.035,id+" static axle distribution")
				car.command.throttle=1
				var slip := 0.0;var changes := 0.0;var previous := 1.0;var active := false
				for frame: int in range(1440):
					await ticks(1)
					slip+=absf(car.drivetrain.wheelspin)/1440
					changes=maxf(changes,absf(previous-car.drivetrain.traction_scale));previous=car.drivetrain.traction_scale
					active=active or car.drivetrain.tc_active
				report.append({"kind":"launch","car":id,"water":depth,"tc":mode,"speed_kmh":car.linear_velocity.length()*3.6,"gear":car.drivetrain.gear,"slip":slip,"largest_demand_step":changes,"active":active})
				check(car.position.is_finite() and car.linear_velocity.length()>(2 if depth>.05 else 7),id+" launches through soil without a stall")
				if mode==1:
					var unassisted:=float(report[-2].slip)
					check(slip<unassisted*.8 or (unassisted<.1 and slip<=unassisted+.001),id+" TC reduces excess slip or preserves an already stable traction band")
					check(changes<.035,id+" TC demand changes smoothly across engine speeds")
					if depth==0: check((car.drivetrain.gear>=2 or definition.electric),id+" hardpack launch uses valid gearing")
				else: check(not active and is_equal_approx(previous,1),id+" TC off leaves engine demand unchanged")
				car.free();await ticks(2)
	ground.remove_meta("surface_provider")
	for mode: int in [0,1,2]:
		var car := RallyVehicle.new();var definition := RallyContentCatalog.vehicle("R200")
		car.config=definition.physics_config();car.drivetrain.config=definition.drivetrain_config();car.aids.esp_mode=mode
		world.add_child(car);car.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,.8,0)));await ticks(120)
		car.linear_velocity=Vector3(0,0,-24);car.angular_velocity=Vector3(0,.8,0)
		for wheel: RallyWheelState in car.wheels: wheel.omega=24/car.config.wheel_radius
		var max_beta := 0.0;var active_frames := 0;var brake_sum := 0.0
		for frame: int in range(360):
			await ticks(1)
			max_beta=maxf(max_beta,absf(car.aids.beta));active_frames+=int(car.aids.esp_active)
			for brake: float in car.aids.esp_brakes: brake_sum+=brake/120
		report.append({"kind":"yaw_recovery","mode":mode,"max_beta_deg":rad_to_deg(max_beta),"final_beta_deg":rad_to_deg(car.aids.beta),"active_frames":active_frames,"brake_impulse":brake_sum})
		check(car.global_basis.y.y>.9 and car.position.is_finite(),"ESP mode %d remains upright"%mode)
		if mode==0:check(active_frames==0 and is_zero_approx(brake_sum),"ESP off never applies selective brakes")
		else:check(active_frames>0 and brake_sum>0,"ESP mode %d intervenes through actual wheel braking"%mode)
		car.command.handbrake=1;await ticks(5)
		check(not car.aids.esp_active,"Handbrake intentionally suspends ESP")
		car.free();await ticks(2)
	check(float(report[-2].max_beta_deg)<float(report[-3].max_beta_deg)*.6,"Sport ESP limits a deliberate yaw disturbance")
	check(float(report[-1].max_beta_deg)<float(report[-2].max_beta_deg) and absf(float(report[-1].final_beta_deg))<5,"Full ESP intervenes earlier and settles the same disturbance")
	var aid := RallyDriverAids.new();var wheel := RallyWheelState.new()
	wheel.grounded=true;wheel.load=3000;wheel.effective_radius=.3;wheel.surface=RallySurfaceQuery.road_sample(0,0)
	for speed: float in [20,-20]:
		aid.reset();wheel.longitudinal_speed=speed;wheel.omega=0
		for frame: int in range(30):aid.brake(0,wheel,2000,1.0/480)
		check(aid.abs_active and aid.pressure[0]<.5,"ABS releases a locked wheel in either travel direction")
	wheel.longitudinal_speed=1
	check(aid.brake(0,wheel,2000,1.0/120)==2000,"Low speed braking keeps stopping authority")
	wheel.grounded=false;wheel.longitudinal_speed=20
	check(aid.brake(0,wheel,2000,1.0/120)==2000,"Airborne wheel does not cause ABS release")
	aid.reset();check(aid.pressure[0]==1 and not aid.abs_active and not aid.esp_active,"Restart clears all aid state")
	var dry := RallySurfaceQuery.road_sample(2,0);var wet := RallySurfaceQuery.road_sample(2,.015);var mud := RallySurfaceQuery.road_sample(2,.07)
	check(dry.rolling_extra<wet.rolling_extra and wet.rolling_extra<mud.rolling_extra and dry.grip(10)>wet.grip(10) and wet.grip(10)>mud.grip(10),"Packed dirt, wet soil and deep mud have ordered resistance and grip")
	FileAccess.open("res://logs/driver-aids.json",FileAccess.WRITE).store_string(JSON.stringify(report,"\t"))
	world.free();await process_frame;finish()
