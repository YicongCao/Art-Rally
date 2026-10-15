extends "res://tests/test_suite.gd"


func _run() -> void:
	for kind: String in ["engine","load","asphalt","gravel","mud","water","impact"]:
		var stream := RallySynthAudio.stream(kind)
		var max_sample := 0
		for i: int in range(0,stream.data.size(),2): max_sample = maxi(max_sample,absi(stream.data.decode_s16(i)))
		check(stream.data.size()>1000 and max_sample>100 and max_sample<32767,"Synthesized %s stream has bounded nonzero PCM"%kind)
	var car := RallyVehicle.new()
	root.add_child(car)
	var airborne := RallyVehicleFeedback.mix_for(car)
	check(airborne.gravel==0 and airborne.water==0 and airborne.engine>0,"Airborne car keeps engine but has no contact audio")
	for wheel: RallyWheelState in car.wheels:
		wheel.grounded = true
		wheel.load = 3000
		wheel.longitudinal_speed = 20
		wheel.slip = 0.4
		wheel.surface = RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[2],0.08)
	var wet := RallyVehicleFeedback.mix_for(car)
	check(wet.mud>0 and wet.water>0 and wet.asphalt==0,"Material and water layer produce distinct audio contributions")
	car.command.throttle = 1
	var loaded_mix := RallyVehicleFeedback.mix_for(car)
	var mix_sum := 0.0
	for key: String in ["engine","load","asphalt","gravel","mud","water"]:
		mix_sum += float(loaded_mix[key])
	check(is_finite(mix_sum) and mix_sum*float(RallyGameSettings.DEFAULTS.volume)<1.0,"Default synthesized mix retains aggregate headroom under wet loaded driving")
	var effects := RallyVehicleFeedback.new()
	var holder := Node3D.new()
	root.add_child(holder)
	effects.build(holder)
	var controls := RallyInputController.new()
	root.add_child(controls)
	effects.update(car,RallyGameSettings.new(),controls,false,0.05)
	var water_count := 0
	for entry: Dictionary in effects.particles:
		if entry.kind=="water" and entry.emitter.emitting: water_count+=1
	check(water_count==4,"All four contacting wheels can emit water spray")
	effects.update(car,RallyGameSettings.new(),controls,true,0.05)
	check(effects.is_paused and not effects.particles[2].emitter.emitting,"Pause gates feedback updates and particle emission")
	effects.dispose()
	controls.queue_free()
	car.queue_free()
	holder.queue_free()
	await process_frame
	finish()
