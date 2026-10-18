class_name RallySampleAtmosphere
extends RefCounted

# Art-directed 16:00 look, not an astronomical simulation without location/season.
const SUN_ELEVATION_DEGREES := 24.0
const SUN_COLOR := Color("ffe0b0")
const SUN_ENERGY := 1.25
var sun_direction := Vector3.UP
var cloud_root := Node3D.new()
var near_clouds: Array[MeshInstance3D] = []
var far_clouds: Array[MeshInstance3D] = []


func build(land: RallySampleLandscape, sun: DirectionalLight3D) -> void:
	build_at(land.dressing,land.route,land.center,sun)


func build_at(parent: Node3D, route: RallyStageRoute, center: Vector3, sun: DirectionalLight3D, extent: float = 1.0) -> void:
	var forward := route.tangent_at(470)
	forward.y = 0
	forward = forward.normalized()
	var horizontal := forward.rotated(Vector3.UP, -deg_to_rad(14.0))
	var cloud_wind := Vector3(horizontal.z,0,-horizontal.x)
	var elevation := deg_to_rad(SUN_ELEVATION_DEGREES)
	sun_direction = horizontal * cos(elevation) + Vector3.UP * sin(elevation)
	apply_sun(sun)
	cloud_root.name = "WorldSpaceClouds"
	parent.add_child(cloud_root)
	var rng := RandomNumberGenerator.new()
	rng.seed = 160043
	for layer: int in range(2):
		for i: int in range(6 if layer == 0 else 9):
			var count := 6.0 if layer == 0 else 9.0
			var angle := TAU * i / count + layer * 0.39 + rng.randf_range(-0.16,0.16)
			var distance := rng.randf_range(540, 850) if layer == 0 else rng.randf_range(1250, 1700)
			var at := center + Vector3(cos(angle) * distance, rng.randf_range(230, 360) if layer == 0 else rng.randf_range(300, 480), sin(angle) * distance)*extent
			# Leave a small opening around the actual light source for occasional flare.
			if (at - center).normalized().dot(sun_direction) > 0.97: continue
			var cloud := MeshInstance3D.new()
			cloud.name = "Cloud_%d_%d" % [layer, i]
			cloud.mesh = cloud_mesh(200 + i * 17 + layer, sun_direction, layer)
			cloud.position = at
			cloud.rotation.y = atan2(-cloud_wind.z,cloud_wind.x)+rng.randf_range(-0.25,0.25)
			var scale_factor := rng.randf_range(0.75, 1.15) * (1.0 if layer == 0 else 1.35)
			cloud.scale = Vector3.ONE * scale_factor * extent
			cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			cloud_root.add_child(cloud)
			if layer == 0: near_clouds.append(cloud)
			else: far_clouds.append(cloud)


func apply_sun(sun: DirectionalLight3D) -> void:
	sun.basis = Basis.looking_at(-sun_direction, Vector3.UP)
	sun.light_color = SUN_COLOR
	sun.light_energy = SUN_ENERGY


static func cloud_mesh(seed_value: int, light: Vector3, layer: int) -> ArrayMesh:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var tool := SurfaceTool.new()
	tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Blend unequal lobes into one continuous surface. Separate intersecting
	# spheres leave visible seams and resemble a string of balloons.
	var centers: Array[Vector3] = []
	var sizes: Array[Vector3] = []
	for puff: int in range(5):
		var center_weight := 1.0-absf(puff-2)/2.5
		centers.append(Vector3((puff-2)*26.0,rng.randf_range(-2,5)+center_weight*6,rng.randf_range(-14,14)))
		sizes.append(Vector3(rng.randf_range(24,36),rng.randf_range(16,24)+center_weight*12,rng.randf_range(20,30)))
	# Six tetrahedra share each cube's diagonal; a fixed grid gives deterministic
	# geometry and matching edges. The entire surface fits inside these bounds.
	const GRID := Vector3i(27,17,17)
	const OFFSETS := [Vector3i(0,0,0),Vector3i(1,0,0),Vector3i(1,1,0),Vector3i(0,1,0),Vector3i(0,0,1),Vector3i(1,0,1),Vector3i(1,1,1),Vector3i(0,1,1)]
	const TETS := [[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6],[0,5,1,6]]
	var points := PackedVector3Array()
	var fields := PackedFloat32Array()
	for x: int in range(GRID.x):
		for y: int in range(GRID.y):
			for z: int in range(GRID.z):
				var point := Vector3(x,y,z)*8.0-Vector3(104,64,64)
				points.append(point)
				fields.append(_cloud_field(point,centers,sizes))
	for x: int in range(GRID.x-1):
		for y: int in range(GRID.y-1):
			for z: int in range(GRID.z-1):
				var corners: Array[int] = []
				for offset: Vector3i in OFFSETS:
					var cell := Vector3i(x,y,z)+offset
					corners.append((cell.x*GRID.y+cell.y)*GRID.z+cell.z)
				for tetra: Array in TETS:
					var inside: Array[int] = []
					var outside: Array[int] = []
					for corner: int in tetra:
						var index := corners[corner]
						if fields[index]<0: inside.append(index)
						else: outside.append(index)
					if inside.is_empty() or outside.is_empty(): continue
					var edge_points: Array[Vector3] = []
					for a: int in inside:
						for b: int in outside:
							edge_points.append(points[a].lerp(points[b],fields[a]/(fields[a]-fields[b])))
					var indices := [0,1,2] if edge_points.size()==3 else [0,1,2,1,3,2]
					for index: int in indices:
						var point := edge_points[index]
						var normal := Vector3.ZERO
						for axis: int in range(3):
							var offset := Vector3.ZERO
							offset[axis] = 0.5
							normal[axis] = _cloud_field(point+offset,centers,sizes)-_cloud_field(point-offset,centers,sizes)
						tool.set_normal(normal.normalized())
						tool.add_vertex(point)
	var result := tool.commit()
	var material := ShaderMaterial.new()
	material.shader = preload("res://assets/shaders/sample_cloud.gdshader")
	material.set_shader_parameter("sun_direction", light)
	material.set_shader_parameter("distant_layer", float(layer))
	result.surface_set_material(0, material)
	return result


static func _cloud_field(point: Vector3, centers: Array[Vector3], sizes: Array[Vector3]) -> float:
	var distance := 1000.0
	for i: int in range(centers.size()):
		var radius := sizes[i]
		var lobe := ((point-centers[i])/radius).length()-1.0
		lobe *= minf(radius.x,minf(radius.y,radius.z))
		var blend := clampf(0.5+0.5*(lobe-distance)/12.0,0.0,1.0)
		distance = lerpf(lobe,distance,blend)-12.0*blend*(1.0-blend)
	# A gently rounded common underside makes the bank read as a cloud, not
	# disconnected balls, especially when viewed from the road below it.
	var base_plane := -point.y-14.0
	var blend := clampf(0.5+0.5*(distance-base_plane)/4.0,0.0,1.0)
	return lerpf(base_plane,distance,blend)+4.0*blend*(1.0-blend)
