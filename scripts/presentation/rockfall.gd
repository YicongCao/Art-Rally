class_name RallyRockfall
extends Node

const ROCKFALL_DURATION := 2.8
const ROCKFALL_SITES := [450.0,900.0,1480.0,1930.0,2490.0]

var scene: Node3D
var events: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()


func build(owner_scene: Node3D) -> void:
	scene = owner_scene
	name = "HighlandRockfall"
	if scene.challenge.stage.environment_id!="highland": return
	rng.randomize()
	for index: int in range(ROCKFALL_SITES.size()):
		var station: float = ROCKFALL_SITES[index]
		var side := signf(scene.challenge.stage.mountain_side_at(station))
		if side==0: continue
		var group := Node3D.new()
		group.name = "Fall%d"%[index+1]
		scene.presentation.scenery.dressing.add_child(group)
		var event := {"s":station,"side":side,"elapsed":-1.0,"items":[]}
		var count := rng.randi_range(4,6)
		for rock_index: int in range(count):
			var is_boulder := rock_index==0
			var radius := rng.randf_range(1.0,1.45) if is_boulder else rng.randf_range(.28,.65)
			var scale_y := radius*rng.randf_range(.72,1.18)
			var scale_z := radius*rng.randf_range(.8,1.3)
			var mesh := SphereMesh.new()
			mesh.radius = 1
			mesh.height = 2
			mesh.radial_segments = 6 if is_boulder else 5
			mesh.rings = 3
			var stone := MeshInstance3D.new()
			stone.name = "Boulder" if is_boulder else "Fragment%d"%rock_index
			stone.mesh = mesh
			stone.scale = Vector3(radius,scale_y,scale_z)
			stone.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
			var material := StandardMaterial3D.new()
			var tint := Color("67767a").lerp(Color("9b9081"),rng.randf_range(0,0.42))
			material.albedo_color = tint
			material.roughness = .96
			stone.material_override = material
			group.add_child(stone)
			var lateral_start: float = side*(scene.generator.route.width_at(station)*.5+20+rng.randf_range(0,7))
			var lateral_end: float = side*(scene.generator.route.width_at(station)*.5+radius+5.2+rng.randf_range(0,2.5))
			var along := rng.randf_range(-5,5)
			var start := _ground_point(station+along,lateral_start)+Vector3.UP*rng.randf_range(9,22)
			var finish := _ground_point(station+along+rng.randf_range(-3,3),lateral_end)+Vector3.UP*scale_y*.78
			stone.set_meta("start",start)
			stone.set_meta("finish",finish)
			stone.set_meta("spin",rng.randf_range(-3.2,3.2))
			stone.global_position = start
			stone.hide()
			event.items.append(stone)
		events.append(event)


func _ground_point(distance: float,lateral: float) -> Vector3:
	var route: RallyStageRoute = scene.generator.route
	var pose := route.pose_at(distance,0)
	var point: Vector3 = pose.origin+pose.basis.x*lateral
	point.y = scene.presentation.scenery.height_at(point.x,point.z)
	return point


func reset() -> void:
	for event: Dictionary in events:
		event.elapsed = -1.0
		for stone: MeshInstance3D in event.items:
			stone.hide()
			stone.rotation = Vector3.ZERO


func advance(dt: float) -> void:
	if events.is_empty() or scene.session.phase!=RallyStageSession.Phase.RUNNING: return
	var progress: float = scene.session.progress
	var speed: float = scene.vehicle.linear_velocity.length()
	for event: Dictionary in events:
		if float(event.elapsed)<0 and progress>=float(event.s)-clampf(speed*2.3,8,58):
			event.elapsed = 0.0
			for stone: MeshInstance3D in event.items: stone.show()
		if float(event.elapsed)<0: continue
		event.elapsed = minf(ROCKFALL_DURATION,float(event.elapsed)+dt)
		var weight := smoothstep(0,1,float(event.elapsed)/ROCKFALL_DURATION)
		for stone: MeshInstance3D in event.items:
			var start: Vector3 = stone.get_meta("start")
			var finish: Vector3 = stone.get_meta("finish")
			stone.global_position = start.lerp(finish,weight)
			var spin := float(stone.get_meta("spin"))*weight
			stone.rotation = Vector3(spin*.45,spin,spin*.3)
			if scene.vehicle.global_position.distance_to(stone.global_position)<2.8:
				stone.hide()
		if float(event.elapsed)>=ROCKFALL_DURATION:
			for stone: MeshInstance3D in event.items: stone.hide()
