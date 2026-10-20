class_name RallyStageBounds
extends RefCounted


static func outside(route: RallyStageRoute, position: Vector3, velocity: Vector3, dt: float, hint: int) -> bool:
	# Alpine sections permit a visible fall before recovery; other stages retain their safe apron.
	for point: Vector3 in [position,position+velocity*minf(dt*2,0.05)]:
		var end := route.position_at(route.length)
		var forward := route.tangent_at(route.length)
		var beyond := (point-end).dot(forward)
		if beyond>0:
			var lateral := absf((point-end).dot(route.rights[-1]))
			if beyond>130 or lateral>5.5 or point.y<(end+forward*beyond).y-3.5: return true
			continue
		if (point-route.points[0]).dot(route.tangents[0])<2.8: return true
		var p := route.project(point,hint,45)
		if float(p.distance)>24: p = route.project(point)
		var alpine := absf(route.definition.mountain_side_at(p.s))>.01
		if absf(p.lateral)>(32.0 if alpine else 18.0) or float(p.height)<(-12.0 if alpine else -3.5): return true
	return false
