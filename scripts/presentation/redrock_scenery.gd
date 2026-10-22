class_name RallyRedrockScenery
extends RefCounted

# Redrock Canyon dressing. Geometry is faceted (flat-shaded) and uses the
# screenprint sandstone shader so cliffs match the vehicles and older props.
# All solid pieces stay outside the recoverable driving corridor.

const CANYON := Vector2(110,890)
const RIVERBED := Vector2(2250,2990)
const ARCH_S := 2740.0

static func rock_material() -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader=preload("res://assets/shaders/redrock.gdshader")
	return material


static func build(scene: RallyStageScenery) -> void:
	var route := scene.route
	var root := scene.dressing
	var rng := RandomNumberGenerator.new()
	rng.seed=86204
	var rock := rock_material()
	if route.length<1000:
		if scene.generator.definition.stage_id=="redrock_sample":
			for s: int in range(0,90,25):
				for side: float in [-1,1]: _tower(root,scene.ground_at(s,side*15),Vector3(15,30,22),rock,rng)
		else:
			for s: int in range(160,230,10):
				for side: float in [-1,1]: GrayboxGeometry.box(root,"BrakeMarker",Vector3(.35,.6,.35),scene.ground_at(s,side*5)+Vector3.UP*.3,Color("e26935"))
		return
	var noise := FastNoiseLite.new()
	noise.seed=86206
	noise.frequency=1.0
	# Stepped canyon walls: talus, lower cliff, ledge, upper cliff, rim, back slope.
	_walls(scene,"CanyonWalls",CANYON,rock,noise,func(s: float,n: float,m: float) -> PackedVector2Array:
		var taper := smoothstep(CANYON.x,CANYON.x+80,s)*(1-smoothstep(CANYON.y-110,CANYON.y,s))
		var h1 := (7+6*n)*taper+1.5
		var h2 := h1+(9+16*m)*taper
		return PackedVector2Array([Vector2(-4,-3),Vector2(0,2.2),Vector2(.8,h1),Vector2(4.6,h1+.5),Vector2(5.6,h2),Vector2(26,h2+1.2),Vector2(52,-12)]),10.0)
	# Dry-river banks: low two-step ledges so the gravel reads as a channel.
	_walls(scene,"DryRiverbedBanks",RIVERBED,rock,noise,func(s: float,n: float,m: float) -> PackedVector2Array:
		var taper := smoothstep(RIVERBED.x,RIVERBED.x+60,s)*(1-smoothstep(RIVERBED.y-60,RIVERBED.y,s))*(smoothstep(30,70,absf(s-ARCH_S)))
		if taper<.05: return PackedVector2Array()
		var h1 := (2.5+2.5*n)*taper+.4
		var h2 := h1+(1.5+3.5*m)*taper
		return PackedVector2Array([Vector2(-3,-3),Vector2(0,1.0),Vector2(.6,h1),Vector2(3.4,h1+.3),Vector2(4.2,h2),Vector2(10,h2+.2),Vector2(17,-6)]),8.0)
	_arch(scene,rock,rng)
	# Mid-distance hoodoos and buttes along the dune section.
	var hoodoos := Node3D.new()
	hoodoos.name="DuneHoodoos"
	root.add_child(hoodoos)
	var hoodoo_batch := RockBatch.new()
	for i: int in range(34):
		var s := rng.randf_range(CANYON.y+40,RIVERBED.x-20)
		var side := -1.0 if rng.randf()<.5 else 1.0
		var at := scene.ground_at(s,side*rng.randf_range(40,150))
		if float(scene.nearest(at).distance)<34: continue
		var width := rng.randf_range(9,26)
		hoodoo_batch.add(at-Vector3.UP*(2+width*.12),Vector3(width,rng.randf_range(14,42),width*rng.randf_range(.7,1.3)),rng.randf_range(-PI,PI),rng.randi_range(2,3),rng.randi())
	hoodoo_batch.finish(hoodoos,"Hoodoos",rock,true)
	# Distant flat-top buttes framing every section, then two horizon rings.
	var buttes := Node3D.new()
	buttes.name="DistantButtes"
	root.add_child(buttes)
	var butte_batch := RockBatch.new()
	for i: int in range(26):
		var s := 120.0+float(i)/25*(route.length-240)
		var side := -1.0 if i%2==0 else 1.0
		var at := scene.ground_at(s,side*rng.randf_range(190,420))
		var nearest:=scene.nearest(at)
		if float(nearest.distance)<95: continue
		var span := Vector3(rng.randf_range(90,200),rng.randf_range(32,70),rng.randf_range(70,170))
		var sink := 6.0
		for corner: Vector2 in [Vector2(-.5,-.5),Vector2(.5,-.5),Vector2(-.5,.5),Vector2(.5,.5)]:
			sink=maxf(sink,at.y-scene.rendered_height_at(at.x+corner.x*span.x,at.z+corner.y*span.z)+4)
		butte_batch.add(at-Vector3.UP*sink,span+Vector3.UP*sink,rng.randf_range(-PI,PI),2,rng.randi())
	# Distant buttes sit beyond the 170 m shadow range; skip the shadow pass.
	butte_batch.finish(buttes,"Buttes",rock,false)
	_horizon(scene)
	_plants(scene,rng)
	_boulders(scene,rock,rng)
	_mining_station(scene)
	_windpump(scene,route.length*.40)
	RallyDesertLandmarks.build(scene,rock)
	for node: Node in scene.generator.get_children():
		if node.get_meta("prototype_marker",false): node.visible=false


