class_name RallySampleDressing
extends RefCounted

const BATCH_LENGTH := 160.0
const VISIBILITY_SCALE := 1.30
const TREE_SWITCH := 180.0*VISIBILITY_SCALE
const TREE_FADE := 16.0
var biome: String = "autumn"
var land: Node3D
var range_start: float = 430
var range_end: float = 630
var spectator_stations: Array[float] = [503.0]
var rng := RandomNumberGenerator.new()
var batches: Dictionary = {}
var meshes: Dictionary = {}
var placements: Array[Dictionary] = []
var animated_arms: Array[Node3D] = []


func build(landscape: RallySampleLandscape) -> void:
	build_range(landscape,430,630)


func build_range(landscape: Node3D, start: float, end: float, density: float = 1.0) -> void:
	land = landscape
	range_start = start
	range_end = end
	var multiplier := (end-start)/200.0*density
	rng.seed = 84903
	meshes["shadow_pine"] = RallySampleMeshes.tree_shadow(false)
	meshes["shadow_umbrella"] = RallySampleMeshes.tree_shadow(true)
	for variant: int in range(3):
		meshes["pine%d"%variant] = RallySampleMeshes.pine(variant*39+1,false)
		meshes["umbrella%d"%variant] = RallySampleMeshes.pine(variant*19+2,true)
		meshes["rock%d"%variant] = RallySampleMeshes.rock(variant+30)
		meshes["shrub%d"%variant] = RallySampleMeshes.shrub(variant+50)
		meshes["grass%d"%variant] = RallySampleMeshes.grass(variant+70)
		meshes["far_pine%d"%variant] = _distant_tree(variant,false)
		meshes["far_umbrella%d"%variant] = _distant_tree(variant,true)
	if biome!="autumn":
		for key: String in meshes:
			if not key.begins_with("shadow"): meshes[key] = _biome_mesh(meshes[key],key.trim_prefix("far_"))
	# Desert plants no conifers; its yucca and ocotillo are placed by RallyRedrockScenery.
	var tree_share := 0.0 if biome=="desert" else (0.25 if biome=="coast" else 1.0)
	for i: int in range(int(240*multiplier*tree_share)):
		var s := rng.randf_range(range_start,range_end)
		var side := -1.0 if rng.randf() < 0.5 else 1.0
		var lateral := side*rng.randf_range(7.0,95.0)
		# Open up a sightline on the valley side; cluster trees instead of wallpaper spacing.
		if side < 0 and s > 470 and s < 540 and absf(lateral) < 35: continue
		var kind := "umbrella" if rng.randf() < (0.55 if biome=="autumn" else 0.03) else "pine"
		place(kind, s,lateral,rng.randf_range(0.72,1.45))
	for i: int in range(int(600*multiplier)):
		var s := rng.randf_range(range_start,range_end)
		var lateral := rng.randf_range(3.8,30)*(-1 if i%2 else 1)
		place("shrub",s,lateral,rng.randf_range(0.5,1.5))
	for i: int in range(int(150*multiplier)):
		var s := rng.randf_range(range_start,range_end)
		var lateral := rng.randf_range(4.1,6.4)*(-1 if i%2 else 1)
		place("rock",s,lateral,rng.randf_range(0.18,0.65))
	for i: int in range(int(60*multiplier)):
		place("rock",rng.randf_range(range_start,range_end),rng.randf_range(8,24)*(-1 if i%2 else 1),rng.randf_range(0.7,2.7))
	for i: int in range(int(6400*multiplier*(.38 if biome=="desert" else 1.0))):
		var s := rng.randf_range(range_start,range_end)
		var lateral := rng.randf_range(4.05,22)*(-1 if i%2 else 1)
		place("grass",s,lateral,rng.randf_range(0.65,1.4))
	_flush()
	for station: float in spectator_stations: _spectators(station)
	if end-start < 250: _road_signs()


func place(kind: String, s: float, lateral: float, scale_factor: float) -> void:
	var key := kind+str(rng.randi_range(0,2))
	var chunk := int((s-range_start)/BATCH_LENGTH)
	var batch_key := "%s_%d" % [key,chunk]
	if not batches.has(batch_key): batches[batch_key] = {"mesh":key,"transforms":[],"colors":[]}
	var point: Vector3 = land.ground_at(s,lateral)
	if land.has_method("allows_decoration") and not land.allows_decoration(point,kind,scale_factor): return
	var basis := Basis(Vector3.UP,rng.randf()*TAU).scaled(Vector3(scale_factor,scale_factor*rng.randf_range(0.85,1.15),scale_factor))
	batches[batch_key].transforms.append(Transform3D(basis,point))
	batches[batch_key].colors.append(Color.WHITE.darkened(rng.randf_range(0,0.15)))
	placements.append({"kind":kind,"s":s,"lateral":lateral,"scale":scale_factor,"point":point})


