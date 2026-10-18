class_name RallyReplayController
extends Node

const CAMERA_NAMES := ["电视跟随","直升机","追尾","路旁机位"]
var scene: Node3D
var actor := RallyGhostPlayer.new()
var recording: Dictionary = {}
var clock: float = 0
var duration: float = 0
var playing: bool = true
var active: bool = false
var mode: int = 0
var snap: bool = true
var framing_offset: float = 4.2
var broadcast_side: float = 1.0
var canopies: Array[Vector4] = []
var streaks := RallyTailStreaks.new()

func begin(owner_scene: Node3D,data: Dictionary,plate: String) -> bool:
	process_mode = Node.PROCESS_MODE_ALWAYS
	scene = owner_scene
	if not RallyGhostRecording.valid(data,scene.challenge.key()): return false
	for placement: Dictionary in scene.presentation.scenery.foliage.placements:
		if placement.kind not in ["pine","umbrella"] or absf(placement.lateral)>40: continue
		var scale_factor: float = placement.scale
		var at: Vector3 = placement.point
		if placement.kind=="umbrella":
			canopies.append(Vector4(at.x,at.y+6.0*scale_factor,at.z,3.1*scale_factor))
		else:
			canopies.append(Vector4(at.x,at.y+2.8*scale_factor,at.z,2.3*scale_factor))
			canopies.append(Vector4(at.x,at.y+5.8*scale_factor,at.z,1.6*scale_factor))
	recording = data
	duration = float(data.duration)
	if duration<=0: return false
	scene.add_child(actor)
	actor.name = "ReplayVehicle"
	actor.build(scene.challenge.vehicle,recording,false)
	RallyVehiclePlate.attach(actor.get_child(0),scene.challenge.vehicle,plate)
	streaks.build(scene,scene.challenge.vehicle.body_size)
	streaks.visual.name = "ReplayTailStreaks"
	scene.vehicle.visible = false
	scene.ghost.visible = false
	scene.game_hud.visible = false
	scene.presentation.tail_streaks.clear()
	scene.presentation.camera_rig.dashboard.visible = false
	scene.presentation.camera_rig.display_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	scene.controls.set_process_input(false)
	scene.feedback.update(scene.vehicle,scene.preferences,scene.controls,true,0)
	if scene.feedback.one_shot!=null: scene.feedback.one_shot.stream_paused = true
	for particle: Dictionary in scene.feedback.particles: particle.emitter.visible = false
	if is_instance_valid(scene.broadcast): scene.broadcast.airframe.visible = false
	active = true
	seek(float(data.frames[0][0]))
	return true

func stop() -> void:
	active = false
	if is_instance_valid(actor): actor.queue_free()
	if is_instance_valid(streaks.visual): streaks.visual.queue_free()
	if is_instance_valid(scene):
		scene.vehicle.visible = true
		if scene.feedback.one_shot!=null: scene.feedback.one_shot.stream_paused = false
		for particle: Dictionary in scene.feedback.particles: particle.emitter.visible = true
		scene.controls.set_process_input(true)
		scene.camera_snap = true
		scene.presentation.camera_rig.reset()

func seek(seconds: float) -> void:
	clock = clampf(seconds,0,duration)
	snap = true
	streaks.clear()
	_render(0)

func set_camera(value: int) -> void:
	mode = posmod(value,CAMERA_NAMES.size())
	snap = true
	streaks.clear()

func _process(dt: float) -> void:
	if not active or not is_instance_valid(scene): return
	if playing:
		clock+=dt
		if clock>duration:
			clock = float(recording.frames[0][0])
			snap = true
			streaks.clear()
	_render(dt if playing else 0)
	scene.presentation.sky_life.advance(dt if playing else 0)

func _render(dt: float) -> void:
	if not active: return
	actor.update(clock,Vector3.ZERO,true)
	if not actor.visible:
		snap = true
		streaks.clear()
		return
	var pose := actor.transform
	var forward := -pose.basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var target := pose.origin+Vector3.UP*.7
	var eye := target+right*11*broadcast_side-forward*13+Vector3.UP*5.5
	scene.camera.fov = 48
	match mode:
		1:
			eye = target+right*20-forward*24+Vector3.UP*25
			scene.camera.fov = 43
		2:
			eye = target-forward*7+Vector3.UP*2.6
			scene.camera.fov = 62
		3:
			var station_time := minf(duration,floorf(clock/5)*5+2.5)
			var station := RallyGhostRecording.sample(recording,station_time)
			if not station.is_empty():
				var at: Transform3D = station.pose
				eye = at.origin+at.basis.x*12+Vector3.UP*3
			else: eye = target+right*12+Vector3.UP*3
			scene.camera.fov = 52
	var ground: float = scene.presentation.scenery.height_at(eye.x,eye.z)
	eye.y = maxf(eye.y,ground+2)
	if not clear_view(target,eye):
		if mode==0:
			var opposite := target-right*11*broadcast_side-forward*13+Vector3.UP*5.5
			opposite.y = maxf(opposite.y,scene.presentation.scenery.height_at(opposite.x,opposite.z)+2)
			if clear_view(target,opposite):
				broadcast_side *= -1
				eye = opposite
		if not clear_view(target,eye):
			for lift: float in [7,14,22]:
				var raised := eye+Vector3.UP*lift
				if clear_view(target,raised):
					eye = raised
					break
		if not clear_view(target,eye): eye = target-forward*4+Vector3.UP*1.5
		snap = true
	if snap or mode==3: scene.camera.global_position = eye
	else: scene.camera.global_position = scene.camera.global_position.lerp(eye,1-exp(-5*dt))
	if not clear_view(target,scene.camera.global_position): scene.camera.global_position = eye
	var screen_right := (target-eye).normalized().cross(Vector3.UP).normalized()
	var framed_target := target-screen_right*framing_offset
	if scene.camera.global_position.distance_squared_to(framed_target)>.01: scene.camera.look_at(framed_target)
	snap = false
	var future := RallyGhostRecording.sample(recording,minf(duration,clock+.05))
	var speed := 0.0
	if not future.is_empty(): speed = pose.origin.distance_to(future.pose.origin)/.05
	if dt>0: streaks.update(pose,speed,dt,scene.camera)


func _exit_tree() -> void:
	# A short/aborted run can have no usable replay frames.
	if is_instance_valid(actor) and actor.get_parent()==null: actor.free()
	if is_instance_valid(streaks.visual) and streaks.visual.get_parent()==null: streaks.visual.free()


func clear_view(target: Vector3,eye: Vector3) -> bool:
	var delta := eye-target
	var squared := delta.length_squared()
	if squared<.01: return false
	for canopy: Vector4 in canopies:
		var at := Vector3(canopy.x,canopy.y,canopy.z)
		var t := clampf((at-target).dot(delta)/squared,0,1)
		if at.distance_squared_to(target+delta*t)<canopy.w*canopy.w: return false
	var space: PhysicsDirectSpaceState3D = scene.get_world_3d().direct_space_state
	return space.intersect_ray(PhysicsRayQueryParameters3D.create(target,eye,5)).is_empty()
