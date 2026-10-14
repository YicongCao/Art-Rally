class_name RallyStageScenery
extends Node3D

var route: RallyStageRoute
var generator: RallyStageGenerator
var center := Vector3.ZERO
var dressing := Node3D.new()
var foliage := RallySampleDressing.new()
var terrain_noise := FastNoiseLite.new()
var lookup: Dictionary = {}
var obstacles: Array[StaticBody3D] = []
var spectator_zones: Array[Vector3] = []
var spectator_regions: Array[Dictionary] = []
var grass_batches: Array[MultiMeshInstance3D] = []
var all_batches: Array[MultiMeshInstance3D] = []
var gravel_batches: int = 0
var bounds := AABB()


func build(stage: RallyStageGenerator) -> void:
	generator = stage
	route = stage.route
	center = route.position_at(route.length*0.5)
	dressing.name = "StageDressing"
	add_child(dressing)
	terrain_noise.seed = 593
	terrain_noise.frequency = 0.006
	terrain_noise.fractal_octaves = 4
	bounds = AABB(route.points[0],Vector3.ZERO)
	for i: int in range(0,route.points.size()-1,8):
		bounds = bounds.expand(route.points[i])
		var cell := Vector2i(floori(route.points[i].x/64),floori(route.points[i].z/64))
		if not lookup.has(cell): lookup[cell] = []
		lookup[cell].append(i)
	_apply_materials()
	_build_terrain()
	_build_mountains()
	foliage.spectator_stations = [80.0,503.0,1880.0,2970.0]
	foliage.build_range(self,12,route.length-35,0.58)
	for station: float in foliage.spectator_stations:
		spectator_zones.append(ground_at(station+5,8))
		spectator_regions.append({"a":ground_at(station-1,8),"b":ground_at(station+13,8)})
	_build_obstacles()
	_build_guardrails()
	_build_gravel()
	for node: Node in dressing.get_children():
		if node is MultiMeshInstance3D:
			all_batches.append(node)
			if str(node.name).begins_with("grass"): grass_batches.append(node)
	for child: Node in generator.get_children():
		if str(child.name).begins_with("Landmark"): child.visible = false


func nearest(point: Vector3) -> Dictionary:
	var cell := Vector2i(floori(point.x/64),floori(point.z/64))
	var candidates: Array = []
	for x: int in range(-1,2):
		for z: int in range(-1,2):
			candidates.append_array(lookup.get(cell+Vector2i(x,z),[]))
	if candidates.is_empty():
		for i: int in range(0,route.points.size()-1,24): candidates.append(i)
	var best := INF
	var result := {"s":0.0,"distance":INF,"lateral":0.0,"point":Vector3.ZERO}
	for raw: Variant in candidates:
		var i := int(raw)
		var end := mini(i+8,route.points.size()-1)
		var a := route.points[i]
		var b := route.points[end]
		var delta := Vector2(b.x-a.x,b.z-a.z)
		var t := clampf(Vector2(point.x-a.x,point.z-a.z).dot(delta)/maxf(delta.length_squared(),0.001),0,1)
		var at := a.lerp(b,t)
		var distance := Vector2(point.x-at.x,point.z-at.z).length_squared()
		if distance < best:
			best = distance
			result = {"s":lerpf(route.distances[i],route.distances[end],t),"distance":sqrt(distance),"lateral":(point-at).dot(route.rights[i]),"point":at}
	return result


func height_at(x: float,z: float) -> float:
	var p := nearest(Vector3(x,0,z))
	var d: float = p.distance
	var half := route.width_at(p.s)*0.5
	var close: float = p.point.y-minf(maxf(d-half,0)*0.18,2.3)
	close += smoothstep(1.5,10,d-half)*0.5*sin(float(p.s)*0.03+float(p.lateral)*0.2)
	var far: float = p.point.y-6+terrain_noise.get_noise_2d(x,z)*58+signf(p.lateral)*minf(d*0.14,27)
	return lerpf(close-0.65,far,smoothstep(21,110,d))


func ground_at(s: float,lateral: float) -> Vector3:
	var at := route.position_at(s)+route.rights[route.index_at(s)]*lateral
	if absf(lateral) < 21:
		var d := absf(lateral)-route.width_at(s)*0.5
		at.y -= minf(maxf(d,0)*0.18,2.3)
		at.y += smoothstep(1.5,10,d)*0.5*sin(s*0.03+lateral*0.2)
	else: at.y = height_at(at.x,at.z)
	return at


func allows_decoration(point: Vector3, kind: String, scale_factor: float) -> bool:
	var p := nearest(point)
	var radius := 2.8*scale_factor if kind in ["pine","umbrella"] else (1.4*scale_factor if kind == "rock" else 0.25)
	if kind in ["pine","umbrella","rock"]:
		for station: float in foliage.spectator_stations:
			if point.distance_to(ground_at(station+5,8)) < 8+radius: return false
	return float(p.distance) > route.width_at(p.s)*0.5+radius+0.15


func _apply_materials() -> void:
	var ground := ShaderMaterial.new()
	ground.shader = preload("res://assets/shaders/stage_ground.gdshader")
	ground.set_shader_parameter("road_mesh",true)
	for mesh: MeshInstance3D in generator.road_visuals: mesh.material_override = ground
	var water := ShaderMaterial.new()
	water.shader = preload("res://assets/shaders/stage_water.gdshader")
	for mesh: MeshInstance3D in generator.water_visuals: mesh.material_override = water


