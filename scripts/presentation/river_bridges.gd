class_name RallyRiverBridges
extends RefCounted

static func build(land: RallyStageScenery) -> void:
	for crossing: Vector3 in land.generator.definition.river_crossings:
		var node := Node3D.new()
		node.name = "RiverBridge%d"%crossing.x
		land.dressing.add_child(node)
		node.transform = land.route.pose_at(crossing.x)
		var span := crossing.y
		var width := land.route.width_at(crossing.x)
		var deck := RallySampleMeshes.new()
		deck.box(Vector3(width,.3,span),Vector3(0,-.13,0),Color("898979"))
		for z: int in range(-int(span*.5),int(span*.5),2):
			deck.box(Vector3(width,.015,.045),Vector3(0,.027,z),Color("4e5e5a"))
		for side: float in [-1,1]:
			deck.box(Vector3(.38,.4,span+.6),Vector3(side*(width*.5+.18),.10,0),Color("b0ad98"))
			for end: float in [-1,1]:
				deck.box(Vector3(.8,2.8,1.5),Vector3(side*(width*.5+.3),-1.35,end*(span*.5-1)),Color("737c75"))
		RallyStageLandmarks._mesh(node,deck)
		var rails := RallySampleMeshes.new()
		for side: float in [-1,1]:
			var x := side*(width*.5+.2)
			for z: int in range(-int(span*.5),int(span*.5)+1,2): rails.beam(Vector3(x,.2,z),Vector3(x,1.12,z),.075,Color("ddd3b7"))
			rails.beam(Vector3(x,1.12,-span*.5),Vector3(x,1.12,span*.5),.09,Color("adb9ae"))
			rails.beam(Vector3(x,.65,-span*.5),Vector3(x,.65,span*.5),.07,Color("75847c"))
		RallyStageLandmarks._mesh(node,rails,true)
		# River runs across the route below the deck. The route collision itself is continuous.
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
