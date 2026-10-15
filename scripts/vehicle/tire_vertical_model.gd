class_name RallyTireVerticalModel
extends RefCounted

const FLAG_NONE := 0
const FLAG_NO_BRACKET := 1
const FLAG_BOTTOMING := 2
const FLAG_LIMITED := 4


static func deflection_for_load(load: float,tire: RallyTireConfig) -> float:
	if load<=0.0: return 0.0
	var low := 0.0
	var high := tire.max_radial_deflection
	for iteration: int in range(16):
		var middle := (low+high)*0.5
		if elastic_force(middle,tire)>load: high = middle
		else: low = middle
	return (low+high)*0.5


static func unloaded_radius(config: RallyVehicleConfig,tire: RallyTireConfig) -> float:
	return config.wheel_radius+deflection_for_load(tire.reference_load,tire)


static func elastic_force(deflection: float,tire: RallyTireConfig) -> float:
	var delta := clampf(deflection,0.0,tire.max_radial_deflection)
	var force := tire.vertical_linear_stiffness()*delta+tire.radial_nonlinear_stiffness*delta*delta
	if delta>tire.bottoming_start:
		var excess := delta-tire.bottoming_start
		force += tire.bottoming_stiffness*excess
	return maxf(0.0,force)


static func tire_force(deflection: float,previous_deflection: float,dt: float,tire: RallyTireConfig) -> float:
	var rate := (deflection-previous_deflection)/maxf(dt,0.000001)
	return maxf(0.0,elastic_force(deflection,tire)+tire.radial_damping*rate)


static func suspension_force(compression: float,previous_compression: float,dt: float,config: RallyVehicleConfig) -> float:
	var value := clampf(compression,0.0,config.suspension_rest)
	var rate := (value-previous_compression)/maxf(dt,0.000001)
	var damping := config.compression_damping if rate>0.0 else config.rebound_damping
	var length := config.suspension_rest-value
	var bump := maxf(0.0,config.suspension_min-length)
	return maxf(0.0,config.spring_rate()*value+damping*rate+config.bump_stiffness*bump)


static func solve(total_closure: float,previous_deflection: float,previous_compression: float,dt: float,config: RallyVehicleConfig,tire: RallyTireConfig) -> Dictionary:
	var reference_deflection := deflection_for_load(tire.reference_load,tire)
	var free_radius := config.wheel_radius+reference_deflection
	var result := {
		"grounded":false,
		"deflection":0.0,
		"compression":0.0,
		"load":0.0,
		"loaded_radius":free_radius,
		"effective_radius":free_radius,
		"damping_power":0.0,
		"flags":FLAG_NONE,
	}
	if total_closure<=0.0 or dt<=0.0:
		return result
	var low := maxf(0.0,total_closure-config.suspension_rest)
	var high := minf(tire.max_radial_deflection,total_closure)
	var flags := FLAG_NONE
	if low>high:
		low = tire.max_radial_deflection
		high = low
		flags |= FLAG_LIMITED|FLAG_BOTTOMING
	var low_value := _balance(low,total_closure,previous_deflection,previous_compression,dt,config,tire)
	var high_value := _balance(high,total_closure,previous_deflection,previous_compression,dt,config,tire)
	var deflection := low
	if low_value>0.0:
		flags |= FLAG_NO_BRACKET
	elif high_value<0.0:
		deflection = high
		flags |= FLAG_NO_BRACKET|FLAG_BOTTOMING
	else:
		for iteration: int in range(14):
			var middle := (low+high)*0.5
			if _balance(middle,total_closure,previous_deflection,previous_compression,dt,config,tire)>0.0:
				high = middle
			else:
				low = middle
		deflection = (low+high)*0.5
	var compression := clampf(total_closure-deflection,0.0,config.suspension_rest)
	var tire_load := tire_force(deflection,previous_deflection,dt,tire)
	var suspension_load := suspension_force(compression,previous_compression,dt,config)
	var load := minf(tire_load,suspension_load) if (flags&FLAG_NO_BRACKET)!=0 else (tire_load+suspension_load)*0.5
	load = clampf(load,0.0,config.body_mass*9.81*3.0)
	var loaded_radius := clampf(free_radius-deflection,free_radius-tire.max_radial_deflection,free_radius)
	var effective_radius := clampf(config.wheel_radius+(reference_deflection-deflection)*tire.effective_radius_deflection_ratio,loaded_radius,free_radius)
	var rate := (deflection-previous_deflection)/maxf(dt,0.000001)
	result = {
		"grounded":load>0.0,
		"deflection":deflection,
		"compression":compression,
		"load":load,
		"loaded_radius":loaded_radius,
		"effective_radius":effective_radius,
		"damping_power":-tire.radial_damping*rate*rate,
		"flags":flags,
	}
	return result


static func _balance(deflection: float,total_closure: float,previous_deflection: float,previous_compression: float,dt: float,config: RallyVehicleConfig,tire: RallyTireConfig) -> float:
	var compression := clampf(total_closure-deflection,0.0,config.suspension_rest)
	return tire_force(deflection,previous_deflection,dt,tire)-suspension_force(compression,previous_compression,dt,config)
