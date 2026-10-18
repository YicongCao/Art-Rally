class_name RallyBroadcastHelicopter
extends Node3D

const FRACTIONS := [.16,.37,.60,.82]
var scene: Node3D
var album: RallyPhotoAlbum
var airframe := Node3D.new()
var rotor := Node3D.new()
var tail_rotor := Node3D.new()
var camera_viewport: SubViewport
var photo_camera: Camera3D
var next_pass: int = 0
var shot_count: int = 0
var active_time: float = 0
var clock: float = 0
var next_allowed_time: float = 0
var photographed: bool = false
var capture_pending: bool = false
var photos_enabled: bool = true
var last_saved: String = ""
var rotor_audio := AudioStreamPlayer3D.new()

func build(owner_scene: Node3D,photo_album: RallyPhotoAlbum) -> void:
	scene = owner_scene
	album = photo_album
	name = "RallyBroadcastHelicopter"
	add_child(airframe)
	airframe.name = "OrangeWhiteNewsHelicopter"
	rotor_audio.stream = RallyAudioDirector.asset("helicopter",true)
	rotor_audio.bus = "Environment"
	rotor_audio.unit_size = 55
	rotor_audio.max_distance = 220
	rotor_audio.volume_linear = .75
	airframe.add_child(rotor_audio)
	var b := RallySampleMeshes.new()
	b.ellipsoid(Vector3(1.7,1.4,3.0),Vector3(0,0,0),Color("e8e4d5"))
	b.ellipsoid(Vector3(1.5,1.0,1.5),Vector3(0,0,-1.9),Color("426a73"))
	b.box(Vector3(3.0,.48,2.5),Vector3(0,-.32,.2),Color("e77e39"))
	b.beam(Vector3(0,.25,1.8),Vector3(0,1.2,8.1),.35,Color("e8e4d5"))
	b.box(Vector3(.18,2.8,1.8),Vector3(0,1.6,8),Color("e77e39"))
	b.box(Vector3(3.8,.18,.8),Vector3(0,1.1,7.0),Color("e8e4d5"))
	b.beam(Vector3(0,.8,0),Vector3(0,2.2,0),.12,Color("36494a"))
	for side: float in [-1,1]:
		b.beam(Vector3(side*1.9,-1.9,-2.8),Vector3(side*1.9,-1.9,2.7),.10,Color("495a5b"))
		for z: float in [-1.4,1.4]: b.beam(Vector3(side*.9,-.8,z),Vector3(side*1.9,-1.9,z),.07,Color("6f7a72"))
	# The aircraft flies to the player's right: expose the LEFT door and operator.
	# Everything projects beyond the fuselage silhouette, not inside its solid shell.
	b.box(Vector3(.12,1.65,2.0),Vector3(-1.65,.05,.65),Color("19363d"))
	b.box(Vector3(.9,.15,1.7),Vector3(-1.98,-.85,.65),Color("52605a"))
	b.cone(.30,.34,.85,Vector3(-2.02,.12,.65),Color("efb54e"),6)
	b.box(Vector3(.08,.5,.48),Vector3(-2.35,.2,.68),Color("f2e9cd"))
	b.ellipsoid(Vector3(.25,.28,.24),Vector3(-2.05,1.16,.65),Color("d49b76"))
	b.ellipsoid(Vector3(.27,.13,.25),Vector3(-2.05,1.38,.65),Color("3c3432"))
	b.beam(Vector3(-2.05,.48,.65),Vector3(-2.05,1.02,.65),.12,Color("d49b76"))
	for z: float in [.40,.88]:
		b.beam(Vector3(-2.0,-.22,z),Vector3(-2.38,-.65,z+.1),.12,Color("334b50"))
		b.beam(Vector3(-2.38,-.65,z+.1),Vector3(-2.3,-1.25,z+.2),.10,Color("334b50"))
		b.box(Vector3(.38,.16,.22),Vector3(-2.42,-1.27,z+.2),Color("263b3c"))
		b.beam(Vector3(-2.05,.5,z),Vector3(-2.52,.25,z),.09,Color("d49b76"))
		b.beam(Vector3(-2.52,.25,z),Vector3(-2.75,.68,z+.45),.09,Color("d49b76"))
	# Oversized shoulder camera, forward lens hood, eyepiece and red tally light.
	b.box(Vector3(1.05,.45,.48),Vector3(-2.68,.78,1.25),Color("233a40"))
	b.box(Vector3(.28,.60,.62),Vector3(-3.28,.78,1.25),Color("172b32"))
	b.ellipsoid(Vector3(.03,.22,.22),Vector3(-3.44,.78,1.25),Color("78c8ca"))
	b.box(Vector3(.42,.10,.10),Vector3(-2.55,1.05,1.25),Color("586b68"))
	b.box(Vector3(.08,.08,.08),Vector3(-3.44,1.04,1.25),Color("f34c32"))

	RallyStageLandmarks._mesh(airframe,b)
	airframe.add_child(rotor)
	rotor.position.y = 2.2
	var blades := RallySampleMeshes.new()
	blades.box(Vector3(12,.06,.35),Vector3.ZERO,Color("4a5a58"))
	blades.box(Vector3(.35,.06,12),Vector3.ZERO,Color("4a5a58"))
	RallyStageLandmarks._mesh(rotor,blades)
	airframe.add_child(tail_rotor)
	tail_rotor.position = Vector3(.23,1.8,8.1)
	var tail := RallySampleMeshes.new()
	tail.box(Vector3(.05,3,.18),Vector3.ZERO,Color("6e7770"))
	tail.box(Vector3(.05,.18,3),Vector3.ZERO,Color("6e7770"))
	RallyStageLandmarks._mesh(tail_rotor,tail)
	# Main camera sees the aircraft; its own aerial camera excludes its render layer.
	for visual: Node in airframe.find_children("*","MeshInstance3D",true,false): visual.layers = 16
	airframe.visible = false
	camera_viewport = SubViewport.new()
	camera_viewport.name = "AerialPhotoViewport"
	camera_viewport.size = Vector2i(960,540)
	camera_viewport.world_3d = scene.get_world_3d()
	camera_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(camera_viewport)
	photo_camera = Camera3D.new()
	photo_camera.current = true
	photo_camera.cull_mask = 0xfffff & ~16
	photo_camera.fov = 47
	photo_camera.far = 6200
	camera_viewport.add_child(photo_camera)
	photos_enabled = DisplayServer.get_name()!="headless" and not "--test-defaults" in OS.get_cmdline_user_args()

