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
var sailboats: Array[Dictionary] = []
var river_frames: Array[Dictionary] = []
var utility_line := RallyUtilityLine.new()


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
	for river: Vector3 in generator.definition.river_crossings:
		var pose := route.pose_at(river.x,0)
		river_frames.append({"origin":pose.origin,"right":pose.basis.x,"forward":-pose.basis.z,"span":river.y})
	_apply_materials()
	_build_terrain()
	_build_mountains()
	utility_line.plan(self)
	foliage.biome = generator.definition.environment_id
	foliage.spectator_stations.assign(generator.definition.spectators)
	foliage.build_range(self,12,route.length-35,0.58)
	for station: float in foliage.spectator_stations:
		spectator_zones.append(ground_at(station+5,8))
		spectator_regions.append({"a":ground_at(station-1,8),"b":ground_at(station+13,8)})
	_build_landmarks()
	RallyStageLandmarks.build(self)
	RallyRiverBridges.build(self)
	utility_line.build(self)
	_build_obstacles()
	_build_guardrails()
	_build_gravel()
	for node: Node in dressing.get_children():
		if node is MultiMeshInstance3D:
			all_batches.append(node)
			if str(node.name).begins_with("grass"): grass_batches.append(node)
	for child: Node in generator.get_children():
		if child.get_meta("prototype_marker", false): child.visible = false


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
	if generator.definition.environment_id=="coast" and float(p.lateral)<0:
		far = lerpf(p.point.y-12,-40,smoothstep(25,180,d))
	var clearance := lerpf(2.5,.35,smoothstep(6,18,d))
	var height := lerpf(close-clearance,far,smoothstep(21,110,d))
	# Carve an actual sandy bay beneath the final overlook, so the beach props
	# cannot be buried by the generic cliff/noise terrain.
	if generator.definition.environment_id=="coast" and float(p.s)>route.length-160 and float(p.lateral)<-25:
		var bay := smoothstep(route.length-160,route.length-90,float(p.s))*smoothstep(25,38,-float(p.lateral))
		var beach_height := lerpf(-24.4,-40,smoothstep(85,130,-float(p.lateral)))
		height = lerpf(height,beach_height,bay)
	var end := route.points[-1]
	var forward := route.tangents[-1]
	forward.y = 0
	forward = forward.normalized()
	var beyond := Vector3(x-end.x,0,z-end.z).dot(forward)
	if generator.definition.environment_id=="coast" and beyond>110:
		height = lerpf(height,-40,smoothstep(110,230,beyond))
	if generator.definition.environment_id=="highland" and float(p.s)>route.length-200:
		var drop := smoothstep(route.length-200,route.length-80,float(p.s))*smoothstep(32,180,d)
		height = lerpf(height,p.point.y-130+terrain_noise.get_noise_2d(x,z)*35,drop)
	for river: Dictionary in river_frames:
		var origin: Vector3 = river.origin
		var delta := Vector3(x,origin.y,z)-origin
		var across := delta.dot(river.right)
		var along := delta.dot(river.forward)
		if absf(across)>125: continue
		var meander := sin(across*.04)*2+sin(across*.11)*.6
		var half_channel: float = river.span*.45+sin(across*.07)*1.2
		var channel := (1-smoothstep(half_channel,half_channel+7,absf(along-meander)))*(1-smoothstep(100,125,absf(across)))
		var bed := origin.y-4.1-across*.006
		height = lerpf(height,minf(height,bed),channel)
	return height


func ground_at(s: float,lateral: float) -> Vector3:
	var at := route.position_at(s)+route.rights[route.index_at(s)]*lateral
	if absf(lateral) < 21:
		var d := absf(lateral)-route.width_at(s)*0.5
		at.y -= minf(maxf(d,0)*0.18,2.3)
		at.y += smoothstep(1.5,10,d)*0.5*sin(s*0.03+lateral*0.2)
	else: at.y = height_at(at.x,at.z)
	return at


