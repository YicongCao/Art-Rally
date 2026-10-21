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
	rng.randomize()
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
		var event := {"s":station,"side":side,"elapsed":-1.0,"items":[],"impact":false,"near_miss":false}
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
			var lateral_end: float = side*(scene.generator.route.width_at(station)*.5+maxf(radius,maxf(scale_y,scale_z))+1.8+rng.randf_range(0,.4))
			var along := rng.randf_range(-2,2)
			var start := _ground_point(station+along,lateral_start)+Vector3.UP*rng.randf_range(9,22)
			var finish := _ground_point(station+along-3.0,lateral_end)+Vector3.UP*scale_y*.78
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
	point.y = scene.presentation.scenery.rendered_height_at(point.x,point.z)
	return point


func position_at_weight(stone: MeshInstance3D,weight: float) -> Vector3:
	var start: Vector3=stone.get_meta("start")
	var finish: Vector3=stone.get_meta("finish")
	var point := start.lerp(finish,weight)
	var radius := maxf(stone.scale.x,maxf(stone.scale.y,stone.scale.z))
	var projected: Dictionary=scene.presentation.scenery.nearest(point)
	var corridor: float=scene.generator.route.width_at(projected.s)*.5+radius+1.65
	if absf(float(projected.lateral))<corridor:
		var pose: Transform3D=scene.generator.route.pose_at(projected.s,0)
		var shifted := point+pose.basis.x*signf(float(projected.lateral))*(corridor-absf(float(projected.lateral)))
		point.x=shifted.x
		point.z=shifted.z
	var floor_height := -INF
	# A straight interpolation can cut through the newly steep mountainside.
	# Keep the decorative trajectory above its actual rendered triangles.
	for offset: Vector2 in [Vector2.ZERO,Vector2(radius,0),Vector2(-radius,0),Vector2(0,radius),Vector2(0,-radius)]:
		floor_height=maxf(floor_height,scene.presentation.scenery.rendered_height_at(point.x+offset.x,point.z+offset.y))
	point.y=maxf(point.y,floor_height+radius)
	return point


func reset() -> void:
	closest_clearance=INF
	for event: Dictionary in events:
		event.elapsed = -1.0
		event.impact=false
		event.near_miss=false
		for stone: MeshInstance3D in event.items:
			stone.hide()
			stone.rotation = Vector3.ZERO
			stone.transparency=0
			if stone.has_meta("landed"): stone.remove_meta("landed")


