class_name RallySurfaceQuery
extends RefCounted

const PROFILES: Array[RallySurfaceProfile] = [
	preload("res://resources/surfaces/asphalt.tres"), preload("res://resources/surfaces/gravel.tres"),
	preload("res://resources/surfaces/mud.tres"), preload("res://resources/surfaces/grass.tres"),
]


static func point_sample(collider: Object, point: Vector3) -> RallySurfaceSample:
	if collider.has_meta("surface_provider"):
		var provider: Node = collider.get_meta("surface_provider")
		return provider.surface_at(point, int(collider.get_meta("surface_hint", -1)))
	return RallySurfaceSample.from_profile(PROFILES[int(collider.get_meta("surface_id", 0))])


static func footprint(collider: Object, point: Vector3, forward: Vector3, right: Vector3) -> RallySurfaceSample:
	if collider.has_meta("surface_provider"):
		var provider: Node = collider.get_meta("surface_provider")
		if provider.has_method("surface_footprint"):
			return provider.surface_footprint(point, forward, right, int(collider.get_meta("surface_hint", -1)))
	var center := point_sample(collider, point)
	if not collider.has_meta("surface_provider"): return center
	# Blend only within a small tire patch; no time smoothing across distant surfaces.
	var samples: Array[RallySurfaceSample] = [center]
	for offset: Vector3 in [forward * 0.12, -forward * 0.12, right * 0.09, -right * 0.09]:
		samples.append(point_sample(collider, point + offset))
	return RallySurfaceSample.average(samples)
