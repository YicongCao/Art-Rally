extends "res://tests/test_suite.gd"


func _run() -> void:
	var config := RallyVehicleConfig.new()
	config.tire_contact_model = "COMPLIANT_PATCH"
	var tire := RallyTireConfig.new()
	var small := RallyWheelContactPatch.new()
	small.update_shape(config,tire,0.010,RallyTireVerticalModel.elastic_force(0.010,tire))
	var large := RallyWheelContactPatch.new()
	large.update_shape(config,tire,0.020,RallyTireVerticalModel.elastic_force(0.020,tire))
	check(large.half_length>small.half_length and large.area>small.area,"Patch length and area increase with elastic deflection and load")
	check(large.half_width<=tire.section_width*0.5 and large.half_length<=tire.max_patch_half_length,"Patch dimensions remain inside configured tread bounds")
	for normalized: Vector2 in [Vector2.ZERO,Vector2(-0.6,0),Vector2(0.6,0),Vector2(0,-0.6),Vector2(0,0.6)]:
		var sample := RallyWheelContactSample.new()
		sample.hit = true
		sample.supported = true
		sample.local = Vector2(normalized.x*large.half_length,normalized.y*large.half_width)
		sample.shape_weight = maxf(0.05,1.0-normalized.length_squared())
		sample.surface = RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[1])
		large.samples.append(sample)
	large._update_pressure_weights(tire)
	var pressure_sum := 0.0
	for sample: RallyWheelContactSample in large.samples: pressure_sum += sample.pressure_weight
	check(absf(pressure_sum-1.0)<0.000001,"Discrete contact-patch pressure weights normalize to one")
	var gravel := RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[1])
	var mud := RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[2],0.05)
	var mixed := RallySurfaceSample.weighted_average([gravel,mud],PackedFloat64Array([0.75,0.25]))
	check(mixed.surface_id==1 and mixed.friction_scale<gravel.friction_scale and mixed.friction_scale>mud.friction_scale and mixed.water_depth>0,"Weighted footprint preserves dominant material and bounded mixed properties")

	var world := Node3D.new()
	root.add_child(world)
	GrayboxGeometry.box(world,"Flat",Vector3(100,1,200),Vector3(0,-0.5,-80),Color.GRAY,true)
	var bump := GrayboxGeometry.box(world,"PatchBump",Vector3(8,0.10,0.16),Vector3(0,0.04,-8),Color.GRAY,true)
	var vehicle := RallyVehicle.new()
	vehicle.config = vehicle.config.duplicate()
	vehicle.config.tire_contact_model = "COMPLIANT_PATCH"
	vehicle.tire = vehicle.tire.duplicate()
	vehicle.position = Vector3(0,0.85,0)
	world.add_child(vehicle)
	await ticks(480)
	var flat_five := true
	for wheel: RallyWheelState in vehicle.wheels:
		flat_five = flat_five and wheel.patch!=null and wheel.patch.samples.size()==5 and wheel.patch.support_ratio>0.99
	check(flat_five,"Flat ground keeps the minimum five-point contact budget")
	vehicle.command.throttle = 0.45
	var refined := false
	var finite := true
	for i: int in range(720):
		await ticks(1)
		for wheel: RallyWheelState in vehicle.wheels:
			refined = refined or (wheel.patch!=null and wheel.patch.samples.size()>5)
			finite = finite and wheel.load>=0 and is_finite(wheel.load)
	check(refined,"Narrow height variation promotes contact sampling above five points")
	check(finite and vehicle.position.is_finite() and vehicle.position.y>0.3,"Adaptive contact crosses a narrow bump without numerical failure")
	bump.queue_free()
	world.queue_free()
	await process_frame
	finish()
