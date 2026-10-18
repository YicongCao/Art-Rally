class_name RallyStageDefinition
extends Resource

@export var stage_id: String = "sunset_ridge"
@export var title: String = "Sunset Ridge"
@export var seed_value: int = 73421
@export var target_length: float = 3050.0
@export var road_width: float = 5.6
@export var elevation_profile := Vector2.ZERO
@export var rolling_amplitude: float = 0.0
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


@export var stage_version: String = "2"
@export_enum("autumn", "coast", "highland") var environment_id: String = "autumn"
@export var subtitle: String = "秋日山林 · 混合路面"
@export var surface_sections := PackedVector3Array([Vector3(1150,1650,2),Vector3(1650,2100,0)])
@export var default_surface: int = 1
@export var width_sections := PackedVector3Array([Vector3(1150,1650,-0.5)])
@export var water_sections := PackedVector3Array([Vector3(1270,1290,0.07),Vector3(1480,1508,0.11)])
@export var crests := PackedVector3Array([Vector3(360,1.3,7),Vector3(850,1.45,8),Vector3(1430,1.4,7),Vector3(2230,1.5,8),Vector3(2650,1.3,7)])
@export var hazard_notes: Array[Dictionary] = [{"s":1150.0,"code":"MUD_NARROW"},{"s":1270.0,"code":"WATER"},{"s":1480.0,"code":"WATER"},{"s":1650.0,"code":"ASPHALT"},{"s":2100.0,"code":"GRAVEL"},{"s":2650.0,"code":"CREST_JUMP"}]
@export var culverts := PackedFloat32Array([1420])
@export var guardrail_sections := PackedVector2Array([Vector2(1680,2080)])
@export var spectators := PackedFloat32Array([80,320,503,840,1150,1500,1880,2200,2560,2970])
@export var landmarks: Array[Dictionary] = [{"s":480.0,"kind":"cabin","side":-1.0}]
@export var split_fractions := PackedFloat32Array([0.333333,0.666667,1.0])


func surface_id(distance: float) -> int:
	for section: Vector3 in surface_sections:
		if distance>=section.x and distance<section.y: return int(section.z)
	return default_surface


func width_at(distance: float) -> float:
	var width := road_width
	for section: Vector3 in width_sections:
		width += section.z*smoothstep(section.x-20,section.x+20,distance)*(1-smoothstep(section.y-30,section.y+10,distance))
	return width


func water_depth(distance: float, lateral: float) -> float:
	var depth := 0.0
	for pool: Vector3 in water_sections:
		if distance > pool.x and distance < pool.y:
			var edge := minf(distance-pool.x,pool.y-distance)
			var half := 2.8
			depth = maxf(depth,pool.z*smoothstep(0,1.5,edge)*(1-smoothstep(half-0.8,half,absf(lateral))))
	return depth