func _flush() -> void:
	for key: String in batches:
		var batch: Dictionary = batches[key]
		var multimesh := MultiMesh.new()
		multimesh.transform_format = MultiMesh.TRANSFORM_3D
		multimesh.use_colors = true
		multimesh.mesh = meshes[batch.mesh]
		multimesh.instance_count = batch.transforms.size()
		var center := Vector3.ZERO
		for transform: Transform3D in batch.transforms: center += transform.origin
		if not batch.transforms.is_empty(): center /= batch.transforms.size()
		for i: int in range(multimesh.instance_count):
			var local: Transform3D = batch.transforms[i]
			local.origin -= center
			multimesh.set_instance_transform(i,local)
			multimesh.set_instance_color(i,batch.colors[i])
		var instance := MultiMeshInstance3D.new()
		instance.name = key
		instance.position = center
		instance.multimesh = multimesh
		instance.visibility_range_end = default_visibility(key)
		instance.visibility_range_end_margin = 15*VISIBILITY_SCALE
		instance.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		var tree := key.begins_with("pine") or key.begins_with("umbrella")
		if tree or key.begins_with("grass") or key.begins_with("shrub") or key.begins_with("rock"):
			instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		land.dressing.add_child(instance)
		if tree:
			instance.visibility_range_end_margin = TREE_FADE
			var distant := MultiMeshInstance3D.new()
			distant.name = "far_"+key
			distant.position = center
			var distant_mesh := MultiMesh.new()
			distant_mesh.transform_format = MultiMesh.TRANSFORM_3D
			distant_mesh.use_colors = true
			distant_mesh.mesh = meshes["far_"+str(batch.mesh)]
			distant_mesh.instance_count = multimesh.instance_count
			for i: int in range(multimesh.instance_count):
				distant_mesh.set_instance_transform(i,multimesh.get_instance_transform(i))
				distant_mesh.set_instance_color(i,multimesh.get_instance_color(i))
			distant.multimesh = distant_mesh
			distant.visibility_range_begin = TREE_SWITCH
			distant.visibility_range_begin_margin = TREE_FADE
			distant.visibility_range_end = 360*VISIBILITY_SCALE
			distant.visibility_range_end_margin = 24
			distant.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
			distant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			land.dressing.add_child(distant)
			var shadow_multimesh := MultiMesh.new()
			shadow_multimesh.transform_format = MultiMesh.TRANSFORM_3D
			shadow_multimesh.mesh = meshes["shadow_umbrella" if key.begins_with("umbrella") else "shadow_pine"]
			shadow_multimesh.instance_count = multimesh.instance_count
			for i: int in range(multimesh.instance_count):
				shadow_multimesh.set_instance_transform(i,multimesh.get_instance_transform(i))
			var shadow := MultiMeshInstance3D.new()
			shadow.name = "shadow_"+key
			shadow.position = center
			shadow.multimesh = shadow_multimesh
			shadow.visibility_range_end = 210*VISIBILITY_SCALE
			shadow.visibility_range_end_margin = 15*VISIBILITY_SCALE
			shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_SHADOWS_ONLY
			land.dressing.add_child(shadow)


static func default_visibility(key: String) -> float:
	if key.begins_with("far_"): return 360*VISIBILITY_SCALE
	if key.begins_with("pine") or key.begins_with("umbrella"): return 180*VISIBILITY_SCALE
	if key.begins_with("shadow_"): return 210*VISIBILITY_SCALE
	if key.begins_with("grass"): return 105*VISIBILITY_SCALE
	if key.begins_with("shrub"): return 180*VISIBILITY_SCALE
	if key.begins_with("rock"): return 220*VISIBILITY_SCALE
	return 360*VISIBILITY_SCALE


