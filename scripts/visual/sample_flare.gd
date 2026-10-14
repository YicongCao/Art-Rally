class_name RallySampleFlare
extends RefCounted

var overlay := MeshInstance3D.new()
var material := ShaderMaterial.new()
var enabled: bool = true
var current_strength: float = 0
var screen_sun := Vector2(-2, -2)


func build(camera: Camera3D) -> void:
	material.shader = preload("res://assets/shaders/sample_flare.gdshader")
	material.render_priority = 120
	var mesh := QuadMesh.new()
	mesh.size = Vector2(2,2)
	overlay.name = "PreviewLensFlare"
	overlay.mesh = mesh
	overlay.material_override = material
	overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	overlay.extra_cull_margin = 16384
	overlay.position.z = -1
	overlay.physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_OFF
	camera.add_child(overlay)


static func angular_strength(camera: Camera3D, direction: Vector3) -> float:
	return smoothstep(0.72, 0.93, (-camera.global_basis.z).dot(direction))


func update(camera: Camera3D, direction: Vector3, active: bool, dt: float) -> void:
	var size := camera.get_viewport().get_visible_rect().size
	var target := 0.0
	screen_sun = Vector2(-2,-2)
	if enabled and active and angular_strength(camera,direction) > 0:
		screen_sun = camera.unproject_position(camera.global_position + direction * 2000) / size
		var edge := minf(minf(screen_sun.x, 1-screen_sun.x), minf(screen_sun.y,1-screen_sun.y))
		target = angular_strength(camera,direction) * smoothstep(-0.015,0.06,edge)
	current_strength = lerpf(current_strength, target, 1.0-exp(-10.0*dt))
	overlay.visible = enabled and active and current_strength > 0.001
	material.set_shader_parameter("sun_uv",screen_sun)
	material.set_shader_parameter("viewport_size",size)
	material.set_shader_parameter("strength",current_strength)
