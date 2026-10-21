extends "res://tests/test_suite.gd"

func _run() -> void:
	var colors := {}
	for id: String in RallyContentCatalog.STAGES:
		var route := RallyStageRoute.new()
		route.build(RallyContentCatalog.stage(id))
		var session := RallyStageSession.new()
		session.setup(route)
		var host := Node3D.new()
		root.add_child(host)
		var markers := RallyCheckpointMarkers.new()
		markers.build(host,route,session.gates)
		colors[markers.light_color.to_html()]=true
		check(markers.column_multimesh.instance_count==(session.gates.size()-2)*2,id+": every intermediate gate has paired light beams")
		check(markers.base_multimesh.instance_count==markers.column_multimesh.instance_count,id+": all beams have projectors")
		check(markers.column_gate_indices[0]==-1 and markers.column_gate_indices[-1]==-1,id+": beams exclude timing boundary arches")
		check(markers.root.has_node("StartArch") and markers.root.has_node("FinishArch"),id+": start and finish arches remain")
		check(markers.root.find_children("*","CollisionObject3D",true,false).is_empty(),id+": checkpoints remain non-colliding")
		check(markers.root.find_children("*","AudioStreamPlayer3D",true,false).is_empty(),id+": old fan sounds removed")
		var clear := true
		var upright := true
		var grounded := true
		for gate: int in range(1,session.gates.size()-1):
			for side: int in range(2):
				var pose := markers.column_poses[markers.column_gate_indices[gate]+side]
				var road_pose := route.pose_at(session.gates[gate],0)
				var across := (pose.origin-road_pose.origin).dot(road_pose.basis.x)
				clear=clear and absf(across)-.4>route.width_at(session.gates[gate])*.5+.4
				upright=upright and pose.basis.y.is_equal_approx(Vector3.UP)
				var expected_y := road_pose.origin.y-.85*.18+route.road_relief(session.gates[gate],across)
				grounded=grounded and absf(pose.origin.y-expected_y)<.001
		check(clear,id+": projector footprint clears every road edge")
		check(upright,id+": light beams stay vertical on slopes and turns")
		check(grounded,id+": anchors follow shoulder elevation")
		markers.update(1)
		check(markers.symbols[1].visible and not markers.symbols[2].visible,id+": only required gate carries a symbol")
		check(markers.instance_states[0].r>markers.instance_states[2].r,id+": active beam brighter than future beams")
		markers.advance(.5,route.position_at(session.gates[1]))
		check(markers.light_gate==1 and markers.ground_lights.size()==2,id+": only two reusable nearby ground lights")
		check(markers.ground_lights[0].visible and markers.ground_lights[0].light_energy>0,id+": near gate casts coloured ground light")
		paused=true
		markers.advance(.5,Vector3.ZERO)
		check(is_equal_approx(markers.light_time,.5),id+": animation freezes while paused")
		paused=false
		markers.update(2)
		check(markers.instance_states[0].r<markers.instance_states[4].r and markers.instance_states[2].r==1,id+": passed gate dims and next gate lights up")
		check(markers.beam_material.get_shader_parameter("passed_gate")==1,id+": passage response is tied to the gate just crossed")
		markers.advance(.1,Vector3(100000,100000,100000))
		check(markers.light_gate==-1 and not markers.ground_lights[0].visible,id+": distant ground lights disable")
		if DisplayServer.get_name()!="headless":
			await process_frame
			await RenderingServer.frame_post_draw
			check(is_equal_approx(markers.column_multimesh.get_instance_custom_data(2).r,1),id+": renderer receives active beam state")
			check(is_equal_approx(markers.base_multimesh.get_instance_custom_data(2).r,1),id+": projector state matches beam")
		host.free()
	check(colors.size()==RallyContentCatalog.STAGES.size(),"All environments have distinct light palettes")
	await process_frame
	finish()