# Faceted, tiered butte. The last triangles are the upward-facing cap.
static func _rock(parent: Node3D,at: Vector3,size: Vector3,material: Material,tiers: int = 2,seed_value: int = -1) -> MeshInstance3D:
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	_rock_into(tool,Transform3D.IDENTITY,tiers,seed_value if seed_value>=0 else int(absf(at.x*13.1+at.z*7.3))+tiers)
	tool.generate_normals()
	var mesh := MeshInstance3D.new()
	mesh.mesh=tool.commit()
	mesh.position=at
	mesh.scale=size
	mesh.material_override=material
	parent.add_child(mesh)
	return mesh


static func _rock_into(tool: SurfaceTool,transform: Transform3D,tiers: int,seed_value: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value
	var sides := rng.randi_range(7,9)
	var jitter: Array[float] = []
	for j: int in range(sides): jitter.append(rng.randf_range(.78,1.0))
	var y := -.5
	var radius := .5
	var offset := Vector2.ZERO
	var previous_top: Array[Vector3] = []
	var taper := rng.randf_range(.78,.95)
	# Closed underside: tilted placements must never reveal a hollow interior.
	for j: int in range(sides):
		var a0 := j*TAU/sides
		var a1 := ((j+1)%sides)*TAU/sides
		_add_t(tool,transform,[Vector3(0,-.5,0),Vector3(cos(a1)*radius*jitter[(j+1)%sides],-.5,sin(a1)*radius*jitter[(j+1)%sides]),Vector3(cos(a0)*radius*jitter[j],-.5,sin(a0)*radius*jitter[j])])
	for tier: int in range(tiers):
		var height := 1.0/tiers*(1.15 if tier==0 else .925)
		var bottom: Array[Vector3] = []
		var top: Array[Vector3] = []
		for j: int in range(sides):
			var angle := j*TAU/sides
			var r := radius*jitter[(j+tier*3)%sides]
			bottom.append(Vector3(offset.x+cos(angle)*r,y,offset.y+sin(angle)*r))
			top.append(Vector3(offset.x+cos(angle)*r*taper,minf(y+height,.5),offset.y+sin(angle)*r*taper))
		if not previous_top.is_empty():
			for j: int in range(sides):
				var k := (j+1)%sides
				_add_t(tool,transform,[previous_top[j],previous_top[k],bottom[j],bottom[j],previous_top[k],bottom[k]])
		for j: int in range(sides):
			var k := (j+1)%sides
			_add_t(tool,transform,[bottom[j],bottom[k],top[j],top[j],bottom[k],top[k]])
		previous_top=top
		radius*=rng.randf_range(.62,.8)
		offset+=Vector2(rng.randf_range(-.08,.08),rng.randf_range(-.08,.08))
		y=top[0].y
	var cap_center := Vector3.ZERO
	for point: Vector3 in previous_top: cap_center+=point
	cap_center/=previous_top.size()
	for j: int in range(sides):
		_add_t(tool,transform,[cap_center,previous_top[j],previous_top[(j+1)%sides]])


static func _add_t(tool: SurfaceTool,transform: Transform3D,vertices: Array) -> void:
	for vertex: Vector3 in vertices: tool.add_vertex(transform*vertex)


# Many rocks merged into one draw call per group.
class RockBatch:
	var tool := SurfaceTool.new()
	var count := 0
	func _init() -> void:
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_smooth_group(-1)
	func add(base: Vector3,size: Vector3,yaw: float,tiers: int,seed_value: int) -> void:
		RallyRedrockScenery._rock_into(tool,Transform3D(Basis(Vector3.UP,yaw).scaled(size),base+Vector3.UP*size.y*.5),tiers,seed_value)
		count+=1
	func finish(parent: Node3D,title: String,material: Material,shadows: bool,visibility: float = 0) -> MeshInstance3D:
		if count==0: return null
		tool.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name=title
		mesh.mesh=tool.commit()
		mesh.material_override=material
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.visibility_range_end=visibility
		parent.add_child(mesh)
		return mesh


static func _tower(parent: Node3D,base: Vector3,size: Vector3,material: Material,rng: RandomNumberGenerator,tiers: int = -1) -> MeshInstance3D:
	var mesh:=_rock(parent,base+Vector3.UP*size.y*.5,size,material,tiers if tiers>0 else rng.randi_range(2,3),rng.randi())
	mesh.rotation.y=rng.randf_range(-PI,PI)
	return mesh


static func _add(tool: SurfaceTool,vertices: Array) -> void:
	for vertex: Vector3 in vertices: tool.add_vertex(vertex)


static func _tri(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,facing: Vector3) -> void:
	# Godot's generated normal is (c-a)x(b-a); orient each face explicitly.
	if (c-a).cross(b-a).dot(facing)<0: _add(tool,[a,c,b])
	else: _add(tool,[a,b,c])


static func _walls(scene: RallyStageScenery,title: String,span: Vector2,material: Material,noise: FastNoiseLite,profile_at: Callable,clearance: float) -> void:
	var route := scene.route
	var node := Node3D.new()
	node.name=title
	scene.dressing.add_child(node)
	var faces := PackedVector3Array()
	for side: float in [-1,1]:
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_smooth_group(-1)
		var previous: Array = []
		var s := span.x
		while s<=span.y:
			var row := _wall_row(scene,s,side,noise,profile_at,clearance)
			# Close every run of rows with a fan so ends and gaps never show a hollow shell.
			if previous.is_empty() and not row.is_empty(): _cap(tool,row,-route.tangent_at(s))
			if not previous.is_empty() and row.is_empty(): _cap(tool,previous,route.tangent_at(s))
			if not previous.is_empty() and not row.is_empty():
				var right: Vector3=route.rights[route.index_at(s)]*side
				for k: int in range(row.size()-1):
					var a: Vector3=previous[k]
					var b: Vector3=previous[k+1]
					var c: Vector3=row[k]
					var d: Vector3=row[k+1]
					var along := Vector2((b-a).dot(right),b.y-a.y)
					var facing := -right*along.y+Vector3.UP*along.x
					_tri(tool,a,c,b,facing)
					_tri(tool,b,c,d,facing)
					for vertex: Vector3 in [a,c,b,b,c,d]: faces.append(vertex)
			previous=row
			s+=5.0
		if not previous.is_empty(): _cap(tool,previous,route.tangent_at(span.y))
		tool.generate_normals()
		var mesh := MeshInstance3D.new()
		mesh.name="Side%d"%int(side)
		mesh.mesh=tool.commit()
		mesh.material_override=material
		# Self-shadowing comes from the stepped light bands; the sun still lights the road.
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(mesh)
	if faces.is_empty(): return
	var body := StaticBody3D.new()
	body.name="WallCollision"
	body.collision_layer=4
	body.collision_mask=2
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(faces)
	var collider := CollisionShape3D.new()
	collider.shape=shape
	body.add_child(collider)
	node.add_child(body)
	scene.obstacles.append(body)


static func _cap(tool: SurfaceTool,row: Array,facing: Vector3) -> void:
	var low_a: Vector3=row[0]
	var low_b: Vector3=row[-1]
	var floor_y := minf(low_a.y,low_b.y)
	var anchor: Vector3=(low_a+low_b)*.5
	anchor.y=floor_y
	for k: int in range(row.size()-1): _tri(tool,anchor,row[k],row[k+1],facing)


static func _wall_row(scene: RallyStageScenery,s: float,side: float,noise: FastNoiseLite,profile_at: Callable,clearance: float) -> Array:
	var route := scene.route
	var half := route.width_at(s)*.5
	# Open the inside of bends so the next corner stays readable.
	var turn := route.tangent_at(s-25).signed_angle_to(route.tangent_at(s+25),Vector3.UP)
	var inside := 1.0 if signf(turn)==-side else 0.0
	var base := half+clearance+inside*clampf(absf(turn)*26,0,22)+noise.get_noise_1d(s*.013+side*40)*2.5
	var n := clampf(noise.get_noise_1d(s*.02+side*90)*.8+.5,0,1)
	var m := clampf(noise.get_noise_1d(s*.045+side*17)*.6+noise.get_noise_1d(s*.19+side*5)*.4+.5,0,1)
	var profile: PackedVector2Array=profile_at.call(s,n,m)
	if profile.is_empty(): return []
	var origin := route.position_at(s)
	var right: Vector3=route.rights[route.index_at(s)]*side
	right.y=0
	right=right.normalized()
	var foot := origin+right*base
	var ground := scene.rendered_height_at(foot.x,foot.z)
	var row: Array = []
	for k: int in range(profile.size()):
		var lateral := base+profile[k].x
		var at := origin+right*lateral
		var near := scene.nearest(at)
		if float(near.distance)<half+clearance-4.5:
			if k<5: return []
			# Rim and back slope fold back instead of reaching another road branch.
			at=row[k-1]+right*.5
			# The last fold point still drops below ground so the back slope stays closed.
			at.y=row[k-1].y if k<profile.size()-1 else scene.rendered_height_at(at.x,at.z)+profile[k].y
			row.append(at)
			continue
		if k==0 or k==profile.size()-1: at.y=scene.rendered_height_at(at.x,at.z)+profile[k].y
		else: at.y=ground+profile[k].y
		row.append(at)
	return row


static func _arch(scene: RallyStageScenery,material: Material,rng: RandomNumberGenerator) -> void:
	var route := scene.route
	var pose := route.pose_at(minf(ARCH_S,route.length*.76),0)
	var arch := Node3D.new()
	arch.name="MonumentalStoneArch"
	arch.transform=pose
	scene.dressing.add_child(arch)
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	tool.set_smooth_group(-1)
	var segments := 30
	var sides := 8
	var rings: Array = []
	var jitter := RandomNumberGenerator.new()
	jitter.seed=27401
	for i: int in range(segments+1):
		var theta := lerpf(-.16,PI+.16,float(i)/segments)
		var center := Vector3(cos(theta)*16.5,-2+sin(theta)*30,0)
		var tangent := Vector3(-sin(theta)*16.5,cos(theta)*30,0).normalized()
		var normal := tangent.cross(Vector3.BACK).normalized()
		var lift := clampf(sin(theta),0,1)
		var thickness := lerpf(8.0,4.6,pow(lift,1.6))
		var depth := lerpf(9.0,6.4,lift)
		var ring: Array[Vector3] = []
		for j: int in range(sides):
			var phi := j*TAU/sides
			var wobble := .94+.08*sin(phi*3.0+i*.45)+.04*sin(i*1.7+j)
			ring.append(center+normal*cos(phi)*thickness*wobble+Vector3.BACK*sin(phi)*depth*wobble)
		rings.append(ring)
	for i: int in range(segments):
		var center: Vector3=(rings[i][0]+rings[i][4])*.5
		for j: int in range(sides):
			var k := (j+1)%sides
			var a: Vector3=rings[i][j]
			var b: Vector3=rings[i][k]
			var c: Vector3=rings[i+1][j]
			var d: Vector3=rings[i+1][k]
			_tri(tool,a,b,c,a-center)
			_tri(tool,c,b,d,c-center)
	tool.generate_normals()
	var span := MeshInstance3D.new()
	span.name="ArchSpan"
	span.mesh=tool.commit()
	span.material_override=material
	arch.add_child(span)
	var body := StaticBody3D.new()
	body.name="ArchCollision"
	body.collision_layer=4
	body.collision_mask=2
	var collider := CollisionShape3D.new()
	collider.shape=span.mesh.create_trimesh_shape()
	body.add_child(collider)
	for side: float in [-1,1]:
		var foot := _rock(arch,Vector3(side*18.5,7,0),Vector3(15,22,17),material,3,int(side+5))
		foot.name="ArchFoot"
		var shape := CylinderShape3D.new()
		shape.radius=6.2
		shape.height=22
		var solid := CollisionShape3D.new()
		solid.shape=shape
		solid.position=Vector3(side*18.5,7,0)
		body.add_child(solid)
	arch.add_child(body)
	scene.obstacles.append(body)


static func _horizon(scene: RallyStageScenery) -> void:
	var route := scene.route
	var lowest := route.points[0].y
	for point: Vector3 in route.points: lowest=minf(lowest,point.y)
	var floor_mesh := PlaneMesh.new()
	floor_mesh.size=Vector2(12000,12000)
	var floor := MeshInstance3D.new()
	floor.name="DesertFloor"
	floor.mesh=floor_mesh
	floor.position=Vector3(scene.center.x,lowest-34,scene.center.z)
	floor.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# Only seen beyond the terrain edge; a flat sand ink avoids a full-screen ground shader pass.
	var flat := StandardMaterial3D.new()
	flat.albedo_color=Color("d9a46a")
	flat.roughness=1
	flat.specular_mode=BaseMaterial3D.SPECULAR_DISABLED
	floor.material_override=flat
	scene.dressing.add_child(floor)
	var reach := scene.bounds.size.length()*.5+700
	var noise := FastNoiseLite.new()
	noise.seed=4417
	for layer: int in range(2):
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		tool.set_smooth_group(-1)
		var count := 160
		var radius := reach+layer*900.0
		var heights: Array[float] = []
		for i: int in range(count):
			var plateau := smoothstep(-.02,.06,noise.get_noise_1d(i*.16+layer*50))
			heights.append(lowest+lerpf(10,120+layer*110,plateau)+noise.get_noise_1d(i*.9+layer*7)*10)
		for i: int in range(count):
			var k := (i+1)%count
			var a0 := TAU*i/count
			var a1 := TAU*k/count
			var outward_a := Vector3(cos(a0),0,sin(a0))
			var outward_b := Vector3(cos(a1),0,sin(a1))
			var base_a := scene.center+outward_a*radius
			var base_b := scene.center+outward_b*radius
			base_a.y=lowest-60
			base_b.y=lowest-60
			var top_a := scene.center+outward_a*(radius+40)
			var top_b := scene.center+outward_b*(radius+40)
			top_a.y=heights[i]
			top_b.y=heights[k]
			var back_a := scene.center+outward_a*(radius+420)
			var back_b := scene.center+outward_b*(radius+420)
			back_a.y=heights[i]
			back_b.y=heights[k]
			_tri(tool,base_a,base_b,top_a,-outward_a)
			_tri(tool,top_a,base_b,top_b,-outward_a)
			_tri(tool,top_a,top_b,back_a,Vector3.UP)
			_tri(tool,back_a,top_b,back_b,Vector3.UP)
		tool.generate_normals()
		var ring := MeshInstance3D.new()
		ring.name="MesaHorizon%d"%layer
		ring.mesh=tool.commit()
		ring.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var painted := ShaderMaterial.new()
		painted.shader=preload("res://assets/shaders/anime_mountain.gdshader")
		painted.set_shader_parameter("rock_albedo",preload("res://assets/brushline/mountain-rock.png"))
		painted.set_shader_parameter("rock_scale",.012)
		painted.set_shader_parameter("rock_strength",.30)
		painted.set_shader_parameter("layer",0.0)
		painted.set_shader_parameter("shade_color",Color("b36a55") if layer==0 else Color("c48f7c"))
		painted.set_shader_parameter("lit_color",Color("f2a36a") if layer==0 else Color("f1c19a"))
		ring.material_override=painted
		scene.dressing.add_child(ring)


static func _yucca(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value
	var b := RallySampleMeshes.new()
	var trunk := rng.randf_range(.5,1.4)
	b.cone(.13,.10,trunk,Vector3(0,trunk*.5,0),Color("6b5541"),5)
	for i: int in range(22):
		var angle := rng.randf()*TAU
		var lean := rng.randf_range(.15,1.0)
		var tip := Vector3(cos(angle)*lean,1.05-lean*.35,sin(angle)*lean)*rng.randf_range(.75,1.05)+Vector3.UP*trunk
		var across := Vector3(-sin(angle),0,cos(angle))*.06
		b.triangle(Vector3.UP*trunk-across,Vector3.UP*trunk+across,tip,Color("5f9a50").darkened(rng.randf_range(0,.25)))
	return b.finish()


static func _ocotillo(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value
	var b := RallySampleMeshes.new()
	for i: int in range(9):
		var angle := rng.randf()*TAU
		var tip := Vector3(cos(angle)*rng.randf_range(.4,1.1),rng.randf_range(2.2,3.4),sin(angle)*rng.randf_range(.4,1.1))
		b.beam(Vector3.ZERO,tip,.05,Color("6a6a48"))
		b.cone(.09,.0,.38,tip+Vector3.UP*.15,Color("d8513a"),5)
	return b.finish()


static func _plants(scene: RallyStageScenery,rng: RandomNumberGenerator) -> void:
	var route := scene.route
	var kinds := {"yucca":[_yucca(3),_yucca(8),_yucca(21)],"ocotillo":[_ocotillo(4),_ocotillo(9)]}
	var batches := {}
	var s := 20.0
	while s<route.length-40:
		s+=rng.randf_range(4,11)
		var side := -1.0 if rng.randf()<.5 else 1.0
		var at := scene.ground_at(s,side*rng.randf_range(5.5,34))
		if not scene.allows_decoration(at,"shrub",1.0) or scene.spectator_intrusion(at): continue
		var kind := "yucca" if rng.randf()<.7 else "ocotillo"
		var variant := rng.randi_range(0,kinds[kind].size()-1)
		var key := "%s%d_%d"%[kind,variant,int(s/400)]
		if not batches.has(key): batches[key]={"mesh":kinds[kind][variant],"transforms":[]}
		var size := rng.randf_range(.75,1.5)
		batches[key].transforms.append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*size),at))
	for key: String in batches:
		var transforms: Array=batches[key].transforms
		var center := Vector3.ZERO
		for transform: Transform3D in transforms: center+=transform.origin
		center/=transforms.size()
		var multimesh := MultiMesh.new()
		multimesh.transform_format=MultiMesh.TRANSFORM_3D
		multimesh.mesh=batches[key].mesh
		multimesh.instance_count=transforms.size()
		for i: int in range(transforms.size()):
			var local: Transform3D=transforms[i]
			local.origin-=center
			multimesh.set_instance_transform(i,local)
		var instance := MultiMeshInstance3D.new()
		instance.name="DesertPlants_"+key
		instance.multimesh=multimesh
		instance.position=center
		instance.visibility_range_end=230
		instance.visibility_range_end_margin=20
		instance.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		scene.dressing.add_child(instance)


