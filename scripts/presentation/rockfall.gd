class_name RallyRockfall
extends Node

const ROCKFALL_DURATION := 2.8
const ROLL_DURATION := 8.0
const ROCKFALL_SITES := [450.0,900.0,1480.0,1930.0,2490.0]

var scene: Node3D
var events: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()
var impact: AudioStreamPlayer3D
var closest_clearance: float=INF


func build(owner_scene: Node3D) -> void:
	scene = owner_scene
	name = "HighlandRockfall"
	if scene.challenge.stage.environment_id!="highland": return
	impact=AudioStreamPlayer3D.new()
	rng.seed=59173
	impact.stream=RallyAudioDirector.asset("collision")
	impact.bus="Environment"
	impact.unit_size=24
	impact.max_distance=100
	scene.add_child(impact)
	scene.vehicle.reset_completed.connect(reset)
	for index: int in range(ROCKFALL_SITES.size()):
		var station: float = ROCKFALL_SITES[index]
		var side := signf(scene.challenge.stage.mountain_side_at(station))
		if side==0: continue
		var group := Node3D.new()
		group.name = "Fall%d"%[index+1]
		scene.presentation.scenery.dressing.add_child(group)
		var event := {"s":station,"side":side,"elapsed":-1.0,"items":[],"impact":false}
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
			var lateral_start: float = side*(scene.generator.route.width_at(station)*.5+24+rock_index*1.3)
			var along := rng.randf_range(-2,2)
			stone.set_meta("station",station+along)
			stone.set_meta("side",side)
			stone.set_meta("lateral_start",lateral_start)
			stone.set_meta("radius",maxf(radius,maxf(scale_y,scale_z)))
			stone.set_meta("spin",rng.randf_range(2.2,3.2))
			stone.set_meta("start",position_at_time(stone,0))
			stone.set_meta("finish",position_at_time(stone,ROCKFALL_DURATION+ROLL_DURATION))
			stone.global_position=stone.get_meta("start")
			stone.hide()
			event.items.append(stone)
		events.append(event)


func _ground_point(distance: float,lateral: float) -> Vector3:
	var route: RallyStageRoute = scene.generator.route
	var pose := route.pose_at(distance,0)
	var point: Vector3 = pose.origin+pose.basis.x*lateral
	point.y = scene.presentation.scenery.rendered_height_at(point.x,point.z)
	return point


func position_at_weight(stone: MeshInstance3D,weight: float) -> Vector3:
	return position_at_time(stone,clampf(weight,0,1)*(ROCKFALL_DURATION+ROLL_DURATION))


func position_at_time(stone: MeshInstance3D,time: float) -> Vector3:
	# One fixed transverse plane per stone, independent of the moving car.
	# Horizontal travel never clamps: the rock keeps travelling during cleanup.
	var station: float=stone.get_meta("station")
	var side: float=stone.get_meta("side")
	var start: float=stone.get_meta("lateral_start")
	var radius: float=stone.get_meta("radius")
	var route: RallyStageRoute=scene.generator.route
	var pose := route.pose_at(station,0)
	var travel := 3.0*time+1.7*time*time
	var lateral := start-side*travel
	var point := pose.origin+pose.basis.x*lateral
	var ground := _support_height(station,lateral)
	var half := route.width_at(station)*.5
	var edge := -side*(half+1.2)
	var edge_travel := absf(start-edge)
	var edge_time := (sqrt(9+6.8*edge_travel)-3)/3.4
	if time<=edge_time:
		point.y=ground+radius+absf(sin(time*7))*.18
	else:
		var rim := _ground_point(station,edge)
		rim.y=_support_height(station,edge)
		var falling := time-edge_time
		# Preserve the rim position continuously, then accelerate down the cliff.
		var rim_y := rim.y+radius+absf(sin(edge_time*7))*.18
		if falling<=2:
			point.y=maxf(ground+radius,rim_y-4*falling-4.9*falling*falling)
		else:
			# Beyond the near cliff, keep falling behind the valley terrain.
			# Sampling distant switchbacks would otherwise lift stones back uphill.
			var release_time := edge_time+2
			var release_lateral := start-side*(3*release_time+1.7*release_time*release_time)
			var release := _ground_point(station,release_lateral)
			var release_y := maxf(release.y+radius,rim_y-8-19.6)
			var tail := falling-2
			point.y=release_y-23.6*tail-4.9*tail*tail
	return point


