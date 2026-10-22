extends SceneTree
# Off-road grip audit: brake from 60 km/h straight, and coast through a fixed
# steer, on each stage's road surface and its off-road shoulder surface.
#   godot --headless --path . --fixed-fps 120 --script res://scripts/dev/offroad_audit.gd
var world: Node3D
func _initialize() -> void: run.call_deferred()
func ticks(n: int) -> void:
	for i: int in range(n): await physics_frame
func trial(id: String,surface: int,mode: String) -> Dictionary:
	var ground := GrayboxGeometry.box(world,"Ground",Vector3(3000,1,3000),Vector3(0,-.5,0),Color.GRAY,true)
	ground.set_meta("surface_id",surface)
	var def := RallyContentCatalog.vehicle(id)
	var car := RallyVehicle.new()
	car.config=def.physics_config()
	car.drivetrain.config=def.drivetrain_config()
	world.add_child(car)
	car.request_reset(Transform3D(Basis.IDENTITY,Vector3(0,.8,0)))
	await ticks(120)
	var speed := 60/3.6
	car.linear_velocity=Vector3(0,0,-speed)
	for wheel: RallyWheelState in car.wheels: wheel.omega=speed/car.config.wheel_radius
	car.drivetrain.gear=mini(2,car.drivetrain.config.ratios.size())
	car.drivetrain.engine_omega=speed/car.config.wheel_radius*car.drivetrain.ratio()
	var start := car.global_position
	var result := {}
	var peak_lat := 0.0
	for frame: int in range(120*12):
		car.command.throttle=0
		car.command.brake=1.0 if mode=="brake" else 0.0
		car.command.steer=.5 if mode=="turn" else 0.0
		await ticks(1)
		var local := car.basis.inverse()*car.linear_velocity
		peak_lat=maxf(peak_lat,absf(local.x))
		if mode=="brake" and car.linear_velocity.length()<.5:
			result={"stop_m":snappedf(start.distance_to(car.global_position),.1),"stop_s":snappedf(frame/120.0,.01)}
			break
		if mode=="turn" and frame==240:
			# Lateral acceleration proxy: speed^2 * yaw curvature at 2 s.
			result={"yaw_deg_s":snappedf(rad_to_deg(car.angular_velocity.y),.1),"lat_g":snappedf(car.linear_velocity.length()*absf(car.angular_velocity.y)/9.81,.01),"slip_kmh":snappedf(absf(local.x)*3.6,.1)}
			break
	if result.is_empty(): result={"stop_m":-1,"note":"did not stop"}
	car.free();ground.free();await process_frame
	return result
func run() -> void:
	world=Node3D.new();root.add_child(world)
	var stages := {}
	for id: String in RallyContentCatalog.STAGES:
		var d:=RallyContentCatalog.stage(id)
		stages[id]=[d.default_surface,d.shoulder_surface]
	print("STAGES ",stages)
	for vehicle: String in ["R200","A240","P7"]:
		for surface: int in range(6):
			var b: Dictionary=await trial(vehicle,surface,"brake")
			var t: Dictionary=await trial(vehicle,surface,"turn")
			print("OFFROAD ",JSON.stringify({"car":vehicle,"surface":RallySurfaceQuery.LABELS[surface],"id":surface,"brake":b,"turn":t}))
	quit()
