class_name RallySurfaceSample
extends RefCounted

var surface_id: int = 0
var friction_scale: float = 1.0
var longitudinal_scale: float = 1.0
var lateral_scale: float = 1.0
var sliding_scale: float = 1.0
var rolling_extra: float = 0.0
var wet_grip: float = 0.65
var water_depth: float = 0.0


func reset() -> void:
	surface_id = 0
	friction_scale = 1.0
	longitudinal_scale = 1.0
	lateral_scale = 1.0
	sliding_scale = 1.0
	rolling_extra = 0.0
	wet_grip = 0.65
	water_depth = 0.0


static func from_profile(profile: RallySurfaceProfile, depth: float = 0) -> RallySurfaceSample:
	var result := RallySurfaceSample.new()
	result.surface_id = profile.surface_id
	result.friction_scale = profile.friction_scale
	result.longitudinal_scale = profile.longitudinal_scale
	result.lateral_scale = profile.lateral_scale
	result.sliding_scale = profile.sliding_scale
	result.rolling_extra = profile.rolling_extra
	result.wet_grip = profile.wet_grip
	result.water_depth = clampf(depth, 0, 0.3)
	return result


func grip(speed: float) -> float:
	var wet := smoothstep(0, 0.015, water_depth)
	var speed_loss := clampf(water_depth * maxf(absf(speed) - 12, 0) * 0.08, 0, 0.38)
	return friction_scale * lerpf(1, wet_grip, wet) * (1.0 - speed_loss)


static func average(samples: Array[RallySurfaceSample]) -> RallySurfaceSample:
	var weights := PackedFloat64Array()
	weights.resize(samples.size())
	weights.fill(1.0/maxi(samples.size(),1))
	return weighted_average(samples,weights)


static func weighted_average(samples: Array[RallySurfaceSample],weights: PackedFloat64Array) -> RallySurfaceSample:
	var result := RallySurfaceSample.new()
	if samples.is_empty() or weights.size()!=samples.size(): return result
	var weight_sum := 0.0
	var id_weights := PackedFloat64Array([0,0,0,0])
	for i: int in range(samples.size()):
		var weight := maxf(0.0,weights[i])
		weight_sum += weight
		if samples[i].surface_id>=0 and samples[i].surface_id<id_weights.size(): id_weights[samples[i].surface_id] += weight
	if weight_sum<=0.0: return result
	var dominant := 0
	for i: int in range(1,id_weights.size()):
		if id_weights[i]>id_weights[dominant]: dominant = i
	result.surface_id = dominant
	for field: String in ["friction_scale", "longitudinal_scale", "lateral_scale", "sliding_scale", "rolling_extra", "wet_grip", "water_depth"]:
		var sum := 0.0
		for i: int in range(samples.size()): sum += float(samples[i].get(field))*maxf(0.0,weights[i])
		result.set(field, sum/weight_sum)
	return result


func water_resistance(velocity: Vector3, load: float, dt: float, effective_mass: float) -> Vector3:
	if water_depth <= 0 or load <= 0: return Vector3.ZERO
	# Empirical wheel-width water drag, bounded so a step cannot reverse velocity.
	var magnitude := minf(0.5 * 1000.0 * 0.23 * water_depth * velocity.length_squared(), effective_mass * velocity.length() / maxf(dt, 0.0001))
	return -velocity.normalized() * magnitude
