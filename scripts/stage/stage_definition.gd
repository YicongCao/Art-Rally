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


@export var stage_version: String = "6"
@export_enum("autumn", "coast", "highland") var environment_id: String = "autumn"
@export var subtitle: String = "秋日山林 · 混合路面"
@export var surface_sections := PackedVector3Array([Vector3(1150,1650,2),Vector3(1650,2100,0)])
@export var default_surface: int = 1
@export var width_sections := PackedVector3Array([Vector3(1150,1650,-0.5)])
@export var water_sections := PackedVector3Array([Vector3(1270,1290,0.07),Vector3(1480,1508,0.11)])
@export var crests := PackedVector3Array([Vector3(360,1.3,7),Vector3(850,1.45,8),Vector3(1430,1.4,7),Vector3(2230,1.5,8),Vector3(2650,1.3,7)])
@export var hazard_notes: Array[Dictionary] = [{"s":1150.0,"code":"MUD_NARROW"},{"s":1270.0,"code":"WATER"},{"s":1480.0,"code":"WATER"},{"s":1650.0,"code":"ASPHALT"},{"s":2100.0,"code":"GRAVEL"},{"s":2650.0,"code":"CREST_JUMP"}]
@export var river_crossings := PackedVector3Array([Vector3(590,16,4.2),Vector3(1840,18,4.2)])
@export var culverts := PackedFloat32Array([1420])
@export var guardrail_sections := PackedVector2Array([Vector2(1680,2080)])
@export var spectators := PackedFloat32Array([80,320,503,840,1150,1500,1880,2200,2560,2970])
@export var landmarks: Array[Dictionary] = [{"s":480.0,"kind":"cabin","side":-1.0}]
# Authored sparse relief: centre, length, amplitude in metres. Banking stores
# start, end and outside-edge elevation; negative values are adverse camber.
@export var rough_patches := PackedVector3Array()
@export var bank_sections := PackedVector3Array()
@export var log_pile_stations := PackedFloat32Array()
@export var split_fractions := PackedFloat32Array([0.333333,0.666667,1.0])


func surface_id(distance: float) -> int:
	for section: Vector3 in surface_sections:
		if distance>=section.x and distance<section.y: return int(section.z)
	return default_surface


func width_at(distance: float) -> float:
	var width := road_width
	for section: Vector3 in width_sections:
		width += section.z*smoothstep(section.x-20,section.x+20,distance)*(1-smoothstep(section.y-30,section.y+10,distance))
	for river: Vector3 in river_crossings:
		var blend := 1-smoothstep(river.y*.5,river.y*.5+24,absf(distance-river.x))
		width = lerpf(width,minf(width,river.z),blend)
	return width


func water_depth(distance: float, lateral: float) -> float:
	var depth := 0.0
	for pool: Vector3 in water_sections:
		if distance > pool.x and distance < pool.y:
			var edge := minf(distance-pool.x,pool.y-distance)
			var half := 2.8
			depth = maxf(depth,pool.z*smoothstep(0,1.5,edge)*(1-smoothstep(half-0.8,half,absf(lateral))))
	return depth


func surface_weights(distance: float,lateral: float = 0) -> Vector3:
	var weights := Vector3.ZERO
	weights[default_surface] = 1
	# Twelve metres of dragged gravel, worn asphalt and mud, rather than a hard seam.
	var worn_s := distance+sin(lateral*2.3+distance*.11)*1.6+sin(lateral*5.1)*.6
	for section: Vector3 in surface_sections:
		var amount := smoothstep(section.x-6,section.x+6,worn_s)*(1-smoothstep(section.y-6,section.y+6,worn_s))
		var next := Vector3.ZERO
		next[int(section.z)] = 1
		weights = weights.lerp(next,amount)
	return weights


func wetness(distance: float,lateral: float) -> float:
	var wet := 0.0
	for pool: Vector3 in water_sections:
		var along := smoothstep(pool.x-10,pool.x+2,distance)*(1-smoothstep(pool.y-2,pool.y+10,distance))
		wet = maxf(wet,along*(1-smoothstep(width_at(distance)*.35,width_at(distance)*.6,absf(lateral))))
	return wet


func surface_proportions() -> Vector3:
	var totals := Vector3.ZERO
	for i: int in range(int(ceilf(target_length))): totals[surface_id(float(i)+.5)]+=1
	return totals/float(ceilf(target_length))


func surface_summary() -> String:
	var weights := surface_proportions()
	var bits: Array[String] = []
	var remaining := 100
	var present: Array[int] = []
	for i: int in range(3):
		if weights[i]>.001: present.append(i)
	for n: int in range(present.size()):
		var i := present[n]
		var percent := remaining if n==present.size()-1 else roundi(weights[i]*100)
		remaining-=percent
		bits.append("%s %d%%"%[["柏油","砂石","泥地"][i],percent])
	return " / ".join(bits)


func relief_weight(s: float) -> float:
	var weight := (1-surface_weights(s).x)*smoothstep(50,80,s)*(1-smoothstep(target_length-100,target_length-50,s))
	for bridge: Vector3 in river_crossings:
		weight *= smoothstep(bridge.y*.5+24,bridge.y*.5+36,absf(s-bridge.x))
	for crest: Vector3 in crests:
		weight *= smoothstep(crest.z*2,crest.z*3,absf(s-crest.x))
	return weight


func bumps_at(s: float,lateral: float) -> float:
	var height := 0.0
	for patch: Vector3 in rough_patches:
		var envelope := 1-smoothstep(patch.y*.3,patch.y*.5,absf(s-patch.x))
		if envelope<=0: continue
		# Long enough wavelengths for the 2m collision samples; lateral phase
		# gives left/right wheels different motion instead of uniform pitching.
		height += patch.z*envelope*sin((s-patch.x)*TAU/10+lateral*.7)*(.7+.3*cos(lateral*1.3))
	return height*relief_weight(s)
