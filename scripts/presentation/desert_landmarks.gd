class_name RallyDesertLandmarks
extends RefCounted

# Mid-stage desert set pieces between the canyon exit and the dry riverbed so the
# dune section reads as a sequence of places, not one repeated view. Each piece
# sits outside the driving corridor; only the large props carry collision.

const SPAN := Vector2(930,2230)


static func build(scene: RallyStageScenery,rock: Material) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed=51907
	_saguaros(scene,rng)
	_joshua_trees(scene,rng)
	_salt_pan(scene,1180.0,-1.0)
	_trading_post(scene,1330.0,1.0)
	_nomad_camp(scene,1560.0,-1.0)
	_ghost_tower(scene,1840.0,1.0)
	_rock_garden(scene,rock,rng,2050.0)
	_dust_devils(scene)
	_route_cairns(scene)


static func _root(scene: RallyStageScenery,title: String,s: float,lateral: float) -> Node3D:
	var node := Node3D.new()
	node.name=title
	scene.dressing.add_child(node)
	node.position=scene.ground_at(s,lateral)
	node.position.y-=.15
	node.rotation.y=scene.route.pose_at(s).basis.get_euler().y
	return node


static func _clear(scene: RallyStageScenery,point: Vector3,margin: float) -> bool:
	var near := scene.nearest(point)
	return float(near.distance)>scene.route.width_at(near.s)*.5+margin and not scene.spectator_intrusion(point)


static func _batch(scene: RallyStageScenery,title: String,mesh: Mesh,transforms: Array,visibility: float) -> void:
	# Distance visibility is measured from each batch centre, not each cactus.
	# Keep nearby plants visible and avoid drawing a kilometre-long batch.
	var cells: Dictionary={}
	for transform: Transform3D in transforms:
		var cell := Vector2i(floori(transform.origin.x/120),floori(transform.origin.z/120))
		if not cells.has(cell): cells[cell]=[]
		cells[cell].append(transform)
	for cell: Vector2i in cells:
		_batch_cell(scene,title+"_%d_%d"%[cell.x,cell.y],mesh,cells[cell],visibility)


static func _batch_cell(scene: RallyStageScenery,title: String,mesh: Mesh,transforms: Array,visibility: float) -> void:
	if transforms.is_empty(): return
	var center := Vector3.ZERO
	for transform: Transform3D in transforms: center+=transform.origin
	center/=transforms.size()
	var multimesh := MultiMesh.new()
	multimesh.transform_format=MultiMesh.TRANSFORM_3D
	multimesh.mesh=mesh
	multimesh.instance_count=transforms.size()
	for i: int in range(transforms.size()):
		var local: Transform3D=transforms[i]
		local.origin-=center
		multimesh.set_instance_transform(i,local)
	var instance := MultiMeshInstance3D.new()
	instance.name=title
	instance.multimesh=multimesh
	instance.position=center
	instance.visibility_range_end=visibility
	instance.visibility_range_end_margin=25
	instance.visibility_range_fade_mode=GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	instance.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	scene.dressing.add_child(instance)


static func saguaro_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value
	var b := RallySampleMeshes.new()
	var green := Color("4f8a4a")
	var height := rng.randf_range(4.2,6.2)
	b.cone(.34,.28,height,Vector3(0,height*.5,0),green,8)
	b.ellipsoid(Vector3(.28,.22,.28),Vector3(0,height,0),green.lightened(.08))
	for arm: int in range(rng.randi_range(1,3)):
		var side := -1.0 if arm%2==0 else 1.0
		var angle := rng.randf_range(-.5,.5)+(PI if side<0 else 0.0)
		var out := Vector3(cos(angle),0,sin(angle))
		var base := rng.randf_range(height*.35,height*.6)
		var elbow := out*rng.randf_range(.75,1.05)+Vector3.UP*(base+.25)
		b.beam(Vector3.UP*base,elbow,.24,green)
		var tip := elbow+Vector3.UP*rng.randf_range(1.0,1.9)
		b.beam(elbow,tip,.22,green)
		b.ellipsoid(Vector3(.2,.16,.2),tip,green.lightened(.08))
		# Pale flower crown on some arms keeps the silhouette readable at speed.
		if rng.randf()<.5: b.ellipsoid(Vector3(.12,.07,.12),tip+Vector3.UP*.15,Color("f2e3b6"))
	return b.finish()