func allows_decoration(point: Vector3, kind: String, scale_factor: float) -> bool:
	if kind in ["pine","umbrella","rock"] and not utility_line.allows_tree(point): return false
	var p := nearest(point)
	for river: Vector3 in generator.definition.river_crossings:
		if absf(float(p.s)-river.x)<river.y*.5+10 and absf(float(p.lateral))<125: return false
	if absf(float(p.s)-route.length*.51)<22 and float(p.lateral)>5 and float(p.lateral)<19: return false
	if float(p.s)>route.length-140 and kind in ["pine","umbrella","rock"]: return false
	if float(p.s)>route.length-75 and float(p.lateral)<-7 and float(p.lateral)>-100: return false
	if generator.definition.environment_id=="coast" and (point.y < -18 or (float(p.lateral)<-18 and kind in ["pine","umbrella"])): return false
	for note: Dictionary in generator.definition.hazard_notes:
		if note.code=="CUT" and absf(float(p.s)-float(note.s))<40 and float(p.distance)<route.width_at(p.s)*.5+1.2: return false
	for landmark: Dictionary in generator.definition.landmarks:
		if point.distance_to(ground_at(landmark.s,landmark.side*18))<12: return false
	var radius := 2.8*scale_factor if kind in ["pine","umbrella"] else (1.4*scale_factor if kind == "rock" else 0.25)
	if kind in ["pine","umbrella","rock"]:
		for station: float in foliage.spectator_stations:
			if point.distance_to(ground_at(station+5,8)) < 8+radius: return false
	return float(p.distance) > route.width_at(p.s)*0.5+radius+0.15


func _apply_materials() -> void:
	var ground := ShaderMaterial.new()
	ground.shader = preload("res://assets/shaders/stage_ground.gdshader")
	ground.set_shader_parameter("road_mesh",true)
	_theme_ground(ground)
	for mesh: MeshInstance3D in generator.road_visuals: mesh.material_override = ground
	var water := ShaderMaterial.new()
	water.shader = preload("res://assets/shaders/stage_water.gdshader")
	for mesh: MeshInstance3D in generator.water_visuals: mesh.material_override = water


func _build_terrain() -> void:
	var start := Vector2(bounds.position.x-400,bounds.position.z-400)
	var extent := Vector2(bounds.size.x+800,bounds.size.z+800)
	var count := Vector2i(ceili(extent.x/8),ceili(extent.y/8))
	var vertices := PackedVector3Array()
	for z: int in range(count.y+1):
		for x: int in range(count.x+1):
			var px := start.x+x*8
			var pz := start.y+z*8
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
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/stage_ground.gdshader")
	_theme_ground(material)
	mesh.material_override = material
	dressing.add_child(mesh)


func _build_mountains() -> void:
	if generator.definition.environment_id=="coast":
		var sea := MeshInstance3D.new()
		sea.name = "CoastalOcean"
		var plane := PlaneMesh.new()
		plane.size = Vector2(14000,14000)
		sea.mesh = plane
		sea.position = center
		sea.position.y = -25
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/coastal_ocean.gdshader")
		sea.material_override = material
		dressing.add_child(sea)
		return
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
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif str(child.name) == "DistantValleyFloor":
			child.scale = Vector3(1.5,1,1.5)
			# The background floor must never intersect a lower section of the route.
			var minimum := route.points[0].y
			for point: Vector3 in route.points: minimum = minf(minimum,point.y)
			child.position.y = minimum-100
			child.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sample.dressing = null
	sample.free()


func _build_obstacles() -> void:
	var body := StaticBody3D.new()
	body.name = "CombinedSceneryObstacles"
	body.collision_layer = 4
	body.collision_mask = 2
	for placement: Dictionary in foliage.placements:
		var tree: bool = placement.kind in ["pine","umbrella"]
		var rock: bool = placement.kind=="rock" and placement.scale>0.8 and absf(placement.lateral)<11
		if (not tree and not rock) or absf(placement.lateral) > 14: continue
		var collision := CollisionShape3D.new()
		if tree:
			var cylinder := CylinderShape3D.new()
			cylinder.radius = 0.20*float(placement.scale)
			cylinder.height = 4*float(placement.scale)
			collision.position = placement.point+Vector3.UP*cylinder.height*0.5
			collision.shape = cylinder
		else:
			var sphere := SphereShape3D.new()
			sphere.radius = 0.6*float(placement.scale)
			collision.position = placement.point+Vector3.UP*0.4*float(placement.scale)
			collision.shape = sphere
		body.add_child(collision)
	if body.get_child_count()>0:
		add_child(body)
		obstacles.append(body)
	else: body.free()


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
		var center := Vector3.ZERO
		for transform: Transform3D in transforms: center += transform.origin
		if not transforms.is_empty(): center /= transforms.size()
		for i: int in range(transforms.size()):
			var local := transforms[i]
			local.origin -= center
			mm.set_instance_transform(i,local)
		var visual := MultiMeshInstance3D.new()
		visual.name = "Aggregate%d"%start
		visual.position = center
		visual.multimesh = mm
		visual.visibility_range_end = 75*RallySampleDressing.VISIBILITY_SCALE
		visual.visibility_range_end_margin = 12
		visual.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		visual.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		dressing.add_child(visual)
		gravel_batches += 1


