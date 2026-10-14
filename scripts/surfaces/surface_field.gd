class_name RallySurfaceField
extends Node3D

var base_id: int = 0
var patches: Array[Dictionary] = []
var water: Array[Dictionary] = []


func surface_at(point: Vector3, _hint: int = -1) -> RallySurfaceSample:
	var local := to_local(point)
	var id := base_id
	for patch: Dictionary in patches:
		if patch.bounds.has_point(local): id = patch.id
	var depth := 0.0
	for pool: Dictionary in water:
		var bounds: AABB = pool.bounds
		if bounds.has_point(local):
			var edge := minf(minf(local.x - bounds.position.x, bounds.end.x - local.x), minf(local.z - bounds.position.z, bounds.end.z - local.z))
			depth = maxf(depth, float(pool.depth) * smoothstep(0, 0.6, edge))
	return RallySurfaceSample.from_profile(RallySurfaceQuery.PROFILES[id], depth)


func attach(body: Node) -> void:
	body.set_meta("surface_provider", self)
