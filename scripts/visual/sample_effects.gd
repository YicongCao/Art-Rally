class_name RallySampleEffects
extends RefCounted

var emitters: Array[GPUParticles3D] = []


func build(parent: Node3D) -> void:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(1,1,1,0.25),Color(1,1,1,0)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 64
	texture.height = 64
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5,0.5)
	texture.fill_to = Vector2(0.5,0)
	var material := StandardMaterial3D.new()
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_texture = texture
	material.albedo_color = Color("bcaa7e")
	material.vertex_color_use_as_albedo = true
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.no_depth_test = false
	var mesh := QuadMesh.new()
	mesh.size = Vector2(1.5,1.5)
	mesh.material = material
	for i: int in range(2):
		var emitter := GPUParticles3D.new()
		emitter.name = "PreviewDust%d"%i
		emitter.emitting = false
		emitter.amount = 45
		emitter.lifetime = 1.4
		emitter.local_coords = false
		emitter.visibility_aabb = AABB(Vector3(-8,-2,-8),Vector3(16,10,16))
		emitter.draw_pass_1 = mesh
		emitter.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var process := ParticleProcessMaterial.new()
		process.direction = Vector3(0,1,0)
		process.spread = 70
		process.initial_velocity_min = 0.35
		process.initial_velocity_max = 1.0
		process.gravity = Vector3(0,0.25,0)
		process.scale_min = 0.35
		process.scale_max = 0.9
		var ramp := Gradient.new()
		ramp.offsets = PackedFloat32Array([0,0.15,1])
		ramp.colors = PackedColorArray([Color(1,1,1,0),Color(1,1,1,0.65),Color(1,1,1,0)])
		var ramp_texture := GradientTexture1D.new()
		ramp_texture.gradient = ramp
		process.color_ramp = ramp_texture
		emitter.process_material = process
		parent.add_child(emitter)
		emitters.append(emitter)


func update(car: RallyVehicle, enabled: bool) -> void:
	for i: int in range(2):
		var wheel := car.wheels[i+2]
		var emitter := emitters[i]
		emitter.visible = enabled
		emitter.global_position = wheel.point+Vector3.UP*0.12
		emitter.emitting = enabled and wheel.grounded and wheel.load > 50 and wheel.surface.surface_id == 1 and wheel.surface.water_depth < 0.005 and absf(wheel.longitudinal_speed) > 3
		emitter.amount_ratio = clampf(absf(wheel.longitudinal_speed)*0.025+absf(wheel.slip)*0.3,0.1,0.8)