func advance(dt: float) -> void:
	if events.is_empty() or scene.session.phase!=RallyStageSession.Phase.RUNNING or scene.get_tree().paused: return
	var progress: float = scene.session.progress
	var speed: float = scene.vehicle.linear_velocity.length()
	for event: Dictionary in events:
		if float(event.elapsed)>=ROCKFALL_DURATION+ROLL_DURATION: continue
		if float(event.elapsed)<0 and progress>float(event.s)+60:
			event.elapsed=ROCKFALL_DURATION+ROLL_DURATION
			event.impact=true
			continue
		if float(event.elapsed)<0 and progress>=float(event.s)-clampf(speed*2.0,12,46):
			# Slow/stopped cars see the stones on the mountain, not in their path.
			event.elapsed=0.0
			event.near_miss=speed>5.0 and scene.vehicle.linear_velocity.dot(-scene.vehicle.global_basis.z)>4.0
			for stone: MeshInstance3D in event.items: stone.show()
		if float(event.elapsed)<0: continue
		event.elapsed=minf(ROCKFALL_DURATION+ROLL_DURATION,float(event.elapsed)+dt)
		var weight := smoothstep(0,1,minf(1,float(event.elapsed)/ROCKFALL_DURATION))
		for stone: MeshInstance3D in event.items:
			var candidate := position_at_weight(stone,weight)
			# A moving car sees the last part of the arc land behind its rear bumper.
			# Stop/reverse falls remain on the authored mountain-side trajectory.
			if event.near_miss:
				var radius_bound := maxf(stone.scale.x,maxf(stone.scale.y,stone.scale.z))
				var rear: Vector3=scene.vehicle.global_position+scene.vehicle.global_basis.z*(scene.vehicle.config.body_size.z*.5+radius_bound+2.1)
				rear+=scene.vehicle.global_basis.x*float(event.side)*.4
				rear.y=scene.generator.surface_position_at(maxf(0,scene.session.progress-scene.vehicle.config.body_size.z*.5-radius_bound-2.1),0).y+radius_bound
				var alternative: Vector3=stone.get_meta("finish")
				var forward_speed: float=scene.vehicle.linear_velocity.dot(-scene.vehicle.global_basis.z)
				var target := alternative.lerp(rear,smoothstep(1,5,forward_speed))
				# Blend continuously into the last arc; no disappearing safety trick.
				candidate=candidate.lerp(target,smoothstep(.15,1,weight))
			if stone.has_meta("landed"):
				candidate=_roll_down(stone,float(event.elapsed)-ROCKFALL_DURATION,float(event.side))
			# Expanded oriented chassis envelope. Continuous displacement to the
			# mountain/upward escape side keeps every stone visible, never clipping.
			var local: Vector3=scene.vehicle.to_local(candidate)
			var half: Vector3=scene.vehicle.config.body_size*.5
			var nearest := local.clamp(-half,half)
			var outward := local-nearest
			var radius := maxf(stone.scale.x,maxf(stone.scale.y,stone.scale.z))
			var required := radius+1.5
			if outward.length()<required:
				if outward.length()<.001: outward=Vector3.UP
				candidate=scene.vehicle.to_global(nearest+outward.normalized()*required)
			var measured_local: Vector3=scene.vehicle.to_local(candidate)
			closest_clearance=minf(closest_clearance,measured_local.distance_to(measured_local.clamp(-half,half))-radius)
			if weight>=1 and not stone.has_meta("landed"): stone.set_meta("landed",candidate)
			stone.global_position=candidate
			var spin := float(stone.get_meta("spin"))*(weight+maxf(0,float(event.elapsed)-ROCKFALL_DURATION)*1.6)
			stone.rotation=Vector3(spin*.45,spin,spin*.3)
			stone.transparency=smoothstep(ROCKFALL_DURATION+ROLL_DURATION-1,ROCKFALL_DURATION+ROLL_DURATION,float(event.elapsed))
		if weight>=.98 and not event.impact:
			event.impact=true
			impact.global_position=event.items[0].global_position
			impact.pitch_scale=.65
			impact.volume_db=2
			if DisplayServer.get_name()!="headless": impact.play()
			_dust(impact.global_position)
		if float(event.elapsed)>=ROCKFALL_DURATION+ROLL_DURATION:
			for stone: MeshInstance3D in event.items: stone.hide()

func _roll_down(stone: MeshInstance3D,time: float,mountain_side: float) -> Vector3:
	var landed: Vector3=stone.get_meta("landed")
	var route: RallyStageRoute=scene.generator.route
	var projected: Dictionary=scene.presentation.scenery.nearest(landed)
	var pose := route.pose_at(projected.s,0)
	var radius := maxf(stone.scale.x,maxf(stone.scale.y,stone.scale.z))
	var cliff_side := -mountain_side
	var lateral_start: float=(landed-pose.origin).dot(pose.basis.x)
	var target_lateral := cliff_side*(route.width_at(projected.s)*.5+32)
	var travel := clampf(pow(maxf(time,0)/4.2,1.3),0,1)
	var point := landed+pose.basis.x*(target_lateral-lateral_start)*travel
	var lateral: float=lateral_start+(target_lateral-lateral_start)*travel
	var edge := route.width_at(projected.s)*.5+1.2
	var edge_fraction := clampf((cliff_side*edge-lateral_start)/(target_lateral-lateral_start),0,1)
	var edge_time := 4.2*pow(edge_fraction,1/1.3)
	var drop := maxf(0,time-edge_time)
	var floor_y: float=scene.presentation.scenery.rendered_height_at(point.x,point.z)+radius
	if absf(lateral)<edge:
		floor_y=maxf(floor_y,scene.generator.surface_position_at(projected.s,lateral).y+radius)
	# Roll across the shoulder, then gravity carries the rock down the visible
	# cliff. Fade only at the remote end, rather than vanishing at the bumper.
	point.y=maxf(floor_y,landed.y-4.9*drop*drop)+sin(minf(time,edge_time)*7)*.12*maxf(0,1-drop)
	return point


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
