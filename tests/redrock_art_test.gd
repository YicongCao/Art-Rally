extends "res://tests/test_suite.gd"
# Structural checks behind docs/expansion/REDROCK_ART_STANDARD.md.
func _run() -> void:
	var app: RallyGameApp = load("res://scenes/game/game.tscn").instantiate()
	root.add_child(app)
	app.profile.path = "user://redrock-art-test-%d/profile.json"%OS.get_process_id()
	app.profile.data = RallyProfileStore.fresh()
	app.chosen_stage = "redrock_canyon"
	app.practice = true
	await app.start_race()
	var land: RallyStageScenery = app.race.presentation.scenery
	var dressing := land.dressing
	var route := land.route
	# A4/A5: continuous canyon walls, riverbed banks, a spanning arch and finish overlook.
	for title: String in ["CanyonWalls","DryRiverbedBanks","MonumentalStoneArch","MesaOverlook","MiningServiceStation","DesertWindpump","DuneHoodoos","DistantButtes","MesaHorizon0","MesaHorizon1"]:
		check(dressing.has_node(title),"Redrock has "+title)
	var walls := dressing.get_node("CanyonWalls")
	var tallest := 0.0
	for side: String in ["Side-1","Side1"]:
		var mesh := (walls.get_node(side) as MeshInstance3D).mesh
		check(mesh.get_faces().size()>2000,"Canyon wall "+side+" is a continuous faceted surface")
		tallest=maxf(tallest,mesh.get_aabb().size.y)
	check(tallest>20,"Canyon walls rise above 20 m")
	var arch_span := dressing.get_node("MonumentalStoneArch/ArchSpan") as MeshInstance3D
	var arch_box := arch_span.get_aabb()
	check(arch_box.size.x>40 and arch_box.position.y+arch_box.size.y>25,"Stone arch spans the road with monumental height")
	# A2/A7: real roadside vegetation, crowds and desert wildlife.
	var plants := 0
	var grass := 0
	for node: Node in dressing.get_children():
		if node is MultiMeshInstance3D:
			if str(node.name).begins_with("DesertPlants"): plants+=(node as MultiMeshInstance3D).multimesh.instance_count
			if str(node.name).begins_with("grass"): grass+=(node as MultiMeshInstance3D).multimesh.instance_count
	check(plants>250 and grass>3000,"Desert has dense yucca, ocotillo and dry grass (plants=%d grass=%d)"%[plants,grass])
	check(land.foliage.spectator_stations.size()==5 and land.foliage.animated_arms.size()>=35,"Spectator groups line the desert stage")
	check(dressing.has_node("MedicalAndMarshals"),"Medical support and marshals are present")
	var kinds: Array=[]
	for event: Dictionary in app.race.wildlife.events: kinds.append(event.kind)
	check(not kinds.is_empty() and kinds.all(func(kind: String) -> bool: return kind in ["kangaroo","ostrich"]),"Only arid-country animals cross the desert: "+str(kinds))
	for placement: Dictionary in land.foliage.placements:
		if placement.kind in ["pine","umbrella"]:
			check(false,"Desert must not plant conifers")
			break
	# A1: low warm sun.
	var sun_height: float = app.race.presentation.atmosphere.sun_direction.y
	check(sun_height>0.17 and sun_height<0.38,"Late-afternoon sun angle (%.2f)"%sun_height)
	# B3: new solid scenery keeps the whole vehicle corridor clear.
	await ticks(2)
	var space: PhysicsDirectSpaceState3D = app.race.vehicle.get_world_3d().direct_space_state
	var blocked := 0
	for station: int in range(5,int(route.length)-5,2):
		for offset: float in [-1.6,-.8,0,.8,1.6]:
			var at := route.position_at(station)+route.rights[route.index_at(station)]*offset
			if not space.intersect_ray(PhysicsRayQueryParameters3D.create(at+Vector3.UP*2.4,at+Vector3.UP*.15,4)).is_empty(): blocked+=1
	check(blocked==0,"Walls, arch and props leave the full corridor clear (%d hits)"%blocked)
	# B4: canyon walls never crowd the road edge.
	var closest := INF
	for side: String in ["Side-1","Side1"]:
		var faces: PackedVector3Array=(walls.get_node(side) as MeshInstance3D).mesh.get_faces()
		for i: int in range(0,faces.size(),7):
			var near := land.nearest(faces[i])
			closest=minf(closest,float(near.distance)-route.width_at(near.s)*.5)
	check(closest>4.0,"Canyon wall keeps more than 4 m from the road edge (%.1f m)"%closest)
	await app.leave_race()
	app.queue_free()
	await process_frame
	finish()