func _build_terrain() -> void:
	var start := Vector2(bounds.position.x-400,bounds.position.z-400)
	var extent := Vector2(bounds.size.x+800,bounds.size.z+800)
	var count := Vector2i(ceili(extent.x/16),ceili(extent.y/16))
	var vertices := PackedVector3Array()
	for z: int in range(count.y+1):
		for x: int in range(count.x+1):
			var px := start.x+x*16
			var pz := start.y+z*16
			vertices.append(Vector3(px,height_at(px,pz),pz))
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z: int in range(count.y):
		for x: int in range(count.x):
			var a := z*(count.x+1)+x
			var b := a+count.x+1
			for index: int in [a,a+1,b+1,a,b+1,b]: tool.add_vertex(vertices[index])
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.name = "StageTerrain"
	mesh.mesh = tool.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/stage_ground.gdshader")
	mesh.material_override = material
	dressing.add_child(mesh)


func _build_mountains() -> void:
	# Reuse approved faceted silhouettes, expanding the background around the entire stage.
	var sample := RallySampleLandscape.new()
	sample.center = center
	sample.dressing.free()
	sample.dressing = dressing
	sample._build_mountains()
	for child: Node in dressing.get_children():
		if child is MeshInstance3D and str(child.name).begins_with("MountainLayer"):
			child.scale = Vector3(2.8,1.65,2.8)
			child.position = center-child.scale*center
		elif str(child.name) == "DistantValleyFloor":
			child.scale = Vector3(1.5,1,1.5)
	sample.dressing = null
	sample.free()


func _build_obstacles() -> void:
	for placement: Dictionary in foliage.placements:
		var tree: bool = placement.kind in ["pine","umbrella"]
		var rock: bool = placement.kind=="rock" and placement.scale>0.8 and absf(placement.lateral)<11
		if (not tree and not rock) or absf(placement.lateral) > 14: continue
		var body := StaticBody3D.new()
		body.position = placement.point
		body.collision_layer = 4
		body.collision_mask = 2
		var collision := CollisionShape3D.new()
		if tree:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = 0.20*float(placement.scale)
			cylinder.height = 4*float(placement.scale)
			collision.position.y = cylinder.height*0.5
			collision.shape = cylinder
		else:
			var sphere := SphereShape3D.new()
			sphere.radius = 0.6*float(placement.scale)
			collision.position.y = 0.4*float(placement.scale)
			collision.shape = sphere
		body.add_child(collision)
		add_child(body)
		obstacles.append(body)


func _build_gravel() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 164307
	var mesh := RallySampleGravel.pebble_mesh()
	for start: int in range(0,int(route.length)-20,40):
		if generator.definition.surface_id(start+20) != 1: continue
		var transforms: Array[Transform3D] = []
		for i: int in range(1600):
			var s := rng.randf_range(start,start+40)
			var lateral := rng.randf_range(-2.7,2.7)
			if absf(absf(lateral)-0.8)<0.28 and rng.randf()<0.75: continue
			var at := ground_at(s,lateral)+Vector3.UP*0.001
			var radius := rng.randf_range(0.025,0.055)
			var basis := route.pose_at(s).basis*Basis(Vector3.UP,rng.randf()*TAU)
			transforms.append(Transform3D(basis.scaled_local(Vector3(radius,rng.randf_range(0.004,0.014),radius)),at))
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = transforms.size()
		for i: int in range(transforms.size()): mm.set_instance_transform(i,transforms[i])
		var visual := MultiMeshInstance3D.new()
		visual.name = "Aggregate%d"%start
		visual.multimesh = mm
		visual.visibility_range_end = 75
		visual.visibility_range_end_margin = 12
		visual.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dressing.add_child(visual)
		gravel_batches += 1


func _build_guardrails() -> void:
	for s: int in range(1680,2080,4):
		var angle := route.tangent_at(s).signed_angle_to(route.tangent_at(s+8),Vector3.UP)
		if absf(angle)<0.025: continue
		var lateral := signf(angle)*(route.width_at(s)*0.5+1.1)
		var a := ground_at(s,lateral)+Vector3.UP*0.62
		var b := ground_at(s+4,lateral)+Vector3.UP*0.62
		var rotation := Basis.looking_at((b-a).normalized()).get_euler()*180/PI
		var rail := GrayboxGeometry.box(dressing,"Guardrail",Vector3(0.12,0.18,a.distance_to(b)+0.1),(a+b)*0.5,Color("929b8d"),true,rotation) as StaticBody3D
		rail.collision_layer = 4
		obstacles.append(rail)
		GrayboxGeometry.box(dressing,"RailPost",Vector3(0.11,0.70,0.11),a-Vector3.UP*0.3,Color("5e6b60"))


func spectator_intrusion(point: Vector3) -> bool:
	for region: Dictionary in spectator_regions:
		var a: Vector3 = region.a
		var b: Vector3 = region.b
		var delta := Vector2(b.x-a.x,b.z-a.z)
		var t := clampf(Vector2(point.x-a.x,point.z-a.z).dot(delta)/maxf(delta.length_squared(),0.01),0,1)
		var at := a.lerp(b,t)
		if absf(point.y-at.y)<4 and Vector2(point.x-at.x,point.z-at.z).length()<2.3: return true
	return false


func set_quality(low: bool) -> void:
	for batch: MultiMeshInstance3D in grass_batches: batch.visible = not low
	for batch: MultiMeshInstance3D in all_batches:
		if str(batch.name).begins_with("Aggregate"): batch.visible = not low
		elif not str(batch.name).begins_with("grass"): batch.visibility_range_end = 270 if low else 520
