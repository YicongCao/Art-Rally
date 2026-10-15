extends "res://tests/test_suite.gd"


func _run() -> void:
	var world := Node3D.new()
	root.add_child(world)
	GrayboxGeometry.box(world,"Flat",Vector3(100,1,200),Vector3(0,-0.5,-80),Color.GRAY,true)
	var car := RallyVehicle.new()
	car.config = car.config.duplicate()
	car.config.tire_contact_model = "COMPLIANT_PATCH"
	car.tire = car.tire.duplicate()
	car.position = Vector3(0,0.85,0)
	world.add_child(car)
	await ticks(480)
	var wheel := car.wheels[0]
	var physical := PackedFloat64Array([wheel.load,wheel.radial_deflection,wheel.effective_radius,wheel.patch.area])
	car.visual_deformation_gain = 0
	var hidden := car.tire_visual_scale(wheel)
	car.visual_deformation_gain = 1
	var normal := car.tire_visual_scale(wheel)
	car.visual_deformation_gain = 2
	var amplified := car.tire_visual_scale(wheel)
	check(hidden==Vector3.ONE and normal.x<1 and amplified.x<normal.x,"Visual gain independently controls finite tire squash")
	check(physical==PackedFloat64Array([wheel.load,wheel.radial_deflection,wheel.effective_radius,wheel.patch.area]),"Visual deformation controls cannot modify physical tire state")
	var debug := RallyDebugPanel.data_for(car)
	check(debug.wheels[0].deflection_mm>0 and debug.wheels[0].patch_samples>=5 and debug.wheels[0].patch_length_mm>0,"F9 data exposes live tire deformation and patch dimensions")
	wheel.slip_dissipation = 7500
	wheel.patch.wet_fraction = 0.5
	var mix := RallyVehicleFeedback.mix_for(car)
	check(mix.slip>0 and mix.water>0,"Compliant feedback reads dissipated slip power and wet patch fraction")
	var recorder := VehicleTelemetryRecorder.new()
	recorder.capture(car)
	var path := recorder.export_csv(car)
	var file := FileAccess.open(path,FileAccess.READ)
	var header := file.get_csv_line()
	file.close()
	check("fl_deflection_m" in header and "fl_patch_area_m2" in header and "fl_slip_dissipation_w" in header,"Telemetry export appends compliant tire fields")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(path.replace(".csv",".json"))
	world.queue_free()
	await process_frame
	finish()