static func joshua_mesh(seed_value: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed=seed_value
	var b := RallySampleMeshes.new()
	var bark := Color("7a6650")
	var trunk_top := Vector3(rng.randf_range(-.2,.2),rng.randf_range(2.0,2.8),rng.randf_range(-.2,.2))
	b.beam(Vector3.ZERO,trunk_top,.22,bark)
	for branch: int in range(rng.randi_range(3,5)):
		var angle := branch*TAU/5+rng.randf_range(-.3,.3)
		var tip := trunk_top+Vector3(cos(angle)*rng.randf_range(.7,1.3),rng.randf_range(.5,1.2),sin(angle)*rng.randf_range(.7,1.3))
		b.beam(trunk_top,tip,.14,bark)
		# Spiky leaf pom-pom at each tip.
		for i: int in range(10):
			var spike := Vector3(rng.randf_range(-1,1),rng.randf_range(-.3,1),rng.randf_range(-1,1)).normalized()*.55
			b.triangle(tip-Vector3(.05,0,0),tip+Vector3(.05,0,0),tip+spike,Color("6e8f4c").darkened(rng.randf_range(0,.2)))
			b.triangle(tip-Vector3(0,0,.05),tip+Vector3(0,0,.05),tip+spike,Color("6e8f4c").darkened(rng.randf_range(0,.2)))
	return b.finish()


static func _saguaros(scene: RallyStageScenery,rng: RandomNumberGenerator) -> void:
	var meshes := [saguaro_mesh(11),saguaro_mesh(29),saguaro_mesh(47)]
	var groups := [[],[],[]]
	var s := SPAN.x
	while s<SPAN.y:
		s+=rng.randf_range(14,30)
		var side := -1.0 if rng.randf()<.5 else 1.0
		# Clusters of two to four, some close to the road, some on the dune shoulders.
		var center := rng.randf_range(9,60)
		for i: int in range(rng.randi_range(1,3)):
			var at := scene.ground_at(s+rng.randf_range(-6,6),side*(center+rng.randf_range(-4,6)))
			if not _clear(scene,at,6.5): continue
			var variant := rng.randi_range(0,2)
			groups[variant].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.8,1.25)),at-Vector3.UP*.1))
	for i: int in range(3): _batch(scene,"Saguaros%d"%i,meshes[i],groups[i],420)


static func _joshua_trees(scene: RallyStageScenery,rng: RandomNumberGenerator) -> void:
	var meshes := [joshua_mesh(5),joshua_mesh(17)]
	var groups := [[],[]]
	var s := SPAN.x+60
	while s<SPAN.y:
		s+=rng.randf_range(35,70)
		var side := -1.0 if rng.randf()<.5 else 1.0
		var at := scene.ground_at(s,side*rng.randf_range(12,45))
		if not _clear(scene,at,8): continue
		var variant := rng.randi_range(0,1)
		groups[variant].append(Transform3D(Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3.ONE*rng.randf_range(.9,1.3)),at))
	for i: int in range(2): _batch(scene,"JoshuaTrees%d"%i,meshes[i],groups[i],380)


static func _salt_pan(scene: RallyStageScenery,s: float,side: float) -> void:
	# Dry white playa with hexagonal crack lines, flat on the terrain.
	var node := _root(scene,"SaltPan",s,side*48)
	var b := RallySampleMeshes.new()
	var ground := scene.ground_at(s,side*48)
	for ring: int in range(3):
		var radius := 34.0-ring*9
		b.cone(radius,radius*.98,.12,Vector3(0,.06+ring*.02,0),[Color("e9dfc8"),Color("f2ead6"),Color("f7f1e2")][ring],18)
	var rng := RandomNumberGenerator.new()
	rng.seed=771
	for i: int in range(60):
		var a := Vector3(rng.randf_range(-26,26),.13,rng.randf_range(-26,26))
		if Vector2(a.x,a.z).length()>27: continue
		var b2 := a+Vector3(rng.randf_range(-4,4),0,rng.randf_range(-4,4))
		b.beam(a,b2,.05,Color("cbbd9e"))
	var mesh := MeshInstance3D.new()
	mesh.mesh=b.finish()
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.add_child(mesh)
	# Keep the disc level even where the dune slopes.
	node.position.y=ground.y-.25


