class_name RallyWheelContactPatch
extends RefCounted

const FLAG_NONE := 0
const FLAG_REFINED_9 := 1
const FLAG_REFINED_17 := 2
const FLAG_PARTIAL_SUPPORT := 4
const FLAG_BRIDGE_REJECTED := 8
const FLAG_MIXED_SURFACE := 16

var grounded: bool = false
var center := Vector3.ZERO
var normal := Vector3.UP
var forward := Vector3.FORWARD
var right := Vector3.RIGHT
var support_length: float = INF
var half_length: float = 0.0
var half_width: float = 0.0
var area: float = 0.0
var support_ratio: float = 0.0
var wet_fraction: float = 0.0
var pressure_center := Vector2.ZERO
var samples: Array[RallyWheelContactSample] = []
var surface := RallySurfaceSample.new()
var flags: int = FLAG_NONE
var sample_pool: Array[RallyWheelContactSample] = []
var query := PhysicsRayQueryParameters3D.new()


func _init() -> void:
	for i: int in range(17): sample_pool.append(RallyWheelContactSample.new())


func begin_step() -> void:
	grounded = false
	center = Vector3.ZERO
	normal = Vector3.UP
	support_length = INF
	support_ratio = 0.0
	wet_fraction = 0.0
	pressure_center = Vector2.ZERO
	surface.reset()
	flags = FLAG_NONE
	samples.clear()


func acquire_sample() -> RallyWheelContactSample:
	var index := samples.size()
	if index>=sample_pool.size(): return null
	var sample := sample_pool[index]
	sample.reset()
	samples.append(sample)
	return sample


func update_shape(config: RallyVehicleConfig,tire: RallyTireConfig,deflection: float,elastic_load: float) -> void:
	if deflection<=0.0 or elastic_load<=0.0:
		half_length = 0.0
		half_width = 0.0
		area = 0.0
		return
	var free_radius := RallyTireVerticalModel.unloaded_radius(config,tire)
	var geometric := sqrt(maxf(2.0*free_radius*deflection-deflection*deflection,0.0))
	half_length = clampf(tire.patch_length_scale*geometric,tire.min_patch_half_length,tire.max_patch_half_length)
	var mean_pressure := maxf(tire.inflation_pressure_pa+tire.carcass_contact_pressure_pa,1000.0)
	var target_area := elastic_load/mean_pressure
	half_width = clampf(target_area/(PI*maxf(half_length,0.001)),tire.min_patch_half_width,minf(tire.max_patch_half_width,tire.section_width*0.5))
	area = PI*half_length*half_width
	_update_pressure_weights(tire)


func _update_pressure_weights(tire: RallyTireConfig) -> void:
	var sum := 0.0
	for sample: RallyWheelContactSample in samples:
		var x := sample.local.x/maxf(half_length,0.001)
		var y := sample.local.y/maxf(half_width,0.001)
		var radial := x*x+y*y
		sample.pressure_weight = sample.shape_weight*pow(maxf(0.0,1.0-radial),tire.patch_pressure_exponent) if sample.supported else 0.0
		sum += sample.pressure_weight
	if sum<=0.0: return
	pressure_center = Vector2.ZERO
	wet_fraction = 0.0
	for sample: RallyWheelContactSample in samples:
		sample.pressure_weight /= sum
		pressure_center += sample.local*sample.pressure_weight
		wet_fraction += smoothstep(0.0,0.015,sample.surface.water_depth)*sample.pressure_weight


func refresh_surface() -> void:
	surface.reset()
	var total := 0.0
	var id0 := 0.0
	var id1 := 0.0
	var id2 := 0.0
	var id3 := 0.0
	var friction := 0.0
	var longitudinal := 0.0
	var lateral := 0.0
	var sliding := 0.0
	var rolling := 0.0
	var wet_grip_sum := 0.0
	var depth := 0.0
	for sample: RallyWheelContactSample in samples:
		if not sample.supported: continue
		var weight := sample.pressure_weight
		total += weight
		match sample.surface.surface_id:
			0: id0 += weight
			1: id1 += weight
			2: id2 += weight
			3: id3 += weight
		friction += sample.surface.friction_scale*weight
		longitudinal += sample.surface.longitudinal_scale*weight
		lateral += sample.surface.lateral_scale*weight
		sliding += sample.surface.sliding_scale*weight
		rolling += sample.surface.rolling_extra*weight
		wet_grip_sum += sample.surface.wet_grip*weight
		depth += sample.surface.water_depth*weight
	if total<=0.0: return
	var ids := Vector4(id0,id1,id2,id3)
	var dominant := 0
	for i: int in range(1,4):
		if ids[i]>ids[dominant]: dominant = i
	surface.surface_id = dominant
	surface.friction_scale = friction/total
	surface.longitudinal_scale = longitudinal/total
	surface.lateral_scale = lateral/total
	surface.sliding_scale = sliding/total
	surface.rolling_extra = rolling/total
	surface.wet_grip = wet_grip_sum/total
	surface.water_depth = depth/total