func reset() -> void:
	next_pass = 0
	next_allowed_time = 0
	clock = 0
	shot_count = 0
	active_time = 0
	airframe.visible = false
	rotor_audio.stop()

func advance(dt: float) -> void:
	clock += dt
	rotor.rotation.y = fmod(clock*28,TAU)
	tail_rotor.rotation.x = fmod(clock*37,TAU)
	if scene.session.phase!=RallyStageSession.Phase.RUNNING:
		airframe.visible = false
		rotor_audio.stop()
		return
	var progress: float = scene.session.progress/scene.generator.route.length
	if clock>=next_allowed_time and active_time<=0 and next_pass<FRACTIONS.size() and progress>=FRACTIONS[next_pass]:
		next_allowed_time = clock+47
		active_time = 12
		photographed = false
		next_pass += 1
	active_time = maxf(0,active_time-dt)
	airframe.visible = active_time>0
	if not airframe.visible:
		rotor_audio.stop()
		return
	if not rotor_audio.playing and DisplayServer.get_name()!="headless": rotor_audio.play()
	rotor_audio.volume_linear = .75*smoothstep(0,2,active_time)*(1-smoothstep(10,12,active_time))
	var pose: Transform3D = scene.vehicle.get_global_transform_interpolated()
	var forward := -pose.basis.z
	forward.y = 0
	forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var departure := smoothstep(10,12,active_time)+(1-smoothstep(0,2,active_time))
	airframe.global_position = pose.origin+forward*30+right*(14+departure*100+sin(clock*.4)*3)+Vector3.UP*(12+departure*8+sin(clock*.6))
	airframe.look_at(pose.origin+forward*90,Vector3.UP)
	airframe.rotation.z = -.07
	if active_time<8 and not photographed:
		photographed = true
		shot_count+=1
		if photos_enabled and not capture_pending: _capture_photo.call_deferred()

func _capture_photo() -> void:
	if not is_instance_valid(scene) or not is_inside_tree(): return
	capture_pending = true
	photo_camera.global_position = airframe.global_position+Vector3(-2,-2.5,0)
	photo_camera.look_at(scene.vehicle.global_position+Vector3.UP*.45)
	camera_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	await RenderingServer.frame_post_draw
	if not is_inside_tree() or not is_instance_valid(scene): return
	var image := camera_viewport.get_texture().get_image()
	if image!=null:
		last_saved = album.store(image,{"stage":scene.challenge.stage.stage_id,"vehicle":scene.challenge.vehicle.vehicle_id,"power_ps":scene.challenge.vehicle.power_ps,"time":scene.session.total_time(),"camera":"helicopter"})
		if last_saved.is_empty() and not album.message.is_empty():
			scene.recovery_notice = album.message
			scene.recovery_notice_time = 4
	capture_pending = false