static func _trading_post(scene: RallyStageScenery,s: float,side: float) -> void:
	var node := _root(scene,"DesertTradingPost",s,side*21)
	node.scale=Vector3.ONE*1.6
	var b := RallySampleMeshes.new()
	var adobe := Color("d29b6b")
	# Adobe store with flat roof, vigas, porch and a faded sign.
	b.box(Vector3(9,4,7),Vector3(side*4.5,2,0),adobe)
	b.box(Vector3(9.4,.4,7.4),Vector3(side*4.5,4.2,0),adobe.darkened(.12))
	for z: float in [-2.6,-1.3,0,1.3,2.6]: b.beam(Vector3(-side*.1,3.7,z),Vector3(-side*.8,3.6,z),.1,Color("6b5541"))
	b.box(Vector3(.1,1.9,1.2),Vector3(0,.95,1.4),Color("4a3b30"))
	for z: float in [-2.2,2.2]: b.box(Vector3(.1,.8,.9),Vector3(0,2.2,z),Color("2e4c55"))
	b.box(Vector3(2.4,.12,8.2),Vector3(-side*1.2,3.1,0),Color("8a6747"))
	for z: float in [-3.8,3.8]: b.beam(Vector3(-side*2.3,0,z),Vector3(-side*2.3,3.1,z),.08,Color("6b5541"))
	b.box(Vector3(.12,.9,4.6),Vector3(-side*.05,4.9,0),Color("c2493a"))
	b.box(Vector3(.13,.25,4.0),Vector3(-side*.06,4.9,0),Color("f2e3b6"))
	# Fuel pump, barrels, wagon wheel and a parked support pickup.
	b.box(Vector3(.6,1.6,.5),Vector3(-side*3.5,.8,-1),Color("c2493a"))
	b.ellipsoid(Vector3(.25,.25,.08),Vector3(-side*3.5,1.75,-1),Color("f2e3b6"))
	for i: int in range(4): b.cone(.32,.32,.9,Vector3(-side*(3+i%2*.7),.45,2.2+i*.6),[Color("3f7a7c"),Color("d9a23c")][i%2],8)
	b.cone(.7,.7,.08,Vector3(-side*.15,.7,-2.9),Color("6b5541"),12)
	b.box(Vector3(2,1.1,4.2),Vector3(-side*6.5,.95,-1.5),Color("e8e2d0"))
	b.box(Vector3(1.9,.8,1.8),Vector3(-side*6.5,1.9,-2.3),Color("e8e2d0"))
	b.box(Vector3(1.85,.5,.05),Vector3(-side*6.5,2.0,-3.2),Color("2e4c55"))
	for x: float in [-.95,.95]:
		for z: float in [-2.8,-.2]: b.cone(.38,.38,.28,Vector3(-side*6.5+x,.38,z-1.5+1.5),Color("262a2a"),10)
	RallyStageLandmarks._mesh(node,b,true)


static func _nomad_camp(scene: RallyStageScenery,s: float,side: float) -> void:
	var node := _root(scene,"NomadCamp",s,side*24)
	node.scale=Vector3.ONE*1.6
	var b := RallySampleMeshes.new()
	# Two striped tents, a shade awning, rugs, a fire ring and resting camels.
	for t: int in range(2):
		var at := Vector3(side*(t*7.0),0,-3+t*6.5)
		for stripe: int in range(4):
			b.cone(3.2-stripe*.75,2.45-stripe*.75,.75,at+Vector3(0,.4+stripe*.75,0),[Color("b6452f"),Color("ead8b2"),Color("2f6b6b"),Color("ead8b2")][stripe],10)
		b.cone(.4,0,.8,at+Vector3(0,3.4,0),Color("6b5541"),6)
	for corner: Vector2 in [Vector2(-3,-1.5),Vector2(3,-1.5),Vector2(-3,1.5),Vector2(3,1.5)]:
		b.beam(Vector3(side*3.5+corner.x,0,8+corner.y),Vector3(side*3.5+corner.x,2.4,8+corner.y),.06,Color("6b5541"))
	b.box(Vector3(6.6,.08,3.6),Vector3(side*3.5,2.45,8),Color("d9a23c"),Vector3(.05,0,0))
	b.box(Vector3(2.8,.03,1.8),Vector3(side*3.5,.02,8),Color("8f2f3a"))
	for i: int in range(8):
		var a := i*TAU/8
		b.ellipsoid(Vector3(.28,.2,.28),Vector3(side*9+cos(a)*.8,.12,4+sin(a)*.8),Color("6f6156"))
	b.cone(.35,0,.6,Vector3(side*9,.3,4),Color("f08a3a"),6)
	for c: int in range(3):
		var at := Vector3(side*(-4.5-c*2.6),0,1+c*3.2)
		var hide := Color("c79a62").darkened(c*.06)
		b.ellipsoid(Vector3(1.3,.55,.6),at+Vector3(0,.55,0),hide)
		b.ellipsoid(Vector3(.45,.45,.4),at+Vector3(.1,1.05,0),hide.lightened(.05))
		b.beam(at+Vector3(1.0,.6,0),at+Vector3(1.6,1.5,0),.16,hide)
		b.ellipsoid(Vector3(.36,.2,.2),at+Vector3(1.85,1.55,0),hide)
		b.box(Vector3(.9,.12,.75),at+Vector3(0,1.05,0),Color("b6452f"))
	RallyStageLandmarks._mesh(node,b,false)