static func _boulders(scene: RallyStageScenery,material: Material,rng: RandomNumberGenerator) -> void:
	var node := Node3D.new()
	node.name="RedBoulders"
	scene.dressing.add_child(node)
	var batches: Dictionary = {}
	var s := 60.0
	while s<scene.route.length-60:
		s+=rng.randf_range(18,42)
		var side := -1.0 if rng.randf()<.5 else 1.0
		var lateral := side*rng.randf_range(13,30)
		var at := scene.ground_at(s,lateral)
		if float(scene.nearest(at).distance)<12 or scene.spectator_intrusion(at): continue
		var size := rng.randf_range(1.6,4.2)
		var chunk := int(s/450)
		if not batches.has(chunk): batches[chunk]=RockBatch.new()
		(batches[chunk] as RockBatch).add(at-Vector3.UP*size*.25,Vector3(size*rng.randf_range(1,1.6),size,size*rng.randf_range(.9,1.4)),rng.randf_range(-PI,PI),1,rng.randi())
	for chunk: int in batches: (batches[chunk] as RockBatch).finish(node,"Boulders%d"%chunk,material,false,420)


static func _mining_station(scene: RallyStageScenery) -> void:
	var service := Node3D.new()
	service.name="MiningServiceStation"
	service.transform=scene.route.pose_at(65,0)
	scene.dressing.add_child(service)
	var b := RallySampleMeshes.new()
	# Timber headframe with sheave wheel, ore hopper, shed, tank and drums.
	for x: float in [-16,-10]:
		b.beam(Vector3(x,0,6),Vector3(-13,11,4),.24,Color("7a5a3f"))
		b.beam(Vector3(x,0,2),Vector3(-13,11,4),.24,Color("6c4f37"))
	b.box(Vector3(5,.4,.4),Vector3(-13,8,4),Color("8a6747"))
	b.cone(1.5,1.5,.3,Vector3(-13,11.4,4),Color("3f4a4c"),12)
	b.box(Vector3(4.5,3.2,4),Vector3(-13,4.4,-3.5),Color("b34d2d"))
	b.cone(2.2,.6,2.2,Vector3(-13,1.9,-3.5),Color("7a3a24"),6)
	b.box(Vector3(7,4,6),Vector3(-21,2,-3),Color("6d7c78"))
	b.box(Vector3(7.6,.25,6.8),Vector3(-21,4.15,-3),Color("c7b48c"),Vector3(0,0,.08))
	b.box(Vector3(1.4,2.4,.1),Vector3(-19,1.2,.05),Color("2f3b3d"))
	b.cone(1.6,1.6,3.2,Vector3(-23,5.4,4),Color("d6c7a3"),10)
	for leg: Vector2 in [Vector2(-24.2,2.8),Vector2(-21.8,2.8),Vector2(-24.2,5.2),Vector2(-21.8,5.2)]:
		b.beam(Vector3(leg.x,0,leg.y),Vector3(leg.x,3.8,leg.y),.1,Color("5e4a3a"))
	for i: int in range(5):
		b.cone(.35,.35,.9,Vector3(-10.5-i*.8,.45,-6.5+(i%2)*.7),[Color("d9a23c"),Color("3f7a7c"),Color("c4552f")][i%3],8)
	b.box(Vector3(2.2,1.0,1.4),Vector3(-9.5,.8,-1),Color("4a4f4b"))
	for x: float in [-10.2,-8.8]: b.cone(.32,.32,.2,Vector3(x,.32,-1),Color("262a2a"),8)
	RallyStageLandmarks._mesh(service,b,true)


