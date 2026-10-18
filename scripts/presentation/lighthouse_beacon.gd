class_name RallyLighthouseBeacon
extends Node3D

func _ready() -> void:
	position.y = 21.7
	var light := SpotLight3D.new()
	light.light_color = Color("ffda72")
	light.position.z = -2.1
	light.light_energy = 4.0
	light.spot_range = 170
	light.spot_angle = 12
	light.spot_attenuation = .55
	light.shadow_enabled = false
	add_child(light)
	# A subtle scattering volume makes the sweep legible in daylight, too.
	var rays := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = .16
	cone.bottom_radius = 18
	cone.height = 120
	cone.radial_segments = 24
	cone.cap_top = false
	cone.cap_bottom = false
	rays.mesh = cone
	rays.rotation.x = PI/2
	rays.position.z = -62
	rays.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var glow := ShaderMaterial.new()
	glow.shader = preload("res://assets/shaders/beacon.gdshader")
	rays.material_override = glow
	add_child(rays)
	var bulb := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = .45
	sphere.height = .9
	bulb.mesh = sphere
	bulb.position.z = -2.05
	var emission := StandardMaterial3D.new()
	emission.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	emission.albedo_color = Color("ffe395")
	bulb.material_override = emission
	add_child(bulb)

func _process(dt: float) -> void:
	rotation.y = fmod(rotation.y+dt*.32,TAU)
