class_name RallyStageRoute
extends RefCounted

var definition: RallyStageDefinition
var curve := Curve3D.new()
var points := PackedVector3Array()
var tangents := PackedVector3Array()
var rights := PackedVector3Array()
var distances := PackedFloat64Array()
var length: float = 0.0
var spacing: float = 2.0
var notes: Array[Dictionary] = []


func build(settings: RallyStageDefinition) -> void:
	definition = settings
	curve = _curve(settings.control_points, 1.0)
	curve = _curve(settings.control_points, settings.target_length / curve.get_baked_length())
	length = curve.get_baked_length()
	points.clear()
	tangents.clear()
	rights.clear()
	distances.clear()
	var count := ceili(length / settings.sample_spacing)
	spacing = length / count
	for i: int in range(count + 1):
		var s := i * spacing
		var point := curve.sample_baked(s, true)
		var roughness := 0.006 if settings.surface_id(s) == 0 else 0.025
		point.y += roughness * sin(s * 1.3) * sin(s * 0.17)
		point.y += 1.3 * exp(-pow((s - 2650) / 7.0, 2))
		points.append(point)
		distances.append(s)
	for i: int in range(points.size()):
		var tangent := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		tangents.append(tangent)
		rights.append(tangent.cross(Vector3.UP).normalized())
	_build_notes()


func _curve(controls: PackedVector3Array, scale_factor: float) -> Curve3D:
	var result := Curve3D.new()
	result.bake_interval = 0.5
	for i: int in range(controls.size()):
		var tangent := (controls[mini(i + 1, controls.size() - 1)] - controls[maxi(i - 1, 0)]) * scale_factor / 6
		result.add_point(controls[i] * scale_factor, -tangent if i > 0 else Vector3.ZERO, tangent if i < controls.size() - 1 else Vector3.ZERO)
	return result


func index_at(s: float) -> int:
	return clampi(int(s / spacing), 0, points.size() - 2)


func position_at(s: float) -> Vector3:
	var i := index_at(s)
	var fraction := clampf((s - distances[i]) / (distances[i + 1] - distances[i]), 0, 1)
	return points[i].lerp(points[i + 1], fraction)


func tangent_at(s: float) -> Vector3:
	return tangents[index_at(s)]


func width_at(s: float) -> float:
	return definition.road_width - 0.5 * smoothstep(1130, 1170, s) * (1 - smoothstep(1620, 1660, s))


func pose_at(s: float, clearance: float = 0.82) -> Transform3D:
	var forward := tangent_at(s)
	var right := forward.cross(Vector3.UP).normalized()
	var up := right.cross(forward).normalized()
	return Transform3D(Basis(right, up, -forward), position_at(s) + up * clearance)


func project(point: Vector3, hint: int = -1, radius: int = 35) -> Dictionary:
	var start := 0 if hint < 0 else maxi(0, hint - radius)
	var end := points.size() - 1 if hint < 0 else mini(points.size() - 1, hint + radius)
	var best := INF
	var result := {"s": 0.0, "lateral": 0.0, "index": 0, "distance": INF, "height": 0.0}
	for i: int in range(start, end):
		var segment := points[i + 1] - points[i]
		var t := clampf((point - points[i]).dot(segment) / segment.length_squared(), 0, 1)
		var at := points[i] + segment * t
		var distance := point.distance_squared_to(at)
		if distance < best:
			best = distance
			result = {"s": lerpf(distances[i], distances[i + 1], t), "lateral": (point - at).dot(rights[i]), "index": i, "distance": sqrt(distance), "height": point.y - at.y}
	return result


func _build_notes() -> void:
	notes.clear()
	var last_turn := -100.0
	for i: int in range(10, points.size() - 10, 5):
		var angle := tangents[i - 10].signed_angle_to(tangents[i + 10], Vector3.UP)
		if absf(angle) > 0.24 and distances[i] - last_turn > 85:
			var direction := "LEFT" if angle > 0 else "RIGHT"
			var severity := "TIGHT" if absf(angle) > 0.75 else "MEDIUM"
			notes.append({"s": distances[i], "code": direction + "_" + severity})
			last_turn = distances[i]
	for note: Dictionary in [{"s": 1150.0, "code": "MUD_NARROW"}, {"s": 1270.0, "code": "WATER"}, {"s": 1480.0, "code": "WATER"}, {"s": 1650.0, "code": "ASPHALT"}, {"s": 2100.0, "code": "GRAVEL"}, {"s": 2650.0, "code": "CREST_JUMP"}, {"s": length - 30.0, "code": "FINISH"}]:
		notes.append(note)
	notes.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.s < b.s)


func validate() -> PackedStringArray:
	var errors := PackedStringArray()
	for i: int in range(points.size() - 1):
		var delta := points[i + 1] - points[i]
		if not points[i].is_finite() or delta.length() < 0.01: errors.append("Invalid sample %d" % i)
		if absf(delta.y) / maxf(Vector2(delta.x, delta.z).length(), 0.01) > 0.35: errors.append("Slope too steep %d" % i)
		if rights[i].dot(rights[i + 1]) < 0.9: errors.append("Road frame discontinuity %d" % i)
	# Coarse corridor clearance catches distant crossing/overlap, not adjacent road samples.
	for i: int in range(0, points.size(), 5):
		for j: int in range(i + 25, points.size(), 5):
			if Vector2(points[i].x - points[j].x, points[i].z - points[j].z).length() < 14:
				errors.append("Nonadjacent road overlap %d/%d" % [i, j])
	return errors