static func _windpump(scene: RallyStageScenery,s: float) -> void:
	var node := Node3D.new()
	node.name="DesertWindpump"
	node.position=scene.ground_at(s,-34)
	node.rotation.y=scene.route.pose_at(s).basis.get_euler().y
	scene.dressing.add_child(node)
	var b := RallySampleMeshes.new()
	for corner: Vector2 in [Vector2(-1.4,-1.4),Vector2(1.4,-1.4),Vector2(-1.4,1.4),Vector2(1.4,1.4)]:
		b.beam(Vector3(corner.x,0,corner.y),Vector3(corner.x*.18,11,corner.y*.18),.09,Color("8b9290"))
	for y: float in [3.5,7]:
		var w := 1.4*(1-y/11*.82)
		for edge: Array in [[Vector3(-w,y,-w),Vector3(w,y,-w)],[Vector3(w,y,-w),Vector3(w,y,w)],[Vector3(w,y,w),Vector3(-w,y,w)],[Vector3(-w,y,w),Vector3(-w,y,-w)]]:
			b.beam(edge[0],edge[1],.05,Color("8b9290"))
	for i: int in range(14):
		var angle := i*TAU/14
		b.box(Vector3(.5,2.3,.06),Vector3(cos(angle)*1.6,11.6+sin(angle)*1.6,-.6),Color("e8e2d0") if i%2 else Color("c2493a"),Vector3(0,0,angle-PI/2))
	b.box(Vector3(.12,.9,3.2),Vector3(0,11.6,1.6),Color("c2493a"))
	b.cone(3.2,3.2,2.4,Vector3(6,1.2,2),Color("7c8783"),14)
	b.cone(3.3,3.3,.2,Vector3(6,2.45,2),Color("a8b1ab"),14)
	# Stock fence runs parallel to the road, well beyond the shoulder.
	for i: int in range(12):
		var at := Vector3(-6,0,-22+i*4)
		b.beam(at,at+Vector3.UP*1.3,.07,Color("6b5541"))
		if i>0:
			for y: float in [.6,1.1]: b.beam(at+Vector3(0,y,-4),at+Vector3(0,y,0),.02,Color("9a9488"))
	RallyStageLandmarks._mesh(node,b,true)
