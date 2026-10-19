class_name RallyBreakablePosts
extends Node3D

# Five paired corridors, each exactly 6% of stage distance. Breakaway props do
# not modify the road collider, checkpoint corridor, or ghost compatibility.
const STARTS := [.06,.24,.42,.60,.80]
const SPAN := .06
const STEP := 12.0
const CELL := 32.0
var car: RallyVehicle
var batch: MultiMesh
var poses: Array[Transform3D] = []
var broken: Dictionary = {}
var grid: Dictionary = {}
var debris: Array[Dictionary] = []
var previous := Transform3D.IDENTITY
var piece_mesh: Mesh
var band_mesh: Mesh
var hits: int = 0

static func covers(station: float, length: float) -> bool:
	var fraction := station/maxf(length,1)
	for start: float in STARTS:
		if fraction>=start and fraction<start+SPAN: return true
	return false

static func stations(length: float) -> Array[float]:
	var result: Array[float] = []
	for start: float in STARTS:
		var s := start*length
		while s<(start+SPAN)*length:
			result.append(s)
			s+=STEP
	return result

func build(scenery: RallyStageScenery, vehicle: RallyVehicle) -> void:
	name="BreakableRoadPosts"
	car=vehicle
	previous=car.global_transform
	car.reset_completed.connect(_reset_sweep)
	var geometry := RallySampleMeshes.new()
	geometry.cone(.075,.065,.78,Vector3(0,.39,0),Color("f3ebd6"))
	geometry.cone(.065,.06,.25,Vector3(0,.905,0),Color("dc452c"))
	geometry.cone(.06,.055,.25,Vector3(0,1.155,0),Color("fff1da"))
	batch=MultiMesh.new()
	batch.transform_format=MultiMesh.TRANSFORM_3D
	batch.mesh=geometry.finish()
	var route := scenery.route
	for s: float in stations(route.length):
		for side: float in [-1,1]:
			var at := scenery.ground_at(s,side*(route.width_at(s)*.5+.8))
			var pose := Transform3D(Basis.IDENTITY,at)
			var key := _cell(at)
			if not grid.has(key): grid[key]=[]
			grid[key].append(poses.size())
			poses.append(pose)
	batch.instance_count=poses.size()
	for i: int in range(poses.size()):batch.set_instance_transform(i,poses[i])
	var mesh := MultiMeshInstance3D.new()
	mesh.multimesh=batch
	add_child(mesh)
	piece_mesh=_piece(Color("f3ebd6"))
	band_mesh=_piece(Color("dc452c"))

func _piece(color: Color) -> Mesh:
	var geometry := RallySampleMeshes.new()
	geometry.cone(.068,.06,.42,Vector3.ZERO,color)
	return geometry.finish()

func _cell(point: Vector3) -> Vector2i:
	return Vector2i(floori(point.x/CELL),floori(point.z/CELL))

func _reset_sweep() -> void:
	previous=car.global_transform

func reset() -> void:
	broken.clear()
	hits=0
	for i: int in range(poses.size()): batch.set_instance_transform(i,poses[i])
	for item: Dictionary in debris: item.body.queue_free()
	debris.clear()
	_reset_sweep()

# Slab test for the swept car envelope expanded by the narrow post. Unlike
# proximity triggers, this requires actual overlap, including vertical height.
static func intersects_post(point: Vector3, from: Transform3D, to: Transform3D, body_size: Vector3) -> bool:
	if from.origin.distance_to(to.origin)>35: return false # recovery teleport
	var inv := to.affine_inverse()
	var a := inv*(point+Vector3.UP*.64+to.origin-from.origin)
	var b := inv*(point+Vector3.UP*.64)
	var extent := body_size*.5+Vector3(.075,.64,.075)
	var low := 0.0
	var high := 1.0
	for axis: int in range(3):
		var delta := b[axis]-a[axis]
		if absf(delta)<.00001:
			if absf(a[axis])>extent[axis]:return false
		else:
			var t1 := (-extent[axis]-a[axis])/delta
			var t2 := (extent[axis]-a[axis])/delta
			low=maxf(low,minf(t1,t2))
			high=minf(high,maxf(t1,t2))
			if low>high:return false
	return true

func _physics_process(dt: float) -> void:
	if not is_instance_valid(car):return
	var current := car.global_transform
	if car.linear_velocity.length_squared()>.64:
		var cell := _cell(current.origin)
		for x: int in range(-1,2):
			for z: int in range(-1,2):
				for index: int in grid.get(cell+Vector2i(x,z),[]):
					if not broken.has(index) and intersects_post(poses[index].origin,previous,current,car.config.body_size):
						break_post(index,car.linear_velocity)
	previous=current
	for i: int in range(debris.size()-1,-1,-1):
		debris[i].age+=dt
		if debris[i].age>6:
			debris[i].body.queue_free()
			debris.remove_at(i)
		elif debris[i].age>5:
			debris[i].visual.transparency=debris[i].age-5

func break_post(index: int, velocity: Vector3) -> void:
	if broken.has(index):return
	broken[index]=true
	hits+=1
	batch.set_instance_transform(index,Transform3D(Basis.IDENTITY.scaled(Vector3(.8,.065,.8)),poses[index].origin))
	for section: int in range(3):
		if debris.size()>=24:
			debris[0].body.queue_free()
			debris.pop_front()
		var body := RigidBody3D.new()
		body.mass=.4
		body.collision_layer=0
		body.collision_mask=1 # ground only; cannot kick or snag the player's car
		body.position=poses[index].origin+Vector3.UP*(.22+section*.42)
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size=Vector3(.13,.42,.13)
		shape.shape=box
		body.add_child(shape)
		var visual := MeshInstance3D.new()
		visual.mesh=band_mesh if section==2 else piece_mesh
		body.add_child(visual)
		add_child(body)
		body.linear_velocity=velocity*.28+Vector3(0,1.7+section*.5,0)
		body.angular_velocity=Vector3(4+section,2,3-section)
		debris.append({"body":body,"visual":visual,"age":0.0})
