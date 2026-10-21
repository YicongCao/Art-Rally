extends "res://tests/test_suite.gd"

var car: RallyVehicle
var world: Node3D
var field: RallySurfaceField


func _run() -> void:
	var generator := RallyStageGenerator.new()
	generator.auto_build = false
	root.add_child(generator)
	for id: String in RallyContentCatalog.STAGES:
		generator.definition = RallyContentCatalog.stage(id)
		generator.route.build(generator.definition)
		var continuous := true
		var safe := true
		for station: int in range(20,int(generator.route.length)-20,20):
			var half := generator.route.width_at(station)*.5
			for side: float in [-1,1]:
				var edge := generator._surface_at_coordinates(station,side*half)
				var next := generator._surface_at_coordinates(station,side*(half+.01))
				var middle := generator._surface_at_coordinates(station,side*(half+.6))
				var grass := generator._surface_at_coordinates(station,side*(half+1.2))
				continuous = continuous and absf(next.friction_scale-edge.friction_scale)<.001 and is_equal_approx(middle.friction_scale,(edge.friction_scale+grass.friction_scale)*.5) and grass.surface_id==generator.definition.shoulder_surface
		for station: float in generator.definition.spectators:
			for s: float in [station-4,station,station+6,station+14]:
				var pose := generator.route.pose_at(s)
				for lateral: float in [5.8,7.5,8.5]:
					var point := pose.origin+generator.route.rights[generator.route.index_at(s)]*lateral
					var projection := generator.route.project(point)
					safe = safe and absf(float(projection.lateral))>generator.route.width_at(projection.s)*.5+.8
		check(continuous,id+" has continuous 1.2m shoulders on both sides, across width/surface changes")
		check(safe and generator.definition.spectators.size()==(5 if id=="redrock_canyon" else 10),id+" has crowd groups safely outside all nearby driving corridors")
	check(is_equal_approx(RallySampleDressing.default_visibility("pine0"),234) and is_equal_approx(RallySampleDressing.default_visibility("far_pine0"),468),"Near and distant tree visibility grows exactly 30%")
	check(is_equal_approx(RallySampleDressing.default_visibility("grass0"),136.5) and is_equal_approx(RallySampleDressing.default_visibility("rock0"),286),"Roadside detail visibility grows 30% too")
	world = Node3D.new()
	root.add_child(world)
	field = RallySurfaceField.new()
	field.base_id = 3
	world.add_child(field)
	var floor_body := GrayboxGeometry.box(world,"Ground",Vector3(300,1,1500),Vector3(0,-.5,-400),Color.GRAY,true)
	field.attach(floor_body)
	var profile: RallySurfaceProfile = RallySurfaceQuery.PROFILES[3]
	var revised := [profile.friction_scale,profile.longitudinal_scale,profile.lateral_scale,profile.rolling_extra]
	profile.friction_scale = .52
	profile.longitudinal_scale = .55
	profile.lateral_scale = .50
	profile.rolling_extra = .045
	var before := await slide_run()
	profile.friction_scale = revised[0]
	profile.longitudinal_scale = revised[1]
	profile.lateral_scale = revised[2]
	profile.rolling_extra = revised[3]
	var after := await slide_run()
	print("OFFROAD SLIDE before=",before," after=",after)
	check(after.x<before.x*.9 and after.y<before.y*.9,"Revised grass reduces lateral excursion and braking distance in actual vehicle physics")
	check(car.position.is_finite() and car.position.y>.3,"Offroad recovery remains physically stable")
	world.queue_free()
	generator.queue_free()
	await process_frame
	finish()


func slide_run() -> Vector2:
	if is_instance_valid(car):
		car.queue_free()
		await ticks(2)
	car = RallyVehicle.new()
	car.position = Vector3(0,.8,0)
	world.add_child(car)
	await ticks(240)
	car.linear_velocity = Vector3(6,0,-15)
	car.command.brake = .7
	var maximum := 0.0
	for i: int in range(600):
		await ticks(1)
		maximum = maxf(maximum,absf(car.position.x))
		if car.linear_velocity.length()<.2: break
	return Vector2(maximum,Vector2(car.position.x,car.position.z).length())