static func _ghost_tower(scene: RallyStageScenery,s: float,side: float) -> void:
	# Ghost-town water tower and two leaning false-front buildings.
	var node := _root(scene,"GhostTownWaterTower",s,side*28)
	node.scale=Vector3.ONE*1.3
	var b := RallySampleMeshes.new()
	var wood := Color("7a5a3f")
	for corner: Vector2 in [Vector2(-2,-2),Vector2(2,-2),Vector2(-2,2),Vector2(2,2)]:
		b.beam(Vector3(corner.x,0,corner.y),Vector3(corner.x*.7,9,corner.y*.7),.18,wood)
	for y: float in [3,6]:
		b.beam(Vector3(-1.8,y,-1.8),Vector3(1.8,y,1.8),.07,wood.darkened(.1))
		b.beam(Vector3(1.8,y,-1.8),Vector3(-1.8,y,1.8),.07,wood.darkened(.1))
	b.cone(2.6,2.6,3.6,Vector3(0,10.8,0),Color("9b7651"),14)
	for y: float in [9.5,11.0,12.2]: b.cone(2.68,2.68,.15,Vector3(0,y,0),Color("3f4a4c"),14)
	b.cone(2.9,0,1.4,Vector3(0,13.3,0),Color("6c4f37"),14)
	b.box(Vector3(.3,1.0,2.4),Vector3(-2.65*side,11.2,0),Color("f2e3b6"))
	for h: int in range(2):
		var x := -side*(7+h*6.5)
		b.box(Vector3(5,3.4,5.5),Vector3(x,1.7,0),Color("a88866").darkened(h*.1),Vector3(0,0,side*(.03+h*.04)))
		b.box(Vector3(5.2,1.6,.2),Vector3(x,4.1,-2.8),Color("b99a72").darkened(h*.1))
		b.box(Vector3(1.2,1.9,.1),Vector3(x,.95,-2.78),Color("3a2f27"))
		b.box(Vector3(3.6,.6,.08),Vector3(x,4.2,-2.92),[Color("c2493a"),Color("3f7a7c")][h])
	RallyStageLandmarks._mesh(node,b,true)


static func _rock_garden(scene: RallyStageScenery,rock: Material,rng: RandomNumberGenerator,s: float) -> void:
	# Balanced rocks and a small natural window, visible from the approach.
	var node := _root(scene,"BalancedRocks",s,-30)
	var batch := RallyRedrockScenery.RockBatch.new()
	batch.add(Vector3(0,-1,0),Vector3(6,9,5),0,2,701)
	batch.add(Vector3(0,7.6,0),Vector3(7,4.5,6),.6,1,702)
	batch.add(Vector3(9,-1,4),Vector3(5,6,5),1.2,2,703)
	batch.add(Vector3(9.3,4.6,4),Vector3(3.6,3.2,3.2),2.0,1,704)
	batch.add(Vector3(-8,-1,-3),Vector3(4,12,4),.4,3,705)
	batch.finish(node,"BalancedRockMesh",rock,true)


static func _dust_devils(scene: RallyStageScenery) -> void:
	# Slowly turning translucent dust columns on the open dunes; visual only.
	for i: int in range(3):
		var s := SPAN.x+180+i*380
		var side := -1.0 if i%2==0 else 1.0
		var node := _root(scene,"DustDevil%d"%i,s,side*(55+i*12))
		var b := RallySampleMeshes.new()
		for ring: int in range(9):
			var y := ring*2.4
			b.cone(1.2+ring*.55,1.5+ring*.6,2.2,Vector3(sin(ring*.7)*.6,y+1.1,cos(ring*.5)*.6),Color("e2bd8a"),10)
		var mesh := MeshInstance3D.new()
		mesh.mesh=b.finish()
		var material := StandardMaterial3D.new()
		material.albedo_color=Color(.89,.74,.54,.28)
		material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA
		material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
		material.cull_mode=BaseMaterial3D.CULL_DISABLED
		mesh.material_override=material
		mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mesh.set_meta("spin",.5+i*.2)
		node.add_child(mesh)
		scene.dust_devils.append(mesh)


static func _route_cairns(scene: RallyStageScenery) -> void:
	# Stacked-stone cairns with orange flags mark the dune route on crests.
	var b := RallySampleMeshes.new()
	var node := Node3D.new()
	node.name="RouteCairns"
	scene.dressing.add_child(node)
	var s := SPAN.x+40
	var index := 0
	while s<SPAN.y:
		var side := -1.0 if index%2==0 else 1.0
		var at := scene.ground_at(s,side*(scene.route.width_at(s)*.5+3.2))
		for k: int in range(4): b.ellipsoid(Vector3(.42-k*.07,.18,.38-k*.06),at+Vector3(0,.15+k*.3,0),Color("a8553a").lightened(k*.05))
		b.beam(at+Vector3(0,1.1,0),at+Vector3(0,2.4,0),.03,Color("6b5541"))
		b.box(Vector3(.04,.32,.5),at+Vector3(0,2.2,.25),Color("f08a3a"))
		s+=95
		index+=1
	var mesh := MeshInstance3D.new()
	mesh.mesh=b.finish()
	mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.visibility_range_end=320
	node.add_child(mesh)
