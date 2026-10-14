class_name RallyVehicleFeedback
extends RefCounted

var players: Dictionary = {}
var particles: Array[Dictionary] = []
var elapsed: float = 0
var impact_cooldown: float = 0
var previous_impact: float = 0
var rumble_clock: float = 0
var rumble_device: int = -1
var last_mix: Dictionary = {}
var is_paused: bool = false


func build(parent: Node3D) -> void:
	for kind: String in ["engine","load","asphalt","gravel","mud","water","impact"]:
		var player := AudioStreamPlayer.new()
		player.name = "RallyAudio_"+kind
		player.stream = RallySynthAudio.stream(kind)
		player.volume_db = -80
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		parent.add_child(player)
		if kind!="impact" and DisplayServer.get_name()!="headless": player.play()
		players[kind] = player
	for wheel: int in range(4):
		for kind: String in ["dust","mud","water"]:
			var particle := _particle(kind)
			parent.add_child(particle)
			particles.append({"wheel":wheel,"kind":kind,"emitter":particle})


static func mix_for(car: RallyVehicle) -> Dictionary:
	var result := {"engine":0.15+car.command.throttle*0.16,"load":car.command.throttle*0.20,"asphalt":0.0,"gravel":0.0,"mud":0.0,"water":0.0,"impact":0.0,"slip":0.0}
	for wheel: RallyWheelState in car.wheels:
		if not wheel.grounded or wheel.load<=0: continue
		var speed := clampf(absf(wheel.longitudinal_speed)/25,0,1)
		var slip := clampf(absf(wheel.slip)*0.6+absf(wheel.slip_angle)*1.5,0,1)
		var wet := clampf(wheel.surface.water_depth/0.08,0,1)
		var key: String = ["asphalt","gravel","mud","gravel"][wheel.surface.surface_id]
		result[key] += speed*(0.035+slip*0.13)*(1-wet*0.6)
		result.water += speed*wet*0.14
		result.slip += slip*0.25
		result.impact = maxf(result.impact,clampf((wheel.load-6500)/13000,0,1))
	return result


func update(car: RallyVehicle, settings: RallyGameSettings, controls: RallyInputController, paused: bool, dt: float) -> void:
	is_paused = paused
	for player: AudioStreamPlayer in players.values(): player.stream_paused = paused
	if paused:
		for entry: Dictionary in particles: entry.emitter.emitting = false
		stop_rumble()
		return
	elapsed += dt
	impact_cooldown = maxf(0,impact_cooldown-dt)
	last_mix = mix_for(car)
	for key: String in ["engine","load","asphalt","gravel","mud","water"]:
		var player: AudioStreamPlayer = players[key]
		var target := linear_to_db(maxf(float(last_mix[key])*float(settings.values.volume),0.0001))
		player.volume_db = lerpf(player.volume_db,target,1-exp(-dt*12))
		if key in ["engine","load"]: player.pitch_scale = clampf(car.drivetrain.rpm()/3000,0.28,2.65)
		else: player.pitch_scale = 0.8+minf(car.linear_velocity.length()/50,0.55)
	if elapsed>0.8 and impact_cooldown<=0 and float(last_mix.impact)>previous_impact+0.15:
		var impact: AudioStreamPlayer = players.impact
		impact.volume_db = linear_to_db(maxf(float(last_mix.impact)*float(settings.values.volume)*0.5,0.0001))
		if DisplayServer.get_name()!="headless": impact.play()
		impact_cooldown = 0.25
	previous_impact = last_mix.impact
	for entry: Dictionary in particles:
		var wheel := car.wheels[entry.wheel]
		var active := wheel.grounded and wheel.load>50 and absf(wheel.longitudinal_speed)>3
		var kind: String = entry.kind
		active = active and ((kind=="dust" and wheel.surface.surface_id in [1,3] and wheel.surface.water_depth<0.005) or (kind=="mud" and wheel.surface.surface_id==2 and wheel.surface.water_depth<0.015) or (kind=="water" and wheel.surface.water_depth>0.005))
		var emitter: GPUParticles3D = entry.emitter
		emitter.global_position = wheel.point+Vector3.UP*0.10
		emitter.emitting = active
		emitter.amount_ratio = clampf(absf(wheel.longitudinal_speed)*0.02+absf(wheel.slip)*0.25,0.1,0.7)
	rumble_clock += dt
	if not settings.values.vibration or controls.active_device<0:
		stop_rumble()
	elif rumble_clock>0.08 and controls.active_device in Input.get_connected_joypads():
		if rumble_device!=controls.active_device: stop_rumble()
		rumble_device = controls.active_device
		Input.start_joy_vibration(rumble_device,minf(last_mix.slip*0.25,0.25),minf(last_mix.impact*0.4,0.35),0.12)
		rumble_clock = 0


func reset() -> void:
	elapsed = 0
	previous_impact = 0
	for entry: Dictionary in particles: entry.emitter.restart()
	stop_rumble()


func stop_rumble() -> void:
	if rumble_device>=0: Input.stop_joy_vibration(rumble_device)
	rumble_device = -1


func dispose() -> void:
	stop_rumble()
	for player: AudioStreamPlayer in players.values():
		if is_instance_valid(player):
			player.stream_paused = false
			player.stop()
			player.stream = null


func _particle(kind: String) -> GPUParticles3D:
	var emitter := GPUParticles3D.new()
	emitter.name = "WheelFX_"+kind
	emitter.amount = 35 if kind=="dust" else 24
	emitter.lifetime = 1.3 if kind=="dust" else 0.48
	emitter.local_coords = false
	emitter.emitting = false
	emitter.process_mode = Node.PROCESS_MODE_PAUSABLE
	emitter.visibility_aabb = AABB(Vector3(-8,-3,-8),Vector3(16,12,16))
	emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var material := StandardMaterial3D.new()
	material.albedo_color = Color("b7a27b") if kind=="dust" else (Color("6b4b2c") if kind=="mud" else Color("a6cccf"))
	var mesh: Mesh
	if kind=="dust":
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color(1,1,1,0.20),Color(1,1,1,0)])
		var texture := GradientTexture2D.new()
		texture.gradient = gradient
		texture.width = 32
		texture.height = 32
		texture.fill = GradientTexture2D.FILL_RADIAL
		texture.fill_from = Vector2(0.5,0.5)
		texture.fill_to = Vector2(0.5,0)
		material.albedo_texture = texture
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		var quad := QuadMesh.new()
		quad.size = Vector2(1.2,1.2)
		mesh = quad
	else:
		var cube := BoxMesh.new()
		cube.size = Vector3(0.045,0.09,0.045) if kind=="water" else Vector3(0.065,0.035,0.055)
		mesh = cube
	material.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0,material)
	emitter.draw_pass_1 = mesh
	var process := ParticleProcessMaterial.new()
	process.direction = Vector3(0,1,0)
	process.spread = 65
	process.initial_velocity_min = 0.4 if kind=="dust" else 1.4
	process.initial_velocity_max = 1.2 if kind=="dust" else 3.2
	process.gravity = Vector3(0,0.2,0) if kind=="dust" else Vector3(0,-8,0)
	process.scale_min = 0.4
	process.scale_max = 1.0
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0,0.15,1])
	ramp.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.7),Color(1,1,1,0)])
	var ramp_texture := GradientTexture1D.new()
	ramp_texture.gradient = ramp
	process.color_ramp = ramp_texture
	emitter.process_material = process
	return emitter
