extends "res://tests/test_suite.gd"
func _run() -> void:
	for id: String in RallyContentCatalog.STAGES:
		var route := RallyStageRoute.new()
		route.build(RallyContentCatalog.stage(id))
		var session := RallyStageSession.new()
		session.setup(route)
		var host := Node3D.new()
		root.add_child(host)
		var markers := RallyCheckpointMarkers.new()
		markers.build(host,route,session.gates)
		var mesh := markers.tube_multimesh.mesh
		var arrays := mesh.surface_get_arrays(0)
		var colors: PackedColorArray=arrays[Mesh.ARRAY_COLOR]
		var masks: PackedVector2Array=arrays[Mesh.ARRAY_TEX_UV2]
		var palette := {}
		var groups := {}
		for c: Color in colors: palette[c.to_html()]=true
		for mask: Vector2 in masks: groups[int(mask.x)]=true
		check(palette.size()>=9,id+": authored checker/cloth/machine colors survive merging")
		check(groups.has(0) and groups.has(1) and groups.has(2),id+": separate rigid, pressure cloth and streamer masks")
		check(mesh.get_aabb().size.y>3.2 and mesh.get_aabb().size.y<3.8,id+": pressure gate has intended height")
		check(markers.tube_multimesh.instance_count==(session.gates.size()-2)*2,id+": every intermediate gate has two complete assemblies")
		var outward := true
		var clearance := true
		for gate: int in range(1,session.gates.size()-1):
			for side: int in range(2):
				var pose := markers.tube_poses[markers.tube_gate_indices[gate]+side]
				var across := route.pose_at(session.gates[gate]).basis.x*(-1 if side==0 else 1)
				outward=outward and pose.basis.x.dot(across)>.99
				# Static mesh + worst inward sway never enters the road corridor.
				var vertices: PackedVector3Array=arrays[Mesh.ARRAY_VERTEX]
				for vertex: int in range(vertices.size()):
					var flex := .10 if masks[vertex].x>.5 else 0.0
					clearance=clearance and .85+vertices[vertex].x-flex>.15
		check(outward,id+": both tips bend out of the road, including rotated corners")
		check(clearance,id+": static foot and full sway envelope clear the road")
		check(markers.root.find_children("*","CollisionObject3D",true,false).is_empty(),id+": presentation does not introduce checkpoint collision")
		check(markers.root.has_node("StartArch") and markers.root.has_node("FinishArch"),id+": timing boundary arches remain")
		markers.update(1)
		check(markers.instance_states[0].r==1,id+": active gate highlight preserves base palette")
		if DisplayServer.get_name()!="headless":
			await process_frame
			await RenderingServer.frame_post_draw
			check(is_equal_approx(markers.tube_multimesh.get_instance_custom_data(0).r,1.0),id+": rendered MultiMesh receives active state")
		markers.advance(.5,session.route.position_at(session.gates[1]))
		if DisplayServer.get_name()!="headless":
			check(markers.fan_players[0].playing and markers.fan_players[1].playing,id+": native spatial fan playback starts")
		check(is_equal_approx(markers.air_time,.5) and markers.fan_gate==1,id+": cloth clock and nearest fan pair advance")
		paused=true
		markers.advance(.5,Vector3.ZERO)
		check(is_equal_approx(markers.air_time,.5) and not markers.fan_players[0].can_process(),id+": pause freezes cloth and suspends spatial fans")
		paused=false
		markers.update(2)
		check(markers.air_material.get_shader_parameter("flutter_gate")==1,id+": passed gate gets bounded streamer response")
		check(markers.fan_players.size()==2 and markers.fan_players[0].stream.loop_mode==AudioStreamWAV.LOOP_FORWARD,id+": only two reusable looping spatial fans")
		markers.advance(.1,Vector3(100000,100000,100000))
		check(markers.fan_gate==-1 and not markers.fan_players[0].playing,id+": distant fans stop")
		host.free()
	await process_frame
	finish()