func _support_height(station: float,lateral: float) -> float:
	var half: float=scene.generator.route.width_at(station)*.5
	var ground := _ground_point(station,lateral).y
	var road: float=scene.generator.surface_position_at(station,clampf(lateral,-half,half)).y
	# The road is a separate mesh above terrain: blend the shoulder instead
	# of snapping upward when the rock enters the road's collision apron.
	return lerpf(ground,maxf(ground,road),1-smoothstep(half,half+4,absf(lateral)))


func reset() -> void:
	closest_clearance=INF
	for event: Dictionary in events:
		event.elapsed = -1.0
		event.impact=false
		for stone: MeshInstance3D in event.items:
			stone.hide()
			stone.rotation = Vector3.ZERO
			stone.transparency=0


func advance(dt: float) -> void:
	if events.is_empty() or scene.session.phase!=RallyStageSession.Phase.RUNNING or scene.get_tree().paused: return
	var progress: float = scene.session.progress
	var speed: float = scene.vehicle.linear_velocity.length()
	var duration := ROCKFALL_DURATION+ROLL_DURATION
	for event: Dictionary in events:
		if float(event.elapsed)>=duration: continue
		if float(event.elapsed)<0:
			if progress>float(event.s)+60:
				event.elapsed=duration
				continue
			# Start well ahead of an approaching car. If reset/spawn puts the car
			# in the crossing itself, wait until it has cleared the fixed site.
			var gap: float=float(event.s)-progress
			if gap>clampf(speed*5.5+20,45,200) or absf(gap)<20: continue
			event.elapsed=0.0
			for stone: MeshInstance3D in event.items: stone.show()
		event.elapsed=minf(duration,float(event.elapsed)+dt)
		var time: float=event.elapsed
		for stone: MeshInstance3D in event.items:
			stone.global_position=position_at_time(stone,time)
			var pose: Transform3D=scene.generator.route.pose_at(float(stone.get_meta("station")),0)
			var roll_axis: Vector3=-pose.basis.z*float(event.side)
			stone.quaternion=Quaternion(roll_axis,float(stone.get_meta("spin"))*time*time)
			# Fade only far down the valley while still moving, never at the road.
			stone.transparency=maxf(1-smoothstep(0,.3,time),smoothstep(duration-1.5,duration,time))
			var local: Vector3=scene.vehicle.to_local(stone.global_position)
			var half: Vector3=scene.vehicle.config.body_size*.5
			closest_clearance=minf(closest_clearance,local.distance_to(local.clamp(-half,half))-float(stone.get_meta("radius")))
		var hero: MeshInstance3D=event.items[0]
		var road_pose: Transform3D=scene.generator.route.pose_at(float(hero.get_meta("station")),0)
		var lateral: float=(hero.global_position-road_pose.origin).dot(road_pose.basis.x)*float(event.side)
		if lateral<=scene.generator.route.width_at(event.s)*.5 and not event.impact:
			event.impact=true
			impact.global_position=hero.global_position
			impact.pitch_scale=.65
			impact.volume_db=2
			if DisplayServer.get_name()!="headless": impact.play()
			_dust(impact.global_position)
		if time>=duration:
			for stone: MeshInstance3D in event.items: stone.hide()


func _dust(at: Vector3) -> void:
	var puff := GPUParticles3D.new()
	puff.amount=24
	puff.one_shot=true
	puff.explosiveness=.9
	puff.lifetime=1.2
	var process := ParticleProcessMaterial.new()
	process.direction=Vector3.UP
	process.spread=85
	process.initial_velocity_min=1.0
	process.initial_velocity_max=3.0
	process.gravity=Vector3(0,-1,0)
	process.scale_min=.13
	process.scale_max=.45
	process.color=Color("8b8196")
	puff.process_material=process
	var mesh := SphereMesh.new()
	mesh.radial_segments=6
	mesh.rings=3
	mesh.radius=.35
	mesh.height=.7
	var dust := StandardMaterial3D.new()
	dust.vertex_color_use_as_albedo=true
	dust.roughness=1.0
	mesh.material=dust
	puff.draw_pass_1=mesh
	scene.add_child(puff)
	puff.global_position=at
	puff.emitting=true
	scene.get_tree().create_timer(1.5,false).timeout.connect(puff.queue_free)
