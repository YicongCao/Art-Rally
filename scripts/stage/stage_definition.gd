class_name RallyStageDefinition
extends Resource

@export var title: String = "Sunset Ridge"
@export var seed_value: int = 73421
@export var target_length: float = 3050.0
@export var road_width: float = 5.6
@export var sample_spacing: float = 2.0
@export var control_points := PackedVector3Array([
	Vector3(0, 0, 0), Vector3(0, 2, -180), Vector3(80, 8, -300),
	Vector3(130, 10, -410), Vector3(40, 8, -520), Vector3(-60, 9, -620),
	Vector3(-130, 14, -780), Vector3(-70, 18, -940), Vector3(90, 15, -1060),
	Vector3(150, 12, -1200), Vector3(70, 8, -1320), Vector3(-70, 7, -1400),
	Vector3(-160, 8, -1560), Vector3(-100, 14, -1710), Vector3(80, 18, -1800),
	Vector3(180, 22, -1840), Vector3(235, 24, -1810), Vector3(235, 24, -1760),
	Vector3(290, 27, -1720), Vector3(380, 30, -1830), Vector3(360, 34, -1990),
	Vector3(240, 36, -2120), Vector3(270, 42, -2280), Vector3(380, 44, -2410),
	Vector3(370, 42, -2570),
])


func surface_id(distance: float) -> int:
	if distance >= 1150 and distance < 1650: return 2
	if distance >= 1650 and distance < 2100: return 0
	return 1


func water_depth(distance: float, lateral: float) -> float:
	var depth := 0.0
	for pool: Vector3 in [Vector3(1270, 1290, 0.07), Vector3(1480, 1508, 0.11)]:
		if distance > pool.x and distance < pool.y:
			var edge := minf(distance - pool.x, pool.y - distance)
			depth = maxf(depth, pool.z * smoothstep(0, 1.5, edge) * (1.0 - smoothstep(2.0, 2.8, absf(lateral))))
	return depth