func _spectators(station: float) -> void:
	var people := Node3D.new()
	people.name = "Spectators"
	land.dressing.add_child(people)
	for i: int in range(7):
		var s := station+i*1.7
		var at: Vector3 = land.ground_at(s,7.5+(i%2)*1.0)
		var builder := RallySampleMeshes.new()
		var shirt: Color = [Color("d2763f"),Color("3a6068"),Color("dfd7b3"),Color("9b4b3f")][i%4]
		builder.cone(0.19,0.23,0.57,Vector3(0,1.02,0),shirt,6)
		builder.ellipsoid(Vector3(0.14,0.18,0.14),Vector3(0,1.49,0),Color("c89870"))
		for side: float in [-1,1]:
			builder.beam(Vector3(side*0.12,0.78,0),Vector3(side*0.15,0.12,0),0.08,Color("35424a"))
			builder.box(Vector3(0.15,0.1,0.27),Vector3(side*0.15,0.07,-0.05),Color("282d2c"))
		builder.beam(Vector3(-0.23,1.22,0),Vector3(-0.30,0.83,-0.07),0.065,shirt)
		var figure := MeshInstance3D.new()
		figure.mesh = builder.finish()
		figure.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		figure.position = at
		figure.rotation.y = atan2(-land.route.rights[land.route.index_at(s)].x,-land.route.rights[land.route.index_at(s)].z)
		people.add_child(figure)
		var arm := Node3D.new()
		arm.position = Vector3(0.22,1.22,0)
		figure.add_child(arm)
		var arm_builder := RallySampleMeshes.new()
		arm_builder.beam(Vector3.ZERO,Vector3(0.2,0.43,0),0.065,shirt)
		arm_builder.ellipsoid(Vector3(0.065,0.085,0.065),Vector3(0.2,0.45,0),Color("c89870"))
		var mesh := MeshInstance3D.new()
		mesh.mesh = arm_builder.finish()
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		arm.add_child(mesh)
		animated_arms.append(arm)
	# Visible rope separates the spectator sample from the driving corridor.
	var fence := RallySampleMeshes.new()
	var previous := Vector3.ZERO
	for i: int in range(9):
		var at: Vector3 = land.ground_at(station-4+i*2.2,5.8)
		fence.cone(0.045,0.03,0.95,at+Vector3.UP*0.475,Color("94744c"),6)
		if i > 0: fence.beam(previous,at+Vector3.UP*0.8,0.018,Color("e6c78c"))
		previous = at+Vector3.UP*0.8
	var mesh := MeshInstance3D.new()
	mesh.mesh = fence.finish()
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	people.add_child(mesh)


func _road_signs() -> void:
	for station: float in [438,625]:
		var root := Node3D.new()
		root.position = land.ground_at(station,4.7)
		root.basis = land.route.pose_at(station).basis
		land.dressing.add_child(root)
		GrayboxGeometry.box(root,"Post",Vector3(0.07,1.2,0.07),Vector3(0,0.6,0),Color("88724d"))
		GrayboxGeometry.box(root,"Sign",Vector3(1.0,0.5,0.07),Vector3(0,1.25,0),Color("294b43"))
		var text := Label3D.new()
		text.text = "PINE RIDGE\nVISUAL STUDY" if station < 500 else "END OF SAMPLE"
		text.font_size = 40
		text.pixel_size = 0.004
		text.position = Vector3(0,1.25,0.045)
		root.add_child(text)


func _biome_mesh(source: ArrayMesh,kind: String) -> ArrayMesh:
	var arrays := source.surface_get_arrays(0)
	var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
	var palette := {"pine":Color("2e5148"),"umbrella":Color("68825a"),"rock":Color("7f94a5"),"shrub":Color("737c50"),"grass":Color("c5c083")}
	if biome=="coast": palette = {"pine":Color("315f4a"),"umbrella":Color("4e7250"),"rock":Color("dfdbc4"),"shrub":Color("7b8a5a"),"grass":Color("cbc486")}
	if biome=="desert": palette = {"pine":Color("4f6a4c"),"umbrella":Color("6d7f55"),"rock":Color("b85a35"),"shrub":Color("5f8f4e"),"grass":Color("ddb260")}
	var base := Color.WHITE
	for key: String in palette:
		if kind.begins_with(key): base = palette[key].srgb_to_linear()
	for i: int in range(colors.size()):
		var shade := clampf(colors[i].get_luminance()*1.5+.40,.40,1.2)
		colors[i] = Color(base.r*shade,base.g*shade,base.b*shade)
	arrays[Mesh.ARRAY_COLOR] = colors
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
	mesh.surface_set_material(0,source.surface_get_material(0))
	return mesh


static func _distant_tree(variant: int, broadleaf: bool) -> ArrayMesh:
	# The same placement transforms and collision remain; only distant drawing is simplified.
	var builder := RallySampleMeshes.new()
	builder.cone(.19,.045,7.4,Vector3(0,3.7,0),Color("685047"),5)
	if broadleaf:
		var color: Color = [Color("e97428"),Color("d7a833"),Color("cb533f")][variant]
		for i: int in range(13):
			var angle := i*2.39996
			var center := Vector3(cos(angle)*1.2,5.5+(i%4)*.44,sin(angle)*1.2)
			var vertices: Array[Vector3] = [center+Vector3.UP*1.4,center+Vector3.DOWN*.9,center+Vector3.LEFT*1.1,center+Vector3.RIGHT*1.1,center+Vector3.FORWARD*1.1,center+Vector3.BACK*1.1]
			for face: Vector3i in [Vector3i(0,2,4),Vector3i(0,4,3),Vector3i(0,3,5),Vector3i(0,5,2),Vector3i(1,4,2),Vector3i(1,3,4),Vector3i(1,5,3),Vector3i(1,2,5)]:
				builder.triangle(vertices[face.x],vertices[face.y],vertices[face.z],color.darkened((i%3)*.035))
	else:
		var color: Color = [Color("397b56"),Color("356c68"),Color("cfaa35")][variant]
		for tier: int in range(10):
			builder.cone(2.05-tier*.19,0,1.65,Vector3(0,2.0+tier*.61,0),color.lightened((tier%3)*.025),7)
	return builder.finish()
