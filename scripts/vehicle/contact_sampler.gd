class_name RallyContactSampler
extends RefCounted

const BASE_POINTS := [
	Vector2.ZERO,
	Vector2(-0.72,0),Vector2(0.72,0),
	Vector2(0,-0.72),Vector2(0,0.72),
]
const DIAGONAL_POINTS := [Vector2(-0.58,-0.58),Vector2(-0.58,0.58),Vector2(0.58,-0.58),Vector2(0.58,0.58)]
const OUTER_POINTS := [
	Vector2(-0.92,-0.28),Vector2(-0.92,0.28),Vector2(0.92,-0.28),Vector2(0.92,0.28),
	Vector2(-0.28,-0.92),Vector2(0.28,-0.92),Vector2(-0.28,0.92),Vector2(0.28,0.92),
]


static func sample(wheel: RallyWheelState,mount: Vector3,state: PhysicsDirectBodyState3D,config: RallyVehicleConfig,tire: RallyTireConfig,body_rid: RID) -> RallyWheelContactPatch:
	var patch := wheel.patch
	patch.begin_step()
	var up := state.transform.basis.y
	var origin := state.transform*mount
	var forward := -state.transform.basis.z.rotated(up,wheel.steer)
	var right := forward.cross(up).normalized()
	patch.forward = forward
	patch.right = right
	var predicted_deflection := wheel.radial_deflection
	if predicted_deflection<=0.0: predicted_deflection = RallyTireVerticalModel.deflection_for_load(tire.reference_load,tire)
	patch.update_shape(config,tire,predicted_deflection,RallyTireVerticalModel.elastic_force(predicted_deflection,tire))
	var query := patch.query
	query.collision_mask = 1
	if query.exclude.is_empty(): query.exclude = [body_rid]
	_append_samples(patch,BASE_POINTS,origin,up,forward,right,state,config,tire,query)
	if _needs_refine(patch,tire):
		patch.flags |= RallyWheelContactPatch.FLAG_REFINED_9
		_append_samples(patch,DIAGONAL_POINTS,origin,up,forward,right,state,config,tire,query)
		if _needs_refine(patch,tire):
			patch.flags |= RallyWheelContactPatch.FLAG_REFINED_17
			_append_samples(patch,OUTER_POINTS,origin,up,forward,right,state,config,tire,query)
	_finalize(patch,up,tire)
	return patch


static func _append_samples(patch: RallyWheelContactPatch,coordinates: Array,origin: Vector3,up: Vector3,forward: Vector3,right: Vector3,state: PhysicsDirectBodyState3D,config: RallyVehicleConfig,tire: RallyTireConfig,query: PhysicsRayQueryParameters3D) -> void:
	var free_radius := RallyTireVerticalModel.unloaded_radius(config,tire)
	for normalized: Vector2 in coordinates:
		var sample := patch.acquire_sample()
		if sample==null: return
		sample.local = Vector2(normalized.x*patch.half_length,normalized.y*patch.half_width)
		var radial := normalized.length_squared()
		sample.shape_weight = maxf(0.05,1.0-radial)
		# The compliant footprint is flattened against the support plane; all patch
		# nodes use the unloaded radius when measuring total suspension+tire closure.
		var reach := free_radius
		var from := origin+forward*sample.local.x+right*sample.local.y
		query.from = from
		query.to = from-up*(config.suspension_rest+reach)
		var hit := state.get_space_state().intersect_ray(query)
		if not hit.is_empty() and hit.normal.dot(up)>0.25:
			sample.hit = true
			sample.point = hit.position
			sample.normal = hit.normal
			sample.collider = hit.collider
			sample.support_length = from.distance_to(hit.position)-reach
			sample.surface = RallySurfaceQuery.point_sample(hit.collider,hit.position)


static func _needs_refine(patch: RallyWheelContactPatch,tire: RallyTireConfig) -> bool:
	var hits := 0
	var misses := 0
	var min_support := INF
	var max_support := -INF
	var reference_normal := Vector3.ZERO
	var reference_surface := -1
	var reference_water := -1.0
	for sample: RallyWheelContactSample in patch.samples:
		if not sample.hit:
			misses += 1
			continue
		hits += 1
		min_support = minf(min_support,sample.support_length)
		max_support = maxf(max_support,sample.support_length)
		if reference_normal==Vector3.ZERO: reference_normal = sample.normal
		elif reference_normal.angle_to(sample.normal)>tire.contact_normal_refine_radians: return true
		if reference_surface<0:
			reference_surface = sample.surface.surface_id
			reference_water = sample.surface.water_depth
		elif sample.surface.surface_id!=reference_surface or absf(sample.surface.water_depth-reference_water)>0.003:
			return true
	if hits==0: return false
	if misses>0: return true
	return max_support-min_support>tire.contact_height_refine_threshold


static func _finalize(patch: RallyWheelContactPatch,up: Vector3,tire: RallyTireConfig) -> void:
	var min_support := INF
	var total_shape := 0.0
	for sample: RallyWheelContactSample in patch.samples:
		total_shape += sample.shape_weight
		if sample.hit: min_support = minf(min_support,sample.support_length)
	if not is_finite(min_support) or total_shape<=0.0: return
	var supported_shape := 0.0
	var center_weight := 0.0
	var normal_sum := Vector3.ZERO
	var surface_mask := 0
	for sample: RallyWheelContactSample in patch.samples:
		if not sample.hit: continue
		if sample.support_length>min_support+tire.contact_cluster_tolerance:
			patch.flags |= RallyWheelContactPatch.FLAG_BRIDGE_REJECTED
			continue
		sample.supported = true
		supported_shape += sample.shape_weight
		center_weight += sample.shape_weight
		patch.center += sample.point*sample.shape_weight
		normal_sum += sample.normal*sample.shape_weight
		surface_mask |= 1<<clampi(sample.surface.surface_id,0,RallySurfaceQuery.PROFILES.size()-1)
	patch.support_ratio = clampf(supported_shape/total_shape,0.0,1.0)
	if patch.support_ratio<0.999: patch.flags |= RallyWheelContactPatch.FLAG_PARTIAL_SUPPORT
	if (surface_mask&(surface_mask-1))!=0: patch.flags |= RallyWheelContactPatch.FLAG_MIXED_SURFACE
	if center_weight<=0.0 or patch.support_ratio<0.12: return
	patch.center /= center_weight
	patch.normal = normal_sum.normalized()
	if patch.normal.dot(up)<=0.25: return
	patch.support_length = min_support
	patch.grounded = true
	patch._update_pressure_weights(tire)
	patch.refresh_surface()
