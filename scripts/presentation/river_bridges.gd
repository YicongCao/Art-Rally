class_name RallyRiverBridges
extends RefCounted

static func build(land: RallyStageScenery) -> void:
	for crossing: Vector3 in land.generator.definition.river_crossings:
		var node := Node3D.new()
		node.name = "RiverBridge%d"%crossing.x
		land.dressing.add_child(node)
		node.transform = land.route.pose_at(crossing.x,0)
		var span := crossing.y
		var inverse := node.transform.affine_inverse()
		var deck := RallySampleMeshes.new()
		var rails := RallySampleMeshes.new()
		var first := land.route.index_at(crossing.x-span*.5)
		var last := land.route.index_at(crossing.x+span*.5)+1
		for i: int in range(first,last):
			var a := land.route.points[i]
			var b := land.route.points[i+1]
			var ra := land.route.rights[i]
			var rb := land.route.rights[i+1]
			var wa := land.route.width_at(land.route.distances[i])*.5
			var wb := land.route.width_at(land.route.distances[i+1])*.5
			var corners: Array[Vector3] = [inverse*(a-ra*wa+Vector3.UP*.008),inverse*(a+ra*wa+Vector3.UP*.008),inverse*(b-rb*wb+Vector3.UP*.008),inverse*(b+rb*wb+Vector3.UP*.008)]
			deck.triangle(corners[0],corners[2],corners[1],Color("898979"))
			deck.triangle(corners[1],corners[2],corners[3],Color("898979"))
			deck.beam(corners[0],corners[1],.022,Color("4e5e5a"))
			for side: float in [-1,1]:
				var edge_a := inverse*(a+ra*side*(wa+.20))
				var edge_b := inverse*(b+rb*side*(wb+.20))
				deck.beam(edge_a-Vector3.UP*.16,edge_b-Vector3.UP*.16,.32,Color("b0ad98"))
				rails.beam(edge_a+Vector3.UP*.15,edge_a+Vector3.UP*1.12,.075,Color("ddd3b7"))
				RallyScreenprintProps.add(node,"bridge_post",edge_a)
				for height: float in [.65,1.12]: rails.beam(edge_a+Vector3.UP*height,edge_b+Vector3.UP*height,.075,Color("adb9ae"))
				if i==first or i==last-1:
					deck.beam(edge_a,edge_a-Vector3.UP*3,.65,Color("737c75"))
		RallyStageLandmarks._mesh(node,deck)
		RallyStageLandmarks._mesh(node,rails,true)
		# River runs across the route below the deck. The raised route triangles are the matching deck collision; no second floating floor.
		var water := MeshInstance3D.new()
		water.name = "CrossingRiver"
		var tool := SurfaceTool.new()
		tool.begin(Mesh.PRIMITIVE_TRIANGLES)
		for x: int in range(-120,120,6):
			for corner: Vector2 in [Vector2(x,-span*.45),Vector2(x+6,-span*.45),Vector2(x,span*.45),Vector2(x,span*.45),Vector2(x+6,-span*.45),Vector2(x+6,span*.45)]:
				var x_coord := corner.x
				var z_coord := corner.y+sin(x_coord*.04)*2+sin(x_coord*.11)*.6+signf(corner.y)*sin(x_coord*.07)*1.2
				tool.set_uv(Vector2(x_coord,z_coord))
				tool.add_vertex(Vector3(x_coord,-3.05-x_coord*.006,z_coord))
		tool.generate_normals()
		water.mesh = tool.commit()
		var material := ShaderMaterial.new()
		material.shader = preload("res://assets/shaders/stage_water.gdshader")
		material.set_shader_parameter("river",true)
		water.material_override = material
		water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		node.add_child(water)
		var rocks := RallySampleMeshes.new()
		for i: int in range(20):
			var x := (-1 if i%2==0 else 1)*(7+i*3.8)
			rocks.ellipsoid(Vector3(.6,.55,.8),Vector3(x,-2.8-x*.006,(-1 if i%3==0 else 1)*span*.43),Color("7d8984"))
		RallyStageLandmarks._mesh(node,rocks)