func _build_guardrails() -> void:
	var body := StaticBody3D.new()
	body.name = "CombinedGuardrails"
	body.collision_layer = 4
	body.collision_mask = 2
	for section: Vector2 in generator.definition.guardrail_sections:
		for s: int in range(int(section.x),int(section.y),4):
			var angle := route.tangent_at(s).signed_angle_to(route.tangent_at(s+8),Vector3.UP)
			if absf(angle)<0.025: continue
			var lateral := signf(angle)*(route.width_at(s)*0.5+1.1)
			var a := ground_at(s,lateral)+Vector3.UP*0.62
			var b := ground_at(s+4,lateral)+Vector3.UP*0.62
			var rotation := Basis.looking_at((b-a).normalized()).get_euler()*180/PI
			var rail := GrayboxGeometry.box(dressing,"Guardrail",Vector3(0.12,0.18,a.distance_to(b)+0.1),(a+b)*0.5,Color("929b8d"),false,rotation)
			(rail.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(0.12,0.18,a.distance_to(b)+0.1)
			collision.shape = shape
			collision.position = (a+b)*0.5
			collision.rotation_degrees = rotation
			body.add_child(collision)
			var post := GrayboxGeometry.box(dressing,"RailPost",Vector3(0.11,0.70,0.11),a-Vector3.UP*0.3,Color("5e6b60"))
			(post.get_child(0) as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if body.get_child_count()>0:
		add_child(body)
		obstacles.append(body)
	else: body.free()


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
		elif not str(batch.name).begins_with("grass"):
			batch.visibility_range_end = minf(286,RallySampleDressing.default_visibility(str(batch.name))) if low else RallySampleDressing.default_visibility(str(batch.name))


func _theme_ground(material: ShaderMaterial) -> void:
	match generator.definition.environment_id:
		"coast":
			material.set_shader_parameter("grass_dark",Color("a8a785"))
			material.set_shader_parameter("grass_light",Color("ddd8b6"))
		"highland":
			material.set_shader_parameter("grass_dark",Color("737e67"))
			material.set_shader_parameter("grass_light",Color("c4be88"))


func _build_landmarks() -> void:
	for entry: Dictionary in generator.definition.landmarks:
		var root := Node3D.new()
		root.name = entry.kind.capitalize()
		dressing.add_child(root)
		root.position = ground_at(entry.s,entry.side*18)
		root.rotation.y = route.pose_at(entry.s).basis.get_euler().y
		var builder := RallySampleMeshes.new()
		match entry.kind:
			"lighthouse":
				root.add_child(RallyLighthouseBeacon.new())
				builder.cone(3,2.1,20,Vector3(0,10,0),Color("eee3c7"),12)
				builder.cone(2.65,2.4,2,Vector3(0,8,0),Color("c45d3e"),12)
				builder.cone(3.3,3.3,.4,Vector3(0,20,0),Color("4c6966"),12)
				builder.cone(2.0,2.0,3,Vector3(0,21.5,0),Color("a6d2ce"),8)
				builder.cone(3,0,2,Vector3(0,24,0),Color("c45d3e"),8)
				builder.box(Vector3(1.3,2.5,.2),Vector3(0,1.25,2.9),Color("314f51"))
			"stones":
				for i: int in range(7):
					var angle := i*TAU/7
					builder.ellipsoid(Vector3(1.1,2.6+i%2,1.1),Vector3(sin(angle)*5,1.6,cos(angle)*5),Color("7e929c"))
				builder.box(Vector3(3.2,.65,1.5),Vector3(0,.33,0),Color("a2b0ad"))
			_:
				builder.box(Vector3(8,5,6),Vector3(0,2.5,0),Color("a95132"))
				for side: float in [-1,1]:
					builder.box(Vector3(5.1,.25,7),Vector3(side*2,6,0),Color("594e45"),Vector3(0,0,-side*.65))
				builder.box(Vector3(1.6,2.8,.15),Vector3(0,1.4,3.05),Color("e2b26b"))
				for side: float in [-1,1]: builder.box(Vector3(1.4,1.5,.16),Vector3(side*2.4,2.8,3.05),Color("a9c8bc"))
		var mesh := MeshInstance3D.new()
		mesh.mesh = builder.finish()
		root.add_child(mesh)
